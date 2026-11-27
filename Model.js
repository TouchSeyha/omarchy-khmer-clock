// Pure date, clock format, and Cambodia holiday parsing math.
// Kept Qt- and locale-free so it can be unit-tested directly under Node.

var MS_PER_DAY = 86400000
var WEEKDAY_NAMES = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

var CLOCK_FORMATS = [
  "dddd HH:mm",
  "dddd h:mm AP",
  "dddd HH:mm:ss",
  "dddd h:mm:ss AP",
  "HH:mm",
  "h:mm AP",
  "ddd d MMM HH:mm",
  "ddd d MMM h:mm AP",
  "d MMMM 'W'ww yyyy",
  "yyyy-MM-dd HH:mm"
]

var VERTICAL_CLOCK_FORMATS = [
  "HH\n—\nmm",
  "h\n—\nmm\nAP",
  "dd\nMMM\n'W'ww\n''yy",
  "HH\nmm"
]

var DEFAULT_LIFE_EXPECTANCY = 90

var MAX_ICS_CHARS = 262144
var MAX_EVENTS = 512
var MAX_SPAN_DAYS = 14
var MAX_TITLE_CHARS = 120
var UNSAFE_CONTROLS = /[\u0000-\u001f\u007f-\u009f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]/g

var HOLIDAY_LANGUAGES = ["en", "km", "both"]

var KHMER_DIGITS = ["០", "១", "២", "៣", "៤", "៥", "៦", "៧", "៨", "៩"]

// Official Khmer names for Cambodia public holidays returned by Google's
// public Cambodia holidays calendar feed. Unknown/future holidays fall back
// cleanly to the English summary from the feed.
var KHMER_HOLIDAY_NAMES = {
  "new year": "ទិវាចូលឆ្នាំសកល",
  "new year's day": "ទិវាចូលឆ្នាំសកល",
  "victory over genocide day": "ទិវាជ័យជម្នះលើរបបប្រល័យពូជសាសន៍",
  "international women day": "ទិវាអន្តរជាតិនារី",
  "international women's day": "ទិវាអន្តរជាតិនារី",
  "khmer new year day": "ពិធីបុណ្យចូលឆ្នាំថ្មីប្រពៃណីជាតិ",
  "khmer new year": "ពិធីបុណ្យចូលឆ្នាំថ្មីប្រពៃណីជាតិ",
  "labour day": "ទិវាពលកម្មអន្តរជាតិ",
  "international labor day": "ទិវាពលកម្មអន្តរជាតិ",
  "visak bochea day": "ពិធីបុណ្យវិសាខបូជា",
  "royal plowing ceremony": "ព្រះរាជពិធីច្រត់ព្រះនង្គ័ល",
  "king's birthday": "ព្រះរាជពិធីបុណ្យចម្រើនព្រះជន្មព្រះមហាក្សត្រ",
  "king's mother's birthday": "ព្រះរាជពិធីបុណ្យចម្រើនព្រះជន្មសម្តេចព្រះមហាក្សត្រី",
  "funan techo canal holiday": "ទិវាបើកការដ្ឋានព្រែកជីកហ្វូណនតេជោ",
  "constitutional day": "ទិវាប្រកាសរដ្ឋធម្មនុញ្ញ",
  "constitution day": "ទិវាប្រកាសរដ្ឋធម្មនុញ្ញ",
  "pchum ben festival": "ពិធីបុណ្យភ្ជុំបិណ្ឌ",
  "pchum ben": "ពិធីបុណ្យភ្ជុំបិណ្ឌ",
  "commemoration day of king's father": "ទិវាប្រារព្ធពិធីគោរពព្រះវិញ្ញាណក្ខន្ធព្រះបរមរតនកោដ្ឋ",
  "king's coronation day": "ព្រះរាជពិធីគ្រងព្រះបរមរាជសម្បត្តិ",
  "independence day": "ទិវាបុណ្យឯករាជ្យជាតិ",
  "water festival ceremony": "ព្រះរាជពិធីបុណ្យអុំទូក",
  "water festival": "ព្រះរាជពិធីបុណ្យអុំទូក",
  "peace day": "ទិវាសន្តិភាពនៅកម្ពុជា"
}

function clockNeedsSeconds(format) {
  var text = String(format === undefined || format === null ? "" : format)
  return /s/.test(text.replace(/'[^']*'?/g, ""))
}

function clockFormats(vertical) {
  return vertical ? VERTICAL_CLOCK_FORMATS.slice() : CLOCK_FORMATS.slice()
}

function clockFormatRing(configured, configuredAlt, presets) {
  var ring = []
  var candidates = (presets || []).concat([configuredAlt, configured])
  for (var i = 0; i < candidates.length; i++) {
    var format = String(candidates[i] === undefined || candidates[i] === null ? "" : candidates[i])
    if (format === "" || ring.indexOf(format) !== -1) continue
    ring.push(format)
  }
  return ring.length > 0 ? ring : ["HH:mm"]
}

function nextClockFormat(ring, current) {
  if (!ring || ring.length === 0) return ""
  var index = ring.indexOf(String(current === undefined || current === null ? "" : current))
  return ring[(index + 1) % ring.length]
}

function isoWeekLiteral(year, month, day) {
  return pad2(isoWeek(year, month, day))
}

function pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

function dateKey(year, month, day) {
  return year + "-" + pad2(Number(month) + 1) + "-" + pad2(day)
}

function keyForDate(date) {
  return dateKey(date.getFullYear(), date.getMonth(), date.getDate())
}

function coerceWeekStart(value) {
  if (value === undefined || value === null) return null
  if (typeof value === "number")
    return isFinite(value) ? ((Math.round(value) % 7) + 7) % 7 : null

  var text = String(value).replace(/^\s+|\s+$/g, "").toLowerCase()
  if (text === "") return null

  for (var i = 0; i < WEEKDAY_NAMES.length; i++)
    if (WEEKDAY_NAMES[i] === text || WEEKDAY_NAMES[i].substr(0, 3) === text) return i

  var parsed = parseInt(text, 10)
  return isFinite(parsed) ? ((parsed % 7) + 7) % 7 : null
}

function normalizedWeekStart(value, fallback) {
  var configured = coerceWeekStart(value)
  if (configured !== null) return configured
  var fallbackStart = coerceWeekStart(fallback)
  return fallbackStart === null ? 1 : fallbackStart
}

function weekStartSettingName(index) {
  return WEEKDAY_NAMES[normalizedWeekStart(index, 1)]
}

function toggledWeekStart(index) {
  return normalizedWeekStart(index, 1) === 1 ? 0 : 1
}

function weekdayOrder(weekStart) {
  var start = normalizedWeekStart(weekStart, 1)
  var out = []
  for (var i = 0; i < 7; i++) out.push((start + i) % 7)
  return out
}

function isoWeek(year, month, day) {
  var date = new Date(Date.UTC(year, month, day))
  var weekday = date.getUTCDay() || 7
  date.setUTCDate(date.getUTCDate() + 4 - weekday)
  var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
  return Math.ceil(((date.getTime() - yearStart.getTime()) / MS_PER_DAY + 1) / 7)
}

function dayOfYear(year, month, day) {
  return Math.round((Date.UTC(year, month, day) - Date.UTC(year, 0, 1)) / MS_PER_DAY) + 1
}

function daysInYear(year) {
  return dayOfYear(year, 11, 31)
}

function yearProgress(year, month, day) {
  var total = daysInYear(year)
  if (total <= 0) return 0
  return Math.max(0, Math.min(1, (dayOfYear(year, month, day) - 1) / total))
}

function yearProgressPercent(year, month, day) {
  return Math.round(yearProgress(year, month, day) * 100)
}

function parseBirthYear(value, currentYear) {
  var now = Math.round(Number(currentYear))
  if (!isFinite(now)) return 0
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  if (!/^\d{4}$/.test(text)) return 0
  var year = parseInt(text, 10)
  if (!isFinite(year) || year > now || year < now - 120) return 0
  return year
}

function ageFromBirthYear(birthYear, currentYear) {
  var born = parseBirthYear(birthYear, currentYear)
  if (born <= 0) return 0
  return Math.round(Number(currentYear)) - born
}

function parseAge(value) {
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  if (!/^\d+$/.test(text)) return 0
  var years = parseInt(text, 10)
  if (!isFinite(years) || years <= 0 || years > 120) return 0
  return years
}

function parseLifeExpectancy(value) {
  var text = String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
  if (!/^\d+$/.test(text)) return DEFAULT_LIFE_EXPECTANCY
  var years = parseInt(text, 10)
  if (!isFinite(years) || years <= 0 || years > 150) return DEFAULT_LIFE_EXPECTANCY
  return years
}

function lifeProgress(age, expectancy) {
  var years = parseAge(age)
  var span = parseLifeExpectancy(expectancy)
  if (years <= 0 || span <= 0) return 0
  return Math.max(0, Math.min(1, years / span))
}

function lifeProgressPercent(age, expectancy) {
  return Math.round(lifeProgress(age, expectancy) * 100)
}

function monthGrid(year, month, weekStart, todayKey, holidaysByDate) {
  var start = normalizedWeekStart(weekStart, 1)
  var leading = (new Date(Date.UTC(year, month, 1)).getUTCDay() - start + 7) % 7
  var cursor = new Date(Date.UTC(year, month, 1 - leading))
  var today = String(todayKey || "")
  var map = holidaysByDate && typeof holidaysByDate === "object" ? holidaysByDate : null
  var weeks = []

  for (var w = 0; w < 6; w++) {
    var days = []
    var thursday = null
    for (var d = 0; d < 7; d++) {
      var cellYear = cursor.getUTCFullYear()
      var cellMonth = cursor.getUTCMonth()
      var cellDay = cursor.getUTCDate()
      var weekday = cursor.getUTCDay()
      var key = dateKey(cellYear, cellMonth, cellDay)
      if (weekday === 4) thursday = { year: cellYear, month: cellMonth, day: cellDay }
      var entries = map && Object.prototype.hasOwnProperty.call(map, key) ? map[key] : []
      var hasPublic = false
      for (var h = 0; h < entries.length; h++) {
        if (entries[h].kind !== "observance") {
          hasPublic = true
          break
        }
      }
      days.push({
        key: key,
        year: cellYear,
        month: cellMonth,
        day: cellDay,
        weekday: weekday,
        inMonth: cellMonth === month && cellYear === year,
        weekend: weekday === 0 || weekday === 6,
        today: key === today,
        holidays: entries,
        hasHoliday: entries.length > 0,
        hasPublicHoliday: hasPublic
      })
      cursor.setUTCDate(cursor.getUTCDate() + 1)
    }
    var anchor = thursday || days[0]
    weeks.push({
      week: isoWeek(anchor.year, anchor.month, anchor.day),
      days: days
    })
  }
  return weeks
}

function msUntilNextTick(nowMs, step) {
  return step - nowMs % step
}

function stepMonth(year, month, delta) {
  var target = new Date(Date.UTC(year, Number(month) + Number(delta), 1))
  return { year: target.getUTCFullYear(), month: target.getUTCMonth() }
}

// ---- Holiday helpers ----

function sanitizeText(value) {
  if (typeof value !== "string") return ""
  var cleaned = value.replace(UNSAFE_CONTROLS, " ").replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "")
  if (cleaned.length > MAX_TITLE_CHARS) cleaned = cleaned.slice(0, MAX_TITLE_CHARS)
  return cleaned
}

// Neutralize HTML/Qt rich-text markup before passing dynamic text to shared
// Omarchy UI components (such as PanelToolTip) whose Text format we do not own.
function escapeMarkup(value) {
  return sanitizeText(String(value === undefined || value === null ? "" : value))
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

function toKhmerDigits(num) {
  return String(num).replace(/\d/g, function(ch) {
    return KHMER_DIGITS[Number(ch)] || ch
  })
}

function translateToKhmer(englishSummary) {
  var clean = sanitizeText(englishSummary)
  if (!clean) return ""
  var lower = clean.toLowerCase()
  if (Object.prototype.hasOwnProperty.call(KHMER_HOLIDAY_NAMES, lower))
    return KHMER_HOLIDAY_NAMES[lower]

  var dayMatch = clean.match(/^(.*?)\s*\(Day\s+(\d+)\)$/i)
  if (dayMatch) {
    var baseLower = dayMatch[1].replace(/^\s+|\s+$/g, "").toLowerCase()
    if (Object.prototype.hasOwnProperty.call(KHMER_HOLIDAY_NAMES, baseLower))
      return KHMER_HOLIDAY_NAMES[baseLower] + " (ថ្ងៃទី" + toKhmerDigits(dayMatch[2]) + ")"
  }
  return ""
}

function normalizeHolidayLanguage(value) {
  var text = String(value === undefined || value === null ? "" : value)
    .replace(/^\s+|\s+$/g, "")
    .toLowerCase()
  return HOLIDAY_LANGUAGES.indexOf(text) !== -1 ? text : "both"
}

function nextHolidayLanguage(current) {
  var normalized = normalizeHolidayLanguage(current)
  var idx = HOLIDAY_LANGUAGES.indexOf(normalized)
  return HOLIDAY_LANGUAGES[(idx + 1) % HOLIDAY_LANGUAGES.length]
}

function holidayLanguageLabel(lang) {
  var normalized = normalizeHolidayLanguage(lang)
  if (normalized === "km") return "ខ្មែរ"
  if (normalized === "both") return "EN · ខ្មែរ"
  return "EN"
}

function unescapeIcsText(value) {
  return String(value || "")
    .replace(/\\n/gi, " ")
    .replace(/\\,/g, ",")
    .replace(/\\;/g, ";")
    .replace(/\\\\/g, "\\")
}

function parseIcsDate(raw) {
  var match = String(raw || "").match(/^(\d{4})(\d{2})(\d{2})/)
  if (!match) return null
  var year = parseInt(match[1], 10)
  var month = parseInt(match[2], 10)
  var day = parseInt(match[3], 10)
  if (year < 1970 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31) return null
  var check = new Date(Date.UTC(year, month - 1, day))
  if (check.getUTCFullYear() !== year || check.getUTCMonth() !== month - 1 || check.getUTCDate() !== day)
    return null
  return { year: year, month: month - 1, day: day, utcMs: check.getTime() }
}

function parseHolidaysIcs(icsText) {
  if (typeof icsText !== "string" || icsText.length === 0 || icsText.length > MAX_ICS_CHARS)
    return null
  if (icsText.indexOf("BEGIN:VCALENDAR") === -1) return null

  var unfolded = icsText.replace(/\r\n/g, "\n").replace(/\r/g, "\n").replace(/\n[ \t]/g, "")
  var lines = unfolded.split("\n")

  var map = Object.create(null)
  var inEvent = false
  var eventCount = 0
  var dtStart = null
  var dtEnd = null
  var summary = ""
  var description = ""

  function commitEvent() {
    if (!dtStart || !summary) return
    var nameEn = sanitizeText(unescapeIcsText(summary))
    if (!nameEn) return
    var descClean = sanitizeText(unescapeIcsText(description)).toLowerCase()
    var kind = descClean.indexOf("observance") === 0 ? "observance" : "public"
    var nameKm = translateToKhmer(nameEn)

    var spanDays = 1
    if (dtEnd && dtEnd.utcMs > dtStart.utcMs) {
      spanDays = Math.round((dtEnd.utcMs - dtStart.utcMs) / MS_PER_DAY)
      if (spanDays < 1) spanDays = 1
      if (spanDays > MAX_SPAN_DAYS) spanDays = MAX_SPAN_DAYS
    }

    var cursor = new Date(dtStart.utcMs)
    for (var i = 0; i < spanDays; i++) {
      var y = cursor.getUTCFullYear()
      var m = cursor.getUTCMonth()
      var d = cursor.getUTCDate()
      var key = dateKey(y, m, d)
      if (!Object.prototype.hasOwnProperty.call(map, key)) map[key] = []
      var list = map[key]
      var duplicate = false
      for (var j = 0; j < list.length; j++) {
        if (list[j].nameEn === nameEn) {
          duplicate = true
          break
        }
      }
      if (!duplicate) {
        list.push({
          key: key,
          year: y,
          month: m,
          day: d,
          nameEn: nameEn,
          nameKm: nameKm,
          kind: kind
        })
      }
      cursor.setUTCDate(cursor.getUTCDate() + 1)
    }
  }

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line === "BEGIN:VEVENT") {
      if (++eventCount > MAX_EVENTS) break
      inEvent = true
      dtStart = null
      dtEnd = null
      summary = ""
      description = ""
      continue
    }
    if (line === "END:VEVENT") {
      if (inEvent) commitEvent()
      inEvent = false
      continue
    }
    if (!inEvent) continue

    var colon = line.indexOf(":")
    if (colon <= 0) continue
    var prop = line.slice(0, colon).split(";")[0].toUpperCase()
    var val = line.slice(colon + 1)
    if (prop === "DTSTART") dtStart = parseIcsDate(val)
    else if (prop === "DTEND") dtEnd = parseIcsDate(val)
    else if (prop === "SUMMARY") summary = val
    else if (prop === "DESCRIPTION") description = val
  }

  return map
}

function formatHolidayPrimary(entry, language) {
  if (!entry) return ""
  var lang = normalizeHolidayLanguage(language)
  if (lang === "km") return entry.nameKm || entry.nameEn || ""
  return entry.nameEn || ""
}

function formatHolidaySecondary(entry, language) {
  if (!entry) return ""
  var lang = normalizeHolidayLanguage(language)
  if (lang === "both" && entry.nameKm && entry.nameKm !== entry.nameEn)
    return entry.nameKm
  return ""
}

function formatHolidayTooltip(entries, language) {
  if (!entries || entries.length === 0) return ""
  var lines = []
  for (var i = 0; i < entries.length; i++) {
    var primary = formatHolidayPrimary(entries[i], language)
    var secondary = formatHolidaySecondary(entries[i], language)
    if (primary && secondary) lines.push(escapeMarkup(primary) + " · " + escapeMarkup(secondary))
    else if (primary) lines.push(escapeMarkup(primary))
  }
  return lines.join("\n")
}

// Chronological list of holidays in a given month. Consecutive days with the
// exact same name (e.g. "Pchum Ben Festival" Oct 10–12) are grouped into one row.
function monthHolidays(holidaysByDate, year, month) {
  if (!holidaysByDate || typeof holidaysByDate !== "object") return []
  var prefix = year + "-" + pad2(Number(month) + 1) + "-"
  var keys = Object.keys(holidaysByDate).filter(function(k) {
    return k.indexOf(prefix) === 0
  }).sort()

  var items = []
  for (var i = 0; i < keys.length; i++) {
    var entries = holidaysByDate[keys[i]] || []
    for (var j = 0; j < entries.length; j++) {
      var e = entries[j]
      var merged = false
      for (var k = items.length - 1; k >= 0; k--) {
        if (items[k].nameEn === e.nameEn && items[k].endDay === e.day - 1) {
          items[k].endDay = e.day
          items[k].endKey = e.key
          items[k].keys.push(e.key)
          merged = true
          break
        }
      }
      if (!merged) {
        items.push({
          startDay: e.day,
          endDay: e.day,
          startKey: e.key,
          endKey: e.key,
          keys: [e.key],
          nameEn: e.nameEn,
          nameKm: e.nameKm,
          kind: e.kind
        })
      }
    }
  }
  return items
}

function nextUpcomingHoliday(holidaysByDate, fromKey) {
  if (!holidaysByDate || typeof holidaysByDate !== "object") return null
  var start = String(fromKey || "")
  var keys = Object.keys(holidaysByDate).filter(function(k) {
    return k >= start && holidaysByDate[k] && holidaysByDate[k].length > 0
  }).sort()
  if (keys.length === 0) return null
  return holidaysByDate[keys[0]][0]
}

if (typeof module !== "undefined") {
  module.exports = {
    msUntilNextTick: msUntilNextTick,
    dateKey: dateKey,
    keyForDate: keyForDate,
    normalizedWeekStart: normalizedWeekStart,
    weekStartSettingName: weekStartSettingName,
    toggledWeekStart: toggledWeekStart,
    weekdayOrder: weekdayOrder,
    isoWeek: isoWeek,
    dayOfYear: dayOfYear,
    daysInYear: daysInYear,
    yearProgress: yearProgress,
    yearProgressPercent: yearProgressPercent,
    parseAge: parseAge,
    parseBirthYear: parseBirthYear,
    ageFromBirthYear: ageFromBirthYear,
    parseLifeExpectancy: parseLifeExpectancy,
    lifeProgress: lifeProgress,
    lifeProgressPercent: lifeProgressPercent,
    monthGrid: monthGrid,
    stepMonth: stepMonth,
    clockFormats: clockFormats,
    clockNeedsSeconds: clockNeedsSeconds,
    clockFormatRing: clockFormatRing,
    nextClockFormat: nextClockFormat,
    isoWeekLiteral: isoWeekLiteral,
    sanitizeText: sanitizeText,
    escapeMarkup: escapeMarkup,
    toKhmerDigits: toKhmerDigits,
    translateToKhmer: translateToKhmer,
    normalizeHolidayLanguage: normalizeHolidayLanguage,
    nextHolidayLanguage: nextHolidayLanguage,
    holidayLanguageLabel: holidayLanguageLabel,
    parseHolidaysIcs: parseHolidaysIcs,
    formatHolidayPrimary: formatHolidayPrimary,
    formatHolidaySecondary: formatHolidaySecondary,
    formatHolidayTooltip: formatHolidayTooltip,
    monthHolidays: monthHolidays,
    nextUpcomingHoliday: nextUpcomingHoliday
  }
}
