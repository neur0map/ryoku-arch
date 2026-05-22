import QtQuick
import qs.aikira
import QtQuick.Layouts
import "../../colors" as ColorsModule

Item {
    id: root

    property var  editing:  null
    property bool showForm: false

    function openNew()   { editing = null;  resetForm(); showForm = true }
    function openEdit(p) { editing = p;     resetForm(); showForm = true }

    function resetForm() {
        fpName.text    = editing ? editing.name         : ""
        fpUrl.text     = editing ? editing.endpoint_url : ""
        fpModel.text   = editing ? editing.model_name   : ""
        fpKey.text     = ""
        fpTemp.text    = editing ? String(editing.temperature) : "0.8"
        fpTok.text     = editing ? String(editing.max_tokens)  : "2048"
        fpDefault.on   = editing ? editing.is_default          : false
        fpErrMsg.visible = false
    }

    function doSave() {
        const name = fpName.text.trim()
        const url  = fpUrl.text.trim()
        const mdl  = fpModel.text.trim()
        if (!name || !url || !mdl) { fpErrMsg.visible = true; return }
        fpErrMsg.visible = false
        const data = {
            name:         name,
            endpoint_url: url,
            model_name:   mdl,
            api_key:      fpKey.text.trim() || (editing ? undefined : ""),
            temperature:  parseFloat(fpTemp.text) || 0.8,
            max_tokens:   parseInt(fpTok.text)    || 2048,
            is_default:   fpDefault.on
        }
        // Don't send api_key if editing and field is empty (keep existing)
        if (editing && (data.api_key === undefined || data.api_key === "")) delete data.api_key

        if (!editing) {
            Api.createProxy(data, function(err) {
                if (err) { fpErrMsg.visible = true; return }
                AppState.refreshProxies(); showForm = false
            })
        } else {
            Api.updateProxy(editing.id, data, function(err) {
                if (err) { fpErrMsg.visible = true; return }
                AppState.refreshProxies(); showForm = false
            })
        }
    }

    Rectangle { anchors.fill: parent; color: ColorsModule.Colors.background }

    // Header
    Rectangle {
        id: pmHead
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 56
        color: ColorsModule.Colors.surface_container

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            Text { text: "proxy manager"; font { pixelSize: 15; weight: Font.Medium; letterSpacing: 0.3 }
                color: ColorsModule.Colors.on_surface }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 96; height: 32; radius: 16
                color: addHov.containsMouse
                    ? ColorsModule.Colors.primary : ColorsModule.Colors.primary_container
                Behavior on color { ColorAnimation { duration: 140 } }
                Text { anchors.centerIn: parent; text: "+ add proxy"
                    font { pixelSize: 12; weight: Font.Medium }
                    color: addHov.containsMouse
                        ? ColorsModule.Colors.on_primary
                        : ColorsModule.Colors.on_primary_container }
                MouseArea { id: addHov; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: root.openNew() }
            }
        }
    }

    // Empty state
    Item {
        anchors { top: pmHead.bottom; left: parent.left; right: showForm ? formPanel.left : parent.right; bottom: parent.bottom }
        visible: !AppState.proxies || AppState.proxies.length === 0

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "⚙"
                font.pixelSize: 40
                color: ColorsModule.Colors.primary
                opacity: 0.2
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "no proxies configured"
                font { pixelSize: 14; letterSpacing: 0.3 }
                color: ColorsModule.Colors.on_surface_variant
                opacity: 0.5
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "add a proxy to connect to an LLM endpoint"
                font.pixelSize: 11
                color: ColorsModule.Colors.on_surface_variant
                opacity: 0.35
            }
        }
    }

    // Proxy list
    ListView {
        id: proxyList
        anchors { top: pmHead.bottom; left: parent.left; right: showForm ? formPanel.left : parent.right; bottom: parent.bottom }
        clip: true; topMargin: 12; spacing: 8
        visible: AppState.proxies && AppState.proxies.length > 0

        Behavior on anchors.rightMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        model: AppState.proxies

        delegate: Rectangle {
            width: proxyList.width - 32; x: 16
            height: 76; radius: 12
            color: ColorsModule.Colors.surface_container_high
            border { width: modelData.is_default ? 1 : 0; color: ColorsModule.Colors.primary }

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                spacing: 12

                Text { text: modelData.is_default ? "★" : "☆"; font.pixelSize: 18
                    color: modelData.is_default ? ColorsModule.Colors.primary : ColorsModule.Colors.on_surface_variant
                    opacity: modelData.is_default ? 1 : 0.3 }

                Column {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: modelData.name; font { pixelSize: 13; weight: Font.Medium }
                        color: ColorsModule.Colors.on_surface
                        elide: Text.ElideRight; width: parent.width }
                    Text { text: modelData.model_name; font { pixelSize: 11; family: "monospace" }
                        color: ColorsModule.Colors.primary; opacity: 0.85
                        elide: Text.ElideRight; width: parent.width }
                    Text { text: modelData.endpoint_url; font.pixelSize: 10
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.45
                        elide: Text.ElideRight; width: parent.width }
                }

                // Test button
                Rectangle {
                    id: testBtn
                    width: 56; height: 28; radius: 14
                    color: testArea.containsMouse
                        ? ColorsModule.Colors.surface_container_highest
                        : ColorsModule.Colors.surface_container
                    Behavior on color { ColorAnimation { duration: 110 } }

                    property string resultText: "test"
                    property color  resultColor: ColorsModule.Colors.on_surface_variant

                    Text {
                        anchors.centerIn: parent
                        text: testBtn.resultText
                        font.pixelSize: 11
                        color: testBtn.resultColor
                    }
                    MouseArea {
                        id: testArea; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            testBtn.resultText  = "…"
                            testBtn.resultColor = ColorsModule.Colors.on_surface_variant
                            Api.testProxy(modelData.id, function(err, res) {
                                if (res && res.ok) {
                                    testBtn.resultText  = res.latency_ms + "ms"
                                    testBtn.resultColor = ColorsModule.Colors.tertiary
                                } else {
                                    testBtn.resultText  = "fail"
                                    testBtn.resultColor = ColorsModule.Colors.error
                                }
                            })
                        }
                    }
                }

                // Edit
                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: edHov.containsMouse ? ColorsModule.Colors.surface_container_highest : "transparent"
                    Behavior on color { ColorAnimation { duration: 110 } }
                    Text { anchors.centerIn: parent; text: "✎"; font.pixelSize: 14
                        color: ColorsModule.Colors.on_surface_variant }
                    MouseArea { id: edHov; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: root.openEdit(modelData) }
                }

                // Delete
                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: dHov.containsMouse ? ColorsModule.Colors.error_container : "transparent"
                    Behavior on color { ColorAnimation { duration: 110 } }
                    Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 18
                        color: ColorsModule.Colors.error }
                    MouseArea { id: dHov; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Api.deleteProxy(modelData.id, function(err) {
                            if (!err) AppState.refreshProxies()
                        })
                    }
                }
            }
        }
    }

    Rectangle {
        id: formPanel
        visible: showForm
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: showForm ? 360 : 0
        color: ColorsModule.Colors.surface_container_low
        border { width: 1; color: ColorsModule.Colors.outline_variant }
        clip: true

        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Flickable {
            anchors.fill: parent
            contentHeight: fpCol.implicitHeight + 40
            clip: true

            Column {
                id: fpCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 18

                // Form header
                Row {
                    width: parent.width
                    Text { text: editing ? "edit proxy" : "new proxy"
                        font { pixelSize: 14; weight: Font.Medium }
                        color: ColorsModule.Colors.on_surface
                        width: parent.width - 36 }
                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: closeHov.containsMouse ? ColorsModule.Colors.surface_container_high : "transparent"
                        Behavior on color { ColorAnimation { duration: 110 } }
                        Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 18
                            color: ColorsModule.Colors.on_surface_variant }
                        MouseArea { id: closeHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: showForm = false }
                    }
                }

                // Name
                Column {
                    width: parent.width; spacing: 5
                    Text { text: "NAME"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                    Rectangle {
                        width: parent.width; height: 36; radius: 8; clip: true
                        color: ColorsModule.Colors.surface_container_highest
                        border { width: fpName.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                        Behavior on border.width { NumberAnimation { duration: 100 } }
                        TextInput { id: fpName; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: ColorsModule.Colors.on_surface; font { pixelSize: 12; family: "monospace" }
                            selectByMouse: true
                            Text {
                                anchors { fill: parent; leftMargin: 0; rightMargin: 0 }
                                verticalAlignment: Text.AlignVCenter
                                text: "e.g. OpenRouter"
                                font { pixelSize: 12; family: "monospace" }
                                color: ColorsModule.Colors.on_surface_variant
                                opacity: 0.35
                                visible: fpName.text.length === 0
                            }
                        }
                    }
                }

                // Endpoint URL
                Column {
                    width: parent.width; spacing: 5
                    Text { text: "ENDPOINT URL"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                    Rectangle {
                        width: parent.width; height: 36; radius: 8; clip: true
                        color: ColorsModule.Colors.surface_container_highest
                        border { width: fpUrl.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                        Behavior on border.width { NumberAnimation { duration: 100 } }
                        TextInput { id: fpUrl; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: ColorsModule.Colors.on_surface; font { pixelSize: 12; family: "monospace" }
                            selectByMouse: true
                            Text {
                                anchors { fill: parent; leftMargin: 0; rightMargin: 0 }
                                verticalAlignment: Text.AlignVCenter
                                text: "https://openrouter.ai/api/v1"
                                font { pixelSize: 12; family: "monospace" }
                                color: ColorsModule.Colors.on_surface_variant
                                opacity: 0.35
                                visible: fpUrl.text.length === 0
                            }
                        }
                    }
                }

                // Model name
                Column {
                    width: parent.width; spacing: 5
                    Text { text: "MODEL NAME"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                    Rectangle {
                        width: parent.width; height: 36; radius: 8; clip: true
                        color: ColorsModule.Colors.surface_container_highest
                        border { width: fpModel.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                        Behavior on border.width { NumberAnimation { duration: 100 } }
                        TextInput { id: fpModel; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: ColorsModule.Colors.on_surface; font { pixelSize: 12; family: "monospace" }
                            selectByMouse: true
                            Text {
                                anchors { fill: parent; leftMargin: 0; rightMargin: 0 }
                                verticalAlignment: Text.AlignVCenter
                                text: "mistralai/mistral-7b-instruct"
                                font { pixelSize: 12; family: "monospace" }
                                color: ColorsModule.Colors.on_surface_variant
                                opacity: 0.35
                                visible: fpModel.text.length === 0
                            }
                        }
                    }
                }

                // API key
                Column {
                    width: parent.width; spacing: 5
                    Text { text: "API KEY"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                        color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                    Text { visible: editing !== null; text: "leave empty to keep existing key"
                        font.pixelSize: 10; color: ColorsModule.Colors.on_surface_variant; opacity: 0.4 }
                    Rectangle {
                        width: parent.width; height: 36; radius: 8; clip: true
                        color: ColorsModule.Colors.surface_container_highest
                        border { width: fpKey.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                        Behavior on border.width { NumberAnimation { duration: 100 } }
                        TextInput { id: fpKey; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: ColorsModule.Colors.on_surface; font { pixelSize: 12; family: "monospace" }
                            echoMode: TextInput.Password; selectByMouse: true }
                    }
                }

                // Temp + tokens row
                Row {
                    width: parent.width; spacing: 12
                    Column {
                        width: (parent.width - 12) / 2; spacing: 5
                        Text { text: "TEMPERATURE"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                        Rectangle {
                            width: parent.width; height: 36; radius: 8
                            color: ColorsModule.Colors.surface_container_highest
                            border { width: fpTemp.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                            Behavior on border.width { NumberAnimation { duration: 100 } }
                            TextInput { id: fpTemp; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: ColorsModule.Colors.on_surface; font { pixelSize: 12; family: "monospace" }
                                selectByMouse: true }
                        }
                    }
                    Column {
                        width: (parent.width - 12) / 2; spacing: 5
                        Text { text: "MAX TOKENS"; font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                            color: ColorsModule.Colors.on_surface_variant; opacity: 0.65 }
                        Rectangle {
                            width: parent.width; height: 36; radius: 8
                            color: ColorsModule.Colors.surface_container_highest
                            border { width: fpTok.activeFocus ? 1 : 0; color: ColorsModule.Colors.primary }
                            Behavior on border.width { NumberAnimation { duration: 100 } }
                            TextInput { id: fpTok; anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: ColorsModule.Colors.on_surface; font { pixelSize: 12; family: "monospace" }
                                selectByMouse: true }
                        }
                    }
                }

                // Default toggle
                Row {
                    spacing: 10
                    Rectangle {
                        id: fpDefault; property bool on: false
                        width: 40; height: 22; radius: 11
                        color: on ? ColorsModule.Colors.primary : ColorsModule.Colors.surface_container_highest
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Rectangle {
                            width: 16; height: 16; radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.on ? parent.width - width - 3 : 3
                            color: "white"
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: fpDefault.on = !fpDefault.on }
                    }
                    Text { text: "set as default proxy"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter
                        color: ColorsModule.Colors.on_surface_variant }
                }

                // Error message
                Text {
                    id: fpErrMsg; visible: false
                    text: "name, endpoint url, and model are required"
                    font.pixelSize: 11; color: ColorsModule.Colors.error
                    wrapMode: Text.WordWrap; width: parent.width
                }

                // Save button
                Row {
                    anchors.right: parent.right; spacing: 10
                    Rectangle {
                        width: 72; height: 32; radius: 16
                        color: svHov.containsMouse
                            ? ColorsModule.Colors.primary_fixed_dim : ColorsModule.Colors.primary
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "save"
                            font { pixelSize: 13; weight: Font.Medium }
                            color: ColorsModule.Colors.on_primary }
                        MouseArea { id: svHov; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.doSave() }
                    }
                }

                Item { height: 16 }
            }
        }
    }
}
