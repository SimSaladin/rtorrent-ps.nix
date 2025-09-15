#ifndef UI_PYROSCOPE_H
#define UI_PYROSCOPE_H

#include <string>
#include "display/color_map.h"

namespace ps {

// #define COL_SYS_BASE 90

enum AlertKind {
    // Sync changes to cmd-ref.html#term-d-message-alert
    ALERT_NORMAL,
    ALERT_NORMAL_CYCLING, // Tried all trackers
    ALERT_NORMAL_GHOST, // no data
    ALERT_GENERIC,
    ALERT_TIMEOUT,
    ALERT_CONNECT,
    ALERT_REQUEST,
    ALERT_GONE,
    ALERT_PERMS,
    ALERT_DOWN,
    ALERT_DNS,
    ALERT_MAX
};


enum ColorKPS {
 COL_DEFAULT = display::RCOLOR_NCURSES_DEFAULT,
 COL_TITLE = display::RCOLOR_TITLE,
 COL_FOOTER = display::RCOLOR_FOOTER,
 COL_FOCUS = display::RCOLOR_FOCUS,
 COL_LABEL = display::RCOLOR_LABEL,
 COL_INFO = display::RCOLOR_INFO,
 COL_ALARM = display::RCOLOR_ALARM,
 COL_COMPLETE = display::RCOLOR_COMPLETE,
 COL_SEEDING = display::RCOLOR_SEEDING,
 COL_STOPPED = display::RCOLOR_STOPPED,
 COL_QUEUED = display::RCOLOR_QUEUED,
 COL_INCOMPLETE = display::RCOLOR_INCOMPLETE,
 COL_LEECHING = display::RCOLOR_LEECHING,
 COL_ODD = display::RCOLOR_ODD,
 COL_EVEN = display::RCOLOR_EVEN,
 COL_CUSTOM1        = display::COL_CUSTOM1,
 COL_CUSTOM2        = display::COL_CUSTOM2,
 COL_CUSTOM3        = display::COL_CUSTOM3,
 COL_CUSTOM4        = display::COL_CUSTOM4,
 COL_CUSTOM5        = display::COL_CUSTOM5,
 COL_CUSTOM6        = display::COL_CUSTOM6,
 COL_CUSTOM7        = display::COL_CUSTOM7,
 COL_CUSTOM8        = display::COL_CUSTOM8,
 COL_CUSTOM9        = display::COL_CUSTOM9,
 COL_PROGRESS0      = display::COL_PROGRESS0,
 COL_PROGRESS20     = display::COL_PROGRESS20,
 COL_PROGRESS40     = display::COL_PROGRESS40,
 COL_PROGRESS60     = display::COL_PROGRESS60,
 COL_PROGRESS80     = display::COL_PROGRESS80,
 COL_PROGRESS100    = display::COL_PROGRESS100,
 COL_PROGRESS120    = display::COL_PROGRESS120,
 COL_MAX = display::RCOLOR_MAX,
    COL_DOWN_TIME   = display::COL_DOWN_TIME,
    COL_PRIO       = display::COL_PRIO,
    COL_STATE      = display::COL_STATE,
    COL_RATIO      = display::COL_RATIO,
    COL_PROGRESS   = display::COL_PROGRESS,
    COL_ALERT      = display::COL_ALERT,
    COL_UP_TIME    = display::COL_UP_TIME,
    COL_SYS_MAX     = display::COL_SYS_MAX
};

/*enum ColorKind {
    COL_DEFAULT = display::RCOLOR_NCURSES_DEFAULT,
    COL_TITLE = display::RCOLOR_TITLE,
    COL_FOOTER = display::RCOLOR_FOOTER,
    COL_FOCUS = display::RCOLOR_FOCUS,
    COL_LABEL = display::RCOLOR_LABEL, // 20
    COL_INFO = display::RCOLOR_INFO,
    COL_ALARM = display::RCOLOR_ALARM,
    COL_COMPLETE = display::RCOLOR_COMPLETE,
    COL_SEEDING = display::RCOLOR_SEEDING,
    COL_STOPPED = display::RCOLOR_STOPPED,
    COL_QUEUED = display::RCOLOR_QUEUED,
    COL_INCOMPLETE = display::RCOLOR_INCOMPLETE,
    COL_LEECHING = display::RCOLOR_LEECHING,
    COL_ODD = display::RCOLOR_ODD,
    COL_EVEN = display::RCOLOR_EVEN,
    COL_CUSTOM1,
    COL_CUSTOM2,
    COL_CUSTOM3,
    COL_CUSTOM4,
    COL_CUSTOM5,
    COL_CUSTOM6,
    COL_CUSTOM7,
    COL_CUSTOM8,
    COL_CUSTOM9,
    COL_PROGRESS0, // 10
    COL_PROGRESS20,
    COL_PROGRESS40,
    COL_PROGRESS60,
    COL_PROGRESS80,
    COL_PROGRESS100,
    COL_PROGRESS120,
    COL_MAX = display::RCOLOR_MAX,

    COL_DOWN_TIME = COL_SYS_BASE,
    COL_PRIO,
    COL_STATE,
    COL_RATIO,
    COL_PROGRESS,
    COL_ALERT,
    COL_UP_TIME,
    COL_SYS_MAX
};
*/

} // namespace

// defined in command_pyroscope.cc (exported here so we only have to patch in one .h)
extern void add_capability(const char* name);
extern size_t u8_length(const std::string& text);
extern std::string u8_chop(const std::string& text, size_t glyphs);

#endif
