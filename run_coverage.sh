#!/bin/bash

# Exit on error
set -e

# Define colors
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Cleaning existing coverage data...${NC}"
rm -rf coverage

echo -e "${GREEN}Running tests with coverage...${NC}"
dart test --coverage=coverage

echo -e "${GREEN}Formatting coverage report...${NC}"
dart run coverage:format_coverage --packages=.dart_tool/package_config.json --report-on=lib --lcov -i coverage -o coverage/lcov.info

if command -v genhtml >/dev/null 2>&1; then
    echo -e "${GREEN}Generating HTML report...${NC}"
    genhtml coverage/lcov.info -o coverage/html
    echo -e "${GREEN}Coverage report generated at coverage/html/index.html${NC}"
else
    echo -e "${GREEN}genhtml not found. Skipping HTML report generation.${NC}"
    echo -e "You can install it via 'brew install lcov' on macOS."
fi

echo -e "${GREEN}Coverage analysis complete!${NC}"
