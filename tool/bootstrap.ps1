$ErrorActionPreference = 'Stop'

$flutter = Get-Command flutter -ErrorAction Stop
Write-Host "Using Flutter: $($flutter.Source)"
flutter --version

flutter create `
  --platforms=android,windows `
  --org=com.mindtzijib `
  --project-name=aularaiz `
  .

flutter pub get
flutter gen-l10n
flutter analyze
flutter test

Write-Host 'AulaRaíz foundation is ready for local development.'
