# boosh prompt: [empty lines] / line 1 = path, git, time of a slow command / line 2 = the symbol
# (red, with the exit code, after a failure). Everything is switched with `boosh-prompt`.
function fish_prompt
    set -l last_status $status
    set -q __boosh_pwd_text; or __boosh_pwd

    # empty line(s) separating this prompt from the previous command's output (never before the very first prompt)
    if test "$__boosh_gap" = true
        set -l gap (__boosh_opt boosh_prompt_gap 1)
        test "$gap" = true; and set gap 1      # older versions stored true/false
        test "$gap" = false; and set gap 0
        for i in (seq $gap)
            echo
        end
    end

    set_color --bold blue; echo -n $__boosh_pwd_text; set_color normal
    # git info comes with the git pack (./pack add git); without it this part is simply absent
    set -l git
    functions -q __boosh_git_format; and set git (__boosh_git_format)
    test -n "$git"; and echo -n " $git"
    set -l show_time (__boosh_opt boosh_prompt_show_time true)
    if test "$show_time" != false; and test -n "$__boosh_duration"
        set_color yellow; echo -n " $__boosh_duration"; set_color normal
    end

    set -l multiline (__boosh_opt boosh_prompt_multiline true)
    if test "$multiline" = false
        echo -n ' '
    else
        echo
    end

    set -l show_status (__boosh_opt boosh_prompt_show_status true)
    if test $last_status -ne 0
        set_color red
        test "$show_status" != false; and echo -n "✘$last_status "
    else
        set_color magenta
    end
    echo -n (__boosh_opt boosh_prompt_symbol ❯)' '
    set_color normal
end
