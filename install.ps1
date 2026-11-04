# Install FlutterGuard globally from git (SYS-CLI-001b).
# Requires the Dart SDK (3.10+) on PATH.
# Primary path is `dart install`; `pub global activate` is the fallback
# for SDKs that do not ship `dart install` yet.
$ErrorActionPreference = 'Stop'
dart install --help 2>$null 1>$null
if ($LASTEXITCODE -eq 0) {
  dart install 'flutterguard_ai@{git: {url: https://github.com/Thander21/FlutterGuard-AI.git}}'
} else {
  dart pub global activate --source git https://github.com/Thander21/FlutterGuard-AI.git
}
flutterguard check --help | Out-Null
Write-Output 'FlutterGuard installed.'
