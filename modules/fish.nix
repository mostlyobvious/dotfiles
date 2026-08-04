{
  lib,
  pkgs,
  ...
}:

{
  programs.fish = {
    enable = true;
    shellAliases.less = "less -R";

    functions.wt = ''
      set -l code "$HOME/Code"
      set -l root "$code/worktrees"
      set -l entries

      set -l common_dir (git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
      if test $status -eq 0
          set -l main_root (dirname "$common_dir")
          set -l repo (basename "$main_root")
          set -l main_checkout (string replace -- "$code/" "" "$main_root")

          if string match --quiet "$root/$repo/*" (pwd); and test "$main_checkout" != "$main_root"
              set entries $entries "$main_checkout"
          end

      end

      if test -d "$root"
          for worktree in (fd --base-directory "$root" --max-depth 2 --min-depth 2 --type directory .)
              if not contains -- "$worktree" $entries
                  set entries $entries "$worktree"
              end
          end
      end

      if test (count $entries) -eq 0
          echo "No worktrees or checkouts in $code" >&2
          return 1
      end

      set -l selected (printf "%s\n" $entries | fzf --no-sort)

      if test -z "$selected"
          return
      end

      if test -d "$code/$selected"
          cd "$code/$selected"
      else
          cd "$root/$selected"
      end
    '';

    functions.wtc = ''
      if test (count $argv) -ne 1
          echo "Usage: wtc <branch>" >&2
          return 2
      end

      set -l branch $argv[1]
      set -l common_dir (git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
      if test $status -ne 0
          echo "Not in a git repository" >&2
          return 1
      end

      set -l main_root (dirname "$common_dir")
      set -l repo (basename "$main_root")
      set -l name (string replace -ar '[^A-Za-z0-9._-]' - -- "$branch")
      set -l dest "$HOME/Code/worktrees/$repo/$name"

      if test -e "$dest"
          echo "Worktree path already exists: $dest" >&2
          return 1
      end

      mkdir -p (dirname "$dest")
      if test -d "$HOME/Code/mono"; and not test -e "$HOME/Code/worktrees/mono"
          ln -s "$HOME/Code/mono" "$HOME/Code/worktrees/mono"
      end

      if git -C "$main_root" show-ref --verify --quiet "refs/heads/$branch"
          git -C "$main_root" worktree add "$dest" "$branch"; or return
      else
          set -l origin_head (git -C "$main_root" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)
          if test -z "$origin_head"
              git -C "$main_root" remote set-head origin --auto >/dev/null 2>&1
              set origin_head (git -C "$main_root" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)
          end

          set -l base_ref (string replace refs/remotes/ "" -- "$origin_head")
          if test -z "$base_ref"
              set base_ref HEAD
          end

          git -C "$main_root" worktree add -b "$branch" "$dest" "$base_ref"; or return
      end

      for item in .envrc .env devenv.nix devenv.yaml devenv.lock devenv.local.nix .mcp.json
          if test -e "$main_root/$item"
              cp -R "$main_root/$item" "$dest/$item"
          end
      end

      for src in "$main_root"/secretspec*
          if test -e "$src"
              cp -R "$src" "$dest/"(basename "$src")
          end
      end

      if test -d "$main_root/.claude"
          mkdir -p "$dest/.claude"
          for src in "$main_root/.claude"/*
              if test -e "$src"
                  cp -R "$src" "$dest/.claude/"
              end
          end
      end

      cd "$dest"
    '';

    functions.wtd = ''
      if test (count $argv) -gt 1
          echo "Usage: wtd [repo/worktree]" >&2
          return 2
      end

      set -l root "$HOME/Code/worktrees"
      if not test -d "$root"
          echo "No worktrees in $root" >&2
          return 1
      end

      set -l selected $argv[1]
      if test -z "$selected"
          set selected (
              fd --base-directory "$root" --max-depth 2 --min-depth 2 --type directory . \
                  | fzf
          )
      end

      if test -z "$selected"
          return
      end

      set -l path "$root/$selected"
      if not test -d "$path"
          echo "No worktree at $path" >&2
          return 1
      end

      set -l branch (git -C "$path" branch --show-current)
      set -l common_dir (git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
      set -l main_root (dirname "$common_dir")
      set -l origin_head (git -C "$main_root" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)
      set -l default_branch (string replace -r '^refs/remotes/[^/]+/' "" -- "$origin_head")

      if test -z "$default_branch"
          set default_branch (git -C "$main_root" symbolic-ref --short HEAD 2>/dev/null)
      end

      set -l current_dir (pwd -P)
      set -l resolved_path (path resolve "$path")
      if string match --quiet -- "$resolved_path" "$current_dir"; or string match --quiet -- "$resolved_path/*" "$current_dir"
          cd "$main_root"; or return
      end

      git -C "$main_root" worktree remove "$path"; or return

      if test -n "$branch"; and test "$branch" != "$default_branch"
          git -C "$main_root" branch -d "$branch"; or true
      end
    '';

    # Upstream hydro prompt; local deviations go through its public
    # variables (see conf.d/hydro-theme.fish below), no forked functions.
    plugins = [
      {
        name = "hydro";
        inherit (pkgs.fishPlugins.hydro) src;
      }
    ];

    shellInit = ''
      set fish_greeting
    ''
    + lib.optionalString pkgs.stdenv.isDarwin ''
      # Pinned copy of `brew shellenv fish` to skip exec'ing brew per shell;
      # re-sync if brew's shellenv output changes.
      set --global --export HOMEBREW_PREFIX /opt/homebrew
      set --global --export HOMEBREW_CELLAR /opt/homebrew/Cellar
      set --global --export HOMEBREW_REPOSITORY /opt/homebrew
      fish_add_path --global --move --path /opt/homebrew/bin /opt/homebrew/sbin
      if test -n "$MANPATH[1]"; set --global --export MANPATH ''' $MANPATH; end
      if not contains /opt/homebrew/share/info $INFOPATH
        set --global --export INFOPATH /opt/homebrew/share/info $INFOPATH
      end
      if test -d /opt/homebrew/share/fish/completions
        set -p fish_complete_path /opt/homebrew/share/fish/completions
      end
      if test -d /opt/homebrew/share/fish/vendor_completions.d
        set -p fish_complete_path /opt/homebrew/share/fish/vendor_completions.d
      end

      # nix-darwin wires this into PATH via an /etc/profile hook that fish does
      # not read. Prepend it after brew so Nix-provided CLI tools win.
      fish_add_path --global --prepend /run/current-system/sw/bin
    '';

    interactiveShellInit = lib.mkAfter ''
      function fzf-history-widget -d "Show command history"
          set -l fzf_query (commandline)
          set -lx FZF_DEFAULT_OPTS "$FZF_DEFAULT_OPTS --scheme=history --read0 --print0 --no-multi-line --bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS"
          set -lx FZF_DEFAULT_OPTS_FILE

          test -z "$fish_private_mode"; and builtin history merge

          if set -l result (builtin history -z | fzf --query "$fzf_query" | string split0)
              commandline -- $result
          end

          commandline --function repaint
      end
    '';
  };

  # Named to sort before plugin-hydro.fish: hydro bakes hydro_symbol_prompt
  # into _hydro_status as its conf.d loads, so the overrides must exist first.
  xdg.configFile."fish/conf.d/hydro-theme.fish".text = ''
    set --global hydro_symbol_prompt \$
    set --global hydro_symbol_git_dirty ' •'
    set --global hydro_multiline true
    set --global fish_prompt_pwd_dir_length 10

    if set --query SSH_CONNECTION; or set --query SSH_TTY
        set --global hydro_symbol_start (prompt_hostname)' '
    end
  '';
}
