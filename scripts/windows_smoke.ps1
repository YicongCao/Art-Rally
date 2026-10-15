param(
    [string]$ExePath = "builds/windows/Art Rally/Art Rally.exe"
)

$resolved = Resolve-Path -LiteralPath $ExePath -ErrorAction Stop
$process = Start-Process `
    -FilePath $resolved.Path `
    -ArgumentList @("--", "--test-defaults", "--package-smoke") `
    -PassThru `
    -Wait

if ($process.ExitCode -ne 0) {
    throw "Art Rally package smoke failed with exit code $($process.ExitCode)."
}

Write-Host "WINDOWS PACKAGE SMOKE PASSED"
