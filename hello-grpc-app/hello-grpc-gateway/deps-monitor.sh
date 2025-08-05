#!/bin/bash

# Hello gRPC Gateway - Dependency Version Monitor
# This script checks for dependency updates and generates reports

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
REPORTS_DIR="$PROJECT_DIR/reports"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create reports directory
mkdir -p "$REPORTS_DIR"

echo -e "${BLUE}🔍 Hello gRPC Gateway - Dependency Monitor${NC}"
echo "=================================================="

# Check if we're in the right directory
if [ ! -f "go.mod" ]; then
    echo -e "${RED}❌ Error: go.mod not found. Please run this script from the hello-grpc-gateway directory.${NC}"
    exit 1
fi

# Function to check Go dependencies
check_go_dependencies() {
    echo -e "\n${BLUE}📦 Checking Go dependencies...${NC}"
    
    # Get current Go version
    GO_VERSION=$(go version | awk '{print $3}')
    echo "Go version: $GO_VERSION"
    
    # Check for module updates
    echo -e "\n${YELLOW}Checking for available updates...${NC}"
    
    # Create temporary file for outdated deps
    OUTDATED_FILE="$REPORTS_DIR/outdated_deps.txt"
    go list -u -m all > "$OUTDATED_FILE"
    
    # Filter outdated dependencies
    OUTDATED_COUNT=$(grep -E '\[.*\]' "$OUTDATED_FILE" | wc -l)
    
    if [ "$OUTDATED_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Found $OUTDATED_COUNT outdated dependencies:${NC}"
        echo
        
        # Create detailed report
        REPORT_FILE="$REPORTS_DIR/dependency_report_$(date +%Y%m%d_%H%M%S).md"
        
        cat > "$REPORT_FILE" << EOF
# Hello gRPC Gateway - Dependency Report

**Generated**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')  
**Go Version**: $GO_VERSION  
**Module**: $(go list -m)  

## Outdated Dependencies

| Module | Current Version | Available Version | Update Type |
|--------|----------------|-------------------|-------------|
EOF
        
        # Process outdated dependencies
        grep -E '\[.*\]' "$OUTDATED_FILE" | while IFS= read -r line; do
            MODULE=$(echo "$line" | awk '{print $1}')
            CURRENT=$(echo "$line" | awk '{print $2}')
            AVAILABLE=$(echo "$line" | grep -o '\[.*\]' | tr -d '[]')
            
            # Determine update type (major, minor, patch)
            UPDATE_TYPE="patch"
            if [[ "$AVAILABLE" =~ ^v[0-9]+\. ]] && [[ "$CURRENT" =~ ^v[0-9]+\. ]]; then
                CURRENT_MAJOR=$(echo "$CURRENT" | sed 's/^v\([0-9]*\).*/\1/')
                AVAILABLE_MAJOR=$(echo "$AVAILABLE" | sed 's/^v\([0-9]*\).*/\1/')
                
                if [ "$AVAILABLE_MAJOR" -gt "$CURRENT_MAJOR" ]; then
                    UPDATE_TYPE="major ⚠️"
                else
                    CURRENT_MINOR=$(echo "$CURRENT" | sed 's/^v[0-9]*\.\([0-9]*\).*/\1/')
                    AVAILABLE_MINOR=$(echo "$AVAILABLE" | sed 's/^v[0-9]*\.\([0-9]*\).*/\1/')
                    
                    if [ "$AVAILABLE_MINOR" -gt "$CURRENT_MINOR" ]; then
                        UPDATE_TYPE="minor"
                    fi
                fi
            fi
            
            echo "| $MODULE | $CURRENT | $AVAILABLE | $UPDATE_TYPE |" >> "$REPORT_FILE"
            echo -e "  ${YELLOW}$MODULE${NC}: $CURRENT → $AVAILABLE ($UPDATE_TYPE)"
        done
        
        cat >> "$REPORT_FILE" << EOF

## Direct Dependencies

\`\`\`
$(go list -m all | grep -v "$(go list -m)" | head -20)
\`\`\`

## Module Graph

\`\`\`
$(go mod graph | head -10)
\`\`\`

## Commands to Update

To update all dependencies:
\`\`\`bash
go get -u ./...
go mod tidy
\`\`\`

To update specific dependencies:
\`\`\`bash
EOF
        
        # Add specific update commands
        grep -E '\[.*\]' "$OUTDATED_FILE" | while IFS= read -r line; do
            MODULE=$(echo "$line" | awk '{print $1}')
            AVAILABLE=$(echo "$line" | grep -o '\[.*\]' | tr -d '[]')
            echo "go get $MODULE@$AVAILABLE" >> "$REPORT_FILE"
        done
        
        echo "\`\`\`" >> "$REPORT_FILE"
        
        echo -e "\n${GREEN}📄 Detailed report saved to: $REPORT_FILE${NC}"
        
    else
        echo -e "${GREEN}✅ All dependencies are up to date!${NC}"
        
        # Create up-to-date report
        REPORT_FILE="$REPORTS_DIR/dependency_report_$(date +%Y%m%d_%H%M%S).md"
        cat > "$REPORT_FILE" << EOF
# Hello gRPC Gateway - Dependency Report

**Generated**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')  
**Go Version**: $GO_VERSION  
**Module**: $(go list -m)  
**Status**: ✅ All dependencies are up to date

## Current Dependencies

\`\`\`
$(go list -m all | grep -v "$(go list -m)")
\`\`\`
EOF
    fi
    
    # Cleanup
    rm -f "$OUTDATED_FILE"
}

# Function to check for security vulnerabilities
check_vulnerabilities() {
    echo -e "\n${BLUE}🔒 Checking for security vulnerabilities...${NC}"
    
    # Install govulncheck if not present
    if ! command -v govulncheck &> /dev/null; then
        echo "Installing govulncheck..."
        go install golang.org/x/vuln/cmd/govulncheck@latest
    fi
    
    # Run vulnerability check
    VULN_FILE="$REPORTS_DIR/vulnerabilities_$(date +%Y%m%d_%H%M%S).txt"
    
    if govulncheck ./... > "$VULN_FILE" 2>&1; then
        echo -e "${GREEN}✅ No vulnerabilities found${NC}"
    else
        echo -e "${YELLOW}⚠️  Vulnerabilities detected. Check: $VULN_FILE${NC}"
    fi
}

# Function to generate dependency tree
generate_dependency_tree() {
    echo -e "\n${BLUE}🌳 Generating dependency tree...${NC}"
    
    TREE_FILE="$REPORTS_DIR/dependency_tree_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "# Hello gRPC Gateway - Dependency Tree" > "$TREE_FILE"
    echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> "$TREE_FILE"
    echo "" >> "$TREE_FILE"
    
    echo "## Module Graph" >> "$TREE_FILE"
    go mod graph >> "$TREE_FILE"
    
    echo -e "${GREEN}📄 Dependency tree saved to: $TREE_FILE${NC}"
}

# Function to update dependencies
update_dependencies() {
    echo -e "\n${BLUE}🔄 Updating dependencies...${NC}"
    
    # Backup current go.mod and go.sum
    cp go.mod "go.mod.backup.$(date +%Y%m%d_%H%M%S)"
    if [ -f go.sum ]; then
        cp go.sum "go.sum.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    echo "Backing up current go.mod..."
    
    # Update dependencies
    echo "Updating all dependencies..."
    if go get -u ./...; then
        echo "Running go mod tidy..."
        go mod tidy
        
        echo "Verifying build..."
        if go build ./...; then
            echo -e "${GREEN}✅ Dependencies updated successfully!${NC}"
        else
            echo -e "${RED}❌ Build failed after update. Restoring backup...${NC}"
            # Restore backup
            for backup in go.mod.backup.*; do
                if [ -f "$backup" ]; then
                    cp "$backup" go.mod
                    break
                fi
            done
            for backup in go.sum.backup.*; do
                if [ -f "$backup" ]; then
                    cp "$backup" go.sum
                    break
                fi
            done
            exit 1
        fi
    else
        echo -e "${RED}❌ Failed to update dependencies${NC}"
        exit 1
    fi
}

# Main execution
main() {
    case "${1:-check}" in
        "check")
            check_go_dependencies
            check_vulnerabilities
            generate_dependency_tree
            ;;
        "update")
            echo -e "${YELLOW}⚠️  This will update all dependencies. Continue? (y/N)${NC}"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                update_dependencies
                check_go_dependencies
            else
                echo "Update cancelled."
            fi
            ;;
        "report")
            check_go_dependencies
            generate_dependency_tree
            ;;
        "vuln")
            check_vulnerabilities
            ;;
        *)
            echo "Usage: $0 [check|update|report|vuln]"
            echo ""
            echo "Commands:"
            echo "  check   - Check for outdated dependencies (default)"
            echo "  update  - Update all dependencies"
            echo "  report  - Generate dependency reports"
            echo "  vuln    - Check for security vulnerabilities"
            exit 1
            ;;
    esac
}

main "$@"
