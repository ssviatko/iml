#include <X11/Xlib.h>
#include <X11/keysym.h> // for Keysym stuff
#include <X11/Xutil.h> // for XLookupString
#include <assert.h>
#include <stdio.h>
#include <signal.h>
#include <time.h>
#include <getopt.h>
#include <stdarg.h>

#include "memio_driver.h"

#define DEFAULTX 480
#define DEFAULTY 272

struct option g_options[] = {
	{ "scale", required_argument, NULL, 's' },
	{ "exec", required_argument, NULL, 'e' },
	{ NULL, 0, NULL, 0 }
};

unsigned int g_scale = 2;

// X globals
Display *dpy;
int blackColor, whiteColor;
Window win;
GC gc;
Pixmap osb;

int g_flashing;
int g_flash_countdown;
const int g_flash_rate = 15;

const uint8_t g_standard_colors[][3] = {
    { 0x00, 0x00, 0x00 }, // Black
    { 0xdd, 0x00, 0x33 }, // Deep Red
    { 0x00, 0x00, 0x99 }, // Dark Blue
    { 0xdd, 0x22, 0xdd }, // Purple
    { 0x00, 0x77, 0x22 }, // Dark Green
    { 0x55, 0x55, 0x55 }, // Dark Gray
    { 0x22, 0x22, 0xff }, // Medium Blue
    { 0x66, 0xaa, 0xff }, // Light Blue
    { 0x88, 0x55, 0x00 }, // Brown
    { 0xff, 0x66, 0x00 }, // Orange
    { 0xaa, 0xaa, 0xaa }, // Light Gray
    { 0xff, 0x99, 0x88 }, // Pink
    { 0x11, 0xdd, 0x00 }, // Light Green
    { 0xff, 0xff, 0x00 }, // Yellow
    { 0x44, 0xff, 0x99 }, // Aquamarine
    { 0xff, 0xff, 0xff }  // White
};

const uint8_t g_char_rom[][8] = {
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 00
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 01
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 02
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 03
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 04
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 05
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 06
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 07
    { 0x00, 0x08, 0x10, 0x3e, 0x10, 0x08, 0x00, 0x00 }, // 08
    { 0x00, 0x08, 0x1c, 0x2a, 0x08, 0x08, 0x00, 0x00 }, // 09
    { 0x00, 0x08, 0x08, 0x2a, 0x1c, 0x08, 0x00, 0x00 }, // 0a
    { 0x00, 0x08, 0x04, 0x3e, 0x04, 0x08, 0x00, 0x00 }, // 0b
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 0c
    { 0x00, 0x02, 0x0a, 0x12, 0x3e, 0x10, 0x08, 0x00 }, // 0d
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 0e
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 0f
    { 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14 }, // 10
    { 0x00, 0x00, 0x3f, 0x00, 0x3f, 0x00, 0x00, 0x00 }, // 11
    { 0x00, 0x00, 0x1f, 0x10, 0x17, 0x14, 0x14, 0x14 }, // 12
    { 0x00, 0x00, 0x3c, 0x04, 0x34, 0x14, 0x14, 0x14 }, // 13
    { 0x14, 0x14, 0x34, 0x04, 0x3c, 0x00, 0x00, 0x00 }, // 14
    { 0x14, 0x14, 0x17, 0x10, 0x1f, 0x00, 0x00, 0x00 }, // 15
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 16
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 17
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 18
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 19
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 1a
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 1b
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 1c
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 1d
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 1e
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a }, // 1f
    { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, // 20
    { 0x08, 0x08, 0x08, 0x08, 0x00, 0x00, 0x08, 0x00 }, // 21 !
    { 0x14, 0x14, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00 }, // 22 "
    { 0x14, 0x14, 0x3e, 0x14, 0x3e, 0x14, 0x14, 0x00 }, // 23 #
    { 0x08, 0x1e, 0x28, 0x1c, 0x0a, 0x3c, 0x08, 0x00 }, // 24 $
    { 0x30, 0x32, 0x04, 0x08, 0x10, 0x26, 0x06, 0x00 }, // 25 %
    { 0x18, 0x24, 0x28, 0x10, 0x2a, 0x24, 0x1a, 0x00 }, // 26 &
    { 0x18, 0x08, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00 }, // 27 '
    { 0x04, 0x08, 0x10, 0x10, 0x10, 0x08, 0x04, 0x00 }, // 28 (
    { 0x10, 0x08, 0x04, 0x04, 0x04, 0x08, 0x10, 0x00 }, // 29 )
    { 0x00, 0x08, 0x2a, 0x1c, 0x2a, 0x08, 0x00, 0x00 }, // 2a *
    { 0x00, 0x08, 0x08, 0x3e, 0x08, 0x08, 0x00, 0x00 }, // 2b +
    { 0x00, 0x00, 0x00, 0x00, 0x18, 0x08, 0x10, 0x00 }, // 2c ,
    { 0x00, 0x00, 0x00, 0x3e, 0x00, 0x00, 0x00, 0x00 }, // 2d -
    { 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00 }, // 2e .
    { 0x00, 0x02, 0x04, 0x08, 0x10, 0x20, 0x00, 0x00 }, // 2f /
    { 0x1c, 0x22, 0x26, 0x2a, 0x32, 0x22, 0x1c, 0x00 }, // 30 0
    { 0x08, 0x18, 0x08, 0x08, 0x08, 0x08, 0x1c, 0x00 }, // 31 1
    { 0x1c, 0x22, 0x02, 0x04, 0x08, 0x10, 0x3e, 0x00 }, // 32 2
    { 0x3e, 0x04, 0x08, 0x04, 0x02, 0x22, 0x1c, 0x00 }, // 33 3
    { 0x04, 0x0c, 0x14, 0x24, 0x3e, 0x04, 0x04, 0x00 }, // 34 4
    { 0x3e, 0x20, 0x3c, 0x02, 0x02, 0x22, 0x1c, 0x00 }, // 35 5
    { 0x0c, 0x10, 0x20, 0x3c, 0x22, 0x22, 0x1c, 0x00 }, // 36 6
    { 0x3e, 0x02, 0x04, 0x08, 0x10, 0x10, 0x10, 0x00 }, // 37 7
    { 0x1c, 0x22, 0x22, 0x1c, 0x22, 0x22, 0x1c, 0x00 }, // 38 8
    { 0x1c, 0x22, 0x22, 0x1e, 0x02, 0x04, 0x18, 0x00 }, // 39 9
    { 0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x00, 0x00 }, // 3a :
    { 0x00, 0x18, 0x18, 0x00, 0x18, 0x08, 0x10, 0x00 }, // 3b ;
    { 0x04, 0x08, 0x10, 0x20, 0x10, 0x08, 0x04, 0x00 }, // 3c >
    { 0x00, 0x00, 0x3e, 0x00, 0x3e, 0x00, 0x00, 0x00 }, // 3d =
    { 0x10, 0x08, 0x04, 0x02, 0x04, 0x08, 0x10, 0x00 }, // 3e <
    { 0x1c, 0x22, 0x02, 0x04, 0x08, 0x00, 0x08, 0x00 }, // 3f ?
    { 0x1c, 0x22, 0x02, 0x1a, 0x2a, 0x2a, 0x1c, 0x00 }, // 40 @
    { 0x1c, 0x22, 0x22, 0x22, 0x3e, 0x22, 0x22, 0x00 }, // 41 A
    { 0x3c, 0x22, 0x22, 0x3c, 0x22, 0x22, 0x3c, 0x00 }, // 42 B
    { 0x1c, 0x22, 0x20, 0x20, 0x20, 0x22, 0x1c, 0x00 }, // 43 C
    { 0x38, 0x24, 0x22, 0x22, 0x22, 0x24, 0x38, 0x00 }, // 44 D
    { 0x3e, 0x20, 0x20, 0x3c, 0x20, 0x20, 0x3e, 0x00 }, // 45 E
    { 0x3e, 0x20, 0x20, 0x3c, 0x20, 0x20, 0x20, 0x00 }, // 46 F
    { 0x1c, 0x22, 0x20, 0x2e, 0x22, 0x22, 0x1e, 0x00 }, // 47 G
    { 0x22, 0x22, 0x22, 0x3e, 0x22, 0x22, 0x22, 0x00 }, // 48 H
    { 0x1c, 0x08, 0x08, 0x08, 0x08, 0x08, 0x1c, 0x00 }, // 49 I
    { 0x0e, 0x04, 0x04, 0x04, 0x04, 0x24, 0x18, 0x00 }, // 4a J
    { 0x22, 0x24, 0x28, 0x30, 0x28, 0x24, 0x22, 0x00 }, // 4b K
    { 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3e, 0x00 }, // 4c L
    { 0x22, 0x36, 0x2a, 0x2a, 0x22, 0x22, 0x22, 0x00 }, // 4d M
    { 0x22, 0x22, 0x32, 0x2a, 0x26, 0x22, 0x22, 0x00 }, // 4e N
    { 0x1c, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x00 }, // 4f O
    { 0x3c, 0x22, 0x22, 0x3c, 0x20, 0x20, 0x20, 0x00 }, // 50 P
    { 0x1c, 0x22, 0x22, 0x22, 0x2a, 0x24, 0x1a, 0x00 }, // 51 Q
    { 0x3c, 0x22, 0x22, 0x3c, 0x28, 0x24, 0x22, 0x00 }, // 52 R
    { 0x1e, 0x20, 0x20, 0x1c, 0x02, 0x02, 0x3c, 0x00 }, // 53 S
    { 0x3e, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x00 }, // 54 T
    { 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x00 }, // 55 U
    { 0x22, 0x22, 0x22, 0x22, 0x22, 0x14, 0x08, 0x00 }, // 56 V
    { 0x22, 0x22, 0x22, 0x2a, 0x2a, 0x2a, 0x14, 0x00 }, // 57 W
    { 0x22, 0x22, 0x14, 0x08, 0x14, 0x22, 0x22, 0x00 }, // 58 X
    { 0x22, 0x22, 0x22, 0x14, 0x08, 0x08, 0x08, 0x00 }, // 59 Y
    { 0x3e, 0x02, 0x04, 0x08, 0x10, 0x20, 0x3e, 0x00 }, // 5a Z
    { 0x1c, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1c, 0x00 }, // 5b [
    { 0x00, 0x20, 0x10, 0x08, 0x04, 0x02, 0x00, 0x00 }, // 5c \ .
    { 0x1c, 0x04, 0x04, 0x04, 0x04, 0x04, 0x1c, 0x00 }, // 5d ]
    { 0x08, 0x14, 0x22, 0x00, 0x00, 0x00, 0x00, 0x00 }, // 5e ^
    { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3e }, // 5f _
    { 0x10, 0x08, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00 }, // 60 `
    { 0x00, 0x00, 0x1c, 0x02, 0x1e, 0x22, 0x1e, 0x00 }, // 61 a
    { 0x20, 0x20, 0x2c, 0x32, 0x22, 0x22, 0x3c, 0x00 }, // 62 b
    { 0x00, 0x00, 0x1c, 0x20, 0x20, 0x22, 0x1c, 0x00 }, // 63 c
    { 0x02, 0x02, 0x1a, 0x26, 0x22, 0x22, 0x1e, 0x00 }, // 64 d
    { 0x00, 0x00, 0x1c, 0x22, 0x3e, 0x20, 0x1c, 0x00 }, // 65 e
    { 0x0c, 0x12, 0x10, 0x38, 0x10, 0x10, 0x10, 0x00 }, // 66 f
    { 0x00, 0x1e, 0x22, 0x22, 0x1e, 0x02, 0x1c, 0x00 }, // 67 g
    { 0x20, 0x20, 0x2c, 0x32, 0x22, 0x22, 0x22, 0x00 }, // 68 h
    { 0x08, 0x00, 0x18, 0x08, 0x08, 0x08, 0x1c, 0x00 }, // 69 i
    { 0x04, 0x00, 0x0c, 0x04, 0x04, 0x24, 0x18, 0x00 }, // 6a j
    { 0x20, 0x20, 0x24, 0x28, 0x30, 0x28, 0x24, 0x00 }, // 6b k
    { 0x18, 0x08, 0x08, 0x08, 0x08, 0x08, 0x1c, 0x00 }, // 6c l
    { 0x00, 0x00, 0x34, 0x2a, 0x2a, 0x22, 0x22, 0x00 }, // 6d m
    { 0x00, 0x00, 0x2c, 0x32, 0x22, 0x22, 0x22, 0x00 }, // 6e n
    { 0x00, 0x00, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x00 }, // 6f o
    { 0x00, 0x00, 0x3c, 0x22, 0x3c, 0x20, 0x20, 0x00 }, // 70 p
    { 0x00, 0x00, 0x1a, 0x26, 0x1e, 0x02, 0x02, 0x00 }, // 71 q
    { 0x00, 0x00, 0x2c, 0x32, 0x20, 0x20, 0x20, 0x00 }, // 72 r
    { 0x00, 0x00, 0x1c, 0x20, 0x1c, 0x02, 0x3c, 0x00 }, // 73 s
    { 0x10, 0x10, 0x38, 0x10, 0x10, 0x12, 0x0c, 0x00 }, // 74 t
    { 0x00, 0x00, 0x22, 0x22, 0x22, 0x26, 0x1a, 0x00 }, // 75 u
    { 0x00, 0x00, 0x22, 0x22, 0x22, 0x14, 0x08, 0x00 }, // 76 v
    { 0x00, 0x00, 0x22, 0x22, 0x2a, 0x2a, 0x14, 0x00 }, // 77 w
    { 0x00, 0x00, 0x22, 0x14, 0x08, 0x14, 0x22, 0x00 }, // 78 x
    { 0x00, 0x00, 0x22, 0x22, 0x1e, 0x02, 0x1c, 0x00 }, // 79 y
    { 0x00, 0x00, 0x3e, 0x04, 0x08, 0x10, 0x3e, 0x00 }, // 7a z
    { 0x04, 0x08, 0x08, 0x10, 0x08, 0x08, 0x04, 0x00 }, // 7b {
    { 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x00 }, // 7c |
    { 0x10, 0x08, 0x08, 0x04, 0x08, 0x08, 0x10, 0x00 }, // 7d }
    { 0x00, 0x00, 0x10, 0x2a, 0x04, 0x00, 0x00, 0x00 }, // 7e ~
    { 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a } // 7f rubout
};

void draw(void)
{
//	XFillRectangle(dpy, osb, gc, 0, 0, DEFAULTX * g_scale, DEFAULTY * g_scale);
	
    g_flash_countdown--;
    if (g_flash_countdown < 0) {
        g_flash_countdown = g_flash_rate;
        if (g_flashing == 1)
			g_flashing = 0;
		else
			g_flashing = 1;
    }

    int l_pixel_size;
    int l_gr_w;
    int l_gr_h;
    int l_4096;
	unsigned char *mem = mem_driver_buffer();
	int l_video_mode = mem[IOSTART + IO_VIDMODE];
 
    if (l_video_mode >= 8) {
        switch (l_video_mode) {
        case 8: // 40 x 17 text mode
            l_gr_w = 40;
            l_gr_h = 17;
            l_pixel_size = 2;
            break;
        case 9: // 80 x 34 text mode
            l_gr_w = 80;
            l_gr_h = 34;
            l_pixel_size = 1;
            break;
        default: // default to low-res
            l_gr_w = 40;
            l_gr_h = 17;
            l_pixel_size = 4;
            break;
        }
		Pixmap l_charimg;
		l_charimg = XCreatePixmap(dpy, win, l_pixel_size * 6 * g_scale, l_pixel_size * 8 * g_scale, 24);

//		printf("IO_CON_CURSOR %d IO_CON_CURSORH %d IO_CON_CURSORV %d\n", mem[IOSTART + IO_CON_CURSOR], mem[IOSTART + IO_CON_CURSORH], mem[IOSTART + IO_CON_CURSORV]);
		for (int w = 0; w < l_gr_w; ++w) {
			for (int h = 0; h < l_gr_h; ++h) {
				// compute base address and get character/color info out of memory
				uint32_t l_baseaddr = VIDSTART + (h * l_gr_w * 2) + (w * 2);
				uint8_t l_char = mem[l_baseaddr];
				uint8_t l_flash = l_char & 0x80;
				l_char &= 0x7f;
				uint8_t l_color = mem[l_baseaddr + 1] & 0x0f;
				uint8_t l_backcolor = (mem[l_baseaddr + 1] >> 4) & 0x0f;
				if ((mem[IOSTART + IO_CON_CURSOR] >= 0x80) && ((mem[IOSTART + IO_CON_CURSORH] == w) && (mem[IOSTART + IO_CON_CURSORV] == h))) {
					// invert this block.. but don't flash it
//					printf("showing cursor at %d, %d\n", w, h);
					uint8_t l_temp = l_color;
					l_color = l_backcolor;
					l_backcolor = l_temp;
				} else {
					if (g_flashing && l_flash) {
						uint8_t l_temp = l_color;
						l_color = l_backcolor;
						l_backcolor = l_temp;
					}
				}
				// blot out our character stencil with the background color
				XSetForeground(dpy, gc, ((g_standard_colors[l_backcolor][0] * 65536) + (g_standard_colors[l_backcolor][1] * 256) + g_standard_colors[l_backcolor][2]));
				XFillRectangle(dpy, l_charimg, gc, 0, 0, l_pixel_size * 6 * g_scale, l_pixel_size * 8 * g_scale);
				XSetForeground(dpy, gc, ((g_standard_colors[l_color][0] * 65536) + (g_standard_colors[l_color][1] * 256) + g_standard_colors[l_color][2]));
				for (int iy = 0; iy <= 7; ++iy) {
					for (int ix = 0; ix <= 5; ++ix) {
						if (((g_char_rom[l_char][iy] << (ix + 2)) & 0x80) == 0x80) {
							XFillRectangle(dpy, l_charimg, gc, ix * l_pixel_size * g_scale, iy * l_pixel_size * g_scale, l_pixel_size * g_scale, l_pixel_size * g_scale);
						}
					}
				}
				XCopyArea(dpy, l_charimg, osb, gc, 0, 0, l_pixel_size * 6 * g_scale, l_pixel_size * 8 * g_scale, w * l_pixel_size * 6 * g_scale, h * l_pixel_size * 8 * g_scale);
			}
		}
		XFreePixmap(dpy, l_charimg);
    } else {
        switch (l_video_mode) {
        case 0: // 120 x 68, 16 colors, 4k
            l_gr_w = 120;
            l_gr_h = 68;
            l_pixel_size = 8;
            l_4096 = 0;
            break;
        case 1: // 240 x 136, 16 colors, 16k
            l_gr_w = 240;
            l_gr_h = 136;
            l_pixel_size = 4;
            l_4096 = 0;
            break;
        case 2: // 480 x 272, 16 colors, 64k
            l_gr_w = 480;
            l_gr_h = 272;
            l_pixel_size = 2;
            l_4096 = 0;
            break;
        case 4: // 120 x 68, 4096 colors, 16k
            l_gr_w = 120;
            l_gr_h = 68;
            l_pixel_size = 8;
            l_4096 = 1;
            break;
        case 5: // 240 x 136, 4096 colors, 64k
            l_gr_w = 240;
            l_gr_h = 136;
            l_pixel_size = 4;
            l_4096 = 1;
            break;
        case 6: // 480 x 272, 4096 colors, 256k
            l_gr_w = 480;
            l_gr_h = 272;
            l_pixel_size = 2;
            l_4096 = 1;
            break;
        default: // anything we don't recognize behaves as mode 0
            l_gr_w = 120;
            l_gr_h = 68;
            l_pixel_size = 8;
            l_4096 = 0;
            break;
        }
        for (int w = 0; w < l_gr_w; ++w) {
            for (int h = 0; h < l_gr_h; ++h) {
                uint8_t l_pix_l, l_pix_h;
                uint8_t l_pix_red, l_pix_green, l_pix_blue;
               if (l_4096 == 1) {
                    l_pix_l = mem[VIDSTART + (h * (l_gr_w * 2)) + (w * 2)];
                    l_pix_h = mem[VIDSTART + (h * (l_gr_w * 2)) + (w * 2) + 1];
                    l_pix_red = ((l_pix_h & 0b00001111) << 4) + (l_pix_h & 0b00001111);
                    l_pix_green = (l_pix_l & 0b11110000) + ((l_pix_l & 0b11110000) >> 4);
                    l_pix_blue = ((l_pix_l & 0b00001111) << 4) + (l_pix_l & 0b00001111);
                } else {
                    l_pix_l = mem[VIDSTART + (h * (l_gr_w / 2)) + (w >> 1)];
                   if (w % 2) {
                        l_pix_l &= 0x0f;
				   } else {
                        l_pix_l >>= 4;
				   }
					l_pix_red = g_standard_colors[l_pix_l][0];
					l_pix_green = g_standard_colors[l_pix_l][1];
					l_pix_blue = g_standard_colors[l_pix_l][2];
                }
				XSetForeground(dpy, gc, ((l_pix_red * 65536) + (l_pix_green * 256) + l_pix_blue));
				int l_adj_w = w * l_pixel_size * g_scale;
				int l_adj_h = h * l_pixel_size * g_scale;
				int l_adj_w2 = l_adj_w + (l_pixel_size * g_scale);
				int l_adj_h2 = l_adj_h + (l_pixel_size * g_scale);
				XFillRectangle(dpy, osb, gc, l_adj_w, l_adj_h, l_adj_w2, l_adj_h2);
            }
        }
    }
	
	XFlush(dpy);
}

void redraw(void)
{
	XCopyArea(dpy, osb, win, gc, 0, 0, DEFAULTX * g_scale, DEFAULTY * g_scale, 0, 0);
}

void load_server(char *path)
{
	int pid = fork();
	if (pid == 0) {
		char *execargs[1] = { NULL };
		int success = execvp(path, execargs);
		if (success < 0) {
			fprintf(stderr, "exec of server binary failed. errno=%d (%s)\n", errno, strerror(errno));
			exit(-1);
		}
	}
}

int main(int argc, char **argv)
{
	int opt;
	while ((opt = getopt_long(argc, argv, "s:e:", g_options, NULL)) != -1) {
		switch (opt) {
		case 's':
			g_scale = atoi(optarg);
			break;
		case 'e':
			load_server(optarg);
			break;
		}
	}
	
	// sanity check the scale
	if ((g_scale < 1) || (g_scale > 8)) {
		fprintf(stderr, "scale value must be between 1-8.\n");
		exit(-1);
	}
	
	printf("starting up memory and io driver..\n");
	mem_driver_startup();
	io_driver_startup();
	printf("started up memory driver, shmid = %d buffer = %016llX\n", mem_driver_shmid(), (long long)mem_driver_buffer());
	
	// init keypress queue
	unsigned char *mem = mem_driver_buffer();
	mem[IOSTART + IO_KEYQ_SIZE] = 0;
	mem[IOSTART + IO_KEYQ_WAITING] = 0;
	char keyq[256];
	unsigned char keyq_size = 0;
	
	// start up X
	int runFlag=1;
	int ShiftState = 0, ControlState = 0, AltState = 0;
	dpy = XOpenDisplay(0);
	assert(dpy);

	blackColor = BlackPixel(dpy, DefaultScreen(dpy));
	whiteColor = WhitePixel(dpy, DefaultScreen(dpy));

	printf("Creating window...\n");
	win = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 0, 0, DEFAULTX * g_scale, DEFAULTY * g_scale, 0, blackColor, blackColor);

	// constrict window to set size
	XSizeHints sizehints;
	sizehints.flags = PSize | PMinSize | PMaxSize;
	sizehints.min_width = DEFAULTX * g_scale;
	sizehints.max_width = DEFAULTX * g_scale;
	sizehints.min_height = DEFAULTY * g_scale;
	sizehints.max_height = DEFAULTY * g_scale;
	XSetWMNormalHints(dpy, win, &sizehints);

	// we want to get MapNotify events
	XSelectInput(dpy, win, StructureNotifyMask | ExposureMask | ButtonPressMask | PointerMotionMask | KeyPressMask | KeyReleaseMask | ButtonReleaseMask);

	// create off-screen bitmap
	osb = XCreatePixmap(dpy, win, DEFAULTX * g_scale, DEFAULTY * g_scale, 24);
	
	Atom wm_delete = XInternAtom(dpy, "WM_DELETE_WINDOW", 1);
	XSetWMProtocols(dpy, win, &wm_delete, 1);

	// set the window's title
	XStoreName(dpy, win, "IML Console");
	
	struct timespec ts;
	io_message_t msg;
	// wait indefinitely for SERVERALIVE. Nothing to do if the server isn't there
	printf("waiting for server to appear...\n");
	while (io_driver_wait_forward(&msg) == -1) {
		ts.tv_sec = 0;
		ts.tv_nsec = 20000000; // 20ms
		nanosleep(&ts, NULL);
	}
	if (msg.address != IO_CMD_SERVERALIVE) {
		fprintf(stderr, "expected IO_CMD_SERVERALIVE from server!\n");
		exit(-1);
	}
	// send CLIENTALIVE
	io_driver_post_backchannel(IO_CMD_CLIENTALIVE, 0);
	
	// "map" the window (make it appear)
	printf("Mapping window...\n");
	XMapWindow(dpy, win);

	gc = XCreateGC(dpy, osb, 0, 0);

	// wait for window to get mapped
	for(;;)
	{
		XEvent e;
		XNextEvent(dpy, &e);
		if (e.type == MapNotify)
			break;
	}

	draw();
	redraw();
		
	// wait for an event
	int x11_fd = ConnectionNumber(dpy);
	fd_set in_fds;
	
	while (runFlag == 1)
	{
		FD_ZERO(&in_fds);
		FD_SET(x11_fd, &in_fds);

        // Set our timer.  1/30th of a second
		struct timeval tv;
		tv.tv_usec = 33000;
		tv.tv_sec = 0;

		// Wait for X Event or a Timer
		int num_ready_fds = select(x11_fd + 1, &in_fds, NULL, NULL, &tv);
		if (num_ready_fds > 0) {
//			printf("Event Received!\n");
		} else if (num_ready_fds == 0) {
			// Handle timer here
//			printf("33ms timeout\n");
			// respond to message queue
			while (io_driver_wait_forward(&msg) != -1) {
				if (msg.address == IO_VIDMODE) {
					// we read our vidmode right out of softswitches now
//					printf("IO_VIDMODE\n");
				}
				if (msg.address == IO_CMD_SERVERDEAD) {
					printf("server died!\n");
					break;
				}
				if (msg.address == IO_KEYQ_CLEAR) {
					keyq_size = 0;
					mem[IOSTART + IO_KEYQ_SIZE] = 0;
					mem[IOSTART + IO_KEYQ_WAITING] = 0;
				}
				if (msg.address == IO_KEYQ_DEQUEUE) {
					if (keyq_size >= 2) {
						for (int i = 1; i <= keyq_size; i++)
							keyq[i - 1] = keyq[i];
						keyq_size--;
					} else if (keyq_size == 1) {
						keyq_size = 0;
					}
					mem[IOSTART + IO_KEYQ_SIZE] = keyq_size;
					printf("DEQUEUE: IO_KEYQ_SIZE = %d\n", keyq_size);
					if (keyq_size > 0)
						mem[IOSTART + IO_KEYQ_WAITING] = keyq[0];
					else
						mem[IOSTART + IO_KEYQ_WAITING] = 0;
				}
				if (msg.address == IO_CON_REGISTER) {
					// stick IO_CON_CHAROUT on the screen
				}
				if (msg.address == IO_CON_CLS) {
					// clear the text screen
					uint8_t l_w;
					uint8_t l_h;
					if (mem[IOSTART + IO_VIDMODE] == 0x08) {
						l_w = 40;
						l_h = 17;
					} else if (mem[IOSTART + IO_VIDMODE] == 0x09) {
						l_w = 80;
						l_h = 34;
					} else {
						// not in either of the text modes, so do nothing
						l_w = 0;
						l_h = 0;
					}
					for (unsigned int h = 0; h < l_h; ++h) {
						for (unsigned int w = 0; w < l_w; ++w) {
							mem[VIDSTART + (h * l_w * 2) + (w * 2)] = mem[IOSTART + IO_CON_CHAROUT];
							mem[VIDSTART + (h * l_w * 2) + (w * 2) + 1] = mem[IOSTART + IO_CON_COLOR];
						}
					}
				}
				if (msg.address == IO_CON_CR) {
					// print a carriage return
				}
			}
			draw();
			redraw();
		} else {
			fprintf(stderr, "An error occured with X fd_set timeout mechanism.\n");
		}
		
		while (XPending(dpy)) {
			XEvent e;
			XNextEvent(dpy, &e);
			//KeySym key_symbol = XKeycodeToKeysym(dpy, e.xkey.keycode, 0);
			KeySym key_symbol;
			char xlat[10];
			if ((e.type == KeyPress) || (e.type == KeyRelease))
				XLookupString(&e.xkey, xlat, 10, &key_symbol, NULL);

			switch(e.type)
			{
				case ConfigureNotify:
					printf("ConfigureNotify event\n");
					break;
				case Expose:
					redraw();
					printf("Expose event\n");
					break;
				case KeyPress:
					switch(key_symbol) {
						case XK_Shift_L:
						case XK_Shift_R:
							ShiftState = 1;
							break;
						case XK_Control_L:
						case XK_Control_R:
							ControlState = 1;
							break;
						case XK_Alt_L:
						case XK_Alt_R:
							AltState = 1;
							break;
						default:
							printf("Key: %04X ShiftState: %d ControlState: %d AltState: %d XLookupString '%s' (0x%02X)\n", (unsigned int)key_symbol, ShiftState, ControlState, AltState, xlat, xlat[0]);
							keyq[keyq_size++] = xlat[0];
							mem[IOSTART + IO_KEYQ_SIZE] = keyq_size;
							mem[IOSTART + IO_KEYQ_WAITING] = keyq[0];
							break;
					}
					break;
				case KeyRelease:
					switch(key_symbol) {
						case XK_Shift_L:
						case XK_Shift_R:
							ShiftState = 0;
							break;
						case XK_Control_L:
						case XK_Control_R:
							ControlState = 0;
							break;
						case XK_Alt_L:
						case XK_Alt_R:
							AltState = 0;
							break;
					}
					break;
				case ButtonPress:
					printf("Button %d at: X%d, Y%d\n",e.xbutton.button,e.xbutton.x,e.xbutton.y);
					break;
				case ClientMessage:
					char *str = XGetAtomName(dpy,e.xclient.message_type);
//					printf("ClientMessage: %s\n",str);
					if (!strcmp(str,"WM_PROTOCOLS"))
						runFlag = 0;
					XFree(str);
					break;
			}
		}
	}

	printf("Shutting down X Windows...\n");
	XFreePixmap(dpy, osb);
	XFreeGC(dpy, gc);
	XCloseDisplay(dpy);
	io_driver_post_backchannel(IO_CMD_CLIENTDEAD, 0);
	printf("shutting down memory driver...\n");
	mem_driver_shutdown();

	return 0;
}