#!/bin/bash
# Volume Control Helper Script for Hyprland
# Provides volume control with notifications

# Dependencies: pipewire, wireplumber, notify-send

# Get current volume level
get_volume() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2 * 100}'
}

# Get mute status
is_muted() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "MUTED"
}

# Send notification with volume level
send_notification() {
    local volume
    volume=$(get_volume)
    local icon
    
    if is_muted; then
        icon="audio-volume-muted"
        notify-send "Volume" "Muted" --icon="$icon" --hint=int:value:0 --expire-time=2000
    else
        if (( $(echo "$volume < 30" | bc -l) )); then
            icon="audio-volume-low"
        elif (( $(echo "$volume < 70" | bc -l) )); then
            icon="audio-volume-medium"
        else
            icon="audio-volume-high"
        fi
        notify-send "Volume" "${volume}%" --icon="$icon" --hint=int:value:"$volume" --expire-time=2000
    fi
}

# Volume control functions
volume_up() {
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    send_notification
}

volume_down() {
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    send_notification
}

volume_mute() {
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    send_notification
}

volume_set() {
    local level="$1"
    if [[ "$level" =~ ^[0-9]+$ ]] && [[ $level -ge 0 ]] && [[ $level -le 100 ]]; then
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${level}%"
        send_notification
    else
        echo "Invalid volume level: $level (must be 0-100)"
        exit 1
    fi
}

# Microphone control
mic_mute() {
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    local muted
    if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q "MUTED"; then
        muted="Muted"
        icon="microphone-sensitivity-muted"
    else
        muted="Unmuted"
        icon="microphone-sensitivity-high"
    fi
    notify-send "Microphone" "$muted" --icon="$icon" --expire-time=2000
}

# Main logic
case "${1:-}" in
    "up"|"+")
        volume_up
        ;;
    "down"|"-")
        volume_down
        ;;
    "mute"|"toggle")
        volume_mute
        ;;
    "mic"|"microphone")
        mic_mute
        ;;
    "set")
        volume_set "$2"
        ;;
    "get")
        get_volume
        ;;
    *)
        echo "Usage: $0 [up|down|mute|mic|set LEVEL|get]"
        echo "  up    - Increase volume by 5%"
        echo "  down  - Decrease volume by 5%"
        echo "  mute  - Toggle mute"
        echo "  mic   - Toggle microphone mute"
        echo "  set   - Set volume to specific level (0-100)"
        echo "  get   - Get current volume level"
        exit 1
        ;;
esac