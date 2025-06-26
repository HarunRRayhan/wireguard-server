# WireGuard Install Script Modernization Plan

## Overview

Modernization plan for a popular WireGuard installation bash script to support newer OS versions, add comprehensive testing, and improve reliability while maintaining the simple single-script approach that has made it widely adopted in the community.

## Current Issues to Address

### 1. Missing Support for Newer OS Versions (2022-2025)
- **Ubuntu**: 22.04 LTS (Jammy), 24.04 LTS (Noble), 24.10 (Oracular), 25.04 (Plucky)
- **Debian**: 12 (Bookworm) - released June 2023, 13 (Trixie) - in testing
- **Rocky Linux**: 9.0, 9.1, 9.2, 9.3, 9.4 - released 2022-2024  
- **AlmaLinux**: 9.0, 9.1, 9.2, 9.3, 9.4 - released 2022-2024
- **Fedora**: 37 (2022), 38 (2023), 39 (2023), 40 (2024), 41 (2024), 42 (2025)
- **Alpine Linux**: 3.17 (2022), 3.18 (2023), 3.19 (2023), 3.20 (2024)
- **Amazon Linux**: AL2023 - released March 2023
- **Oracle Linux**: 9.x series

### 2. Container/Virtualization Issues
- OpenVZ containers not supported (fails immediately)
- No userspace WireGuard support for environments without kernel modules
- Missing boringtun integration for LXC/Docker environments

### 3. Testing & Quality Issues
- Only basic shellcheck/shfmt formatting in GitHub Actions
- No functional testing of actual VPN installation/operation
- Installation failures discovered by users, not CI
- No testing across different OS versions

### 4. Modern DevOps Gaps
- No non-interactive installation mode
- Limited error handling and recovery
- No automated update mechanism
- No support for infrastructure-as-code deployments

## Modernization Goals

### ✅ Keep What Works
- Single bash script approach
- Interactive installation experience
- Simple download-and-run usage
- Cross-platform Linux support

### 🚀 Add Modern Capabilities
1. **Broader OS Support**: Latest Ubuntu, Debian, Rocky, Alma, Fedora
2. **Comprehensive Testing**: GitHub Actions matrix testing across all OS
3. **Container Support**: OpenVZ/LXC compatibility via userspace WireGuard
4. **Better Reliability**: Enhanced error handling, validation, rollback
5. **Automation-Friendly**: Non-interactive mode for CI/CD integration

## Implementation Plan

### Phase 1: OS Support Updates (Priority: High)

#### 1.1 Update OS Detection Logic
```bash
# Add support for newer versions
case ${ID} in
    ubuntu)
        if [[ ${VERSION_ID} == "24.04" ]]; then
            # Ubuntu 24.04 Noble Numbat support
        fi
        ;;
    debian)
        if [[ ${VERSION_ID} == "12" ]] || [[ ${VERSION_ID} == "13" ]]; then
            # Debian 12/13 support
        fi
        ;;
    rocky|almalinux)
        if [[ ${VERSION_ID} =~ ^9 ]]; then
            # Rocky/Alma Linux 9 support
        fi
        ;;
esac
```

#### 1.2 Package Installation Updates
- Update package names for newer OS versions
- Handle repository changes and new package managers
- Add fallback mechanisms for missing packages
- Fix resolv.conf conflicts in newer Debian versions

#### 1.3 WireGuard Installation Methods
- Support for distribution-provided packages vs backports
- Handle kernel module vs userspace implementations
- Update repository URLs and GPG keys

### Phase 2: Container/Virtualization Support (Priority: High)

#### 2.1 Environment Detection
```bash
checkVirt() {
    if [[ -f /proc/user_beancounters ]]; then
        echo "OpenVZ detected"
        USE_USERSPACE=true
    elif [[ $(systemd-detect-virt) == "lxc" ]]; then
        echo "LXC container detected"
        USE_USERSPACE=true
    fi
}
```

#### 2.2 Userspace WireGuard (boringtun) Integration
```bash
installUserspace() {
    # Install Rust/Cargo if needed
    # Install boringtun
    # Configure systemd service for userspace implementation
    # Set environment variables
}
```

#### 2.3 Systemd Service Configuration
```bash
# Add environment variables for userspace implementation
Environment=WG_QUICK_USERSPACE_IMPLEMENTATION=boringtun
Environment=WG_SUDO=1
```

### Phase 3: GitHub Actions Testing Matrix (Priority: High)

#### 3.1 Multi-OS Testing
```yaml
name: Test WireGuard Installation

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        os:
          - ubuntu:20.04
          - ubuntu:22.04
          - ubuntu:24.04
          - debian:11
          - debian:12
          - rockylinux:8
          - rockylinux:9
          - almalinux:8
          - almalinux:9
          - fedora:39
          - fedora:40
          - alpine:3.18
        test-type:
          - installation
          - client-generation
          - service-validation
          - cleanup
    
    container:
      image: ${{ matrix.os }}
      options: --privileged --cap-add=NET_ADMIN
```

#### 3.2 Test Scenarios
1. **Installation Test**: Script completes without errors
2. **Service Test**: WireGuard service starts successfully
3. **Client Generation**: Client configs created correctly
4. **Basic Connectivity**: Tunnel interface comes up
5. **Cleanup Test**: Uninstall removes all components

#### 3.3 Automated Testing Scripts
```bash
# test-installation.sh
test_installation() {
    # Non-interactive installation
    # Validate WireGuard is installed
    # Check service status
    # Verify config files
}

# test-client-generation.sh
test_client_generation() {
    # Generate test client
    # Validate config format
    # Check QR code generation
}
```

### Phase 4: Enhanced Error Handling (Priority: Medium)

#### 4.1 Pre-flight Validation
```bash
preflight_check() {
    check_root_privileges
    check_network_interfaces
    check_required_ports
    check_dependencies
    check_virtualization_support
}
```

#### 4.2 Rollback/Recovery
```bash
cleanup_on_failure() {
    remove_partial_installation
    restore_network_config
    cleanup_temp_files
    display_troubleshooting_info
}
```

#### 4.3 Better Error Messages
- Specific error codes for different failure types
- Troubleshooting hints for common issues
- Links to documentation and community resources

### Phase 5: Modern Features (Priority: Low)

#### 5.1 Non-Interactive Mode
```bash
# Environment variable configuration
export WG_AUTO_INSTALL=true
export WG_SERVER_IP="auto"
export WG_PORT="51820"
export WG_CLIENT_NAME="client1"
./wireguard-install.sh
```

#### 5.2 Configuration Templates
```bash
# Support for pre-defined configurations
./wireguard-install.sh --config=server-config.env
```

## Testing Strategy

### Local Testing
- Docker containers for each supported OS
- Manual testing on VPS providers (DigitalOcean, Vultr, Hetzner)
- OpenVZ container testing

### CI/CD Testing
- GitHub Actions matrix across all OS versions
- Privileged containers for network testing
- Automated reporting of test results
- Performance benchmarking

### Community Testing
- Beta releases with pre-release tags
- Issue templates for testing feedback
- Documentation for testing procedures

## Success Metrics

### Immediate Goals (1-2 months)
- [ ] Support for Ubuntu 24.04, Debian 12/13, Rocky 9, Alma 9, Fedora 40-41
- [ ] OpenVZ/LXC container support via boringtun
- [ ] GitHub Actions testing across 10+ OS versions
- [ ] 95%+ success rate in automated tests

### Long-term Goals (3-6 months)
- [ ] 50% reduction in OS-related GitHub issues
- [ ] Non-interactive installation mode
- [ ] Comprehensive troubleshooting documentation
- [ ] Community adoption of testing framework

## Risk Mitigation

### Technical Risks
- **Breaking changes in new OS**: Comprehensive testing matrix
- **Container limitations**: Userspace implementation fallback
- **Package dependency hell**: Multiple installation methods

### Project Risks
- **Complexity increase**: Maintain single-script architecture
- **Community resistance**: Backward compatibility guarantee
- **Maintenance burden**: Automated testing reduces manual effort

## Next Steps

1. **Week 1-2**: Update OS support for Ubuntu 24.04, Debian 12/13
2. **Week 2-3**: Implement OpenVZ/boringtun support
3. **Week 3-4**: Create GitHub Actions testing matrix
4. **Week 4-5**: Enhanced error handling and validation
5. **Week 5-6**: Documentation and community testing

This modernization maintains the simplicity that made the script successful while adding the reliability and broad compatibility needed for 2024 and beyond. 