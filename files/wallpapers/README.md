# Wallpapers Directory

This directory contains wallpaper collections for the Hyprland desktop environment.

## Structure

- `landscape/` - Landscape orientation wallpapers (1920x1080, 2560x1440, 3840x2160)
- `abstract/` - Abstract and artistic wallpapers
- `nature/` - Nature and scenery wallpapers
- `minimal/` - Minimalist wallpapers
- `dark/` - Dark theme wallpapers
- `default.jpg` - Default fallback wallpaper

## Supported Formats

- JPEG (.jpg, .jpeg)
- PNG (.png)
- WebP (.webp)

## Configuration

Wallpapers are configured in:
- `configs/ansible/roles/hyprland_desktop/templates/hyprpaper.conf.j2`
- Hyprland configuration files

## Adding Wallpapers

1. Place wallpaper files in appropriate subdirectories
2. Update hyprpaper configuration if needed
3. Ensure proper permissions (644)

## Default Wallpaper

The system falls back to `default.jpg` if configured wallpapers are not found.
