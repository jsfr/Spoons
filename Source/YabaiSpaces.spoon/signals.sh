#!/usr/bin/env sh

yabai="$YABAI_PATH"

$yabai -m signal --add label=hammerspoon_spaces_1 event=application_launched    action="hs -A -c 'spoon.YabaiSpaces:update()'"
$yabai -m signal --add label=hammerspoon_spaces_2 event=application_deactivated action="hs -A -c 'spoon.YabaiSpaces:update()'"
$yabai -m signal --add label=hammerspoon_spaces_3 event=application_terminated  action="hs -A -c 'spoon.YabaiSpaces:update()'"
$yabai -m signal --add label=hammerspoon_spaces_4 event=space_changed           action="hs -A -c 'spoon.YabaiSpaces:update()'"
