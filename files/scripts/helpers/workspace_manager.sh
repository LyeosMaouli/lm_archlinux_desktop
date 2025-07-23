#!/bin/bash
# Workspace Manager for Hyprland
# Provides workspace management and application launching

# Get workspace info
get_workspace_info() {
    hyprctl workspaces -j | jq -r '.[] | "\(.id): \(.name) (\(.windows) windows)"'
}

# Switch to workspace
switch_workspace() {
    local workspace="$1"
    if [[ "$workspace" =~ ^[0-9]+$ ]]; then
        hyprctl dispatch workspace "$workspace"
    else
        echo "Invalid workspace number: $workspace"
        exit 1
    fi
}

# Move window to workspace
move_to_workspace() {
    local workspace="$1"
    if [[ "$workspace" =~ ^[0-9]+$ ]]; then
        hyprctl dispatch movetoworkspace "$workspace"
    else
        echo "Invalid workspace number: $workspace"
        exit 1
    fi
}

# Move window to workspace and follow
move_and_follow() {
    local workspace="$1"
    if [[ "$workspace" =~ ^[0-9]+$ ]]; then
        hyprctl dispatch movetoworkspacesilent "$workspace"
        hyprctl dispatch workspace "$workspace"
    else
        echo "Invalid workspace number: $workspace"
        exit 1
    fi
}

# Create new workspace
create_workspace() {
    local next_workspace
    next_workspace=$(hyprctl workspaces -j | jq '[.[] | .id] | max + 1')
    hyprctl dispatch workspace "$next_workspace"
    echo "Created and switched to workspace $next_workspace"
}

# Close workspace (move all windows to workspace 1)
close_workspace() {
    local current_workspace
    current_workspace=$(hyprctl activeworkspace -j | jq -r '.id')
    
    if [[ "$current_workspace" == "1" ]]; then
        echo "Cannot close workspace 1"
        exit 1
    fi
    
    # Move all windows to workspace 1
    local windows
    windows=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $current_workspace) | .address")
    
    for window in $windows; do
        hyprctl dispatch focuswindow "address:$window"
        hyprctl dispatch movetoworkspacesilent 1
    done
    
    # Switch to workspace 1
    hyprctl dispatch workspace 1
    echo "Closed workspace $current_workspace, moved windows to workspace 1"
}

# Launch application in new workspace
launch_in_new_workspace() {
    local app="$1"
    if [[ -z "${app:-}" ]]; then
        echo "No application specified"
        exit 1
    fi
    
    create_workspace
    sleep 0.5
    hyprctl dispatch exec "$app"
}

# Show workspace overview (requires eww or similar)
show_overview() {
    if command -v eww >/dev/null 2>&1; then
        eww open workspace-overview
    else
        # Fallback: show workspace info
        echo "Current workspaces:"
        get_workspace_info
    fi
}

# Main logic
case "${1:-}" in
    "info"|"list")
        get_workspace_info
        ;;
    "switch"|"go")
        switch_workspace "$2"
        ;;
    "move")
        move_to_workspace "$2"
        ;;
    "movefollow"|"mvf")
        move_and_follow "$2"
        ;;
    "new"|"create")
        create_workspace
        ;;
    "close"|"delete")
        close_workspace
        ;;
    "launch")
        launch_in_new_workspace "$2"
        ;;
    "overview")
        show_overview
        ;;
    *)
        echo "Usage: $0 [COMMAND] [ARGS]"
        echo "Commands:"
        echo "  info              - Show workspace information"
        echo "  switch NUM        - Switch to workspace NUM"
        echo "  move NUM          - Move current window to workspace NUM"
        echo "  movefollow NUM    - Move window to workspace NUM and follow"
        echo "  new               - Create new workspace"
        echo "  close             - Close current workspace"
        echo "  launch APP        - Launch APP in new workspace"
        echo "  overview          - Show workspace overview"
        exit 1
        ;;
esac