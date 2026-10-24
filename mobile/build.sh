#!/bin/bash
# Builds the Therapy Pal web app on Vercel.
# Vercel's build machines do not include Flutter, so this downloads it first.
#
# Required Vercel environment variable:
#   API_BASE_URL  e.g. https://your-server.example.com/api   (must end with /api)
# Optional:
#   FLUTTER_VERSION  defaults to the version used during development
set -e

FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.1}"

if [ -z "$API_BASE_URL" ]; then
  echo "ERROR: API_BASE_URL is not set."
  echo "Add it in Vercel: Project Settings > Environment Variables (for example https://your-server.example.com/api)."
  exit 1
fi

if [ ! -d "$HOME/flutter" ]; then
  echo "Downloading Flutter $FLUTTER_VERSION ..."
  git clone https://github.com/flutter/flutter.git --depth 1 --branch "$FLUTTER_VERSION" "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"

flutter --version
flutter pub get

# Flutter web reads settings at BUILD time, so the server address is passed in here.
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"

if [ ! -d "build/web" ]; then
  echo "ERROR: build/web was not created."
  exit 1
fi
echo "Build finished: build/web"
