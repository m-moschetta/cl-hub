#!/bin/bash
set -e

echo "🚀 Setting up ClaudeHub..."

# Check for xcodegen
if ! command -v xcodegen &> /dev/null; then
    echo "📦 Installing xcodegen via Homebrew..."
    brew install xcodegen
fi

# Generate Xcode project
echo "🔧 Generating Xcode project..."
cd "$(dirname "$0")"
xcodegen generate

echo "✅ Project generated! Opening in Xcode..."
open ClaudeHub.xcodeproj
