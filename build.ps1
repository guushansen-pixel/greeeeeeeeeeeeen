<#
.SYNOPSIS
    Baut den Vokabeltrainer ueber apk-builder und patcht danach nach, was
    apk-builder selbst nicht unterstuetzt: Portrait-Lock, Keep-Screen-On und
    einen Predictive-Back-Handler fuer die Zurueck-Wischgeste.
.DESCRIPTION
    apps\Vokabeltrainer unter apk-builder wird bei jedem Lauf per -Force
    komplett neu aus dem WebView-Template erzeugt (siehe apk-builder\CLAUDE.md) -
    die Patches unten muessen deshalb bei jedem Build erneut angewendet werden.
    Sie sind mit throw-Guards abgesichert: aendert sich das Template von
    apk-builder, bricht der Build laut ab statt still eine unfertige APK zu
    bauen. Aufbau und Patch-Reihenfolge sind bewusst identisch zu
    breathe-well\build.ps1 - nur ohne dessen JS-Bruecke und Erinnerungen.

    Der Predictive-Back-Patch ist hier von Anfang an dabei: ohne ihn schliesst
    die Kanten-Wischgeste bei hohem targetSdk die App, statt im WebView
    zurueckzugehen (in breathe-well erst am Geraet aufgefallen).
.EXAMPLE
    .\build.ps1 -Release -Install
#>
[CmdletBinding()]
param(
    [string]$VersionName = '1.0',
    [int]$VersionCode = 1,
    [switch]$Release,
    [switch]$Install
)

$ErrorActionPreference = 'Stop'

# javac lehnt eine UTF-8-BOM als "Unzulaessiges Zeichen U+FEFF" ab, und
# Set-Content -Encoding utf8 schreibt in PowerShell 5.1 immer eine BOM -
# deshalb wie new-app.ps1 selbst ueber .NET BOM-frei schreiben.
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-TextNoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

$ApkBuilder = "D:\claude code projects\apk-builder"
$Project    = "D:\claude code projects\vokabeltrainer"
$PackageId  = "com.daniel.vokabeltrainer"
$AppName    = "Vokabeltrainer"
$appDir     = Join-Path $ApkBuilder "apps\$AppName"

# Ohne generierte Vokabeldaten waere die APK leer - lieber gleich laut sein.
$dataDir = Join-Path $Project 'web\data'
$packs = @(Get-ChildItem -Path $dataDir -Filter 'vocab.gl*.js' -ErrorAction SilentlyContinue)
if ($packs.Count -eq 0) {
    throw "In web\data\ liegt keine vocab.gl*.js - erst .\tools\fetch-vocab.ps1 und .\tools\build-vocab.ps1 laufen lassen."
}
Write-Host ("  [info] {0} Vokabelpakete werden mitgebaut" -f $packs.Count) -ForegroundColor DarkGray

& "$ApkBuilder\new-app.ps1" -Name $AppName -PackageId $PackageId `
    -WebRoot "$Project\web" `
    -Icon "$Project\icon.xml" `
    -IconBackground "#10352C" `
    -VersionName $VersionName -VersionCode $VersionCode -Force

$javaDir = Join-Path $appDir ("app\src\main\java\" + $PackageId.Replace('.', '\'))

# --- Sprachausgabe-Bruecke hineinkopieren (nicht Teil des Templates) -----
# Liegt als echte Quelldatei vor statt als PowerShell-String: lesbarer, und
# javac meldet Fehler dann an der richtigen Stelle.
Copy-Item "$Project\android-src\TtsBridge.java" $javaDir -Force

# --- AndroidManifest.xml: Portrait-Lock + Predictive Back ----------------
$manifestPath = Join-Path $appDir 'app\src\main\AndroidManifest.xml'
$manifest = Get-Content $manifestPath -Raw

# Patch 1: Portrait-Lock - beim Tippen soll sich das Layout nicht durch eine
# versehentliche Drehung neu aufbauen und die Eingabe verlieren.
$launchModeNeedle = 'android:launchMode="singleTop">'
if ($manifest -notmatch [regex]::Escape($launchModeNeedle)) {
    throw "Manifest-Patchziel (launchMode) nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$manifest = $manifest -replace [regex]::Escape($launchModeNeedle), ('android:launchMode="singleTop"' + "`n            android:screenOrientation=`"portrait`">")

# Patch 2: Predictive Back explizit aktivieren - nur mit diesem Attribut
# registriert Android den OnBackInvokedCallback aus Patch 4 zuverlaessig.
$themeNeedle = 'android:theme="@style/AppTheme">'
if ($manifest -notmatch [regex]::Escape($themeNeedle)) {
    throw "Manifest-Patchziel (theme) nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$manifest = $manifest -replace [regex]::Escape($themeNeedle), ('android:theme="@style/AppTheme"' + "`n        android:enableOnBackInvokedCallback=`"true`">")

# Patch 3: Ab targetSdk 30 sieht eine App fremde Dienste nur noch, wenn sie
# sie in <queries> nennt. Ohne diesen Block findet TextToSpeech keine Engine
# und meldet still einen Init-Fehler - im Desktop-Browser faellt das nicht
# auf, weil dort speechSynthesis benutzt wird.
$appOpenNeedle = '    <application'
if ($manifest -notmatch [regex]::Escape($appOpenNeedle)) {
    throw "Manifest-Patchziel (<application>) nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$queriesBlock = "    <queries>`n        <intent>`n            <action android:name=`"android.intent.action.TTS_SERVICE`" />`n        </intent>`n    </queries>`n`n" + $appOpenNeedle
$manifest = $manifest -replace [regex]::Escape($appOpenNeedle), $queriesBlock

Write-TextNoBom -Path $manifestPath -Content $manifest

# --- MainActivity.java: Keep-Screen-On + Predictive Back -----------------
$mainActivityPath = Join-Path $javaDir 'MainActivity.java'
$java = Get-Content $mainActivityPath -Raw

$importNeedle = 'import android.view.KeyEvent;'
if ($java -notmatch [regex]::Escape($importNeedle)) {
    throw "MainActivity.java Import-Patchziel nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$newImports = "import android.view.WindowManager;`nimport android.window.OnBackInvokedDispatcher;"
$java = $java -replace [regex]::Escape($importNeedle), ($importNeedle + "`n" + $newImports)

# Patch 3: Bildschirm wach halten - beim Nachdenken ueber eine Vokabel
# passiert minutenlang keine Eingabe. FLAG_KEEP_SCREEN_ON braucht keine
# Manifest-Permission (anders als WAKE_LOCK+PowerManager).
$ccNeedle = 'setContentView(webView);'
if ($java -notmatch [regex]::Escape($ccNeedle)) {
    throw "MainActivity.java onCreate-Patchziel nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$java = $java -replace [regex]::Escape($ccNeedle), ($ccNeedle + "`n`n        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);")

# Patch 4: Zurueck-Wischgeste (Predictive Back). Bei targetSdk 33+ faengt
# onKeyDown/KEYCODE_BACK (im Template bereits vorhanden) die moderne
# Kanten-Wischgeste nicht mehr ab - ohne eigenen OnBackInvokedCallback
# schliesst die Geste die App, statt im WebView zurueckzugehen und damit die
# app-eigene history.pushState/popstate-Navigation auszuloesen.
$keepScreenOnNeedle = 'getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);'
if ($java -notmatch [regex]::Escape($keepScreenOnNeedle)) {
    throw "MainActivity.java Predictive-Back-Patchziel nicht gefunden - Keep-Screen-On-Patch hat nicht wie erwartet gegriffen?"
}
$predictiveBackSnippet = $keepScreenOnNeedle + "`n`n        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {`n            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(`n                    OnBackInvokedDispatcher.PRIORITY_DEFAULT,`n                    () -> {`n                        if (webView.canGoBack()) {`n                            webView.goBack();`n                        } else {`n                            finish();`n                        }`n                    });`n        }"
$java = $java -replace [regex]::Escape($keepScreenOnNeedle), $predictiveBackSnippet

# Patch 5: Sprachausgabe-Bruecke anlegen und als window.AndroidTts
# registrieren. Als Feld, damit onDestroy sie wieder abbauen kann - eine
# offene TextToSpeech-Instanz haelt sonst einen Dienst am Leben.
$fieldNeedle = 'private WebView webView;'
if ($java -notmatch [regex]::Escape($fieldNeedle)) {
    throw "MainActivity.java Feld-Patchziel nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$java = $java -replace [regex]::Escape($fieldNeedle), ($fieldNeedle + "`n`n    private TtsBridge tts;")

$clientNeedle = 'webView.setWebViewClient(new LocalWebViewClient());'
if ($java -notmatch [regex]::Escape($clientNeedle)) {
    throw "MainActivity.java JS-Bridge-Patchziel nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$java = $java -replace [regex]::Escape($clientNeedle), ("tts = new TtsBridge(this);`n        webView.addJavascriptInterface(tts, `"AndroidTts`");`n`n        " + $clientNeedle)

# Patch 6: onDestroy gibt es im Template nicht - dazuschreiben.
$saveStateNeedle = @'
    @Override
    protected void onSaveInstanceState(Bundle outState) {
'@
if ($java -notmatch [regex]::Escape($saveStateNeedle)) {
    throw "MainActivity.java onDestroy-Patchziel nicht gefunden - hat sich das apk-builder-Template geaendert?"
}
$onDestroy = "    @Override`n    protected void onDestroy() {`n        if (tts != null) {`n            tts.shutdown();`n            tts = null;`n        }`n        super.onDestroy();`n    }`n`n" + $saveStateNeedle
$java = $java -replace [regex]::Escape($saveStateNeedle), $onDestroy

Write-TextNoBom -Path $mainActivityPath -Content $java

Write-Host "  [ok] Patches angewendet (Portrait-Lock, Keep-Screen-On, Predictive Back, Sprachausgabe)" -ForegroundColor Green

if ($Release -and $Install) {
    & "$ApkBuilder\build-apk.ps1" -App $AppName -Release -Install
} elseif ($Release) {
    & "$ApkBuilder\build-apk.ps1" -App $AppName -Release
} elseif ($Install) {
    & "$ApkBuilder\build-apk.ps1" -App $AppName -Install
} else {
    & "$ApkBuilder\build-apk.ps1" -App $AppName
}
