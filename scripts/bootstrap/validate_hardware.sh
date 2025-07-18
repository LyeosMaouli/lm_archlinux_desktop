#!/bin/bash
# scripts/validate_hardware.sh - Comprehensive hardware detection

detect_hardware() {
    local config_file="configs/hardware_config.json"
    
    # GPU Detection
    local gpu_vendor=$(lspci | grep -i vga | head -1 | cut -d: -f3)
    local gpu_driver="intel"
    
    if echo "$gpu_vendor" | grep -i nvidia; then
        gpu_driver="nvidia"
    elif echo "$gpu_vendor" | grep -i amd; then
        gpu_driver="amd"
    fi
    
    # Network interface detection
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # Generate hardware configuration
    cat > "$config_file" << EOF
{
    "hardware": {
        "gpu": {
            "vendor": "$gpu_vendor",
            "driver": "$gpu_driver"
        },
        "network": {
            "interface": "$interface"
        },
        "hostname": "phoenix",
        "user": "lyeosmaouli"
    }
}
EOF
    
    echo "Hardware configuration saved to $config_file"
}

detect_hardware