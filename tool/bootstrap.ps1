$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$flutter = Get-Command flutter -ErrorAction Stop
Write-Host "Using Flutter: $($flutter.Source)"

function Invoke-Flutter {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
  )

  & $flutter.Source @FlutterArgs

  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($FlutterArgs -join ' ') failed with exit code $LASTEXITCODE."
  }
}

Invoke-Flutter --version

# Regenerate only the native Android/Windows host scaffolds with Flutter's
# minimal template. Existing application sources are preserved.
Invoke-Flutter create `
  --empty `
  --platforms=android,windows `
  --org=com.mindtzijib `
  --project-name=aularaiz `
  .

# Older bootstrap runs used Flutter's default counter template, which can
# leave an untracked test/widget_test.dart that references MyApp. Remove only
# that generated sample; never delete a tracked project test.
$sampleTest = 'test/widget_test.dart'
if (Test-Path $sampleTest) {
  $trackedSampleTest = & git ls-files -- $sampleTest
  $isDefaultSample = Select-String -Path $sampleTest -Pattern 'MyApp' -Quiet

  if (-not $trackedSampleTest -and $isDefaultSample) {
    Write-Host 'Removing stale generated Flutter sample test.'
    Remove-Item $sampleTest -Force
  }
}

Invoke-Flutter pub get
Invoke-Flutter gen-l10n
Invoke-Flutter analyze
Invoke-Flutter test

Write-Host 'AulaRaiz foundation is ready for local development.'
