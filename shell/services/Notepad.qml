pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Multi-tab persistent notepad.
 * Stores tabs as JSON in notepad-tabs.json and migrates a legacy single note.
 * The text property remains the active tab text for existing consumers.
 */
Singleton {
    id: root

    readonly property string tabsFilePath: `${Directories.stateUserPath}/notepad-tabs.json`
    readonly property string legacyFilePath: Directories.notepadPath

    property int activeTab: 0
    property var tabs: [{ title: "Note 1", text: "" }]
    readonly property string text: (tabs[activeTab]?.text) ?? ""
    property string _pendingSaveText: ""

    function setTextValue(newText) {
        if (tabs.length === 0) {
            root._resetTabs()
        }

        const index = root._clampTabIndex(activeTab, tabs.length)
        const updatedTabs = tabs.slice()
        updatedTabs[index] = Object.assign({}, root._normalizedTab(updatedTabs[index], index), {
            text: newText ?? ""
        })
        tabs = updatedTabs
        activeTab = index
        root._saveTabs()
    }

    function createTab(title = "") {
        const updatedTabs = tabs.length > 0 ? tabs.slice() : []
        const index = updatedTabs.length
        const tabTitle = root._cleanTitle(title, index)

        updatedTabs.push({ title: tabTitle, text: "" })
        tabs = updatedTabs
        activeTab = index
        root._saveTabs()
    }

    function deleteTab(index) {
        if (index < 0 || index >= tabs.length || tabs.length <= 1) {
            return
        }

        const updatedTabs = tabs.slice()
        updatedTabs.splice(index, 1)
        tabs = updatedTabs
        activeTab = root._clampTabIndex(activeTab > index ? activeTab - 1 : activeTab, tabs.length)
        root._saveTabs()
    }

    function renameTab(index, title) {
        if (index < 0 || index >= tabs.length) {
            return
        }

        const updatedTabs = tabs.slice()
        updatedTabs[index] = Object.assign({}, root._normalizedTab(updatedTabs[index], index), {
            title: root._cleanTitle(title, index)
        })
        tabs = updatedTabs
        root._saveTabs()
    }

    function activateTab(index) {
        if (index < 0 || index >= tabs.length) {
            return
        }

        activeTab = index
        root._saveTabs()
    }

    function _saveTabs() {
        root._pendingSaveText = JSON.stringify({ activeTab: activeTab, tabs: tabs })
        if (!ensureTabsDirectoryProc.running) {
            ensureTabsDirectoryProc.running = true
        }
    }

    function refresh() {
        tabsFileView.reload()
    }

    function _cleanTitle(title, index) {
        const cleaned = String(title ?? "").trim()
        return cleaned.length > 0 ? cleaned : `Note ${index + 1}`
    }

    function _clampTabIndex(index, tabCount) {
        if (tabCount <= 0) {
            return 0
        }

        const numericIndex = parseInt(index, 10)
        if (isNaN(numericIndex)) {
            return 0
        }

        return Math.max(0, Math.min(numericIndex, tabCount - 1))
    }

    function _normalizedTab(tab, index) {
        if (!tab || typeof tab !== "object") {
            return { title: `Note ${index + 1}`, text: "" }
        }

        return {
            title: root._cleanTitle(tab.title, index),
            text: typeof tab.text === "string" ? tab.text : ""
        }
    }

    function _normalizedTabs(rawTabs) {
        if (!Array.isArray(rawTabs) || rawTabs.length === 0) {
            return [{ title: "Note 1", text: "" }]
        }

        return rawTabs.map((tab, index) => root._normalizedTab(tab, index))
    }

    function _resetTabs() {
        tabs = [{ title: "Note 1", text: "" }]
        activeTab = 0
    }

    Component.onCompleted: {
        refresh()
    }

    Process {
        id: ensureTabsDirectoryProc
        running: false
        command: ["/usr/bin/mkdir", "-p", root.tabsFilePath.substring(0, root.tabsFilePath.lastIndexOf('/'))]
        onExited: (code, status) => {
            if (code === 0) {
                tabsFileView.setText(root._pendingSaveText)
            } else {
                console.log("[Notepad] Error creating tabs directory:", code, status)
            }
        }
    }

    FileView {
        id: tabsFileView
        path: Qt.resolvedUrl(root.tabsFilePath)

        onLoaded: {
            try {
                const data = JSON.parse(tabsFileView.text())

                if (Array.isArray(data.tabs) && data.tabs.length > 0) {
                    root.tabs = root._normalizedTabs(data.tabs)
                    root.activeTab = root._clampTabIndex(data.activeTab ?? 0, root.tabs.length)
                    return
                }
            } catch (error) {
                console.log("[Notepad] Error parsing tabs file, leaving it untouched:", error)
                root._resetTabs()
                return
            }

            console.log("[Notepad] Invalid tabs file schema, leaving it untouched.")
            root._resetTabs()
        }

        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                legacyFileView.reload()
            } else {
                console.log("[Notepad] Error loading tabs file:", error)
            }
        }
    }

    FileView {
        id: legacyFileView
        path: Qt.resolvedUrl(root.legacyFilePath)

        onLoaded: {
            const content = legacyFileView.text()
            root.tabs = [{ title: "Note 1", text: content || "" }]
            root.activeTab = 0
            root._saveTabs()
        }

        onLoadFailed: {
            root._resetTabs()
            root._saveTabs()
        }
    }
}
