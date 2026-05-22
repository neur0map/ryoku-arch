import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ConfigSwitch {
    colBackground: SettingsMaterialPreset.groupColor
    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover
        : Appearance.colors.colLayer2Hover
    colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer2Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer2Active
    labelColor: ColorUtils.ensureReadable(SettingsMaterialPreset.titleExpandedColor, colBackground, 4.5)
}
