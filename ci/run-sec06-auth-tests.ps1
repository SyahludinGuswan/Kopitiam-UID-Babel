$ErrorActionPreference = "Stop"

Push-Location (Join-Path $PSScriptRoot "..\kopitiam_auth")
try {
  npm test
  if ($LASTEXITCODE -ne 0) { throw "kopitiam_auth tests failed with exit code $LASTEXITCODE" }
} finally {
  Pop-Location
}
