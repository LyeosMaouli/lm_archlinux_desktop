# In WSL2 Ubuntu terminal

cd /mnt/c/dev/lm_archlinux_desktop
pwd
ls -la

# From WSL2 to Windows

rsync -av ~/lm_archlinux_desktop/ /mnt/c/dev/lm_archlinux_desktop/

# From Windows to WSL2

rsync -av /mnt/c/dev/lm_archlinux_desktop/ ~/lm_archlinux_desktop/

# Test role structure (this should work now!)

ansible-galaxy role init --init-path roles test_role

# Check if it was created

ls -la roles/test_role/

# Run ansible-lint

ansible-lint local.yml

# Syntax check

ansible-playbook --syntax-check local.yml
ansible-playbook --syntax-check configs/ansible/playbooks/desktop.yml
