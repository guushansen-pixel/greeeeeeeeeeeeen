<#
.SYNOPSIS
    Laedt die kostenlosen Klett-Vokabellisten (PDF) zu Green Line, Ausgabe
    Bayern ab 2017, Band 1-6 nach source-pdfs\.
.DESCRIPTION
    Klett stellt diese Listen oeffentlich bereit (urspruenglich als Hilfe fuer
    ukrainische Gefluechtete, Spalten: Lektion | Englisch | Phonetik | Deutsch |
    Ukrainisch). Uebersicht:
    https://www.klett.de/inhalt/vokabellisten/green-line-bayern-(ausgabe-2017)/278509

    Die PDFs tragen "(c) Ernst Klett Verlag ... Alle Rechte vorbehalten" und
    sind deshalb gitignored - sie werden bei Bedarf hiermit neu geladen.
.EXAMPLE
    .\tools\fetch-vocab.ps1
    .\tools\fetch-vocab.ps1 -Band 1 -Force
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 6)]
    [int[]]$Band = @(1, 2, 3, 4, 5, 6),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'source-pdfs'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# Die ISBN-Nummer im Dateinamen folgt dem Schulbuch: Band 1 = 978-3-12-803010-4
$base = 'https://www.klett.de/inhalt/media_fast_path/145'

foreach ($n in $Band) {
    $name = "Vokabelliste_8030{0}0_GL_BY_17_{0}_ukr.pdf" -f $n
    $dest = Join-Path $outDir "gl$n.pdf"

    if ((Test-Path $dest) -and -not $Force) {
        Write-Host ("  [skip] Band {0} liegt schon in source-pdfs\gl{0}.pdf" -f $n) -ForegroundColor DarkGray
        continue
    }

    $url = "$base/$name"
    Write-Host ("  [get ] Band {0} <- {1}" -f $n, $url)
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing

    $kb = [math]::Round((Get-Item $dest).Length / 1KB)
    if ($kb -lt 50) { throw "Band $n ist nur ${kb} KB gross - das sieht nicht nach der PDF-Liste aus." }
    Write-Host ("  [ok  ] Band {0}: {1} KB" -f $n, $kb) -ForegroundColor Green
}
