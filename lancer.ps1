param([string]$Device = 'chrome')
$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
$localSdk = Join-Path $projectDirectory '../../work/flutter-sdk/bin/flutter.bat'
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) {
    $flutterExecutable = $flutterCommand.Source
} elseif (Test-Path -LiteralPath $localSdk) {
    $flutterExecutable = (Resolve-Path -LiteralPath $localSdk).Path
    $env:PUB_CACHE = [IO.Path]::GetFullPath((Join-Path $projectDirectory '../../work/pub-cache'))
} else {
    throw 'Flutter est introuvable. Installez Flutter 3.41+ et ajoutez son dossier bin au PATH.'
}
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
Push-Location -LiteralPath $projectDirectory
try {
    $env:CA_PASSE_FLUTTER = $flutterExecutable
    python (Join-Path $projectDirectory 'tool/bootstrap_platforms.py')
    if ($LASTEXITCODE -ne 0) { throw 'La génération des plateformes a échoué.' }
    & $flutterExecutable --suppress-analytics pub get
    if ($LASTEXITCODE -ne 0) { throw 'La récupération des dépendances a échoué.' }
    & $flutterExecutable --suppress-analytics run -d $Device
} finally {
    Pop-Location
}

