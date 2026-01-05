# SilentX Release SOP

Standard Operating Procedure for releasing new versions of SilentX.

## Prerequisites

1. **Xcode** - Latest stable version
2. **Developer ID Certificate** - For code signing (or self-signed for testing)
3. **create-dmg** - Install via `brew install create-dmg`
4. **GitHub CLI** - Install via `brew install gh` and authenticate with `gh auth login`

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR.MINOR.PATCH** (e.g., 1.2.3)
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

## Release Workflow

### 1. Prepare the Release

```bash
# 1. Update version in Xcode
# Open SilentX.xcodeproj → SilentX target → General → Version & Build
# - Marketing Version: 1.x.x
# - Build: increment (e.g., 1, 2, 3...)

# 2. Update CHANGELOG.md (if exists)
# Document all changes since last release

# 3. Commit version bump
git add .
git commit -m "chore: bump version to 1.x.x"
git push origin main
```

### 2. Build Release Archive

```bash
cd /Users/xmx/workspace/Silent-Net/SilentX

# Clean build folder
xcodebuild clean -scheme SilentX -configuration Release

# Build for Release
xcodebuild -scheme SilentX \
  -configuration Release \
  -destination 'platform=macOS' \
  -archivePath build/SilentX.xcarchive \
  archive

# Export the app (for ad-hoc distribution without notarization)
xcodebuild -exportArchive \
  -archivePath build/SilentX.xcarchive \
  -exportPath build/Release \
  -exportOptionsPlist ExportOptions.plist
```

#### ExportOptions.plist (create if doesn't exist)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

For unsigned/ad-hoc builds (development):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>-</string>
</dict>
</plist>
```

### 3. Create DMG Package

```bash
# Set version (match Xcode version)
VERSION="1.0.0"

# Create DMG using create-dmg
create-dmg \
  --volname "SilentX ${VERSION}" \
  --volicon "SilentX/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 100 \
  --icon "SilentX.app" 180 170 \
  --hide-extension "SilentX.app" \
  --app-drop-link 480 170 \
  --no-internet-enable \
  "build/SilentX-${VERSION}.dmg" \
  "build/Release/SilentX.app"
```

#### Alternative: Simple DMG (if create-dmg fails)

```bash
VERSION="1.0.0"

# Create temporary folder
mkdir -p build/dmg-staging
cp -R build/Release/SilentX.app build/dmg-staging/

# Create Applications symlink
ln -s /Applications build/dmg-staging/Applications

# Create DMG
hdiutil create -volname "SilentX ${VERSION}" \
  -srcfolder build/dmg-staging \
  -ov -format UDZO \
  "build/SilentX-${VERSION}.dmg"

# Clean up
rm -rf build/dmg-staging
```

### 4. Code Sign & Notarize (Production)

For distribution outside App Store:

```bash
VERSION="1.0.0"

# Sign the DMG
codesign --force --sign "Developer ID Application: YOUR_NAME (TEAM_ID)" \
  "build/SilentX-${VERSION}.dmg"

# Submit for notarization
xcrun notarytool submit "build/SilentX-${VERSION}.dmg" \
  --keychain-profile "AC_PASSWORD" \
  --wait

# Staple the notarization ticket
xcrun stapler staple "build/SilentX-${VERSION}.dmg"
```

### 5. Create GitHub Release

```bash
VERSION="1.0.0"

# Create git tag
git tag -a "v${VERSION}" -m "Release v${VERSION}"
git push origin "v${VERSION}"

# Create GitHub release with DMG
gh release create "v${VERSION}" \
  --title "SilentX v${VERSION}" \
  --notes-file RELEASE_NOTES.md \
  "build/SilentX-${VERSION}.dmg"

# Or with auto-generated notes
gh release create "v${VERSION}" \
  --title "SilentX v${VERSION}" \
  --generate-notes \
  "build/SilentX-${VERSION}.dmg"
```

### 6. Post-Release

1. **Verify download works** - Download from GitHub and test installation
2. **Update documentation** - If needed
3. **Announce** - Post release notes to relevant channels

## Quick Release Script

Save as `scripts/release.sh`:

```bash
#!/bin/bash
set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/release.sh <version>"
  echo "Example: ./scripts/release.sh 1.0.0"
  exit 1
fi

echo "🚀 Starting release process for v${VERSION}..."

# Build
echo "📦 Building release..."
xcodebuild -scheme SilentX -configuration Release -destination 'platform=macOS' build

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "SilentX.app" -path "*Release*" | head -1)

if [ -z "$APP_PATH" ]; then
  echo "❌ Could not find built app"
  exit 1
fi

echo "✅ Found app at: $APP_PATH"

# Create build directory
mkdir -p build

# Create DMG
echo "💿 Creating DMG..."
rm -rf build/dmg-staging
mkdir -p build/dmg-staging
cp -R "$APP_PATH" build/dmg-staging/
ln -s /Applications build/dmg-staging/Applications

hdiutil create -volname "SilentX ${VERSION}" \
  -srcfolder build/dmg-staging \
  -ov -format UDZO \
  "build/SilentX-${VERSION}.dmg"

rm -rf build/dmg-staging

echo "✅ DMG created: build/SilentX-${VERSION}.dmg"

# Create git tag
echo "🏷️  Creating git tag..."
git tag -a "v${VERSION}" -m "Release v${VERSION}" || true
git push origin "v${VERSION}" || true

# Create GitHub release
echo "🌐 Creating GitHub release..."
gh release create "v${VERSION}" \
  --title "SilentX v${VERSION}" \
  --generate-notes \
  "build/SilentX-${VERSION}.dmg"

echo "🎉 Release v${VERSION} complete!"
echo "📥 Download: https://github.com/YOUR_ORG/SilentX/releases/tag/v${VERSION}"
```

Make it executable:
```bash
chmod +x scripts/release.sh
```

Usage:
```bash
# Normal release (will fail if version already exists)
./scripts/release.sh 1.0.0

# Force release (overwrites existing DMG, updates GitHub release assets)
./scripts/release.sh 1.0.0 --force
```

**Note**: The script performs pre-flight checks before building:
- Checks if git tag `v1.0.0` already exists
- Checks if GitHub release already exists
- Checks if local DMG file already exists

If any of these exist, the script will abort unless `--force` is specified.

## Troubleshooting

### DMG won't open (quarantine)
```bash
xattr -d com.apple.quarantine SilentX-1.0.0.dmg
```

### App damaged error
Users need to run:
```bash
xattr -cr /Applications/SilentX.app
```

### Build fails with signing error
For local testing without signing:
```bash
xcodebuild -scheme SilentX \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  build
```

## File Structure After Release

```
build/
├── SilentX.xcarchive/      # Xcode archive
├── Release/
│   └── SilentX.app         # Exported app
└── SilentX-1.0.0.dmg       # Final DMG
```

---

*Last updated: January 2026*

