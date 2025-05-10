#!/bin/bash
# filepath: /Users/han/coding/hello-grpc/get_grpc_protobuf_versions.sh
# 获取本地 gRPC 和 Protobuf 版本

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== 检测 gRPC 和 Protobuf 版本 =====${NC}\n"

# 检查 protoc (Protobuf compiler) 版本
echo -e "${YELLOW}检查 protoc 版本...${NC}"
if command -v protoc &> /dev/null; then
    PROTOC_VERSION=$(protoc --version | awk '{print $2}')
    echo -e "${GREEN}✓ Protobuf 编译器版本: ${PROTOC_VERSION}${NC}"
else
    echo -e "${RED}✗ protoc 未安装或不在 PATH 中${NC}"
fi

# 检查 grpc_cli 工具版本 (如果有)
echo -e "\n${YELLOW}检查 grpc_cli 版本...${NC}"
if command -v grpc_cli &> /dev/null; then
    GRPC_CLI_VERSION=$(grpc_cli --version | head -n 1)
    echo -e "${GREEN}✓ gRPC CLI 工具版本: ${GRPC_CLI_VERSION}${NC}"
else
    echo -e "${RED}✗ grpc_cli 未安装或不在 PATH 中${NC}"
fi

# 检查系统库中的 gRPC 和 Protobuf
echo -e "\n${YELLOW}检查系统库中的 gRPC 和 Protobuf...${NC}"

# macOS 特定检查
if [[ "$(uname)" == "Darwin" ]]; then
    echo -e "\n${YELLOW}在 macOS 上检查 Homebrew 安装的版本:${NC}"
    
    if brew list --versions grpc &> /dev/null; then
        BREW_GRPC_VERSION=$(brew list --versions grpc)
        echo -e "${GREEN}✓ Homebrew gRPC: ${BREW_GRPC_VERSION}${NC}"
    else
        echo -e "${RED}✗ gRPC 未通过 Homebrew 安装${NC}"
    fi
    
    if brew list --versions protobuf &> /dev/null; then
        BREW_PROTOBUF_VERSION=$(brew list --versions protobuf)
        echo -e "${GREEN}✓ Homebrew Protobuf: ${BREW_PROTOBUF_VERSION}${NC}"
    else
        echo -e "${RED}✗ Protobuf 未通过 Homebrew 安装${NC}"
    fi
fi

# Linux 特定检查
if [[ "$(uname)" == "Linux" ]]; then
    echo -e "\n${YELLOW}在 Linux 上检查安装的库版本:${NC}"
    
    # 检查 pkg-config 是否可用
    if command -v pkg-config &> /dev/null; then
        if pkg-config --exists protobuf; then
            PROTOBUF_VERSION=$(pkg-config --modversion protobuf)
            echo -e "${GREEN}✓ 系统 Protobuf 库版本: ${PROTOBUF_VERSION}${NC}"
        else
            echo -e "${RED}✗ 系统 Protobuf 开发库未安装或不可通过 pkg-config 检测${NC}"
        fi
        
        if pkg-config --exists grpc; then
            GRPC_VERSION=$(pkg-config --modversion grpc)
            echo -e "${GREEN}✓ 系统 gRPC 库版本: ${GRPC_VERSION}${NC}"
        else
            echo -e "${RED}✗ 系统 gRPC 开发库未安装或不可通过 pkg-config 检测${NC}"
        fi
    else
        echo -e "${RED}✗ pkg-config 未安装，无法检测系统库版本${NC}"
    fi
    
    # 检查 apt 包管理器中的版本 (Debian/Ubuntu)
    if command -v apt &> /dev/null && command -v dpkg &> /dev/null; then
        echo -e "\n${YELLOW}检查 Debian/Ubuntu 包:${NC}"
        
        if dpkg -l | grep -q "libprotobuf"; then
            PROTOBUF_DEB=$(dpkg -l | grep "libprotobuf" | grep -v "dev" | head -n 1 | awk '{print $2 " " $3}')
            echo -e "${GREEN}✓ Debian/Ubuntu Protobuf: ${PROTOBUF_DEB}${NC}"
        else
            echo -e "${RED}✗ Protobuf 未通过 apt 安装${NC}"
        fi
        
        if dpkg -l | grep -q "libgrpc"; then
            GRPC_DEB=$(dpkg -l | grep "libgrpc" | grep -v "dev" | head -n 1 | awk '{print $2 " " $3}')
            echo -e "${GREEN}✓ Debian/Ubuntu gRPC: ${GRPC_DEB}${NC}"
        else
            echo -e "${RED}✗ gRPC 未通过 apt 安装${NC}"
        fi
    fi
    
    # 检查 rpm 包管理器中的版本 (CentOS/RHEL/Fedora)
    if command -v rpm &> /dev/null; then
        echo -e "\n${YELLOW}检查 RPM 包:${NC}"
        
        if rpm -qa | grep -q "protobuf"; then
            PROTOBUF_RPM=$(rpm -qa | grep "protobuf" | grep -v "devel" | head -n 1)
            echo -e "${GREEN}✓ RPM Protobuf: ${PROTOBUF_RPM}${NC}"
        else
            echo -e "${RED}✗ Protobuf 未通过 rpm 安装${NC}"
        fi
        
        if rpm -qa | grep -q "grpc"; then
            GRPC_RPM=$(rpm -qa | grep "grpc" | grep -v "devel" | head -n 1)
            echo -e "${GREEN}✓ RPM gRPC: ${GRPC_RPM}${NC}"
        else
            echo -e "${RED}✗ gRPC 未通过 rpm 安装${NC}"
        fi
    fi
fi
