import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../schema/ShellSettingsPage.js" as ShellSchema

// The Shell page. Content is the schema; the write ledger (state + diff) lives
// in the shell's side column, no mock preview. A page owns its schema and its
// extras (none here); the store, rail, diff and action bar belong to the shell.
Item {
    id: pg
    property var hub

    readonly property string pTitle: I18n.tr("Shell")
    readonly property string pEyebrow: I18n.tr("DESKTOP")
    readonly property string pBlurb: I18n.tr("The frame, the bar, notifications, and the desktop visualiser.")

    SchemaPage {
        anchors.fill: parent
        schema: ShellSchema.rows
        styleKey: "barStyle"
        draft: pg.hub ? pg.hub.draft : null
        defaults: pg.hub ? pg.hub.committed : ({})
        title: pg.pTitle
        eyebrow: pg.pEyebrow
        blurb: pg.pBlurb
        query: pg.hub ? pg.hub.query : ""
        onEdited: (k, v) => { if (pg.hub) pg.hub.edit(k, v); }
        onPickRequested: (r) => { if (pg.hub) pg.hub.openPick(r); }
    }
}
