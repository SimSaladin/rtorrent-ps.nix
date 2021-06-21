#!/usr/bin/env bash
#
# rTorrent startup script
#

NOCRON_DELAY=600
RT_HOME=@basedir@
RT_SOCKET=$RT_HOME/.scgi_local
RT_OPTS=( )
RT_OPTS+=( -D -I )  # comment this to get deprecated commands
RT_OPTS+=( -n -o "import=@rtorrent_rc@" )

fail() {
    echo "ERROR:" "$@"
    exit 1
}

export LANG=en_US.UTF-8
umask 0027

export RT_HOME RT_SOCKET

cd "$RT_HOME" || fail "RT_HOME $RT_HOME directory does not exist!"

test -S "$RT_SOCKET" && lsof "$RT_SOCKET" >/dev/null && { echo "rTorrent already running"; exit 1; }
test ! -e "$RT_SOCKET" || rm "$RT_SOCKET"

# Performa a mount check
#test -f "$RT_HOME/work/.mounted" -a -f "$RT_HOME/done/.mounted" \
#    || fail "Data drive(s) not mounted!"

#if [ "$TERM" = "${TERM%-256color}" ]; then
#    export TERM="$TERM-256color"
#fi

_at_exit() {
    test -z "$TMUX" || tmux set-w automatic-rename on >/dev/null
    stty sane
    test ! -e "$RT_SOCKET" || rm "$RT_SOCKET"
}
trap _at_exit INT TERM EXIT
test -z "$TMUX" || tmux 'rename-w' 'rT-PS'

# Stop cron jobs during startup, unless already stopped
rm "$RT_HOME/rtorrent.d/START-NOCRON.rc" 2>/dev/null || :
nocron_delay=''
if test -d "$RT_HOME/rtorrent.d" -a ! -f "$HOME/NOCRON"; then
    nocron_delay=$(( $(date +'%s') + NOCRON_DELAY ))
    echo >"$RT_HOME/rtorrent.d/START-NOCRON.rc" \
          "schedule2 = nocron_during_startup, $NOCRON_DELAY, 0, \"execute.nothrow=rm,$HOME/NOCRON\""
    touch "$HOME/NOCRON"
fi

# Make sure necessary directories exist
mkdir -p "$RT_HOME"/{.session,work,watch/{start,load},log}

@rtorrent@/bin/rtorrent "${RT_OPTS[@]}" ; RC=$?
test -z "$nocron_delay" -o "$(date +'%s')" -ge "${nocron_delay:-0}" || rm "$HOME/NOCRON" 2>/dev/null || :
exit $RC
