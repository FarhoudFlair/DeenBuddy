#!/bin/bash

# DeenBuddy TestFlight Deployment Script
# This script handles the complete TestFlight deployment workflow

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(dirname "$0")/.."
IOS_PROJECT_DIR="$PROJECT_DIR"
FASTLANE_DIR="$PROJECT_DIR/fastlane"

echo -e "${BLUE}🚀 DeenBuddy TestFlight Deployment${NC}"
echo "=================================================="

# Step 1: Pre-flight checks
echo -e "\n${YELLOW}📋 Running pre-flight checks...${NC}"

# Check if we're in the right directory
if [ ! -d "$IOS_PROJECT_DIR" ]; then
    echo -e "${RED}❌ Error: iOS project directory not found at $IOS_PROJECT_DIR${NC}"
    exit 1
fi

# Check if Fastlane is available
if ! command -v fastlane &> /dev/null; then
    echo -e "${RED}❌ Error: Fastlane is not installed${NC}"
    echo "Install with: gem install fastlane"
    exit 1
fi

# Check if we're on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${YELLOW}⚠️  Warning: You're on branch '$CURRENT_BRANCH', not 'main'${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠️  Warning: You have uncommitted changes${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo -e "${GREEN}✅ Pre-flight checks completed${NC}"

# Step 2: Environment check
echo -e "\n${YELLOW}🔧 Checking environment configuration...${NC}"

if [ ! -f "$FASTLANE_DIR/.env" ]; then
    echo -e "${YELLOW}⚠️  No .env file found. Creating from template...${NC}"
    cp "$FASTLANE_DIR/.env.default" "$FASTLANE_DIR/.env"
    echo -e "${RED}❌ Please edit $FASTLANE_DIR/.env with your actual values and run this script again${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Environment configuration found${NC}"

# Step 3: Check provisioning profiles
echo -e "\n${YELLOW}📱 Checking provisioning profiles...${NC}"

# This is a basic check - user should have already set up profiles manually
if ! security find-certificate -c "iPhone Distribution" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Warning: iPhone Distribution certificate not found in keychain${NC}"
    echo "Make sure you have downloaded and installed your distribution certificate"
fi

echo -e "${GREEN}✅ Code signing check completed${NC}"

# Step 4: Run tests
echo -e "\n${YELLOW}🧪 Running tests...${NC}"
cd "$IOS_PROJECT_DIR"

if ! fastlane test; then
    echo -e "${RED}❌ Tests failed. Please fix failing tests before deploying to TestFlight${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All tests passed${NC}"

# Step 5: Deploy to TestFlight
echo -e "\n${YELLOW}🚀 Deploying to TestFlight...${NC}"

# Ask for confirmation
echo -e "${BLUE}This will:${NC}"
echo "• Increment the build number"
echo "• Build the app with Release configuration"
echo "• Upload to TestFlight"
echo "• Commit and push version changes"
echo

read -p "Continue with TestFlight deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Run the TestFlight deployment
if fastlane beta; then
    echo -e "\n${GREEN}🎉 Successfully deployed to TestFlight!${NC}"
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Check App Store Connect for the new build"
    echo "2. Add external testers if needed"
    echo "3. Distribute the build to your testing groups"
    echo "4. Monitor TestFlight for crashes and feedback"
else
    echo -e "\n${RED}❌ TestFlight deployment failed${NC}"
    echo "Check the error messages above and resolve any issues"
    exit 1
fi

# Step 6: Summary
echo -e "\n${GREEN}📊 Deployment Summary${NC}"
echo "=================================================="
echo "• Project: DeenBuddy iOS"
echo "• Configuration: Release"
echo "• Distribution: TestFlight"
echo "• Branch: $CURRENT_BRANCH"
echo "• Build uploaded successfully"
echo

echo -e "${BLUE}🔗 Useful links:${NC}"
echo "• App Store Connect: https://appstoreconnect.apple.com"
echo "• TestFlight: https://testflight.apple.com"
echo "• Build logs: $IOS_PROJECT_DIR/build/"
echo

echo -e "${GREEN}✨ Deployment complete!${NC}"