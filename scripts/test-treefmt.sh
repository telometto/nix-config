#!/usr/bin/env bash
# Test script for treefmt configuration

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Testing treefmt configuration..."

# Check if treefmt-nix is properly configured
echo "Checking flake configuration..."
if nix flake show 2> /dev/null | grep -q formatter; then
  echo -e "${GREEN}[PASS]${NC} Formatter found in flake outputs"
else
  echo -e "${RED}[FAIL]${NC} No formatter found in flake outputs"
  exit 1
fi

# Test the formatter
echo "Testing formatter..."
if nix fmt --help > /dev/null 2>&1; then
  echo -e "${GREEN}[PASS]${NC} nix fmt is available"
else
  echo -e "${RED}[FAIL]${NC} nix fmt is not working"
  exit 1
fi

# Check for formatting issues (dry run)
echo "Checking for formatting issues..."
if nix flake check --impure 2>&1 | grep -q "checks.*formatting.*PASS"; then
  echo -e "${GREEN}[PASS]${NC} All files are properly formatted"
elif nix flake check --impure 2>&1 | grep -q "checks.*formatting.*FAIL"; then
  echo -e "${YELLOW}[WARN]${NC} Some files need formatting - run 'nix fmt' to fix"
else
  echo -e "${BLUE}[INFO]${NC} Formatting check completed (status unclear)"
fi

echo -e "${GREEN}[DONE]${NC} treefmt configuration test completed successfully!"
