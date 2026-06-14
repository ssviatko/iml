#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <sys/time.h>
#include <stdint.h>
#include <getopt.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#define DEFAULTX 480
#define DEFAULTY 272

struct option g_options[] = {
    { "scale", required_argument, NULL, 's' },
    { "exec", required_argument, NULL, 'e' },
    { NULL, 0, NULL, 0 }
};

unsigned int g_width = DEFAULTX;
unsigned int g_height = DEFAULTY;
unsigned int g_scale = 1;
uint64_t g_frames = 0;

const uint32_t g_standard_colors[16] = {
    0xff000000, // Black
    0xffdd0033, // Deep Red
    0xff000099, // Dark Blue
    0xffdd22dd, // Purple
    0xff007722, // Dark Green
    0xff555555, // Dark Gray
    0xff2222ff, // Medium Blue
    0xff66aaff, // Light Blue
    0xff885500, // Brown
    0xffff6600, // Orange
    0xffaaaaaa, // Light Gray
    0xffff9988, // Pink
    0xff11dd00, // Light Green
    0xffffff00, // Yellow
    0xff44ff99, // Aquamarine
    0xffffffff  // White
};

int main(int argc, char **argv)
{
    int i;
    srand(time(NULL));
    int opt;
    while ((opt = getopt_long(argc, argv, "s:e:", g_options, NULL)) != -1) {
        switch (opt) {
            case 's':
                g_scale = atoi(optarg);
                break;
            case 'e':
//                load_server(optarg);
                break;
        }
    }

    // sanity check the scale
    if ((g_scale < 1) || (g_scale > 8)) {
        fprintf(stderr, "fconsole: scale value must be between 1-8.\n");
        exit(-1);
    }

    // set height/g_width
    g_width = DEFAULTX * g_scale;
    g_height = DEFAULTY * g_scale;
    printf("fconsole: selecting %dx%d window (scale %d)\n", g_width, g_height, g_scale);

    Display *dpy;
    XSetWindowAttributes attrs;
    Window parent;
    Window win;

    dpy = XOpenDisplay(NULL);

    XVisualInfo vinfo;
    if (!XMatchVisualInfo(dpy, XDefaultScreen(dpy), 24, TrueColor, &vinfo))
    {
        fprintf(stderr, "fconsole: no such visual\n");
        return 1;
    }

    parent = XDefaultRootWindow(dpy);

    XSync(dpy, True);

    printf("fconsole: creating frame buffer...\n");

    Visual *visual;
    visual = vinfo.visual;

    int depth;
    depth = vinfo.depth;

    attrs.colormap = XCreateColormap(dpy, XDefaultRootWindow(dpy), visual, AllocNone);
    attrs.background_pixel = 0;
    attrs.border_pixel = 0;

    int *framebuf;
    framebuf = (int *) malloc((g_width * g_height) * 4);

    for (i = 0; i < (g_width * g_height); i++)
    {
        framebuf[i] = 0xff7f00ff;
    }

    win = XCreateWindow(dpy, parent, 100, 100, g_width, g_height, 0, depth, InputOutput,
                        visual, CWBackPixel | CWColormap | CWBorderPixel, &attrs);

    // constrict window to set size
    XSizeHints sizehints;
    sizehints.flags = PSize | PMinSize | PMaxSize;
    sizehints.min_width = g_width;
    sizehints.max_width = g_width;
    sizehints.min_height = g_height;
    sizehints.max_height = g_height;
    XSetWMNormalHints(dpy, win, &sizehints);

    XImage *ximage = XCreateImage(dpy, vinfo.visual, depth, ZPixmap, 0, (char *)framebuf, g_width, g_height, 8, g_width * 4);

    if (ximage == 0)
    {
        printf("ximage is null!\n");
    }

    XSync(dpy, True);

    XSelectInput(dpy, win, ExposureMask | KeyPressMask);

    Atom wm_delete = XInternAtom(dpy, "WM_DELETE_WINDOW", 1);
    XSetWMProtocols(dpy, win, &wm_delete, 1);

    // set the window's title
    XStoreName(dpy, win, "Random Noise Console");

    XGCValues gcv;
    unsigned long gcm;
    GC NormalGC;

    gcm = GCGraphicsExposures;
    gcv.graphics_exposures = 0;
    NormalGC = XCreateGC(dpy, parent, gcm, &gcv);

    XMapWindow(dpy, win);

    // keep track of our FPS in case we're on a slow machine
    struct timeval start_time;
    struct timeval end_time;
    gettimeofday(&start_time, NULL);

    XEvent event;
    int runFlag = 1;
    while (runFlag == 1) {

        struct timespec l_frame_ts;
        // cap at 120 frames per second to prevent 100% cpu usage
        l_frame_ts.tv_nsec = 8000000;
        l_frame_ts.tv_sec = 0;
        nanosleep(&l_frame_ts, NULL);

        // randomize the screen
        for (i = 0; i < (g_width * g_height); i++)
        {
            framebuf[i] = rand();
            framebuf[i] |= 0xff000000;
        }

        XPutImage(dpy, win, NormalGC, ximage, 0, 0, 0, 0, g_width, g_height);
        g_frames++;

        while (XPending(dpy)) {
            XNextEvent(dpy, &event);
            switch(event.type) {
            case Expose:
//                printf("I have been exposed!\n");
                XPutImage(dpy, win, NormalGC, ximage, 0, 0, 0, 0, g_width, g_height);
                g_frames++;
                break;
            case ClientMessage:
                char *str = XGetAtomName(dpy, event.xclient.message_type);
//                printf("ClientMessage: %s\n",str);
                if (!strcmp(str,"WM_PROTOCOLS")) {
                    runFlag = 0;
                    XFree(str);
                }
                break;
            }
        }
    }

    gettimeofday(&end_time, NULL);
    long elapsed_secs = end_time.tv_sec - start_time.tv_sec - ((end_time.tv_usec - start_time.tv_usec < 0) ? 1 : 0); // subtract 1 if there was a usec rollover
    long elapsed_usecs = end_time.tv_usec - start_time.tv_usec + ((end_time.tv_usec - start_time.tv_usec < 0) ? 1000000 : 0); // bump usecs by 1 million usec for rollover
    printf("fconsole: %ld frames displayed in %ld seconds %ld usecs.\n", g_frames, elapsed_secs, elapsed_usecs);
    printf("fconsole: estimated console FPS: %f\n", (double)g_frames / ((double)elapsed_secs + (double)(elapsed_usecs / 1000000.0)));

    printf("fconsole: exiting...\n");

    return 0;
}

