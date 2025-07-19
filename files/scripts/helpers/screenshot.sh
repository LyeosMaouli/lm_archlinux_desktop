#!/bin/bash
# Screenshot Helper Script for Hyprland
# Provides various screenshot functions

# Dependencies: grim, slurp, wl-clipboard, notify-send

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"

# Function to take full screen screenshot
fullscreen_screenshot() {
    local filename="$SCREENSHOT_DIR/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png"
    grim "$filename"
    wl-copy < "$filename"
    notify-send "Screenshot" "Full screen captured: $(basename "$filename")" --icon="$filename"
}

# Function to take area screenshot
area_screenshot() {
    local filename="$SCREENSHOT_DIR/screenshot-area-$(date +%Y-%m-%d_%H-%M-%S).png"
    grim -g "$(slurp)" "$filename"
    wl-copy < "$filename"
    notify-send "Screenshot" "Area captured: $(basename "$filename")" --icon="$filename"
}

# Function to take window screenshot
window_screenshot() {
    local filename="$SCREENSHOT_DIR/screenshot-window-$(date +%Y-%m-%d_%H-%M-%S).png"
    local window_info
    window_info=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    grim -g "$window_info" "$filename"
    wl-copy < "$filename"
    notify-send "Screenshot" "Window captured: $(basename "$filename")" --icon="$filename"
}

# Function to take screenshot and upload (if imgur or similar is configured)
upload_screenshot() {
    local temp_file="/tmp/screenshot-$(date +%s).png"
    grim -g "$(slurp)" "$temp_file"
    
    # Example upload to imgur (requires imgur.sh or similar)
    if command -v imgur.sh >/dev/null 2>&1; then
        local url
        url=$(imgur.sh "$temp_file")
        echo "$url" | wl-copy
        notify-send "Screenshot" "Uploaded and URL copied: $url"
    else
        # Fallback: just copy to clipboard
        wl-copy < "$temp_file"
        notify-send "Screenshot" "Screenshot copied to clipboard"
    fi
    
    rm -f "$temp_file"
}

# Main logic based on argument
case "${1:-fullscreen}" in
    "fullscreen"|"full")
        fullscreen_screenshot
        ;;
    "area"|"region")
        area_screenshot
        ;;
    "window")
        window_screenshot
        ;;
    "upload")
        upload_screenshot
        ;;
    *)
        echo "Usage: $0 [fullscreen|area|window|upload]"
        echo "  fullscreen - Capture entire screen"
        echo "  area       - Select area to capture"
        echo "  window     - Capture active window"
        echo "  upload     - Capture area and upload"
        exit 1
        ;;
esac