pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Parse the JSON file whenever it changes (after reload)
    readonly property var _colorsData: {
        const text = colorsFile.text();
        if (!text || !text.trim()) return {};
        try {
            return JSON.parse(text);
        } catch (e) {
            console.warn("Failed to parse colors.json:", e);
            return {};
        }
    }

    // Color properties – each bound to the parsed JSON with a fallback default
    property string background:                _colorsData.background                ?? "#141218"
    property string error:                     _colorsData.error                     ?? "#ffb4ab"
    property string error_container:           _colorsData.error_container           ?? "#93000a"
    property string inverse_on_surface:        _colorsData.inverse_on_surface        ?? "#322f35"
    property string inverse_primary:           _colorsData.inverse_primary           ?? "#65558f"
    property string inverse_surface:           _colorsData.inverse_surface           ?? "#e6e0e9"
    property string on_background:             _colorsData.on_background             ?? "#e6e0e9"
    property string on_error:                  _colorsData.on_error                  ?? "#690005"
    property string on_error_container:        _colorsData.on_error_container        ?? "#ffdad6"
    property string on_primary:                _colorsData.on_primary                ?? "#36265d"
    property string on_primary_container:      _colorsData.on_primary_container      ?? "#e9ddff"
    property string on_primary_fixed:          _colorsData.on_primary_fixed          ?? "#210f47"
    property string on_primary_fixed_variant:  _colorsData.on_primary_fixed_variant  ?? "#4d3d75"
    property string on_secondary:              _colorsData.on_secondary              ?? "#332d41"
    property string on_secondary_container:    _colorsData.on_secondary_container    ?? "#e8def8"
    property string on_secondary_fixed:        _colorsData.on_secondary_fixed        ?? "#1e192b"
    property string on_secondary_fixed_variant:_colorsData.on_secondary_fixed_variant?? "#4a4458"
    property string on_surface:                 _colorsData.on_surface                ?? "#e6e0e9"
    property string on_surface_variant:         _colorsData.on_surface_variant        ?? "#cac4cf"
    property string on_tertiary:                _colorsData.on_tertiary                ?? "#4a2532"
    property string on_tertiary_container:      _colorsData.on_tertiary_container      ?? "#ffd9e2"
    property string on_tertiary_fixed:          _colorsData.on_tertiary_fixed          ?? "#31101d"
    property string on_tertiary_fixed_variant:  _colorsData.on_tertiary_fixed_variant  ?? "#633b48"
    property string outline:                     _colorsData.outline                     ?? "#948f99"
    property string outline_variant:             _colorsData.outline_variant             ?? "#49454e"
    property string primary:                     _colorsData.primary                     ?? "#d0bcfe"
    property string primary_container:           _colorsData.primary_container           ?? "#4d3d75"
    property string primary_fixed:               _colorsData.primary_fixed               ?? "#e9ddff"
    property string primary_fixed_dim:           _colorsData.primary_fixed_dim           ?? "#d0bcfe"
    property string scrim:                        _colorsData.scrim                        ?? "#000000"
    property string secondary:                    _colorsData.secondary                    ?? "#ccc2db"
    property string secondary_container:          _colorsData.secondary_container          ?? "#4a4458"
    property string secondary_fixed:              _colorsData.secondary_fixed              ?? "#e8def8"
    property string secondary_fixed_dim:          _colorsData.secondary_fixed_dim          ?? "#ccc2db"
    property string shadow:                        _colorsData.shadow                        ?? "#000000"
    property string source_color:                  _colorsData.source_color                  ?? "#8a5cf6"
    property string surface:                       _colorsData.surface                       ?? "#141218"
    property string surface_bright:                _colorsData.surface_bright                ?? "#3b383e"
    property string surface_container:             _colorsData.surface_container             ?? "#211f24"
    property string surface_container_high:        _colorsData.surface_container_high        ?? "#2b292f"
    property string surface_container_highest:     _colorsData.surface_container_highest     ?? "#36343a"
    property string surface_container_low:         _colorsData.surface_container_low         ?? "#1d1b20"
    property string surface_container_lowest:      _colorsData.surface_container_lowest      ?? "#0f0d13"
    property string surface_dim:                   _colorsData.surface_dim                   ?? "#141218"
    property string surface_tint:                  _colorsData.surface_tint                  ?? "#d0bcfe"
    property string surface_variant:               _colorsData.surface_variant               ?? "#49454e"
    property string tertiary:                       _colorsData.tertiary                       ?? "#efb8c7"
    property string tertiary_container:             _colorsData.tertiary_container             ?? "#633b48"
    property string tertiary_fixed:                 _colorsData.tertiary_fixed                 ?? "#ffd9e2"
    property string tertiary_fixed_dim:             _colorsData.tertiary_fixed_dim             ?? "#efb8c7"

    // Timer to debounce reloads and avoid multiple rapid updates
    Timer {
        id: reloadTimer
        interval: 100
        onTriggered: colorsFile.reload()
    }

    // File viewer – watches for changes and triggers a debounced reload
    FileView {
        id: colorsFile
        path: Quickshell.env("RYOKU_REBIRTH_SHELL_DIR") + "/colors/Colors.json"
        watchChanges: true
        onFileChanged: reloadTimer.restart()
    }
}
