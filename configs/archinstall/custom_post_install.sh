# configs/archinstall/custom_post_install.sh - TPM2 setup
#!/bin/bash

setup_tpm2_luks() {
    local root_device="/dev/nvme0n1p2"
    
    # Install TPM2 tools
    pacman -S --noconfirm tpm2-tools
    
    # Generate recovery key
    systemd-cryptenroll "$root_device" --recovery-key
    
    # Enroll TPM2 key with PCR 7 (Secure Boot state)
    systemd-cryptenroll "$root_device" --tpm2-device=auto --tpm2-pcrs=7
    
    # Configure crypttab for TPM2
    echo "root UUID=$(blkid -s UUID -o value $root_device) none tpm2-device=auto" >> /etc/crypttab
    
    # Rebuild initramfs
    mkinitcpio -P
}

# Execute after chroot
setup_tpm2_luks