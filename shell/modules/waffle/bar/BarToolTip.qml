import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.waffle.looks

WPopupToolTip {
    anchorEdges: (Config.options?.waffles?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom
}
