# pack: git (managed by boosh/pack; edit it in the repo, not here)
# Needs fish >= 3.6 (abbr --set-cursor). Defined in conf.d, so abbreviations
# you set later in config.fish win over these.
if status is-interactive
    abbr -a g git
    abbr -a gst 'git status -sb'
    abbr -a ga 'git add'
    abbr -a gd 'git diff'
    abbr -a gds 'git diff --staged'
    abbr -a gsw 'git switch'
    abbr -a gb 'git branch'
    abbr -a gc 'git commit'
    abbr -a gcm --set-cursor 'git commit -m "%"'
    abbr -a gp 'git push'
    abbr -a gpl 'git pull'
    abbr -a gl 'git log --oneline --graph --decorate -20'

    if type -q lazygit
        abbr -a lg lazygit
    end

    # git info in the default fish prompt (fish_git_prompt ships with fish)
    set -g __fish_git_prompt_showdirtystate yes
    set -g __fish_git_prompt_showuntrackedfiles yes
    set -g __fish_git_prompt_showupstream auto
    set -g __fish_git_prompt_showcolorhints yes
end
