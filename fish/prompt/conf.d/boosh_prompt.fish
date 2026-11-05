# boosh prompt (conf.d part): settings and events.
# Git info is not part of the prompt: it comes with the `git` pack (./pack add git), which provides
# __boosh_git_format and the background job. Without the pack the prompt simply shows no git part.
#
# Settings are universal variables boosh_prompt_*, changed with the `boosh-prompt` command (boosh-prompt --help).
# Defaults are applied by __boosh_opt, so there is nothing to set here.
if status is-interactive
    set -g __boosh_prompt_active 1   # packs look at this: "the boosh prompt is the one being shown"
    set -g __boosh_duration
    set -g __boosh_gap false   # becomes true once the first prompt has been shown

    # the shortened path only changes when the directory does: compute it then, not on every prompt
    function __boosh_pwd --on-variable PWD
        if test (__boosh_opt boosh_prompt_path short) = full
            set -g __boosh_pwd_text (prompt_pwd --dir-length 0)
        else
            set -g __boosh_pwd_text (prompt_pwd --full-length-dirs 2)
        end
    end
    __boosh_pwd

    # runs once per prompt (not on a repaint): from the second prompt on, put an empty line before it
    function __boosh_gap_mark --on-event fish_prompt
        set -q __boosh_seen_prompt; and set -g __boosh_gap true
        set -g __boosh_seen_prompt 1
    end

    # time of the command that just finished (CMD_DURATION is in ms)
    function __boosh_postexec --on-event fish_postexec
        set -g __boosh_duration
        test "$CMD_DURATION" -ge (__boosh_opt boosh_prompt_duration_ms 3000) 2>/dev/null; or return
        set -l s (math --scale=0 "$CMD_DURATION / 1000 % 60")
        set -l m (math --scale=0 "$CMD_DURATION / 60000 % 60")
        set -l h (math --scale=0 "$CMD_DURATION / 3600000")
        set -l out
        test $h -gt 0; and set -a out {$h}h
        test $m -gt 0; and set -a out {$m}m
        test $s -gt 0; and set -a out {$s}s
        set -g __boosh_duration (string join '' $out)
    end
end
