function rubymine --wraps rubymine --description 'Launch RubyMine inheriting the current shell environment'
    set --local bin /Applications/RubyMine.app/Contents/MacOS/rubymine

    if not test -x $bin
        echo "rubymine: $bin not found" >&2
        return 1
    end

    # Exec the bundle binary directly, not `open -a`: LaunchServices would drop
    # the devenv shell environment RubyMine needs to resolve the Ruby toolchain.
    set --local target $argv
    test (count $target) -eq 0; and set target .

    $bin $target >/dev/null 2>&1 &
    disown
end
