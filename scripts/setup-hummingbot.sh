#!/bin/bash
#
# Hummingbot Setup Script
#
# This script automates the process of cloning or updating the Hummingbot repository
# for the AlgVex project.
#
# Usage:
#   ./scripts/setup-hummingbot.sh [version]
#
# Arguments:
#   version - Optional. Specify a Hummingbot version tag (e.g., v2.9.0)
#             If not provided, uses the default stable version
#
# Examples:
#   ./scripts/setup-hummingbot.sh           # Clone/update to default version (v2.11.0)
#   ./scripts/setup-hummingbot.sh v2.8.0    # Clone/update to v2.8.0
#   INTERACTIVE=false ./scripts/setup-hummingbot.sh v2.9.0  # Non-interactive mode
#

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Configuration
HUMMINGBOT_REPO="https://github.com/hummingbot/hummingbot.git"
HUMMINGBOT_DIR="hummingbot"
DEFAULT_VERSION="v2.11.0"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Interactive mode (can be disabled by setting INTERACTIVE=false)
INTERACTIVE="${INTERACTIVE:-true}"

# Get version from argument or use default
VERSION="${1:-$DEFAULT_VERSION}"

# Validate version format (e.g., v2.11.0)
if ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}❌ Invalid version format: $VERSION${NC}"
    echo "Version must be in format: vX.Y.Z (e.g., v2.11.0)"
    exit 1
fi

echo "========================================="
echo "Hummingbot Setup Script for AlgVex"
echo "========================================="
echo ""

# Check if hummingbot directory exists
if [ -d "$HUMMINGBOT_DIR" ]; then
    echo -e "${YELLOW}⚠️  Hummingbot directory already exists${NC}"
    echo "Checking current status..."

    cd "$HUMMINGBOT_DIR"

    # Check if it's a git repository
    if [ -d ".git" ]; then
        echo "Current branch/commit:"
        git log -1 --oneline
        echo ""

        # Prompt for update (or auto-accept in non-interactive mode)
        if [ "$INTERACTIVE" = "true" ]; then
            read -p "Do you want to update to $VERSION? (y/n) " -n 1 -r
            echo ""
        else
            REPLY="y"
            echo "Non-interactive mode: updating to $VERSION"
        fi

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Check for uncommitted changes
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                echo -e "${YELLOW}⚠️  Uncommitted changes detected${NC}"
                echo "Please commit or stash your changes first."
                exit 1
            fi

            echo "Fetching latest changes..."
            git fetch origin

            echo "Checking out $VERSION..."
            if ! git checkout "$VERSION"; then
                echo -e "${RED}❌ Failed to checkout version $VERSION${NC}"
                echo "Please verify the version tag exists."
                exit 1
            fi

            echo "Pulling latest changes..."
            if git pull origin "$VERSION" 2>&1 | grep -q "Already up to date"; then
                echo -e "${GREEN}Already up to date${NC}"
            elif [ ${PIPESTATUS[0]} -eq 0 ]; then
                echo -e "${GREEN}Updated successfully${NC}"
            else
                echo -e "${RED}❌ Failed to pull changes${NC}"
                exit 1
            fi

            echo -e "${GREEN}✅ Hummingbot updated to $VERSION successfully${NC}"
        else
            echo "Skipping update."
        fi
    else
        echo -e "${RED}❌ Directory exists but is not a git repository${NC}"
        echo "Please remove or rename the existing hummingbot directory and run this script again."
        exit 1
    fi

    cd ..
else
    echo -e "${GREEN}📥 Cloning Hummingbot repository...${NC}"
    echo "Repository: $HUMMINGBOT_REPO"
    echo "Version: $VERSION"
    echo ""

    # Clone the repository with error handling
    if git clone --depth 1 --branch "$VERSION" "$HUMMINGBOT_REPO" "$HUMMINGBOT_DIR"; then
        echo ""
        echo -e "${GREEN}✅ Hummingbot $VERSION cloned successfully${NC}"
    else
        echo ""
        echo -e "${RED}❌ Failed to clone Hummingbot repository${NC}"
        echo "Please check:"
        echo "  - Network connectivity"
        echo "  - Version tag exists: $VERSION"
        echo "  - Repository URL: $HUMMINGBOT_REPO"
        exit 1
    fi
fi

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Hummingbot is now available in: ./$HUMMINGBOT_DIR"
echo ""
echo "Next steps:"
echo "1. Install Hummingbot dependencies:"
echo "   cd hummingbot && ./install"
echo ""
echo "2. Or use Docker (recommended):"
echo "   cd hummingbot && docker-compose up -d"
echo ""
echo "3. Start Hummingbot:"
echo "   cd hummingbot && ./start"
echo ""
echo "4. Read the documentation:"
echo "   https://docs.hummingbot.org/"
echo ""
echo "For more information, visit:"
echo "https://github.com/hummingbot/hummingbot"
echo ""
