import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Omarchy clock calendar popup with Cambodia public holidays highlighted
// on the grid and summarized below in English, Khmer, or both.
Panel {
  id: root
  moduleName: "touchseyha.khmer-clock"
  ipcTarget: "touchseyha.khmer-clock"
  manageIpc: false

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  property var anchorItem: null
  property var hostWidget: null
  property var holidayService: null
  readonly property var barIdentity: hostWidget || root

  property date today: new Date()
  readonly property string todayKey: Model.keyForDate(today)

  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()
  property string selectedDateKey: ""

  readonly property date viewDate: new Date(viewYear, viewMonth, 1, 12)
  readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

  readonly property real yearDone: Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
  readonly property int yearDonePercent: Model.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())

  readonly property int birthYear: Model.parseBirthYear(setting("birthYear", 0), today.getFullYear())
  readonly property int age: Model.ageFromBirthYear(birthYear, today.getFullYear())
  readonly property int lifeExpectancy: Model.parseLifeExpectancy(setting("lifeExpectancy", 0))
  readonly property real lifeDone: Model.lifeProgress(age, lifeExpectancy)
  readonly property int lifeDonePercent: Model.lifeProgressPercent(age, lifeExpectancy)
  property bool editingLife: false

  readonly property string holidayLanguage: Model.normalizeHolidayLanguage(setting("holidayLanguage", "en"))
  readonly property bool autoRefreshHolidays: setting("autoRefresh", true) !== false
  readonly property var holidaysByDate: holidayService ? holidayService.holidaysByDate : ({})
  readonly property bool holidaysLoading: holidayService ? holidayService.loading : false
  readonly property string holidaysError: holidayService ? holidayService.errorMessage : ""

  readonly property int weekStart: Model.normalizedWeekStart(setting("weekStartDay", null), labelLocale.firstDayOfWeek)
  readonly property var labelLocale: Qt.locale(Commons.I18n.formatLocale)
  readonly property string monthYearLabel: strings.t("clock.monthYear")
    .arg(labelLocale.standaloneMonthName(viewMonth, Locale.LongFormat))
    .arg(viewDate.toLocaleDateString(labelLocale, "yyyy"))
  readonly property string nextWeekStartLabel: labelLocale.dayName(Model.toggledWeekStart(weekStart), Locale.LongFormat)
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey, holidaysByDate)
  readonly property var currentMonthHolidays: Model.monthHolidays(holidaysByDate, viewYear, viewMonth)
  readonly property var nextHoliday: Model.nextUpcomingHoliday(holidaysByDate, todayKey)

  readonly property color contentForeground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int cellWidth: Style.space(52)
  readonly property int cellHeight: Style.space(34)
  readonly property int cellSpacing: Style.space(2)
  readonly property int weekColumnWidth: Style.space(32)
  readonly property int gutterWidth: Style.space(14)

  function open() {
    refresh()
    if (root.holidayService) root.holidayService.ensureLoaded(root.autoRefreshHolidays)
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    if (root.editingLife) root.cancelEditingLife()
    root.selectedDateKey = ""
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    root.today = new Date()
    root.goToToday()
  }

  function goToToday() {
    root.viewYear = today.getFullYear()
    root.viewMonth = today.getMonth()
    root.selectedDateKey = ""
  }

  function goToDate(year, month, key) {
    root.viewYear = year
    root.viewMonth = month
    root.selectedDateKey = key || ""
  }

  function moveMonth(delta) {
    var next = Model.stepMonth(viewYear, viewMonth, delta)
    root.viewYear = next.year
    root.viewMonth = next.month
    root.selectedDateKey = ""
  }

  function moveYear(delta) {
    moveMonth(delta * 12)
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function cycleHolidayLanguage() {
    var next = Model.nextHolidayLanguage(root.holidayLanguage)
    persistSettings({ holidayLanguage: next })
  }

  function setWeekStart(day) {
    var next = Model.normalizedWeekStart(day, root.weekStart)
    if (next === root.weekStart) return
    persistSettings({ weekStartDay: Model.weekStartSettingName(next) })
  }

  function startEditingLife() {
    root.editingLife = true
    Qt.callLater(function() {
      var content = panel.loadedContent
      if (!content) return
      var bornField = content.bornField
      var expectancyField = content.expectancyField
      bornField.text = root.birthYear > 0 ? String(root.birthYear) : ""
      expectancyField.text = String(root.lifeExpectancy)
      bornField.selectAll()
      bornField.forceActiveFocus()
    })
  }

  function cancelEditingLife() {
    root.editingLife = false
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  }

  function handleLifeKey(event, other) {
    if (event.key === Qt.Key_Escape) {
      root.cancelEditingLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.commitLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      other.selectAll()
      other.forceActiveFocus()
      event.accepted = true
    }
  }

  function clearLife() {
    if (root.birthYear <= 0) return
    persistSettings({ birthYear: 0 })
  }

  function commitLife() {
    var content = panel.loadedContent
    if (!content) return
    var bornField = content.bornField
    var expectancyField = content.expectancyField
    var born = Model.parseBirthYear(bornField.text, today.getFullYear())
    var span = Model.parseLifeExpectancy(expectancyField.text)
    if (born !== root.birthYear || span !== root.lifeExpectancy)
      persistSettings({ birthYear: born, lifeExpectancy: span })
    cancelEditingLife()
  }

  function toggleWeekStart() {
    setWeekStart(Model.toggledWeekStart(root.weekStart))
  }

  function weekdayLabel(weekday) {
    return String(labelLocale.dayName(weekday, Locale.ShortFormat)).toUpperCase()
  }

  function shortMonthDayLabel(year, month, day) {
    var d = new Date(year, month, day, 12)
    return d.toLocaleDateString(root.labelLocale, "MMM d")
  }

  function holidayRangeLabel(item) {
    if (!item) return ""
    var start = Commons.I18n.formatNumber(item.startDay)
    if (item.endDay > item.startDay)
      return start + "–" + Commons.I18n.formatNumber(item.endDay)
    return start
  }

  function holidayItemMatchesSelection(item) {
    if (!item || !root.selectedDateKey) return false
    return item.keys && item.keys.indexOf(root.selectedDateKey) !== -1
  }

  function holidayItemIsToday(item) {
    if (!item) return false
    return item.keys && item.keys.indexOf(root.todayKey) !== -1
  }

  WallClock {
    id: clock
    onDateChanged: {
      if (Model.keyForDate(clock.date) === String(root.todayKey)) return
      var followToday = root.viewingCurrentMonth
      root.today = clock.date
      if (followToday) root.goToToday()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      property alias bornField: bornField
      property alias expectancyField: expectancyField
      implicitHeight: calendarColumn.implicitHeight
      anchors.fill: parent
      blocked: root.editingLife
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.moveMonth(dx)
        if (dy !== 0) root.moveYear(dy)
      }
      onActivateRequested: root.goToToday()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "[") root.moveMonth(-1)
        else if (t === "]") root.moveMonth(1)
        else if (t === "{") root.moveYear(-1)
        else if (t === "}") root.moveYear(1)
        else if (t === "t" || t === "T") root.goToToday()
        else if (t === "w" || t === "W") root.toggleWeekStart()
        else if (t === "l" || t === "L") root.cycleHolidayLanguage()
      }

      Flickable {
        id: calendarScroll
        anchors.fill: parent
        contentWidth: calendarColumn.width
        contentHeight: calendarColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: calendarColumn
          width: Math.max(calendarScroll.width, gridColumn.width)
          spacing: Style.space(8)

          // ---- Hero: today, centered ----
          Item {
            width: parent.width
            height: heroRow.height

            Row {
              id: heroRow
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(22)

              Text {
                anchors.baseline: heroDate.baseline
                text: "󰃭"
                color: heroMouse.containsMouse
                  ? Style.hoverStateColor(root.contentForeground, Commons.Color.accent)
                  : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: 48
              }

              Text {
                id: heroDate
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: root.today.toLocaleDateString(root.labelLocale, strings.t("clock.dayMonthFormat"))
                color: heroMouse.containsMouse
                  ? Style.hoverStateColor(root.contentForeground, Commons.Color.accent)
                  : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: 52
                font.bold: true
              }
            }

            MouseArea {
              id: heroMouse
              x: heroRow.x
              y: heroRow.y
              width: heroRow.width
              height: heroRow.height
              enabled: !root.viewingCurrentMonth
              hoverEnabled: enabled
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goToToday()

              PanelToolTip {
                visible: heroMouse.containsMouse
                text: strings.t("clock.backToToday")
                fontFamily: root.contentFontFamily
              }
            }
          }

          // ---- Year progress rail ----
          Item {
            width: parent.width
            height: yearBlock.y + yearBlock.height

            Item {
              id: yearBlock
              y: Style.space(6)
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: Math.max(yearLabel.implicitHeight, Style.space(10))

              TapHandler {
                enabled: !root.editingLife
                onDoubleTapped: root.startEditingLife()
              }

              Row {
                visible: root.editingLife
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(10)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: strings.t("clock.born")
                  textFormat: Text.PlainText
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1
                }

                TextField {
                  id: bornField
                  width: Style.space(70)
                  anchors.verticalCenter: parent.verticalCenter
                  placeholderText: strings.t("clock.year")
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  inputMethodHints: Qt.ImhDigitsOnly
                  Keys.onPressed: function(event) { root.handleLifeKey(event, expectancyField) }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  leftPadding: Style.space(6)
                  text: strings.t("clock.liveTo")
                  textFormat: Text.PlainText
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1
                }

                TextField {
                  id: expectancyField
                  width: Style.space(60)
                  anchors.verticalCenter: parent.verticalCenter
                  placeholderText: "90"
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  inputMethodHints: Qt.ImhDigitsOnly
                  Keys.onPressed: function(event) { root.handleLifeKey(event, bornField) }
                }
              }

              Text {
                id: yearLabel
                textFormat: Text.PlainText
                visible: !root.editingLife
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Commons.I18n.formatNumber(root.today.getFullYear())
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              Text {
                id: yearPercent
                textFormat: Text.PlainText
                visible: !root.editingLife
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Commons.I18n.formatNumber(root.yearDonePercent) + "%"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                id: yearTrack
                visible: !root.editingLife
                anchors.left: yearLabel.right
                anchors.right: yearPercent.left
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Rectangle {
                  width: Math.round(parent.width * root.yearDone)
                  height: parent.height
                  radius: parent.radius
                  color: Style.selectedStateColor(root.contentForeground, Commons.Color.accent)

                  Behavior on width { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
                }
              }
            }
          }

          // ---- Optional Memento Mori bar ----
          Item {
            visible: root.birthYear > 0
            width: parent.width
            height: visible ? lifeBlock.height : 0

            Item {
              id: lifeBlock
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: Math.max(lifeLabel.implicitHeight, Style.space(10))

              Text {
                id: lifeLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: strings.t("clock.life")
                textFormat: Text.PlainText
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              Text {
                id: lifePercent
                textFormat: Text.PlainText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Commons.I18n.formatNumber(root.lifeDonePercent) + "%"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                anchors.left: lifeLabel.right
                anchors.right: lifePercent.left
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Rectangle {
                  width: Math.round(parent.width * root.lifeDone)
                  height: parent.height
                  radius: parent.radius
                  color: Style.selectedStateColor(root.contentForeground, Commons.Color.accent)

                  Behavior on width { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
                }
              }

              TapHandler {
                onDoubleTapped: root.clearLife()
              }

              MouseArea {
                id: lifeMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                PanelToolTip {
                  visible: lifeMouse.containsMouse
                  text: "Memento Mori"
                  fontFamily: root.contentFontFamily
                }
              }
            }
          }

          // ---- Month grid ----
          Item {
            width: parent.width
            height: gridColumn.y + gridColumn.height

            WheelHandler {
              onWheel: function(event) {
                if (event.angleDelta.y === 0) return
                root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
              }
            }

            Column {
              id: gridColumn
              y: Style.space(18)
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(3)

              Row {
                id: headerRow
                spacing: root.cellSpacing

                Rectangle {
                  width: root.weekColumnWidth
                  height: Style.space(16)
                  radius: Style.cornerRadius
                  color: weekStartMouse.containsMouse
                    ? Style.hoverFillFor(root.contentForeground, Commons.Color.accent)
                    : "transparent"

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: strings.t("clock.weekShort")
                    color: weekStartMouse.containsMouse
                      ? Style.hoverStateColor(root.contentForeground, Commons.Color.accent)
                      : Qt.darker(root.contentForeground, 1.9)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: true
                  }

                  MouseArea {
                    id: weekStartMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleWeekStart()
                  }

                  PanelToolTip {
                    visible: weekStartMouse.containsMouse
                    text: strings.t("clock.startWeeksOn").arg(root.nextWeekStartLabel)
                    fontFamily: root.contentFontFamily
                  }
                }

                Item {
                  width: root.gutterWidth
                  height: Style.space(16)
                }

                Repeater {
                  model: root.weekdays

                  Text {
                    textFormat: Text.PlainText
                    required property var modelData
                    width: root.cellWidth
                    height: Style.space(16)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.weekdayLabel(modelData)
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: true
                  }
                }
              }

              Repeater {
                model: root.weeks

                Row {
                  required property var modelData
                  spacing: root.cellSpacing

                  Text {
                    textFormat: Text.PlainText
                    width: root.weekColumnWidth
                    height: root.cellHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Commons.I18n.formatNumber(modelData.week)
                    color: Qt.darker(root.contentForeground, 1.9)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Item {
                    width: root.gutterWidth
                    height: root.cellHeight
                  }

                  Repeater {
                    model: modelData.days

                    Rectangle {
                      id: dayCell
                      required property var modelData

                      readonly property bool isSelected: root.selectedDateKey !== "" && root.selectedDateKey === modelData.key
                      readonly property bool isHoliday: modelData.hasHoliday === true
                      readonly property bool isPublic: modelData.hasPublicHoliday === true

                      width: root.cellWidth
                      height: root.cellHeight
                      radius: Style.cornerRadius
                      color: {
                        if (isSelected) return Util.alpha(Commons.Color.accent, 0.26)
                        if (isHoliday && dayMouse.containsMouse) return Util.alpha(Commons.Color.accent, 0.22)
                        if (isHoliday && modelData.inMonth) return Util.alpha(Commons.Color.accent, isPublic ? 0.14 : 0.08)
                        if (isHoliday) return Util.alpha(Commons.Color.accent, 0.05)
                        return "transparent"
                      }
                      border.width: (modelData.today || isSelected) ? Style.spacing.hairline : 0
                      border.color: isSelected
                        ? Commons.Color.accent
                        : Style.normalBorderFor(root.contentForeground, Commons.Color.accent)

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: dayCell.isHoliday ? -Style.space(2) : 0
                        text: Commons.I18n.formatNumber(modelData.day)
                        color: {
                          if (dayCell.isHoliday && modelData.inMonth) return Commons.Color.accent
                          if (dayCell.isHoliday) return Util.alpha(Commons.Color.accent, 0.55)
                          if (modelData.inMonth)
                            return modelData.weekend ? Qt.darker(root.contentForeground, 1.45) : root.contentForeground
                          return Qt.darker(root.contentForeground, 2.2)
                        }
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        font.bold: modelData.today || (dayCell.isHoliday && modelData.inMonth)
                      }

                      // Small dot beneath the day number so holidays stand out
                      // clearly even on subtle themes.
                      Rectangle {
                        visible: dayCell.isHoliday
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Style.space(4)
                        width: Style.space(4)
                        height: width
                        radius: width / 2
                        color: Commons.Color.accent
                        opacity: modelData.inMonth ? (dayCell.isPublic ? 0.95 : 0.55) : 0.35
                      }

                      MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        enabled: dayCell.isHoliday
                        hoverEnabled: dayCell.isHoliday
                        cursorShape: dayCell.isHoliday ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                          if (!modelData.inMonth) {
                            root.goToDate(modelData.year, modelData.month, modelData.key)
                          } else {
                            root.selectedDateKey = root.selectedDateKey === modelData.key ? "" : modelData.key
                          }
                        }

                        PanelToolTip {
                          visible: dayCell.isHoliday && dayMouse.containsMouse
                          text: Model.formatHolidayTooltip(modelData.holidays, root.holidayLanguage)
                          fontFamily: root.contentFontFamily
                        }
                      }
                    }
                  }
                }
              }
            }

            Rectangle {
              readonly property real gutterOffset: root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width) / 2)
              x: LayoutMirroring.enabled
                ? gridColumn.x + gridColumn.width - gutterOffset - width
                : gridColumn.x + gutterOffset
              y: gridColumn.y + headerRow.height + gridColumn.spacing
              width: Style.spacing.hairline
              height: gridColumn.height - headerRow.height - gridColumn.spacing
              color: root.contentForeground
              opacity: 0.1
            }
          }

          // ---- Month stepping rail ----
          Item {
            width: parent.width
            height: monthNav.height

            Item {
              id: monthNav
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: monthLabel.implicitHeight + Style.space(10)

              Text {
                id: monthLabel
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(130)
                horizontalAlignment: Text.AlignHCenter
                text: root.monthYearLabel.toUpperCase()
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.letterSpacing: 1
              }

              PanelActionButton {
                anchors.left: parent.left
                anchors.leftMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: Commons.I18n.rightToLeft ? "󰅂" : "󰅁"
                tooltipText: strings.t("clock.previousMonth")
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(-1)
              }

              PanelActionButton {
                anchors.right: parent.right
                anchors.rightMargin: -Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                iconText: Commons.I18n.rightToLeft ? "󰅁" : "󰅂"
                tooltipText: strings.t("clock.nextMonth")
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(1)
              }
            }
          }

          // ---- Cambodia Holidays section ----
          Item {
            width: parent.width
            height: holidaySection.implicitHeight + Style.space(6)

            Column {
              id: holidaySection
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              spacing: Style.space(6)

              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: root.contentForeground
                opacity: 0.1
              }

              Item {
                width: parent.width
                height: Math.max(holidayHeading.implicitHeight, langPill.height)

                Text {
                  id: holidayHeading
                  textFormat: Text.PlainText
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: strings.t("holidays.heading")
                  color: Qt.darker(root.contentForeground, 1.6)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1
                  font.bold: true
                }

                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)

                  Rectangle {
                    id: langPill
                    width: langLabel.implicitWidth + Style.space(12)
                    height: langLabel.implicitHeight + Style.space(6)
                    radius: Style.cornerRadius
                    color: langMouse.containsMouse
                      ? Style.hoverFillFor(root.contentForeground, Commons.Color.accent)
                      : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)

                    Text {
                      id: langLabel
                      textFormat: Text.PlainText
                      anchors.centerIn: parent
                      text: Model.holidayLanguageLabel(root.holidayLanguage)
                      color: langMouse.containsMouse
                        ? Style.hoverStateColor(root.contentForeground, Commons.Color.accent)
                        : root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    MouseArea {
                      id: langMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.cycleHolidayLanguage()

                      PanelToolTip {
                        visible: langMouse.containsMouse
                        text: strings.t("holidays.cycleLanguage")
                        fontFamily: root.contentFontFamily
                      }
                    }
                  }

                  Rectangle {
                    width: langPill.height
                    height: langPill.height
                    radius: Style.cornerRadius
                    color: refreshMouse.containsMouse
                      ? Style.hoverFillFor(root.contentForeground, Commons.Color.accent)
                      : "transparent"

                    Text {
                      textFormat: Text.PlainText
                      anchors.centerIn: parent
                      text: "󰑐"
                      color: refreshMouse.containsMouse
                        ? Style.hoverStateColor(root.contentForeground, Commons.Color.accent)
                        : Qt.darker(root.contentForeground, 1.5)
                      opacity: root.holidaysLoading ? 0.35 : 1
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.bodySmall
                    }

                    MouseArea {
                      id: refreshMouse
                      anchors.fill: parent
                      enabled: !root.holidaysLoading
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (root.holidayService) root.holidayService.refreshNow()
                      }

                      PanelToolTip {
                        visible: refreshMouse.containsMouse
                        text: strings.t("holidays.refresh")
                        fontFamily: root.contentFontFamily
                      }
                    }
                  }
                }
              }

              Text {
                visible: root.holidaysLoading && root.currentMonthHolidays.length === 0
                width: parent.width
                textFormat: Text.PlainText
                text: strings.t("holidays.loading")
                color: Qt.darker(root.contentForeground, 1.6)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                visible: root.holidaysError !== ""
                width: parent.width
                textFormat: Text.PlainText
                text: root.holidaysError
                color: Commons.Color.urgent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Column {
                visible: root.currentMonthHolidays.length > 0
                width: parent.width
                spacing: Style.space(4)

                Repeater {
                  model: root.currentMonthHolidays

                  Rectangle {
                    id: holidayRow
                    required property var modelData
                    readonly property bool isHighlighted: root.holidayItemMatchesSelection(modelData)
                    readonly property bool isTodayHoliday: root.holidayItemIsToday(modelData)
                    readonly property string primaryName: Model.formatHolidayPrimary(modelData, root.holidayLanguage)
                    readonly property string secondaryName: Model.formatHolidaySecondary(modelData, root.holidayLanguage)

                    width: parent.width
                    height: holidayRowLayout.implicitHeight + Style.space(8)
                    radius: Style.cornerRadius
                    color: isHighlighted
                      ? Util.alpha(Commons.Color.accent, 0.18)
                      : (rowMouse.containsMouse
                          ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
                          : "transparent")

                    Row {
                      id: holidayRowLayout
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.leftMargin: Style.space(6)
                      anchors.rightMargin: Style.space(6)
                      spacing: Style.space(10)

                      Text {
                        textFormat: Text.PlainText
                        width: Style.space(48)
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.holidayRangeLabel(modelData)
                        color: modelData.kind === "observance"
                          ? Qt.darker(root.contentForeground, 1.4)
                          : Commons.Color.accent
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                      }

                      Column {
                        width: parent.width - Style.space(58) - (holidayTag.visible ? holidayTag.width + Style.space(10) : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(1)

                        Text {
                          width: parent.width
                          textFormat: Text.PlainText
                          text: holidayRow.primaryName
                          elide: Text.ElideRight
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.bodySmall
                          font.bold: holidayRow.isHighlighted || holidayRow.isTodayHoliday
                        }

                        Text {
                          visible: holidayRow.secondaryName !== ""
                          width: parent.width
                          textFormat: Text.PlainText
                          text: holidayRow.secondaryName
                          elide: Text.ElideRight
                          color: Qt.darker(root.contentForeground, 1.45)
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption
                        }
                      }

                      Text {
                        id: holidayTag
                        visible: holidayRow.isTodayHoliday || modelData.kind === "observance"
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: holidayRow.isTodayHoliday
                          ? strings.t("holidays.today")
                          : strings.t("holidays.observance")
                        color: holidayRow.isTodayHoliday
                          ? Commons.Color.accent
                          : Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: holidayRow.isTodayHoliday
                      }
                    }

                    MouseArea {
                      id: rowMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.selectedDateKey = holidayRow.isHighlighted ? "" : modelData.startKey
                      }
                    }
                  }
                }
              }

              Column {
                visible: !root.holidaysLoading && root.currentMonthHolidays.length === 0
                width: parent.width
                spacing: Style.space(3)

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: strings.t("holidays.noneThisMonth")
                  color: Qt.darker(root.contentForeground, 1.6)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Item {
                  visible: root.nextHoliday !== null
                  width: parent.width
                  height: nextHolidayText.implicitHeight

                  Text {
                    id: nextHolidayText
                    width: parent.width
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: root.nextHoliday
                      ? strings.t("holidays.next")
                          .arg(root.shortMonthDayLabel(root.nextHoliday.year, root.nextHoliday.month, root.nextHoliday.day))
                          .arg(Model.formatHolidayPrimary(root.nextHoliday, root.holidayLanguage))
                      : ""
                    color: nextHolidayMouse.containsMouse
                      ? Commons.Color.accent
                      : Qt.darker(root.contentForeground, 1.35)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    id: nextHolidayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (!root.nextHoliday) return
                      root.goToDate(root.nextHoliday.year, root.nextHoliday.month, root.nextHoliday.key)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
