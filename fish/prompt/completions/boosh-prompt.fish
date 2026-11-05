complete -c boosh-prompt -f
complete -c boosh-prompt -s h -l help -d 'Show help'
complete -c boosh-prompt -s s -l show -d 'Show the current settings'
complete -c boosh-prompt -s r -l reset -d 'Back to the defaults'
complete -c boosh-prompt -l lines -x -a '1 2' -d 'One or two lines'
complete -c boosh-prompt -l gap -x -a '0 1 2 3' -d 'Empty lines between prompts'
complete -c boosh-prompt -l symbol -x -a "❯ ❱ ➜ λ '\$' '>'" -d 'Symbol on the last line'   # -a is parsed as fish code: quote $ and >
complete -c boosh-prompt -l path -x -a 'short full' -d 'Path style'
complete -c boosh-prompt -l git -x -a 'on off' -d 'Git information'
complete -c boosh-prompt -l fields -x -a 'all branch ahead behind staged modified untracked conflicts stash' -d 'Git parts, comma separated, in this order'
complete -c boosh-prompt -l time -x -a 'on off' -d 'Time of slow commands'
complete -c boosh-prompt -l time-after -x -a '1s 3s 10s' -d 'Threshold for "slow"'
complete -c boosh-prompt -l status -x -a 'on off' -d 'Exit code after a failed command'
