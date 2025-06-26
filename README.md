# WireGuard VPN Server Installer

A modernized, user-friendly WireGuard VPN installation script with comprehensive support for modern Linux distributions, client management, and NO initial sudo requirement.

## Features

✅ **Modern OS Support (2022-2025)**
- Ubuntu 22.04 LTS, 24.04 LTS, 24.10, 25.04
- Debian 12 (Bookworm), 13 (Trixie)
- Fedora 40, 41, 42
- AlmaLinux 9.x, Rocky Linux 9.x, Oracle Linux 9.x
- Alpine Linux 3.18+
- Amazon Linux 2023
- Arch Linux (rolling)

✅ **Container & Virtualization Support**
- Docker containers
- LXC containers
- OpenVZ containers (with userspace WireGuard)
- Automatic detection and adaptation

✅ **Advanced Features**
- **No initial sudo requirement** - Only requests privileges when needed
- **Post-installation client management** - Add/remove/list clients easily
- **Multiple DNS providers** - Cloudflare, Quad9, Google, OpenDNS, or custom
- **Configuration backup/restore** - Secure backup and restore functionality
- **IP address tracking** - Prevents client IP conflicts
- **QR code generation** - Easy mobile client setup
- **IPv6 ready** - Dual-stack support detection
- Userspace WireGuard implementation (boringtun) for containers
- Comprehensive error handling and logging
- Interactive and non-interactive modes

✅ **Security Features**
- Delayed privilege escalation - runs without root until needed
- Automatic client IP allocation tracking
- Secure file permissions and key storage
- DNS-over-TLS ready configuration

✅ **Testing Infrastructure**
- GitHub Actions CI/CD
- Multi-OS testing matrix
- Static code analysis (ShellCheck, shfmt)
- Functional testing across distributions

## Quick Start

### Installation

```bash
# Download and run the script (NO sudo required initially!)
curl -O https://raw.githubusercontent.com/HarunRRayhan/wireguard-server/main/installer.sh
chmod +x installer.sh
./installer.sh
```

### Requirements

- Modern Linux distribution (see supported OS list above)
- Internet connection
- Administrative privileges (requested when needed)

The script will automatically:
1. Detect your operating system and requirements
2. Ask for configuration preferences (IP, port, DNS provider)
3. Request admin privileges only when needed for installation
4. Install WireGuard and dependencies
5. Configure the VPN server with selected DNS provider
6. Generate client configuration with QR code

### Client Management

After installation, you can easily manage clients:

```bash
# Add a new client
./installer.sh --add-client laptop

# List all clients
./installer.sh --list-clients

# Show QR code for a client
./installer.sh --show-qr laptop

# Remove a client
./installer.sh --remove-client laptop

# Backup configuration
./installer.sh --backup

# Restore from backup
./installer.sh --restore /path/to/backup.tar.gz
```

### Interactive Mode

```bash
./installer.sh
```

The script will prompt you for:
- Server public IP (auto-detected)
- WireGuard port (default: 51820)
- DNS provider (Cloudflare, Quad9, Google, OpenDNS, or custom)
- First client name (default: client1)

### Non-Interactive Mode

```bash
# Set environment variables for automated installation
export WG_SERVER_IP="203.0.113.123"
export WG_PORT="51820"
export CLIENT_NAME="laptop"
export DNS_PROVIDER="1.1.1.1, 1.0.0.1"
export WIREGUARD_TEST_MODE="true"

./installer.sh
```

## Development

### Running Tests

```bash
# Run all tests (will request sudo when needed)
./tests/run-tests.sh

# Run quick tests only
TEST_MODE=quick ./tests/run-tests.sh

# Run specific test category
TEST_MODE=installation ./tests/run-tests.sh
```

### Static Analysis

```bash
# Check script syntax and style
shellcheck installer.sh
shfmt -d installer.sh
```

### Docker Testing

```bash
# Test on Ubuntu 24.04
docker run --rm -it --privileged ubuntu:24.04 bash
# Inside container:
curl -O https://raw.githubusercontent.com/HarunRRayhan/wireguard-server/main/installer.sh
chmod +x installer.sh
WIREGUARD_TEST_MODE=true WG_SERVER_IP="127.0.0.1" ./installer.sh
```

## Supported Operating Systems

| Distribution | Versions | Package Manager | Status |
|-------------|----------|----------------|---------|
| Ubuntu | 22.04 LTS, 24.04 LTS, 24.10, 25.04 | apt | ✅ Full Support |
| Debian | 12 (Bookworm), 13 (Trixie) | apt | ✅ Full Support |
| Fedora | 40, 41, 42 | dnf | ✅ Full Support |
| AlmaLinux | 9.0, 9.1, 9.2, 9.3, 9.4 | dnf | ✅ Full Support |
| Rocky Linux | 9.0, 9.1, 9.2, 9.3, 9.4 | dnf | ✅ Full Support |
| Oracle Linux | 9.x | dnf | ✅ Full Support |
| Alpine Linux | 3.18, 3.19, 3.20 | apk | ✅ Full Support |
| Amazon Linux | 2023 | dnf | ✅ Full Support |
| Arch Linux | rolling | pacman | ✅ Full Support |

### Legacy Support

| Distribution | Versions | Status |
|-------------|----------|---------|
| Ubuntu | 20.04 LTS, 18.04 LTS | ⚠️ Legacy |
| Debian | 11 (Bullseye) | ⚠️ Legacy |
| Fedora | 37, 38, 39 | ⚠️ End of Life |
| RHEL-based | 8.x series | ⚠️ Legacy |
| Alpine | 3.17 | ⚠️ End of Life |
| Amazon Linux | 2 | ⚠️ Legacy |

## Container Support

The script automatically detects container environments and adapts accordingly:

- **Docker**: Standard installation with some adaptations
- **LXC**: Uses userspace WireGuard if kernel modules unavailable
- **OpenVZ**: Automatically switches to userspace implementation (boringtun)

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WG_SERVER_IP` | Server public IP address | Auto-detected |
| `WG_PORT` | WireGuard port | 51820 |
| `CLIENT_NAME` | First client name | client1 |
| `WIREGUARD_TEST_MODE` | Enable test mode | false |
| `DEBUG` | Enable debug logging | false |

### Files Created

```
/etc/wireguard/
├── wg0.conf                    # Server configuration
├── server_private.key          # Server private key
├── server_public.key           # Server public key
├── client_private.key          # Client private key
└── client_public.key           # Client public key

$HOME/
├── client1.conf                # Client configuration
└── client1.png                 # QR code (if qrencode available)
```

## Troubleshooting

### Common Issues

1. **Permission denied**: The script will request admin privileges when needed
2. **Unsupported OS**: Check supported OS list above
3. **Container issues**: Script will automatically use userspace WireGuard
4. **Network issues**: Check firewall and port availability
5. **Client IP conflicts**: Use `./installer.sh --list-clients` to see IP allocations

### Debug Mode

```bash
DEBUG=true ./installer.sh
```

### Container Testing

For testing in containers without full privileges:

```bash
WIREGUARD_TEST_MODE=true WG_SERVER_IP="127.0.0.1" ./installer.sh
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./tests/run-tests.sh`
5. Submit a pull request

### Code Style

- Follow existing bash style
- Use ShellCheck for linting
- Add tests for new features
- Update documentation

## CI/CD

The repository includes comprehensive GitHub Actions workflows:

- **Static Analysis**: ShellCheck, shfmt
- **Multi-OS Testing**: Ubuntu, Debian, Fedora, Alpine, Rocky, etc.
- **Container Testing**: Docker-based testing
- **Security Scanning**: Script security analysis

## License

MIT License - see LICENSE file for details.

## Security

- All keys are generated locally
- Proper file permissions (600 for private keys)
- Secure default configuration
- Regular security updates

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review existing GitHub issues
3. Create a new issue with detailed information

## What's New in v3.0

🎉 **Major improvements over traditional WireGuard installers:**

- **No more sudo upfront!** - Run as regular user, admin privileges requested only when needed
- **Post-installation client management** - Add/remove clients without reinstalling
- **Smart DNS selection** - Choose from Cloudflare, Quad9, Google, OpenDNS, or custom
- **Configuration backup/restore** - Secure backup and recovery functionality
- **Improved security** - Better privilege separation and file permissions
- **Better user experience** - Clear progress indicators and helpful error messages
- **Command-line interface** - Use flags for automation and scripting

---

**Note**: This is a modernized version focused on current (2022-2025) operating system releases with enhanced security, usability, and client management features.
