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
SCRIPT_VERSION="3.0.0"
WG_CONFIG_FILE="/etc/wireguard/wg0.conf"
WG_INTERFACE="wg0"
WG_PORT=""
WG_SERVER_IP=""
USE_USERSPACE=false
BORINGTUN_INSTALLED=false
CLIENT_DB_FILE="/etc/wireguard/clients.db"
DNS_PROVIDER="1.1.1.1, 1.0.0.1"
CONFIG_BACKUP_DIR="$HOME/.wireguard-backups"

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

# Check if we have root privileges (without requiring it upfront)
has_root_privileges() {
  [[ $EUID -eq 0 ]]
}

# Request root privileges when needed
request_root_access() {
  if ! has_root_privileges; then
    log_info "Administrative privileges required for system configuration."
    log_info "The script will use sudo for privileged operations."
    
    # Test sudo access
    if ! sudo -n true 2>/dev/null; then
      log_info "Please enter your password when prompted for sudo access:"
      sudo -v || {
        log_error "Failed to obtain administrative privileges"
        exit 1
      }
    fi
  fi
}

# Execute command with sudo if not root
exec_as_root() {
  if has_root_privileges; then
    "$@"
  else
    sudo "$@"
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
      exec_as_root apt-get update
      exec_as_root apt-get install -y "${deps[@]}"
      ;;
    dnf)
      exec_as_root dnf install -y "${deps[@]}"
      ;;
    yum)
      exec_as_root yum install -y "${deps[@]}"
      ;;
    apk)
      exec_as_root apk update
      exec_as_root apk add "${deps[@]}"
      ;;
    pacman)
      exec_as_root pacman -Sy --noconfirm "${deps[@]}"
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
  exec_as_root apt-get update

  case "$OS_VERSION" in
    22.04 | 24.04 | 24.10 | 25.04)
      # Ubuntu - WireGuard is in main repository
      exec_as_root apt-get install -y wireguard
      ;;
    12 | 13)
      # Debian - WireGuard is in main repository
      exec_as_root apt-get install -y wireguard
      ;;
    *)
      # Legacy versions
      exec_as_root apt-get install -y wireguard
      ;;
  esac

  # Install additional tools
  exec_as_root apt-get install -y qrencode iptables
}

# Install WireGuard on Fedora
install_wireguard_fedora() {
  exec_as_root dnf install -y wireguard-tools qrencode iptables
}

# Install WireGuard on RHEL-based distributions
install_wireguard_rhel() {
  # Enable EPEL repository for additional packages
  case "$OS" in
    almalinux | rocky)
      exec_as_root dnf install -y epel-release
      ;;
    ol)
      exec_as_root dnf install -y oracle-epel-release-el9
      ;;
  esac

  exec_as_root dnf install -y wireguard-tools qrencode iptables
}

# Install WireGuard on Alpine
install_wireguard_alpine() {
  exec_as_root apk add wireguard-tools qrencode iptables
}

# Install WireGuard on Amazon Linux
install_wireguard_amazon() {
  case "$OS_VERSION" in
    2023)
      exec_as_root dnf install -y wireguard-tools qrencode iptables
      ;;
    2)
      # Amazon Linux 2 requires EPEL
      exec_as_root amazon-linux-extras install epel -y
      exec_as_root yum install -y wireguard-tools qrencode iptables
      ;;
  esac
}

# Install WireGuard on Arch Linux
install_wireguard_arch() {
  exec_as_root pacman -Sy --noconfirm wireguard-tools qrencode iptables
}

# Install boringtun (userspace WireGuard implementation)
install_boringtun() {
  log_info "Installing boringtun (userspace WireGuard implementation)..."

  # Check if Rust/Cargo is available
  if ! command -v cargo >/dev/null 2>&1; then
    log_info "Installing Rust and Cargo..."
    case "$PACKAGE_MANAGER" in
      apt)
        exec_as_root apt-get install -y cargo
        ;;
      dnf | yum)
        exec_as_root $PACKAGE_MANAGER install -y cargo
        ;;
      apk)
        exec_as_root apk add cargo
        ;;
      pacman)
        exec_as_root pacman -S --noconfirm rust cargo
        ;;
    esac
  fi

  # Install boringtun
  exec_as_root cargo install boringtun --root /usr/local

  # Create systemd service for boringtun
  if command -v systemctl >/dev/null 2>&1; then
    create_boringtun_service
  fi

  BORINGTUN_INSTALLED=true
}

# Create systemd service for boringtun
create_boringtun_service() {
  exec_as_root tee /etc/systemd/system/wg-quick@.service >/dev/null <<'EOF'
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

  exec_as_root systemctl daemon-reload
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

# DNS provider selection
select_dns_provider() {
  if [[ -n "$DNS_PROVIDER" ]]; then
    return 0
  fi

  echo
  echo "Select DNS provider for VPN clients:"
  echo "1) Cloudflare (1.1.1.1, 1.0.0.1) - Privacy focused"
  echo "2) Quad9 (9.9.9.9, 149.112.112.112) - Security focused"
  echo "3) Google (8.8.8.8, 8.8.4.4) - Reliable"
  echo "4) OpenDNS (208.67.222.222, 208.67.220.220) - Family safe"
  echo "5) Custom DNS servers"
  echo

  while true; do
    read -r -p "Choose DNS provider [1]: " dns_choice
    dns_choice="${dns_choice:-1}"

    case "$dns_choice" in
      1)
        DNS_PROVIDER="1.1.1.1, 1.0.0.1"
        log_info "Selected Cloudflare DNS"
        break
        ;;
      2)
        DNS_PROVIDER="9.9.9.9, 149.112.112.112"
        log_info "Selected Quad9 DNS"
        break
        ;;
      3)
        DNS_PROVIDER="8.8.8.8, 8.8.4.4"
        log_info "Selected Google DNS"
        break
        ;;
      4)
        DNS_PROVIDER="208.67.222.222, 208.67.220.220"
        log_info "Selected OpenDNS"
        break
        ;;
      5)
        read -r -p "Enter custom DNS servers (comma separated): " custom_dns
        if [[ -n "$custom_dns" ]]; then
          DNS_PROVIDER="$custom_dns"
          log_info "Selected custom DNS: $DNS_PROVIDER"
          break
        else
          log_error "Invalid DNS servers"
        fi
        ;;
      *)
        log_error "Invalid choice. Please select 1-5."
        ;;
    esac
  done
}

# Check for IPv6 support
check_ipv6_support() {
  if [[ -f /proc/net/if_inet6 ]] && ip -6 addr show | grep -q "inet6.*global"; then
    log_debug "IPv6 support detected"
  else
    log_debug "IPv6 not supported or not configured"
  fi
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

  # Select DNS provider
  select_dns_provider

  # Check IPv6 support
  check_ipv6_support
}

# Client database management
init_client_db() {
  local db_dir
  db_dir=$(dirname "$CLIENT_DB_FILE")
  exec_as_root mkdir -p "$db_dir"
  exec_as_root touch "$CLIENT_DB_FILE"
  exec_as_root chmod 600 "$CLIENT_DB_FILE"
}

# Add client to database
add_client_to_db() {
  local client_name="$1"
  local client_ip="$2"
  local client_public_key="$3"
  
  if ! grep -q "^$client_name:" "$CLIENT_DB_FILE" 2>/dev/null; then
    echo "$client_name:$client_ip:$client_public_key:$(date +%s)" | exec_as_root tee -a "$CLIENT_DB_FILE" >/dev/null
  fi
}

# Remove client from database
remove_client_from_db() {
  local client_name="$1"
  exec_as_root sed -i "/^$client_name:/d" "$CLIENT_DB_FILE"
}

# Get next available IP
get_next_client_ip() {
  local base_ip="10.66.66"
  local start_ip=2
  local max_ip=254
  
  for ((i=start_ip; i<=max_ip; i++)); do
    local test_ip="$base_ip.$i"
    if ! grep -q ":$test_ip:" "$CLIENT_DB_FILE" 2>/dev/null; then
      echo "$test_ip"
      return 0
    fi
  done
  
  log_error "No available IP addresses in range $base_ip.2-254"
  exit 1
}

# List all clients
list_clients() {
  if [[ ! -f "$CLIENT_DB_FILE" ]]; then
    log_info "No clients found"
    return 0
  fi
  
  echo "Current WireGuard clients:"
  echo "=========================="
  echo "Name                IP Address      Added"
  echo "------------------------------------------------"
  
  while IFS=: read -r name ip _ timestamp; do
    local date_added
    date_added=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
    printf "%-18s %-15s %s\n" "$name" "$ip" "$date_added"
  done < "$CLIENT_DB_FILE"
}

# Add new client
add_client() {
  local client_name="$1"
  
  if [[ -z "$client_name" ]]; then
    log_error "Client name is required"
    return 1
  fi
  
  # Validate client name
  if [[ ! "$client_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid client name. Use only letters, numbers, hyphens, and underscores."
    return 1
  fi
  
  # Check if client already exists
  if grep -q "^$client_name:" "$CLIENT_DB_FILE" 2>/dev/null; then
    log_error "Client '$client_name' already exists"
    return 1
  fi
  
  # Request root access for system operations
  request_root_access
  
  # Initialize client database
  init_client_db
  
  # Get next available IP
  local client_ip
  client_ip=$(get_next_client_ip)
  
  log_info "Adding client '$client_name' with IP $client_ip"
  
  # Generate client keys
  local client_private_key client_public_key
  client_private_key=$(wg genkey)
  client_public_key=$(echo "$client_private_key" | wg pubkey)
  
  # Add client to WireGuard config
  exec_as_root tee -a "$WG_CONFIG_FILE" >/dev/null << EOF

# Client: $client_name
[Peer]
PublicKey = $client_public_key
AllowedIPs = $client_ip/32
EOF
  
  # Add client to database
  add_client_to_db "$client_name" "$client_ip" "$client_public_key"
  
  # Create client config file
  create_client_config_file "$client_name" "$client_private_key" "$client_ip"
  
  # Reload WireGuard
  exec_as_root systemctl reload wg-quick@wg0 2>/dev/null || true
  
  log_info "Client '$client_name' added successfully"
  log_info "Configuration file: $HOME/$client_name.conf"
}

# Remove client
remove_client() {
  local client_name="$1"
  
  if [[ -z "$client_name" ]]; then
    log_error "Client name is required"
    return 1
  fi
  
  # Check if client exists
  if ! grep -q "^$client_name:" "$CLIENT_DB_FILE" 2>/dev/null; then
    log_error "Client '$client_name' not found"
    return 1
  fi
  
  # Request root access for system operations
  request_root_access
  
  log_info "Removing client '$client_name'"
  
  # Remove from WireGuard config
  exec_as_root sed -i "/^# Client: $client_name$/,/^$/d" "$WG_CONFIG_FILE"
  
  # Remove from database
  remove_client_from_db "$client_name"
  
  # Remove client config file
  rm -f "$HOME/$client_name.conf" "$HOME/$client_name.png"
  
  # Reload WireGuard
  exec_as_root systemctl reload wg-quick@wg0 2>/dev/null || true
  
  log_info "Client '$client_name' removed successfully"
}

# Generate WireGuard keys
generate_keys() {
  log_info "Generating WireGuard keys..."

  # Create WireGuard directory
  exec_as_root mkdir -p /etc/wireguard
  exec_as_root chmod 700 /etc/wireguard

  # Generate server keys
  wg genkey | exec_as_root tee /etc/wireguard/server_private.key | wg pubkey | exec_as_root tee /etc/wireguard/server_public.key >/dev/null
  exec_as_root chmod 600 /etc/wireguard/server_private.key
  exec_as_root chmod 644 /etc/wireguard/server_public.key

  # Generate client keys for initial client
  wg genkey | exec_as_root tee /etc/wireguard/client_private.key | wg pubkey | exec_as_root tee /etc/wireguard/client_public.key >/dev/null
  exec_as_root chmod 600 /etc/wireguard/client_private.key
  exec_as_root chmod 644 /etc/wireguard/client_public.key

  # Initialize client database
  init_client_db
}

# Create client configuration file
create_client_config_file() {
  local client_name="$1"
  local client_private_key="$2"
  local client_ip="$3"
  
  local server_public_key
  server_public_key=$(exec_as_root cat /etc/wireguard/server_public.key)
  
  local config_file="$HOME/$client_name.conf"
  
  cat >"$config_file" <<EOF
[Interface]
PrivateKey = $client_private_key
Address = $client_ip/32
DNS = $DNS_PROVIDER

[Peer]
PublicKey = $server_public_key
AllowedIPs = 0.0.0.0/0
Endpoint = $WG_SERVER_IP:$WG_PORT
PersistentKeepalive = 25
EOF

  chmod 600 "$config_file"
  log_info "Client configuration created: $config_file"
  
  # Generate QR code if qrencode is available
  if command -v qrencode >/dev/null 2>&1; then
    qrencode -t png -o "$HOME/$client_name.png" < "$config_file"
    log_info "QR code generated: $HOME/$client_name.png"
  fi
}

# Create server configuration
create_server_config() {
  log_info "Creating server configuration..."

  local server_private_key
  local client_public_key
  server_private_key=$(exec_as_root cat /etc/wireguard/server_private.key)
  client_public_key=$(exec_as_root cat /etc/wireguard/client_public.key)

  exec_as_root tee "$WG_CONFIG_FILE" >/dev/null <<EOF
[Interface]
Address = 10.66.66.1/24
ListenPort = $WG_PORT
PrivateKey = $server_private_key
PostUp = iptables -A FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -A FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -A POSTROUTING -o \$(ip route | awk '/default/ { print \$5 }') -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -D FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -D POSTROUTING -o \$(ip route | awk '/default/ { print \$5 }') -j MASQUERADE

# Client: $CLIENT_NAME
[Peer]
PublicKey = $client_public_key
AllowedIPs = 10.66.66.2/32
EOF

  exec_as_root chmod 600 "$WG_CONFIG_FILE"
  
  # Add initial client to database
  add_client_to_db "$CLIENT_NAME" "10.66.66.2" "$client_public_key"
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
  echo 'net.ipv4.ip_forward = 1' | exec_as_root tee /etc/sysctl.d/99-wireguard.conf >/dev/null
  exec_as_root sysctl -p /etc/sysctl.d/99-wireguard.conf

  # Configure firewall (basic iptables rules are in the WireGuard config)
  # Additional firewall configuration could go here
}

# Enable and start WireGuard service
start_wireguard() {
  log_info "Starting WireGuard service..."

  if command -v systemctl >/dev/null 2>&1; then
    exec_as_root systemctl enable wg-quick@$WG_INTERFACE
    exec_as_root systemctl start wg-quick@$WG_INTERFACE

    if exec_as_root systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
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

# Show usage information
show_usage() {
  cat << EOF
WireGuard VPN Installer v$SCRIPT_VERSION

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --install               Install WireGuard VPN server (default)
  --add-client <name>     Add a new client
  --remove-client <name>  Remove an existing client
  --list-clients          List all clients
  --show-qr <name>        Show QR code for client
  --backup                Backup WireGuard configuration
  --restore <file>        Restore configuration from backup
  --help                  Show this help message

EXAMPLES:
  $0                      # Interactive installation
  $0 --add-client laptop  # Add client named 'laptop'
  $0 --list-clients       # List all clients
  $0 --show-qr laptop     # Show QR code for 'laptop' client

ENVIRONMENT VARIABLES:
  WG_SERVER_IP           Server public IP address
  WG_PORT               WireGuard port (default: 51820)
  CLIENT_NAME           First client name (default: client1)
  DNS_PROVIDER          DNS servers for clients
  WIREGUARD_TEST_MODE   Enable test mode
  DEBUG                 Enable debug logging

EOF
}

# Show QR code for existing client
show_qr() {
  local client_name="$1"
  local config_file="$HOME/$client_name.conf"
  
  if [[ ! -f "$config_file" ]]; then
    log_error "Client configuration file not found: $config_file"
    return 1
  fi
  
  if command -v qrencode >/dev/null 2>&1; then
    echo "QR Code for client '$client_name':"
    qrencode -t ansiutf8 < "$config_file"
  else
    log_error "qrencode not installed. Install it with: apt install qrencode"
    return 1
  fi
}

# Backup WireGuard configuration
backup_config() {
  local backup_dir="$CONFIG_BACKUP_DIR"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file="$backup_dir/wireguard_backup_$timestamp.tar.gz"
  
  log_info "Creating backup..."
  
  mkdir -p "$backup_dir"
  
  # Create backup
  exec_as_root tar -czf "$backup_file" -C /etc wireguard/ || {
    log_error "Failed to create backup"
    return 1
  }
  
  # Copy client database if it exists
  if [[ -f "$CLIENT_DB_FILE" ]]; then
    exec_as_root cp "$CLIENT_DB_FILE" "$backup_dir/clients_$timestamp.db"
  fi
  
  log_info "Backup created: $backup_file"
}

# Restore WireGuard configuration
restore_config() {
  local backup_file="$1"
  
  if [[ ! -f "$backup_file" ]]; then
    log_error "Backup file not found: $backup_file"
    return 1
  fi
  
  log_warn "This will overwrite current WireGuard configuration!"
  read -r -p "Continue? [y/N]: " confirm
  
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Restore cancelled"
    return 0
  fi
  
  # Request root access
  request_root_access
  
  log_info "Restoring from backup..."
  
  # Stop WireGuard service
  exec_as_root systemctl stop wg-quick@wg0 2>/dev/null || true
  
  # Restore files
  exec_as_root tar -xzf "$backup_file" -C /etc || {
    log_error "Failed to restore backup"
    return 1
  }
  
  # Start WireGuard service
  exec_as_root systemctl start wg-quick@wg0 2>/dev/null || true
  
  log_info "Configuration restored successfully"
}

# Main installation function
install_wireguard_server() {
  echo "WireGuard VPN Installer v$SCRIPT_VERSION"
  echo "Modern version with 2022-2025 OS support"
  echo

  # Phase 1: Non-root operations
  log_info "Phase 1: System analysis and configuration"
  detect_os
  check_virtualization
  check_requirements
  configure_wireguard

  # Phase 2: Request root access and install
  log_info "Phase 2: System installation (requires administrative privileges)"
  request_root_access
  
  install_wireguard
  generate_keys
  create_server_config
  
  # Create initial client configuration
  local client_private_key
  client_private_key=$(exec_as_root cat /etc/wireguard/client_private.key)
  create_client_config_file "$CLIENT_NAME" "$client_private_key" "10.66.66.2"
  
  configure_networking
  start_wireguard
  print_summary

  log_info "Installation completed successfully!"
}

# Main function with argument parsing
main() {
  case "${1:-}" in
    --help|-h)
      show_usage
      exit 0
      ;;
    --add-client)
      if [[ -z "${2:-}" ]]; then
        log_error "Client name required"
        show_usage
        exit 1
      fi
      add_client "$2"
      ;;
    --remove-client)
      if [[ -z "${2:-}" ]]; then
        log_error "Client name required"
        show_usage
        exit 1
      fi
      remove_client "$2"
      ;;
    --list-clients)
      list_clients
      ;;
    --show-qr)
      if [[ -z "${2:-}" ]]; then
        log_error "Client name required"
        show_usage
        exit 1
      fi
      show_qr "$2"
      ;;
    --backup)
      backup_config
      ;;
    --restore)
      if [[ -z "${2:-}" ]]; then
        log_error "Backup file required"
        show_usage
        exit 1
      fi
      restore_config "$2"
      ;;
    --install|"")
      # Default action: install WireGuard server
      install_wireguard_server
      ;;
    *)
      log_error "Unknown option: $1"
      show_usage
      exit 1
      ;;
  esac
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
