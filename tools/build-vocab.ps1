<#
.SYNOPSIS
    Erzeugt aus den Klett-Vokabellisten (source-pdfs\gl<N>.pdf) die
    Vokabeldateien web\data\vocab.gl<N>.js.
.DESCRIPTION
    Extrahiert mit pdftotext -table (liegt bei Git fuer Windows bei) und
    zerlegt die Tabelle positionsbasiert:

      U1   S1   family tree   !*fxmli +tri:?   Stammbaum   <kyrillisch>
      ^0   ^sec ^enStart      ^phonStart       ^deStart    ^erstes kyrillisches Zeichen

    Die Spaltenoffsets unterscheiden sich von Seite zu Seite (pdftotext
    berechnet sie je Seite neu) und stimmen auch NICHT mit der Kopfzeile
    ueberein - sie werden deshalb je Seite aus den Datenzeilen selbst
    ermittelt. Zeilen ohne Lektionscode sind Umbruchfortsetzungen und werden
    spaltenweise an den vorherigen Datensatz angehaengt.

    Phonetik (Kletts eigene ASCII-Notation, kein IPA) und die ukrainische
    Spalte werden verworfen.
.EXAMPLE
    .\tools\build-vocab.ps1
    .\tools\build-vocab.ps1 -Band 1 -KeepText
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 6)]
    [int[]]$Band = @(1, 2, 3, 4, 5, 6),
    [switch]$KeepText
)

$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $PSScriptRoot
$pdfDir = Join-Path $root 'source-pdfs'
$outDir = Join-Path $root 'web\data'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# pdftotext kommt mit Git fuer Windows mit; kein eigener Toolchain-Download noetig.
$pdftotext = $null
$cmd = Get-Command pdftotext -ErrorAction SilentlyContinue
if ($cmd) { $pdftotext = $cmd.Source }
if (-not $pdftotext) {
    $guess = 'C:\Program Files\Git\mingw64\bin\pdftotext.exe'
    if (Test-Path $guess) { $pdftotext = $guess }
}
if (-not $pdftotext) { throw "pdftotext nicht gefunden (kommt mit Git fuer Windows: mingw64\bin\pdftotext.exe)." }

# Lektionscodes des Lehrwerks: Pick-up A/B, Units, Across cultures,
# Focus on ..., Text smart.
$reCode  = '^(PU[AB]|U[0-9]|AC[0-9]|F[0-9]|TS[0-9]?)(\s|$)'
$reNoise = 'Ernst Klett Verlag|Passend zu|^\s*Vokabular|^\s*Lektion|^\s*$'

function Get-Mode([hashtable]$hist) {
    if ($hist.Count -eq 0) { return -1 }
    $best = -1; $bestN = -1
    foreach ($k in ($hist.Keys | Sort-Object)) {
        if ($hist[$k] -gt $bestN) { $bestN = $hist[$k]; $best = [int]$k }
    }
    return $best
}

function Get-FirstNonSpace([string]$s, [int]$from) {
    for ($i = $from; $i -lt $s.Length; $i++) { if ($s[$i] -ne ' ') { return $i } }
    return -1
}

function Get-PageAnchors([string[]]$dataLines) {
    # Phonetik-Spalte: das '!' steht in jeder Datenzeile an derselben Stelle.
    $phonHist = @{}
    foreach ($l in $dataLines) {
        $i = $l.IndexOf('!')
        if ($i -ge 0) { $phonHist[$i] = [int]$phonHist[$i] + 1 }
    }
    $phon = Get-Mode $phonHist
    if ($phon -lt 1) { return $null }

    # Spaltenanfaenge = Zeichen mit mindestens zwei Leerzeichen davor. Die
    # letzte haeufige Position vor der Phonetik ist die Englisch-Spalte;
    # alles davor sind Lektions- und Abschnittscode (CI, S1, ST, SK2, ...).
    $startHist = @{}
    foreach ($l in $dataLines) {
        $upto = [Math]::Min($l.Length, $phon)
        for ($i = 2; $i -lt $upto; $i++) {
            if ($l[$i] -ne ' ' -and $l[$i-1] -eq ' ' -and $l[$i-2] -eq ' ') {
                $startHist[$i] = [int]$startHist[$i] + 1
            }
        }
    }
    $minHits = [Math]::Max(2, [int]($dataLines.Count * 0.3))
    $cands = @($startHist.Keys | Where-Object { $startHist[$_] -ge $minHits } | Sort-Object)
    if ($cands.Count -eq 0) { return $null }
    $en = [int]$cands[-1]

    # Deutsch-Spalte: erstes Zeichen hinter dem '?' der Phonetik.
    $deHist = @{}
    foreach ($l in $dataLines) {
        $q = $l.IndexOf('?', $phon)
        if ($q -lt 0) { continue }
        $d = Get-FirstNonSpace $l ($q + 1)
        if ($d -gt $q) { $deHist[$d] = [int]$deHist[$d] + 1 }
    }
    $de = Get-Mode $deHist
    if ($de -le $phon -or $en -ge $phon) { return $null }

    return [pscustomobject]@{ En = $en; Phon = $phon; De = $de }
}

function Get-Slice([string]$line, [int]$from, [int]$to) {
    if ($from -ge $line.Length) { return '' }
    if ($to -lt 0 -or $to -gt $line.Length) { $to = $line.Length }
    if ($to -le $from) { return '' }
    $s = $line.Substring($from, $to - $from)
    return ($s -replace '\s+', ' ').Trim()
}

$summary = @()

foreach ($n in $Band) {
    $pdf = Join-Path $pdfDir "gl$n.pdf"
    if (-not (Test-Path $pdf)) { throw "source-pdfs\gl$n.pdf fehlt - erst tools\fetch-vocab.ps1 laufen lassen." }

    # Ueber eine Datei statt ueber die Pipeline, weil PowerShell 5.1 die
    # Ausgabe nativer Programme mit der Konsolen-Codepage dekodiert und die
    # Umlaute sonst zerstoert.
    $txt = Join-Path $pdfDir "gl$n.txt"
    & $pdftotext -table -enc UTF-8 $pdf $txt
    if ($LASTEXITCODE -ne 0) { throw "pdftotext ist bei Band $n mit Exitcode $LASTEXITCODE ausgestiegen." }

    $raw   = [System.IO.File]::ReadAllText($txt, [System.Text.Encoding]::UTF8)
    $pages = $raw -split "`f"

    $records = New-Object System.Collections.ArrayList
    $lastRec = $null
    $skipped = 0

    foreach ($page in $pages) {
        $lines = $page -split "`r?`n"
        $dataLines = @($lines | Where-Object { $_ -match $reCode })
        if ($dataLines.Count -lt 3) { continue }

        $a = Get-PageAnchors $dataLines
        if (-not $a) { throw "Band ${n}: Spalten einer Seite nicht erkannt (erste Zeile: '$($dataLines[0])')." }

        foreach ($line in $lines) {
            if ($line -match $reNoise) { continue }

            $code = ''
            $sec  = ''
            if ($line -match $reCode) {
                $code = $Matches[1]
                $sec  = Get-Slice $line $code.Length $a.En
            }

            $en   = Get-Slice $line $a.En $a.Phon
            $rest = Get-Slice $line $a.De -1

            # Deutsch endet, wo die ukrainische Spalte beginnt.
            $cyr = [regex]::Match($rest, '\p{IsCyrillic}')
            if ($cyr.Success) { $de = $rest.Substring(0, $cyr.Index).Trim() } else { $de = $rest }

            if ($code -ne '') {
                if ($en -eq '' -and $de -eq '') { continue }
                $lastRec = [pscustomobject]@{ Code = $code; Sec = $sec; En = $en; De = $de }
                [void]$records.Add($lastRec)
            } elseif ($lastRec) {
                # Umbruchfortsetzung der vorherigen Zeile
                if ($en -ne '') { $lastRec.En = ($lastRec.En + ' ' + $en).Trim() }
                if ($de -ne '') { $lastRec.De = ($lastRec.De + ' ' + $de).Trim() }
            }
        }
    }

    if (-not $KeepText) { Remove-Item $txt -Force }

    # --- Datensaetze aufbereiten und nach Lektion gruppieren -------------
    $unitOrder = New-Object System.Collections.ArrayList
    $byUnit    = @{}

    foreach ($r in $records) {
        $en = $r.En.Trim()
        $de = $r.De.Trim()
        if ($en -eq '' -or $de -eq '') { $skipped++; continue }

        # Kletts Semikolon trennt gleichwertige Uebersetzungen - genau die
        # Liste, die bei der Selbsteingabe alle als richtig gelten soll.
        $vars = @($de -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        if ($vars.Count -eq 0) { $skipped++; continue }

        $words = ($en -split '\s+').Count
        if ($en -match '[.!?]$' -or $words -gt 3) { $kind = 'p' } else { $kind = 'w' }

        if (-not $byUnit.ContainsKey($r.Code)) {
            $byUnit[$r.Code] = New-Object System.Collections.ArrayList
            [void]$unitOrder.Add($r.Code)
        }
        $w = [ordered]@{ en = $en; de = $vars; kind = $kind }
        if ($r.Sec -ne '') { $w.sec = $r.Sec }
        [void]$byUnit[$r.Code].Add($w)
    }

    $units = @()
    foreach ($code in $unitOrder) {
        $units += [ordered]@{ code = $code; words = @($byUnit[$code]) }
    }

    $obj = [ordered]@{
        band    = "gl$n"
        version = 1
        source  = "Klett Vokabelliste Green Line Bayern (Ausgabe 2017), Band $n"
        units   = $units
    }

    $json = $obj | ConvertTo-Json -Depth 8 -Compress
    # Alles ausserhalb von ASCII escapen, damit die Datei unabhaengig von
    # jeder Zeichensatz-Erkennung im Browser korrekt geladen wird.
    $json = [regex]::Replace($json, '[^\x20-\x7E]', {
        param($m) '\u{0:x4}' -f [int][char]$m.Value
    })

    $out = Join-Path $outDir "vocab.gl$n.js"
    [System.IO.File]::WriteAllText($out, "window.VOCAB_GL$n = $json;`r`n", $Utf8NoBom)

    $total = ($units | ForEach-Object { $_.words.Count } | Measure-Object -Sum).Sum
    $kb    = [math]::Round((Get-Item $out).Length / 1KB)
    Write-Host ("  [ok] Band {0}: {1} Vokabeln in {2} Lektionen, {3} verworfen -> web\data\vocab.gl{0}.js ({4} KB)" -f $n, $total, $units.Count, $skipped, $kb) -ForegroundColor Green

    $summary += [pscustomobject]@{
        Band = $n; Vokabeln = $total; Lektionen = $units.Count; Verworfen = $skipped
        Codes = ($unitOrder -join ',')
    }
}

Write-Host ''
$summary | Format-Table -AutoSize
