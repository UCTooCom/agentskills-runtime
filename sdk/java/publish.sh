#!/bin/bash

# Publish script for agentskills-runtime Java SDK to Maven Central
#
# Usage:
#   ./publish.sh [--test] [--skip-tests]
#
# Prerequisites:
#   1. GPG key installed and configured
#   2. Maven settings.xml configured with Sonatype credentials
#   3. Maven installed

set -e

VERSION=$(grep '<version>' pom.xml | head -1 | sed -e 's/.*<version>\(.*\)<\/version>.*/\1/')
GROUP_ID="com.opencangjie"
ARTIFACT_ID="agentskills-runtime"

echo "=========================================="
echo "Publishing agentskills-runtime Java SDK"
echo "=========================================="
echo "Version: $VERSION"
echo "Group ID: $GROUP_ID"
echo "Artifact ID: $ARTIFACT_ID"
echo ""

# Parse arguments
SKIP_TESTS=false
for arg in "$@"
do
    if [ "$arg" == "--skip-tests" ]; then
        SKIP_TESTS=true
    fi
done

# Check prerequisites
echo "Checking prerequisites..."

# Check if GPG is installed
if ! command -v gpg &> /dev/null; then
    echo "Error: GPG is not installed. Please install GPG first."
    echo "  - macOS: brew install gnupg"
    echo "  - Ubuntu: sudo apt-get install gnupg"
    echo "  - Windows: Download from https://www.gnupg.org/download/"
    exit 1
fi

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    echo "Error: Maven is not installed. Please install Maven first."
    echo "  - macOS: brew install maven"
    echo "  - Ubuntu: sudo apt-get install maven"
    echo "  - Windows: Download from https://maven.apache.org/download.cgi"
    exit 1
fi

echo "✓ GPG installed"
echo "✓ Maven installed"
echo ""

# Clean previous builds
echo "Cleaning previous builds..."
mvn clean

# Run tests
if [ "$SKIP_TESTS" = false ]; then
    echo "Running tests..."
    mvn test
    echo "✓ Tests passed"
else
    echo "Skipping tests (--skip-tests flag)"
fi
echo ""

# Build and deploy
echo "Building and deploying to Maven Central..."
mvn deploy -P release

echo ""
echo "=========================================="
echo "✓ Deployment completed successfully!"
echo "=========================================="
echo ""
echo "The artifact has been deployed to the staging repository."
echo "Please check the staging repository at:"
echo "  https://s01.oss.sonatype.org/"
echo ""
echo "After verifying the staging repository, close and release it manually"
echo "or wait for automatic release (if autoReleaseAfterClose is enabled)."
echo ""
echo "Once released, the artifact will be available at:"
echo "  https://repo1.maven.org/maven2/com/opencangjie/agentskills-runtime/"
echo ""
echo "Maven dependency:"
echo "  <dependency>"
echo "    <groupId>$GROUP_ID</groupId>"
echo "    <artifactId>$ARTIFACT_ID</artifactId>"
echo "    <version>$VERSION</version>"
echo "  </dependency>"
echo ""
echo "Gradle dependency:"
echo "  implementation '$GROUP_ID:$ARTIFACT_ID:$VERSION'"
echo ""
