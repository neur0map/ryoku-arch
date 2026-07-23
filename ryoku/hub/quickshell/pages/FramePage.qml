import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../schema/FramePage.js" as FrameSchema

// Frame: the desktop frame and its surface. Shape and roundness, the surface
// fill (colour, opacity, grain) and shadow, notifications, and the shell-wide
// type and language. Rendered through the shared SchemaPage; the ledger and
// action bar belong to the shell.
Item {
    id: pg
    property var hub

    readonly property string pTitle: I18n.tr("Frame")
    readonly property string pEyebrow: I18n.tr("DESKTOP")
    readonly property string pBlurb: I18n.tr("The desktop frame and surface: shape, roundness, fill, shadow, and notifications.")

    SchemaPage {
        anchors.fill: parent
        schema: FrameSchema.rows
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
