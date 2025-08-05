# Hello gRPC Gateway - Makefile
# Simplified dependency management and build operations

.PHONY: help deps-check deps-update deps-report build test clean security vuln

# Default Go settings
GO_VERSION := 1.23
BINARY_NAME := grpc-gateway
BUILD_DIR := ./build
REPORTS_DIR := ./reports

# Colors for output
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(CYAN)Hello gRPC Gateway - Available Commands$(NC)"
	@echo "========================================"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

deps-check: ## Check for outdated dependencies
	@echo "$(CYAN)📦 Checking dependencies...$(NC)"
	@mkdir -p $(REPORTS_DIR)
	@go list -u -m all | grep -E '\[.*\]' > $(REPORTS_DIR)/outdated.txt || true
	@if [ -s $(REPORTS_DIR)/outdated.txt ]; then \
		echo "$(YELLOW)⚠️  Found outdated dependencies:$(NC)"; \
		cat $(REPORTS_DIR)/outdated.txt; \
	else \
		echo "$(GREEN)✅ All dependencies are up to date$(NC)"; \
	fi

deps-update: ## Update all dependencies
	@echo "$(CYAN)🔄 Updating dependencies...$(NC)"
	@cp go.mod go.mod.backup.$$(date +%Y%m%d_%H%M%S)
	@[ -f go.sum ] && cp go.sum go.sum.backup.$$(date +%Y%m%d_%H%M%S) || true
	@go get -u ./...
	@go mod tidy
	@$(MAKE) build
	@echo "$(GREEN)✅ Dependencies updated successfully$(NC)"

deps-update-minor: ## Update only minor and patch versions
	@echo "$(CYAN)🔄 Updating minor/patch versions...$(NC)"
	@go get -u=patch ./...
	@go mod tidy
	@$(MAKE) build

deps-report: ## Generate detailed dependency report
	@echo "$(CYAN)📄 Generating dependency report...$(NC)"
	@mkdir -p $(REPORTS_DIR)
	@echo "# Hello gRPC Gateway - Dependency Report" > $(REPORTS_DIR)/deps_report.md
	@echo "" >> $(REPORTS_DIR)/deps_report.md
	@echo "**Generated**: $$(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> $(REPORTS_DIR)/deps_report.md
	@echo "**Go Version**: $$(go version)" >> $(REPORTS_DIR)/deps_report.md
	@echo "**Module**: $$(go list -m)" >> $(REPORTS_DIR)/deps_report.md
	@echo "" >> $(REPORTS_DIR)/deps_report.md
	@echo "## Direct Dependencies" >> $(REPORTS_DIR)/deps_report.md
	@echo "" >> $(REPORTS_DIR)/deps_report.md
	@echo "\`\`\`" >> $(REPORTS_DIR)/deps_report.md
	@go list -m all | grep -v "$$(go list -m)" >> $(REPORTS_DIR)/deps_report.md
	@echo "\`\`\`" >> $(REPORTS_DIR)/deps_report.md
	@echo "$(GREEN)📄 Report saved to $(REPORTS_DIR)/deps_report.md$(NC)"

build: ## Build the gateway binary
	@echo "$(CYAN)🔨 Building gateway...$(NC)"
	@mkdir -p $(BUILD_DIR)
	@go build -v -o $(BUILD_DIR)/$(BINARY_NAME) .
	@echo "$(GREEN)✅ Build complete: $(BUILD_DIR)/$(BINARY_NAME)$(NC)"

build-release: ## Build release binary with optimizations
	@echo "$(CYAN)🔨 Building release binary...$(NC)"
	@mkdir -p $(BUILD_DIR)
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
		-ldflags="-w -s -X main.version=$$(git describe --tags --always)" \
		-o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 .
	@CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build \
		-ldflags="-w -s -X main.version=$$(git describe --tags --always)" \
		-o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe .
	@CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build \
		-ldflags="-w -s -X main.version=$$(git describe --tags --always)" \
		-o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 .
	@echo "$(GREEN)✅ Release binaries built$(NC)"

test: ## Run tests
	@echo "$(CYAN)🧪 Running tests...$(NC)"
	@go test -v -race -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)✅ Tests completed$(NC)"

test-short: ## Run short tests only
	@echo "$(CYAN)🧪 Running short tests...$(NC)"
	@go test -short -v ./...

benchmark: ## Run benchmarks
	@echo "$(CYAN)⚡ Running benchmarks...$(NC)"
	@go test -bench=. -benchmem ./...

security: vuln ## Alias for vulnerability check

vuln: ## Check for security vulnerabilities
	@echo "$(CYAN)🔒 Checking for vulnerabilities...$(NC)"
	@command -v govulncheck >/dev/null 2>&1 || go install golang.org/x/vuln/cmd/govulncheck@latest
	@govulncheck ./...
	@echo "$(GREEN)✅ Vulnerability check completed$(NC)"

lint: ## Run linting
	@echo "$(CYAN)🔍 Running linter...$(NC)"
	@command -v golangci-lint >/dev/null 2>&1 || go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@golangci-lint run ./...

fmt: ## Format code
	@echo "$(CYAN)📝 Formatting code...$(NC)"
	@go fmt ./...
	@goimports -w . || go install golang.org/x/tools/cmd/goimports@latest && goimports -w .

vet: ## Run go vet
	@echo "$(CYAN)🔎 Running go vet...$(NC)"
	@go vet ./...

clean: ## Clean build artifacts and reports
	@echo "$(CYAN)🧹 Cleaning up...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -rf $(REPORTS_DIR)
	@rm -f coverage.out coverage.html
	@rm -f go.mod.backup.* go.sum.backup.*
	@echo "$(GREEN)✅ Cleanup completed$(NC)"

deps-clean: ## Clean dependency cache
	@echo "$(CYAN)🧹 Cleaning dependency cache...$(NC)"
	@go clean -modcache
	@echo "$(GREEN)✅ Dependency cache cleaned$(NC)"

all: fmt vet lint test build ## Run all checks and build

ci: deps-check vuln test build ## Run CI pipeline

dev-setup: ## Set up development environment
	@echo "$(CYAN)🛠️  Setting up development environment...$(NC)"
	@go install golang.org/x/tools/cmd/goimports@latest
	@go install golang.org/x/vuln/cmd/govulncheck@latest
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo "$(GREEN)✅ Development environment ready$(NC)"

status: ## Show project status
	@echo "$(CYAN)📊 Project Status$(NC)"
	@echo "=================="
	@echo "Go Version: $$(go version | awk '{print $$3}')"
	@echo "Module: $$(go list -m)"
	@echo "Dependencies: $$(go list -m all | wc -l) total"
	@echo "Build Status: $$(if go build -o /dev/null . 2>/dev/null; then echo '$(GREEN)✅ OK$(NC)'; else echo '$(RED)❌ Failed$(NC)'; fi)"
	@echo "Test Status: $$(if go test -short ./... >/dev/null 2>&1; then echo '$(GREEN)✅ Passing$(NC)'; else echo '$(RED)❌ Failing$(NC)'; fi)"

monitor: ## Run continuous dependency monitoring
	@echo "$(CYAN)👁️  Starting dependency monitor...$(NC)"
	@while true; do \
		$(MAKE) deps-check; \
		sleep 3600; \
	done

# Windows-specific targets
ifeq ($(OS),Windows_NT)
deps-monitor: ## Run dependency monitor script (Windows)
	@deps-monitor.bat check

deps-update-auto: ## Auto-update dependencies (Windows)
	@deps-monitor.bat update
else
deps-monitor: ## Run dependency monitor script (Unix)
	@./deps-monitor.sh check

deps-update-auto: ## Auto-update dependencies (Unix)
	@./deps-monitor.sh update
endif
