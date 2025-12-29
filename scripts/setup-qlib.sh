#!/bin/bash
#
# Qlib Setup Script
#
# This script automates the process of cloning or updating the Qlib repository
# for the AlgVex project.
#
# Usage:
#   ./scripts/setup-qlib.sh [version]
#
# Arguments:
#   version - Optional. Specify a Qlib version tag (e.g., v0.9.7)
#             If not provided, uses the default stable version
#
# Examples:
#   ./scripts/setup-qlib.sh           # Clone/update to default version (v0.9.7)
#   ./scripts/setup-qlib.sh v0.9.6    # Clone/update to v0.9.6
#   INTERACTIVE=false ./scripts/setup-qlib.sh v0.9.7  # Non-interactive mode
#

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Configuration
QLIB_REPO="https://github.com/microsoft/qlib.git"
QLIB_DIR="qlib"
DEFAULT_VERSION="v0.9.7"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Interactive mode (can be disabled by setting INTERACTIVE=false)
INTERACTIVE="${INTERACTIVE:-true}"

# Get version from argument or use default
VERSION="${1:-$DEFAULT_VERSION}"

# Validate version format (e.g., v0.9.7)
if ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}❌ Invalid version format: $VERSION${NC}"
    echo "Version must be in format: vX.Y.Z (e.g., v0.9.7)"
    exit 1
fi

echo "========================================="
echo "Qlib Setup Script for AlgVex"
echo "========================================="
echo ""

# Check if qlib directory exists
if [ -d "$QLIB_DIR" ]; then
    echo -e "${YELLOW}⚠️  Qlib directory already exists${NC}"
    echo "Checking current status..."

    cd "$QLIB_DIR"

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

            echo -e "${GREEN}✅ Qlib updated to $VERSION successfully${NC}"
        else
            echo "Skipping update."
        fi
    else
        echo -e "${RED}❌ Directory exists but is not a git repository${NC}"
        echo "Please remove or rename the existing qlib directory and run this script again."
        exit 1
    fi

    cd ..
else
    echo -e "${GREEN}📥 Cloning Qlib repository...${NC}"
    echo "Repository: $QLIB_REPO"
    echo "Version: $VERSION"
    echo ""

    # Clone the repository with error handling
    if git clone --depth 1 --branch "$VERSION" "$QLIB_REPO" "$QLIB_DIR"; then
        echo ""
        echo -e "${GREEN}✅ Qlib $VERSION cloned successfully${NC}"
    else
        echo ""
        echo -e "${RED}❌ Failed to clone Qlib repository${NC}"
        echo "Please check:"
        echo "  - Network connectivity"
        echo "  - Version tag exists: $VERSION"
        echo "  - Repository URL: $QLIB_REPO"
        exit 1
    fi
fi

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Qlib is now available in: ./$QLIB_DIR"
echo ""
echo "Next steps:"
echo "1. Install Qlib dependencies:"
echo "   cd qlib && pip install -e ."
echo ""
echo "2. Get data:"
echo "   python scripts/get_data.py qlib_data --target_dir ~/.qlib/qlib_data/cn_data"
echo ""
echo "3. Run examples:"
echo "   cd examples && python workflow_by_code.py"
echo ""
echo "For more information, visit:"
echo "https://qlib.readthedocs.io/"
echo ""
