function tmux --wraps tmux --description 'Run tmux from Arch distrobox on demand'
    if type -q distrobox-enter
        distrobox-enter arch -- tmux $argv
    else
        command tmux $argv
    end
end
