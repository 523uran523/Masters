<#
.SYNOPSIS
  One-time helper for creating a release signing key for Android.
  Does NOT commit the key. Writes android/key.properties for Gradle.
#>
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$androidDir = Join-Path $root "android"
$storeFile = Join-Path $androidDir "upload-keystore.jks"
$keyProps = Join-Path $androidDir "key.properties"

if (Test-Path $storeFile) {
  $overwrite = Read-Host "Keystore already exists. Overwrite? (y/N)"
  if ($overwrite -ne "y") { Write-Host "Aborted."; exit 0 }
  Remove-Item -Force $storeFile
}

$alias = "upload"
$validity = 10000
$cn = Read-Host "Your name or company (CN)"
$ou = Read-Host "Organizational unit"
$o = Read-Host "Organization"
$l = Read-Host "City"
$st = Read-Host "State/Province"
$c = Read-Host "Country code (2 letters)"
$storePassword = Read-Host "Keystore password" -AsSecureString
$keyPassword = $storePassword

$plainStore = [System.Net.NetworkCredential]::new("", $storePassword).Password
$plainKey = [System.Net.NetworkCredential]::new("", $keyPassword).Password

$dname = "CN=$cn, OU=$ou, O=$o, L=$l, ST=$st, C=$c"
$tool = "keytool"
$args = @(
  "-genkeypair", "-v",
  "-keystore", $storeFile,
  "-storetype", "JKS",
  "-keyalg", "RSA", "-keysize", "2048",
  "-validity", "$validity",
  "-alias", $alias,
  "-dname", $dname,
  "-storepass", $plainStore,
  "-keypass", $plainKey
)

Write-Host "Generating keystore..."
& $tool @args
if (-not (Test-Path $storeFile)) {
  throw "Keystore was not created."
}

@"
storePassword=$plainStore
keyPassword=$plainKey
keyAlias=$alias
storeFile=../upload-keystore.jks
"@ | Set-Content -Path $keyProps -Encoding UTF8

Write-Host ""
Write-Host "Done! Created: $storeFile"
Write-Host "Gradle config: $keyProps"
Write-Host "IMPORTANT: keep the keystore and passwords in at least two independent secure places."
Write-Host "Never commit android/key.properties or *.jks/.keystore (they are gitignored)."
