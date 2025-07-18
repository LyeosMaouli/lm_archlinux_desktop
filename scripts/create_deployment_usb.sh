#!/bin/bash
# scripts/create_deployment_usb.sh - Production USB image creation

set -euo pipefail

# Configuration
WORK_DIR="/tmp/arch-deployment-usb"
OUTPUT_DIR="/opt/deployment-images"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
IMAGE_NAME="arch-hyprland-deployment_$TIMESTAMP.iso"

create_custom_iso() {
    # Copy archiso profile
    cp -r /usr/share/archiso/configs/releng/ "$WORK_DIR/archiso-profile"
    
    # Add custom packages
    cat >> "$WORK_DIR/archiso-profile/packages.x86_64" << 'EOF'
git
python
python-pip
ansible
tmux
vim
curl
wget
intel-ucode
mesa
tpm2-tools
EOF
    
    # Embed configuration files
    mkdir -p "$WORK_DIR/archiso-profile/airootfs/opt/arch-deployment"
    cp -r configs/ "$WORK_DIR/archiso-profile/airootfs/opt/arch-deployment/"
    cp -r scripts/ "$WORK_DIR/archiso-profile/airootfs/opt/arch-deployment/"
    
    # Create autorun script
    cat > "$WORK_DIR/archiso-profile/airootfs/usr/local/bin/autorun.sh" << 'EOF'
#!/bin/bash
cd /opt/arch-deployment
./scripts/master_deploy.sh full
EOF
    
    chmod +x "$WORK_DIR/archiso-profile/airootfs/usr/local/bin/autorun.sh"
    
    # Build ISO
    mkarchiso -v -w "$WORK_DIR/build" -o "$OUTPUT_DIR" "$WORK_DIR/archiso-profile"
    
    echo "Custom ISO created: $OUTPUT_DIR/$IMAGE_NAME"
}

create_custom_iso