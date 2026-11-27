pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Shared Cambodia holiday loader/cache across monitors.
Item {
  id: root

  readonly property string python3Path: "/usr/bin/python3"
  readonly property int maxOutputChars: 524288
  readonly property int watchdogMs: 22000

  readonly property string fetcherPath: {
    var url = Qt.resolvedUrl("./fetch_holidays.py")
    var s = "" + url
    if (s.indexOf("file://") === 0) s = s.substring(7)
    if (!s || s.charAt(0) !== "/" || s.indexOf("..") !== -1) return ""
    return s
  }

  property var holidaysByDate: ({})
  property bool loaded: false
  property bool loading: false
  property string errorMessage: ""
  property string lastSource: ""
  property double lastUpdatedAt: 0

  property string stdoutBuffer: ""
  property bool aborted: false

  function processEnvironment() {
    var env = {
      "HOME": Quickshell.env("HOME"),
      "PATH": "/usr/bin:/bin",
      "LANG": "C.UTF-8"
    }
    var pass = ["XDG_CACHE_HOME", "SSL_CERT_FILE", "SSL_CERT_DIR"]
    for (var i = 0; i < pass.length; i++) {
      var val = Quickshell.env(pass[i])
      if (val && val.charAt(0) === "/") env[pass[i]] = val
    }
    return env
  }

  function ensureLoaded(autoRefresh) {
    if (root.loading) return
    if (root.loaded) return
    runFetcher(autoRefresh === false ? "cache-only" : "load")
  }

  function refreshNow() {
    if (root.loading) return
    runFetcher("force")
  }

  function runFetcher(mode) {
    if (!root.fetcherPath) {
      root.errorMessage = "Holiday fetcher path unavailable"
      return
    }
    root.loading = true
    root.aborted = false
    root.stdoutBuffer = ""
    fetchProcess.command = [
      root.python3Path, "-I", "-S", "-B",
      root.fetcherPath,
      mode
    ]
    watchdog.restart()
    fetchProcess.running = true
  }

  function collectChunk(chunk) {
    if (root.aborted) return
    if (root.stdoutBuffer.length + chunk.length > root.maxOutputChars) {
      root.aborted = true
      root.stdoutBuffer = ""
      root.errorMessage = "Holiday response exceeded size limit"
      fetchProcess.signal(15)
      return
    }
    root.stdoutBuffer += chunk
  }

  function handleExited(exitCode) {
    watchdog.stop()
    var raw = root.stdoutBuffer
    root.stdoutBuffer = ""
    root.loading = false

    if (root.aborted) return
    if (exitCode !== 0 || raw === "") {
      if (root.errorMessage === "") root.errorMessage = "Could not load Cambodia holidays"
      return
    }

    var envelope = null
    try {
      envelope = JSON.parse(raw)
    } catch (e) {
      root.errorMessage = "Holiday cache returned invalid JSON"
      return
    }

    if (!envelope || typeof envelope !== "object") {
      root.errorMessage = "Holiday cache returned invalid data"
      return
    }

    if (typeof envelope.ics === "string" && envelope.ics.length > 0) {
      var parsed = Model.parseHolidaysIcs(envelope.ics)
      if (parsed !== null) {
        root.holidaysByDate = parsed
        root.loaded = true
        root.lastSource = String(envelope.source || "")
        root.lastUpdatedAt = Number(envelope.updatedAt || 0)
      }
    }

    root.errorMessage = typeof envelope.error === "string"
      ? Model.sanitizeText(envelope.error)
      : ""
  }

  Process {
    id: fetchProcess
    clearEnvironment: true
    environment: root.processEnvironment()
    workingDirectory: Quickshell.env("HOME")
    command: []
    running: false
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.collectChunk(chunk) }
    }
    stderr: SplitParser { splitMarker: ""; onRead: function(chunk) {} }
    onExited: function(exitCode) { root.handleExited(exitCode) }
  }

  Timer {
    id: watchdog
    interval: root.watchdogMs
    repeat: false
    onTriggered: {
      if (!fetchProcess.running) return
      root.aborted = true
      root.errorMessage = "Holiday fetch timed out"
      fetchProcess.signal(15)
    }
  }
}
