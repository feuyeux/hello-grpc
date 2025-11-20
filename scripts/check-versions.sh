#!/bin/bash

# Check local gRPC and Protobuf versions

# Set color output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Checking gRPC and Protobuf Versions =====${NC}\n"

# Check protoc (Protobuf compiler) version
echo -e "${YELLOW}Checking protoc version...${NC}"
if command -v protoc &> /dev/null; then
    PROTOC_VERSION=$(protoc --version | awk '{print $2}')
    echo -e "${GREEN}✓ Protobuf Compiler Version: ${PROTOC_VERSION}${NC}"
else
    echo -e "${RED}✗ protoc not installed or not in PATH${NC}"
fi

# Check grpc_cli tool version (if available)
echo -e "\n${YELLOW}Checking grpc_cli version...${NC}"
if command -v grpc_cli &> /dev/null; then
    GRPC_CLI_VERSION=$(grpc_cli --version | head -n 1)
    echo -e "${GREEN}✓ gRPC CLI Tool Version: ${GRPC_CLI_VERSION}${NC}"
else
    echo -e "${RED}✗ grpc_cli not installed or not in PATH${NC}"
fi

# Check gRPC and Protobuf in system libraries
echo -e "\n${YELLOW}Checking system libraries for gRPC and Protobuf...${NC}"

# macOS specific checks
if [[ "$(uname)" == "Darwin" ]]; then
    echo -e "\n${YELLOW}Checking Homebrew installed versions on macOS:${NC}"
    
    if brew list --versions grpc &> /dev/null; then
        BREW_GRPC_VERSION=$(brew list --versions grpc)
        echo -e "${GREEN}✓ Homebrew gRPC: ${BREW_GRPC_VERSION}${NC}"
    else
        echo -e "${RED}✗ gRPC not installed via Homebrew${NC}"
    fi
    
    if brew list --versions protobuf &> /dev/null; then
        BREW_PROTOBUF_VERSION=$(brew list --versions protobuf)
        echo -e "${GREEN}✓ Homebrew Protobuf: ${BREW_PROTOBUF_VERSION}${NC}"
    else
        echo -e "${RED}✗ Protobuf not installed via Homebrew${NC}"
    fi
fi

# Linux specific checks
if [[ "$(uname)" == "Linux" ]]; then
    echo -e "\n${YELLOW}Checking installed library versions on Linux:${NC}"
    
    # Check if pkg-config is available
    if command -v pkg-config &> /dev/null; then
        if pkg-config --exists protobuf; then
            PROTOBUF_VERSION=$(pkg-config --modversion protobuf)
            echo -e "${GREEN}✓ System Protobuf Library Version: ${PROTOBUF_VERSION}${NC}"
        else
            echo -e "${RED}✗ System Protobuf development library not installed or not detectable via pkg-config${NC}"
        fi
        
        if pkg-config --exists grpc; then
            GRPC_VERSION=$(pkg-config --modversion grpc)
            echo -e "${GREEN}✓ System gRPC Library Version: ${GRPC_VERSION}${NC}"
        else
            echo -e "${RED}✗ System gRPC development library not installed or not detectable via pkg-config${NC}"
        fi
    else
        echo -e "${RED}✗ pkg-config not installed, cannot detect system library versions${NC}"
    fi
    
    # Check apt package manager versions (Debian/Ubuntu)
    if command -v apt &> /dev/null && command -v dpkg &> /dev/null; then
        echo -e "\n${YELLOW}Checking Debian/Ubuntu packages:${NC}"
        
        if dpkg -l | grep -q "libprotobuf"; then
            PROTOBUF_DEB=$(dpkg -l | grep "libprotobuf" | grep -v "dev" | head -n 1 | awk '{print $2 " " $3}')
            echo -e "${GREEN}✓ Debian/Ubuntu Protobuf: ${PROTOBUF_DEB}${NC}"
        else
            echo -e "${RED}✗ Protobuf not installed via apt${NC}"
        fi
        
        if dpkg -l | grep -q "libgrpc"; then
            GRPC_DEB=$(dpkg -l | grep "libgrpc" | grep -v "dev" | head -n 1 | awk '{print $2 " " $3}')
            echo -e "${GREEN}✓ Debian/Ubuntu gRPC: ${GRPC_DEB}${NC}"
        else
            echo -e "${RED}✗ gRPC not installed via apt${NC}"
        fi
    fi
    
    # Check rpm package manager versions (CentOS/RHEL/Fedora)
    if command -v rpm &> /dev/null; then
        echo -e "\n${YELLOW}Checking RPM packages:${NC}"
        
        if rpm -qa | grep -q "protobuf"; then
            PROTOBUF_RPM=$(rpm -qa | grep "protobuf" | grep -v "devel" | head -n 1)
            echo -e "${GREEN}✓ RPM Protobuf: ${PROTOBUF_RPM}${NC}"
        else
            echo -e "${RED}✗ Protobuf not installed via rpm${NC}"
        fi
        
        if rpm -qa | grep -q "grpc"; then
            GRPC_RPM=$(rpm -qa | grep "grpc" | grep -v "devel" | head -n 1)
            echo -e "${GREEN}✓ RPM gRPC: ${GRPC_RPM}${NC}"
        else
            echo -e "${RED}✗ gRPC not installed via rpm${NC}"
        fi
    fi
fi

# Version check complete summary
echo -e "\n${BLUE}===== Version Check Complete =====${NC}"
