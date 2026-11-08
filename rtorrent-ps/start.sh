#!/usr/bin/env bash
# rTorrent startup script

fail() {
    echo "rtorrent-ps: error: ${1:-unspecified}" >&2
    exit "${2:-1}"
}

export LANG=en_US.UTF-8

if [[ -z ${RT_HOME-} ]]; then
    RT_HOME=${HOME:-$PWD}/.rtorrent
    echo "warning: RT_HOME not set, defaulting to $RT_HOME" >&2
fi

if [[ ! -e $RT_HOME ]]; then
    echo >&2 "warning: the instance directory doesn't exist yet ($RT_HOME)." \
        "Attempting to create it..."
    mkdir -p "$RT_HOME"
fi

# Change directory to the base directory.
cd "$RT_HOME" || fail "Instance directory inaccessible: $RT_HOME"
RT_HOME=$(pwd -P)
export RT_HOME

RT_SOCKET=${RT_SOCKET:-"$RT_HOME/.scgi_local"}
RT_INITRC=${RT_INITRC:-"$RT_HOME/rtorrent.rc"}
RT_OPTIONS=( -n -o "import=$RT_INITRC" "${RT_OPTIONS[@]}" ) # -D -I
LimitFSIZE=${LimitFSIZE-unlimited}
LimitNOFILE=${LimitNOFILE-500000}

# Set resource limits
if [[ -n $LimitNOFILE ]]; then
    echo >&2 "Setting ulimit -n $LimitNOFILE"
    ulimit -n "$LimitNOFILE"
fi
if [[ -n $LimitFSIZE ]]; then
    echo >&2 "Setting ulimit -f $LimitNOFILE"
    ulimit -f "$LimitFSIZE"
fi

# Setup TERM properly in some corner case.
if [[ ${TERM-} =~ ^(xterm|tmux|screen)$ ]]; then
    export TERM=$TERM-256color
fi

# Exit if socket in use or delete if obsolete.
if [[ -e $RT_SOCKET ]]; then
    if ! [[ -S $RT_SOCKET ]]; then
        fail "Socket file $RT_SOCKET exists, but it is not a socket!"
    fi
    # TODO the lsof check fails with network namespaces
    if lsof -t -- "$RT_SOCKET" >/dev/null; then
        fail "already running (socket in use)"
    fi
    rm -v "$RT_SOCKET"
fi

# Make sure necessary directories exist
mkdir -p "$RT_HOME"/work

# Exit signal handler
_at_exit() {
    stty sane
    test -z "${TMUX-}" || tmux set-window-option -t "$TMUX_PANE" \
        automatic-rename on >/dev/null || :
}
trap _at_exit TERM EXIT

# Set tmux window title
test -z "${TMUX-}" || tmux rename-window -t "$TMUX_PANE" "rTorrent-PS" || :

# Note: not exec'ing so that the shell trap is run when rtorrent exits
${RT_START_EXEC+exec} "${RT_BIN:-rtorrent}" "${RT_OPTIONS[@]}" "$@"
