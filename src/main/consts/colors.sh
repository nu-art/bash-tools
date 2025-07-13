#!/bin/sh bash

COLOR_PREFIX="\033"
# Reset
NoColor="${COLOR_PREFIX}[0m"        # Text Reset

# Regular Colors
COLOR_Black="${COLOR_PREFIX}[0;30m"       # Black
COLOR_Red="${COLOR_PREFIX}[0;31m"         # Red
COLOR_Green="${COLOR_PREFIX}[0;32m"       # Green
COLOR_Yellow="${COLOR_PREFIX}[0;33m"      # Yellow
COLOR_Blue="${COLOR_PREFIX}[0;34m"        # Blue
COLOR_Purple="${COLOR_PREFIX}[0;35m"      # Purple
COLOR_Cyan="${COLOR_PREFIX}[0;36m"        # Cyan
COLOR_White="${COLOR_PREFIX}[0;37m"       # White
Gray="\e[37m"                       # White

# Bold
COLOR_BBlack="${COLOR_PREFIX}[1;30m"      # Black
COLOR_BRed="${COLOR_PREFIX}[1;31m"        # Red
COLOR_BGreen="${COLOR_PREFIX}[1;32m"      # Green
COLOR_BYellow="${COLOR_PREFIX}[1;33m"     # Yellow
COLOR_BBlue="${COLOR_PREFIX}[1;34m"       # Blue
COLOR_BPurple="${COLOR_PREFIX}[1;35m"     # Purple
COLOR_BCyan="${COLOR_PREFIX}[1;36m"       # Cyan
COLOR_BWhite="${COLOR_PREFIX}[1;37m"      # White

# Underline
COLOR_UBlack="${COLOR_PREFIX}[4;30m"      # Black
COLOR_URed="${COLOR_PREFIX}[4;31m"        # Red
COLOR_UGreen="${COLOR_PREFIX}[4;32m"      # Green
COLOR_UYellow="${COLOR_PREFIX}[4;33m"     # Yellow
COLOR_UBlue="${COLOR_PREFIX}[4;34m"       # Blue
COLOR_UPurple="${COLOR_PREFIX}[4;35m"     # Purple
COLOR_UCyan="${COLOR_PREFIX}[4;36m"       # Cyan
COLOR_UWhite="${COLOR_PREFIX}[4;37m"      # White

# Background
COLOR_On_Black="${COLOR_PREFIX}[40m"      # Black
COLOR_On_Red="${COLOR_PREFIX}[41m"        # Red
COLOR_On_Green="${COLOR_PREFIX}[42m"      # Green
COLOR_On_Yellow="${COLOR_PREFIX}[43m"     # Yellow
COLOR_On_Blue="${COLOR_PREFIX}[44m"       # Blue
COLOR_On_Purple="${COLOR_PREFIX}[45m"     # Purple
COLOR_On_Cyan="${COLOR_PREFIX}[46m"       # Cyan
COLOR_On_White="${COLOR_PREFIX}[47m"      # White

# High Intensity
COLOR_IBlack="${COLOR_PREFIX}[0;90m"      # Black
COLOR_IRed="${COLOR_PREFIX}[0;91m"        # Red
COLOR_IGreen="${COLOR_PREFIX}[0;92m"      # Green
COLOR_IYellow="${COLOR_PREFIX}[0;93m"     # Yellow
COLOR_IBlue="${COLOR_PREFIX}[0;94m"       # Blue
COLOR_IPurple="${COLOR_PREFIX}[0;95m"     # Purple
COLOR_ICyan="${COLOR_PREFIX}[0;96m"       # Cyan
COLOR_IWhite="${COLOR_PREFIX}[0;97m"      # White

# Bold High Intensity
COLOR_BIBlack="${COLOR_PREFIX}[1;90m"     # Black
COLOR_BIRed="${COLOR_PREFIX}[1;91m"       # Red
COLOR_BIGreen="${COLOR_PREFIX}[1;92m"     # Green
COLOR_BIYellow="${COLOR_PREFIX}[1;93m"    # Yellow
COLOR_BIBlue="${COLOR_PREFIX}[1;94m"      # Blue
COLOR_BIPurple="${COLOR_PREFIX}[1;95m"    # Purple
COLOR_BICyan="${COLOR_PREFIX}[1;96m"      # Cyan
COLOR_BIWhite="${COLOR_PREFIX}[1;97m"     # White

# High Intensity backgrounds
COLOR_On_IBlack="${COLOR_PREFIX}[0;100m"  # Black
COLOR_On_IRed="${COLOR_PREFIX}[0;101m"    # Red
COLOR_On_IGreen="${COLOR_PREFIX}[0;102m"  # Green
COLOR_On_IYellow="${COLOR_PREFIX}[0;103m" # Yellow
COLOR_On_IBlue="${COLOR_PREFIX}[0;104m"   # Blue
COLOR_On_IPurple="${COLOR_PREFIX}[0;105m" # Purple
COLOR_On_ICyan="${COLOR_PREFIX}[0;106m"   # Cyan
COLOR_On_IWhite="${COLOR_PREFIX}[0;107m"  # White
