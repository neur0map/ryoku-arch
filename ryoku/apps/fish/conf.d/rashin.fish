# Ryoku Rashin in the terminal. `rashin <what you want>` answers from the
# same brain as the launcher's \ ask and the dashboard: it proposes a
# command, you press Enter. Nothing runs on its own. Inert when the daemon is
# off or ryoku-rashin is absent. See docs/rashin-terminal.md.

if not status is-interactive
    exit
end

if not type -q ryoku-rashin
    exit
end

# The interactive wrapper shadows the `rashin` binary: it asks with the
# terminal context, streams the answer to the terminal (stderr), and drops the
# proposed command on the prompt (stdout). Info verbs print and inject nothing.
function rashin --description 'Rashin: the needle, in your terminal'
    set -l payload (RASHIN_LAST_CMD=$__rashin_last_cmd RASHIN_LAST_STATUS=$__rashin_last_status \
        command ryoku-rashin term --buffer -- $argv)
    if test -n "$payload"
        set -g __rashin_proposed (string join ' && ' -- $payload)
        commandline -r -- (string join \n -- $payload)
        commandline -f repaint
    end
end

# Alt+R transmutes the current command line: send it as an ask and replace it
# with the proposed command. stderr is dropped so the spinner never scribbles
# the prompt; the user asked for the command, not the prose.
function __rashin_transmute
    set -l buf (commandline)
    if test -z "$buf"
        return
    end
    set -l payload (command ryoku-rashin term --buffer -- $buf 2>/dev/null)
    if test -n "$payload"
        set -g __rashin_proposed (string join ' && ' -- $payload)
        commandline -r -- (string join \n -- $payload)
    end
    commandline -f repaint
end

# fish 4 uses named keys (bind alt-r); fish 3 uses the escape sequence (\er).
# Bind both so the keystroke works across versions.
function __rashin_bindings
    bind alt-r __rashin_transmute 2>/dev/null; or bind \er __rashin_transmute
    if bind -M insert >/dev/null 2>&1
        bind -M insert alt-r __rashin_transmute 2>/dev/null; or bind -M insert \er __rashin_transmute
    end
end
__rashin_bindings

# Learn from what actually ran: after a rashin-proposed command, report the
# proposed-vs-ran pair and the exit status back to the daemon (loopback,
# backgrounded, only when a proposal was on the line). The daemon surfaces the
# corrections in the habits layer so the next ask does better.
function __rashin_learn --on-event fish_postexec
    set -l st $status
    if set -q __rashin_proposed
        set -l proposed $__rashin_proposed
        set -e __rashin_proposed
        command ryoku-rashin term --report $proposed "$argv" $st &>/dev/null &
        disown 2>/dev/null
    end
    # Remember this command for the next ask's terminal context.
    set -g __rashin_last_cmd $argv
    set -g __rashin_last_status $st
end

# Recipes: saved shortcuts materialize as `rr-<name>` fish abbreviations in a
# rashin-owned state file; source it when present so they expand at the prompt.
set -l __rashin_recipes $XDG_STATE_HOME
test -z "$__rashin_recipes"; and set __rashin_recipes $HOME/.local/state
set __rashin_recipes $__rashin_recipes/ryoku/rashin-recipes.fish
test -f $__rashin_recipes; and source $__rashin_recipes
