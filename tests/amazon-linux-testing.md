# Amazon Linux Testing Guide

This document outlines how to test the WireGuard installation script on Amazon Linux using Docker containers from the [official Amazon Linux Docker repository](https://hub.docker.com/_/amazonlinux).

## Available Amazon Linux Versions

Based on the [Amazon Linux Docker Hub repository](https://hub.docker.com/_/amazonlinux), the following versions are available for testing:

### Amazon Linux 2023 (Recommended)
- **Docker Image**: `amazonlinux:2023`
- **Package Manager**: `dnf`
- **Architecture**: x86_64, arm64
- **Status**: Current, actively supported
- **WireGuard Support**: Native kernel module support

### Amazon Linux 2
- **Docker Image**: `amazonlinux:2`
- **Package Manager**: `yum`
- **Architecture**: x86_64, arm64
- **Status**: Legacy support until June 2025
- **WireGuard Support**: Requires EPEL or manual compilation

### Amazon Linux Latest
- **Docker Image**: `amazonlinux:latest`
- **Package Manager**: `dnf` (currently points to AL2023)
- **Architecture**: x86_64, arm64
- **Status**: Current (aliases to latest stable)

## Testing Strategy

### 1. Automated GitHub Actions Testing

Our CI/CD pipeline tests all Amazon Linux versions using Docker containers to avoid GLIBC compatibility issues:

```yaml
strategy:
  matrix:
    include:
      - os: "amazonlinux:2023"
        name: "Amazon Linux 2023"
        package_manager: "dnf"
        expected_version: "2023"
      - os: "amazonlinux:2"
        name: "Amazon Linux 2"
        package_manager: "yum"
        expected_version: "2"
      - os: "amazonlinux:latest"
        name: "Amazon Linux Latest"
        package_manager: "dnf"
        expected_version: "2023"
```

**Note**: Amazon Linux 2 has older GLIBC versions (< 2.27) that are incompatible with modern GitHub Actions runners. We now run tests in Docker containers and upload artifacts from the runner to avoid this issue.

### 2. Local Testing Commands

#### Test Amazon Linux 2023
```bash
docker run --rm -it --privileged --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v $(pwd):/workspace -w /workspace \
  amazonlinux:2023 \
  bash -c "
    dnf update -y && \
    dnf install -y curl wget iproute iptables kmod systemd procfs-ng ca-certificates && \
    chmod +x installer.sh && \
    export DEBUG=true WIREGUARD_TEST_MODE=true && \
    ./installer.sh
  "
```

#### Test Amazon Linux 2
```bash
docker run --rm -it --privileged --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v $(pwd):/workspace -w /workspace \
  amazonlinux:2 \
  bash -c "
    yum update -y && \
    yum install -y curl wget iproute iptables kmod systemd procfs ca-certificates && \
    chmod +x installer.sh && \
    export DEBUG=true WIREGUARD_TEST_MODE=true && \
    ./installer.sh
  "
```

### 3. Amazon Linux Specific Considerations

#### Package Repositories
- **AL2023**: Uses dnf and has WireGuard packages in the main repository
- **AL2**: Uses yum and may require EPEL for WireGuard packages

#### Kernel Module Support
- **AL2023**: Full kernel module support for WireGuard
- **AL2**: May require userspace implementation (BoringTun) in some configurations

#### systemd Integration
Both versions support systemd, which is essential for WireGuard service management.

### 4. Test Coverage

Our Amazon Linux tests verify:

1. **OS Detection**: Correctly identifies Amazon Linux version
2. **Package Manager**: Proper dnf/yum functionality
3. **Dependencies**: Installation of required system packages
4. **WireGuard Installation**: Successful WireGuard setup
5. **Service Management**: systemd service configuration
6. **Network Configuration**: iptables and routing setup
7. **Container Compatibility**: Proper detection of container environment

### 5. Expected Test Results

#### Amazon Linux 2023
- ✅ Native WireGuard kernel module
- ✅ dnf package manager
- ✅ Full systemd support
- ✅ Modern iptables support

#### Amazon Linux 2
- ⚠️ May require userspace WireGuard (BoringTun)
- ✅ yum package manager
- ✅ systemd support
- ✅ iptables support

### 6. Troubleshooting

#### Common Issues

1. **WireGuard Module Not Available**
   - AL2023: Should work out of the box
   - AL2: May need to enable EPEL repository

2. **Container Environment**
   - All versions automatically detect container environment
   - Falls back to userspace implementation when needed

3. **Package Installation Failures**
   - Ensure proper repository configuration
   - Check network connectivity within container

4. **GLIBC Compatibility Issues in CI/CD**
   - Amazon Linux 2 has GLIBC < 2.27, incompatible with modern Node.js
   - Symptoms: `GLIBC_2.27' not found`, `GLIBC_2.28' not found`
   - Solution: Run tests in Docker containers, not as container jobs
   - Upload artifacts from the runner, not from within the container

#### Debug Commands

```bash
# Check OS version
cat /etc/os-release

# Check package manager
which dnf yum
dnf --version || yum --version

# Check WireGuard availability
modinfo wireguard
dnf list available | grep wireguard  # AL2023
yum list available | grep wireguard  # AL2

# Check systemd
systemctl --version

# Check network tools
ip --version
iptables --version
```

### 7. Performance Benchmarks

Expected installation times (in CI environment):
- Amazon Linux 2023: ~60-90 seconds
- Amazon Linux 2: ~90-120 seconds
- Amazon Linux Latest: ~60-90 seconds

### 8. Security Considerations

All Amazon Linux versions are tested with:
- Privileged container mode (required for network configuration)
- NET_ADMIN and NET_RAW capabilities
- Standard security scanning for the installation script

### 9. Future Considerations

- Monitor for new Amazon Linux releases
- Test compatibility with AWS-specific tools
- Validate performance in actual EC2 environments
- Consider ARM64 architecture testing

## References

- [Amazon Linux Docker Hub](https://hub.docker.com/_/amazonlinux)
- [Amazon Linux 2023 User Guide](https://docs.aws.amazon.com/linux/al2023/)
- [Amazon Linux 2 User Guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-linux-2-virtual-machine.html)
- [WireGuard Installation Guide](https://www.wireguard.com/install/) 