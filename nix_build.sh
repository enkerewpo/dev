#!/bin/bash

set -e

export NIXPKGS_ALLOW_BROKEN=1
export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_progress() {
    echo -e "${CYAN}[PROGRESS]${NC} $1"
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r${CYAN}[PROGRESS]${NC} ["
    printf "%${completed}s" | tr ' ' '#'
    printf "%${remaining}s" | tr ' ' '-'
    printf "] %d%%" $percentage
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# Default values
ARCH=""
SKIP_NIX=false
EXPAND_SIZE="8G"

# Function to display usage
usage() {
    echo -e "${WHITE}Usage: $0 [OPTIONS]${NC}"
    echo -e "${WHITE}Options:${NC}"
    echo -e "  ${CYAN}-t, --target ARCH${NC}    Target architecture (aarch64, loongarch64)"
    echo -e "  ${CYAN}-s, --skip-nix${NC}       Skip nix build step"
    echo -e "  ${CYAN}-e, --expand SIZE${NC}    Expand root partition to SIZE (e.g., 4G, 8G) [default: 8G]"
    echo -e "  ${CYAN}-h, --help${NC}           Display this help message"
    echo ""
    echo -e "${WHITE}Examples:${NC}"
    echo -e "  ${GREEN}$0 --target aarch64${NC}"
    echo -e "  ${GREEN}$0 -t loongarch64 --skip-nix${NC}"
    echo -e "  ${GREEN}$0 -t aarch64 -s${NC}"
    echo -e "  ${GREEN}$0 -t aarch64 -e 16G${NC}"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target)
            ARCH="$2"
            shift 2
            ;;
        -s|--skip-nix)
            SKIP_NIX=true
            shift
            ;;
        -e|--expand)
            EXPAND_SIZE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$ARCH" ]; then
    # default to loongarch64
    ARCH="loongarch64"
    log_info "using default architecture: $ARCH"
fi

# Validate architecture
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "loongarch64" ]; then
    log_error "invalid architecture: $ARCH"
    log_error "supported architectures: aarch64, loongarch64"
    exit 1
fi

# Validate expand size format
if [ -n "$EXPAND_SIZE" ]; then
    if [[ ! "$EXPAND_SIZE" =~ ^[0-9]+[KMG]?$ ]]; then
        log_error "invalid expand size format: $EXPAND_SIZE"
        log_error "supported formats: 2G, 500M, 1024K, 1000"
        exit 1
    fi
fi

to_linux_arch() {
    case "$1" in
        aarch64) echo "arm64" ;;
        loongarch64) echo "loongarch" ;;
        *) log_error "invalid architecture: $1"
            exit 1
    esac
}

log_step "cleaning linux kernel source..."
make -C linux-git ARCH="$(to_linux_arch "$ARCH")" mrproper || exit 1

# Build nix image unless --skip-nix is specified
if [ "$SKIP_NIX" = false ]; then
    log_step "building nix image for $ARCH..."
    if [ "$ARCH" == "aarch64" ]; then
        nix-build aarch64.nix --show-trace --log-format bar -A image --out-link image
    elif [ "$ARCH" == "loongarch64" ]; then
        nix-build loongarch.nix --show-trace --log-format bar -A image --out-link image
    fi
    log_success "nix image built successfully"
else
    log_warning "skipping nix build as requested"
fi

# if has flag --skip-nix/-s, skip the nix build

NIXOS_VERSION="25.11pre-git"
IMG_PATH="image/sd-image/nixos-image-sd-card-${NIXOS_VERSION}-${ARCH}-linux.img"

if [ ! -f "$IMG_PATH" ]; then
    log_error "image file not found at $IMG_PATH"
    exit 1
fi

log_info "found image at: $IMG_PATH"

# image has 2 partitions, the first is the boot partition, the second is the root partition(ext4)

# Function to expand the image and root partition
expand_image() {
    local expand_size="$1"
    local img_path="$2"
    
    log_step "expanding image to $expand_size..."
    
    # Get current image size
    local current_size=$(stat -c%s "$img_path")
    log_info "current image size: $(numfmt --to=iec $current_size)"
    
    # Convert target size to bytes
    local target_bytes=0
    if [[ "$expand_size" =~ ^[0-9]+G$ ]]; then
        target_bytes=$(( ${expand_size%G} * 1024 * 1024 * 1024 ))
    elif [[ "$expand_size" =~ ^[0-9]+M$ ]]; then
        target_bytes=$(( ${expand_size%M} * 1024 * 1024 ))
    elif [[ "$expand_size" =~ ^[0-9]+K$ ]]; then
        target_bytes=$(( ${expand_size%K} * 1024 ))
    else
        target_bytes=$expand_size
    fi
    
    log_info "target image size: $(numfmt --to=iec $target_bytes)"
    
    # Only expand if target size is larger than current size
    if [ "$target_bytes" -gt "$current_size" ]; then
        # Expand the image file to target size
        log_progress "expanding image file..."
        sudo truncate -s "$target_bytes" "$img_path"
        log_success "image expanded to $(numfmt --to=iec $target_bytes)"
    else
        log_info "image already at target size or larger"
    fi
    
    # Setup loop device for partition manipulation
    log_progress "setting up loop device..."
    local loop_dev=$(sudo losetup -f --show "$img_path")
    sudo partprobe "$loop_dev"
    
    # Get partition info before resize
    log_info "partition info before resize:"
    sudo fdisk -l "$loop_dev" | grep "^${loop_dev}p"
    
    # Use parted to resize the partition
    log_progress "resizing root partition..."
    sudo parted "$loop_dev" resizepart 2 100%
    
    # Get partition info after resize
    log_info "partition info after resize:"
    sudo fdisk -l "$loop_dev" | grep "^${loop_dev}p"
    
    # Clean up loop device
    sudo losetup -d "$loop_dev"
    
    log_success "image expansion completed successfully!"
}

MOUNT_DIR="mount"
BOOT_MOUNT="$MOUNT_DIR/boot"
ROOT_MOUNT="$MOUNT_DIR/root"

cleanup() {
    log_info "cleaning up..."
    while mountpoint -q "$ROOT_MOUNT"; do
        sudo umount "$ROOT_MOUNT"
    done
    while mountpoint -q "$BOOT_MOUNT"; do
        sudo umount "$BOOT_MOUNT"
    done
    if [ -e "$LOOP_DEV" ]; then
        sudo losetup -d "$LOOP_DEV"
    fi
    sudo rm -rf "$MOUNT_DIR"
    log_success "cleanup completed"
}

trap cleanup EXIT

mount_image() {
    sudo mkdir -p "$BOOT_MOUNT" "$ROOT_MOUNT"

    log_progress "mounting boot partition..."
    sudo mount "${LOOP_DEV}p1" "$BOOT_MOUNT"
    if [ $? -ne 0 ]; then
        log_error "failed to mount boot partition"
        exit 1
    fi

    log_progress "mounting root partition..."
    sudo mount "${LOOP_DEV}p2" "$ROOT_MOUNT"
    if [ $? -ne 0 ]; then
        log_error "failed to mount root partition"
        exit 1
    fi

    log_success "image mounted successfully!"
    log_info "boot partition mounted at: $BOOT_MOUNT"
    log_info "root partition mounted at: $ROOT_MOUNT"
}

# Expand image if requested
if [ -n "$EXPAND_SIZE" ] && [ "$EXPAND_SIZE" != "0" ]; then
    expand_image "$EXPAND_SIZE" "$IMG_PATH"
fi

# Setup loop device and resize filesystem before mounting
LOOP_DEV=$(sudo losetup -f --show "$IMG_PATH")
sudo partprobe "$LOOP_DEV"

# Resize filesystem to use all available space if image was expanded
if [ -n "$EXPAND_SIZE" ] && [ "$EXPAND_SIZE" != "0" ]; then
    log_step "resizing filesystem to use all available space..."
    
    # Check filesystem size before resize
    log_info "filesystem size before resize:"
    sudo dumpe2fs -h "${LOOP_DEV}p2" 2>/dev/null | grep "Block count\|Block size" || log_warning "could not get filesystem info"
    
    log_progress "checking filesystem first..."
    sudo e2fsck -f "${LOOP_DEV}p2"
    log_progress "resizing filesystem..."
    sudo resize2fs "${LOOP_DEV}p2"
    
    # Check filesystem size after resize
    log_info "filesystem size after resize:"
    sudo dumpe2fs -h "${LOOP_DEV}p2" 2>/dev/null | grep "Block count\|Block size" || log_warning "could not get filesystem info"
    
    # Re-read partition table to ensure it's updated
    log_progress "re-reading partition table..."
    sudo partprobe "$LOOP_DEV"
    
    log_success "filesystem resize completed!"
fi

# Check available space on root partition
log_info "checking available space on root partition..."

# Get partition info
log_info "partition information:"
sudo fdisk -l "$LOOP_DEV" | grep "^${LOOP_DEV}p"

# Get filesystem info
log_info "filesystem information:"
sudo dumpe2fs -h "${LOOP_DEV}p2" 2>/dev/null | grep -E "(Block count|Block size|Free blocks|Free inodes)" || log_warning "could not get filesystem info"

ROOT_SIZE=$(sudo blockdev --getsize64 "${LOOP_DEV}p2")
ROOT_SIZE_GB=$((ROOT_SIZE / 1024 / 1024 / 1024))
log_info "root partition size: ${ROOT_SIZE_GB}GB"

sudo mkdir -p "$ROOT_MOUNT/usr/include"
sudo mkdir -p "$ROOT_MOUNT/lib"

# copy modules to tools directory
copy_modules() {
    MODULE_INSTALL_DIR="build/modules-install/lib"
    if [ -d "$MODULE_INSTALL_DIR" ]; then
        log_info "module install directory found at: $MODULE_INSTALL_DIR"
        
        # Always clean up old modules first
        if [ -d "$ROOT_MOUNT/lib/modules" ]; then
            log_warning "removing old modules in root filesystem..."
            sudo rm -rf "$ROOT_MOUNT/lib/modules"
        fi
        
        # Check available space before copying
        MODULE_SIZE=$(du -sb "$MODULE_INSTALL_DIR/modules" 2>/dev/null | cut -f1)
        AVAILABLE_SPACE=$(df -B1 "$ROOT_MOUNT" | tail -1 | awk '{print $4}')
        
        log_info "module size: $(numfmt --to=iec $MODULE_SIZE)"
        log_info "available space: $(numfmt --to=iec $AVAILABLE_SPACE)"
        
        if [ "$MODULE_SIZE" -gt "$AVAILABLE_SPACE" ]; then
            log_error "not enough space to copy modules"
            log_error "need: $(numfmt --to=iec $MODULE_SIZE), available: $(numfmt --to=iec $AVAILABLE_SPACE)"
            exit 1
        fi
        
        log_progress "copying modules to lib/modules directory..."
        # if $ROOT_MOUNT/lib not exists, create it
        if [ ! -d "$ROOT_MOUNT/lib" ]; then
            sudo mkdir -p "$ROOT_MOUNT/lib"
        fi
        sudo cp -r "$MODULE_INSTALL_DIR/modules" "$ROOT_MOUNT/lib/modules"
        log_success "modules copied successfully"
    else
        log_warning "module install directory not found at: $MODULE_INSTALL_DIR, so we will not copy modules to tools directory"
    fi
}

# copy libbpf to tools directory
copy_libbpf() {
    LIBBPF_DIR="linux-git/samples/bpf"
    sudo mkdir -p "$ROOT_MOUNT/usr/share"
    # just copy the entire bpf folder into root /usr/share/bpf
    log_progress "copying libbpf to root /usr/share/bpf/..."
    sudo cp -r "$LIBBPF_DIR" "$ROOT_MOUNT/usr/share/bpf"
    log_success "libbpf copied to root /usr/share/bpf/"
}

mount_image

# Analyze filesystem usage
log_info "analyzing filesystem usage..."
log_info "largest directories in root filesystem:"
sudo du -h --max-depth=1 "$ROOT_MOUNT" | sort -hr | head -10

log_info "largest files in root filesystem:"
sudo find "$ROOT_MOUNT" -type f -exec du -h {} + 2>/dev/null | sort -hr | head -10

copy_modules
copy_libbpf

log_success "all operations completed successfully!"
log_info "SD card image is ready for use"