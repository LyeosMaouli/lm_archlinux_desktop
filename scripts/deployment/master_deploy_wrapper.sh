#!/bin/bash
#
# master_deploy_wrapper.sh - Backward compatibility wrapper
#
# DEPRECATED: Please use: ./scripts/deploy.sh [COMMAND] [OPTIONS]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_SCRIPT="$SCRIPT_DIR/../deploy.sh"

echo "⚠️  DEPRECATED: master_deploy.sh is deprecated!"
echo "Use: $NEW_SCRIPT [install|desktop|security|full] [OPTIONS]"
echo "Redirecting to full deployment..."
sleep 2

exec "$NEW_SCRIPT" "full" "$@"