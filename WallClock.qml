import QtQuick
import "Model.js" as Model

// Epoch-aligned clock timer matching Omarchy's built-in WallClock.
Timer {
  id: root

  property int step: 60000
  property date date: new Date()

  function arm() {
    interval = Model.msUntilNextTick(Date.now(), step)
    restart()
  }

  onStepChanged: arm()
  onTriggered: {
    date = new Date()
    arm()
  }
  Component.onCompleted: arm()
}
