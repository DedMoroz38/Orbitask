#!/bin/bash
set -e

echo "🌌 CosmicTasks — Build Setup"
echo "=============================="
echo ""

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode command line tools not found."
    echo "   Install with: xcode-select --install"
    exit 1
fi

# Check for xcodegen
if ! command -v xcodegen &> /dev/null; then
    echo "📦 Installing xcodegen via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Install from https://brew.sh"
        echo "   Then run: brew install xcodegen"
        exit 1
    fi
    brew install xcodegen
fi

echo "🔧 Generating Xcode project..."
xcodegen generate

echo ""
echo "✅ Project generated! Opening in Xcode..."
open CosmicTasks.xcodeproj

echo ""
echo "📋 Next steps:"
echo "   1. Select the 'CosmicTasks' scheme in Xcode"
echo "   2. Press ⌘R to build & run"
echo "   3. The app will appear as a ✨ icon in your menu bar"
echo "   4. The cosmic scene renders directly on your desktop"
echo ""
echo "💡 Tips:"
echo "   - Hover over meteors to see task details"
echo "   - Double-click a meteor to mark it complete"  
echo "   - Click the menu bar icon to manage tasks"
echo "   - Tasks persist in ~/Library/Application Support/CosmicTasks/"
