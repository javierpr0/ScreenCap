#!/bin/bash

# Script to create a ScreenCap release
# Usage: ./create-release.sh [version]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to show usage
show_usage() {
    echo "Usage: $0 [version]"
    echo ""
    echo "Examples:"
    echo "  $0 1.1.0          # Create release v1.1.0"
    echo "  $0                # Interactive mode"
    echo ""
    echo "This script will:"
    echo "  1. Validate the version format"
    echo "  2. Update CHANGELOG.md if needed"
    echo "  3. Create and push a git tag"
    echo "  4. GitHub Actions will automatically create the release"
}

# Function to validate version format (semantic versioning)
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Error: Version must follow semantic versioning (e.g., 1.0.0)${NC}"
        return 1
    fi
    return 0
}

# Function to check if tag already exists
check_tag_exists() {
    local version=$1
    if git tag -l | grep -q "^v$version$"; then
        echo -e "${RED}Error: Tag v$version already exists${NC}"
        return 1
    fi
    return 0
}

# Function to check if working directory is clean
check_working_directory() {
    if [[ -n $(git status --porcelain) ]]; then
        echo -e "${RED}Error: Working directory is not clean. Please commit or stash changes.${NC}"
        git status --short
        return 1
    fi
    return 0
}

# Function to update changelog
update_changelog() {
    local version=$1
    local date=$(date +"%Y-%m-%d")
    
    echo -e "${BLUE}Checking CHANGELOG.md...${NC}"
    
    if grep -q "## \[$version\]" CHANGELOG.md; then
        echo -e "${GREEN}✅ CHANGELOG.md already contains entry for v$version${NC}"
    else
        echo -e "${YELLOW}⚠️  CHANGELOG.md doesn't contain entry for v$version${NC}"
        echo "Please update CHANGELOG.md with the changes for this version."
        echo "Add a section like:"
        echo ""
        echo "## [$version] - $date"
        echo ""
        echo "### Added"
        echo "- New feature descriptions"
        echo ""
        echo "### Changed"
        echo "- Changed feature descriptions"
        echo ""
        echo "### Fixed"
        echo "- Bug fix descriptions"
        echo ""
        read -p "Press Enter after updating CHANGELOG.md..."
    fi
}

# Main script
echo -e "${BLUE}🚀 ScreenCap Release Creator${NC}"
echo ""

# Check if we're in the right directory
if [[ ! -f "Package.swift" ]] || [[ ! -f "ScreenCapApp.swift" ]]; then
    echo -e "${RED}Error: This script must be run from the ScreenCap project root${NC}"
    exit 1
fi

# Get version from argument or prompt
if [[ -n $1 ]]; then
    if [[ $1 == "-h" ]] || [[ $1 == "--help" ]]; then
        show_usage
        exit 0
    fi
    VERSION=$1
else
    echo "Current tags:"
    git tag -l | tail -5
    echo ""
    read -p "Enter new version (e.g., 1.1.0): " VERSION
fi

# Validate inputs
if [[ -z $VERSION ]]; then
    echo -e "${RED}Error: Version is required${NC}"
    show_usage
    exit 1
fi

validate_version $VERSION || exit 1
check_tag_exists $VERSION || exit 1
check_working_directory || exit 1

echo -e "${GREEN}✅ Creating release v$VERSION${NC}"
echo ""

# Update changelog
update_changelog $VERSION

# Final confirmation
echo -e "${YELLOW}Ready to create release v$VERSION${NC}"
echo "This will:"
echo "  1. Create git tag v$VERSION"
echo "  2. Push the tag to origin"
echo "  3. Trigger GitHub Actions to build and create the release"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Create and push tag
echo -e "${BLUE}Creating git tag...${NC}"
git tag -a "v$VERSION" -m "Release v$VERSION"

echo -e "${BLUE}Pushing tag to origin...${NC}"
git push origin "v$VERSION"

echo ""
echo -e "${GREEN}🎉 Release v$VERSION created successfully!${NC}"
echo ""
echo "GitHub Actions will now:"
echo "  1. Build the application"
echo "  2. Create DMG and ZIP files"
echo "  3. Create a GitHub release with the assets"
echo ""
echo "You can monitor the progress at:"
echo "https://github.com/javierpr0/ScreenCap/actions"
echo ""
echo "The release will be available at:"
echo "https://github.com/javierpr0/ScreenCap/releases/tag/v$VERSION"