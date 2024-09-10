#include <X11/Xlib.h>
#include <X11/keysym.h> // for Keysym stuff
#include <X11/Xutil.h> // for XLookupString
#include <assert.h>
#include <stdio.h>
#include <signal.h>
#include <time.h>

#include "mem_driver.h"
#include "io_driver.h"

// X globals
Display *dpy;
int blackColor, whiteColor;
Window w;
GC gc;
Pixmap osb;

void ctrlc()
{
	printf("shutting down memory driver...\n");
	mem_driver_shutdown();
	// send CLIENTDEAD
	io_message_t msg;
	msg.address = IO_CMD_CLIENTDEAD;
	msg.byte = 0;
	io_driver_post_backchannel(&msg);
	exit(0);
}

void draw(void)
{
	XFillRectangle(dpy, osb, gc, 0, 0, 640, 480);
	
	for (int i=0; i<256; i++)
	{
		XSetForeground(dpy, gc, i*256);
		XDrawPoint(dpy, osb, gc, i+20, 80);
		XDrawLine(dpy, osb, gc, i+20, 85, i+20, 100);
	}
	for (int i=0; i<131072; i++)
	{
		XSetForeground(dpy, gc, i);
		XDrawPoint(dpy, osb, gc, 20+(i%512), 120+(i/512));
	}
	XSetForeground(dpy, gc, whiteColor);
	XDrawLine(dpy, osb, gc, 10, 60, 180, 20);

//	char xds[80];
//	for (int i=0; i<5; i++) {
//		sprintf(xds,"Hello, World! Number %d",i);
//		//printf("Drawing %s\n",xds);
//		XDrawString(dpy, osb, gc, 20, 135+(i*14), xds, strlen(xds));
//	}
	XFlush(dpy);
}

void redraw(void)
{
	XCopyArea(dpy, osb, w, gc, 0, 0, 640, 480, 0, 0);
}

int main(int argc, char **argv)
{
	// handle SIGINT
	struct sigaction sa;
	sa.sa_handler = ctrlc;
	sigemptyset(&sa.sa_mask);
	sigaddset(&sa.sa_mask, SIGINT);
	sa.sa_flags = 0;
	if (sigaction(SIGINT, &sa, NULL) < 0) {
		fprintf(stderr, "fatal error: can't catch SIGINT");
		exit(-1);
	}

	// start up X
	int runFlag=1;
	int ShiftState = 0, ControlState = 0, AltState = 0;
	dpy = XOpenDisplay(0);
	assert(dpy);

	blackColor = BlackPixel(dpy, DefaultScreen(dpy));
	whiteColor = WhitePixel(dpy, DefaultScreen(dpy));

	printf("Creating window...\n");
	w = XCreateSimpleWindow(dpy, DefaultRootWindow(dpy), 0, 0, 640, 480, 0, blackColor, blackColor);

	// constrict window to set size
	XSizeHints sizehints;
	sizehints.flags=PSize|PMinSize|PMaxSize;
	sizehints.min_width=640;
	sizehints.max_width=640;
	sizehints.min_height=480;
	sizehints.max_height=480;
	XSetWMNormalHints(dpy,w,&sizehints);

	// we want to get MapNotify events
	XSelectInput(dpy, w, StructureNotifyMask | ExposureMask | ButtonPressMask | PointerMotionMask | KeyPressMask | KeyReleaseMask | ButtonReleaseMask);

	// create off-screen bitmap
	osb = XCreatePixmap(dpy, w, 640, 480, 24);
	
	Atom wm_delete = XInternAtom(dpy, "WM_DELETE_WINDOW", 1);
	XSetWMProtocols(dpy, w, &wm_delete, 1);

	// set the window's title
	XStoreName(dpy, w, "IML Console");
	
	// "map" the window (make it appear)
	printf("Mapping window...\n");
	XMapWindow(dpy, w);

	gc = XCreateGC(dpy, osb, 0, 0);

	// wait for window to get mapped
	for(;;)
	{
		XEvent e;
		XNextEvent(dpy, &e);
		if (e.type == MapNotify)
			break;
	}

	printf("starting up memory and io driver..\n");
	mem_driver_startup();
	io_driver_startup();
	printf("started up memory driver, shmid = %d buffer = %016llX\n", mem_driver_shmid(), (long long)mem_driver_buffer());
	
	struct timespec ts;
	io_message_t msg;
	// wait indefinitely for SERVERALIVE. Nothing to do if the server isn't there
//	printf("waiting for server to appear...\n");
//	while (io_driver_wait_forward(&msg) == -1) {
//		ts.tv_sec = 0;
//		ts.tv_nsec = 20000000; // 20ms
//		nanosleep(&ts, NULL);
//	}
//	if (msg.address != IO_CMD_SERVERALIVE) {
//		fprintf(stderr, "expected IO_CMD_SERVERALIVE from server!\n");
//		exit(-1);
//	}
	// send CLIENTALIVE
	msg.address = IO_CMD_CLIENTALIVE;
	msg.byte = 0;
	io_driver_post_backchannel(&msg);
	
	// retrieve commands from server
//	while (1) {
//		printf("waiting for command from server...\n");
//		while (io_driver_wait_forward(&msg) == -1) {
//			ts.tv_sec = 0;
//			ts.tv_nsec = 20000000; // 20ms
//			nanosleep(&ts, NULL);
//		}
//		printf("received %04X/%02X from server.\n", msg.address, msg.byte);
//		if (msg.address == IO_CMD_SERVERDEAD) {
//			printf("server died!\n");
//			break;
//		}
//		unsigned char *mem = (unsigned char *)mem_driver_buffer();
//		printf("video: %02X %02X %02X %02X %02X %02X\n", mem[VIDSTART + 0], mem[VIDSTART + 1], mem[VIDSTART + 2],
//			mem[VIDSTART + 3], mem[VIDSTART + 4], mem[VIDSTART + 5]);
//	}
	
	draw();
	redraw();
		
	// wait for an event
	while (runFlag == 1)
	{
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
					printf("Key: %04X ShiftState: %d ControlState: %d AltState: %d XLookupString '%s' (0x%02X)\n",key_symbol, ShiftState, ControlState, AltState, xlat, xlat[0]);
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
				printf("ClientMessage: %s\n",str);
				if (!strcmp(str,"WM_PROTOCOLS"))
					runFlag = 0;
				XFree(str);
				break;
		}
	}

	printf("Freeing resources...\n");
	XFreePixmap(dpy, osb);
	XFreeGC(dpy, gc);
	XCloseDisplay(dpy);
	printf("shutting down memory driver...\n");
	mem_driver_shutdown();

	return 0;
}