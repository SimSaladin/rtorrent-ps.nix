#!/usr/bin/env bash
#
# rTorrent startup script
#

fail() {
    echo "rtorrent-ps: error: $*" >&2
    exit 1
}

export LANG=en_US.UTF-8

umask 0027

if [[ -z ${RT_HOME-} ]]; then
    RT_HOME=${HOME:-$PWD}/.rtorrent
    echo "warning: RT_HOME not set, defaulting to $RT_HOME" >&2
fi

if [[ ! -e $RT_HOME ]]; then
    echo "creating directory: $RT_HOME" >&2
    mkdir -p "$RT_HOME" || fail "Could not initialize home directory!"
fi

# Change directory to the base directory.
cd "$RT_HOME" || fail "RT_HOME ($RT_HOME) directory does not exist or is not accessible"
RT_HOME=$(pwd -P)
export RT_HOME

RT_SOCKET=${RT_SOCKET:-"$RT_HOME/.scgi_local"}
RT_INITRC=${RT_INITRC:-"$RT_HOME/rtorrent.rc"}
RT_OPTIONS=( -n -o "import=$RT_INITRC" ) # -D -I
LimitFSIZE=${LimitFSIZE-unlimited}
LimitNOFILE=${LimitNOFILE-500000}

# Set resource limits
if [[ -n $LimitNOFILE ]]; then
    ulimit -n "$LimitNOFILE" || fail "Failed to raise open files limit (-n) of process"
fi
if [[ -n $LimitFSIZE ]]; then
    ulimit -f "$LimitFSIZE" || fail "Failed to set FSIZE limit to $LimitFSIZE"
fi

# Setup TERM properly in some corner case.
if [[ ${TERM-} =~ ^(xterm|tmux|screen)$ ]]; then
    export TERM="$TERM-256color"
fi

# Exit if socket in use or delete if obsolete.
if [[ -e $RT_SOCKET ]]; then
    [[ -S $RT_SOCKET ]] || fail "Socket file $RT_SOCKET exists, but it is not a socket!"
    # TODO the lsof check fails with network namespaces
    ! lsof -w -- "$RT_SOCKET" >/dev/null || fail "already running (socket in use)"
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
