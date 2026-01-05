#!/bin/bash
#
# SilentX Release Script
# 
# Usage:
#   ./scripts/release.sh <version> --build-only    # Step 1: Build DMG for testing
#   ./scripts/release.sh <version> --publish       # Step 2: Publish to GitHub after testing
#   ./scripts/release.sh <version>                 # Full release (build + publish)
#
# Example workflow:
#   ./scripts/release.sh 1.0.0 --build-only   # Create DMG, test it
#   ./scripts/release.sh 1.0.0 --publish      # After testing, publish to GitHub
#

set -e

VERSION=""
BUILD_ONLY=false
PUBLISH_ONLY=false
FORCE_RELEASE=false
DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --build-only|--build)
            BUILD_ONLY=true
            ;;
        --publish-only|--publish)
            PUBLISH_ONLY=true
            ;;
        --force)
            FORCE_RELEASE=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION=$arg
            fi
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_dry_run() {
    echo -e "${CYAN}[DRY-RUN]${NC} $1"
}

print_info() {
    echo -e "${MAGENTA}ℹ️${NC} $1"
}

# Check version argument
if [ -z "$VERSION" ]; then
    echo "SilentX Release Script"
    echo ""
    echo "Usage: $0 <version> [options]"
    echo ""
    echo "Options:"
    echo "  --build-only   Only build DMG for testing (no GitHub release)"
    echo "  --publish      Publish existing DMG to GitHub (after testing)"
    echo "  --force        Force release even if version already exists"
    echo "  --dry-run      Simulate the release without making changes"
    echo ""
    echo "Recommended Workflow:"
    echo "  ${GREEN}Step 1:${NC} $0 1.0.0 --build-only   # Build and test DMG"
    echo "  ${GREEN}Step 2:${NC} $0 1.0.0 --publish      # Publish to GitHub"
    echo ""
    echo "Or full release in one command:"
    echo "  $0 1.0.0"
    echo ""
    exit 1
fi

# Validate version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid version format. Use semantic versioning (e.g., 1.0.0)"
    exit 1
fi

cd "$PROJECT_DIR"

# Determine mode
MODE="full"
if [ "$BUILD_ONLY" = true ]; then
    MODE="build"
elif [ "$PUBLISH_ONLY" = true ]; then
    MODE="publish"
fi

DMG_NAME="SilentX-${VERSION}.dmg"
DMG_PATH="build/${DMG_NAME}"

echo ""
if [ "$DRY_RUN" = true ]; then
    echo "🧪 SilentX Release v${VERSION} [DRY-RUN MODE]"
elif [ "$MODE" = "build" ]; then
    echo "📦 SilentX Build v${VERSION} [BUILD ONLY]"
elif [ "$MODE" = "publish" ]; then
    echo "🚀 SilentX Publish v${VERSION} [PUBLISH ONLY]"
else
    echo "🚀 SilentX Release v${VERSION}"
fi
echo "================================"
echo ""

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY-RUN mode enabled - no changes will be made"
    echo ""
fi

# ==========================================
# PRE-FLIGHT CHECKS
# ==========================================

print_step "Pre-flight checks..."

# For publish mode, check if DMG exists
if [ "$MODE" = "publish" ]; then
    if [ ! -f "$DMG_PATH" ]; then
        print_error "DMG not found: $DMG_PATH"
        echo ""
        echo "  Run build first:"
        echo "    $0 ${VERSION} --build-only"
        echo ""
        exit 1
    fi
    print_success "Found DMG: $DMG_PATH"
fi

# Check git tag (only for publish/full mode)
TAG_EXISTS=false
if [ "$MODE" != "build" ]; then
    if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
        TAG_EXISTS=true
        if [ "$FORCE_RELEASE" = true ]; then
            print_warning "Tag v${VERSION} exists locally (--force specified, will skip tag creation)"
        else
            print_error "Version v${VERSION} already exists as a git tag!"
            echo ""
            echo "  Options:"
            echo "    1. Use a different version number"
            echo "    2. Delete the existing tag: git tag -d v${VERSION}"
            echo "    3. Use --force to skip tag creation: $0 ${VERSION} --force"
            echo ""
            exit 1
        fi
    fi
fi

# Check GitHub release (only for publish/full mode)
RELEASE_EXISTS=false
if [ "$MODE" != "build" ] && command -v gh &> /dev/null; then
    if gh release view "v${VERSION}" &>/dev/null; then
        RELEASE_EXISTS=true
        if [ "$FORCE_RELEASE" = true ]; then
            print_warning "Release v${VERSION} exists on GitHub (--force specified, will update assets)"
        else
            print_error "Release v${VERSION} already exists on GitHub!"
            echo ""
            echo "  Options:"
            echo "    1. Use a different version number"
            echo "    2. Delete the existing release: gh release delete v${VERSION}"
            echo "    3. Use --force to update release assets: $0 ${VERSION} --force"
            echo ""
            exit 1
        fi
    fi
fi

# Check local DMG file (only for build/full mode)
DMG_EXISTS=false
if [ "$MODE" != "publish" ] && [ -f "$DMG_PATH" ]; then
    DMG_EXISTS=true
    if [ "$FORCE_RELEASE" = true ]; then
        print_warning "DMG $DMG_PATH exists (--force specified, will overwrite)"
    else
        print_error "DMG file $DMG_PATH already exists!"
        echo ""
        echo "  Options:"
        echo "    1. Delete it manually: rm $DMG_PATH"
        echo "    2. Use --force to overwrite: $0 ${VERSION} --force"
        echo "    3. Or publish existing DMG: $0 ${VERSION} --publish"
        echo ""
        exit 1
    fi
fi

print_success "Pre-flight checks passed"
echo ""

# ==========================================
# BUILD PHASE (skip if publish-only)
# ==========================================

if [ "$MODE" != "publish" ]; then
    
    # Step 1: Clean build
    print_step "Cleaning previous build..."
    if [ "$DRY_RUN" = true ]; then
        print_dry_run "Would run: rm -rf build && mkdir -p build"
    else
        rm -rf build
        mkdir -p build
    fi

    # Step 2: Build release
    print_step "Building release configuration..."
    if [ "$DRY_RUN" = true ]; then
        print_dry_run "Would run: xcodebuild -scheme SilentX -configuration Release build"
        APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "SilentX.app" -path "*Release*" -type d 2>/dev/null | head -1)
        if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
            print_dry_run "Found existing app at: $APP_PATH"
        else
            print_dry_run "No existing build found (would build fresh)"
            APP_PATH="/path/to/SilentX.app"
        fi
    else
        xcodebuild -scheme SilentX \
            -configuration Release \
            -destination 'platform=macOS' \
            build \
            2>&1 | grep -E "(Build |error:|warning:)" || true

        APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "SilentX.app" -path "*Release*" -type d 2>/dev/null | head -1)

        if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
            print_error "Could not find built app. Build may have failed."
            exit 1
        fi

        print_success "App built at: $APP_PATH"
    fi

    # Step 3: Create DMG with beautiful styling
    print_step "Creating DMG package..."
    if [ "$DRY_RUN" = true ]; then
        print_dry_run "Would create beautiful DMG with create-dmg"
        print_dry_run "DMG would be created at: $DMG_PATH"
    else
        # Generate background image if not exists
        BACKGROUND_PATH="$PROJECT_DIR/dmg-assets/background.png"
        if [ ! -f "$BACKGROUND_PATH" ]; then
            print_step "Generating DMG background..."
            if [ -f "$SCRIPT_DIR/generate-dmg-background.swift" ]; then
                swift "$SCRIPT_DIR/generate-dmg-background.swift" "$BACKGROUND_PATH" 2>/dev/null || true
            fi
        fi

        # Create professional DMG with Applications icon drawn on background
        # The symlink is hidden but still functional for drag-and-drop
        if [ -f "$BACKGROUND_PATH" ]; then
            print_info "Creating professional DMG installer..."
            
            # Remove existing files
            rm -f "$DMG_PATH"
            rm -rf build/dmg-staging build/temp.dmg
            mkdir -p build/dmg-staging/.background
            
            # Copy app and background
            cp -R "$APP_PATH" build/dmg-staging/
            cp "$BACKGROUND_PATH" build/dmg-staging/.background/background.png
            
            # Create symlink to Applications (will be hidden)
            ln -s /Applications build/dmg-staging/Applications
            
            # Create writable DMG
            hdiutil create -volname "SilentX ${VERSION}" \
                -srcfolder build/dmg-staging \
                -ov -format UDRW \
                -fs HFS+ \
                -size 60m \
                build/temp.dmg > /dev/null 2>&1
            
            # Mount the DMG
            DEVICE=$(hdiutil attach -readwrite -noverify build/temp.dmg 2>/dev/null | grep "/dev/" | head -1 | awk '{print $1}')
            MOUNT_DIR="/Volumes/SilentX ${VERSION}"
            
            sleep 1
            
            if [ -d "$MOUNT_DIR" ]; then
                # Hide the Applications symlink (icon is on background)
                # SetFile -a V makes it invisible but still functional
                SetFile -a V "$MOUNT_DIR/Applications" 2>/dev/null || chflags hidden "$MOUNT_DIR/Applications" 2>/dev/null || true
                
                # Configure Finder view
                osascript << APPLESCRIPT
tell application "Finder"
    tell disk "SilentX ${VERSION}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 860, 520}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set text size of theViewOptions to 12
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "SilentX.app" of container window to {180, 200}
        -- Applications is hidden, but we still set its position for drag target
        try
            set position of item "Applications" of container window to {480, 200}
        end try
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT
                
                sync
                sleep 1
                hdiutil detach "$DEVICE" > /dev/null 2>&1 || true
            fi
            
            # Convert to compressed DMG
            hdiutil convert build/temp.dmg -format UDZO -o "$DMG_PATH" > /dev/null 2>&1
            rm -f build/temp.dmg
            rm -rf build/dmg-staging
        fi

        if [ -f "$DMG_PATH" ]; then
            DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
            print_success "DMG created: $DMG_PATH (${DMG_SIZE})"
        else
            print_error "Failed to create DMG"
            exit 1
        fi
    fi

    # Step 4: Generate SHA256 checksum
    print_step "Generating checksum..."
    if [ "$DRY_RUN" = true ]; then
        print_dry_run "Would generate SHA256 checksum for $DMG_PATH"
        CHECKSUM="<would-be-calculated>"
    else
        CHECKSUM=$(shasum -a 256 "$DMG_PATH" | cut -d ' ' -f 1)
        echo "$CHECKSUM  ${DMG_NAME}" > "${DMG_PATH}.sha256"
        print_success "SHA256: $CHECKSUM"
    fi
fi

# ==========================================
# PUBLISH PHASE (skip if build-only)
# ==========================================

if [ "$MODE" != "build" ]; then

    # Step 5: Create git tag
    print_step "Creating git tag v${VERSION}..."
    if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
        print_warning "Tag v${VERSION} already exists, skipping tag creation"
    else
        if [ "$DRY_RUN" = true ]; then
            print_dry_run "Would run: git tag -a 'v${VERSION}' -m 'Release v${VERSION}'"
            print_dry_run "Would run: git push origin 'v${VERSION}'"
        else
            git tag -a "v${VERSION}" -m "Release v${VERSION}"
            git push origin "v${VERSION}" 2>/dev/null || print_warning "Could not push tag (may need to push manually)"
            print_success "Tag v${VERSION} created and pushed"
        fi
    fi

    # Step 6: Create GitHub release
    if command -v gh &> /dev/null; then
        print_step "Creating GitHub release..."
        
        if gh release view "v${VERSION}" &>/dev/null; then
            if [ "$FORCE_RELEASE" = true ]; then
                if [ "$DRY_RUN" = true ]; then
                    print_dry_run "Would update existing release v${VERSION} assets"
                else
                    print_step "Updating existing release v${VERSION} assets..."
                    gh release upload "v${VERSION}" \
                        "$DMG_PATH" \
                        --clobber
                    print_success "Release assets updated!"
                fi
            else
                print_warning "Release v${VERSION} already exists on GitHub (use --force to update assets)"
            fi
        else
            if [ "$DRY_RUN" = true ]; then
                print_dry_run "Would create new GitHub release v${VERSION}"
            else
                gh release create "v${VERSION}" \
                    --title "SilentX v${VERSION}" \
                    --generate-notes \
                    "$DMG_PATH"
                
                print_success "GitHub release created!"
            fi
        fi
    else
        print_warning "GitHub CLI (gh) not found. Skipping GitHub release."
        echo "  Install with: brew install gh"
        echo "  Then run: gh auth login"
    fi
fi

# ==========================================
# SUMMARY
# ==========================================

echo ""
echo "================================"

if [ "$DRY_RUN" = true ]; then
    echo "🧪 Dry-run v${VERSION} Complete!"
    echo "================================"
    echo ""
    echo "No changes were made."
    
elif [ "$MODE" = "build" ]; then
    echo "📦 Build v${VERSION} Complete!"
    echo "================================"
    echo ""
    echo "Files created:"
    echo "  📦 $DMG_PATH"
    echo "  🔐 ${DMG_PATH}.sha256"
    echo ""
    echo -e "${GREEN}Next step:${NC} Test the DMG, then publish:"
    echo ""
    echo "  1. Open DMG: open $DMG_PATH"
    echo "  2. Test installation and features"
    echo "  3. Publish: $0 ${VERSION} --publish"
    echo ""
    
elif [ "$MODE" = "publish" ]; then
    echo "🚀 Publish v${VERSION} Complete!"
    echo "================================"
    echo ""
    if command -v gh &> /dev/null; then
        REPO_URL=$(gh repo view --json url -q .url 2>/dev/null || echo "")
        if [ -n "$REPO_URL" ]; then
            echo "Download URL:"
            echo "  ${REPO_URL}/releases/tag/v${VERSION}"
        fi
    fi
    
else
    echo "🎉 Release v${VERSION} Complete!"
    echo "================================"
    echo ""
    echo "Files created:"
    echo "  📦 $DMG_PATH"
    echo "  🔐 ${DMG_PATH}.sha256"
    echo ""
    if command -v gh &> /dev/null; then
        REPO_URL=$(gh repo view --json url -q .url 2>/dev/null || echo "")
        if [ -n "$REPO_URL" ]; then
            echo "Download URL:"
            echo "  ${REPO_URL}/releases/tag/v${VERSION}"
        fi
    fi
    echo ""
    echo "Next steps:"
    echo "  1. Test the DMG installation"
    echo "  2. Update documentation if needed"
    echo "  3. Announce the release"
fi

echo ""
