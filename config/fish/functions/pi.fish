function pi --wraps pi --description 'Run pi with a live macOS light/dark theme'
    set --local watcher "$HOME/.pi/agent/bin/pi-system-theme-watch"
    set --local watcher_pid

    if test -x "$watcher"
        "$watcher" --once
        "$watcher" --watch &
        set watcher_pid $last_pid
    end

    command pi $argv
    set --local pi_status $status

    if test -n "$watcher_pid"
        kill $watcher_pid 2>/dev/null
    end

    return $pi_status
end
