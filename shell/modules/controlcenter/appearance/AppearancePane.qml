pragma ComponentBehavior: Bound

import ".."
import "../components"
import "../../launcher/services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.images
import qs.services
import qs.utils

Item {
  id: root

  required property Session session

  readonly property var availableFontFamilies: Qt.fontFamilies()
  property string searchText: ""

  property real animDurationsScale: GlobalConfig.appearance.anim.durations.scale ?? 1
  property string fontFamilyMaterial: resolveFont(Config.appearance.font.family.material, ["Material Symbols Rounded", "Material Symbols Outlined"])
  property string fontFamilyMono: resolveFont(Config.appearance.font.family.mono, ["CaskaydiaCove Nerd Font", "CaskaydiaCove NF", "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font"])
  property string fontFamilySans: resolveFont(Config.appearance.font.family.sans, ["Rubik", "Adwaita Sans", "Noto Sans", "DejaVu Sans"])
  property real fontSizeScale: Config.appearance.font.size.scale ?? 1
  property real paddingScale: Config.appearance.padding.scale ?? 1
  property real roundingScale: Config.appearance.rounding.scale ?? 1
  property real spacingScale: Config.appearance.spacing.scale ?? 1
  property bool transparencyEnabled: GlobalConfig.appearance.transparency.enabled ?? false
  property real transparencyBase: GlobalConfig.appearance.transparency.base ?? 0.85
  property real transparencyLayers: GlobalConfig.appearance.transparency.layers ?? 0.4
  property real borderRounding: Config.border.rounding ?? 1
  property real borderThickness: Config.border.thickness ?? 1

  property bool desktopClockEnabled: Config.background.desktopClock.enabled ?? false
  property real desktopClockScale: Config.background.desktopClock.scale ?? 1
  property string desktopClockPosition: Config.background.desktopClock.position ?? "bottom-right"
  property bool desktopClockShadowEnabled: Config.background.desktopClock.shadow.enabled ?? true
  property real desktopClockShadowOpacity: Config.background.desktopClock.shadow.opacity ?? 0.7
  property real desktopClockShadowBlur: Config.background.desktopClock.shadow.blur ?? 0.4
  property bool desktopClockBackgroundEnabled: Config.background.desktopClock.background.enabled ?? false
  property real desktopClockBackgroundOpacity: Config.background.desktopClock.background.opacity ?? 0.7
  property bool desktopClockBackgroundBlur: Config.background.desktopClock.background.blur ?? false
  property bool desktopClockInvertColors: Config.background.desktopClock.invertColors ?? false
  property bool backgroundEnabled: Config.background.enabled ?? true
  property bool wallpaperEnabled: Config.background.wallpaperEnabled ?? true
  property bool visualiserEnabled: Config.background.visualiser.enabled ?? false
  property bool visualiserAutoHide: Config.background.visualiser.autoHide ?? true
  property real visualiserRounding: Config.background.visualiser.rounding ?? 1
  property real visualiserSpacing: Config.background.visualiser.spacing ?? 1

  function resolveFont(value: var, fallbacks: var): string {
    if (value && availableFontFamilies.includes(value))
      return value;

    for (const fallback of fallbacks) {
      if (availableFontFamilies.includes(fallback))
        return fallback;
    }

    return value || fallbacks[0];
  }

  function saveConfig(): void {
    GlobalConfig.appearance.anim.durations.scale = root.animDurationsScale;

    GlobalConfig.appearance.font.family.material = root.fontFamilyMaterial;
    GlobalConfig.appearance.font.family.mono = root.fontFamilyMono;
    GlobalConfig.appearance.font.family.sans = root.fontFamilySans;
    GlobalConfig.appearance.font.size.scale = root.fontSizeScale;

    GlobalConfig.appearance.padding.scale = root.paddingScale;
    GlobalConfig.appearance.rounding.scale = root.roundingScale;
    GlobalConfig.appearance.spacing.scale = root.spacingScale;

    GlobalConfig.appearance.transparency.enabled = root.transparencyEnabled;
    GlobalConfig.appearance.transparency.base = root.transparencyBase;
    GlobalConfig.appearance.transparency.layers = root.transparencyLayers;

    GlobalConfig.background.desktopClock.enabled = root.desktopClockEnabled;
    GlobalConfig.background.enabled = root.backgroundEnabled;
    GlobalConfig.background.desktopClock.scale = root.desktopClockScale;
    GlobalConfig.background.desktopClock.position = root.desktopClockPosition;
    GlobalConfig.background.desktopClock.shadow.enabled = root.desktopClockShadowEnabled;
    GlobalConfig.background.desktopClock.shadow.opacity = root.desktopClockShadowOpacity;
    GlobalConfig.background.desktopClock.shadow.blur = root.desktopClockShadowBlur;
    GlobalConfig.background.desktopClock.background.enabled = root.desktopClockBackgroundEnabled;
    GlobalConfig.background.desktopClock.background.opacity = root.desktopClockBackgroundOpacity;
    GlobalConfig.background.desktopClock.background.blur = root.desktopClockBackgroundBlur;
    GlobalConfig.background.desktopClock.invertColors = root.desktopClockInvertColors;

    GlobalConfig.background.wallpaperEnabled = root.wallpaperEnabled;

    GlobalConfig.background.visualiser.enabled = root.visualiserEnabled;
    GlobalConfig.background.visualiser.autoHide = root.visualiserAutoHide;
    GlobalConfig.background.visualiser.rounding = root.visualiserRounding;
    GlobalConfig.background.visualiser.spacing = root.visualiserSpacing;

    GlobalConfig.border.rounding = root.borderRounding;
    GlobalConfig.border.thickness = root.borderThickness;
  }

  function repairFontConfig(): void {
    if (Config.appearance.font.family.material !== root.fontFamilyMaterial)
      GlobalConfig.appearance.font.family.material = root.fontFamilyMaterial;
    if (Config.appearance.font.family.mono !== root.fontFamilyMono)
      GlobalConfig.appearance.font.family.mono = root.fontFamilyMono;
    if (Config.appearance.font.family.sans !== root.fontFamilySans)
      GlobalConfig.appearance.font.family.sans = root.fontFamilySans;
  }

  function setVariant(variant: string): void {
    Schemes.currentVariant = variant;
    Quickshell.execDetached(["ryoku", "scheme", "set", "-v", variant]);
    variantReloadTimer.restart();
  }

  function setScheme(name: string, flavour: string): void {
    Schemes.currentScheme = `${name} ${flavour}`;
    Quickshell.execDetached(["ryoku", "scheme", "set", "-n", name, "-f", flavour]);
    schemeReloadTimer.restart();
  }

  function setRandomWallpaper(): void {
    const entries = Wallpapers.list;
    if (!entries || entries.length === 0)
      return;

    const entry = entries[Math.floor(Math.random() * entries.length)];
    if (entry && entry.path)
      Wallpapers.setWallpaper(entry.path);
  }

  function fontModel(current: string, preferred: var, materialOnly: bool): var {
    const seen = new Set();
    const result = [];
    const query = root.searchText.trim().toLowerCase();
    const add = font => {
      if (!font || seen.has(font))
        return;
      if (query && font.toLowerCase().indexOf(query) < 0 && current.toLowerCase().indexOf(query) < 0)
        return;

      seen.add(font);
      result.push(font);
    };

    for (const font of preferred) {
      if (availableFontFamilies.includes(font))
        add(font);
    }

    add(current);

    const candidates = materialOnly ? availableFontFamilies.filter(f => f.startsWith("Material Symbols")) : availableFontFamilies;
    for (const font of candidates)
      add(font);

    return result;
  }

  function clockPart(index: int): string {
    const parts = (root.desktopClockPosition || "bottom-right").split("-");
    return parts[index] || (index === 0 ? "bottom" : "right");
  }

  function setClockPosition(vertical: string, horizontal: string): void {
    root.desktopClockPosition = vertical + "-" + horizontal;
    root.saveConfig();
  }

  function percent(value: real): int {
    return Math.round(value * 100);
  }

  anchors.fill: parent
  Component.onCompleted: repairFontConfig()

  Timer {
    id: variantReloadTimer

    interval: 300
    onTriggered: Schemes.reload()
  }

  Timer {
    id: schemeReloadTimer

    interval: 300
    onTriggered: Schemes.reload()
  }

  StyledFlickable {
    id: flickable

    anchors.fill: parent
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentHeight: content.implicitHeight + Tokens.padding.normal * 2

    StyledScrollBar.vertical: StyledScrollBar {
      flickable: flickable
    }

    ColumnLayout {
      id: content

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      StyledRect {
        Layout.fillWidth: true
        implicitHeight: 40
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainer

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Tokens.padding.normal
          anchors.rightMargin: Tokens.padding.normal
          spacing: Tokens.spacing.small

          MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "search"
            color: searchField.activeFocus ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.normal
          }

          StyledTextField {
            id: searchField

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.searchText
            placeholderText: qsTr("Search appearance")

            onTextChanged: {
              if (root.searchText !== text)
                root.searchText = text;
            }
          }

          IconButton {
            Layout.alignment: Qt.AlignVCenter
            visible: root.searchText !== ""
            icon: "close"
            type: IconButton.Text
            padding: Tokens.padding.small / 2

            onClicked: root.searchText = ""
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: flickable.width > 720 ? 5 : 1
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        AppearanceBoard {
          Layout.fillWidth: true
          Layout.columnSpan: flickable.width > 720 ? 3 : 1
        }

        ToneDock {
          Layout.fillWidth: true
          Layout.columnSpan: flickable.width > 720 ? 2 : 1
        }
      }

      TuningDock {
        Layout.fillWidth: true
      }

      WallpaperDock {
        Layout.fillWidth: true
      }

      GridLayout {
        Layout.fillWidth: true
        columns: width > 760 ? 2 : 1
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        FontDock {
          Layout.fillWidth: true
        }

        ClockDock {
          Layout.fillWidth: true
        }
      }

      VisualiserDock {
        Layout.fillWidth: true
      }

    }
  }

  component AppearanceDock: StyledRect {
    id: dock

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property real bodySpacing: Tokens.spacing.small
    default property alias content: dockBody.data

    implicitHeight: dockLayout.implicitHeight + Tokens.padding.small * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    ColumnLayout {
      id: dockLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
          Layout.alignment: Qt.AlignVCenter
          text: dock.icon
          color: Colours.palette.m3primary
          fill: 1
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 0

          StyledText {
            Layout.fillWidth: true
            text: dock.title
            font.weight: 700
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            visible: dock.subtitle !== ""
            text: dock.subtitle
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            elide: Text.ElideRight
          }
        }
      }

      ColumnLayout {
        id: dockBody

        Layout.fillWidth: true
        spacing: dock.bodySpacing
      }
    }
  }

  component AppearanceBoard: StyledRect {
    id: board

    implicitHeight: 158
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      HeroPreview {
        Layout.fillWidth: false
        Layout.preferredWidth: Math.min(260, board.width * 0.38)
        Layout.fillHeight: true
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.small

        RowLayout {
          Layout.fillWidth: true
          spacing: Tokens.spacing.small

          PickerAction {
            icon: "casino"
            title: qsTr("Random")

            onClicked: root.setRandomWallpaper()
          }

          PickerAction {
            icon: "folder_open"
            title: qsTr("Folder")

            onClicked: Quickshell.execDetached(["app2unit", "--", ...GlobalConfig.general.apps.explorer, Paths.wallsdir])
          }
        }

        Flow {
          Layout.fillWidth: true
          spacing: Tokens.spacing.small

          CompactToggle {
            icon: "image"
            title: qsTr("Background")
            checked: root.backgroundEnabled

            onToggled: checked => {
              root.backgroundEnabled = checked;
              root.saveConfig();
            }
          }

          CompactToggle {
            icon: "wallpaper"
            title: qsTr("Wallpaper")
            checked: root.wallpaperEnabled

            onToggled: checked => {
              root.wallpaperEnabled = checked;
              root.saveConfig();
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Tokens.spacing.small

          ModeCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon: "light_mode"
            title: qsTr("Light")
            active: Colours.currentLight

            onClicked: Colours.setMode("light")
          }

          ModeCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon: "dark_mode"
            title: qsTr("Dark")
            active: !Colours.currentLight

            onClicked: Colours.setMode("dark")
          }
        }
      }
    }
  }

  component ToneDock: AppearanceDock {
    icon: "palette"
    title: qsTr("Tone")
    subtitle: Schemes.currentScheme

    Flow {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      Repeater {
        model: M3Variants.list

        VariantPill {
          required property var modelData

          icon: modelData.icon
          title: modelData.name
          active: modelData.variant === Schemes.currentVariant

          onClicked: root.setVariant(modelData.variant)
        }
      }
    }

    Flow {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      Repeater {
        model: Schemes.list

        SchemeSwatch {
          required property var modelData

          title: modelData.flavour ?? ""
          subtitle: modelData.name ?? ""
          surface: `#${modelData.colours?.surface ?? "202020"}`
          primary: `#${modelData.colours?.primary ?? "ffffff"}`
          active: `${modelData.name} ${modelData.flavour}` === Schemes.currentScheme

          onClicked: root.setScheme(modelData.name, modelData.flavour)
        }
      }
    }
  }

  component TuningDock: AppearanceDock {
    icon: "tune"
    title: qsTr("Tuning")
    subtitle: qsTr("Scale, shape, transparency")

    Flow {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      CompactToggle {
        icon: "opacity"
        title: qsTr("Transparent")
        checked: root.transparencyEnabled

        onToggled: checked => {
          root.transparencyEnabled = checked;
          root.saveConfig();
        }
      }
    }

    GridLayout {
      Layout.fillWidth: true
      columns: width > 760 ? 3 : width > 480 ? 2 : 1
      columnSpacing: Tokens.spacing.small
      rowSpacing: Tokens.spacing.small

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Text")
        value: root.fontSizeScale
        from: 0.7
        to: 1.5
        stepSize: 0.01
        valueText: value.toFixed(2) + "x"

        onValueModified: newValue => {
          root.fontSizeScale = newValue;
          root.saveConfig();
        }
      }

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Padding")
        value: root.paddingScale
        from: 0.5
        to: 2
        stepSize: 0.1
        valueText: value.toFixed(1) + "x"

        onValueModified: newValue => {
          root.paddingScale = newValue;
          root.saveConfig();
        }
      }

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Spacing")
        value: root.spacingScale
        from: 0.1
        to: 2
        stepSize: 0.1
        valueText: value.toFixed(1) + "x"

        onValueModified: newValue => {
          root.spacingScale = newValue;
          root.saveConfig();
        }
      }

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Corners")
        value: root.roundingScale
        from: 0.1
        to: 5
        stepSize: 0.1
        valueText: value.toFixed(1) + "x"

        onValueModified: newValue => {
          root.roundingScale = newValue;
          root.saveConfig();
        }
      }

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Border radius")
        value: root.borderRounding
        from: 0.1
        to: 100
        stepSize: 0.1
        valueText: value.toFixed(1) + "px"

        onValueModified: newValue => {
          root.borderRounding = newValue;
          root.saveConfig();
        }
      }

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Border width")
        value: root.borderThickness
        from: 0
        to: 100
        stepSize: 0.1
        valueText: value.toFixed(1) + "px"

        onValueModified: newValue => {
          root.borderThickness = newValue;
          root.saveConfig();
        }
      }

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Base alpha")
        value: root.percent(root.transparencyBase)
        from: 0
        to: 100
        stepSize: 1
        valueText: Math.round(value) + "%"

        onValueModified: newValue => {
          root.transparencyBase = newValue / 100;
          root.saveConfig();
        }
      }

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Layer alpha")
        value: root.percent(root.transparencyLayers)
        from: 0
        to: 100
        stepSize: 1
        valueText: Math.round(value) + "%"

        onValueModified: newValue => {
          root.transparencyLayers = newValue / 100;
          root.saveConfig();
        }
      }
    }
  }

  component WallpaperDock: AppearanceDock {
    icon: "wallpaper"
    title: qsTr("Wallpapers")
    subtitle: Paths.shortenHome(Paths.wallsdir)

    WallpaperGrid {
      Layout.fillWidth: true
      Layout.preferredHeight: 180
      session: root.session
      compact: true
    }
  }

  component FontDock: AppearanceDock {
    icon: "text_fields"
    title: qsTr("Fonts")
    subtitle: root.fontFamilySans

    GridLayout {
      Layout.fillWidth: true
      columns: width > 640 ? 3 : 1
      columnSpacing: Tokens.spacing.small
      rowSpacing: Tokens.spacing.small

      FontStrip {
        Layout.fillWidth: true
        title: qsTr("Sans")
        current: root.fontFamilySans
        model: root.fontModel(root.fontFamilySans, ["Rubik", "Adwaita Sans", "Noto Sans", "DejaVu Sans"], false)

        onSelected: font => {
          root.fontFamilySans = font;
          root.saveConfig();
        }
      }

      FontStrip {
        Layout.fillWidth: true
        title: qsTr("Mono")
        current: root.fontFamilyMono
        model: root.fontModel(root.fontFamilyMono, ["CaskaydiaCove Nerd Font", "CaskaydiaCove NF", "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font"], false)

        onSelected: font => {
          root.fontFamilyMono = font;
          root.saveConfig();
        }
      }

      FontStrip {
        Layout.fillWidth: true
        title: qsTr("Icons")
        current: root.fontFamilyMaterial
        model: root.fontModel(root.fontFamilyMaterial, ["Material Symbols Rounded", "Material Symbols Outlined"], true)

        onSelected: font => {
          root.fontFamilyMaterial = font;
          root.saveConfig();
        }
      }
    }
  }

  component ClockDock: AppearanceDock {
    icon: "schedule"
    title: qsTr("Desktop clock")
    subtitle: root.desktopClockPosition

    Flow {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      CompactToggle {
        icon: "schedule"
        title: qsTr("Clock")
        checked: root.desktopClockEnabled

        onToggled: checked => {
          root.desktopClockEnabled = checked;
          root.saveConfig();
        }
      }

      CompactToggle {
        icon: "invert_colors"
        title: qsTr("Invert")
        checked: root.desktopClockInvertColors

        onToggled: checked => {
          root.desktopClockInvertColors = checked;
          root.saveConfig();
        }
      }

      CompactToggle {
        icon: "filter_drama"
        title: qsTr("Shadow")
        checked: root.desktopClockShadowEnabled

        onToggled: checked => {
          root.desktopClockShadowEnabled = checked;
          root.saveConfig();
        }
      }

      CompactToggle {
        icon: "texture"
        title: qsTr("Panel")
        checked: root.desktopClockBackgroundEnabled

        onToggled: checked => {
          root.desktopClockBackgroundEnabled = checked;
          root.saveConfig();
        }
      }

      CompactToggle {
        icon: "blur_on"
        title: qsTr("Blur")
        checked: root.desktopClockBackgroundBlur

        onToggled: checked => {
          root.desktopClockBackgroundBlur = checked;
          root.saveConfig();
        }
      }
    }

    PositionPad {
      Layout.fillWidth: true
    }

    GridLayout {
      Layout.fillWidth: true
      columns: width > 560 ? 3 : 1
      columnSpacing: Tokens.spacing.small
      rowSpacing: Tokens.spacing.small

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Scale")
        value: root.desktopClockScale
        from: 0.4
        to: 3
        stepSize: 0.1
        valueText: value.toFixed(1) + "x"

        onValueModified: newValue => {
          root.desktopClockScale = newValue;
          root.saveConfig();
        }
      }

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Shadow")
        value: root.percent(root.desktopClockShadowOpacity)
        from: 0
        to: 100
        stepSize: 1
        valueText: Math.round(value) + "%"

        onValueModified: newValue => {
          root.desktopClockShadowOpacity = newValue / 100;
          root.saveConfig();
        }
      }

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Panel alpha")
        value: root.percent(root.desktopClockBackgroundOpacity)
        from: 0
        to: 100
        stepSize: 1
        valueText: Math.round(value) + "%"

        onValueModified: newValue => {
          root.desktopClockBackgroundOpacity = newValue / 100;
          root.saveConfig();
        }
      }
    }
  }

  component VisualiserDock: AppearanceDock {
    icon: "graphic_eq"
    title: qsTr("Visualiser")
    subtitle: root.visualiserEnabled ? qsTr("Enabled") : qsTr("Disabled")

    Flow {
      Layout.fillWidth: true
      spacing: Tokens.spacing.small

      CompactToggle {
        icon: "graphic_eq"
        title: qsTr("Bars")
        checked: root.visualiserEnabled

        onToggled: checked => {
          root.visualiserEnabled = checked;
          root.saveConfig();
        }
      }

      CompactToggle {
        icon: "visibility_off"
        title: qsTr("Auto hide")
        checked: root.visualiserAutoHide

        onToggled: checked => {
          root.visualiserAutoHide = checked;
          root.saveConfig();
        }
      }
    }

    GridLayout {
      Layout.fillWidth: true
      columns: width > 640 ? 3 : 1
      columnSpacing: Tokens.spacing.small
      rowSpacing: Tokens.spacing.small

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Animation")
        value: root.animDurationsScale
        from: 0.1
        to: 5
        stepSize: 0.1
        valueText: value.toFixed(1) + "x"

        onValueModified: newValue => {
          root.animDurationsScale = newValue;
          root.saveConfig();
        }
      }

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Radius")
        value: root.visualiserRounding
        from: 0
        to: 10
        stepSize: 1
        valueText: Math.round(value).toString()

        onValueModified: newValue => {
          root.visualiserRounding = Math.round(newValue);
          root.saveConfig();
        }
      }

      CompactRange {
        Layout.fillWidth: true
        title: qsTr("Gap")
        value: root.visualiserSpacing
        from: 0
        to: 2
        stepSize: 0.1
        valueText: value.toFixed(1)

        onValueModified: newValue => {
          root.visualiserSpacing = newValue;
          root.saveConfig();
        }
      }
    }
  }

  component PickerBoard: StyledRect {
    id: board

    implicitHeight: 226
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      HeroPreview {
        Layout.fillWidth: false
        Layout.preferredWidth: Math.min(360, board.width * 0.42)
        Layout.fillHeight: true
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing.small

        GridLayout {
          Layout.fillWidth: true
          columns: 2
          columnSpacing: Tokens.spacing.small
          rowSpacing: Tokens.spacing.small

          PickerAction {
            Layout.fillWidth: true
            icon: "casino"
            title: qsTr("Random")
            detail: qsTr("Wallpaper")

            onClicked: root.setRandomWallpaper()
          }

          PickerAction {
            Layout.fillWidth: true
            icon: "folder_open"
            title: qsTr("Folder")
            detail: Paths.shortenHome(Paths.wallsdir)

            onClicked: Quickshell.execDetached(["app2unit", "--", ...GlobalConfig.general.apps.explorer, Paths.wallsdir])
          }

          CompactToggle {
            Layout.fillWidth: true
            icon: "image"
            title: qsTr("Background")
            checked: root.backgroundEnabled

            onToggled: checked => {
              root.backgroundEnabled = checked;
              root.saveConfig();
            }
          }

          CompactToggle {
            Layout.fillWidth: true
            icon: "wallpaper"
            title: qsTr("Wallpaper")
            checked: root.wallpaperEnabled

            onToggled: checked => {
              root.wallpaperEnabled = checked;
              root.saveConfig();
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Tokens.spacing.small

          ModeCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon: "light_mode"
            title: qsTr("Light")
            active: Colours.currentLight

            onClicked: Colours.setMode("light")
          }

          ModeCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon: "dark_mode"
            title: qsTr("Dark")
            active: !Colours.currentLight

            onClicked: Colours.setMode("dark")
          }
        }
      }
    }
  }

  component HeroPreview: StyledRect {
    id: preview

    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    CachingImage {
      anchors.fill: parent
      path: Wallpapers.actualCurrent
      fillMode: Image.PreserveAspectCrop
      cache: true
      visible: path !== ""
      sourceSize: Qt.size(width, height)
    }

    StyledRect {
      anchors.fill: parent
      color: Qt.alpha(Colours.palette.m3surface, 0.25)
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: "wallpaper"
        color: Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.large
        fill: 1
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: qsTr("Current wallpaper")
          color: Colours.palette.m3onSurface
          font.weight: 700
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: Wallpapers.actualCurrent || qsTr("No wallpaper selected")
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideMiddle
        }
      }
    }
  }

  component PickerSection: ColumnLayout {
    id: section

    property string title: ""
    default property alias content: sectionContent.data

    spacing: Tokens.spacing.small

    StyledText {
      Layout.fillWidth: true
      text: section.title
      font.pointSize: Tokens.font.size.normal
      font.weight: 700
      elide: Text.ElideRight
    }

    ColumnLayout {
      id: sectionContent

      Layout.fillWidth: true
      spacing: Tokens.spacing.small
    }
  }

  component PickerAction: StyledRect {
    id: action

    property string icon: ""
    property string title: ""
    property string detail: ""

    signal clicked

    implicitWidth: 118
    implicitHeight: 36
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: action.clicked()

      color: Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      id: actionContent

      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: action.icon
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.normal
      }

      StyledText {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: action.title
        font.weight: 650
        elide: Text.ElideRight
      }

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: Math.max(42, action.width * 0.38)
        text: action.detail
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        elide: Text.ElideRight
      }
    }
  }

  component ModeCard: StyledRect {
    id: card

    property string icon: ""
    property string title: ""
    property bool active: false

    signal clicked

    radius: Tokens.rounding.small
    color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: card.clicked()

      color: card.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
      radius: parent.radius
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignHCenter
        text: card.icon
        color: card.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.extraLarge
        fill: card.active ? 1 : 0
      }

      StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: card.title
        color: card.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        font.weight: 650
      }
    }
  }

  component VariantPill: StyledRect {
    id: pill

    property string icon: ""
    property string title: ""
    property bool active: false

    signal clicked

    implicitWidth: pillContent.implicitWidth + Tokens.padding.small * 2
    implicitHeight: 32
    radius: Tokens.rounding.full
    color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: pill.clicked()

      color: pill.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      id: pillContent

      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: pill.icon
        color: pill.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: pill.active ? 1 : 0
      }

      StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: pill.title
        color: pill.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        font.pointSize: Tokens.font.size.small
        font.weight: 650
      }
    }
  }

  component SchemeSwatch: StyledRect {
    id: swatch

    property string title: ""
    property string subtitle: ""
    property color surface: Colours.palette.m3surfaceContainerHigh
    property color primary: Colours.palette.m3primary
    property bool active: false

    signal clicked

    implicitWidth: 124
    implicitHeight: 38
    radius: Tokens.rounding.small
    color: active ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
    border.width: active ? 1 : 0
    border.color: Colours.palette.m3primary
    clip: true

    StateLayer {
      onClicked: swatch.clicked()

      color: swatch.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      StyledRect {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 24
        implicitHeight: 24
        radius: Tokens.rounding.full
        color: swatch.surface

        StyledRect {
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          implicitWidth: parent.implicitWidth / 2
          radius: Tokens.rounding.full
          color: swatch.primary
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: swatch.title
          color: swatch.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
          font.pointSize: Tokens.font.size.small
          font.weight: 650
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: swatch.subtitle
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }
    }
  }

  component CompactToggle: StyledRect {
    id: toggle

    property string icon: "toggle_on"
    property string title: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: Math.max(118, toggleContent.implicitWidth + Tokens.padding.small * 2)
    implicitHeight: 36
    radius: Tokens.rounding.small
    color: checked ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      onClicked: toggle.toggled(!toggle.checked)

      color: toggle.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      id: toggleContent

      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: toggle.icon
        color: toggle.checked ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.normal
        fill: toggle.checked ? 1 : 0
      }

      StyledText {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: toggle.title
        color: toggle.checked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
        font.weight: 650
        elide: Text.ElideRight
      }

      StyledSwitch {
        Layout.alignment: Qt.AlignVCenter
        checked: toggle.checked

        onToggled: toggle.toggled(checked)
      }
    }
  }

  component CompactRange: StyledRect {
    id: range

    property string title: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string valueText: Math.round(value).toString()

    signal valueModified(real newValue)

    function steppedValue(raw: real): real {
      if (range.stepSize <= 0)
        return raw;

      return Math.round(raw / range.stepSize) * range.stepSize;
    }

    implicitHeight: 54
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.smaller

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: range.title
          font.pointSize: Tokens.font.size.small
          font.weight: 650
          elide: Text.ElideRight
        }

        StyledText {
          Layout.alignment: Qt.AlignVCenter
          text: range.valueText
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          font.weight: 650
        }
      }

      StyledSlider {
        id: slider

        Layout.fillWidth: true
        implicitHeight: Tokens.padding.normal * 2
        from: range.from
        to: range.to
        stepSize: range.stepSize

        onMoved: range.valueModified(range.steppedValue(value))

        Binding {
          target: slider
          property: "value"
          value: range.value
          when: !slider.pressed
        }
      }
    }
  }

  component FontStrip: StyledRect {
    id: strip

    property string title: ""
    property string current: ""
    property var model: []

    signal selected(string font)

    implicitHeight: 104
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledText {
          Layout.fillWidth: true
          text: strip.title
          font.weight: 700
          elide: Text.ElideRight
        }

        StyledText {
          Layout.alignment: Qt.AlignVCenter
          text: strip.current
          color: Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      ListView {
        id: fontList

        Layout.fillWidth: true
        Layout.fillHeight: true
        orientation: ListView.Horizontal
        spacing: Tokens.spacing.small
        clip: true
        model: strip.model

        delegate: FontChip {
          required property string modelData

          title: modelData
          active: modelData === strip.current

          onClicked: strip.selected(modelData)
        }
      }
    }
  }

  component FontChip: StyledRect {
    id: chip

    property string title: ""
    property bool active: false

    signal clicked

    width: Math.max(92, Math.min(180, chipLabel.implicitWidth + Tokens.padding.normal * 2))
    height: 34
    radius: Tokens.rounding.small
    color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainer
    clip: true

    StateLayer {
      onClicked: chip.clicked()

      color: chip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
      radius: parent.radius
    }

    StyledText {
      id: chipLabel

      anchors.centerIn: parent
      width: parent.width - Tokens.padding.small * 2
      text: chip.title
      color: chip.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
      font.pointSize: Tokens.font.size.small
      font.weight: 650
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }

  component PositionPad: StyledRect {
    id: pad

    implicitHeight: 92
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    GridLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.small
      columns: 3
      rowSpacing: Tokens.spacing.smaller
      columnSpacing: Tokens.spacing.smaller

      Repeater {
        model: [
          ["top", "left"],
          ["top", "center"],
          ["top", "right"],
          ["middle", "left"],
          ["middle", "center"],
          ["middle", "right"],
          ["bottom", "left"],
          ["bottom", "center"],
          ["bottom", "right"]
        ]

        StyledRect {
          id: point

          required property var modelData
          readonly property bool active: root.clockPart(0) === modelData[0] && root.clockPart(1) === modelData[1]

          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Tokens.rounding.small
          color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainer

          StateLayer {
            onClicked: root.setClockPosition(point.modelData[0], point.modelData[1])

            color: point.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            radius: parent.radius
          }

          MaterialIcon {
            anchors.centerIn: parent
            text: point.active ? "radio_button_checked" : "radio_button_unchecked"
            color: point.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
          }
        }
      }
    }
  }
}
