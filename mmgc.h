/*
*
* Memory Mapped Graphics Console
*
* An offshoot of the IML project
* For stand alone apps that would like to use the IML
* console for its graphics and text capabilities.
*
*/

#include <X11/Xlib.h>
#include <X11/keysym.h> // for Keysym stuff
#include <X11/Xutil.h> // for XLookupString
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdarg.h>
#include <pthread.h>

typedef enum {
	ERROR_NONE = 0,
	ERROR_CLOSE_REQUESTED,
	ERROR_KEY_WAITING
} mmgc_error;

mmgc_error mmgc_startup(uint32_t a_scale, char *a_title);
mmgc_error mmgc_close_requested();
mmgc_error mmgc_shutdown();
mmgc_error mmgc_draw();
mmgc_error mmgc_redraw();
void mmgc_flush();
char *mmgc_mem();
void mmgc_con_cls(uint8_t a_charout, uint8_t a_color);
void mmgc_con_cr();
void mmgc_con_color(uint8_t a_color);
void mmgc_con_color_default();
void mmgc_puts(char *a_str);
void mmgc_printf(const char *fmt, ...);
void mmgc_putc(uint8_t a_char);
mmgc_error mmgc_key_waiting();
uint8_t mmgc_key_retrieve();
uint8_t mmgc_getc();
void mmgc_vidmode(uint8_t a_mode);
