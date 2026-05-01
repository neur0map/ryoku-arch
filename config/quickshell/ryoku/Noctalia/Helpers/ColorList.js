var colors = [
    // --- REDS ---
    { name: "MistyRose", color: "mistyrose" },
    { name: "LightPink", color: "lightpink" },
    { name: "Pink", color: "pink" },
    { name: "PaleVioletRed", color: "palevioletred" },
    { name: "Pink 500", color: "#E91E63" }, // Material
    { name: "HotPink", color: "hotpink" },
    { name: "DeepPink", color: "deeppink" },
    { name: "MediumVioletRed", color: "mediumvioletred" },
    { name: "LightSalmon", color: "lightsalmon" },
    { name: "Salmon", color: "salmon" },
    { name: "DarkSalmon", color: "darksalmon" },
    { name: "LightCoral", color: "lightcoral" },
    { name: "IndianRed", color: "indianred" },
    { name: "Alizarin", color: "#E74C3C" }, // Flat UI
    { name: "Red 500", color: "#F44336" }, // Material
    { name: "Crimson", color: "crimson" },
    { name: "Red", color: "red" },
    { name: "FireBrick", color: "firebrick" },
    { name: "DarkRed", color: "darkred" },
    { name: "Maroon", color: "maroon" },
    { name: "Brown", color: "brown" },

    // --- ORANGES & BROWNS ---
    { name: "Coral", color: "coral" },
    { name: "Tomato", color: "tomato" },
    { name: "OrangeRed", color: "orangered" },
    { name: "Deep Orange 500", color: "#FF5722" }, // Material
    { name: "DarkOrange", color: "darkorange" },
    { name: "Carrot", color: "#E67E22" }, // Flat UI
    { name: "Orange 500", color: "#FF9800" }, // Material
    { name: "Orange", color: "orange" },
    { name: "SandyBrown", color: "sandybrown" },
    { name: "Peru", color: "peru" },
    { name: "Chocolate", color: "chocolate" },
    { name: "SaddleBrown", color: "saddlebrown" },
    { name: "Sienna", color: "sienna" },
    { name: "Brown 500", color: "#795548" }, // Material

    // --- YELLOWS, BEIGES & GOLDS ---
    { name: "LightYellow", color: "lightyellow" },
    { name: "LemonChiffon", color: "lemonchiffon" },
    { name: "LightGoldenrodYellow", color: "lightgoldenrodyellow" },
    { name: "PapayaWhip", color: "papayawhip" },
    { name: "Moccasin", color: "moccasin" },
    { name: "PeachPuff", color: "peachpuff" },
    { name: "NavajoWhite", color: "navajowhite" },
    { name: "Wheat", color: "wheat" },
    { name: "BurlyWood", color: "burlywood" },
    { name: "Tan", color: "tan" },
    { name: "Bisque", color: "bisque" },
    { name: "BlanchedAlmond", color: "blanchedalmond" },
    { name: "Cornsilk", color: "cornsilk" },
    { name: "PaleGoldenrod", color: "palegoldenrod" },
    { name: "Khaki", color: "khaki" },
    { name: "DarkKhaki", color: "darkkhaki" },
    { name: "Goldenrod", color: "goldenrod" },
    { name: "DarkGoldenrod", color: "darkgoldenrod" },
    { name: "Sun Flower", color: "#F1C40F" }, // Flat UI
    { name: "Yellow 500", color: "#FFEB3B" }, // Material
    { name: "Yellow", color: "yellow" },
    { name: "Gold", color: "gold" },
    { name: "Amber 500", color: "#FFC107" }, // Material

    // --- GREENS ---
    { name: "GreenYellow", color: "greenyellow" },
    { name: "Chartreuse", color: "chartreuse" },
    { name: "LawnGreen", color: "lawngreen" },
    { name: "Lime 500", color: "#CDDC39" }, // Material
    { name: "Lime", color: "lime" },
    { name: "LimeGreen", color: "limegreen" },
    { name: "PaleGreen", color: "palegreen" },
    { name: "LightGreen", color: "lightgreen" },
    { name: "Light Green 500", color: "#8BC34A" }, // Material
    { name: "MediumSpringGreen", color: "mediumspringgreen" },
    { name: "SpringGreen", color: "springgreen" },
    { name: "Emerald", color: "#2ECC71" }, // Flat UI
    { name: "Green 500", color: "#4CAF50" }, // Material
    { name: "MediumSeaGreen", color: "mediumseagreen" },
    { name: "SeaGreen", color: "seagreen" },
    { name: "ForestGreen", color: "forestgreen" },
    { name: "Green", color: "green" },
    { name: "DarkGreen", color: "darkgreen" },
    { name: "YellowGreen", color: "yellowgreen" },
    { name: "OliveDrab", color: "olivedrab" },
    { name: "Olive", color: "olive" },
    { name: "DarkOliveGreen", color: "darkolivegreen" },

    // --- TEALS & CYANS ---
    { name: "MediumAquamarine", color: "mediumaquamarine" },
    { name: "DarkSeaGreen", color: "darkseagreen" },
    { name: "LightSeaGreen", color: "lightseagreen" },
    { name: "DarkCyan", color: "darkcyan" },
    { name: "Teal", color: "teal" },
    { name: "Turquoise", color: "#1ABC9C" }, // Flat UI
    { name: "LightCyan", color: "lightcyan" },
    { name: "PaleTurquoise", color: "paleturquoise" },
    { name: "Aquamarine", color: "aquamarine" },
    { name: "Turquoise", color: "turquoise" },
    { name: "MediumTurquoise", color: "mediumturquoise" },
    { name: "DarkTurquoise", color: "darkturquoise" },
    { name: "Aqua", color: "aqua" },
    { name: "Cyan", color: "cyan" },
    { name: "Cyan 500", color: "#00BCD4" }, // Material
    { name: "CadetBlue", color: "cadetblue" },
    { name: "Teal 500", color: "#009688" }, // Material
    { name: "DarkSlateGray", color: "darkslategray" },

    // --- BLUES ---
    { name: "PowderBlue", color: "powderblue" },
    { name: "LightBlue", color: "lightblue" },
    { name: "SkyBlue", color: "skyblue" },
    { name: "LightSkyBlue", color: "lightskyblue" },
    { name: "Light Blue 500", color: "#03A9F4" }, // Material
    { name: "DeepSkyBlue", color: "deepskyblue" },
    { name: "DodgerBlue", color: "dodgerblue" },
    { name: "CornflowerBlue", color: "cornflowerblue" },
    { name: "Peter River", color: "#3498DB" }, // Flat UI
    { name: "Blue 500", color: "#2196F3" }, // Material
    { name: "SteelBlue", color: "steelblue" },
    { name: "LightSteelBlue", color: "lightsteelblue" },
    { name: "RoyalBlue", color: "royalblue" },
    { name: "Blue", color: "blue" },
    { name: "MediumBlue", color: "mediumblue" },
    { name: "Belize Hole", color: "#2980B9" }, // Flat UI
    { name: "DarkBlue", color: "darkblue" },
    { name: "Navy", color: "navy" },
    { name: "MidnightBlue", color: "midnightblue" },
    { name: "Midnight Blue", color: "#2C3E50" }, // Flat UI (Same name, different color)
    { name: "Indigo 500", color: "#3F51B5" }, // Material
    { name: "DarkSlateBlue", color: "darkslateblue" },
    { name: "MediumSlateBlue", color: "mediumslateblue" },
    { name: "SlateBlue", color: "slateblue" },

    // --- PURPLES & MAGENTAS ---
    { name: "Lavender", color: "lavender" },
    { name: "Thistle", color: "thistle" },
    { name: "Plum", color: "plum" },
    { name: "Violet", color: "violet" },
    { name: "Orchid", color: "orchid" },
    { name: "Fuchsia", color: "fuchsia" },
    { name: "Magenta", color: "magenta" },
    { name: "MediumOrchid", color: "mediumorchid" },
    { name: "MediumPurple", color: "mediumpurple" },
    { name: "Amethyst", color: "#9B59B6" }, // Flat UI
    { name: "Purple 500", color: "#9C27B0" }, // Material
    { name: "BlueViolet", color: "blueviolet" },
    { name: "DarkViolet", color: "darkviolet" },
    { name: "DarkOrchid", color: "darkorchid" },
    { name: "DarkMagenta", color: "darkmagenta" },
    { name: "Purple", color: "purple" },
    { name: "Deep Purple 500", color: "#673AB7" }, // Material
    { name: "Indigo", color: "indigo" },

    // --- NEUTRALS ---
    { name: "White", color: "white" },
    { name: "Snow", color: "snow" },
    { name: "HoneyDew", color: "honeydew" },
    { name: "MintCream", color: "mintcream" },
    { name: "Azure", color: "azure" },
    { name: "AliceBlue", color: "aliceblue" },
    { name: "GhostWhite", color: "ghostwhite" },
    { name: "WhiteSmoke", color: "whitesmoke" },
    { name: "Seashell", color: "seashell" },
    { name: "Beige", color: "beige" },
    { name: "OldLace", color: "oldlace" },
    { name: "FloralWhite", color: "floralwhite" },
    { name: "Ivory", color: "ivory" },
    { name: "AntiqueWhite", color: "antiquewhite" },
    { name: "Linen", color: "linen" },
    { name: "LavenderBlush", color: "lavenderblush" },
    { name: "Gainsboro", color: "gainsboro" },
    { name: "LightGray", color: "lightgray" },
    { name: "Silver", color: "silver" },
    { name: "DarkGray", color: "darkgray" },
    { name: "Gray", color: "gray" },
    { name: "Grey 500", color: "#9E9E9E" }, // Material
    { name: "Concrete", color: "#95A5A6" }, // Flat UI
    { name: "DimGray", color: "dimgray" },
    { name: "LightSlateGray", color: "lightslategray" },
    { name: "SlateGray", color: "slategray" },
    { name: "Asbestos", color: "#7F8C8D" }, // Flat UI
    { name: "Blue Grey 500", color: "#607D8B" }, // Material
    { name: "Wet Asphalt", color: "#34495E" }, // Flat UI
    { name: "Black", color: "black" }
  ]
