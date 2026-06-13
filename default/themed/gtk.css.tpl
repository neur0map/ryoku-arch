/* Ryoku dynamic app colors - libadwaita / GTK4 + GTK3 widget palette.
   Mapped from the active Ryoku scheme so GTK/Adwaita apps match the shell. */

/* Accent (links, focus rings, switches, selected rows) */
@define-color accent_color {{ accent }};
@define-color accent_bg_color {{ accent }};
@define-color accent_fg_color {{ background }};

/* Window chrome */
@define-color window_bg_color {{ background }};
@define-color window_fg_color {{ foreground }};

/* Text / list / content views */
@define-color view_bg_color {{ background }};
@define-color view_fg_color {{ foreground }};

/* Header bars */
@define-color headerbar_bg_color {{ color0 }};
@define-color headerbar_fg_color {{ foreground }};
@define-color headerbar_border_color {{ foreground }};
@define-color headerbar_backdrop_color {{ background }};
@define-color headerbar_shade_color {{ color0 }};

/* Cards, popovers, dialogs, sidebars */
@define-color card_bg_color {{ color0 }};
@define-color card_fg_color {{ foreground }};
@define-color popover_bg_color {{ color0 }};
@define-color popover_fg_color {{ foreground }};
@define-color dialog_bg_color {{ color0 }};
@define-color dialog_fg_color {{ foreground }};
@define-color sidebar_bg_color {{ color0 }};
@define-color sidebar_fg_color {{ foreground }};
@define-color sidebar_backdrop_color {{ background }};
@define-color sidebar_border_color {{ color8 }};
@define-color secondary_sidebar_bg_color {{ color0 }};
@define-color secondary_sidebar_fg_color {{ foreground }};
@define-color secondary_sidebar_border_color {{ color8 }};

/* Semantic states */
@define-color destructive_color {{ color1 }};
@define-color destructive_bg_color {{ color1 }};
@define-color destructive_fg_color {{ background }};
@define-color success_color {{ color2 }};
@define-color success_bg_color {{ color2 }};
@define-color success_fg_color {{ background }};
@define-color warning_color {{ color3 }};
@define-color warning_bg_color {{ color3 }};
@define-color warning_fg_color {{ background }};
@define-color error_color {{ color1 }};
@define-color error_bg_color {{ color1 }};
@define-color error_fg_color {{ background }};

/* GTK3 legacy widget aliases (apps that read the old names) */
@define-color theme_bg_color {{ background }};
@define-color theme_fg_color {{ foreground }};
@define-color theme_base_color {{ background }};
@define-color theme_text_color {{ foreground }};
@define-color theme_selected_bg_color {{ accent }};
@define-color theme_selected_fg_color {{ background }};
@define-color insensitive_bg_color {{ color0 }};
@define-color insensitive_fg_color {{ color8 }};
@define-color borders {{ color8 }};
