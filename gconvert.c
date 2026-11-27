// gconvert - convert a BMP, Targa or JPEG image to an IML 4096 color screen (see docs/gconvert.md)
//
// gconvert -i input.(bmp/tga/jpg) -o screen.scr -m (4/5/6) [-s]
//
// The output is the raw screen image, to be loaded at $180000: one 16 bit pixel per screen
// position, left to right then top to bottom, with red in bits 8-11, green in bits 4-7 and blue
// in bits 0-3. Each pixel is stored low byte first, which is how the consoles read video memory.
//
// Without -s the image must fit the mode, and is centered on a black screen. With -s it is
// scaled up or down to fit the screen keeping its aspect ratio, with black bars filling the rest.
//
// The decoders are built in: BMP (1/4/8 bit palette, 16/24/32 bit, RLE4/RLE8, bitfields),
// Targa (palette, truecolor, grayscale, with or without RLE) and baseline JPEG (grayscale or
// color, any chroma subsampling, restart markers). Progressive JPEGs aren't supported.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <math.h>
#include <unistd.h>
#include <getopt.h>

#define MAX_PIXELS (64 * 1024 * 1024) // refuse anything bigger than this (64 megapixels)

typedef struct {
	int w, h;
	uint8_t *rgb; // w * h * 3 bytes, top row first
} image_t;

static char g_err[256]; // the reason a decoder failed

static int fail(const char *a_msg)
{
	snprintf(g_err, sizeof(g_err), "%s", a_msg);
	return -1;
}

static int alloc_image(image_t *a_img, long a_w, long a_h)
{
	if ((a_w <= 0) || (a_h <= 0))
		return fail("bad image size");
	if (a_w * a_h > MAX_PIXELS)
		return fail("image is too large");
	a_img->w = (int)a_w;
	a_img->h = (int)a_h;
	a_img->rgb = calloc((size_t)a_w * a_h, 3);
	if (!a_img->rgb)
		return fail("out of memory");
	return 0;
}

static unsigned u16le(const uint8_t *p) { return p[0] | (p[1] << 8); }
static uint32_t u32le(const uint8_t *p) { return p[0] | (p[1] << 8) | (p[2] << 16) | ((uint32_t)p[3] << 24); }
static unsigned u16be(const uint8_t *p) { return (p[0] << 8) | p[1]; }

// ---------------------------------------------------------------- BMP

typedef struct {
	uint32_t mask;
	int shift, bits;
} bitfield_t;

static void bitfield_init(bitfield_t *a_bf, uint32_t a_mask)
{
	a_bf->mask = a_mask;
	a_bf->shift = 0;
	a_bf->bits = 0;
	if (!a_mask)
		return;
	while (!(a_mask & 1)) {
		a_mask >>= 1;
		a_bf->shift++;
	}
	while (a_mask & 1) {
		a_mask >>= 1;
		a_bf->bits++;
	}
}

static uint8_t bitfield_get(const bitfield_t *a_bf, uint32_t a_px)
{
	if (!a_bf->mask)
		return 0;
	uint32_t v = (a_px & a_bf->mask) >> a_bf->shift;
	uint32_t max = (a_bf->bits >= 32) ? 0xffffffff : ((1u << a_bf->bits) - 1);
	return (uint8_t)(((uint64_t)v * 255 + max / 2) / max);
}

static int decode_bmp(const uint8_t *d, size_t len, image_t *img)
{
	if (len < 26)
		return fail("BMP file is truncated");
	uint32_t off = u32le(d + 10);
	uint32_t dibsize = u32le(d + 14);
	long w, h;
	unsigned bpp;
	uint32_t comp = 0, clrused = 0;
	int palentry = 4;

	if (dibsize == 12) { // OS/2 BITMAPCOREHEADER
		w = u16le(d + 18);
		h = (int16_t)u16le(d + 20);
		bpp = u16le(d + 24);
		palentry = 3;
	} else if ((dibsize >= 40) && (14 + (size_t)dibsize <= len)) {
		w = (int32_t)u32le(d + 18);
		h = (int32_t)u32le(d + 22);
		bpp = u16le(d + 28);
		comp = u32le(d + 30);
		clrused = u32le(d + 46);
	} else {
		return fail("unsupported BMP header");
	}
	int topdown = (h < 0);
	if (topdown)
		h = -h;
	if ((w <= 0) || (h <= 0))
		return fail("bad BMP image size");

	// bitfield masks: in the header (V2 and later), or right after a 40 byte header
	bitfield_t bf[3];
	uint32_t masks[3] = { 0, 0, 0 };
	size_t paloff = 14 + dibsize;
	if ((comp == 3) || (comp == 6)) {
		size_t moff = 14 + 40;
		if (dibsize == 40)
			paloff += (comp == 6) ? 16 : 12;
		if (moff + 12 > len)
			return fail("BMP file is truncated");
		for (int i = 0; i < 3; ++i)
			masks[i] = u32le(d + moff + i * 4);
	} else if (bpp == 16) {
		masks[0] = 0x7c00; masks[1] = 0x03e0; masks[2] = 0x001f;
	} else if (bpp == 32) {
		masks[0] = 0xff0000; masks[1] = 0x00ff00; masks[2] = 0x0000ff;
	}
	for (int i = 0; i < 3; ++i)
		bitfield_init(&bf[i], masks[i]);

	switch (comp) {
		case 0: // BI_RGB
			if ((bpp != 1) && (bpp != 4) && (bpp != 8) && (bpp != 16) && (bpp != 24) && (bpp != 32))
				return fail("unsupported BMP bit depth");
			break;
		case 1: // BI_RLE8
			if (bpp != 8)
				return fail("bad BMP RLE8 bit depth");
			break;
		case 2: // BI_RLE4
			if (bpp != 4)
				return fail("bad BMP RLE4 bit depth");
			break;
		case 3: // BI_BITFIELDS
		case 6: // BI_ALPHABITFIELDS
			if ((bpp != 16) && (bpp != 32))
				return fail("bad BMP bitfields bit depth");
			break;
		default:
			return fail("unsupported BMP compression (embedded JPEG/PNG BMPs aren't supported)");
	}

	// palette
	uint8_t pal[256][3];
	memset(pal, 0, sizeof(pal));
	if (bpp <= 8) {
		unsigned ncolors = clrused ? clrused : (1u << bpp);
		if (ncolors > 256)
			ncolors = 256;
		if (paloff + (size_t)ncolors * palentry > len)
			return fail("BMP palette is truncated");
		for (unsigned i = 0; i < ncolors; ++i) {
			const uint8_t *p = d + paloff + i * palentry;
			pal[i][0] = p[2];
			pal[i][1] = p[1];
			pal[i][2] = p[0];
		}
	}

	if (alloc_image(img, w, h) < 0)
		return -1;

	if ((comp == 1) || (comp == 2)) {
		// RLE: bottom-up; pixels it skips stay color 0
		if (topdown)
			return fail("bad BMP: RLE images can't be top-down");
		uint8_t *idx = calloc((size_t)w * h, 1);
		if (!idx)
			return fail("out of memory");
		size_t p = off;
		long x = 0, y = 0;
		int done = 0;
		while (!done) {
			if (p + 2 > len)
				break; // truncated: keep what we have
			unsigned n = d[p], c = d[p + 1];
			p += 2;
			if (n > 0) {
				for (unsigned i = 0; i < n; ++i, ++x) {
					uint8_t v = (comp == 1) ? c : ((i & 1) ? (c & 15) : (c >> 4));
					if ((x < w) && (y < h))
						idx[y * w + x] = v;
				}
			} else if (c == 0) { // end of line
				x = 0;
				++y;
			} else if (c == 1) { // end of bitmap
				done = 1;
			} else if (c == 2) { // delta
				if (p + 2 > len)
					break;
				x += d[p];
				y += d[p + 1];
				p += 2;
			} else { // absolute run of c pixels
				size_t nbytes = (comp == 1) ? c : (c + 1) / 2;
				if (p + nbytes > len)
					break;
				for (unsigned i = 0; i < c; ++i, ++x) {
					uint8_t v = (comp == 1) ? d[p + i] : ((i & 1) ? (d[p + i / 2] & 15) : (d[p + i / 2] >> 4));
					if ((x < w) && (y < h))
						idx[y * w + x] = v;
				}
				p += nbytes + (nbytes & 1); // runs are padded to 16 bits
			}
			if (y >= h)
				done = 1;
		}
		for (long yy = 0; yy < h; ++yy)
			for (long xx = 0; xx < w; ++xx)
				memcpy(img->rgb + ((h - 1 - yy) * w + xx) * 3, pal[idx[yy * w + xx]], 3);
		free(idx);
		return 0;
	}

	size_t rowsize = (((size_t)w * bpp + 31) / 32) * 4;
	if ((off > len) || (rowsize * h > len - off))
		return fail("BMP pixel data is truncated");
	for (long y = 0; y < h; ++y) {
		const uint8_t *row = d + off + rowsize * (topdown ? y : (h - 1 - y));
		uint8_t *out = img->rgb + y * w * 3;
		for (long x = 0; x < w; ++x, out += 3) {
			switch (bpp) {
				case 1:
					memcpy(out, pal[(row[x >> 3] >> (7 - (x & 7))) & 1], 3);
					break;
				case 4:
					memcpy(out, pal[(x & 1) ? (row[x >> 1] & 15) : (row[x >> 1] >> 4)], 3);
					break;
				case 8:
					memcpy(out, pal[row[x]], 3);
					break;
				case 24:
					out[0] = row[x * 3 + 2];
					out[1] = row[x * 3 + 1];
					out[2] = row[x * 3];
					break;
				case 16:
				case 32: {
					uint32_t px = (bpp == 16) ? u16le(row + x * 2) : u32le(row + x * 4);
					out[0] = bitfield_get(&bf[0], px);
					out[1] = bitfield_get(&bf[1], px);
					out[2] = bitfield_get(&bf[2], px);
					break;
				}
			}
		}
	}
	return 0;
}

// ---------------------------------------------------------------- Targa

static int tga_header_ok(const uint8_t *d, size_t len)
{
	if (len < 18)
		return 0;
	unsigned cmtype = d[1], type = d[2], bpp = d[16];
	if (cmtype > 1)
		return 0;
	if ((u16le(d + 12) == 0) || (u16le(d + 14) == 0))
		return 0;
	switch (type) {
		case 1: case 9: // color mapped
			return (cmtype == 1) && ((bpp == 8) || (bpp == 16));
		case 2: case 10: // truecolor
			return (bpp == 15) || (bpp == 16) || (bpp == 24) || (bpp == 32);
		case 3: case 11: // grayscale
			return bpp == 8;
	}
	return 0;
}

// one Targa color value of a_bits bits to RGB
static void tga_color(const uint8_t *p, unsigned a_bits, uint8_t *out)
{
	if ((a_bits == 15) || (a_bits == 16)) {
		unsigned v = u16le(p);
		out[0] = ((v >> 10) & 31) * 255 / 31;
		out[1] = ((v >> 5) & 31) * 255 / 31;
		out[2] = (v & 31) * 255 / 31;
	} else { // 24 or 32 (BGR(A))
		out[0] = p[2];
		out[1] = p[1];
		out[2] = p[0];
	}
}

static int decode_tga(const uint8_t *d, size_t len, image_t *img)
{
	if (!tga_header_ok(d, len))
		return fail("unsupported or bad Targa header");
	unsigned idlen = d[0], cmtype = d[1], type = d[2];
	unsigned cmfirst = u16le(d + 3), cmlen = u16le(d + 5), cmbits = d[7];
	unsigned w = u16le(d + 12), h = u16le(d + 14), bpp = d[16], desc = d[17];
	size_t p = 18 + idlen;
	unsigned bytespp = (bpp + 7) / 8;

	// color map (it can be present even for truecolor images; then it's just skipped)
	uint8_t (*cmap)[3] = NULL;
	if (cmtype == 1) {
		if ((cmbits != 15) && (cmbits != 16) && (cmbits != 24) && (cmbits != 32))
			return fail("unsupported Targa color map");
		size_t cmsize = (size_t)cmlen * ((cmbits + 7) / 8);
		if (p + cmsize > len)
			return fail("Targa color map is truncated");
		if ((type == 1) || (type == 9)) {
			cmap = calloc(cmlen ? cmlen : 1, 3);
			if (!cmap)
				return fail("out of memory");
			for (unsigned i = 0; i < cmlen; ++i)
				tga_color(d + p + i * ((cmbits + 7) / 8), cmbits, cmap[i]);
		}
		p += cmsize;
	}

	if (alloc_image(img, w, h) < 0) {
		free(cmap);
		return -1;
	}

	int rle = (type >= 9);
	size_t total = (size_t)w * h, n = 0;
	unsigned run = 0, raw = 0;
	const uint8_t *px = NULL;
	int truncated = 0;
	while (n < total) {
		// next pixel's bytes
		if (rle && !run && !raw) {
			if (p >= len) { truncated = 1; break; }
			unsigned hdr = d[p++];
			if (hdr & 0x80) {
				if (p + bytespp > len) { truncated = 1; break; }
				run = (hdr & 0x7f) + 1;
				px = d + p;
				p += bytespp;
			} else {
				raw = (hdr & 0x7f) + 1;
			}
		}
		if (run) {
			--run;
		} else {
			if (p + bytespp > len) { truncated = 1; break; }
			px = d + p;
			p += bytespp;
			if (raw)
				--raw;
		}

		// where it goes: bottom-up unless descriptor bit 5, left to right unless bit 4
		unsigned row = n / w, col = n % w;
		if (!(desc & 0x20))
			row = h - 1 - row;
		if (desc & 0x10)
			col = w - 1 - col;
		uint8_t *out = img->rgb + ((size_t)row * w + col) * 3;
		if (cmap) {
			unsigned i = (bpp == 8) ? px[0] : u16le(px);
			i -= cmfirst;
			if (i < cmlen)
				memcpy(out, cmap[i], 3);
		} else if ((type == 3) || (type == 11)) {
			out[0] = out[1] = out[2] = px[0];
		} else {
			tga_color(px, bpp, out);
		}
		++n;
	}
	free(cmap);
	if (truncated)
		return fail("Targa pixel data is truncated");
	return 0;
}

// ---------------------------------------------------------------- JPEG (baseline)

static const uint8_t g_zigzag[64] = {
	 0,  1,  8, 16,  9,  2,  3, 10, 17, 24, 32, 25, 18, 11,  4,  5,
	12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13,  6,  7, 14, 21, 28,
	35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
	58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63
};

typedef struct {
	int present;
	int32_t maxcode[18]; // largest code of each length, -1 if none
	int32_t valptr[17];  // index in vals of the first code of each length
	int32_t mincode[17];
	uint8_t vals[256];
} huff_t;

typedef struct {
	int id, h, v, tq;
	int td, ta;          // DC and AC table for the current scan
	int pred;            // DC predictor
	int bw, bh;          // plane size in blocks
	uint8_t *plane;      // bw*8 x bh*8 samples
} jcomp_t;

typedef struct {
	const uint8_t *d;
	size_t len, pos;
	uint32_t buf;
	int cnt;
	int marker;          // hit a marker in the entropy data: feed zeros from here
	uint16_t qt[4][64];
	int qt_present[4];
	huff_t dc[4], ac[4];
	int ncomp, width, height, hmax, vmax, mcux, mcuy;
	jcomp_t comp[4];
	int restart;
	int adobe, adobe_transform;
	int frame_seen;
} jpeg_t;

static float g_idct_cos[8][8]; // [x][u] = C(u) * cos((2x+1)u pi / 16) / 2

static void idct_init(void)
{
	for (int x = 0; x < 8; ++x)
		for (int u = 0; u < 8; ++u)
			g_idct_cos[x][u] = (float)(((u == 0) ? M_SQRT1_2 : 1.0) * cos((2 * x + 1) * u * M_PI / 16.0) / 2.0);
}

static void idct_block(const int *a_coef, uint8_t *a_out, int a_stride)
{
	float tmp[64];
	// columns: tmp[y][u] = sum_v cos[y][v] * coef[v][u]
	for (int u = 0; u < 8; ++u)
		for (int y = 0; y < 8; ++y) {
			float s = 0;
			for (int v = 0; v < 8; ++v)
				s += g_idct_cos[y][v] * a_coef[v * 8 + u];
			tmp[y * 8 + u] = s;
		}
	// rows
	for (int y = 0; y < 8; ++y)
		for (int x = 0; x < 8; ++x) {
			float s = 0;
			for (int u = 0; u < 8; ++u)
				s += g_idct_cos[x][u] * tmp[y * 8 + u];
			int v = (int)lrintf(s + 128.0f);
			a_out[y * a_stride + x] = (v < 0) ? 0 : ((v > 255) ? 255 : v);
		}
}

static void bits_fill(jpeg_t *j)
{
	while (j->cnt <= 24) {
		uint8_t b = 0;
		if (!j->marker && (j->pos < j->len)) {
			b = j->d[j->pos];
			if (b == 0xff) {
				uint8_t next = (j->pos + 1 < j->len) ? j->d[j->pos + 1] : 0xd9;
				if (next == 0x00) {
					j->pos += 2; // stuffed FF
				} else {
					j->marker = 1; // stop here, the marker is read later
					b = 0;
				}
			} else {
				j->pos++;
			}
		}
		j->buf |= (uint32_t)b << (24 - j->cnt);
		j->cnt += 8;
	}
}

static unsigned bits_get(jpeg_t *j, int n)
{
	if (n == 0)
		return 0;
	if (j->cnt < n)
		bits_fill(j);
	unsigned v = j->buf >> (32 - n);
	j->buf <<= n;
	j->cnt -= n;
	return v;
}

static void huff_build(huff_t *a_h, const uint8_t *a_counts, const uint8_t *a_vals, int a_nvals)
{
	int code = 0, k = 0;
	memcpy(a_h->vals, a_vals, a_nvals);
	for (int l = 1; l <= 16; ++l) {
		a_h->valptr[l] = k;
		a_h->mincode[l] = code;
		code += a_counts[l - 1];
		k += a_counts[l - 1];
		a_h->maxcode[l] = a_counts[l - 1] ? code - 1 : -1;
		code <<= 1;
	}
	a_h->maxcode[17] = 0x7fffffff;
	a_h->present = 1;
}

static int huff_decode(jpeg_t *j, const huff_t *a_h)
{
	int32_t code = bits_get(j, 1);
	int l = 1;
	while ((l <= 16) && (code > a_h->maxcode[l])) {
		code = (code << 1) | bits_get(j, 1);
		++l;
	}
	if (l > 16)
		return -1;
	return a_h->vals[a_h->valptr[l] + code - a_h->mincode[l]];
}

static int extend(unsigned a_v, int a_t)
{
	return (a_v < (1u << (a_t - 1))) ? (int)a_v - (1 << a_t) + 1 : (int)a_v;
}

static int decode_block(jpeg_t *j, jcomp_t *c, uint8_t *a_out, int a_stride)
{
	int coef[64];
	const uint16_t *q = j->qt[c->tq];
	memset(coef, 0, sizeof(coef));

	int t = huff_decode(j, &j->dc[c->td]);
	if ((t < 0) || (t > 11))
		return fail("bad JPEG data");
	c->pred += t ? extend(bits_get(j, t), t) : 0;
	coef[0] = c->pred * q[0];
	for (int k = 1; k < 64; ) {
		int rs = huff_decode(j, &j->ac[c->ta]);
		if (rs < 0)
			return fail("bad JPEG data");
		int r = rs >> 4, s = rs & 15;
		if (s == 0) {
			if (r != 15)
				break; // end of block
			k += 16;
			continue;
		}
		k += r;
		if (k > 63)
			return fail("bad JPEG data");
		coef[g_zigzag[k]] = extend(bits_get(j, s), s) * q[k];
		++k;
	}
	idct_block(coef, a_out, a_stride);
	return 0;
}

// skip to the RSTn marker after a restart interval and reset the decoder state
static void jpeg_restart(jpeg_t *j)
{
	j->buf = 0;
	j->cnt = 0;
	j->marker = 0;
	while (j->pos + 1 < j->len) {
		if ((j->d[j->pos] == 0xff) && (j->d[j->pos + 1] >= 0xd0) && (j->d[j->pos + 1] <= 0xd7)) {
			j->pos += 2;
			break;
		}
		j->pos++;
	}
	for (int i = 0; i < j->ncomp; ++i)
		j->comp[i].pred = 0;
}

static int jpeg_scan(jpeg_t *j, jcomp_t **a_sc, int a_ns)
{
	for (int i = 0; i < a_ns; ++i) {
		a_sc[i]->pred = 0;
		if (!j->dc[a_sc[i]->td].present || !j->ac[a_sc[i]->ta].present)
			return fail("bad JPEG: missing Huffman table");
		if (!j->qt_present[a_sc[i]->tq])
			return fail("bad JPEG: missing quantization table");
	}
	j->buf = 0;
	j->cnt = 0;
	j->marker = 0;
	int count = 0;

	if (a_ns == 1) {
		// non-interleaved: one block per MCU, covering only the component's own area
		jcomp_t *c = a_sc[0];
		int cw = (j->width * c->h + j->hmax - 1) / j->hmax;
		int ch = (j->height * c->v + j->vmax - 1) / j->vmax;
		int bx = (cw + 7) / 8, by = (ch + 7) / 8;
		int stride = c->bw * 8;
		for (int y = 0; y < by; ++y)
			for (int x = 0; x < bx; ++x) {
				if (j->restart && count && !(count % j->restart))
					jpeg_restart(j);
				if (decode_block(j, c, c->plane + (y * 8) * stride + x * 8, stride) < 0)
					return -1;
				++count;
			}
	} else {
		for (int my = 0; my < j->mcuy; ++my)
			for (int mx = 0; mx < j->mcux; ++mx) {
				if (j->restart && count && !(count % j->restart))
					jpeg_restart(j);
				for (int i = 0; i < a_ns; ++i) {
					jcomp_t *c = a_sc[i];
					int stride = c->bw * 8;
					for (int v = 0; v < c->v; ++v)
						for (int h = 0; h < c->h; ++h) {
							int bx = mx * c->h + h, by = my * c->v + v;
							if (decode_block(j, c, c->plane + (by * 8) * stride + bx * 8, stride) < 0)
								return -1;
						}
				}
				++count;
			}
	}
	// carry on from the next marker after the scan
	while (j->pos + 1 < j->len) {
		if ((j->d[j->pos] == 0xff) && (j->d[j->pos + 1] != 0) && (j->d[j->pos + 1] != 0xff)
			&& !((j->d[j->pos + 1] >= 0xd0) && (j->d[j->pos + 1] <= 0xd7)))
			break;
		j->pos++;
	}
	return 0;
}

static int decode_jpeg(const uint8_t *d, size_t len, image_t *img)
{
	jpeg_t *j = calloc(1, sizeof(jpeg_t));
	int ret = -1, scans = 0;
	if (!j)
		return fail("out of memory");
	j->d = d;
	j->len = len;
	j->pos = 2; // after SOI
	idct_init();

	for (;;) {
		// next marker
		if (j->pos >= len) {
			if (scans)
				break; // missing EOI: use what we have
			fail("JPEG file is truncated");
			goto done;
		}
		if (d[j->pos] != 0xff) {
			fail("bad JPEG marker");
			goto done;
		}
		while ((j->pos < len) && (d[j->pos] == 0xff))
			j->pos++;
		if (j->pos >= len)
			continue;
		uint8_t m = d[j->pos++];
		if (m == 0xd9) // EOI
			break;
		if ((m == 0x01) || ((m >= 0xd0) && (m <= 0xd7)))
			continue; // markers without a length
		if (j->pos + 2 > len) {
			fail("JPEG file is truncated");
			goto done;
		}
		size_t seglen = u16be(d + j->pos);
		if ((seglen < 2) || (j->pos + seglen > len)) {
			fail("JPEG file is truncated");
			goto done;
		}
		const uint8_t *s = d + j->pos + 2;
		size_t sl = seglen - 2;
		j->pos += seglen;

		switch (m) {
			case 0xc0: case 0xc1: { // SOF0/SOF1: baseline / extended sequential Huffman
				if (j->frame_seen) {
					fail("bad JPEG: more than one frame");
					goto done;
				}
				if (sl < 6) {
					fail("bad JPEG frame header");
					goto done;
				}
				if (s[0] != 8) {
					fail("unsupported JPEG: only 8 bit samples are supported");
					goto done;
				}
				j->height = u16be(s + 1);
				j->width = u16be(s + 3);
				j->ncomp = s[5];
				if ((j->width == 0) || (j->height == 0)) {
					fail("unsupported JPEG: no image size in the frame header");
					goto done;
				}
				if ((j->ncomp != 1) && (j->ncomp != 3)) {
					fail("unsupported JPEG: only grayscale and 3 component color are supported (no CMYK)");
					goto done;
				}
				if (sl < 6 + (size_t)j->ncomp * 3) {
					fail("bad JPEG frame header");
					goto done;
				}
				if ((long)j->width * j->height > MAX_PIXELS) {
					fail("image is too large");
					goto done;
				}
				j->hmax = j->vmax = 1;
				for (int i = 0; i < j->ncomp; ++i) {
					jcomp_t *c = &j->comp[i];
					c->id = s[6 + i * 3];
					c->h = s[7 + i * 3] >> 4;
					c->v = s[7 + i * 3] & 15;
					c->tq = s[8 + i * 3] & 3;
					if ((c->h < 1) || (c->h > 4) || (c->v < 1) || (c->v > 4)) {
						fail("bad JPEG sampling factors");
						goto done;
					}
					if (c->h > j->hmax) j->hmax = c->h;
					if (c->v > j->vmax) j->vmax = c->v;
				}
				j->mcux = (j->width + 8 * j->hmax - 1) / (8 * j->hmax);
				j->mcuy = (j->height + 8 * j->vmax - 1) / (8 * j->vmax);
				for (int i = 0; i < j->ncomp; ++i) {
					jcomp_t *c = &j->comp[i];
					c->bw = j->mcux * c->h;
					c->bh = j->mcuy * c->v;
					c->plane = calloc((size_t)c->bw * 8 * c->bh * 8, 1);
					if (!c->plane) {
						fail("out of memory");
						goto done;
					}
				}
				j->frame_seen = 1;
				break;
			}
			case 0xc2: case 0xc6: case 0xca: case 0xce:
				fail("unsupported JPEG: progressive JPEGs aren't supported (re-save it as baseline)");
				goto done;
			case 0xc3: case 0xc5: case 0xc7: case 0xc9: case 0xcb: case 0xcd: case 0xcf:
				fail("unsupported JPEG: lossless, hierarchical and arithmetic coded JPEGs aren't supported");
				goto done;
			case 0xc4: { // DHT
				size_t p = 0;
				while (p < sl) {
					if (p + 17 > sl) {
						fail("bad JPEG Huffman table");
						goto done;
					}
					int tc = s[p] >> 4, th = s[p] & 15;
					int n = 0;
					for (int i = 0; i < 16; ++i)
						n += s[p + 1 + i];
					if ((tc > 1) || (th > 3) || (n > 256) || (p + 17 + n > sl)) {
						fail("bad JPEG Huffman table");
						goto done;
					}
					huff_build(tc ? &j->ac[th] : &j->dc[th], s + p + 1, s + p + 17, n);
					p += 17 + n;
				}
				break;
			}
			case 0xdb: { // DQT
				size_t p = 0;
				while (p < sl) {
					int pq = s[p] >> 4, tq = s[p] & 15;
					size_t n = pq ? 128 : 64;
					if ((pq > 1) || (tq > 3) || (p + 1 + n > sl)) {
						fail("bad JPEG quantization table");
						goto done;
					}
					for (int i = 0; i < 64; ++i)
						j->qt[tq][i] = pq ? u16be(s + p + 1 + i * 2) : s[p + 1 + i];
					j->qt_present[tq] = 1;
					p += 1 + n;
				}
				break;
			}
			case 0xdd: // DRI
				if (sl < 2) {
					fail("bad JPEG restart interval");
					goto done;
				}
				j->restart = u16be(s);
				break;
			case 0xee: // APP14: Adobe, tells whether 3 components are RGB or YCbCr
				if ((sl >= 12) && !memcmp(s, "Adobe", 5)) {
					j->adobe = 1;
					j->adobe_transform = s[11];
				}
				break;
			case 0xda: { // SOS
				if (!j->frame_seen) {
					fail("bad JPEG: scan before frame header");
					goto done;
				}
				if (sl < 1) {
					fail("bad JPEG scan header");
					goto done;
				}
				int ns = s[0];
				if ((ns < 1) || (ns > j->ncomp) || (sl < 4 + (size_t)ns * 2)) {
					fail("bad JPEG scan header");
					goto done;
				}
				jcomp_t *sc[4];
				for (int i = 0; i < ns; ++i) {
					int id = s[1 + i * 2], k;
					for (k = 0; k < j->ncomp; ++k)
						if (j->comp[k].id == id)
							break;
					if (k == j->ncomp) {
						fail("bad JPEG scan header");
						goto done;
					}
					sc[i] = &j->comp[k];
					sc[i]->td = s[2 + i * 2] >> 4;
					sc[i]->ta = s[2 + i * 2] & 15;
					if ((sc[i]->td > 3) || (sc[i]->ta > 3)) {
						fail("bad JPEG scan header");
						goto done;
					}
				}
				if (jpeg_scan(j, sc, ns) < 0)
					goto done;
				++scans;
				break;
			}
			default:
				break; // APPn, COM, etc.
		}
	}
	if (!scans) {
		fail("JPEG has no image data");
		goto done;
	}

	// to RGB
	if (alloc_image(img, j->width, j->height) < 0)
		goto done;
	int rgb = (j->ncomp == 3) && ((j->adobe && (j->adobe_transform == 0))
		|| ((j->comp[0].id == 'R') && (j->comp[1].id == 'G') && (j->comp[2].id == 'B')));
	for (int y = 0; y < j->height; ++y)
		for (int x = 0; x < j->width; ++x) {
			uint8_t smp[3];
			for (int i = 0; i < j->ncomp; ++i) {
				jcomp_t *c = &j->comp[i];
				smp[i] = c->plane[(y * c->v / j->vmax) * c->bw * 8 + (x * c->h / j->hmax)];
			}
			uint8_t *out = img->rgb + ((size_t)y * j->width + x) * 3;
			if (j->ncomp == 1) {
				out[0] = out[1] = out[2] = smp[0];
			} else if (rgb) {
				memcpy(out, smp, 3);
			} else {
				float Y = smp[0], cb = smp[1] - 128.0f, cr = smp[2] - 128.0f;
				float v[3] = { Y + 1.402f * cr, Y - 0.344136f * cb - 0.714136f * cr, Y + 1.772f * cb };
				for (int k = 0; k < 3; ++k) {
					int iv = (int)lrintf(v[k]);
					out[k] = (iv < 0) ? 0 : ((iv > 255) ? 255 : iv);
				}
			}
		}
	ret = 0;
done:
	for (int i = 0; i < 4; ++i)
		free(j->comp[i].plane);
	free(j);
	return ret;
}

// ---------------------------------------------------------------- scaling and output

// one destination pixel from the source area [x0,x1) x [y0,y1) (in source pixels), area weighted
static void sample_area(const image_t *a_img, double x0, double x1, double y0, double y1, double *a_out)
{
	double acc[3] = { 0, 0, 0 }, total = 0;
	for (int sy = (int)floor(y0); sy < (int)ceil(y1); ++sy) {
		double wy = fmin(y1, sy + 1) - fmax(y0, sy);
		if ((wy <= 0) || (sy < 0) || (sy >= a_img->h))
			continue;
		for (int sx = (int)floor(x0); sx < (int)ceil(x1); ++sx) {
			double wx = fmin(x1, sx + 1) - fmax(x0, sx);
			if ((wx <= 0) || (sx < 0) || (sx >= a_img->w))
				continue;
			const uint8_t *p = a_img->rgb + ((size_t)sy * a_img->w + sx) * 3;
			for (int k = 0; k < 3; ++k)
				acc[k] += p[k] * wx * wy;
			total += wx * wy;
		}
	}
	for (int k = 0; k < 3; ++k)
		a_out[k] = total ? acc[k] / total : 0;
}

// bilinear sample at source position (x, y), pixel centers at +0.5
static void sample_bilinear(const image_t *a_img, double x, double y, double *a_out)
{
	x -= 0.5;
	y -= 0.5;
	int ix = (int)floor(x), iy = (int)floor(y);
	double fx = x - ix, fy = y - iy;
	for (int k = 0; k < 3; ++k)
		a_out[k] = 0;
	for (int dy = 0; dy < 2; ++dy)
		for (int dx = 0; dx < 2; ++dx) {
			int sx = ix + dx, sy = iy + dy;
			sx = (sx < 0) ? 0 : ((sx >= a_img->w) ? a_img->w - 1 : sx);
			sy = (sy < 0) ? 0 : ((sy >= a_img->h) ? a_img->h - 1 : sy);
			double wgt = (dx ? fx : 1 - fx) * (dy ? fy : 1 - fy);
			const uint8_t *p = a_img->rgb + ((size_t)sy * a_img->w + sx) * 3;
			for (int k = 0; k < 3; ++k)
				a_out[k] += p[k] * wgt;
		}
}

static unsigned to4(double a_v)
{
	int v = (int)lrint(a_v * 15.0 / 255.0);
	return (v < 0) ? 0 : ((v > 15) ? 15 : v);
}

// build the screen (a_sw x a_sh 16 bit pixels, low byte first)
static uint8_t *make_screen(const image_t *a_img, int a_sw, int a_sh, int a_scale)
{
	uint8_t *scr = calloc((size_t)a_sw * a_sh, 2); // black
	if (!scr)
		return NULL;
	int dw = a_img->w, dh = a_img->h;
	double f = 1.0;
	if (a_scale) {
		f = fmin((double)a_sw / a_img->w, (double)a_sh / a_img->h);
		dw = (int)lrint(a_img->w * f);
		dh = (int)lrint(a_img->h * f);
		if (dw < 1) dw = 1;
		if (dh < 1) dh = 1;
		if (dw > a_sw) dw = a_sw;
		if (dh > a_sh) dh = a_sh;
	}
	int ox = (a_sw - dw) / 2, oy = (a_sh - dh) / 2;
	double sx = (double)a_img->w / dw, sy = (double)a_img->h / dh; // source pixels per screen pixel

	for (int y = 0; y < dh; ++y)
		for (int x = 0; x < dw; ++x) {
			double c[3];
			if (!a_scale) {
				const uint8_t *p = a_img->rgb + ((size_t)y * a_img->w + x) * 3;
				c[0] = p[0]; c[1] = p[1]; c[2] = p[2];
			} else if ((sx >= 1.0) && (sy >= 1.0)) {
				sample_area(a_img, x * sx, (x + 1) * sx, y * sy, (y + 1) * sy, c); // shrinking
			} else {
				sample_bilinear(a_img, (x + 0.5) * sx, (y + 0.5) * sy, c); // enlarging
			}
			unsigned px = (to4(c[0]) << 8) | (to4(c[1]) << 4) | to4(c[2]);
			uint8_t *o = scr + ((size_t)(oy + y) * a_sw + (ox + x)) * 2;
			o[0] = px & 0xff;
			o[1] = px >> 8;
		}
	return scr;
}

// ---------------------------------------------------------------- main

static struct option g_options[] = {
	{ "input", required_argument, NULL, 'i' },
	{ "output", required_argument, NULL, 'o' },
	{ "mode", required_argument, NULL, 'm' },
	{ "scale", no_argument, NULL, 's' },
	{ "help", no_argument, NULL, 'h' },
	{ NULL, 0, NULL, 0 }
};

static void usage(void)
{
	fprintf(stderr, "usage: gconvert -i input.(bmp/tga/jpg) -o screen.scr -m (4/5/6) [-s]\n"
		"       -i, --input   BMP, Targa or JPEG image\n"
		"       -o, --output  screen image, to load at 180000h\n"
		"       -m, --mode    4 = 120x68, 5 = 240x136, 6 = 480x272 (4096 colors)\n"
		"       -s, --scale   scale the image to fit the screen\n");
}

static uint8_t *read_file(const char *a_name, size_t *a_len)
{
	FILE *f = fopen(a_name, "rb");
	if (!f) {
		fprintf(stderr, "gconvert: can't open %s: %s\n", a_name, strerror(errno));
		return NULL;
	}
	size_t cap = 1 << 20, len = 0;
	uint8_t *buf = malloc(cap);
	while (buf) {
		len += fread(buf + len, 1, cap - len, f);
		if (len < cap)
			break;
		uint8_t *nb = realloc(buf, cap * 2);
		if (!nb) {
			free(buf);
			buf = NULL;
			break;
		}
		buf = nb;
		cap *= 2;
	}
	if (!buf) {
		fprintf(stderr, "gconvert: out of memory reading %s\n", a_name);
	} else if (ferror(f)) {
		fprintf(stderr, "gconvert: error reading %s: %s\n", a_name, strerror(errno));
		free(buf);
		buf = NULL;
	}
	fclose(f);
	*a_len = len;
	return buf;
}

int main(int argc, char **argv)
{
	int opt, scale = 0, mode = 0;
	char *input = NULL, *output = NULL, *end;

	while ((opt = getopt_long(argc, argv, "i:o:m:sh", g_options, NULL)) != -1) {
		switch (opt) {
			case 'i':
				input = optarg;
				break;
			case 'o':
				output = optarg;
				break;
			case 'm':
				mode = (int)strtol(optarg, &end, 10);
				if ((*end != 0) || (mode < 4) || (mode > 6)) {
					fprintf(stderr, "gconvert: mode must be 4, 5 or 6, not '%s'\n", optarg);
					return 1;
				}
				break;
			case 's':
				scale = 1;
				break;
			default:
				usage();
				return 1;
		}
	}
	if (optind < argc) {
		fprintf(stderr, "gconvert: unexpected argument '%s'\n", argv[optind]);
		usage();
		return 1;
	}
	if (!input || !output || !mode) {
		fprintf(stderr, "gconvert: %s\n", !input ? "no input file specified (-i)" :
			(!output ? "no output file specified (-o)" : "no mode specified (-m)"));
		usage();
		return 1;
	}
	int sw = 120 << (mode - 4), sh = 68 << (mode - 4);

	size_t len;
	uint8_t *data = read_file(input, &len);
	if (!data)
		return 1;

	image_t img = { 0, 0, NULL };
	int r;
	const char *kind;
	if ((len >= 2) && (data[0] == 'B') && (data[1] == 'M')) {
		kind = "BMP";
		r = decode_bmp(data, len, &img);
	} else if ((len >= 3) && (data[0] == 0xff) && (data[1] == 0xd8) && (data[2] == 0xff)) {
		kind = "JPEG";
		r = decode_jpeg(data, len, &img);
	} else if (tga_header_ok(data, len)) { // Targa has no signature; go by a sensible header
		kind = "Targa";
		r = decode_tga(data, len, &img);
	} else {
		fprintf(stderr, "gconvert: %s is not a BMP, Targa or JPEG file\n", input);
		free(data);
		return 1;
	}
	free(data);
	if (r < 0) {
		fprintf(stderr, "gconvert: %s: %s\n", input, g_err);
		free(img.rgb);
		return 1;
	}

	if (!scale && ((img.w > sw) || (img.h > sh))) {
		fprintf(stderr, "gconvert: %s is %dx%d, bigger than mode %d's %dx%d. Use -s (--scale) to scale it to fit.\n",
			input, img.w, img.h, mode, sw, sh);
		free(img.rgb);
		return 1;
	}

	uint8_t *scr = make_screen(&img, sw, sh, scale);
	free(img.rgb);
	if (!scr) {
		fprintf(stderr, "gconvert: out of memory\n");
		return 1;
	}

	size_t outlen = (size_t)sw * sh * 2;
	FILE *f = fopen(output, "wb");
	if (!f) {
		fprintf(stderr, "gconvert: can't create %s: %s\n", output, strerror(errno));
		free(scr);
		return 1;
	}
	size_t n = fwrite(scr, 1, outlen, f);
	int err = (n != outlen) ? (errno ? errno : EIO) : 0;
	if ((fclose(f) != 0) && !err)
		err = errno ? errno : EIO;
	free(scr);
	if (err) {
		fprintf(stderr, "gconvert: error writing %s: %s\n", output, strerror(err));
		unlink(output);
		return 1;
	}
	printf("gconvert: %s %s (%dx%d) -> %s, mode %d (%dx%d, %zu bytes, load with bload -a 180000h)\n",
		kind, input, img.w, img.h, output, mode, sw, sh, outlen);
	return 0;
}
