#!/bin/bash

# WireGuard Installation Script Test Helpers
# This file contains reusable functions for testing the WireGuard script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test status tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

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

# Test framework functions
test_start() {
    local test_name="$1"
    echo -e "\n${YELLOW}=== Testing: $test_name ===${NC}"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

test_pass() {
    echo -e "${GREEN}✓ Test passed${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    local reason="$1"
    echo -e "${RED}✗ Test failed: $reason${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_summary() {
    echo -e "\n${YELLOW}=== Test Summary ===${NC}"
    echo "Total: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# OS Detection functions
detect_os() {
    local os_info=""
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        os_info="$ID $VERSION_ID"
    elif [[ -f /etc/redhat-release ]]; then
        os_info=$(cat /etc/redhat-release)
    elif [[ -f /etc/debian_version ]]; then
        os_info="debian $(cat /etc/debian_version)"
    fi
    
    echo "$os_info"
}

get_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v apk >/dev/null 2>&1; then
        echo "apk"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# Pre-test validation
validate_test_environment() {
    test_start "Test Environment Validation"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        test_fail "Tests must be run as root"
        return 1
    fi
    
    # Check if script exists
    if [[ ! -f "installer.sh" ]]; then
        test_fail "installer.sh not found"
        return 1
    fi
    
    # Check if script is executable
    if [[ ! -x "installer.sh" ]]; then
        chmod +x installer.sh
        log_info "Made script executable"
    fi
    
    # Detect OS
    local os_info
    os_info=$(detect_os)
    log_info "Detected OS: $os_info"
    
    # Detect package manager
    local pkg_mgr
    pkg_mgr=$(get_package_manager)
    log_info "Package manager: $pkg_mgr"
    
    test_pass
}

# WireGuard specific tests
test_wireguard_installation() {
    test_start "WireGuard Installation"
    
    # Set environment variables for non-interactive installation
    export AUTO_INSTALL=y
    export APPROVE_INSTALL=y
    export APPROVE_IP=y
    export IPV6_SUPPORT=n
    export PORT_CHOICE=1
    export DNS=1
    export CLIENT=testclient
    export PASS=1
    
    # Run installation with timeout
    log_info "Starting WireGuard installation..."
    if timeout 300 ./installer.sh; then
        test_pass
    else
        test_fail "Installation script failed or timed out"
        return 1
    fi
}

test_wireguard_binaries() {
    test_start "WireGuard Binary Installation"
    
    # Check for wg command
    if command -v wg >/dev/null 2>&1; then
        log_info "wg command found: $(wg --version)"
    else
        test_fail "wg command not found"
        return 1
    fi
    
    # Check for wg-quick command
    if command -v wg-quick >/dev/null 2>&1; then
        log_info "wg-quick command found"
    else
        test_fail "wg-quick command not found"
        return 1
    fi
    
    test_pass
}

test_configuration_files() {
    test_start "Configuration Files"
    
    # Check server configuration
    if [[ -f /etc/wireguard/wg0.conf ]]; then
        log_info "Server configuration exists"
        
        # Validate configuration syntax
        if wg-quick strip wg0 >/dev/null 2>&1; then
            log_info "Server configuration is valid"
        else
            test_fail "Server configuration is invalid"
            return 1
        fi
    else
        test_fail "Server configuration file not found"
        return 1
    fi
    
    # Check client configuration
    if [[ -f ~/testclient.conf ]]; then
        log_info "Client configuration exists"
        
        # Basic validation of client config
        if grep -q "PrivateKey" ~/testclient.conf && grep -q "PublicKey" ~/testclient.conf; then
            log_info "Client configuration contains required keys"
        else
            test_fail "Client configuration missing required keys"
            return 1
        fi
    else
        test_fail "Client configuration file not found"
        return 1
    fi
    
    test_pass
}

test_service_management() {
    test_start "Service Management"
    
    # Check if systemd is available
    if command -v systemctl >/dev/null 2>&1; then
        # Check if service is enabled
        if systemctl is-enabled wg-quick@wg0 >/dev/null 2>&1; then
            log_info "WireGuard service is enabled"
        else
            test_fail "WireGuard service is not enabled"
            return 1
        fi
        
        # Try to start service (may fail in containers)
        if systemctl start wg-quick@wg0 2>/dev/null; then
            log_info "WireGuard service started successfully"
            
            # Check service status
            if systemctl is-active wg-quick@wg0 >/dev/null 2>&1; then
                log_info "WireGuard service is active"
            else
                log_warn "WireGuard service is not active (may be expected in containers)"
            fi
        else
            log_warn "Could not start WireGuard service (may be expected in containers)"
        fi
    else
        log_warn "systemctl not available, skipping service tests"
    fi
    
    test_pass
}

test_network_configuration() {
    test_start "Network Configuration"
    
    # Check iptables rules (may not work in all containers)
    if command -v iptables >/dev/null 2>&1; then
        if iptables -L >/dev/null 2>&1; then
            log_info "iptables is functional"
            
            # Look for WireGuard-related rules
            if iptables -t nat -L | grep -q "MASQUERADE\|SNAT" 2>/dev/null; then
                log_info "NAT rules appear to be configured"
            else
                log_warn "No NAT rules found (may be expected in containers)"
            fi
        else
            log_warn "iptables not functional (expected in some containers)"
        fi
    else
        log_warn "iptables command not found"
    fi
    
    # Check IP forwarding
    if [[ -f /proc/sys/net/ipv4/ip_forward ]]; then
        local ip_forward
        ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)
        if [[ "$ip_forward" == "1" ]]; then
            log_info "IP forwarding is enabled"
        else
            log_warn "IP forwarding is disabled"
        fi
    fi
    
    test_pass
}

test_file_permissions() {
    test_start "File Permissions and Security"
    
    # Check server config permissions
    if [[ -f /etc/wireguard/wg0.conf ]]; then
        local perms
        perms=$(stat -c "%a" /etc/wireguard/wg0.conf)
        if [[ "$perms" == "600" ]]; then
            log_info "Server config has correct permissions (600)"
        else
            test_fail "Server config has incorrect permissions: $perms (should be 600)"
            return 1
        fi
    fi
    
    # Check client config permissions
    if [[ -f ~/testclient.conf ]]; then
        local perms
        perms=$(stat -c "%a" ~/testclient.conf)
        if [[ "$perms" == "600" ]]; then
            log_info "Client config has correct permissions (600)"
        else
            log_warn "Client config has permissions: $perms (should be 600)"
        fi
    fi
    
    test_pass
}

# Cleanup functions
cleanup_installation() {
    test_start "Cleanup Installation"
    
    log_info "Cleaning up WireGuard installation..."
    
    # Stop service if running
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop wg-quick@wg0 2>/dev/null || true
        systemctl disable wg-quick@wg0 2>/dev/null || true
    fi
    
    # Remove configuration files
    rm -f /etc/wireguard/wg0.conf
    rm -f ~/testclient.conf
    rm -f ~/testclient.png
    
    # Remove WireGuard interface if it exists
    if ip link show wg0 >/dev/null 2>&1; then
        ip link delete wg0 2>/dev/null || true
    fi
    
    log_info "Cleanup completed"
    test_pass
}

# Container environment detection
is_container_environment() {
    if [[ -f /.dockerenv ]] || [[ -n "${container}" ]]; then
        return 0
    fi
    
    if grep -q "container=\|docker\|lxc" /proc/1/cgroup 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Export functions for use in other scripts
export -f log_info log_warn log_error
export -f test_start test_pass test_fail test_summary
export -f detect_os get_package_manager
export -f validate_test_environment
export -f test_wireguard_installation test_wireguard_binaries
export -f test_configuration_files test_service_management
export -f test_network_configuration test_file_permissions
export -f cleanup_installation is_container_environment 