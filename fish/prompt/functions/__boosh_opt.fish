# __boosh_opt NAME DEFAULT: the value of a boosh_prompt_* setting, or DEFAULT when it is not set.
# (Defaults live here instead of in variables, so `boosh-prompt --reset` is just "erase the variable".)
function __boosh_opt --argument-names name default
    if set -q $name
        echo $$name
    else
        echo $default
    end
end
