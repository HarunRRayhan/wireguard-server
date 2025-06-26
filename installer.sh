#!/bin/bash

# WireGuard VPN installer for Linux servers
# Modernized version with support for 2022-2025 OS releases
# https://github.com/HarunRRayhan/wireguard-server

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_VERSION="2.0.0"
WG_CONFIG_FILE="/etc/wireguard/wg0.conf"
WG_INTERFACE="wg0"
WG_PORT=""
WG_SERVER_IP=""
USE_USERSPACE=false
BORINGTUN_INSTALLED=false

# Logging functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
  if [[ "${DEBUG:-false}" == "true" ]]; then
    echo -e "${BLUE}[DEBUG]${NC} $1"
  fi
}

# Check if running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
  fi
}

# Detect operating system and version
detect_os() {
  local os_id=""
  local os_version=""
  local os_name=""

  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/etc/os-release
    source /etc/os-release
    os_id="$ID"
    os_version="$VERSION_ID"
    os_name="$PRETTY_NAME"
  else
    log_error "Cannot detect operating system. /etc/os-release not found."
    exit 1
  fi

  log_debug "Detected OS: $os_name"

  case "$os_id" in
    ubuntu)
      detect_ubuntu_version "$os_version"
      ;;
    debian)
      detect_debian_version "$os_version"
      ;;
    fedora)
      detect_fedora_version "$os_version"
      ;;
    almalinux | rocky | ol)
      detect_rhel_version "$os_id" "$os_version"
      ;;
    alpine)
      detect_alpine_version "$os_version"
      ;;
    amzn)
      detect_amazon_linux_version "$os_version"
      ;;
    arch)
      detect_arch_version
      ;;
    *)
      log_error "Unsupported operating system: $os_name"
      log_error "Supported OS: Ubuntu 22.04+, Debian 12+, Fedora 40+, AlmaLinux 9+, Rocky 9+, Oracle 9+, Alpine 3.18+, Amazon Linux 2023, Arch Linux"
      exit 1
      ;;
  esac
}

# Ubuntu version detection and validation
detect_ubuntu_version() {
  local version="$1"
  local major_version="${version%%.*}"

  case "$version" in
    22.04 | 24.04 | 24.10 | 25.04)
      OS="ubuntu"
      OS_VERSION="$version"
      PACKAGE_MANAGER="apt"
      log_info "Ubuntu $version detected - Supported ✓"
      ;;
    20.04 | 18.04)
      OS="ubuntu"
      OS_VERSION="$version"
      PACKAGE_MANAGER="apt"
      log_warn "Ubuntu $version detected - Legacy support, consider upgrading"
      ;;
    *)
      log_error "Ubuntu $version is not supported"
      log_error "Supported Ubuntu versions: 22.04 LTS, 24.04 LTS, 24.10, 25.04"
      exit 1
      ;;
  esac
}

# Debian version detection and validation
detect_debian_version() {
  local version="$1"

  case "$version" in
    12)
      OS="debian"
      OS_VERSION="12"
      PACKAGE_MANAGER="apt"
      log_info "Debian 12 (Bookworm) detected - Supported ✓"
      ;;
    13)
      OS="debian"
      OS_VERSION="13"
      PACKAGE_MANAGER="apt"
      log_info "Debian 13 (Trixie) detected - Supported ✓"
      ;;
    11)
      OS="debian"
      OS_VERSION="11"
      PACKAGE_MANAGER="apt"
      log_warn "Debian 11 (Bullseye) detected - Legacy support, consider upgrading"
      ;;
    *)
      log_error "Debian $version is not supported"
      log_error "Supported Debian versions: 12 (Bookworm), 13 (Trixie)"
      exit 1
      ;;
  esac
}

# Fedora version detection and validation
detect_fedora_version() {
  local version="$1"

  case "$version" in
    40 | 41 | 42)
      OS="fedora"
      OS_VERSION="$version"
      PACKAGE_MANAGER="dnf"
      log_info "Fedora $version detected - Supported ✓"
      ;;
    37 | 38 | 39)
      OS="fedora"
      OS_VERSION="$version"
      PACKAGE_MANAGER="dnf"
      log_warn "Fedora $version detected - End of life, consider upgrading"
      ;;
    *)
      log_error "Fedora $version is not supported"
      log_error "Supported Fedora versions: 40, 41, 42"
      exit 1
      ;;
  esac
}

# RHEL-based distributions (AlmaLinux, Rocky, Oracle)
detect_rhel_version() {
  local os_id="$1"
  local version="$2"
  local major_version="${version%%.*}"

  case "$major_version" in
    9)
      OS="$os_id"
      OS_VERSION="$version"
      PACKAGE_MANAGER="dnf"
      case "$os_id" in
        almalinux)
          log_info "AlmaLinux $version detected - Supported ✓"
          ;;
        rocky)
          log_info "Rocky Linux $version detected - Supported ✓"
          ;;
        ol)
          log_info "Oracle Linux $version detected - Supported ✓"
          ;;
      esac
      ;;
    8)
      OS="$os_id"
      OS_VERSION="$version"
      PACKAGE_MANAGER="dnf"
      log_warn "RHEL 8-based distribution detected - Legacy support, consider upgrading to version 9"
      ;;
    *)
      log_error "RHEL-based distribution version $version is not supported"
      log_error "Supported versions: 9.x series (AlmaLinux, Rocky Linux, Oracle Linux)"
      exit 1
      ;;
  esac
}

# Alpine version detection and validation
detect_alpine_version() {
  local version="$1"
  local major_minor_version="${version%.*}" # Extract major.minor (e.g., "3.19.7" -> "3.19")

  case "$major_minor_version" in
    3.18 | 3.19 | 3.20)
      OS="alpine"
      OS_VERSION="$major_minor_version"
      PACKAGE_MANAGER="apk"
      log_info "Alpine Linux $major_minor_version detected - Supported ✓"
      ;;
    3.17)
      OS="alpine"
      OS_VERSION="$major_minor_version"
      PACKAGE_MANAGER="apk"
      log_warn "Alpine Linux $major_minor_version detected - End of life, consider upgrading"
      ;;
    *)
      log_error "Alpine Linux $version is not supported"
      log_error "Supported Alpine versions: 3.18, 3.19, 3.20"
      exit 1
      ;;
  esac
}

# Amazon Linux version detection and validation
detect_amazon_linux_version() {
  local version="$1"

  case "$version" in
    2023)
      OS="amzn"
      OS_VERSION="2023"
      PACKAGE_MANAGER="dnf"
      log_info "Amazon Linux 2023 detected - Supported ✓"
      ;;
    2)
      OS="amzn"
      OS_VERSION="2"
      PACKAGE_MANAGER="yum"
      log_warn "Amazon Linux 2 detected - Legacy support, consider upgrading to AL2023"
      ;;
    *)
      log_error "Amazon Linux $version is not supported"
      log_error "Supported Amazon Linux versions: 2023"
      exit 1
      ;;
  esac
}

# Arch Linux detection
detect_arch_version() {
  OS="arch"
  OS_VERSION="rolling"
  PACKAGE_MANAGER="pacman"
  log_info "Arch Linux detected - Supported ✓"
}

# Check for virtualization and container environments
check_virtualization() {
  local virt=""

  # Check for common container indicators
  if [[ -f /.dockerenv ]]; then
    log_warn "Docker container detected"
    return 0
  fi

  if [[ -f /proc/user_beancounters ]]; then
    log_warn "OpenVZ container detected - will use userspace WireGuard"
    USE_USERSPACE=true
    return 0
  fi

  # Use systemd-detect-virt if available
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    virt=$(systemd-detect-virt)
    case "$virt" in
      lxc | lxc-libvirt)
        log_warn "LXC container detected - will use userspace WireGuard"
        USE_USERSPACE=true
        ;;
      openvz)
        log_warn "OpenVZ container detected - will use userspace WireGuard"
        USE_USERSPACE=true
        ;;
      none)
        log_debug "No virtualization detected"
        ;;
      *)
        log_debug "Virtualization detected: $virt"
        ;;
    esac
  fi

  # Check for other container indicators
  if grep -q "container=" /proc/1/environ 2>/dev/null; then
    log_warn "Container environment detected"
  fi
}

# Check system requirements
check_requirements() {
  local missing_deps=()

  # Check for required commands
  local required_commands=("curl" "ip")
  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_deps+=("$cmd")
    fi
  done

  # Check for kernel support (if not using userspace)
  if [[ "$USE_USERSPACE" != "true" ]]; then
    if ! modinfo wireguard >/dev/null 2>&1; then
      log_warn "WireGuard kernel module not available, will attempt to install"
    fi
  fi

  # Install missing dependencies
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log_info "Installing missing dependencies: ${missing_deps[*]}"
    install_dependencies "${missing_deps[@]}"
  fi
}

# Install system dependencies
install_dependencies() {
  local deps=("$@")

  case "$PACKAGE_MANAGER" in
    apt)
      apt-get update
      apt-get install -y "${deps[@]}"
      ;;
    dnf)
      dnf install -y "${deps[@]}"
      ;;
    yum)
      yum install -y "${deps[@]}"
      ;;
    apk)
      apk update
      apk add "${deps[@]}"
      ;;
    pacman)
      pacman -Sy --noconfirm "${deps[@]}"
      ;;
  esac
}

# Install WireGuard
install_wireguard() {
  log_info "Installing WireGuard..."

  case "$OS" in
    ubuntu | debian)
      install_wireguard_debian
      ;;
    fedora)
      install_wireguard_fedora
      ;;
    almalinux | rocky | ol)
      install_wireguard_rhel
      ;;
    alpine)
      install_wireguard_alpine
      ;;
    amzn)
      install_wireguard_amazon
      ;;
    arch)
      install_wireguard_arch
      ;;
  esac

  # Install userspace implementation if needed
  if [[ "$USE_USERSPACE" == "true" ]]; then
    install_boringtun
  fi
}

# Install WireGuard on Debian/Ubuntu
install_wireguard_debian() {
  apt-get update

  case "$OS_VERSION" in
    22.04 | 24.04 | 24.10 | 25.04)
      # Ubuntu - WireGuard is in main repository
      apt-get install -y wireguard
      ;;
    12 | 13)
      # Debian - WireGuard is in main repository
      apt-get install -y wireguard
      ;;
    *)
      # Legacy versions
      apt-get install -y wireguard
      ;;
  esac

  # Install additional tools
  apt-get install -y qrencode iptables
}

# Install WireGuard on Fedora
install_wireguard_fedora() {
  dnf install -y wireguard-tools qrencode iptables
}

# Install WireGuard on RHEL-based distributions
install_wireguard_rhel() {
  # Enable EPEL repository for additional packages
  case "$OS" in
    almalinux | rocky)
      dnf install -y epel-release
      ;;
    ol)
      dnf install -y oracle-epel-release-el9
      ;;
  esac

  dnf install -y wireguard-tools qrencode iptables
}

# Install WireGuard on Alpine
install_wireguard_alpine() {
  apk add wireguard-tools qrencode iptables
}

# Install WireGuard on Amazon Linux
install_wireguard_amazon() {
  case "$OS_VERSION" in
    2023)
      dnf install -y wireguard-tools qrencode iptables
      ;;
    2)
      # Amazon Linux 2 requires EPEL
      amazon-linux-extras install epel -y
      yum install -y wireguard-tools qrencode iptables
      ;;
  esac
}

# Install WireGuard on Arch Linux
install_wireguard_arch() {
  pacman -Sy --noconfirm wireguard-tools qrencode iptables
}

# Install boringtun (userspace WireGuard implementation)
install_boringtun() {
  log_info "Installing boringtun (userspace WireGuard implementation)..."

  # Check if Rust/Cargo is available
  if ! command -v cargo >/dev/null 2>&1; then
    log_info "Installing Rust and Cargo..."
    case "$PACKAGE_MANAGER" in
      apt)
        apt-get install -y cargo
        ;;
      dnf | yum)
        $PACKAGE_MANAGER install -y cargo
        ;;
      apk)
        apk add cargo
        ;;
      pacman)
        pacman -S --noconfirm rust cargo
        ;;
    esac
  fi

  # Install boringtun
  cargo install boringtun --root /usr/local

  # Create systemd service for boringtun
  if command -v systemctl >/dev/null 2>&1; then
    create_boringtun_service
  fi

  BORINGTUN_INSTALLED=true
}

# Create systemd service for boringtun
create_boringtun_service() {
  cat >/etc/systemd/system/wg-quick@.service <<'EOF'
[Unit]
Description=WireGuard via wg-quick(8) for %I (boringtun)
After=network-online.target nss-lookup.target
Wants=network-online.target nss-lookup.target
PartOf=wg-quick.target
Documentation=man:wg-quick(8)
Documentation=man:wg(8)
Documentation=https://www.wireguard.com/
Documentation=https://www.wireguard.com/quickstart/
Documentation=https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8
Documentation=https://git.zx2c4.com/wireguard-tools/about/src/man/wg.8

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/wg-quick up %i
ExecStop=/usr/bin/wg-quick down %i
ExecReload=/bin/bash -c 'exec /usr/bin/wg-quick down %i; exec /usr/bin/wg-quick up %i'
Environment=WG_QUICK_USERSPACE_IMPLEMENTATION=/usr/local/bin/boringtun
Environment=WG_SUDO=1

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
}

# Get server public IP
get_server_ip() {
  local ip=""

  # Try multiple methods to get public IP
  for method in "ip route get 1.1.1.1" "curl -s https://ipv4.icanhazip.com" "curl -s https://api.ipify.org" "dig +short myip.opendns.com @resolver1.opendns.com"; do
    case "$method" in
      "ip route get"*)
        ip=$(ip route get 1.1.1.1 | awk 'NR==1 {print $(NF-2)}' 2>/dev/null)
        ;;
      "curl"*)
        ip=$(eval "$method" 2>/dev/null)
        ;;
      "dig"*)
        if command -v dig >/dev/null 2>&1; then
          ip=$(eval "$method" 2>/dev/null)
        fi
        ;;
    esac

    # Validate IP address
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      WG_SERVER_IP="$ip"
      log_debug "Server IP detected: $ip"
      return 0
    fi
  done

  log_warn "Could not automatically detect server IP"
  return 1
}

# Interactive configuration
configure_wireguard() {
  echo
  echo "====================================="
  echo "WireGuard VPN Server Setup"
  echo "====================================="
  echo

  # Get server IP
  if [[ -z "$WG_SERVER_IP" ]]; then
    if ! get_server_ip; then
      read -r -p "Enter server public IP address: " WG_SERVER_IP
    else
      read -r -p "Server IP [$WG_SERVER_IP]: " input_ip
      WG_SERVER_IP="${input_ip:-$WG_SERVER_IP}"
    fi
  fi

  # Get WireGuard port
  if [[ -z "$WG_PORT" ]]; then
    read -r -p "WireGuard port [51820]: " input_port
    WG_PORT="${input_port:-51820}"
  fi

  # Validate port
  if ! [[ "$WG_PORT" =~ ^[0-9]+$ ]] || [[ "$WG_PORT" -lt 1 ]] || [[ "$WG_PORT" -gt 65535 ]]; then
    log_error "Invalid port number: $WG_PORT"
    exit 1
  fi

  # Get first client name
  if [[ -z "$CLIENT_NAME" ]]; then
    read -r -p "First client name [client1]: " input_client
    CLIENT_NAME="${input_client:-client1}"
  fi

  # Validate client name
  if [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid client name. Use only letters, numbers, hyphens, and underscores."
    exit 1
  fi
}

# Generate WireGuard keys
generate_keys() {
  log_info "Generating WireGuard keys..."

  # Create WireGuard directory
  mkdir -p /etc/wireguard
  chmod 700 /etc/wireguard

  # Generate server keys
  wg genkey | tee /etc/wireguard/server_private.key | wg pubkey >/etc/wireguard/server_public.key
  chmod 600 /etc/wireguard/server_private.key
  chmod 644 /etc/wireguard/server_public.key

  # Generate client keys
  wg genkey | tee /etc/wireguard/client_private.key | wg pubkey >/etc/wireguard/client_public.key
  chmod 600 /etc/wireguard/client_private.key
  chmod 644 /etc/wireguard/client_public.key
}

# Create server configuration
create_server_config() {
  log_info "Creating server configuration..."

  local server_private_key
  local client_public_key
  server_private_key=$(cat /etc/wireguard/server_private.key)
  client_public_key=$(cat /etc/wireguard/client_public.key)

  cat >"$WG_CONFIG_FILE" <<EOF
[Interface]
Address = 10.66.66.1/24
ListenPort = $WG_PORT
PrivateKey = $server_private_key
PostUp = iptables -A FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -A FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -A POSTROUTING -o \$(ip route | awk '/default/ { print \$5 }') -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -D FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -D POSTROUTING -o \$(ip route | awk '/default/ { print \$5 }') -j MASQUERADE

[Peer]
PublicKey = $client_public_key
AllowedIPs = 10.66.66.2/32
EOF

  chmod 600 "$WG_CONFIG_FILE"
}

# Create client configuration
create_client_config() {
  log_info "Creating client configuration..."

  local client_private_key
  local server_public_key
  client_private_key=$(cat /etc/wireguard/client_private.key)
  server_public_key=$(cat /etc/wireguard/server_public.key)
  local client_config_file="$HOME/${CLIENT_NAME}.conf"

  cat >"$client_config_file" <<EOF
[Interface]
PrivateKey = $client_private_key
Address = 10.66.66.2/24
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = $server_public_key
Endpoint = $WG_SERVER_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

  chmod 600 "$client_config_file"

  # Generate QR code
  if command -v qrencode >/dev/null 2>&1; then
    log_info "Generating QR code..."
    qrencode -t ansiutf8 <"$client_config_file"
    qrencode -t png -o "$HOME/${CLIENT_NAME}.png" <"$client_config_file"
    log_info "QR code saved to: $HOME/${CLIENT_NAME}.png"
  fi

  log_info "Client configuration saved to: $client_config_file"
}

# Configure firewall and networking
configure_networking() {
  log_info "Configuring networking..."

  # Enable IP forwarding
  echo 'net.ipv4.ip_forward = 1' >/etc/sysctl.d/99-wireguard.conf
  sysctl -p /etc/sysctl.d/99-wireguard.conf

  # Configure firewall (basic iptables rules are in the WireGuard config)
  # Additional firewall configuration could go here
}

# Enable and start WireGuard service
start_wireguard() {
  log_info "Starting WireGuard service..."

  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable wg-quick@$WG_INTERFACE
    systemctl start wg-quick@$WG_INTERFACE

    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
      log_info "WireGuard service started successfully"
    else
      log_warn "WireGuard service may not have started properly (this can be normal in containers)"
    fi
  else
    log_warn "systemctl not available, manual service management required"
  fi
}

# Print installation summary
print_summary() {
  echo
  echo "====================================="
  echo "WireGuard Installation Complete!"
  echo "====================================="
  echo "Server IP: $WG_SERVER_IP"
  echo "Server Port: $WG_PORT"
  echo "Client Name: $CLIENT_NAME"
  echo "Client Config: $HOME/${CLIENT_NAME}.conf"
  if [[ -f "$HOME/${CLIENT_NAME}.png" ]]; then
    echo "QR Code: $HOME/${CLIENT_NAME}.png"
  fi
  echo
  echo "Import the client configuration file to your WireGuard client"
  echo "or scan the QR code to connect to the VPN."
  echo
  if [[ "$BORINGTUN_INSTALLED" == "true" ]]; then
    echo "Note: Using userspace WireGuard implementation (boringtun)"
    echo "due to container/virtualization environment."
  fi
  echo "====================================="
}

# Main installation function
main() {
  echo "WireGuard VPN Installer v$SCRIPT_VERSION"
  echo "Modern version with 2022-2025 OS support"
  echo

  # Pre-flight checks
  check_root
  detect_os
  check_virtualization
  check_requirements

  # Install WireGuard
  install_wireguard

  # Configure WireGuard
  configure_wireguard
  generate_keys
  create_server_config
  create_client_config
  configure_networking

  # Start service
  start_wireguard

  # Show summary
  print_summary

  log_info "Installation completed successfully!"
}

# Handle script arguments and environment variables
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Handle test mode and environment variables
  if [[ "${WIREGUARD_TEST_MODE:-false}" == "true" ]]; then
    # Test mode - use environment variables for non-interactive installation
    WG_SERVER_IP="${WG_SERVER_IP:-127.0.0.1}"
    WG_PORT="${WG_PORT:-51820}"
    CLIENT_NAME="${CLIENT_NAME:-testclient}"
    AUTO_INSTALL="${AUTO_INSTALL:-y}"
  fi

  # Run main function
  main "$@"
fi
