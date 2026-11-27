const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

const SAMPLE_ICS = [
  "BEGIN:VCALENDAR",
  "VERSION:2.0",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20261010",
  "DTEND;VALUE=DATE:20261011",
  "SUMMARY:Pchum Ben Festival",
  "DESCRIPTION:Public holiday",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20261011",
  "DTEND;VALUE=DATE:20261012",
  "SUMMARY:Pchum Ben Festival",
  "DESCRIPTION:Public holiday",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20261012",
  "DTEND;VALUE=DATE:20261013",
  "SUMMARY:Pchum Ben Festival",
  "DESCRIPTION:Public holiday",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20261109",
  "DTEND;VALUE=DATE:20261110",
  "SUMMARY:Independence Day",
  "DESCRIPTION:Public holiday",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20261123",
  "DTEND;VALUE=DATE:20261124",
  "SUMMARY:Water Festival",
  "  Ceremony (Day 1)",
  "DESCRIPTION:Public holiday",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20260501",
  "DTEND;VALUE=DATE:20260502",
  "SUMMARY:Labour Day",
  "DESCRIPTION:Public holiday",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20260501",
  "DTEND;VALUE=DATE:20260502",
  "SUMMARY:Visak Bochea Day",
  "DESCRIPTION:Public holiday",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20260618",
  "DTEND;VALUE=DATE:20260619",
  "SUMMARY:King's Mother's Birthday",
  "DESCRIPTION:Observance\\nTo hide observances\\, go to settings",
  "END:VEVENT",
  "END:VCALENDAR"
].join("\r\n")

test("parseHolidaysIcs unfolds lines, translates Khmer names, and classifies observances", () => {
  const map = Model.parseHolidaysIcs(SAMPLE_ICS)
  assert.ok(map)
  assert.equal(map["2026-11-09"][0].nameEn, "Independence Day")
  assert.equal(map["2026-11-09"][0].nameKm, "ទិវាបុណ្យឯករាជ្យជាតិ")
  assert.equal(map["2026-11-09"][0].kind, "public")

  // Folded summary line + (Day 1) Khmer numeral translation
  assert.equal(map["2026-11-23"][0].nameEn, "Water Festival Ceremony (Day 1)")
  assert.equal(map["2026-11-23"][0].nameKm, "ព្រះរាជពិធីបុណ្យអុំទូក (ថ្ងៃទី១)")

  // Multiple holidays on the same day
  assert.equal(map["2026-05-01"].length, 2)

  // Observance classification
  assert.equal(map["2026-06-18"][0].kind, "observance")
})

test("monthHolidays groups consecutive identical days and preserves separate days", () => {
  const map = Model.parseHolidaysIcs(SAMPLE_ICS)
  const oct = Model.monthHolidays(map, 2026, 9) // October
  assert.equal(oct.length, 1)
  assert.equal(oct[0].startDay, 10)
  assert.equal(oct[0].endDay, 12)
  assert.deepEqual(oct[0].keys, ["2026-10-10", "2026-10-11", "2026-10-12"])

  const nov = Model.monthHolidays(map, 2026, 10) // November
  assert.equal(nov.length, 2)
  assert.equal(nov[0].startDay, 9)
  assert.equal(nov[1].startDay, 23)
})

test("monthGrid attaches holiday metadata onto day cells", () => {
  const map = Model.parseHolidaysIcs(SAMPLE_ICS)
  const weeks = Model.monthGrid(2026, 10, 0, "2026-11-27", map)
  const allDays = weeks.flatMap(w => w.days)
  const nov9 = allDays.find(d => d.key === "2026-11-09")
  const nov10 = allDays.find(d => d.key === "2026-11-10")
  assert.equal(nov9.hasHoliday, true)
  assert.equal(nov9.hasPublicHoliday, true)
  assert.equal(nov10.hasHoliday, false)
})

test("language normalization, cycling, and formatting", () => {
  assert.equal(Model.normalizeHolidayLanguage("KM"), "km")
  assert.equal(Model.normalizeHolidayLanguage("invalid"), "en")
  assert.equal(Model.nextHolidayLanguage("en"), "km")
  assert.equal(Model.nextHolidayLanguage("km"), "both")
  assert.equal(Model.nextHolidayLanguage("both"), "en")

  const entry = { nameEn: "Peace Day", nameKm: "ទិវាសន្តិភាពនៅកម្ពុជា" }
  assert.equal(Model.formatHolidayPrimary(entry, "en"), "Peace Day")
  assert.equal(Model.formatHolidaySecondary(entry, "en"), "")
  assert.equal(Model.formatHolidayPrimary(entry, "km"), "ទិវាសន្តិភាពនៅកម្ពុជា")
  assert.equal(Model.formatHolidayPrimary(entry, "both"), "Peace Day")
  assert.equal(Model.formatHolidaySecondary(entry, "both"), "ទិវាសន្តិភាពនៅកម្ពុជា")

  // Unknown future holiday falls back cleanly to English in km mode
  const unknown = { nameEn: "Future National Day", nameKm: "" }
  assert.equal(Model.formatHolidayPrimary(unknown, "km"), "Future National Day")
  assert.equal(Model.formatHolidaySecondary(unknown, "both"), "")
})

test("formatHolidayTooltip neutralizes markup-shaped untrusted input", () => {
  const maliciousIcs = [
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "DTSTART;VALUE=DATE:20261201",
    "DTEND;VALUE=DATE:20261202",
    'SUMMARY:<img src="https://example.invalid/tracker"> <b>Holiday</b>',
    "END:VEVENT",
    "END:VCALENDAR"
  ].join("\n")

  const map = Model.parseHolidaysIcs(maliciousIcs)
  const tip = Model.formatHolidayTooltip(map["2026-12-01"], "en")
  assert.ok(!tip.includes("<img"))
  assert.ok(!tip.includes("<b>"))
  assert.ok(tip.includes("&lt;img"))
  assert.ok(tip.includes("&lt;b&gt;Holiday&lt;/b&gt;"))
})

test("rejects oversized or malformed ICS payloads", () => {
  assert.equal(Model.parseHolidaysIcs(""), null)
  assert.equal(Model.parseHolidaysIcs("not a calendar"), null)
  assert.equal(Model.parseHolidaysIcs("BEGIN:VCALENDAR\n" + "A".repeat(300000)), null)
})

test("nextUpcomingHoliday returns nearest holiday on or after given date", () => {
  const map = Model.parseHolidaysIcs(SAMPLE_ICS)
  const next = Model.nextUpcomingHoliday(map, "2026-11-10")
  assert.equal(next.key, "2026-11-23")
  assert.equal(next.nameEn, "Water Festival Ceremony (Day 1)")
})
