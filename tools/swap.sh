#!/bin/bash

# Swap file management script
# Create a swap file if it doesn't exist, or recreate if size is incorrect

# Default values
SWAP_FILE="/swapfile"
SWAP_SIZE="32G"
ACTION="auto"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo
    echo "Commands:"
    echo "  auto                    Auto manage swap file (default)"
    echo "  enable                  Enable existing swap file"
    echo "  disable                 Disable swap file"
    echo "  status                  Show swap status"
    echo
    echo "Options:"
    echo "  -s, --size SIZE         Specify swap file size (default: 32G)"
    echo "  -f, --file FILE         Specify swap file path (default: /swapfile)"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0                      # Auto manage 32G swap file"
    echo "  $0 --size 16G           # Auto manage 16G swap file"
    echo "  $0 enable               # Enable existing swap file"
    echo "  $0 disable              # Disable swap file"
    echo "  $0 status               # Show current swap status"
    echo "  $0 -s 8G -f /swap2     # Auto manage 8G swap file at /swap2"
    echo
}

# Function to show swap status
show_status() {
    echo "=== Swap Status ==="
    echo "Target file: $SWAP_FILE"
    echo "Target size: $SWAP_SIZE"
    echo
    
    if [[ -f "$SWAP_FILE" ]]; then
        echo "✓ Swap file exists: $SWAP_FILE"
        
        # Get file size
        EXISTING_SIZE=$(stat -c%s "$SWAP_FILE")
        EXISTING_SIZE_GB=$((EXISTING_SIZE / 1024 / 1024 / 1024))
        echo "File size: ${EXISTING_SIZE_GB}G"
        
        # Check if enabled
        if swapon --show | grep -q "$SWAP_FILE"; then
            echo "Status: ✓ Enabled"
        else
            echo "Status: ⚠ Disabled"
        fi
    else
        echo "✗ Swap file does not exist: $SWAP_FILE"
    fi
    
    echo
    echo "System swap status:"
    swapon --show
    echo
    free -h
}

# Function to enable swap
enable_swap() {
    echo "=== Enabling Swap ==="
    echo "Target file: $SWAP_FILE"
    echo
    
    if [[ ! -f "$SWAP_FILE" ]]; then
        echo "Error: Swap file does not exist: $SWAP_FILE"
        echo "Please create it first or use 'auto' command"
        exit 1
    fi
    
    if swapon --show | grep -q "$SWAP_FILE"; then
        echo "✓ Swap file is already enabled"
    else
        echo "Enabling swap file..."
        if swapon "$SWAP_FILE"; then
            echo "✓ Swap file enabled successfully"
        else
            echo "✗ Failed to enable swap file"
            exit 1
        fi
    fi
    
    echo
    show_status
}

# Function to disable swap
disable_swap() {
    echo "=== Disabling Swap ==="
    echo "Target file: $SWAP_FILE"
    echo
    
    if swapon --show | grep -q "$SWAP_FILE"; then
        echo "Disabling swap file..."
        if swapoff "$SWAP_FILE"; then
            echo "✓ Swap file disabled successfully"
        else
            echo "✗ Failed to disable swap file"
            exit 1
        fi
    else
        echo "✓ Swap file is already disabled"
    fi
    
    echo
    show_status
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--size)
            SWAP_SIZE="$2"
            shift 2
            ;;
        -f|--file)
            SWAP_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        auto|enable|disable|status)
            ACTION="$1"
            shift
            ;;
        *)
            echo "Unknown option or command: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if running with root privileges (except for status command)
if [[ $EUID -ne 0 && "$ACTION" != "status" ]]; then
   echo "Error: This script requires root privileges"
   echo "Please run with: sudo $0"
   exit 1
fi

# Execute based on action
case $ACTION in
    status)
        show_status
        exit 0
        ;;
    enable)
        enable_swap
        exit 0
        ;;
    disable)
        disable_swap
        exit 0
        ;;
    auto)
        # Original auto management logic
        echo "=== Swap File Management Script ==="
        echo "Target file: $SWAP_FILE"
        echo "Target size: $SWAP_SIZE"
        echo

        # Check if swap file already exists
        if [[ -f "$SWAP_FILE" ]]; then
            echo "✓ Swap file already exists: $SWAP_FILE"
            
            # Get the size of existing swap file
            EXISTING_SIZE=$(stat -c%s "$SWAP_FILE")
            EXISTING_SIZE_GB=$((EXISTING_SIZE / 1024 / 1024 / 1024))
            
            echo "Current size: ${EXISTING_SIZE_GB}G"
            
            # Calculate target size in GB for comparison
            TARGET_SIZE_GB=$(echo "$SWAP_SIZE" | sed 's/[^0-9]//g')
            
            # Check if it's already the correct size
            if [[ $EXISTING_SIZE_GB -eq $TARGET_SIZE_GB ]]; then
                echo "✓ Swap file size is correct ($SWAP_SIZE)"
                
                # Check if it's already enabled
                if swapon --show | grep -q "$SWAP_FILE"; then
                    echo "✓ Swap file is enabled"
                else
                    echo "⚠  Swap file exists but is not enabled"
                    echo "   Enable command: sudo swapon $SWAP_FILE"
                fi
                
                echo
                echo "Current system swap status:"
                swapon --show
                echo
                free -h
                
            else
                echo "⚠  Swap file size is incorrect (expected $SWAP_SIZE, actual ${EXISTING_SIZE_GB}G)"
                echo "   Removing existing swap file and recreating..."
                
                # Disable swap if it's currently active
                if swapon --show | grep -q "$SWAP_FILE"; then
                    echo "   Disabling current swap..."
                    swapoff "$SWAP_FILE"
                fi
                
                # Remove the existing swap file
                rm -f "$SWAP_FILE"
                echo "   Removed existing swap file"
                
                # Continue to creation section
                RECREATE=true
            fi
            
        else
            echo "✗ Swap file does not exist, creating..."
            RECREATE=true
        fi

        # Create or recreate swap file
        if [[ "$RECREATE" == "true" ]]; then
            # Check disk space
            DISK_SPACE=$(df / | awk 'NR==2 {print $4}')
            DISK_SPACE_GB=$((DISK_SPACE / 1024 / 1024))
            TARGET_SIZE_GB=$(echo "$SWAP_SIZE" | sed 's/[^0-9]//g')
            
            if [[ $DISK_SPACE_GB -lt $TARGET_SIZE_GB ]]; then
                echo "Error: Insufficient disk space"
                echo "Available space: ${DISK_SPACE_GB}G"
                echo "Required space: $SWAP_SIZE"
                exit 1
            fi
            
            echo "✓ Sufficient disk space (${DISK_SPACE_GB}G available)"
            
            # Create swap file
            echo "Creating $SWAP_SIZE swap file..."
            if fallocate -l "$SWAP_SIZE" "$SWAP_FILE"; then
                echo "✓ Swap file created successfully"
            else
                echo "✗ Failed to create swap file"
                exit 1
            fi
            
            # Set correct permissions
            chmod 600 "$SWAP_FILE"
            echo "✓ Permissions set correctly"
            
            # Format as swap
            mkswap "$SWAP_FILE"
            echo "✓ Swap formatting completed"
            
            # Enable swap
            swapon "$SWAP_FILE"
            echo "✓ Swap enabled"
            
            echo
            echo "Swap file creation completed!"
            echo "File location: $SWAP_FILE"
            echo "File size: $SWAP_SIZE"
            echo
            echo "Current system swap status:"
            swapon --show
            echo
            free -h
            
            # Prompt to add to fstab
            echo
            echo "Note: To enable swap on boot, add the following line to /etc/fstab:"
            echo "$SWAP_FILE none swap sw 0 0"
        fi

        echo
        echo "=== Script execution completed ==="
        ;;
esac
