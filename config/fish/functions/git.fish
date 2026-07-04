function git
    set -l args $argv

    # show/log honor diff.external only with --ext-diff; show implies a patch.
    if test (count $args) -ge 1
        set -l command $args[1]
        if contains -- $command show log whatchanged; and not contains -- --ext-diff $args
            set args $args[1] --ext-diff $args[2..-1]
        end
    end

    env LC_ALL=en_US.UTF-8 command git $args
end
