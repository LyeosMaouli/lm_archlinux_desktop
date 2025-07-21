#!/bin/bash
#
# master_auto_deploy_wrapper.sh - Backward compatibility wrapper
#
# DEPRECATED: Please use: ./scripts/deploy.sh full [OPTIONS]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_SCRIPT="$SCRIPT_DIR/../deploy.sh"

echo "⚠️  DEPRECATED: master_auto_deploy.sh is deprecated!"
echo "Use: $NEW_SCRIPT full [OPTIONS]"
echo "Redirecting..."
sleep 2

if [[ ! -f "$NEW_SCRIPT" ]]; then
    echo "❌ Error: New deployment script not found"
    exit 1
fi

# Map arguments and execute
declare -a new_args=("full")
new_args+=("$@")

exec "$NEW_SCRIPT" "${new_args[@]}"