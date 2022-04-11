#!/usr/bin/env sh

yabai="$YABAI_PATH"
jq="$JQ_PATH"

number_of_sticky_windows=$(
        $yabai -m query --windows |
                $jq -r "[.[] | select(.\"is-sticky\" == true) | .id] | unique | length"
)

$yabai -m query --spaces |
        $jq -r "[.[] | select((.windows | length > ${number_of_sticky_windows}) or .\"has-focus\" == true)]
        | reduce .[] as \$i (
        {shift: 0, focused: 0, spaces: []};
                if \$i.\"is-native-fullscreen\" == true then
                        {shift: (.shift + 1), focused: .focused, spaces: (.spaces + [\"f\"])}
                elif \$i.\"has-focus\" == true then
                        {shift: .shift, focused: (\$i.index - .shift), spaces: (.spaces + [\$i.index - .shift])}
                else
                        {shift: .shift, focused: .focused, spaces: (.spaces + [\$i.index - .shift])}
                end
        )"
