#!/usr/bin/python3
"""Fetch and cache Cambodia public holidays ICS from Google's fixed HTTPS feed.

Invoked as:
  /usr/bin/python3 -I -S -B /path/to/fetch_holidays.py [load|cache-only|force]

Always outputs a single bounded JSON object to stdout:
  {"source": "cache"|"network"|"stale-cache"|"none", "updatedAt": <unix>, "error": "...", "ics": "..."}
"""
from __future__ import annotations

import json
import os
import pwd
import sys
import tempfile
import time
import urllib.error
import urllib.request

FEED_URL = (
    "https://calendar.google.com/calendar/ical/"
    "en.kh%23holiday%40group.v.calendar.google.com/public/basic.ics"
)
CACHE_TTL_SEC = 7 * 24 * 60 * 60
HTTP_TIMEOUT_SEC = 15
MAX_ICS_BYTES = 262144


def cache_file_path() -> str:
    xdg = os.environ.get("XDG_CACHE_HOME", "")
    if xdg.startswith("/") and ".." not in xdg:
        base = xdg
    else:
        home = pwd.getpwuid(os.getuid()).pw_dir
        base = os.path.join(home, ".cache")
    return os.path.join(base, "omarchy-khmer-clock", "cambodia-holidays.ics")


def is_valid_ics(data: bytes) -> bool:
    if not data or len(data) > MAX_ICS_BYTES:
        return False
    return b"BEGIN:VCALENDAR" in data and b"END:VCALENDAR" in data


def read_cache(path: str) -> tuple[str | None, int]:
    try:
        st = os.stat(path)
        if st.st_size <= 0 or st.st_size > MAX_ICS_BYTES:
            return None, 0
        with open(path, "rb") as fh:
            raw = fh.read(MAX_ICS_BYTES + 1)
        if not is_valid_ics(raw):
            return None, 0
        return raw.decode("utf-8", "replace"), int(st.st_mtime)
    except OSError:
        return None, 0


def write_cache_atomic(path: str, raw: bytes) -> int:
    directory = os.path.dirname(path)
    os.makedirs(directory, mode=0o700, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(prefix=".cambodia-", suffix=".tmp", dir=directory)
    try:
        os.write(fd, raw)
        os.close(fd)
        fd = -1
        os.replace(tmp_path, path)
        return int(time.time())
    except OSError:
        if fd >= 0:
            try:
                os.close(fd)
            except OSError:
                pass
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        return int(time.time())


def fetch_remote() -> tuple[bytes | None, str]:
    req = urllib.request.Request(
        FEED_URL,
        headers={"User-Agent": "omarchy-khmer-clock/1.0"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT_SEC) as resp:
            if getattr(resp, "status", 200) != 200:
                return None, f"HTTP {resp.status}"
            raw = resp.read(MAX_ICS_BYTES + 1)
            if len(raw) > MAX_ICS_BYTES:
                return None, "Holiday feed exceeded 256 KiB limit"
            if not is_valid_ics(raw):
                return None, "Holiday feed returned invalid ICS"
            return raw, ""
    except urllib.error.URLError:
        return None, "Could not reach Google Calendar (offline?)"
    except TimeoutError:
        return None, "Holiday feed request timed out"
    except OSError:
        return None, "Failed to fetch Cambodia holidays"


def emit(source: str, updated_at: int, error: str, ics: str) -> None:
    payload = {
        "source": source,
        "updatedAt": updated_at,
        "error": error,
        "ics": ics,
    }
    sys.stdout.write(json.dumps(payload, ensure_ascii=False))
    sys.stdout.flush()


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "load"
    if mode not in ("load", "cache-only", "force"):
        emit("none", 0, "Invalid mode", "")
        sys.exit(2)

    path = cache_file_path()
    cached_ics, cached_mtime = read_cache(path)
    cache_fresh = cached_ics is not None and (time.time() - cached_mtime) < CACHE_TTL_SEC

    if mode == "cache-only":
        if cached_ics is not None:
            emit("cache", cached_mtime, "", cached_ics)
        else:
            emit("none", 0, "", "")
        return

    if mode == "load" and cache_fresh:
        emit("cache", cached_mtime, "", cached_ics)
        return

    raw, err = fetch_remote()
    if raw is not None:
        updated_at = write_cache_atomic(path, raw)
        emit("network", updated_at, "", raw.decode("utf-8", "replace"))
        return

    if cached_ics is not None:
        emit("stale-cache", cached_mtime, err, cached_ics)
        return

    emit("none", 0, err or "Failed to load holidays", "")


if __name__ == "__main__":
    main()
