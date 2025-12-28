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
#             If not provided, uses the main branch
#
# Examples:
#   ./scripts/setup-qlib.sh           # Clone/update to main branch
#   ./scripts/setup-qlib.sh v0.9.7    # Clone/update to v0.9.7
#

set -e  # Exit on error

# Configuration
QLIB_REPO="https://github.com/microsoft/qlib.git"
QLIB_DIR="qlib"
DEFAULT_VERSION="v0.9.7"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get version from argument or use default
VERSION="${1:-$DEFAULT_VERSION}"

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

        read -p "Do you want to update to $VERSION? (y/n) " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Fetching latest changes..."
            git fetch origin

            echo "Checking out $VERSION..."
            git checkout "$VERSION"

            echo "Pulling latest changes..."
            git pull origin "$VERSION" 2>/dev/null || echo "Already up to date"

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

    # Clone the repository
    git clone --depth 1 --branch "$VERSION" "$QLIB_REPO" "$QLIB_DIR"

    echo ""
    echo -e "${GREEN}✅ Qlib $VERSION cloned successfully${NC}"
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
