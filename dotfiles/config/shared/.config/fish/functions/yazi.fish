function yazi --wraps yazi --description 'Run yazi from Arch distrobox on demand'
    if type -q distrobox-enter
        distrobox-enter arch -- yazi $argv
    else
        command yazi $argv
    end
end
