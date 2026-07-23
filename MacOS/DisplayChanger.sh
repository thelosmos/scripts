#!/bin/bash
DP="/opt/homebrew/bin/displayplacer"
SCREEN_1="6AA432C0-05F6-4C60-8E10-1C16192D6944" # Dell 34" Widescreen Bottom
SCREEN_2="59F17B16-BAC7-4310-865F-C0E5B9FE6F9C" # Dell 27" Widescreen Portrait Right
SCREEN_3="A7D583A8-6DBE-42F9-9C2E-252B7975FC46" # LG 34" Widescreen Top
# Fetch current layout configuration
CONFIG=$($DP list)

# Check if the first screen is currently enabled
if echo "$CONFIG" | grep -q "$SCREEN_1.*enabled:true"; then
    # If it's on, turn BOTH monitors off
    $DP "id:$SCREEN_1 enabled:true" "id:$SCREEN_2 enabled:true"
else
    # If it's off, turn BOTH monitors back on
    $DP "id:$SCREEN_1 enabled:true" "id:$SCREEN_2 enabled:true"
fi