#!/bin/bash
#
# auto_deploy_wrapper.sh - Backward compatibility wrapper
#
# DEPRECATED: Please use: ./scripts/deploy.sh desktop [OPTIONS]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_SCRIPT="$SCRIPT_DIR/../deploy.sh"

echo "⚠️  DEPRECATED: auto_deploy.sh is deprecated!"
echo "Use: $NEW_SCRIPT desktop [OPTIONS]"
echo "Redirecting..."
sleep 2

exec "$NEW_SCRIPT" "desktop" "$@"