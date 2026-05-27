pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities as Utilities
import qs.modules.utilities.cards as UtilityCards
import qs.ambxst.modules.widgets.dashboard as AmbxstContent
import qs.ambxst.modules.globals as AmbxstGlobals

Item {
  id: root

  required property DrawerVisibilities visibilities
  required property BarPopouts.Wrapper popouts
  required property var props
  required property matrix4x4 deformMatrix

  property string mode: "dashboard"

  readonly property bool recordMode: mode === "record"

  function openLens(): void {
    mode = "dashboard";
    Quickshell.execDetached(["ryoku-cmd-google-lens"]);
  }

  function openColorPicker(): void {
    mode = "dashboard";
    Quickshell.execDetached(["ryoku-cmd-color-picker", "--repeat"]);
  }

  function setMode(nextMode: string): void {
    mode = mode === nextMode ? "dashboard" : nextMode;
  }

  implicitWidth: contentLoader.implicitWidth
  implicitHeight: contentLoader.implicitHeight

  // RYOKU PORT: drive Ambxst's dashboard open/close from ryoku's island visibility, so the
  // vendored content renders (and its dashboardOpen-gated interactions enable) only while the
  // island is open — replacing Ambxst's axctl-based notch state machine.
  Binding {
    target: AmbxstGlobals.GlobalStates
    property: "ryokuDashboardOpen"
    value: root.visibilities.island && !root.recordMode
  }

  Loader {
    id: contentLoader

    anchors.fill: parent
    active: true
    sourceComponent: root.recordMode ? recordSurface : dashboardSurface
  }

  Component {
    id: dashboardSurface

    // RYOKU PORT: faithful Ambxst dashboard content (qs.ambxst.*, AGPL) mounted as a
    // 1:1 starting point. DashboardView is self-contained (self-wires via Ambxst's own
    // singletons), so it takes no ryoku props. The ryoku lens / color-picker / record
    // hooks are intentionally not wired yet — to be re-added after restyle.
    AmbxstContent.DashboardView {}
  }

  Component {
    id: recordSurface

    Item {
      implicitWidth: 620
      implicitHeight: recordLayout.implicitHeight + Tokens.padding.large * 2

      ColumnLayout {
        id: recordLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.normal

        RowLayout {
          Layout.fillWidth: true
          spacing: Tokens.spacing.normal

          IconButton {
            icon: "arrow_back"
            type: IconButton.Text
            font.pointSize: Tokens.font.size.large
            onClicked: root.mode = "dashboard"
          }

          StyledText {
            Layout.fillWidth: true
            text: qsTr("Screen Recorder")
            font.pointSize: Tokens.font.size.large
            font.weight: 650
            elide: Text.ElideRight
          }
        }

        UtilityCards.Record {
          Layout.fillWidth: true
          props: root.props
          visibilities: root.visibilities
        }
      }

      Utilities.RecordingDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
      }
    }
  }
}
