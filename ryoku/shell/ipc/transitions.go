package main

import "math/rand/v2"

// transitionDurationMs is the shared wall-clock length of every wallpaper reveal.
// Recovered from the wallpaper-daemon era (the old shared transitionDuration of
// "2.2" seconds): every Super+W / Super+Shift+W switch runs the same duration and
// only the shape (kind / easing / edge) varies, so the desktop feels consistent
// regardless of which preset is picked.
const transitionDurationMs = 2200

// transitionKinds is the closed set of reveal geometries the backdrop's shader
// understands. Recovered from the daemon's --transition-type values.
var transitionKinds = map[string]bool{
	"fade": true, "wipe": true, "wave": true,
	"center": true, "grow": true, "any": true, "outer": true,
}

// transitionPreset is one named wallpaper reveal. The in-shell backdrop reveals the
// new image over the old through a GPU mask whose geometry is `kind`, whose timing
// is the cubic-bezier `bezier`, and whose boundary is feathered by `edgeSoftness`,
// all over the shared transitionDurationMs. The 13 presets below are recovered from
// the wallpaper daemon and re-typed from its --transition-* flags:
//
//	--transition-type  -> kind        --transition-wave "<w>,<h>" -> waveAmp (h/500)
//	--transition-angle -> angle       --transition-pos            -> pos
//	--transition-bezier -> bezier     --transition-step           -> edgeSoftness
//
// where the daemon's step is edge softness only (low = feathered band, high =
// crisp), so it maps inversely as edgeSoftness = (120 - step) / 300; 'fade' ignored
// step, so its edgeSoftness stays 0.
type transitionPreset struct {
	name string
	// kind is the reveal geometry: one of fade, wipe, wave, center, grow, any,
	// outer (see transitionKinds).
	kind string
	// angle is the sweep direction in degrees for wipe / wave (0 sweeps left to
	// right, 90 top to bottom). Unused by the radial and fade kinds.
	angle float64
	// waveAmp is the wave-boundary amplitude as a fraction of the sweep extent, for
	// the wave kind only (0 otherwise).
	waveAmp float64
	// pos is the origin anchor for the grow kind, one of the eight compass points;
	// "" means the surface centre. center / any resolve their own origin, so they
	// leave it empty.
	pos string
	// bezier is the cubic-bezier easing (x1,y1,x2,y2) shaping the reveal's timing,
	// recovered verbatim. All 13 stay monotonic (y in [0,1]) so no reveal wraps.
	bezier [4]float64
	// edgeSoftness is the feathered width of the reveal boundary as a fraction of
	// the reveal coordinate: 0 = crisp, larger = a softer band.
	edgeSoftness float64
}

// transitionPresets is the recovered 13-preset table: one crossfade, three
// directional sweeps (wipe / wave), five circle reveals (center / grow / any /
// outer), and four Material 3 expressive-motion ports. The per-preset intent
// comments are the recovered originals.
var transitionPresets = []transitionPreset{
	// crossfade
	{name: "silk_fade", kind: "fade", // crossfade, easeInOutCubic
		bezier: [4]float64{0.65, 0, 0.35, 1}},
	// directional sweeps (wipe / wave)
	{name: "diagonal_silk", kind: "wipe", angle: 30, // 30deg wipe, fast launch then glide, easeOutExpo
		bezier: [4]float64{0.16, 1, 0.3, 1}, edgeSoftness: (120 - 110) / 300.0},
	{name: "dream_curtain", kind: "wipe", angle: 90, // top-down curtain, soft feathered edge, easeInOutQuint
		bezier: [4]float64{0.83, 0, 0.17, 1}, edgeSoftness: (120 - 35) / 300.0},
	{name: "liquid_ribbon", kind: "wave", angle: 45, waveAmp: 35 / 500.0, // diagonal rolling waves, easeInOutQuart
		bezier: [4]float64{0.76, 0, 0.24, 1}, edgeSoftness: (120 - 90) / 300.0},
	// circle reveals (center / grow / outer / any)
	{name: "iris_open", kind: "center", // iris bloom from dead center, easeOutQuint
		bezier: [4]float64{0.22, 1, 0.36, 1}, edgeSoftness: (120 - 100) / 300.0},
	{name: "corner_bloom", kind: "grow", pos: "bottom-left", // blooms from bottom-left, easeOutExpo
		bezier: [4]float64{0.16, 1, 0.3, 1}, edgeSoftness: (120 - 90) / 300.0},
	{name: "spotlight_rise", kind: "grow", pos: "bottom", // swells up from bottom-center, easeOutCirc
		bezier: [4]float64{0, 0.55, 0.45, 1}, edgeSoftness: (120 - 90) / 300.0},
	{name: "wander_iris", kind: "any", // bloom from a random on-screen point, easeOutQuart
		bezier: [4]float64{0.25, 1, 0.5, 1}, edgeSoftness: (120 - 100) / 300.0},
	{name: "vignette_close", kind: "outer", // new image seals from edges to center, easeInOutCubic
		bezier: [4]float64{0.65, 0, 0.35, 1}, edgeSoftness: (120 - 90) / 300.0},
	// Material 3 expressive-motion ports: the daemon rode these signature curves
	// on its sweeps; celeste_veil is the wallpaper crossfade itself. The springy
	// overshoot (y>1) and two-segment emphasized curves were left out because a
	// single monotonic bezier cannot carry them.
	{name: "celeste_veil", kind: "fade", // expressive slow-effects wallpaper crossfade
		bezier: [4]float64{0.34, 0.88, 0.34, 1}},
	{name: "comet_streak", kind: "wipe", angle: 135, // fast-launch, long-glide sweep, emphasizedDecel
		bezier: [4]float64{0.05, 0.7, 0.1, 1}, edgeSoftness: (120 - 100) / 300.0},
	{name: "aurora_ripple", kind: "wave", angle: 120, waveAmp: 30 / 500.0, // snappy front-loaded wavy sweep, expressiveFastEffects
		bezier: [4]float64{0.31, 0.94, 0.34, 1}, edgeSoftness: (120 - 80) / 300.0},
	{name: "starfall_bloom", kind: "grow", pos: "top", // iris blooming down from the top, M3 standard
		bezier: [4]float64{0.2, 0, 0, 1}, edgeSoftness: (120 - 100) / 300.0},
}

// pickedTransition is a preset resolved for one switch: the preset fields plus a
// concrete origin (the pos anchor, or a fresh random point for the `any` kind) and
// the shared duration. It is what the daemon publishes on the wallpaper topic for
// the backdrop's reveal shader to consume; the json tags match the QML frame.
type pickedTransition struct {
	Name         string     `json:"name"`
	Kind         string     `json:"kind"`
	Angle        float64    `json:"angle"`
	WaveAmp      float64    `json:"waveAmp"`
	OriginX      float64    `json:"originX"`
	OriginY      float64    `json:"originY"`
	Bezier       [4]float64 `json:"bezier"`
	EdgeSoftness float64    `json:"edgeSoftness"`
	DurationMs   int        `json:"durationMs"`
}

// pickTransition returns a random preset resolved for one switch, never repeating
// the immediately previous pick so consecutive switches never feel samey. The last
// index is persisted on the daemon (guarded by wallMu, the wallpaper hot-path lock,
// so the bare field needs no extra mutex), mirroring the recovered picker.
func (d *daemon) pickTransition() *pickedTransition {
	n := len(transitionPresets)
	if n == 0 {
		return nil
	}
	i := rand.IntN(n)
	if n > 1 && i == d.lastTransition {
		i = (i + 1 + rand.IntN(n-1)) % n
	}
	d.lastTransition = i
	return resolveTransition(transitionPresets[i])
}

// resolveTransition binds a preset to a concrete origin and the shared duration.
func resolveTransition(p transitionPreset) *pickedTransition {
	ox, oy := originForPreset(p)
	return &pickedTransition{
		Name:         p.name,
		Kind:         p.kind,
		Angle:        p.angle,
		WaveAmp:      p.waveAmp,
		OriginX:      ox,
		OriginY:      oy,
		Bezier:       p.bezier,
		EdgeSoftness: p.edgeSoftness,
		DurationMs:   transitionDurationMs,
	}
}

// originForPreset resolves the reveal origin in surface coordinates (0,0 top-left
// to 1,1 bottom-right). The `any` kind blooms from a fresh random on-screen point;
// grow reads its compass `pos`; every other kind blooms from (or, for outer, seals
// toward) the centre.
func originForPreset(p transitionPreset) (x, y float64) {
	if p.kind == "any" {
		return rand.Float64(), rand.Float64()
	}
	switch p.pos {
	case "top":
		return 0.5, 0.0
	case "bottom":
		return 0.5, 1.0
	case "left":
		return 0.0, 0.5
	case "right":
		return 1.0, 0.5
	case "top-left":
		return 0.0, 0.0
	case "top-right":
		return 1.0, 0.0
	case "bottom-left":
		return 0.0, 1.0
	case "bottom-right":
		return 1.0, 1.0
	}
	return 0.5, 0.5
}

// imagePics is the `wallpaper random` pool: the switcher's set (listPics) with
// videos dropped, because a reveal transition is an image operation - a video
// paints through ryoku-livewall on its own surface, with no mask to animate.
func imagePics() []string {
	var imgs []string
	for _, p := range listPics() {
		if !isVideo(p) {
			imgs = append(imgs, p)
		}
	}
	return imgs
}

// pickRandomImage returns a random image from imgs that is not cur, so
// `wallpaper random` never re-picks the current wallpaper. It returns "" when no
// other image is available (an empty pool, or a pool holding only the current one).
// imgs is never mutated.
func pickRandomImage(imgs []string, cur string) string {
	pool := make([]string, 0, len(imgs))
	for _, p := range imgs {
		if p != cur {
			pool = append(pool, p)
		}
	}
	if len(pool) == 0 {
		return ""
	}
	return pool[rand.IntN(len(pool))]
}
