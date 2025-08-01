# GitHub Actions Workflows

This directory contains automated workflows for managing Flutter and Tauri dependencies and ensuring code quality.

## 🔄 Dependency Management

### Dependabot Configuration (`.github/dependabot.yml`)
- **Flutter**: Automatically checks for Dart package updates in `hello-grpc-flutter/`
- **Tauri Frontend**: Monitors npm dependencies in `hello-grpc-tauri/`
- **Tauri Backend**: Tracks Rust crate updates in `hello-grpc-tauri/src-tauri/`
- **Schedule**: Weekly updates on Monday
- **Features**:
  - Automatic PR creation for dependency updates
  - Commit message prefixes for easy identification
  - Reviewer and assignee assignment

### Flutter & Tauri Dependencies Update (`.github/workflows/flutter-tauri-deps.yml`)
- **Trigger**: Weekly (Monday 9:00 AM UTC) or manual dispatch
- **Features**:
  - Updates Flutter dependencies with `flutter pub upgrade --major-versions`
  - Updates Tauri npm and Cargo dependencies
  - Runs basic tests to ensure compatibility
  - Creates separate PRs for Flutter and Tauri updates
  - Includes security audit checks

### Version Check & Notifications (`.github/workflows/version-check.yml`)
- **Trigger**: Daily (8:00 AM UTC) or manual dispatch
- **Features**:
  - Monitors Flutter SDK versions
  - Checks for outdated Flutter, Tauri npm, and Cargo dependencies
  - Creates/updates GitHub issues with available updates
  - Automatically closes issues when all dependencies are current

## 🤖 Auto-merge (`.github/workflows/auto-merge.yml`)
- **Trigger**: Pull request events
- **Features**:
  - Auto-approves and merges minor/patch dependency updates
  - Runs basic tests before merging
  - Adds warning comments for major version updates
  - Handles both Dependabot and automated PRs

## 🏗️ Build & Test (`.github/workflows/build-test.yml`)
- **Trigger**: Push/PR to main/develop branches, or manual dispatch
- **Features**:
  - Cross-platform testing (Ubuntu, Windows, macOS)
  - Flutter: analyze, test, and build for desktop platforms
  - Tauri: lint, test, and build for all platforms
  - Integration testing
  - Artifact uploads for build outputs

## 📊 Security Auditing

The workflows include security auditing features:
- **Flutter**: Dependency analysis (manual review required)
- **Tauri npm**: `npm audit` with automatic fixes
- **Tauri Cargo**: `cargo audit` for known vulnerabilities

## 🚀 Usage

### Manual Triggers
You can manually trigger workflows from the GitHub Actions tab:

1. **Flutter & Tauri Dependencies Update**:
   - Choose which dependencies to update (Flutter/Tauri)
   - Useful for urgent security updates

2. **Version Check & Notifications**:
   - Get immediate status of available updates
   - Useful before releases

3. **Build & Test**:
   - Verify builds across all platforms
   - Useful for testing changes

### Workflow Outputs

- **Artifacts**: Build outputs for each platform
- **Issues**: Automated dependency update notifications
- **PRs**: Automatic dependency update pull requests
- **Reports**: Security audit and test results

## 🔧 Configuration

### Required Secrets
- `GITHUB_TOKEN`: Automatically provided by GitHub
- `TAURI_PRIVATE_KEY`: (Optional) For signed Tauri builds
- `TAURI_KEY_PASSWORD`: (Optional) For signed Tauri builds

### Customization
- Modify schedules in workflow files
- Adjust auto-merge criteria in `auto-merge.yml`
- Add custom test commands in `build-test.yml`
- Configure notification preferences in `version-check.yml`

## 📝 Best Practices

1. **Review Major Updates**: Auto-merge only handles minor/patch updates
2. **Monitor Issues**: Check the automated update issues regularly
3. **Test Locally**: Always test major dependency updates locally first
4. **Security First**: Review security audit reports in workflow logs

## 🐛 Troubleshooting

- **Failed Builds**: Check workflow logs for specific error messages
- **Missing Dependencies**: Ensure all required tools are installed in workflows
- **Permission Issues**: Verify GitHub token permissions for repository access
- **Platform-specific Issues**: Check matrix build results for OS-specific problems