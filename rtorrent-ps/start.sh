#!/usr/bin/env bash
# rTorrent startup script

fail() {
    echo "rtorrent-ps: error: ${1:-unspecified}" >&2
    exit "${2:-1}"
}

export LANG=en_US.UTF-8

umask 0027

if [[ -z ${RT_HOME-} ]]; then
    RT_HOME=${HOME:-$PWD}/.rtorrent
    echo "warning: RT_HOME not set, defaulting to $RT_HOME" >&2
fi

if [[ ! -e $RT_HOME ]]; then
    echo >&2 "warning: the instance directory doesn't exist yet ($RT_HOME)." \
        "Attempting to create it..."
    if mkdir -p "$RT_HOME"; then
        :
    else
        fail "Could not initialize home directory!" "$?"
    fi
fi

# Change directory to the base directory.
cd "$RT_HOME" || fail "Instance directory inaccessible: $RT_HOME"
RT_HOME=$(pwd -P)
export RT_HOME

RT_SOCKET=${RT_SOCKET:-"$RT_HOME/.scgi_local"}
RT_INITRC=${RT_INITRC:-"$RT_HOME/rtorrent.rc"}
RT_OPTIONS=( -n -o "import=$RT_INITRC" ) # -D -I
LimitFSIZE=${LimitFSIZE-unlimited}
LimitNOFILE=${LimitNOFILE-500000}

# Set resource limits
if [[ -n $LimitNOFILE ]]; then
    if ulimit -n "$LimitNOFILE"; then
        :
    else
        fail "Failed to raise open files limit (-n) of process" "$?"
    fi
fi
if [[ -n $LimitFSIZE ]]; then
    if ulimit -f "$LimitFSIZE"; then
        :
    else
        fail "Failed to set FSIZE limit to $LimitFSIZE" "$?"
    fi
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
    if ! lsof -w -- "$RT_SOCKET" >/dev/null; then
        fail "already running (socket in use)"
    fi
    rm -v "$RT_SOCKET"
fi

# Make sure necessary directories exist
mkdir -p "$RT_HOME"/{.session,work,watch/{start,load},log}

# Exit signal handler
_at_exit() {
    stty sane
    #test ! -e "$RT_SOCKET" || rm "$RT_SOCKET"
    test -z "${TMUX-}" || tmux set-w automatic-rename on >/dev/null || :
}
trap _at_exit TERM EXIT

# Set tmux window title
test -z "${TMUX-}" || tmux rename-w "rTorrent-PS" || :

# Note: not exec'ing so that the shell trap is run when rtorrent exits
"${RT_BIN:-rtorrent}" "${RT_OPTIONS[@]}" "$@"
