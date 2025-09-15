#ifndef RTORRENT_DISPLAY_COLOR_MAP_H
#define RTORRENT_DISPLAY_COLOR_MAP_H

#include <array>
#include <map>

#include <curses.h>

namespace display {

#define COL_SYS_BASE 90

enum ColorKind {
  RCOLOR_NCURSES_DEFAULT, // Color 0 is reserved by ncurses and cannot be changed
  RCOLOR_TITLE,
  RCOLOR_FOOTER,
  RCOLOR_FOCUS,
  RCOLOR_LABEL,
  RCOLOR_INFO,
  RCOLOR_ALARM,
  RCOLOR_COMPLETE,
  RCOLOR_SEEDING,
  RCOLOR_STOPPED,
  RCOLOR_QUEUED,
  RCOLOR_INCOMPLETE,
  RCOLOR_LEECHING,
  RCOLOR_ODD,
  RCOLOR_EVEN,
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
  RCOLOR_MAX,
  COL_DOWN_TIME = COL_SYS_BASE,
  COL_PRIO,
  COL_STATE,
  COL_RATIO,
  COL_PROGRESS,
  COL_ALERT,
  COL_UP_TIME,
  COL_SYS_MAX
};

static const std::array<const char*, RCOLOR_MAX> color_vars{
  nullptr,
  "ui.color.title",
  "ui.color.footer",
  "ui.color.focus",
  "ui.color.label",
  "ui.color.info",
  "ui.color.alarm",
  "ui.color.complete",
  "ui.color.seeding",
  "ui.color.stopped",
  "ui.color.queued",
  "ui.color.incomplete",
  "ui.color.leeching",
  "ui.color.odd",
  "ui.color.even",
  "ui.color.custom1",
  "ui.color.custom2",
  "ui.color.custom3",
  "ui.color.custom4",
  "ui.color.custom5",
  "ui.color.custom6",
  "ui.color.custom7",
  "ui.color.custom8",
  "ui.color.custom9",
  "ui.color.progress0",
  "ui.color.progress20",
  "ui.color.progress40",
  "ui.color.progress60",
  "ui.color.progress80",
  "ui.color.progress100",
  "ui.color.progress120",
};

} // namespace display
#endif
