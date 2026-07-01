function fish_prompt --description Hydro
    set --local remote

    if set --query SSH_CONNECTION; or set --query SSH_TTY
        set remote (prompt_hostname)' '
    end

    echo -e "$remote$_hydro_color_pwd$_hydro_pwd$hydro_color_normal $_hydro_color_git$$_hydro_git$hydro_color_normal$_hydro_color_duration$_hydro_cmd_duration$hydro_color_normal$_hydro_status$hydro_color_normal "
end
