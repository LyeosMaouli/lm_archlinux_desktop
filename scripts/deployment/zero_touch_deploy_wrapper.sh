#!/bin/bash
#
# zero_touch_deploy_wrapper.sh - Backward compatibility wrapper
#
# This wrapper maintains backward compatibility with the original zero_touch_deploy.sh
# while redirecting calls to the new unified deploy.sh script.
#
# DEPRECATED: This script is deprecated and will be removed in a future version.
# Please use: ./scripts/deploy.sh full [OPTIONS]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_SCRIPT="$SCRIPT_DIR/../deploy.sh"

# Show deprecation warning
echo "=========================================="
echo "  DEPRECATED SCRIPT WARNING"
echo "=========================================="
echo "⚠️  The script 'zero_touch_deploy.sh' is deprecated!"
echo ""
echo "Please use the new unified deployment script:"
echo "  $NEW_SCRIPT full [OPTIONS]"
echo ""
echo "This wrapper will be removed in a future version."
echo "Update your scripts and documentation to use the new syntax."
echo ""
echo "Redirecting to new script in 3 seconds..."
echo "=========================================="

# Give users time to see the warning
sleep 3

# Check if new script exists
if [[ ! -f "$NEW_SCRIPT" ]]; then
    echo "❌ Error: New deployment script not found at $NEW_SCRIPT"
    echo "Please ensure the refactored scripts are properly installed."
    exit 1
fi

# Map old arguments to new format
declare -a new_args=("full")

while [[ $# -gt 0 ]]; do
    case $1 in
        --password-mode)
            new_args+=("--password" "$2")
            shift 2
            ;;
        --password-file)
            new_args+=("--password-file" "$2")
            shift 2
            ;;
        --hostname)
            new_args+=("--hostname" "$2")
            shift 2
            ;;
        --user)
            new_args+=("--user" "$2")
            shift 2
            ;;
        --profile)
            new_args+=("--profile" "$2")
            shift 2
            ;;
        --encryption)
            new_args+=("--encryption")
            shift
            ;;
        --no-encryption)
            new_args+=("--no-encryption")
            shift
            ;;
        --network)
            new_args+=("--network" "$2")
            shift 2
            ;;
        --config)
            new_args+=("--config" "$2")
            shift 2
            ;;
        --verbose|-v)
            new_args+=("--verbose")
            shift
            ;;
        --quiet|-q)
            new_args+=("--quiet")
            shift
            ;;
        --dry-run)
            new_args+=("--dry-run")
            shift
            ;;
        --help|-h)
            new_args+=("--help")
            shift
            ;;
        *)
            echo "⚠️  Unknown argument: $1 (passing through to new script)"
            new_args+=("$1")
            shift
            ;;
    esac
done

# Execute the new script
echo "🔄 Executing: $NEW_SCRIPT ${new_args[*]}"
echo ""

exec "$NEW_SCRIPT" "${new_args[@]}"