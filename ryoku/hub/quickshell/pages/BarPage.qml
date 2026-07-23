import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../schema/BarPage.js" as BarSchema

// Bar: the status bar and the side panels. Content is the schema, rendered
// through the shared SchemaPage; the write ledger, rail and action bar belong to
// the shell. barStyle gates the per-style rows so each bar look shows only the
// settings it reads.
Item {
    id: pg
    property var hub

    readonly property string pTitle: I18n.tr("Bar")
    readonly property string pEyebrow: I18n.tr("DESKTOP")
    readonly property string pBlurb: I18n.tr("The status bar and side panels: content, clusters, the island, and sidebars.")

    SchemaPage {
        anchors.fill: parent
        schema: BarSchema.rows
        styleKey: "barStyle"
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
