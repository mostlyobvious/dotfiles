function git
    set -l args $argv

    # diff.external=difft covers `git diff`, but Git only consults external
    # diff for log/show when --ext-diff is present. Add that flag at the shell
    # seam instead of asking every call site to remember it.
    if test (count $args) -ge 2
        set -l command $args[1]
        set -l has_patch 0
        set -l has_ext_diff 0

        for arg in $args
            switch $arg
                case -p --patch
                    set has_patch 1
                case --ext-diff
                    set has_ext_diff 1
            end
        end

        if contains -- $command log show; and test $has_patch -eq 1
            if test $has_ext_diff -eq 0
                set args $args[1] --ext-diff $args[2..-1]
            end
            env LC_ALL=en_US.UTF-8 command git $args
            return $status
        end
    end

    env LC_ALL=en_US.UTF-8 command git $args
end
