#!/bin/bash

# Cross-compile library build script
# For building and managing cross-compiled compression libraries (zlib, zstd)

set -e  # Exit on error

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show help message
show_help() {
    cat << EOF
Cross-compile library build script

Usage: $0 [options]

Options:
    -s, --system SYSTEM    Specify target system (default: loongarch64-linux)
    -b, --build            Build cross-compiled libraries
    -t, --test             Test built libraries
    -e, --enter            Enter build environment
    -c, --clean            Clean build cache
    -h, --help             Show this help message

Supported target systems:
    - loongarch64-linux
    - aarch64-linux
    - x86_64-linux
    - riscv64-linux

Examples:
    $0 -b -s aarch64-linux      # Build for aarch64-linux
    $0 -t -s loongarch64-linux  # Test loongarch64-linux libraries
    $0 -e -s riscv64-linux      # Enter riscv64-linux build environment
EOF
}

# Default parameters
TARGET_SYSTEM="loongarch64-linux"
ACTION=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--system)
            TARGET_SYSTEM="$2"
            shift 2
            ;;
        -b|--build)
            ACTION="build"
            shift
            ;;
        -t|--test)
            ACTION="test"
            shift
            ;;
        -e|--enter)
            ACTION="enter"
            shift
            ;;
        -c|--clean)
            ACTION="clean"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Default action is build
if [[ -z "$ACTION" ]]; then
    ACTION="build"
fi

# Check if Nix is available
check_nix() {
    if ! command -v nix &> /dev/null; then
        print_error "Nix is not installed or not in PATH"
        exit 1
    fi
    
    if ! nix --version &> /dev/null; then
        print_error "Nix is not working properly"
        exit 1
    fi
    
    print_success "Nix environment check passed"
}

# Build cross-compiled libraries
build_libs() {
    print_info "Start building cross-compiled libraries for ${TARGET_SYSTEM}..."
    
    # Use nix-build to build libraries
    nix-build -E "
        let
          pkgs = import ../nixpkgs {};
          crossLibs = import ./lib/cross-compile-libs.nix { 
            inherit pkgs; 
            system = \"${TARGET_SYSTEM}\"; 
          };
        in crossLibs.default
    " --show-trace --log-format bar
    
    if [[ $? -eq 0 ]]; then
        print_success "Cross-compiled libraries build finished"
        print_info "Build result at: ./result"
        
        # Use sudo to create symlink result -> lib/result
        sudo rm -rf lib/result
        sudo ln -sfn $(realpath ./result) lib/result
        print_success "Symlinked ./result to lib/result"
    else
        print_error "Build failed"
        exit 1
    fi
}

# Test built libraries
test_libs() {
    print_info "Testing cross-compiled libraries for ${TARGET_SYSTEM}..."
    
    if [[ ! -L "./result" ]]; then
        print_warning "Build result not found, building first..."
        build_libs
    fi
    
    print_info "Checking Nix build result..."
    
    # Check if library files exist
    if [[ -d "./result/lib" ]]; then
        print_success "Library directory exists"
        
        # Check zlib
        if [[ -f "./result/lib/libz.so" ]] || [[ -f "./result/lib/libz.a" ]]; then
            print_success "zlib library files exist"
        else
            print_warning "zlib library files not found"
        fi
        
        # Check zstd
        if [[ -f "./result/lib/libzstd.so" ]] || [[ -f "./result/lib/libzstd.a" ]]; then
            print_success "zstd library files exist"
        else
            print_warning "zstd library files not found"
        fi
        
        # Check pkg-config files
        if [[ -d "./result/lib/pkgconfig" ]]; then
            print_success "pkg-config files exist"
            ls -la ./result/lib/pkgconfig/
        fi
        
        # Check scripts
        if [[ -f "./result/bin/setup-env" ]]; then
            print_success "Environment setup script exists"
        fi
        
        if [[ -f "./result/bin/pkg-config-wrapper" ]]; then
            print_success "pkg-config wrapper script exists"
        fi
        
    else
        print_error "Library directory does not exist"
        exit 1
    fi
    
    print_info "Library test finished"
}

# Enter build environment
enter_env() {
    print_info "Entering build environment for ${TARGET_SYSTEM}..."
    
    nix-shell -E "
        let
          pkgs = import ../nixpkgs {};
          crossLibs = import ./lib/cross-compile-libs.nix { 
            inherit pkgs; 
            system = \"${TARGET_SYSTEM}\"; 
          };
        in pkgs.mkShell {
          buildInputs = [ crossLibs.default ];
          shellHook = ''
            echo \"Entered cross-compilation environment: ${TARGET_SYSTEM}\"
            echo \"Available libraries:\"
            echo \"  - zlib (static/dynamic)\"
            echo \"  - zstd (static/dynamic)\"
            echo \"Use setup-env script to set environment variables\"
          '';
        }
    "
}

# Clean build cache
clean_build() {
    print_info "Cleaning build cache..."
    
    if [[ -L "./result" ]]; then
        rm -f ./result
        print_success "Removed build result symlink"
    fi
    
    if [[ -L "lib/result" ]]; then
        sudo rm -f lib/result
        print_success "Removed lib/result symlink"
    fi
    
    # Clean Nix build cache
    nix-collect-garbage -d
    
    print_success "Clean finished"
}

# Main function
main() {
    print_info "Cross-compile library script started"
    print_info "Target system: ${TARGET_SYSTEM}"
    print_info "Action: ${ACTION}"
    
    # Check Nix environment
    check_nix
    
    # Execute action
    case $ACTION in
        "build")
            build_libs
            ;;
        "test")
            test_libs
            ;;
        "enter")
            enter_env
            ;;
        "clean")
            clean_build
            ;;
        *)
            print_error "Unknown action: $ACTION"
            exit 1
            ;;
    esac
    
    print_success "Script finished"
}

# Run main function
main "$@" 