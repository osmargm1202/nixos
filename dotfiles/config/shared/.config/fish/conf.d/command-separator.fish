# Print a subtle separator after each interactive command.
# Override with:
#   set -g fish_command_separator_glyph "·"
#   set -g fish_command_separator_color brblack
status is-interactive; or return

function __orgm_command_separator --on-event fish_postexec --description 'Draw command separator after each command'
    set -l glyph "·"
    if set -q fish_command_separator_glyph
        set glyph $fish_command_separator_glyph
    end

    set -l color brblack
    if set -q fish_command_separator_color
        set color $fish_command_separator_color
    end

    set -l cols $COLUMNS
    if test -z "$cols"; or test "$cols" -lt 1
        set cols 80
    end

    set -l unit "$glyph"
    set -l unit_width (string length -- $unit)
    set -l count (math "ceil($cols / $unit_width)")
    set -l line (string repeat -n $count -- $unit | string sub -l $cols)

    set_color $color
    echo $line
    set_color normal
end
