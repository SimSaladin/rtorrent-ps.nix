// PyroScope - rTorrent Command Extensions
// Copyright (c) 2011 The PyroScope Project <pyroscope.project@gmail.com>
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

#include "config.h"
#include "globals.h"

#include <cstdio>
#include <climits>
#include <ctime>
#include <cwchar>
#include <set>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <rak/path.h>
#include <rak/algorithm.h>
#include "utils/functional.h"

#include "core/download.h"
#include "core/manager.h"
#include "core/view_manager.h"
#include "rpc/parse.h"
#include <torrent/tracker/tracker.h>
#include "tracker/tracker_list.h"
#include "download/download_main.h"
#include "ui/root.h"
#include "ui/download_list.h"
#include "ui/element_base.h"
#include "ui/element_download_list.h"

#include "globals.h"
#include "control.h"
#include "command_helpers.h"


// In 0.9.x this changed to 'tr1' (dropping sigc::bind), see https://stackoverflow.com/a/4682954/2748717
// "C++ Technical Report 1" was later added to "C++11", using tr1 makes stuff compile on older GCC
#define _cxxstd_ std

// List of system capabilities for `system.has` command
static std::set<std::string> system_capabilities;

// handle for message log file
namespace core {
int log_messages_fd = -1;
};


// return the "main" tracker for this download item
torrent::tracker::Tracker* get_active_tracker(torrent::Download* item) {
    torrent::TrackerList* tl = item->main()->tracker_list();
    torrent::tracker::Tracker* tracker = 0;
    torrent::tracker::Tracker* fallback = 0;

    for (size_t trkidx = 0; trkidx < tl->size(); trkidx++) {
        tracker = &tl->at(trkidx);
        if (tracker->is_usable() && tracker->type() == torrent::tracker_enum::TRACKER_HTTP) {
            if (!fallback) fallback = tracker;
            if (tracker->state().scrape_complete() || tracker->state().scrape_incomplete()) {
                break;
            }
        }
        tracker = 0;
    }
    if (!tracker && tl->size()) tracker = fallback ? fallback : &tl->at(0);

    return tracker;
}


// return the domain name of the "main" tracker of the given download item
std::string get_active_tracker_domain(torrent::Download* item) {
    std::string url;
    torrent::tracker::Tracker* tracker = get_active_tracker(item);

    if (tracker && !tracker->url().empty()) {
        url = tracker->url();

        // snip url to domain name
        if (url.compare(0, 7, "http://")  == 0) url = url.substr(7);
        if (url.compare(0, 8, "https://") == 0) url = url.substr(8);
        if (url.find('/') > 0) url = url.substr(0, url.find('/'));
        if (url.find(':') > 0) url = url.substr(0, url.find(':'));

        // remove some common cruft
        const char* domain_cruft[] = {
            "tracker", "1.", "2.", "001.", ".",
            "www.", "cfdata.",
            0
        };
        for (const char** cruft = domain_cruft; *cruft; cruft++) {
            int cruft_len = strlen(*cruft);
            if (url.compare(0, cruft_len, *cruft) == 0) url = url.substr(cruft_len);
        }
    }

    return url;
}


// return various scrape information of the "main" tracker for this download item
int64_t get_active_tracker_scrape_info(const int operation, torrent::Download* item) {
    int64_t scrape_num = 0;
    torrent::tracker::Tracker* tracker = get_active_tracker(item);

    if (tracker) {
        switch (operation) {
            case 1:
                scrape_num = tracker->state().scrape_downloaded();
                break;
            case 2:
                scrape_num = tracker->state().scrape_complete();
                break;
            case 3:
                scrape_num = tracker->state().scrape_incomplete();
                break;
        }
    }

    return scrape_num;
}


static std::map<int, std::string> bound_commands[ui::DownloadList::DISPLAY_MAX_SIZE];

/*  @DOC
    ui.bind_key=display,key,"command1=[,...]"

        Binds the given key on a specified display to execute the commands when pressed.

        "display" must be one of "download_list", ...
        "key" can be either a single character for normal keys,
            ^ plus a character for control keys, or a 4 digit octal key code.

        Configuration example:
            # VIEW: Bind view #7 to the "rtcontrol" result
            schedule = bind_7,1,0,"ui.bind_key=download_list,7,ui.current_view.set=rtcontrol"
*/
torrent::Object apply_ui_bind_key(rpc::target_type target, const torrent::Object& rawArgs) {
    const torrent::Object::list_type& args = rawArgs.as_list();

    if (args.size() != 3)
        throw torrent::input_error("Expecting display, key, and commands.");

    // Parse positional arguments
    torrent::Object::list_const_iterator itr = args.begin();
    const std::string& element  = (itr++)->as_string();
    const std::string& keydef   = (itr++)->as_string();
    const std::string& commands = (itr++)->as_string();
    const bool verbose = rpc::call_command_value("ui.bind_key.verbose");

    // Get key index from definition
    if (keydef.empty() || keydef.size() > (keydef[0] == '0' ? 4 : keydef[0] == '^' ? 2 : 1))
        throw torrent::input_error("Bad key definition.");
    int key = keydef[0];
    if (key == '^' && keydef.size() > 1) key = keydef[1] & 31;
    if (key == '0' && keydef.size() != 1) {
        if (keydef.size() != 4)
            throw torrent::input_error("Bad key definition (expected 4 digit octal code).");
        key = (int) strtol(keydef.c_str(), (char **) NULL, 8);
    }

    // Look up display
    ui::DownloadList::Display displayType = ui::DownloadList::DISPLAY_MAX_SIZE;
    if (element == "download_list") {
        displayType = ui::DownloadList::DISPLAY_DOWNLOAD_LIST;
    } else {
        throw torrent::input_error(std::string("Unknown display ") + element);
    }
    ui::DownloadList* dl_list = control->ui()->download_list().get();
    if (!dl_list)
        throw torrent::input_error("No download list.");
    ui::ElementBase* display = dl_list->display(displayType);
    if (!display)
        throw torrent::input_error("Display not found.");

    // Bind the key to the given commands
    bool new_binding = display->bindings().find(key) == display->bindings().end();
    bound_commands[displayType][key] = commands; // keep hold of the string, so the c_str() below remains valid
    switch (displayType) {
        case ui::DownloadList::DISPLAY_DOWNLOAD_LIST:
            display->bindings()[key] =
                _cxxstd_::bind(&ui::ElementDownloadList::receive_command, (ui::ElementDownloadList*)display,
                               bound_commands[displayType][key].c_str());
            break;
        default:
            return torrent::Object();
    }

    if (!new_binding && verbose) {
        std::string msg = "Replaced key binding";
        msg += " for " + keydef + " in " + element + " with " + commands.substr(0, 30);
        if (commands.size() > 30) msg += "...";
        control->core()->push_log(msg.c_str());
    }

    return torrent::Object();
}


torrent::Object cmd_ui_focus_home() {
    ui::DownloadList* dl_list = control->ui()->download_list().get();
    core::View* dl_view = dl_list->current_view();

    if (!dl_view->empty_visible()) {
        dl_view->set_focus(dl_view->begin_visible());
        dl_view->set_last_changed();
    }

    return torrent::Object();
}


torrent::Object cmd_ui_focus_end() {
    ui::DownloadList* dl_list = control->ui()->download_list().get();
    core::View* dl_view = dl_list->current_view();

    if (!dl_view->empty_visible()) {
        dl_view->set_focus(dl_view->end_visible() - 1);
        dl_view->set_last_changed();
    }

    return torrent::Object();
}


static int ui_page_size() {
    // TODO: map 0 to the current view size, for adaptive scrolling
    return std::max(1, (int) rpc::call_command_value("ui.focus.page_size"));
}


torrent::Object cmd_ui_focus_pgup() {
    ui::DownloadList* dl_list = control->ui()->download_list().get();
    core::View* dl_view = dl_list->current_view();

    int skip = ui_page_size();
    if (!dl_view->empty_visible()) {
        if (dl_view->focus() == dl_view->end_visible())
            dl_view->set_focus(dl_view->end_visible() - 1);
        else if (dl_view->focus() - dl_view->begin_visible() >= skip)
            dl_view->set_focus(dl_view->focus() - skip);
        else
            dl_view->set_focus(dl_view->begin_visible());
        dl_view->set_last_changed();
    }

    return torrent::Object();
}


torrent::Object cmd_ui_focus_pgdn() {
    ui::DownloadList* dl_list = control->ui()->download_list().get();
    core::View* dl_view = dl_list->current_view();

    int skip = ui_page_size();
    if (!dl_view->empty_visible()) {
        if (dl_view->focus() == dl_view->end_visible())
            dl_view->set_focus(dl_view->begin_visible());
        else if (dl_view->end_visible() - dl_view->focus() > skip)
            dl_view->set_focus(dl_view->focus() + skip);
        else
            dl_view->set_focus(dl_view->end_visible() - 1);
        dl_view->set_last_changed();
    }

    return torrent::Object();
}


torrent::Object cmd_log_messages(const torrent::Object::string_type& arg) {
    if (arg.empty()) {
        control->core()->push_log_std("Closing message log file.");
    }

    if (core::log_messages_fd >= 0) {
        ::close(core::log_messages_fd);
        core::log_messages_fd = -1;
    }

    if (!arg.empty()) {
        core::log_messages_fd = open(rak::path_expand(arg).c_str(), O_WRONLY | O_APPEND | O_CREAT, 0644);

        if (core::log_messages_fd < 0) {
            throw torrent::input_error("Could not open message log file.");
        }

        control->core()->push_log_std("Opened message log file '" + rak::path_expand(arg) + "'.");
    }

    return torrent::Object();
}


torrent::Object cmd_import_return(rpc::target_type target, const torrent::Object& args) {
    // Handled in src/rpc/parse_commands.cc::parse_command_file via patch
    throw torrent::input_error("import.return");
}


torrent::Object cmd_do(rpc::target_type target, const torrent::Object& args) {
    return rpc::call_object(args, target);
}


torrent::Object cmd_d_custom_set_if_z(core::Download* download, const torrent::Object::list_type& args) {
    torrent::Object::list_const_iterator itr = args.begin();
    if (itr == args.end())
        throw torrent::bencode_error("d.custom.set_if_z: Missing key argument.");
    const std::string& key = (itr++)->as_string();
    if (key.empty())
        throw torrent::bencode_error("d.custom.set_if_z: Empty key argument.");
    if (itr == args.end())
        throw torrent::bencode_error("d.custom.set_if_z: Missing value argument.");

    bool set_it = false;
    try {
        const std::string& val = download->bencode()->get_key("rtorrent").get_key("custom").get_key_string(key);
        set_it = val.empty();
    } catch (torrent::bencode_error& e) {
        set_it = true;
    }
    if (set_it)
        download->bencode()->get_key("rtorrent").
            insert_preserve_copy("custom", torrent::Object::create_map()).first->second.
            insert_key(key, itr->as_string());

    return torrent::Object();
}


torrent::Object cmd_d_custom_erase(core::Download* download, const torrent::Object::list_type& args) {
    for (torrent::Object::list_type::const_iterator itr = args.begin(), last = args.end(); itr != last; itr++) {
        const std::string& key = itr->as_string();
        if (key.empty())
            throw torrent::bencode_error("d.custom.erase: Empty key argument.");

        download->bencode()->get_key("rtorrent").get_key("custom").erase_key(key);
    }

    return torrent::Object();
}



torrent::Object cmd_d_custom_toggle(core::Download* download, const std::string& key) {
    bool result = true;
    try {
        const std::string& strval = download->bencode()->get_key("rtorrent").get_key("custom").get_key_string(key);
        if (!strval.empty()) {
            char* junk = 0;
            long number = strtol(strval.c_str(), &junk, 10);
            while (std::isspace(*junk)) ++junk;
            result = !*junk && number == 0;
        }
    } catch (torrent::bencode_error& e) {
        // true
    }

    download->bencode()->get_key("rtorrent").
        insert_preserve_copy("custom", torrent::Object::create_map()).first->second.
        insert_key(key, result ? "1" : "0");
    return (int64_t) (result ? 1 : 0);
}


torrent::Object retrieve_d_custom_as_value(core::Download* download, const std::string& key) {
    try {
        const std::string& strval = download->bencode()->get_key("rtorrent").get_key("custom").get_key_string(key);
        if (strval.empty())
            return (int64_t) 0;

        char* junk = 0;
        long result = strtol(strval.c_str(), &junk, 10);
        if (*junk)
            throw torrent::input_error("d.custom.as_value(" + key + "): junk at end of '" + strval + "'!");
        return (int64_t) result;
    } catch (torrent::bencode_error& e) {
        return (int64_t) 0;
    }
}



/*  throttle.names=

    Returns a list of all defined throttle names,
    including the built-in ones (i.e. '' and NULL).

    https://github.com/pyroscope/rtorrent-ps/issues/65
 */
torrent::Object cmd_throttle_names() {
    torrent::Object result = torrent::Object::create_list();
    torrent::Object::list_type& resultList = result.as_list();

    resultList.push_back(std::string());
    for (core::ThrottleMap::const_iterator itr = control->core()->throttles().begin();
         itr != control->core()->throttles().end(); itr++) {
       resultList.push_back(itr->first);
    }

    return result;
}


// Get length of an UTF8-encoded std::string
size_t u8_length(const std::string& text) {
    // Take total length and subtract number of non-leading multi-bytes
    return text.length() - count_if(text.begin(), text.end(),
                                    [](char c)->bool { return (c & 0xC0) == 0x80; });
}


// Chop off an UTF-8 string
std::string u8_chop(const std::string& text, size_t glyphs) {
    std::mbstate_t mbs = std::mbstate_t();
    size_t bytes = 0, skip;
    const char* pos = text.c_str();

    while (*pos && glyphs-- > 0 && (skip = std::mbrlen(pos, text.length() - bytes, &mbs)) > 0) {
        pos += skip;
        bytes += skip;
    }

    return bytes < text.length() ? text.substr(0, bytes) : text;
}


static const std::string& string_get_first_arg(const char* name, const torrent::Object::list_type& args) {
    torrent::Object::list_const_iterator itr = args.begin();
    if (args.size() < 1 || !itr->is_string()) {
        throw torrent::input_error("string." + std::string(name) + " needs a string argument.0!");
    }
    return itr->as_string();
}


// get a numeric arg from a string or value, advancing the passed iterator
static int64_t string_get_value_arg(const char* name, torrent::Object::list_const_iterator& itr) {
    int64_t result = 0;
    if (itr->is_string()) {
        char* junk = 0;
        result = strtol(itr->as_string().c_str(), &junk, 10);
        if (*junk) {
            throw torrent::input_error("string." + std::string(name) + ": "
                                       "junk at end of value: " + itr->as_string());
        }
    } else {
        result = itr->as_value();
    }

    ++itr;
    return result;
}


torrent::Object cmd_string_len(rpc::target_type target, const torrent::Object::list_type& args) {
    std::mbstate_t mbs = std::mbstate_t();
    std::string text = string_get_first_arg("len", args);
    const char* pos = text.c_str();
    int glyphs = 0, bytes = 0, skip;

    while (*pos && (skip = std::mbrlen(pos, text.length() - bytes, &mbs)) > 0) {
        pos += skip;
        bytes += skip;
        ++glyphs;
    }

    return (int64_t) glyphs;
}


torrent::Object cmd_string_join(rpc::target_type target, const torrent::Object::list_type& args) {
    std::string delim = string_get_first_arg("join", args);
    std::string result;
    torrent::Object::list_const_iterator first = args.begin() + 1, last = args.end();

    for (torrent::Object::list_const_iterator itr = first; itr != last; ++itr) {
        if (itr != first) result += delim;
        rpc::print_object_std(&result, &*itr, 0);
    }

    return result;
}


torrent::Object cmd_string_strip(int where, const torrent::Object::list_type& args) {
    std::string text = string_get_first_arg("[lr]strip", args);
    torrent::Object::list_const_iterator first = args.begin() + 1, last = args.end();

    if (args.size() == 1) {
        // Strip whitespace
        if (where <= 0) {
            text.erase(text.begin(),
                       std::find_if(text.begin(), text.end(),
                                    std::not1(std::ptr_fun<int, int>(std::isspace))));
        }
        if (where >= 0) {
            text.erase(std::find_if(text.rbegin(), text.rend(),
                                    std::not1(std::ptr_fun<int, int>(std::isspace))).base(),
                       text.end());
        }
    } else {
        size_t lpos = 0, rpos = text.length();
        bool changed;
        do {
            changed = false;
            for (torrent::Object::list_const_iterator itr = first; itr != last; ++itr) {
                const std::string& strippable = itr->as_string();
                if (strippable.empty()) continue;

                bool found;
                do {
                    found = false;

                    if (where <= 0) {
                        if (0 == strncmp(text.c_str() + lpos, strippable.c_str(), strippable.length())) {
                            lpos += strippable.length();
                            changed = found = true;
                        }
                    }
                    if (where >= 0 && lpos <= rpos - strippable.length()) {
                        if (0 == strncmp(text.c_str() + rpos - strippable.length(), strippable.c_str(), strippable.length())) {
                            rpos -= strippable.length();
                            changed = found = true;
                        }
                    }
                } while (found && lpos < rpos);
            }
        } while (changed && lpos < rpos);
        text = lpos < rpos ? text.substr(lpos, rpos - lpos) : "";
    }

    return text;
}


torrent::Object cmd_string_pad(bool at_end, const torrent::Object::list_type& args) {
    std::string text;
    if (args.size() > 0 && args.begin()->is_value()) {
        char buf[65];
        snprintf(buf, sizeof(buf), "%ld", (long)args.begin()->as_value());
        text = buf;
    } else {
        text = string_get_first_arg("[lr]pad", args);
    }

    torrent::Object::list_const_iterator itr = args.begin() + 1;
    int64_t pad_len = 0;
    std::string filler;
    if (itr != args.end()) pad_len = string_get_value_arg("[lr]pad(pad_len)", itr);
    if (itr != args.end()) filler = (itr++)->as_string();
    if (pad_len < 0)
       throw torrent::input_error("string.[lr]pad: Invalid negative padding length!");
    if (filler.empty()) filler = " ";
    size_t text_len = u8_length(text), filler_len = u8_length(filler);

    if (size_t(pad_len) > text_len) {
        std::string pad;
        size_t count = size_t(pad_len) - text_len;

        if (filler.length() == 1) { // optimize the common case
            pad.insert(0, count, filler.at(0));
        } else while (count > 0) {
            if (count >= filler_len) {
                pad += filler;
                count -= filler_len;
            } else {
                pad += u8_chop(filler, count);
                count = 0;
            }
        }

        return at_end ? text + pad : pad + text;
    }

    return text;
}


torrent::Object cmd_string_split(rpc::target_type target, const torrent::Object::list_type& args) {
    const std::string text = string_get_first_arg("split", args);
    if (args.size() != 2 || !args.rbegin()->is_string()) {
        throw torrent::input_error("string.split needs a string argument.1!");
    }
    const std::string delim = args.rbegin()->as_string();
    torrent::Object result = torrent::Object::create_list();
    torrent::Object::list_type& resultList = result.as_list();

    if (delim.length()) {
        size_t pos = 0, next = 0;

        while ((next = text.find(delim, pos)) != std::string::npos) {
            resultList.push_back(text.substr(pos, next - pos));
            pos = next + delim.length();
        }
        resultList.push_back(text.substr(pos));
    } else {
        std::mbstate_t mbs = std::mbstate_t();
        const char* cpos = text.c_str();
        int bytes = 0, skip;

        while (*cpos && (skip = std::mbrlen(cpos, text.length() - bytes, &mbs)) > 0) {
            resultList.push_back(std::string(cpos, skip));
            cpos += skip;
            bytes += skip;
        }
    }

    return result;
}


torrent::Object cmd_string_substr(rpc::target_type target, const torrent::Object::list_type& args) {
    const std::string text = string_get_first_arg("substr", args);

    torrent::Object::list_const_iterator itr = args.begin() + 1;
    int64_t glyphs = 0, count = text.length();
    std::string fallback;
    if (itr != args.end()) glyphs = string_get_value_arg("substr(pos)", itr);
    if (itr != args.end()) count = string_get_value_arg("substr(count)", itr);
    if (itr != args.end()) fallback = (itr++)->as_string();

    if (count < 0) {
       throw torrent::input_error("string.substr: Invalid negative count!");
    }

    std::mbstate_t mbs = std::mbstate_t();
    const char* pos = text.c_str();
    int bytes = 0, skip;

    if (glyphs < 0) {
        std::string::size_type offsets[text.length() + 1];
        int64_t idx = 0;
        while (*pos && (skip = std::mbrlen(pos, text.length() - bytes, &mbs)) > 0) {
            offsets[idx++] = bytes;
            pos += skip;
            bytes += skip;
        }
        offsets[idx] = bytes;

        int64_t begidx = std::max(idx + glyphs, (int64_t) 0);
        int64_t endidx = std::min(idx, begidx + count);
        return text.substr(offsets[begidx], offsets[endidx] - offsets[begidx]);
    }

    while (glyphs-- > 0 && *pos && (skip = std::mbrlen(pos, text.length() - bytes, &mbs)) > 0) {
        pos += skip;
        bytes += skip;
    }
    if (!*pos) return fallback;

    int bytes_pos = bytes, bytes_count = 0;
    while (count-- > 0 && *pos && (skip = std::mbrlen(pos, text.length() - bytes, &mbs)) > 0) {
        pos += skip;
        bytes += skip;
        bytes_count += skip;
    }

    return text.substr(bytes_pos, bytes_count);
}


torrent::Object cmd_string_shorten(rpc::target_type target, const torrent::Object::list_type& args) {
    const std::string text = string_get_first_arg("shorten", args);

    torrent::Object::list_const_iterator itr = args.begin() + 1;
    int64_t u8len = u8_length(text), maxlen = u8len, tail = 5;
    if (itr != args.end()) maxlen = string_get_value_arg("shorten(maxlen)", itr);
    if (itr != args.end()) tail = string_get_value_arg("shorten(tail)", itr);

    if (maxlen < 0 || tail < 0) {
       throw torrent::input_error("string.shorten: Invalid negative maximal or tail length!");
    }

    if (!maxlen) return std::string();
    if (u8len <= maxlen) return text;

    int64_t head = std::max(int64_t(0), std::min(u8len, maxlen - tail - 1));
    if (2*tail >= maxlen) {
        tail = (maxlen - 1) / 2;
        head = maxlen - tail - 1;
    }

    std::mbstate_t mbs = std::mbstate_t();
    const char* pos = text.c_str();
    int bytes = 0, skip;
    while (head-- > 0 && *pos && (skip = std::mbrlen(pos, text.length() - bytes, &mbs)) > 0) {
        pos += skip;
        bytes += skip;
    }
    std::string::size_type head_bytes = bytes;
    std::string::size_type tail_bytes = bytes;

    std::string::size_type offsets[text.length() + 1];
    int64_t idx = 0;
    while (*pos && (skip = std::mbrlen(pos, text.length() - bytes, &mbs)) > 0) {
        offsets[idx++] = bytes;
        pos += skip;
        bytes += skip;
    }
    offsets[idx] = bytes;
    if (tail <= idx) tail_bytes = offsets[idx - tail];

    return text.substr(0, head_bytes) +
           (head + tail < u8len ? "…" : "") +
           (tail ? text.substr(tail_bytes) : "");
}


torrent::Object::value_type apply_string_contains(bool ignore_case, const torrent::Object::list_type& args) {
    if (args.size() < 2) {
        throw torrent::input_error("string.contains[_i] takes at least two arguments!");
    }

    torrent::Object::list_const_iterator itr = args.begin();
    std::string text = itr->as_string();
    if (ignore_case)
        std::transform(text.begin(), text.end(), text.begin(), ::tolower);

    for (++itr; itr != args.end(); ++itr) {
        std::string substr = itr->as_string();
        if (ignore_case)
            std::transform(substr.begin(), substr.end(), substr.begin(), ::tolower);
        if (substr.empty() || text.find(substr) != std::string::npos)
            return 1;
    }

    return 0;
}


torrent::Object cmd_string_contains(rpc::target_type target, const torrent::Object::list_type& args) {
    return apply_string_contains(false, args);
}

// XXX: Will NOT work correctly for non-ASCII strings!
torrent::Object cmd_string_contains_i(rpc::target_type target, const torrent::Object::list_type& args) {
    return apply_string_contains(true, args);
}


torrent::Object apply_string_mutate(int operation, const torrent::Object::list_type& args) {
    if (args.size() < 1) {
        throw torrent::input_error("string.* takes at least a string!");
    }

    torrent::Object::list_const_iterator itr = args.begin();
    std::string result = itr->as_string();

    for (++itr; itr != args.end(); ++itr) {
        std::string needle = itr->as_list().begin()->as_string();
        std::string subst = itr->as_list().rbegin()->as_string();

        switch (operation) {
        case 1:
            if (result == needle)
                result = subst;
            break;
        case 2:
            for (size_t pos = 0; (pos = result.find(needle, pos)) != std::string::npos; pos += subst.length()) {
                result.replace(pos, needle.length(), subst);
            }
            break;
        }
    }

    return result;
}

torrent::Object cmd_string_map(rpc::target_type target, const torrent::Object::list_type& args) {
    return apply_string_mutate(1, args);
}

torrent::Object cmd_string_replace(rpc::target_type target, const torrent::Object::list_type& args) {
    return apply_string_mutate(2, args);
}


torrent::Object cmd_string_compare(int mode, const torrent::Object::list_type& args) {
    const char* opnames[] = {"equals", "startswith", "endswith"};
    if (args.size() < 2) {
        throw torrent::input_error("string." + std::string(opnames[mode]) + " takes at least two arguments!");
    }

    std::string value = string_get_first_arg(opnames[mode], args);
    torrent::Object::list_const_iterator first = args.begin() + 1, last = args.end();

    for (torrent::Object::list_const_iterator itr = first; itr != last; ++itr) {
        const std::string& cmp = itr->as_string();
        switch (mode) {
        case 0:
            if (value == cmp) return (int64_t) 1;
            break;
        case 1:
            if (value.substr(0, cmp.length()) == cmp) return (int64_t) 1;
            break;
        case 2:
            if (value.length() >= cmp.length() && value.substr(value.length() - cmp.length()) == cmp) return (int64_t) 1;
            break;
        default:
            throw torrent::input_error("string comparison: internal error (unknown mode)");
        }
    }

    return (int64_t) 0;
}


torrent::Object cmd_array_at(rpc::target_type target, const torrent::Object::list_type& args) {
    if (args.size() != 2) {
        throw torrent::input_error("array.at takes at exactly two arguments!");
    }

    torrent::Object::list_const_iterator itr = args.begin();
    torrent::Object::list_type array = (itr++)->as_list();
    torrent::Object::value_type index = (itr++)->as_value();

    if (array.empty()) {
        throw torrent::input_error("array.at: array is empty!");
    }
    if (index < 0 || int(array.size()) <= index) {
        throw torrent::input_error("array.at: index out of bounds!");
    }

    return array.at(index);
}


void add_capability(const char* name) {
    system_capabilities.insert(name);
}


torrent::Object cmd_system_has(const torrent::Object::string_type& arg) {
    if (arg.empty()) {
        throw torrent::input_error("Passed empty string to 'system.has'!");
    }

    bool result = (system_capabilities.count(arg) != 0);
    if (!result && '=' == arg.at(arg.size()-1)) {
        result = rpc::commands.has(arg.substr(0, arg.size()-1));
    }
    return (int64_t) result;
}


torrent::Object cmd_system_has_list() {
    torrent::Object result = torrent::Object::create_list();
    torrent::Object::list_type& resultList = result.as_list();

    for (std::set<std::string>::const_iterator itr = system_capabilities.begin(); itr != system_capabilities.end(); itr++) {
       resultList.push_back(*itr);
    }

    return result;
}


torrent::Object cmd_system_has_methods(bool filter_public) {
    torrent::Object result = torrent::Object::create_list();
    torrent::Object::list_type& resultList = result.as_list();

    for (rpc::CommandMap::const_iterator itr = rpc::commands.begin(), last = rpc::commands.end(); itr != last; itr++) {
        if (bool(itr->second.m_flags & rpc::CommandMap::flag_public_rpc) == filter_public) {
            resultList.push_back(itr->first);
        }
    }

    return result;
}


torrent::Object cmd_system_client_version_as_value() {
    int64_t result = 0;
    const char* pos = PACKAGE_VERSION;

    while (*pos) {
        result = 100 * result + strtol(pos, (char**)&pos, 10);
        if (*pos && *pos != '.')
            throw torrent::input_error("INTERNAL ERROR: Bad version " PACKAGE_VERSION);
        if (*pos) ++pos;
    }
    return result;
}


torrent::Object cmd_d_tracker_domain(core::Download* download) {
    return get_active_tracker_domain(download->download());
}


torrent::Object cmd_d_tracker_scrape_info(const int operation, core::Download* download) {
    return get_active_tracker_scrape_info(operation, download->download());
}


// MATH FUNCTIONS

inline std::vector<int64_t> as_vector(const torrent::Object::list_type& args) {
    if (args.size() == 0)
        throw torrent::input_error("Wrong argument count in as_vector.");

    std::vector<int64_t> result;

    for (torrent::Object::list_const_iterator itr = args.begin(), last = args.end(); itr != last; itr++) {
        if (itr->is_value()) {
            result.push_back(itr->as_value());
        } else if (itr->is_string()) {
            result.push_back(rpc::convert_to_value(itr->as_string()));
        } else if (itr->is_list()) {
            std::vector<int64_t> subResult = as_vector(itr->as_list());
            result.insert(result.end(), subResult.begin(), subResult.end());
        } else {
            throw torrent::input_error("Wrong type supplied to as_vector.");
        }
    }

    return result;
}



void initialize_command_pyroscope() {
    /*
        *_ANY – no arguments (signature `cmd_*()`)
        *_ANY_P – the 'P' means 'private'
        *_STRING – takes (one?) string argument
        *_LIST – takes any number of arguments
        *_DL, *_DL_LIST – function gets a `core::Download*` as first parameter
        *_VAR_VALUE – define a value, with getter and setter, and a default
    */

    // string.* group
    CMD2_ANY_LIST("string.len", &cmd_string_len);
    CMD2_ANY_LIST("string.join", &cmd_string_join);
    CMD2_ANY_LIST("string.split", &cmd_string_split);
    CMD2_ANY_LIST("string.substr", &cmd_string_substr);
    CMD2_ANY_LIST("string.shorten", &cmd_string_shorten);
    CMD2_ANY_LIST("string.contains", &cmd_string_contains);
    CMD2_ANY_LIST("string.contains_i", &cmd_string_contains_i);
    CMD2_ANY_LIST("string.map", &cmd_string_map);
    CMD2_ANY_LIST("string.replace", &cmd_string_replace);
    CMD2_ANY_LIST("string.equals",      std::bind(&cmd_string_compare, 0, std::placeholders::_2));
    CMD2_ANY_LIST("string.startswith",  std::bind(&cmd_string_compare, 1, std::placeholders::_2));
    CMD2_ANY_LIST("string.endswith",    std::bind(&cmd_string_compare, 2, std::placeholders::_2));
    CMD2_ANY_LIST("string.strip",       std::bind(&cmd_string_strip,  0, std::placeholders::_2));
    CMD2_ANY_LIST("string.lstrip",      std::bind(&cmd_string_strip, -1, std::placeholders::_2));
    CMD2_ANY_LIST("string.rstrip",      std::bind(&cmd_string_strip,  1, std::placeholders::_2));
    CMD2_ANY_LIST("string.lpad",        std::bind(&cmd_string_pad, false, std::placeholders::_2));
    CMD2_ANY_LIST("string.rpad",        std::bind(&cmd_string_pad, true,  std::placeholders::_2));

    // array.* group
    CMD2_ANY_LIST("array.at", &cmd_array_at);

    // ui.focus.* – quick paging
    CMD2_ANY("ui.focus.home", _cxxstd_::bind(&cmd_ui_focus_home));
    CMD2_ANY("ui.focus.end", _cxxstd_::bind(&cmd_ui_focus_end));
    CMD2_ANY("ui.focus.pgup", _cxxstd_::bind(&cmd_ui_focus_pgup));
    CMD2_ANY("ui.focus.pgdn", _cxxstd_::bind(&cmd_ui_focus_pgdn));
    //CMD2_VAR_VALUE("ui.focus.page_size", 50);

    // system.has.*
    CMD2_ANY_STRING("system.has", _cxxstd_::bind(&cmd_system_has, _cxxstd_::placeholders::_2));
    CMD2_ANY("system.has.list", _cxxstd_::bind(&cmd_system_has_list));
    CMD2_ANY("system.has.private_methods", _cxxstd_::bind(&cmd_system_has_methods, false));
    CMD2_ANY("system.has.public_methods", _cxxstd_::bind(&cmd_system_has_methods, true));
    CMD2_ANY("system.client_version.as_value", _cxxstd_::bind(&cmd_system_client_version_as_value));

    // d.custom.* extensions
    CMD2_DL_LIST("d.custom.set_if_z", _cxxstd_::bind(&cmd_d_custom_set_if_z,
                                                     _cxxstd_::placeholders::_1, _cxxstd_::placeholders::_2));
    CMD2_DL_LIST("d.custom.erase", _cxxstd_::bind(&cmd_d_custom_erase,
                                                  _cxxstd_::placeholders::_1, _cxxstd_::placeholders::_2));
    CMD2_DL_STRING("d.custom.toggle",  _cxxstd_::bind(&cmd_d_custom_toggle,
                                                      _cxxstd_::placeholders::_1, _cxxstd_::placeholders::_2));
    CMD2_DL_STRING("d.custom.as_value",  _cxxstd_::bind(&retrieve_d_custom_as_value,
                                                        _cxxstd_::placeholders::_1, _cxxstd_::placeholders::_2));

    // Misc commands
    CMD2_ANY("ui.bind_key", &apply_ui_bind_key);
    CMD2_VAR_VALUE("ui.bind_key.verbose", 1);
    CMD2_ANY("throttle.names", _cxxstd_::bind(&cmd_throttle_names));
    CMD2_DL("d.tracker_domain", _cxxstd_::bind(&cmd_d_tracker_domain, _cxxstd_::placeholders::_1));
    CMD2_DL("d.tracker_scrape.downloaded", _cxxstd_::bind(&cmd_d_tracker_scrape_info, 1, _cxxstd_::placeholders::_1));
    CMD2_DL("d.tracker_scrape.complete", _cxxstd_::bind(&cmd_d_tracker_scrape_info, 2, _cxxstd_::placeholders::_1));
    CMD2_DL("d.tracker_scrape.incomplete", _cxxstd_::bind(&cmd_d_tracker_scrape_info, 3, _cxxstd_::placeholders::_1));

    CMD2_ANY_STRING("log.messages", _cxxstd_::bind(&cmd_log_messages, _cxxstd_::placeholders::_2));
    CMD2_ANY_P("import.return", &cmd_import_return);
    CMD2_ANY("do", _cxxstd_::bind(&cmd_do, _cxxstd_::placeholders::_1, _cxxstd_::placeholders::_2));

    // List capabilities of this build
    add_capability("system.has");         // self
    add_capability("rtorrent-ps");        // obvious
    add_capability("colors");             // not monochrome
    add_capability("canvas_v2");          // new PS 1.1 canvas with fully dynamic columns
    add_capability("collapsed-views");    // pre-collapsed views
    add_capability("fixed-log-xmlrpc-close");
}
