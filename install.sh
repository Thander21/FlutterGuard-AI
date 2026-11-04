#!/bin/sh
# Install FlutterGuard globally from git (SYS-CLI-001b).
# Requires the Dart SDK (3.10+) on PATH.
# Primary path is `dart install`; `pub global activate` is the fallback
# for SDKs that do not ship `dart install` yet.
set -e
if dart install --help >/dev/null 2>&1; then
  dart install 'flutterguard_ai@{git:{url:https://github.com/Thander21/FlutterGuard-AI.git}}'
else
  dart pub global activate --source git https://github.com/Thander21/FlutterGuard-AI.git
fi
flutterguard check --help >/dev/null
echo "FlutterGuard installed."
