# boosh prompt (conf.d part): settings, events and the background git job.
#
# Technique (git status computed in a background fish, result delivered by a signal, then a repaint) is the
# one Hydro by Jorge Bucaran (MIT) uses. This is a separate, much smaller implementation.
#
# Settings are universal variables boosh_prompt_*, changed with the `boosh-prompt` command (boosh-prompt --help).
# Defaults are applied by __boosh_opt, so there is nothing to set here.
if status is-interactive
    set -g __boosh_git_data
    set -g __boosh_git_root
    set -g __boosh_git_pid
    set -g __boosh_duration
    set -g __boosh_gap false   # becomes true once the first prompt has been shown
    set -g __boosh_git_out (set -q XDG_RUNTIME_DIR; and echo $XDG_RUNTIME_DIR; or echo /tmp)/boosh-git-$fish_pid

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

    # repo root without starting a process: walk up looking for .git
    function __boosh_git_find_root
        set -l d $PWD
        while test "$d" != /
            test -e $d/.git; and echo $d; and return
            set d (path dirname $d)
        end
    end

    # right before each prompt: start the background job and do not wait for it
    function __boosh_git_kick --on-event fish_prompt
        # git switched off (boosh-prompt --git off): no job at all
        if set -q boosh_prompt_git_fields; and test (count $boosh_prompt_git_fields) -eq 0
            set -g __boosh_git_data
            set -g __boosh_git_root
            return
        end
        set -l root (__boosh_git_find_root)
        if test -z "$root"
            set -g __boosh_git_data
            set -g __boosh_git_root
            return
        end
        if test "$root" != "$__boosh_git_root"   # another repository: never show the old one's data
            set -g __boosh_git_data
            set -g __boosh_git_root $root
        end
        # an older job is still running (huge repo, quick Enter): stop it, but only if that pid is really ours
        if test -n "$__boosh_git_pid"
            ps -p $__boosh_git_pid -o args= 2>/dev/null | string match -q '*__boosh_git_worker*'
            and command kill $__boosh_git_pid 2>/dev/null
        end
        set -l worker (functions --details __boosh_git_worker)
        test -f "$worker"; or return   # the file is gone (repository moved, branch switched): stay quiet, show no git info
        fish --no-config -c 'source $argv[1]; __boosh_git_worker $argv[2] $argv[3] $argv[4]' $worker $root $__boosh_git_out $fish_pid &
        set -g __boosh_git_pid $last_pid
        disown
    end

    # the job is done: read its result and repaint the prompt
    function __boosh_git_on_result --on-signal USR1
        set -g __boosh_git_pid
        test -f $__boosh_git_out; or return
        set -l l
        while read -l line
            set -a l $line
        end <$__boosh_git_out
        if test "$l[1]" = "$__boosh_git_root"
            set -g __boosh_git_data $l[2..-1]
            commandline -f repaint
        end
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

    function __boosh_cleanup --on-event fish_exit
        rm -f $__boosh_git_out $__boosh_git_out.tmp
    end
end
