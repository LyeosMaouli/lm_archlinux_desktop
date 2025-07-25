#!/bin/bash
#
# Terminal Formatting Library
# Provides consistent terminal formatting functions across all scripts
#

# Source color definitions if not already available
if [[ -z "${RED:-}" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly PURPLE='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly WHITE='\033[1;37m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly NC='\033[0m' # No Color
fi

# Terminal capability detection
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
TERM_COLORS=$(tput colors 2>/dev/null || echo 8)

#
# Core Formatting Functions
#

# Strip ANSI color codes for accurate length calculation
strip_ansi() {
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# Get terminal width with fallback
get_terminal_width() {
    tput cols 2>/dev/null || echo 80
}

# Draw a formatted box with title and content
draw_box() {
    local width=${1:-60}
    local title="$2"
    local content="$3"
    
    # Ensure minimum width
    if [[ $width -lt 20 ]]; then
        width=20
    fi
    
    # Use fallback characters if Unicode not supported
    local tl="┌" tr="┐" bl="└" br="┘" h="─" v="│" 
    local cross="├" rcross="┤"
    
    if [[ $TERM_COLORS -lt 8 ]]; then
        tl="+" tr="+" bl="+" br="+" h="-" v="|" cross="+" rcross="+"
    fi
    
    # Top border
    printf "${BLUE}%s" "$tl"
    printf "${h}%.0s" $(seq 1 $((width - 2)))
    printf "%s${NC}\n" "$tr"
    
    # Title
    if [[ -n "$title" ]]; then
        local title_clean=$(strip_ansi "$title")
        local title_len=${#title_clean}
        local padding=$(( (width - title_len - 4) / 2 ))
        local right_padding=$((width - title_len - padding - 3))
        
        printf "${BLUE}%s${NC}" "$v"
        printf " %.0s" $(seq 1 $padding)
        printf "${BOLD}%s${NC}" "$title"
        printf " %.0s" $(seq 1 $right_padding)
        printf "${BLUE}%s${NC}\n" "$v"
        
        # Separator
        printf "${BLUE}%s" "$cross"
        printf "${h}%.0s" $(seq 1 $((width - 2)))
        printf "%s${NC}\n" "$rcross"
    fi
    
    # Content
    if [[ -n "$content" ]]; then
        while IFS= read -r line; do
            # Handle empty lines
            if [[ -z "$line" ]]; then
                printf "${BLUE}%s${NC}" "$v"
                printf " %.0s" $(seq 1 $((width - 2)))
                printf "${BLUE}%s${NC}\n" "$v"
                continue
            fi
            
            # Strip color codes for length calculation
            local line_clean=$(strip_ansi "$line")
            local line_len=${#line_clean}
            local content_padding=$((width - line_len - 4))
            
            # Ensure padding is not negative
            if [[ $content_padding -lt 0 ]]; then
                content_padding=0
            fi
            
            printf "${BLUE}%s${NC} %s" "$v" "$line"
            printf " %.0s" $(seq 1 $content_padding)
            printf " ${BLUE}%s${NC}\n" "$v"
        done <<< "$content"
    fi
    
    # Bottom border
    printf "${BLUE}%s" "$bl"
    printf "${h}%.0s" $(seq 1 $((width - 2)))
    printf "%s${NC}\n" "$br"
}

# Draw a simple banner
draw_banner() {
    local title="$1"
    local subtitle="$2"
    local width=${3:-$(get_terminal_width)}
    
    # Ensure reasonable width
    if [[ $width -gt 100 ]]; then
        width=100
    elif [[ $width -lt 60 ]]; then
        width=60
    fi
    
    local content=""
    if [[ -n "$subtitle" ]]; then
        content="${GREEN}$title${NC}

${YELLOW}$subtitle${NC}"
    else
        content="${GREEN}$title${NC}"
    fi
    
    draw_box "$width" "" "$content"
}

# Printf with proper width calculation (strips ANSI codes)
printf_with_width() {
    local format="$1"
    local text="$2"
    local width="$3"
    
    local text_clean=$(strip_ansi "$text")
    local text_len=${#text_clean}
    
    # Create format string with calculated width
    local width_format="${format/%-*s/%-${width}s}"
    printf "$width_format" "$text"
}

# Show success box (compatible with deploy.sh)
show_success_box() {
    local success_msg="$1"
    local details="$2"
    local width=${3:-70}
    
    echo
    local content="${GREEN}✓ $success_msg${NC}"
    if [[ -n "$details" ]]; then
        content="${content}

${DIM}$details${NC}"
    fi
    draw_box "$width" "${GREEN}Success${NC}" "$content"
    echo
}

# Show error box
show_error_box() {
    local error_msg="$1"
    local details="$2"
    local width=${3:-70}
    
    echo
    local content="${RED}✗ $error_msg${NC}"
    if [[ -n "$details" ]]; then
        content="${content}

${DIM}$details${NC}"
    fi
    draw_box "$width" "${RED}Error${NC}" "$content"
    echo
}

# Show warning box
show_warning_box() {
    local warning_msg="$1"
    local details="$2"
    local width=${3:-70}
    
    echo
    local content="${YELLOW}⚠ $warning_msg${NC}"
    if [[ -n "$details" ]]; then
        content="${content}

${DIM}$details${NC}"
    fi
    draw_box "$width" "${YELLOW}Warning${NC}" "$content"
    echo
}

# Show info box
show_info_box() {
    local info_msg="$1"
    local details="$2"
    local width=${3:-70}
    
    echo
    local content="${BLUE}ℹ $info_msg${NC}"
    if [[ -n "$details" ]]; then
        content="${content}

${DIM}$details${NC}"
    fi
    draw_box "$width" "${BLUE}Information${NC}" "$content"
    echo
}