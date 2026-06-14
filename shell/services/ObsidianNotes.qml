pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Config
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property string commandName: "ryoku-obsidian-notes"
    readonly property string selectedIsoDate: isoDate(selectedDate)
    readonly property int draftRetentionMs: 5 * 60 * 1000
    readonly property bool hasUnsavedDraft: draftText.trim().length > 0 && draftText !== savedText

    property bool notesExpanded: true
    property bool saving
    property bool opening
    property var selectedDate: new Date()
    property var _drafts: ({})
    property var recentNotes: []
    property string currentEntryId
    property string draftText
    property string savedText
    property string lastSavedPath
    property string error

    property string _pendingSaveContent
    property string _saveStdout
    property string _saveStderr
    property string _openStdout
    property string _openStderr

    function isoDate(date: var): string {
        const d = date || new Date();
        const year = d.getFullYear();
        const month = `${d.getMonth() + 1}`.padStart(2, "0");
        const day = `${d.getDate()}`.padStart(2, "0");
        return `${year}-${month}-${day}`;
    }

    function displayDate(date: var): string {
        return Qt.locale().toString(date || selectedDate, Locale.ShortFormat);
    }

    function dateFromIso(iso: string): var {
        const parts = (iso || "").split("-");
        if (parts.length !== 3)
            return new Date();
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    function selectDate(date: var): void {
        if (!date)
            return;
        selectedDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        notesExpanded = true;
        loadDraftForSelectedDate();
    }

    function toggleNotes(): void {
        notesExpanded = true;
    }

    function _copyDrafts(): var {
        const drafts = {};
        for (const key in _drafts)
            drafts[key] = _drafts[key];
        return drafts;
    }

    function _draftForDate(iso: string): var {
        const entry = _drafts[iso];
        if (!entry || entry.expiresAt <= Date.now())
            return null;
        return entry;
    }

    function loadDraftForSelectedDate(): void {
        pruneExpiredDrafts();
        const entry = _draftForDate(selectedIsoDate);
        currentEntryId = entry?.entryId || "";
        savedText = entry?.savedText || "";
        draftText = entry?.text || "";
    }

    function rememberDraft(content: string): void {
        const body = content || "";
        const drafts = _copyDrafts();

        if (body.length > 0) {
            drafts[selectedIsoDate] = {
                text: body,
                entryId: currentEntryId,
                savedText: savedText,
                expiresAt: Date.now() + draftRetentionMs
            };
        } else {
            delete drafts[selectedIsoDate];
        }

        _drafts = drafts;
        draftText = body;
        draftExpiryTimer.running = Object.keys(_drafts).length > 0;
        if (draftExpiryTimer.running)
            draftExpiryTimer.restart();
    }

    function clearDraftForSelectedDate(): void {
        const drafts = _copyDrafts();
        delete drafts[selectedIsoDate];
        _drafts = drafts;
        draftText = "";
        draftExpiryTimer.running = Object.keys(_drafts).length > 0;
    }

    function pruneExpiredDrafts(): void {
        const drafts = {};
        const now = Date.now();
        let changed = false;

        for (const key in _drafts) {
            const entry = _drafts[key];
            if (entry && entry.expiresAt > now && (entry.text || "").length > 0) {
                drafts[key] = entry;
            } else {
                changed = true;
            }
        }

        if (changed) {
            _drafts = drafts;
            if (!_drafts[selectedIsoDate])
                draftText = "";
        }

        draftExpiryTimer.running = Object.keys(_drafts).length > 0;
    }

    function clearDraftRecordForSelectedDate(): void {
        const drafts = _copyDrafts();
        delete drafts[selectedIsoDate];
        _drafts = drafts;
        draftExpiryTimer.running = Object.keys(_drafts).length > 0;
    }

    function startNewNote(): void {
        currentEntryId = "";
        savedText = "";
        draftText = "";
        clearDraftRecordForSelectedDate();
    }

    function selectRecentNote(note: var): void {
        if (!note)
            return;

        selectedDate = dateFromIso(note.date || selectedIsoDate);
        currentEntryId = note.id || "";
        savedText = note.content || "";
        draftText = savedText;
        notesExpanded = true;
    }

    function _summaryFor(content: string): string {
        const lines = (content || "").split(/\n/);
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length > 0)
                return line.length > 28 ? `${line.slice(0, 27)}...` : line;
        }
        return qsTr("Untitled");
    }

    function _upsertRecentNote(id: string, date: string, content: string, path: string): void {
        if (!id)
            return;

        const notes = [{
            id: id,
            date: date,
            content: content,
            path: path,
            summary: _summaryFor(content),
            updatedAt: Date.now()
        }];

        for (let i = 0; i < recentNotes.length; i++) {
            if (recentNotes[i].id !== id)
                notes.push(recentNotes[i]);
        }

        recentNotes = notes.slice(0, 3);
    }

    function _noteArgs(): var {
        const args = [
            "--daily-dir", GlobalConfig.paths.obsidianDailyDir || "Daily",
            "--inbox-file", GlobalConfig.paths.obsidianInboxFile || "Inbox.md",
            "--date", selectedIsoDate
        ];
        const vaultDir = (GlobalConfig.paths.obsidianVaultDir || "").trim();
        if (vaultDir.length > 0)
            args.unshift("--vault-dir", Paths.absolutePath(vaultDir));
        return args;
    }

    function _openArgs(): var {
        const args = _noteArgs();
        const vaultName = (GlobalConfig.paths.obsidianVaultName || "").trim();
        if (vaultName.length > 0 && vaultName !== "Ryoku Notes")
            args.push("--vault-name", vaultName);
        return args;
    }

    function saveNote(content: string): void {
        const body = content || "";
        if (body.trim().length === 0) {
            Toaster.toast(qsTr("Obsidian"), qsTr("Nothing to save"), "edit_note");
            return;
        }

        if (saveProcess.running) {
            Toaster.toast(qsTr("Obsidian"), qsTr("A note is already saving"), "sync");
            return;
        }

        saving = true;
        error = "";
        _saveStdout = "";
        _saveStderr = "";
        _pendingSaveContent = body;
        const args = [commandName, "save", ..._noteArgs(), "--content", body, "--print-path", "--print-entry-id"];
        if (currentEntryId.length > 0)
            args.push("--entry-id", currentEntryId);
        saveProcess.command = args;
        saveProcess.running = true;
    }

    function openSelectedNote(): void {
        if (openProcess.running)
            return;

        opening = true;
        error = "";
        _openStdout = "";
        _openStderr = "";
        openProcess.command = [commandName, "open", ..._openArgs()];
        openProcess.running = true;
    }

    function _finishSave(exitCode: int): void {
        saving = false;
        if (exitCode !== 0) {
            error = _saveStderr.trim() || qsTr("Could not save note");
            Toaster.toast(qsTr("Obsidian"), error, "error");
            return;
        }

        const lines = _saveStdout.trim().split(/\n/);
        lastSavedPath = lines[0] || "";
        currentEntryId = lines[1] || currentEntryId;
        savedText = _pendingSaveContent;
        draftText = _pendingSaveContent;
        clearDraftRecordForSelectedDate();
        _upsertRecentNote(currentEntryId, selectedIsoDate, savedText, lastSavedPath);
        Toaster.toast(qsTr("Note saved"), Paths.shortenHome(lastSavedPath), "edit_note");
    }

    function _finishOpen(exitCode: int): void {
        opening = false;
        if (exitCode !== 0) {
            error = _openStderr.trim() || qsTr("Could not open Obsidian");
            Toaster.toast(qsTr("Obsidian"), error, "error");
        }
    }

    Process {
        id: saveProcess

        stdout: StdioCollector {
            onStreamFinished: root._saveStdout = text
        }

        stderr: StdioCollector {
            onStreamFinished: root._saveStderr = text
        }

        onExited: exitCode => root._finishSave(exitCode)
    }

    Process {
        id: openProcess

        stdout: StdioCollector {
            onStreamFinished: root._openStdout = text
        }

        stderr: StdioCollector {
            onStreamFinished: root._openStderr = text
        }

        onExited: exitCode => root._finishOpen(exitCode)
    }

    Timer {
        id: draftExpiryTimer

        interval: 30000
        repeat: true
        onTriggered: root.pruneExpiredDrafts()
    }
}
