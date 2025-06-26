# WireGuard Script Testing Infrastructure

This directory contains a comprehensive testing suite for the WireGuard installation script, designed to validate functionality across multiple Linux distributions released from 2022-2025.

## Overview

The testing infrastructure consists of:

- **GitHub Actions Workflows**: Automated testing across 15+ OS versions
- **Test Helper Library**: Reusable functions for validation
- **Test Runner**: Main orchestration script
- **Multi-OS Support**: Ubuntu, Debian, RHEL-based, Fedora, Alpine, Amazon Linux, Arch

## Quick Start

### Local Testing

```bash
# Run full test suite
sudo ./tests/run-tests.sh

# Run quick tests only
sudo TEST_MODE=quick ./tests/run-tests.sh

# Run installation test only
sudo TEST_MODE=installation ./tests/run-tests.sh

# Skip cleanup (for debugging)
sudo SKIP_CLEANUP=true ./tests/run-tests.sh
```

### Docker Testing

```bash
# Test on Ubuntu 24.04
docker run --rm --privileged \
  -v $(pwd):/workspace \
  -w /workspace \
  ubuntu:24.04 \
  bash -c "apt-get update && apt-get install -y curl && ./tests/run-tests.sh"

# Test on AlmaLinux 9
docker run --rm --privileged \
  -v $(pwd):/workspace \
  -w /workspace \
  almalinux:9 \
  bash -c "dnf install -y curl && ./tests/run-tests.sh"
```

## Supported Operating Systems

### Currently Tested (2022-2025 Releases)

| Distribution | Versions | Package Manager | Init System | Status |
|--------------|----------|-----------------|-------------|--------|
| Ubuntu | 22.04, 24.04, 24.10 | apt | systemd | ✅ Full Support |
| Debian | 12, 13 (testing) | apt | systemd | ✅ Full Support |
| AlmaLinux | 9.x | dnf | systemd | ✅ Full Support |
| Rocky Linux | 9.x | dnf | systemd | ✅ Full Support |
| Oracle Linux | 9.x | dnf | systemd | ✅ Full Support |
| Fedora | 40, 41, 42 | dnf | systemd | ✅ Full Support |
| Alpine | 3.18, 3.19, 3.20 | apk | openrc | ✅ Full Support |
| Amazon Linux | 2023 | dnf | systemd | ✅ Full Support |
| Arch Linux | Latest | pacman | systemd | ✅ Full Support |

## Test Scenarios

### 1. Installation Tests
- **Fresh Installation**: Clean WireGuard setup
- **OS Detection**: Verify correct OS identification
- **Package Installation**: Validate WireGuard packages
- **Service Setup**: Systemd service configuration

### 2. Configuration Tests
- **Server Config**: Validate `/etc/wireguard/wg0.conf`
- **Client Config**: Check generated client configurations
- **Key Generation**: Verify cryptographic keys
- **File Permissions**: Security validation (600 permissions)

### 3. Network Tests
- **Interface Creation**: WireGuard network interface
- **IP Forwarding**: Kernel parameter configuration
- **Firewall Rules**: iptables/nftables validation
- **NAT Configuration**: Masquerading setup

### 4. Service Management Tests
- **Service Enable**: Systemd service enablement
- **Service Start**: WireGuard service startup
- **Service Status**: Health check validation
- **Boot Configuration**: Startup on boot

### 5. Security Tests
- **File Permissions**: Configuration file security
- **Key Security**: Private key protection
- **Process Validation**: Service security
- **Network Security**: Interface isolation

## GitHub Actions Integration

The testing infrastructure integrates with GitHub Actions to provide:

### Automated Testing Matrix
- **15+ OS Versions**: Complete coverage of 2022-2025 releases
- **Container-based**: Privileged containers with NET_ADMIN capability
- **Parallel Execution**: Fast test completion
- **Failure Isolation**: Individual OS test failure isolation

### CI/CD Pipeline
```yaml
# Triggers
- Push to main/develop branches
- Pull requests
- Weekly scheduled runs

# Test Stages
1. Static Analysis (ShellCheck, syntax)
2. Security Scanning
3. Multi-OS Functional Testing
4. Integration Testing
5. Test Result Aggregation
```

### Test Artifacts
- Individual test reports per OS
- Aggregated compatibility matrix
- Failed test logs and debugging info
- Performance benchmarks

## Test Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TEST_MODE` | `full` | Test mode: full, quick, installation, validation |
| `SKIP_CLEANUP` | `false` | Skip cleanup after tests |
| `DEBUG` | `false` | Enable verbose debugging output |
| `AUTO_INSTALL` | `y` | Non-interactive installation mode |
| `WIREGUARD_TEST_MODE` | `true` | Enable test-specific behaviors |

### Test Modes

#### Full Test Suite (`full`)
- Complete validation of all functionality
- Installation, configuration, network, security
- Recommended for release validation
- Duration: ~5-10 minutes per OS

#### Quick Tests (`quick`)
- Essential functionality only
- Installation and basic validation
- Good for development workflow
- Duration: ~2-3 minutes per OS

#### Installation Only (`installation`)
- Just test the installation process
- Verify packages and basic setup
- Useful for OS compatibility testing
- Duration: ~1-2 minutes per OS

#### Validation Only (`validation`)
- Assumes WireGuard already installed
- Test configuration and functionality
- Good for post-installation validation
- Duration: ~1-2 minutes per OS

## Adding New Tests

### 1. Create Test Function
```bash
test_my_feature() {
    test_start "My Feature Test"
    
    # Test implementation
    if validate_my_feature; then
        log_info "Feature working correctly"
        test_pass
    else
        test_fail "Feature validation failed"
        return 1
    fi
}
```

### 2. Add to Test Suite
```bash
# In run-tests.sh, add to run_full_test_suite()
test_my_feature
```

### 3. Update GitHub Actions
```yaml
# Add to .github/workflows/comprehensive-testing.yml
- name: Test My Feature
  run: |
    echo "Testing my feature..."
    # Test commands here
```

## Adding New Operating Systems

### 1. Update GitHub Actions Matrix
```yaml
# Add to .github/workflows/comprehensive-testing.yml
- os: "newdistro:version"
  name: "New Distribution Version"
  package_manager: "pkg_mgr"
  init: "init_system"
```

### 2. Update Test Helpers
```bash
# Add package manager support in test-helpers.sh
elif [[ "${{ matrix.package_manager }}" == "new_pkg_mgr" ]]; then
    new_pkg_mgr install -y curl wget iproute2 iptables
```

### 3. Test Locally
```bash
# Test the new OS
docker run --rm --privileged \
  -v $(pwd):/workspace \
  -w /workspace \
  newdistro:version \
  ./tests/run-tests.sh
```

## Troubleshooting

### Common Issues

#### Container Privileges
```bash
# Error: Operation not permitted
# Solution: Use --privileged flag
docker run --privileged --cap-add=NET_ADMIN --cap-add=NET_RAW
```

#### Service Start Failures
```bash
# Error: Failed to start service
# This is expected in containers - services may not start but should be configured
```

#### Network Interface Issues
```bash
# Error: Cannot create WireGuard interface
# Expected in some container environments - test focuses on configuration
```

### Debug Mode
```bash
# Enable detailed debugging
DEBUG=true ./tests/run-tests.sh

# Skip cleanup to inspect state
SKIP_CLEANUP=true ./tests/run-tests.sh
```

### Manual Testing
```bash
# Test specific components
source tests/test-helpers.sh
validate_test_environment
test_wireguard_installation
```

## Performance Benchmarks

| Test Suite | Duration (avg) | OS Coverage |
|------------|----------------|-------------|
| Full | 8 minutes | 15+ OSes |
| Quick | 3 minutes | 15+ OSes |
| Installation | 2 minutes | 15+ OSes |
| Validation | 1 minute | 15+ OSes |

## Contributing

### Test Development Guidelines
1. Use the test framework functions (`test_start`, `test_pass`, `test_fail`)
2. Include proper error messages and debugging info
3. Handle container environment limitations gracefully
4. Add documentation for new test scenarios
5. Update the GitHub Actions matrix for new OS support

### Submitting Changes
1. Test locally across multiple distributions
2. Ensure all existing tests still pass
3. Add tests for new functionality
4. Update documentation
5. Submit PR with test results

## Security Considerations

### Privileged Containers
Tests run in privileged containers to:
- Create network interfaces
- Modify iptables rules
- Access kernel modules
- Configure system services

### Test Isolation
- Each test run starts with a clean environment
- Tests clean up after themselves
- No persistence between test runs
- Isolated network namespaces

### Sensitive Data
- No real private keys used in tests
- Test configurations use dummy values
- No network traffic leaves test environment
- All test data is ephemeral

## License

This testing infrastructure is part of the WireGuard installation script modernization project and follows the same MIT license as the original script. 