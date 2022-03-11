#!/usr/bin/env bash
#
# rTorrent startup script
#

export RT_HOME=${RT_HOME:?}
export RT_SOCKET=${RT_SOCKET:?}
RT_INITRC=${RT_INITRC:?}
RT_BIN=${RT_BIN-rtorrent}
RT_OPTS=( -D -I -n -o "import=$RT_INITRC" )
RT_NOFILE=${RT_NOFILE:-30000}

fail() {
    echo "ERROR:" "$@"
    exit 1
}

export LANG=en_US.UTF-8

umask 0027
ulimit -n "$RT_NOFILE" || fail "Failed to raise open files limit (-n) of process"

cd "$RT_HOME" || fail "RT_HOME ($RT_HOME) directory does not exist or is not accessible"

test -S "$RT_SOCKET" && lsof -w -- "$RT_SOCKET" >/dev/null && { echo "rTorrent already running"; exit 1; }
test ! -e "$RT_SOCKET" || rm "$RT_SOCKET"

if [ "$TERM" = "${TERM%-256color}" ]; then
    export TERM="$TERM-256color"
fi

_at_exit() {
    test -z "$TMUX" || tmux set-w automatic-rename on >/dev/null
    stty sane
    test ! -e "$RT_SOCKET" || rm "$RT_SOCKET"
}
trap _at_exit INT TERM EXIT
test -z "$TMUX" || tmux 'rename-w' 'rT-PS'

# Make sure necessary directories exist
mkdir -p "$RT_HOME"/{.session,work,watch/{start,load},log}

# Note: not exec'ing so that the shell trap is run when rtorrent exits
"$RT_BIN" "${RT_OPTS[@]}" "$@"
