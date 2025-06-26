# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2025-01-20

### 🎉 Major Release - Modernized WireGuard Installer

### Added
- **Modern OS Support (2022-2025)**
  - Ubuntu 22.04 LTS, 24.04 LTS, 24.10, 25.04
  - Debian 12 (Bookworm), 13 (Trixie)
  - Fedora 40, 41, 42
  - AlmaLinux 9.x, Rocky Linux 9.x, Oracle Linux 9.x
  - Alpine Linux 3.18, 3.19, 3.20
  - Amazon Linux 2023 (NEW!)
  - Arch Linux (rolling)

- **Container & Virtualization Support**
  - Docker containers detection and adaptation
  - LXC containers with userspace WireGuard fallback
  - OpenVZ containers with automatic boringtun integration
  - Automatic kernel module vs userspace implementation switching

- **Advanced Installation Features**
  - Interactive and non-interactive installation modes
  - Automatic OS detection and validation
  - QR code generation for mobile client setup
  - Enhanced error handling and logging with colored output
  - Comprehensive pre-flight checks and validation

- **Testing Infrastructure**
  - Comprehensive GitHub Actions CI/CD pipeline
  - Multi-OS testing matrix (9 distributions, 15+ versions)
  - Static code analysis with ShellCheck and shfmt
  - Security scanning and vulnerability checks
  - Unit tests and integration testing
  - Functional testing across all supported OS

- **Developer Experience**
  - Modern bash practices and code formatting
  - Comprehensive documentation and guides
  - Development status tracking
  - Test helpers and utilities
  - Debug mode and troubleshooting tools

### Changed
- **Script Renamed**: `wireguard-install.sh` → `installer.sh` for clarity
- **Architecture**: Complete rewrite with modular, testable functions
- **Error Handling**: Enhanced with proper exit codes and user feedback
- **Logging**: Structured logging with debug capabilities
- **Configuration**: Environment variable support for automation

### Improved
- **Code Quality**: ShellCheck compliant (only 1 info warning)
- **Security**: Enhanced security checks and safe defaults
- **Performance**: Optimized package detection and installation
- **Reliability**: Comprehensive testing and validation
- **Maintainability**: Clean, documented, and modular code structure

### Technical Details
- **Lines of Code**: 750+ well-structured lines
- **Functions**: 25+ modular functions
- **Test Coverage**: Comprehensive test suite with multiple scenarios
- **Documentation**: Complete README, development guides, and API docs

### Supported Environments
- **Physical Servers**: Full support with kernel modules
- **Virtual Machines**: Complete compatibility
- **Docker Containers**: Automatic adaptation
- **LXC Containers**: Userspace WireGuard support
- **OpenVZ/VPS**: Boringtun userspace implementation

### CI/CD Pipeline
- **Linting**: ShellCheck, shfmt, syntax validation
- **Security**: Vulnerability scanning, credential detection
- **Testing**: Multi-OS functional testing
- **Integration**: End-to-end testing and validation
- **Deployment**: Release readiness checks

---

## Development Workflow

This version introduces a comprehensive development workflow:

1. **Code Quality Gates**: All code must pass linting and security checks
2. **Multi-OS Testing**: Functional testing across 9+ distributions  
3. **Automated CI/CD**: GitHub Actions pipeline for every PR and push
4. **Documentation**: Complete guides for users and developers
5. **Release Management**: Automated release readiness validation

## Migration Guide

If you're upgrading from a previous version:

1. **Script Name**: Update any automation to use `installer.sh` instead of `wireguard-install.sh`
2. **Environment Variables**: New variables available for non-interactive installation
3. **Container Support**: Automatic detection - no changes needed
4. **Configuration**: Same config file locations and formats

## Compatibility

- **Backward Compatible**: Existing WireGuard configurations continue to work
- **Forward Compatible**: Designed for future OS releases
- **Container Ready**: Works in modern containerized environments
- **Cloud Native**: Suitable for infrastructure-as-code deployments

---

**Full Changelog**: [View on GitHub](https://github.com/HarunRRayhan/wireguard-server/compare/main...research) 