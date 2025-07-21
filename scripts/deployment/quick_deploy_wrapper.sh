#!/bin/bash
#
# quick_deploy_wrapper.sh - Backward compatibility wrapper
#
# DEPRECATED: Please use: ./scripts/deploy.sh full [OPTIONS]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_SCRIPT="$SCRIPT_DIR/../deploy.sh"

echo "⚠️  DEPRECATED: quick_deploy.sh is deprecated!"
echo "Use: $NEW_SCRIPT full [OPTIONS]"
echo "Redirecting..."
sleep 2

exec "$NEW_SCRIPT" "full" "$@"