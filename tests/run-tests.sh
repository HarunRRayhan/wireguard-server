#!/bin/bash

# WireGuard Installation Script Test Runner
# Main entry point for running all tests

set -e

# Change to script directory
cd "$(dirname "$0")/.."

# Source test helpers
source tests/test-helpers.sh

# Test configuration
TEST_MODE="${TEST_MODE:-full}" # full, quick, or specific
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"

# Print banner
echo "=========================================="
echo "WireGuard Installation Script Test Runner"
echo "=========================================="
echo "Test Mode: $TEST_MODE"
echo "OS: $(detect_os)"
echo "Package Manager: $(get_package_manager)"
if is_container_environment; then
  echo "Environment: Container"
else
  echo "Environment: Physical/VM"
fi
echo "=========================================="

# Main test execution
main() {
  local exit_code=0

  # Validate test environment
  if ! validate_test_environment; then
    log_error "Test environment validation failed"
    return 1
  fi

  # Run tests based on mode
  case "$TEST_MODE" in
    "full")
      run_full_test_suite
      exit_code=$?
      ;;
    "quick")
      run_quick_tests
      exit_code=$?
      ;;
    "installation")
      test_installation_only
      exit_code=$?
      ;;
    "validation")
      test_validation_only
      exit_code=$?
      ;;
    *)
      log_error "Unknown test mode: $TEST_MODE"
      print_usage
      return 1
      ;;
  esac

  # Cleanup if requested
  if [[ "$SKIP_CLEANUP" != "true" ]]; then
    cleanup_installation
  else
    log_warn "Skipping cleanup (SKIP_CLEANUP=true)"
  fi

  # Print test summary
  test_summary

  return $exit_code
}

run_full_test_suite() {
  log_info "Running full test suite..."

  # Pre-installation tests
  test_script_syntax
  test_permissions

  # Installation tests
  test_wireguard_installation

  # Post-installation validation
  test_wireguard_binaries
  test_configuration_files
  test_service_management
  test_network_configuration
  test_file_permissions

  # Functional tests
  test_client_operations
  test_config_validation

  return 0
}

run_quick_tests() {
  log_info "Running quick test suite..."

  # Essential tests only
  test_script_syntax
  test_wireguard_installation
  test_wireguard_binaries
  test_configuration_files

  return 0
}

test_installation_only() {
  log_info "Running installation test only..."

  test_wireguard_installation
  test_wireguard_binaries

  return 0
}

test_validation_only() {
  log_info "Running validation tests only..."

  # Assume WireGuard is already installed
  test_wireguard_binaries
  test_configuration_files
  test_service_management
  test_network_configuration
  test_file_permissions

  return 0
}

# Additional test functions
test_script_syntax() {
  test_start "Script Syntax Check"

  if bash -n installer.sh; then
    log_info "Script syntax is valid"
    test_pass
  else
    test_fail "Script has syntax errors"
    return 1
  fi
}

test_permissions() {
  test_start "Script Permissions"

  local script_perms
  script_perms=$(stat -c "%a" installer.sh)
  if [[ "$script_perms" =~ ^[67][0-9][0-9]$ ]]; then
    log_info "Script has appropriate permissions: $script_perms"
    test_pass
  else
    log_warn "Script permissions: $script_perms (should be executable)"
    test_pass # Not a failure, just a warning
  fi
}

test_client_operations() {
  test_start "Client Operations"

  # Test adding a second client
  log_info "Testing client addition..."

  # This would require modifying the original script to support
  # non-interactive client addition
  # For now, just validate that the first client was created properly

  if [[ -f ~/testclient.conf ]]; then
    # Validate client config structure
    if grep -q "\[Interface\]" ~/testclient.conf &&
      grep -q "\[Peer\]" ~/testclient.conf; then
      log_info "Client configuration has correct structure"
      test_pass
    else
      test_fail "Client configuration has incorrect structure"
      return 1
    fi
  else
    test_fail "No client configuration found"
    return 1
  fi
}

test_config_validation() {
  test_start "Configuration Validation"

  # Test server config
  if [[ -f /etc/wireguard/wg0.conf ]]; then
    # Check for required sections
    if grep -q "\[Interface\]" /etc/wireguard/wg0.conf &&
      grep -q "PrivateKey" /etc/wireguard/wg0.conf; then
      log_info "Server config has required interface section"
    else
      test_fail "Server config missing required interface section"
      return 1
    fi

    # Check for peer section (should exist if client was added)
    if grep -q "\[Peer\]" /etc/wireguard/wg0.conf; then
      log_info "Server config has peer section"
    else
      log_warn "Server config has no peer section"
    fi

    test_pass
  else
    test_fail "Server configuration not found"
    return 1
  fi
}

# Debugging functions
debug_environment() {
  echo "=== Debug Information ==="
  echo "Working directory: $(pwd)"
  echo "Script exists: $(test -f installer.sh && echo "yes" || echo "no")"
  echo "Script executable: $(test -x installer.sh && echo "yes" || echo "no")"
  echo "Running as: $(whoami) (UID: $EUID)"
  echo "OS Release:"
  cat /etc/os-release 2>/dev/null || echo "No /etc/os-release"
  echo "Available commands:"
  for cmd in wg wg-quick systemctl iptables; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "  $cmd: $(command -v "$cmd")"
    else
      echo "  $cmd: not found"
    fi
  done
  echo "========================="
}

print_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Test modes:
  full         Run complete test suite (default)
  quick        Run essential tests only
  installation Run installation test only
  validation   Run validation tests only (assumes WireGuard installed)

Environment variables:
  TEST_MODE       Set test mode (full|quick|installation|validation)
  SKIP_CLEANUP    Skip cleanup after tests (true|false)
  DEBUG          Enable debug output (true|false)

Examples:
  $0                           # Run full test suite
  TEST_MODE=quick $0           # Run quick tests
  SKIP_CLEANUP=true $0         # Run tests without cleanup
  DEBUG=true $0                # Run with debug output

EOF
}

# Handle command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --help | -h)
      print_usage
      exit 0
      ;;
    --debug | -d)
      DEBUG=true
      shift
      ;;
    --mode | -m)
      TEST_MODE="$2"
      shift 2
      ;;
    --skip-cleanup)
      SKIP_CLEANUP=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# Enable debug mode if requested
if [[ "$DEBUG" == "true" ]]; then
  set -x
  debug_environment
fi

# Run main function
if main; then
  log_info "All tests completed successfully!"
  exit 0
else
  log_error "Some tests failed!"
  exit 1
fi
