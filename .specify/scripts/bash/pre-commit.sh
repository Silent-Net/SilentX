#!/bin/bash
# Pre-commit hook for SilentX
# Constitution Section VII: Continuous Integration and Validation

set -e

echo "🔍 Running pre-commit validation..."

# Check if we're in the right directory
if [ ! -f "SilentX.xcodeproj/project.pbxproj" ]; then
    echo "❌ Not in SilentX project root"
    exit 1
fi

# Build validation
echo "⚙️  Building project..."
if xcodebuild build -scheme SilentX -destination 'platform=macOS' -quiet; then
    echo "✅ Build succeeded"
else
    echo "❌ Build failed - fix errors before committing"
    exit 1
fi

# Optional: Uncomment to run tests (slower)
# echo "🧪 Running tests..."
# if xcodebuild test -scheme SilentX -destination 'platform=macOS' -quiet; then
#     echo "✅ Tests passed"
# else
#     echo "❌ Tests failed"
#     exit 1
# fi

echo "✅ Pre-commit validation passed"
exit 0
