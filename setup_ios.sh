#!/bin/bash
set -e

echo "🏌️  PuttTrack – iOS Setup Script"
echo "================================="

# 1. Check Node
if ! command -v node &> /dev/null; then
  echo "❌  Node.js nicht gefunden."
  echo "   Installiere Node via: brew install node"
  echo "   Oder: https://nodejs.org"
  exit 1
fi
echo "✅  Node $(node --version) gefunden"

# 2. Check Xcode CLI tools
if ! command -v xcodebuild &> /dev/null; then
  echo "❌  Xcode Command Line Tools fehlen."
  echo "   Führe aus: xcode-select --install"
  exit 1
fi
echo "✅  Xcode CLI Tools gefunden"

# 3. Go to project dir
cd "$(dirname "$0")"
echo "📁  Projektverzeichnis: $(pwd)"

# 4. Install npm dependencies
echo ""
echo "📦  Installiere npm-Pakete..."
npm install --legacy-peer-deps

# 5. Install Expo CLI if needed
if ! command -v expo &> /dev/null && ! npx expo --version &> /dev/null 2>&1; then
  echo "📦  Installiere Expo CLI global..."
  npm install -g expo-cli
fi

# 6. Prebuild iOS (generates the ios/ native directory)
echo ""
echo "🔨  Generiere natives iOS-Projekt (expo prebuild)..."
npx expo prebuild --platform ios --clean

# 7. Install CocoaPods
echo ""
echo "📦  Installiere CocoaPods..."
if ! command -v pod &> /dev/null; then
  echo "⚠️  CocoaPods nicht gefunden. Installiere..."
  sudo gem install cocoapods
fi
cd ios && pod install && cd ..

# 8. Open in Xcode
echo ""
echo "🚀  Öffne Projekt in Xcode..."
WORKSPACE=$(find ios -name "*.xcworkspace" | head -1)
if [ -n "$WORKSPACE" ]; then
  open "$WORKSPACE"
  echo "✅  Xcode geöffnet: $WORKSPACE"
  echo ""
  echo "👉  In Xcode:"
  echo "   1. Oben links: Simulator auswählen (z.B. iPhone 16)"
  echo "   2. ▶ Play-Button drücken zum Starten"
else
  echo "❌  Kein .xcworkspace gefunden!"
  exit 1
fi

echo ""
echo "✅  Setup abgeschlossen!"
