import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.noctalia.Commons
import qs.noctalia.Widgets

// RYOKU WIRED: GlobalConfig.launcher.favouriteApps / hiddenApps (regex pattern lists,
// matched against each app's desktop id).
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  function addPattern(isFav, pattern) {
    const cur = (isFav ? GlobalConfig.launcher.favouriteApps : GlobalConfig.launcher.hiddenApps) || [];
    const arr = cur.slice();
    if (arr.indexOf(pattern) !== -1)
      return;
    arr.push(pattern);
    if (isFav)
      GlobalConfig.launcher.favouriteApps = arr;
    else
      GlobalConfig.launcher.hiddenApps = arr;
    GlobalConfig.save();
  }

  function removePattern(isFav, index) {
    const arr = (isFav ? GlobalConfig.launcher.favouriteApps : GlobalConfig.launcher.hiddenApps).slice();
    arr.splice(index, 1);
    if (isFav)
      GlobalConfig.launcher.favouriteApps = arr;
    else
      GlobalConfig.launcher.hiddenApps = arr;
    GlobalConfig.save();
  }

  PatternEditor {
    isFav: true
    title: qsTr("Favourite apps")
    desc: qsTr("Apps whose id matches a pattern are pinned to the top of the launcher and shown with a star.")
    patterns: GlobalConfig.launcher.favouriteApps
  }

  NDivider {
    Layout.fillWidth: true
  }

  PatternEditor {
    isFav: false
    title: qsTr("Hidden apps")
    desc: qsTr("Apps whose id matches a pattern are removed from the launcher entirely.")
    patterns: GlobalConfig.launcher.hiddenApps
  }

  component PatternEditor: ColumnLayout {
    id: pe
    required property bool isFav
    required property string title
    required property string desc
    required property var patterns

    Layout.fillWidth: true
    spacing: Style.marginM

    NText {
      text: pe.title
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
    }
    NText {
      Layout.fillWidth: true
      text: pe.desc
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }

    NTextInputButton {
      id: input
      Layout.fillWidth: true
      placeholderText: qsTr("Pattern (regex), e.g. firefox or org\\.gnome\\..*")
      buttonIcon: "add"
      onButtonClicked: {
        const t = input.text.trim();
        if (t.length > 0) {
          root.addPattern(pe.isFav, t);
          input.text = "";
        }
      }
    }

    NText {
      visible: !pe.patterns || pe.patterns.length === 0
      text: qsTr("None yet.")
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
    }

    Repeater {
      model: pe.patterns
      delegate: NBox {
        id: row
        required property int index
        required property string modelData
        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + Style.marginM
        color: Color.mSurface

        RowLayout {
          id: rowLayout
          anchors.fill: parent
          anchors.leftMargin: Style.marginM
          anchors.rightMargin: Style.marginS
          spacing: Style.marginS

          NText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: row.modelData
            color: Color.mOnSurface
            elide: Text.ElideRight
          }
          NIconButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "trash"
            tooltipText: qsTr("Remove")
            baseSize: Style.baseWidgetSize * 0.8
            colorFg: Color.mError
            onClicked: root.removePattern(pe.isFav, row.index)
          }
        }
      }
    }
  }
}
