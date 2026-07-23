import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../schema/DesktopPage.js" as DesktopSchema

// Desktop: what sits on the desktop itself. The brand mark, the weather source
// the widgets and bar read, the widget board, and the audio visualiser.
// Rendered through the shared SchemaPage; the ledger and action bar belong to
// the shell.
Item {
    id: pg
    property var hub

    readonly property string pTitle: I18n.tr("Desktop")
    readonly property string pEyebrow: I18n.tr("DESKTOP")
    readonly property string pBlurb: I18n.tr("What sits on your desktop: the brand mark, weather source, and the audio visualiser.")

    SchemaPage {
        anchors.fill: parent
        schema: DesktopSchema.rows
        draft: pg.hub ? pg.hub.draft : null
        defaults: pg.hub ? pg.hub.committed : ({})
        advanced: pg.hub ? pg.hub.advanced : false
        title: pg.pTitle
        eyebrow: pg.pEyebrow
        blurb: pg.pBlurb
        query: pg.hub ? pg.hub.query : ""
        onEdited: (k, v) => { if (pg.hub) pg.hub.edit(k, v); }
        onPickRequested: (r) => { if (pg.hub) pg.hub.openPick(r); }
    }
}
