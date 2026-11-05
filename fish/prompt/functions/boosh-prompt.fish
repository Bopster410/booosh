# boosh-prompt: show or change the boosh prompt.
# Settings are universal variables (boosh_prompt_*): they apply to the next prompt in every open terminal and
# survive restarts. Nothing is changed unless every flag you gave is valid.
function boosh-prompt --description 'Show or change the boosh prompt settings'
    set -l all_fields branch ahead behind staged modified untracked conflicts stash
    argparse -n boosh-prompt h/help s/show r/reset 'lines=' 'gap=' 'symbol=' 'git=' 'fields=' 'time=' 'time-after=' 'status=' 'path=' -- $argv
    or return 2

    if set -q _flag_help
        __boosh_prompt_help
        return 0
    end

    # ---- validate everything first
    set -l errors
    set -l v_git
    set -l v_time
    set -l v_status
    set -l v_after
    set -l v_fields
    if set -q _flag_lines; and not contains -- $_flag_lines 1 2
        set -a errors "--lines must be 1 or 2"
    end
    if set -q _flag_gap; and not string match -qr '^[0-5]$' -- $_flag_gap
        set -a errors "--gap must be a number from 0 to 5"
    end
    if set -q _flag_symbol; and test -z "$_flag_symbol"
        set -a errors "--symbol needs a character"
    end
    if set -q _flag_path; and not contains -- $_flag_path short full
        set -a errors "--path must be short or full"
    end
    if set -q _flag_git
        set v_git (__boosh_prompt_bool $_flag_git)
        test -n "$v_git"; or set -a errors "--git must be on or off"
    end
    if set -q _flag_time
        set v_time (__boosh_prompt_bool $_flag_time)
        test -n "$v_time"; or set -a errors "--time must be on or off"
    end
    if set -q _flag_status
        set v_status (__boosh_prompt_bool $_flag_status)
        test -n "$v_status"; or set -a errors "--status must be on or off"
    end
    if set -q _flag_time_after
        if string match -qr '^[0-9]+$' -- $_flag_time_after
            set v_after $_flag_time_after
        else if string match -qr '^[0-9]+s$' -- $_flag_time_after
            set v_after (math (string replace s '' -- $_flag_time_after) \* 1000)
        else
            set -a errors "--time-after must be milliseconds (3000) or seconds (3s)"
        end
    end
    if set -q _flag_fields
        set v_fields (string split -n , -- (string replace -a ' ' , -- $_flag_fields))
        if test "$v_fields" = all
            set v_fields $all_fields
        else
            for f in $v_fields
                contains -- $f $all_fields; or set -a errors "--fields: unknown part '$f' (one of: $all_fields)"
            end
            test (count $v_fields) -gt 0; or set -a errors "--fields needs at least one part"
        end
        test "$v_git" = false; and set -a errors "--git off and --fields contradict each other"
    end
    if test (count $errors) -gt 0
        for e in $errors
            echo "boosh-prompt: $e" >&2
        end
        return 2
    end

    # ---- apply
    set -l changed 0
    if set -q _flag_reset
        for v in (set -Un | string match -r '^boosh_prompt_.*')
            set -e -U $v
        end
        for v in (set -n | string match -r '^boosh_prompt_.*')
            set -e -g $v 2>/dev/null
        end
        set changed 1
    end
    if set -q _flag_lines
        __boosh_prompt_put boosh_prompt_multiline (test "$_flag_lines" = 1; and echo false; or echo true)
        set changed 1
    end
    if set -q _flag_gap
        __boosh_prompt_put boosh_prompt_gap $_flag_gap
        set changed 1
    end
    if set -q _flag_symbol
        __boosh_prompt_put boosh_prompt_symbol $_flag_symbol
        set changed 1
    end
    if set -q _flag_path
        __boosh_prompt_put boosh_prompt_path $_flag_path
        set changed 1
    end
    if set -q _flag_time
        __boosh_prompt_put boosh_prompt_show_time $v_time
        set changed 1
    end
    if set -q _flag_time_after
        __boosh_prompt_put boosh_prompt_duration_ms $v_after
        set changed 1
    end
    if set -q _flag_status
        __boosh_prompt_put boosh_prompt_show_status $v_status
        set changed 1
    end
    if test "$v_git" = false
        __boosh_prompt_put boosh_prompt_git_fields   # an empty list means: no git info, no background job
        set changed 1
    else if set -q _flag_fields
        __boosh_prompt_put boosh_prompt_git_fields $v_fields
        set changed 1
    else if test "$v_git" = true
        set -e -U boosh_prompt_git_fields             # back to the default list of parts
        set -e -g boosh_prompt_git_fields 2>/dev/null
        set changed 1
    end

    # the shortened path is cached until you change directory: refresh it now
    functions -q __boosh_pwd; and __boosh_pwd
    __boosh_prompt_show   # shown with no flags, with --show, and after every change
end

function __boosh_prompt_bool
    switch (string lower -- $argv[1])
        case on true yes 1
            echo true
        case off false no 0
            echo false
    end
end

function __boosh_prompt_put --argument-names name
    set -e -g $name 2>/dev/null   # a global of the same name would hide the universal one
    set -U $name $argv[2..-1]
end

function __boosh_prompt_show
    set -l git_all branch ahead behind staged modified untracked conflicts stash
    set -l fields $git_all
    set -q boosh_prompt_git_fields; and set fields $boosh_prompt_git_fields
    set -l lines (test (__boosh_opt boosh_prompt_multiline true) = false; and echo 1; or echo 2)
    set -l gap (__boosh_opt boosh_prompt_gap 1)
    test "$gap" = true; and set gap 1
    test "$gap" = false; and set gap 0
    set -l ms (__boosh_opt boosh_prompt_duration_ms 3000)
    set -l git (test (count $fields) -eq 0; and echo off; or echo on)

    echo "boosh prompt settings (* = changed from the default)"
    printf '  %-9s %s%s\n' lines (__boosh_prompt_mark boosh_prompt_multiline) $lines
    printf '  %-9s %s%s empty line(s) between prompts\n' gap (__boosh_prompt_mark boosh_prompt_gap) $gap
    printf '  %-9s %s%s\n' symbol (__boosh_prompt_mark boosh_prompt_symbol) (__boosh_opt boosh_prompt_symbol ❯)
    printf '  %-9s %s%s\n' path (__boosh_prompt_mark boosh_prompt_path) (__boosh_opt boosh_prompt_path short)
    printf '  %-9s %s%s  %s\n' git (__boosh_prompt_mark boosh_prompt_git_fields) $git "$fields"
    printf '  %-9s %s%s  (commands slower than %s ms)\n' time (__boosh_prompt_mark boosh_prompt_show_time) (test (__boosh_opt boosh_prompt_show_time true) = false; and echo off; or echo on) $ms
    printf '  %-9s %s%s  (exit code after a failed command)\n' status (__boosh_prompt_mark boosh_prompt_show_status) (test (__boosh_opt boosh_prompt_show_status true) = false; and echo off; or echo on)
end

function __boosh_prompt_mark --argument-names name
    set -q $name; and echo '*'; or echo ' '
end

function __boosh_prompt_help
    echo 'boosh-prompt: show or change the boosh prompt (changes apply to the next prompt, everywhere, and stay)

  boosh-prompt                      show the current settings
  boosh-prompt --lines 1|2          one or two lines
  boosh-prompt --gap N              empty lines between prompts, 0 to 5
  boosh-prompt --symbol TEXT        the character on the last line, for example ">" or "λ"
  boosh-prompt --path short|full    ~/a/b/c as shortened (~/a/b/c) or in full
  boosh-prompt --git on|off         git information; off also stops the background job
  boosh-prompt --fields LIST        git parts, comma separated, shown in this order:
                                    branch ahead behind staged modified untracked conflicts stash (or: all)
  boosh-prompt --time on|off        time of slow commands
  boosh-prompt --time-after 3s      "slow" threshold: 3s or 3000 (milliseconds)
  boosh-prompt --status on|off      exit code (✘1) after a failed command
  boosh-prompt --reset              back to the defaults
  boosh-prompt --show               show the settings (also after every change)

Flags can be combined: boosh-prompt --lines 1 --gap 0 --fields branch,modified,untracked'
end
