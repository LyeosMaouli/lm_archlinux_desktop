#!/bin/bash
# Hyprland Autostart Script
# Essential applications and services to start with Hyprland

# Set environment variables
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland

# Wait for Hyprland to fully start
sleep 2

# Start Waybar (status bar)
if command -v waybar >/dev/null 2>&1; then
    waybar &
fi

# Start notification daemon
if command -v mako >/dev/null 2>&1; then
    mako &
fi

# Start wallpaper daemon
if command -v hyprpaper >/dev/null 2>&1; then
    hyprpaper &
elif command -v swaybg >/dev/null 2>&1; then
    swaybg -i ~/.config/hypr/wallpaper.jpg &
fi

# Start authentication agent
if command -v /usr/lib/polkit-kde-authentication-agent-1 >/dev/null 2>&1; then
    /usr/lib/polkit-kde-authentication-agent-1 &
elif command -v /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 >/dev/null 2>&1; then
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
fi

# Start clipboard manager
if command -v wl-paste >/dev/null 2>&1; then
    wl-paste --watch cliphist store &
fi

# Start idle daemon
if command -v hypridle >/dev/null 2>&1; then
    hypridle &
fi

# Start network manager applet
if command -v nm-applet >/dev/null 2>&1; then
    nm-applet --indicator &
fi

# Start bluetooth applet
if command -v blueman-applet >/dev/null 2>&1; then
    blueman-applet &
fi

# Start volume control applet
if command -v pavucontrol >/dev/null 2>&1; then
    # Don't start pavucontrol automatically, just ensure it's available
    :
fi

# Profile-specific autostart
PROFILE_AUTOSTART="/home/$USER/.config/hypr/autostart-profile.sh"
if [[ -f "$PROFILE_AUTOSTART" ]]; then
    source "$PROFILE_AUTOSTART"
fi