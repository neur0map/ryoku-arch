// ryoku-livewall (PoC): a sub-100MB live video wallpaper.
//
// It software-decodes a clip with libav on the CPU and paints frames into
// wl_shm buffers on a wlr-layer-shell BACKGROUND surface, letting wp_viewport
// upscale a small (capped) render buffer to the whole output. Because it never
// creates an EGL/GL context, no GPU userspace driver (Mesa gallium+LLVM, or the
// NVIDIA GL/CUDA stack) is ever mapped into the process, so its RSS stays in the
// swww/awww class regardless of GPU vendor. Decoded frames live in ordinary
// shared memory, kept tiny by decoding at <=CAP_W width; the compositor scales.
//
// Usage: livewall <video-file> [cap_width] [fit]
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <poll.h>
#include <unistd.h>
#include <sys/mman.h>
#include <wayland-client.h>
#include "wlr-layer-shell-client-protocol.h"
#include "viewporter-client-protocol.h"
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>

#define NBUF 3

static struct wl_display *dpy;
static struct wl_compositor *comp;
static struct wl_shm *shm;
static struct zwlr_layer_shell_v1 *layer_shell;
static struct wp_viewporter *viewporter;

static struct wl_surface *surface;
static struct zwlr_layer_surface_v1 *layer_surface;
static struct wp_viewport *viewport;

static int screen_w = 0, screen_h = 0; // logical output size (from configure)
static int configured = 0;
static int running = 1;

struct buffer {
	struct wl_buffer *wl_buf;
	void *data;
	size_t size;
	int busy;
};
static struct buffer bufs[NBUF];
static int render_w, render_h, stride;

// ---- registry ----
static void reg_global(void *d, struct wl_registry *r, uint32_t name,
                       const char *iface, uint32_t ver) {
	(void)d; (void)ver;
	if (!strcmp(iface, wl_compositor_interface.name))
		comp = wl_registry_bind(r, name, &wl_compositor_interface, 4);
	else if (!strcmp(iface, wl_shm_interface.name))
		shm = wl_registry_bind(r, name, &wl_shm_interface, 1);
	else if (!strcmp(iface, zwlr_layer_shell_v1_interface.name))
		layer_shell = wl_registry_bind(r, name, &zwlr_layer_shell_v1_interface, 1);
	else if (!strcmp(iface, wp_viewporter_interface.name))
		viewporter = wl_registry_bind(r, name, &wp_viewporter_interface, 1);
}
static void reg_remove(void *d, struct wl_registry *r, uint32_t name) { (void)d;(void)r;(void)name; }
static const struct wl_registry_listener reg_listener = { reg_global, reg_remove };

// ---- layer surface ----
static void ls_configure(void *d, struct zwlr_layer_surface_v1 *ls,
                         uint32_t serial, uint32_t w, uint32_t h) {
	(void)d;
	zwlr_layer_surface_v1_ack_configure(ls, serial);
	if (w) screen_w = w;
	if (h) screen_h = h;
	configured = 1;
}
static void ls_closed(void *d, struct zwlr_layer_surface_v1 *ls) { (void)d;(void)ls; running = 0; }
static const struct zwlr_layer_surface_v1_listener ls_listener = { ls_configure, ls_closed };

// ---- buffer release ----
static void buf_release(void *d, struct wl_buffer *wl_buf) {
	(void)wl_buf;
	struct buffer *b = d;
	b->busy = 0;
}
static const struct wl_buffer_listener buf_listener = { buf_release };

static int alloc_buffers(void) {
	stride = render_w * 4;
	size_t bsize = (size_t)stride * render_h;
	size_t total = bsize * NBUF;
	int fd = memfd_create("livewall", MFD_CLOEXEC);
	if (fd < 0) { perror("memfd_create"); return -1; }
	if (ftruncate(fd, total) < 0) { perror("ftruncate"); close(fd); return -1; }
	void *base = mmap(NULL, total, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (base == MAP_FAILED) { perror("mmap"); close(fd); return -1; }
	struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, total);
	for (int i = 0; i < NBUF; i++) {
		bufs[i].wl_buf = wl_shm_pool_create_buffer(pool, i * bsize, render_w, render_h,
		                                           stride, WL_SHM_FORMAT_XRGB8888);
		bufs[i].data = (char *)base + i * bsize;
		bufs[i].size = bsize;
		bufs[i].busy = 0;
		wl_buffer_add_listener(bufs[i].wl_buf, &buf_listener, &bufs[i]);
	}
	wl_shm_pool_destroy(pool);
	close(fd);
	return 0;
}

static struct buffer *free_buffer(void) {
	for (int i = 0; i < NBUF; i++)
		if (!bufs[i].busy) return &bufs[i];
	return NULL;
}

static int64_t now_ns(void) {
	struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
	return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

// pump the wayland fd until deadline so wl_buffer.release events arrive
static void pump_until(int64_t deadline) {
	int fd = wl_display_get_fd(dpy);
	while (running) {
		wl_display_flush(dpy);
		int64_t left = deadline - now_ns();
		if (left <= 0) break;
		struct pollfd pfd = { fd, POLLIN, 0 };
		int t = (int)(left / 1000000LL);
		int r = poll(&pfd, 1, t > 0 ? t : 0);
		if (r > 0 && (pfd.revents & POLLIN)) {
			if (wl_display_dispatch(dpy) < 0) { running = 0; return; }
		} else break;
	}
	// drain anything already queued
	wl_display_dispatch_pending(dpy);
}

int main(int argc, char **argv) {
	if (argc < 2) { fprintf(stderr, "usage: %s <video> [cap_width] [fit]\n", argv[0]); return 2; }
	const char *path = argv[1];
	int cap_w = argc > 2 ? atoi(argv[2]) : 1280;
	if (cap_w < 64) cap_w = 1280;
	// fill (cover, default) crops the frame to the screen aspect; fit
	// letterboxes it whole. ryoku-shell passes the ryowalls Fit knob as argv[3].
	int fit = (argc > 3 && strcmp(argv[3], "fit") == 0);

	dpy = wl_display_connect(NULL);
	if (!dpy) { fprintf(stderr, "no wayland display\n"); return 1; }
	struct wl_registry *reg = wl_display_get_registry(dpy);
	wl_registry_add_listener(reg, &reg_listener, NULL);
	wl_display_roundtrip(dpy);
	if (!comp || !shm || !layer_shell || !viewporter) {
		fprintf(stderr, "missing globals (compositor=%p shm=%p layer_shell=%p viewporter=%p)\n",
		        (void*)comp,(void*)shm,(void*)layer_shell,(void*)viewporter);
		return 1;
	}

	surface = wl_compositor_create_surface(comp);
	// NULL output: the compositor places this on its primary output. Single
	// output for now; multi-monitor (a surface per wl_output, one shared decoder)
	// is a follow-up before this replaces mpvpaper's ALL-outputs behaviour.
	layer_surface = zwlr_layer_shell_v1_get_layer_surface(
		layer_shell, surface, NULL, ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND, "ryoku-livewall");
	zwlr_layer_surface_v1_add_listener(layer_surface, &ls_listener, NULL);
	zwlr_layer_surface_v1_set_anchor(layer_surface,
		ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP | ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
		ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT | ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
	zwlr_layer_surface_v1_set_exclusive_zone(layer_surface, -1);
	zwlr_layer_surface_v1_set_size(layer_surface, 0, 0);
	wl_surface_commit(surface);
	// wait for the configure that carries the output size
	while (!configured && wl_display_dispatch(dpy) >= 0) {}
	if (screen_w <= 0 || screen_h <= 0) { screen_w = 1920; screen_h = 1080; }

	// ---- libav: open + find video stream + SW decoder ----
	AVFormatContext *fmt = NULL;
	if (avformat_open_input(&fmt, path, NULL, NULL) < 0) { fprintf(stderr, "open %s failed\n", path); return 1; }
	avformat_find_stream_info(fmt, NULL);
	const AVCodec *codec = NULL;
	int vid = av_find_best_stream(fmt, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
	if (vid < 0) { fprintf(stderr, "no video stream\n"); return 1; }
	AVCodecContext *dec = avcodec_alloc_context3(codec);
	avcodec_parameters_to_context(dec, fmt->streams[vid]->codecpar);
	dec->thread_count = 2; // cheap parallelism, bounded so RAM stays low
	if (avcodec_open2(dec, codec, NULL) < 0) { fprintf(stderr, "codec open failed\n"); return 1; }

	int src_w = dec->width, src_h = dec->height;
	if (src_w < 2) src_w = 2;
	if (src_h < 2) src_h = 2;

	// Aspect-correct mapping. The buffer is decoded small (width capped at
	// cap_w) and wp_viewport upscales it to the screen on the compositor GPU
	// for free. fill keeps a video-aspect buffer and crops it to the screen
	// via the viewport source rect (cover); fit decodes into a screen-aspect
	// buffer with the frame centred, leaving the shm zero-fill as black bars.
	int sws_w, sws_h, dst_ox = 0, dst_oy = 0;
	int crop_x = 0, crop_y = 0, crop_w = 0, crop_h = 0;
	if (fit) {
		render_w = src_w <= cap_w ? src_w : cap_w;
		render_h = (int)((long)render_w * screen_h / screen_w);
		render_w &= ~1; render_h &= ~1;
		if (render_w < 2) render_w = 2;
		if (render_h < 2) render_h = 2;
		if ((long)src_w * render_h > (long)render_w * src_h) { // src wider than buffer
			sws_w = render_w;
			sws_h = (int)((long)render_w * src_h / src_w);
		} else {
			sws_h = render_h;
			sws_w = (int)((long)render_h * src_w / src_h);
		}
		sws_w &= ~1; sws_h &= ~1;
		if (sws_w < 2) sws_w = 2;
		if (sws_h < 2) sws_h = 2;
		if (sws_w > render_w) sws_w = render_w;
		if (sws_h > render_h) sws_h = render_h;
		dst_ox = ((render_w - sws_w) / 2) & ~1;
		dst_oy = ((render_h - sws_h) / 2) & ~1;
	} else {
		render_w = src_w <= cap_w ? src_w : cap_w;
		render_h = (int)((long)src_h * render_w / src_w);
		render_w &= ~1; render_h &= ~1;
		if (render_w < 2) render_w = 2;
		if (render_h < 2) render_h = 2;
		sws_w = render_w; sws_h = render_h;
		crop_w = render_w; crop_h = render_h;
		if ((long)render_w * screen_h > (long)render_h * screen_w) { // buffer wider than screen
			crop_w = (int)((long)render_h * screen_w / screen_h);
			crop_x = (render_w - crop_w) / 2;
		} else {
			crop_h = (int)((long)render_w * screen_h / screen_w);
			crop_y = (render_h - crop_h) / 2;
		}
		if (crop_w < 1) crop_w = 1;
		if (crop_h < 1) crop_h = 1;
	}

	if (alloc_buffers() < 0) return 1;
	viewport = wp_viewporter_get_viewport(viewporter, surface);
	if (!fit)
		wp_viewport_set_source(viewport,
			wl_fixed_from_int(crop_x), wl_fixed_from_int(crop_y),
			wl_fixed_from_int(crop_w), wl_fixed_from_int(crop_h));
	wp_viewport_set_destination(viewport, screen_w, screen_h);

	AVRational afr = fmt->streams[vid]->avg_frame_rate;
	double fps = (afr.num > 0 && afr.den > 0) ? av_q2d(afr) : 30.0;
	if (fps < 1 || fps > 240) fps = 30.0;
	int64_t frame_ns = (int64_t)(1e9 / fps);

	struct SwsContext *sws = sws_getContext(src_w, src_h, dec->pix_fmt,
		sws_w, sws_h, AV_PIX_FMT_BGRA, SWS_BILINEAR, NULL, NULL, NULL);
	if (!sws) { fprintf(stderr, "sws init failed\n"); return 1; }

	AVPacket *pkt = av_packet_alloc();
	AVFrame *frame = av_frame_alloc();
	fprintf(stderr, "livewall: %dx%d src -> %dx%d buffer (%s) -> %dx%d screen @ %.1ffps\n",
	        src_w, src_h, render_w, render_h, fit ? "fit" : "fill", screen_w, screen_h, fps);

	int64_t next = now_ns();
	while (running) {
		// pull one decoded frame (loop the file at EOF)
		int got = 0;
		while (!got && running) {
			int rp = av_read_frame(fmt, pkt);
			if (rp < 0) { // EOF: seek back to start, flush, keep looping
				av_seek_frame(fmt, vid, 0, AVSEEK_FLAG_BACKWARD);
				avcodec_flush_buffers(dec);
				continue;
			}
			if (pkt->stream_index != vid) { av_packet_unref(pkt); continue; }
			int rs = avcodec_send_packet(dec, pkt);
			av_packet_unref(pkt);
			if (rs < 0) continue;
			int rr = avcodec_receive_frame(dec, frame);
			if (rr == 0) got = 1;
		}
		if (!running) break;

		struct buffer *b = free_buffer();
		if (!b) { // all buffers in flight; give the compositor a moment
			pump_until(now_ns() + frame_ns);
			b = free_buffer();
			if (!b) { av_frame_unref(frame); continue; }
		}
		uint8_t *dst[4] = { b->data + (size_t)dst_oy * stride + (size_t)dst_ox * 4, NULL, NULL, NULL };
		int dstride[4] = { stride, 0, 0, 0 };
		sws_scale(sws, (const uint8_t *const *)frame->data, frame->linesize, 0, src_h, dst, dstride);
		av_frame_unref(frame);

		b->busy = 1;
		wl_surface_attach(surface, b->wl_buf, 0, 0);
		wl_surface_damage_buffer(surface, 0, 0, render_w, render_h);
		wl_surface_commit(surface);

		next += frame_ns;
		int64_t t = now_ns();
		if (next < t) next = t; // don't accumulate lag
		pump_until(next);
	}
	return 0;
}
