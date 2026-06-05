pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.ambxst.config
import qs.ambxst.modules.globals
import "../../config/KeybindActions.js" as KeybindActions

/**
 * CompositorTomlWriter - Generates TOML configuration for axctl
 * Writes to ~/.local/share/ambxst/axctl.toml
 */
Singleton {
    id: root

    property string outputPath: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/ambxst/axctl.toml"

    property Process writeProcess: Process {
        running: false
        stdout: SplitParser {}
    }

    function getColorValue(colorName) {
        const resolved = Config.resolveColor(colorName);
        return (typeof resolved === 'string') ? Qt.color(resolved) : resolved;
    }

    function formatColorForCompositor(color) {
        const r = Math.round(color.r * 255).toString(16).padStart(2, '0');
        const g = Math.round(color.g * 255).toString(16).padStart(2, '0');
        const b = Math.round(color.b * 255).toString(16).padStart(2, '0');
        const a = Math.round(color.a * 255).toString(16).padStart(2, '0');

        if (color.a === 1.0) {
            return `rgb(${r}${g}${b})`;
        } else {
            return `rgba(${r}${g}${b}${a})`;
        }
    }

    function colorToHex(color, includeAlpha = false) {
        const r = Math.round(color.r * 255).toString(16).padStart(2, '0');
        const g = Math.round(color.g * 255).toString(16).padStart(2, '0');
        const b = Math.round(color.b * 255).toString(16).padStart(2, '0');

        if (includeAlpha) {
            const a = Math.round(color.a * 255).toString(16).padStart(2, '0');
            return `#${r}${g}${b}${a}`;
        }
        return `#${r}${g}${b}`;
    }

    function resolveColorToHex(colorName, alpha = 1.0) {
        const resolved = Config.resolveColor(colorName);
        const color = (typeof resolved === 'string') ? Qt.color(resolved) : resolved;
        if (alpha < 1.0) {
            return colorToHex(Qt.rgba(color.r, color.g, color.b, alpha), true);
        }
        return colorToHex(color, false);
    }

    function formatBorderColors(colorNames, angle) {
        if (!colorNames || colorNames.length === 0) {
            return [];
        }
        
        if (colorNames.length > 1) {
            const formattedColors = colorNames.map(colorName => {
                const color = getColorValue(colorName);
                return formatColorForCompositor(color);
            }).join(" ");
            return [`${formattedColors} ${angle}deg`];
        } else {
            const color = getColorValue(colorNames[0]);
            return [formatColorForCompositor(color)];
        }
    }

    function formatInactiveBorderColors(colorNames, angle) {
        if (!colorNames || colorNames.length === 0) {
            return [];
        }
        
        if (colorNames.length > 1) {
            const formattedColors = colorNames.map(colorName => {
                const color = getColorValue(colorName);
                const colorWithFullOpacity = Qt.rgba(color.r, color.g, color.b, 1.0);
                return formatColorForCompositor(colorWithFullOpacity);
            }).join(" ");
            return [`${formattedColors} ${angle}deg`];
        } else {
            const color = getColorValue(colorNames[0] || "surface");
            const colorWithFullOpacity = Qt.rgba(color.r, color.g, color.b, 1.0);
            return [formatColorForCompositor(colorWithFullOpacity)];
        }
    }

    function formatShadowColors(colorName, opacity) {
        const color = getColorValue(colorName);
        const colorWithOpacity = Qt.rgba(color.r, color.g, color.b, color.a * opacity);
        return formatColorForCompositor(colorWithOpacity);
    }

    function getBarOrientation() {
        const position = Config.bar.position || "top";
        return (position === "left" || position === "right") ? "vertical" : "horizontal";
    }

    function calculateIgnoreAlpha() {
        let ignoreAlphaValue = 0.0;

        if (Config.compositor.blurExplicitIgnoreAlpha) {
            ignoreAlphaValue = Config.compositor.blurIgnoreAlphaValue;
        } else {
            const barBgOpacity = (Config.theme.srBarBg && Config.theme.srBarBg.opacity !== undefined) ? Config.theme.srBarBg.opacity : 0;
            const bgOpacity = (Config.theme.srBg && Config.theme.srBg.opacity !== undefined) ? Config.theme.srBg.opacity : 1.0;
            ignoreAlphaValue = (barBgOpacity > 0 ? Math.min(barBgOpacity, bgOpacity) : bgOpacity);
        }

        return ignoreAlphaValue.toFixed(2);
    }

    function generateToml() {
        let toml = "";

        toml += "[startup]\n";
        toml += "exec-once = \"ambxst\"\n";

        function tomlEscape(str) {
            if (str === null || str === undefined)
                return "";
            return String(str)
                .replace(/\\/g, "\\\\")
                .replace(/\"/g, "\\\"")
                .replace(/\n/g, "\\n");
        }

        function tomlString(str) {
            return "\"" + tomlEscape(str) + "\"";
        }

        function tomlStringArray(arr) {
            if (!arr || arr.length === 0)
                return "[]";
            const parts = arr.map(s => tomlString(s));
            return "[" + parts.join(", ") + "]";
        }

        function pushKeybindEntry(modifiers, key, dispatcher, argument, flags) {
            if (!key || String(key).trim().length === 0)
                return;
            const normalized = normalizeKeybindDispatcher(dispatcher || "", argument || "");
            toml += "\n[[keybinds]]\n";
            toml += `modifiers = ${tomlStringArray(modifiers || [])}\n`;
            toml += `key = ${tomlString(String(key))}\n`;
            toml += `dispatcher = ${tomlString(normalized.dispatcher)}\n`;
            toml += `argument = ${tomlString(normalized.argument)}\n`;
            toml += `flags = ${tomlString(flags || "")}\n`;
            toml += "enabled = true\n";
        }

        function normalizeKeybindDispatcher(dispatcher, argument) {
            if (dispatcher === "layoutmsg") {
                if (argument.indexOf("focus ") === 0) {
                    return { dispatcher: "movefocus", argument: argument.split(" ")[1] || "" };
                }
                if (argument.indexOf("movewindowto ") === 0) {
                    return { dispatcher: "movewindow", argument: argument.split(" ")[1] || "" };
                }
            }
            return { dispatcher: dispatcher, argument: argument };
        }

        function resolveBindAction(action, fallback) {
            const resolved = KeybindActions.resolveAction(action || fallback);
            if (!resolved) return null;
            return {
                dispatcher: resolved.dispatcher || "",
                argument: resolved.argument || "",
                flags: resolved.flags || ""
            };
        }

        function actionCompatibleWithLayout(action) {
            if (!action)
                return false;
            if (!action.layouts || action.layouts.length === 0)
                return true;
            return action.layouts.indexOf(GlobalStates.compositorLayout) !== -1;
        }

        toml += "[appearance]\n";

        toml += "[appearance.gaps]\n";
        toml += `inner = ${Config.compositor.gapsIn}\n`;
        toml += `outer = ${Config.compositor.gapsOut}\n`;

        toml += "[appearance.border]\n";
        toml += `width = ${Config.compositorBorderSize}\n`;

        const borderColors = Config.compositor.syncBorderColor ? [Config.compositorBorderColor] : Config.compositor.activeBorderColor;
        const activeBorderFormatted = formatBorderColors(borderColors || ["primary"], Config.compositor.borderAngle);
        if (activeBorderFormatted.length > 0) {
            toml += `active_color = "${activeBorderFormatted[0]}"\n`;
        }

        const inactiveBorderColors = Config.compositor.inactiveBorderColor;
        const inactiveBorderFormatted = formatInactiveBorderColors(inactiveBorderColors, Config.compositor.inactiveBorderAngle);
        if (inactiveBorderFormatted.length > 0) {
            toml += `inactive_color = "${inactiveBorderFormatted[0]}"\n`;
        }

        toml += `rounding = ${Config.compositorRounding}\n`;

        toml += "[appearance.opacity]\n";
        toml += "active = 1.0\n";
        toml += "inactive = 1.0\n";

        toml += "[appearance.blur]\n";
        toml += `enabled = ${Config.compositor.blurEnabled}\n`;
        toml += `size = ${Config.compositor.blurSize}\n`;
        toml += `passes = ${Config.compositor.blurPasses}\n`;

        toml += "[appearance.shadow]\n";
        toml += `enabled = ${Config.compositor.shadowEnabled}\n`;
        toml += `size = ${Config.compositor.shadowRange}\n`;
        const shadowColorFormatted = formatShadowColors(Config.compositorShadowColor, Config.compositorShadowOpacity);
        toml += `color = "${shadowColorFormatted}"\n`;

        toml += "[appearance.animations]\n";
        toml += "enabled = true\n";

        if (GlobalStates.compositorLayout && GlobalStates.compositorLayout.length > 0) {
            toml += "\n[general]\n";
            toml += `layout = "${GlobalStates.compositorLayout}"\n`;
        }

        if (Config.keybindsLoader.loaded && Config.keybindsLoader.adapter) {
            const adapter = Config.keybindsLoader.adapter;
            const ambxst = adapter.ambxst;

            function pushCoreBind(keybind) {
                if (!keybind)
                    return;
                const resolved = resolveBindAction(keybind.action, keybind);
                if (!resolved)
                    return;
                pushKeybindEntry(
                    keybind.modifiers || [],
                    keybind.key || "",
                    resolved.dispatcher,
                    resolved.argument,
                    resolved.flags
                );
            }

            if (ambxst) {
                pushCoreBind(ambxst.launcher);
                pushCoreBind(ambxst.dashboard);
                pushCoreBind(ambxst.assistant);
                pushCoreBind(ambxst.clipboard);
                pushCoreBind(ambxst.emoji);
                pushCoreBind(ambxst.notes);
                pushCoreBind(ambxst.tmux);
                pushCoreBind(ambxst.wallpapers);

                if (ambxst.system) {
                    pushCoreBind(ambxst.system.overview);
                    pushCoreBind(ambxst.system.powermenu);
                    pushCoreBind(ambxst.system.config);
                    pushCoreBind(ambxst.system.lockscreen);
                    pushCoreBind(ambxst.system.tools);
                    pushCoreBind(ambxst.system.screenshot);
                    pushCoreBind(ambxst.system.screenrecord);
                    pushCoreBind(ambxst.system.lens);
                    if (ambxst.system.reload) pushCoreBind(ambxst.system.reload);
                    if (ambxst.system.quit) pushCoreBind(ambxst.system.quit);
                }
            }

            if (adapter.custom && adapter.custom.length > 0) {
                for (let i = 0; i < adapter.custom.length; i++) {
                    const bind = adapter.custom[i];
                    if (bind && bind.enabled === false)
                        continue;

                    if (bind && bind.keys && bind.actions) {
                        for (let k = 0; k < bind.keys.length; k++) {
                            const keyObj = bind.keys[k];
                            if (!keyObj || !keyObj.key)
                                continue;
                            for (let a = 0; a < bind.actions.length; a++) {
                                const action = bind.actions[a];
                                if (!actionCompatibleWithLayout(action))
                                    continue;
                                const resolved = resolveBindAction(action, action);
                                if (!resolved)
                                    continue;
                                pushKeybindEntry(
                                    keyObj.modifiers || [],
                                    keyObj.key || "",
                                    resolved.dispatcher,
                                    resolved.argument,
                                    resolved.flags
                                );
                            }
                        }
                    } else if (bind) {
                        const resolved = resolveBindAction(bind.action, bind);
                        if (!resolved)
                            continue;
                        pushKeybindEntry(
                            bind.modifiers || [],
                            bind.key || "",
                            resolved.dispatcher,
                            resolved.argument,
                            resolved.flags
                        );
                    }
                }
            }
        }

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"quickshell\"\n";
        toml += "no_anim = true\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"quickshell\"\n";
        toml += "blur = true\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"quickshell\"\n";
        toml += "blur_popups = true\n";

        // Dynamic ignorealpha based on blur settings
        const ignoreAlphaValue = calculateIgnoreAlpha();
        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"quickshell\"\n";
        toml += "ignore_alpha = true\n";
        toml += `ignore_alpha_value = ${ignoreAlphaValue}\n`;
        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"selection\"\n";
        toml += "no_anim = true\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"fabric\"\n";
        toml += "blur = true\n";
        toml += "ignore_alpha_value = 0.4\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"ambxst\"\n";
        toml += "blur = true\n";
        toml += "blur_popups = true\n";
        toml += "no_anim = true\n";
        toml += "ignore_alpha_value = 0.5\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"overview\"\n";
        toml += "blur = true\n";
        toml += "blur_popups = true\n";
        toml += "no_anim = true\n";

        toml += "\n[[layer_rules]]\n";
        toml += "namespace = \"presets\"\n";
        toml += "blur = true\n";
        toml += "blur_popups = true\n";
        toml += "no_anim = true\n";



        toml += "\n[input]\n";
        toml += "[input.keyboard]\n";
        toml += 'layouts = ""\n';
        toml += 'variants = ""\n';

        return toml;
    }

    function writeTomlFile() {
        const tomlContent = generateToml();
        const escapedPath = root.outputPath.replace(/'/g, "'\\''");
        const escapedContent = tomlContent.replace(/'/g, "'\\''");

        writeProcess.command = ["bash", "-c", `mkdir -p "$(dirname '${escapedPath}')" && echo '${escapedContent}' > '${escapedPath}'`];
        writeProcess.running = true;
        console.log("CompositorTomlWriter: Written TOML to", root.outputPath);
    }

    function refresh() {
        writeTomlFile();
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            if (Config.loader.loaded) {
                writeTomlFile();
            }
        });
    }

    property Connections configConnections: Connections {
        target: Config.loader
        function onLoaded() {
            writeTomlFile();
        }
    }

    property Connections keybindsConnections: Connections {
        target: Config.keybindsLoader
        function onLoaded() { writeTomlFile(); }
        function onFileChanged() { writeTomlFile(); }
        function onAdapterUpdated() { writeTomlFile(); }
        function onPathChanged() { writeTomlFile(); }
    }

    property Connections compositorConnections: Connections {
        target: Config.compositor
        
        function onBorderSizeChanged() { writeTomlFile(); }
        function onRoundingChanged() { writeTomlFile(); }
        function onGapsInChanged() { writeTomlFile(); }
        function onGapsOutChanged() { writeTomlFile(); }
        function onActiveBorderColorChanged() { writeTomlFile(); }
        function onInactiveBorderColorChanged() { writeTomlFile(); }
        function onBorderAngleChanged() { writeTomlFile(); }
        function onInactiveBorderAngleChanged() { writeTomlFile(); }
        
        function onSyncRoundnessChanged() { writeTomlFile(); }
        function onSyncBorderWidthChanged() { writeTomlFile(); }
        function onSyncBorderColorChanged() { writeTomlFile(); }
        function onSyncShadowOpacityChanged() { writeTomlFile(); }
        function onSyncShadowColorChanged() { writeTomlFile(); }
        
        function onShadowEnabledChanged() { writeTomlFile(); }
        function onShadowRangeChanged() { writeTomlFile(); }
        function onShadowRenderPowerChanged() { writeTomlFile(); }
        function onShadowSharpChanged() { writeTomlFile(); }
        function onShadowIgnoreWindowChanged() { writeTomlFile(); }
        function onShadowColorChanged() { writeTomlFile(); }
        function onShadowColorInactiveChanged() { writeTomlFile(); }
        function onShadowOpacityChanged() { writeTomlFile(); }
        function onShadowOffsetChanged() { writeTomlFile(); }
        function onShadowScaleChanged() { writeTomlFile(); }
        
        function onBlurEnabledChanged() { writeTomlFile(); }
        function onBlurSizeChanged() { writeTomlFile(); }
        function onBlurPassesChanged() { writeTomlFile(); }
        function onBlurIgnoreOpacityChanged() { writeTomlFile(); }
        function onBlurExplicitIgnoreAlphaChanged() { writeTomlFile(); }
        function onBlurIgnoreAlphaValueChanged() { writeTomlFile(); }
        function onBlurNewOptimizationsChanged() { writeTomlFile(); }
        function onBlurXrayChanged() { writeTomlFile(); }
        function onBlurNoiseChanged() { writeTomlFile(); }
        function onBlurContrastChanged() { writeTomlFile(); }
        function onBlurBrightnessChanged() { writeTomlFile(); }
        function onBlurVibrancyChanged() { writeTomlFile(); }
        function onBlurVibrancyDarknessChanged() { writeTomlFile(); }
        function onBlurSpecialChanged() { writeTomlFile(); }
        function onBlurPopupsChanged() { writeTomlFile(); }
        function onBlurPopupsIgnorealphaChanged() { writeTomlFile(); }
        function onBlurInputMethodsChanged() { writeTomlFile(); }
        function onBlurInputMethodsIgnorealphaChanged() { writeTomlFile(); }
    }

    property Connections themeConnections: Connections {
        target: Config.theme
        function onSrBarBgChanged() { writeTomlFile(); }
        function onSrBgChanged() { writeTomlFile(); }
        function onShadowColorChanged() { writeTomlFile(); }
        function onShadowOpacityChanged() { writeTomlFile(); }
    }

    property Connections barConnections: Connections {
        target: Config.bar
        function onPositionChanged() { writeTomlFile(); }
    }

    property Connections globalStatesConnections: Connections {
        target: GlobalStates
        function onCompositorLayoutChanged() { writeTomlFile(); }
    }
}
