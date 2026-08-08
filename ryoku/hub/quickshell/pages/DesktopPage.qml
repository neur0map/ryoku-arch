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
    function focusKey(k) { sp.focusKey(k) }

    SchemaPage {
        id: sp
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

        // A live, self-contained preview of the desktop visualiser. It rides the
        // shared `extras` slot, so it sits full width between the tabs and the
        // STYLE/SPECTRUM/MOTION cards -- shown only on the Visualizer subtab and
        // folded flat (height 0) elsewhere, so the General tab is untouched.
        VizPreview {
            hub: pg.hub
            anchors.left: parent.left
            anchors.right: parent.right
            visible: sp.tab === "Visualizer"
        }
    }
}
