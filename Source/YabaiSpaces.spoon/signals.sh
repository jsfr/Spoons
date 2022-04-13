#!/usr/bin/env sh

yabai="$YABAI_PATH"

$yabai -m signal --add event=application_launched    action="hs -A -c 'spoon.YabaiSpaces:update()'"
$yabai -m signal --add event=application_deactivated action="hs -A -c 'spoon.YabaiSpaces:update()'"
$yabai -m signal --add event=application_terminated  action="hs -A -c 'spoon.YabaiSpaces:update()'"
$yabai -m signal --add event=space_changed           action="hs -A -c 'spoon.YabaiSpaces:update()'"
