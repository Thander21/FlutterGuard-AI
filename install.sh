#!/bin/sh
# Install FlutterGuard globally from git (SYS-CLI-001b).
# Requires the Dart SDK (3.10+) on PATH.
set -e
dart pub global activate --source git https://github.com/Thander21/FlutterGuard-AI.git
flutterguard check --help >/dev/null
echo "FlutterGuard installed."
