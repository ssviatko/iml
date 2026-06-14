#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>

int g_width = 960;
int g_height = 544;
int g_scale = 2;

int main(int argc, char **argv)
{
    srand(time(NULL));

    Display *dpy;
    XVisualInfo vinfo;
    int depth;
    XVisualInfo *visual_list;
    XVisualInfo visual_template;
    int nxvisuals;
    int i;
    XSetWindowAttributes attrs;
    Window parent;
    Visual *visual;

    Window win;
    int *framebuf;
    XImage *ximage;
    XEvent event;

    dpy = XOpenDisplay(NULL);

    nxvisuals = 0;
    visual_template.screen = DefaultScreen(dpy);
    visual_list = XGetVisualInfo (dpy, VisualScreenMask, &visual_template, &nxvisuals);

    if (!XMatchVisualInfo(dpy, XDefaultScreen(dpy), 24, TrueColor, &vinfo))
    {
        fprintf(stderr, "no such visual\n");
        return 1;
    }

    parent = XDefaultRootWindow(dpy);

    XSync(dpy, True);

    printf("creating RGBA child\n");

    visual = vinfo.visual;
    depth = vinfo.depth;

    attrs.colormap = XCreateColormap(dpy, XDefaultRootWindow(dpy), visual, AllocNone);
    attrs.background_pixel = 0;
    attrs.border_pixel = 0;

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

    ximage = XCreateImage(dpy, vinfo.visual, depth, ZPixmap, 0, (char *)framebuf, g_width, g_height, 8, g_width * 4);

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

    int runFlag = 1;
    while (runFlag == 1) {

        struct timespec l_frame_ts;
        l_frame_ts.tv_nsec = 33000000;
        l_frame_ts.tv_sec = 0;
        nanosleep(&l_frame_ts, NULL);

        // randomize the screen
        for (i = 0; i < (g_width * g_height); i++)
        {
            framebuf[i] = rand();
            framebuf[i] |= 0xff000000;
        }

        XPutImage(dpy, win, NormalGC, ximage, 0, 0, 0, 0, g_width, g_height);

        while (XPending(dpy)) {
            XNextEvent(dpy, &event);
            switch(event.type) {
            case Expose:
                printf("I have been exposed!\n");
                XPutImage(dpy, win, NormalGC, ximage, 0, 0, 0, 0, g_width, g_height);
                break;
            case ClientMessage:
                char *str = XGetAtomName(dpy, event.xclient.message_type);
                printf("ClientMessage: %s\n",str);
                if (!strcmp(str,"WM_PROTOCOLS")) {
                    runFlag = 0;
                    XFree(str);
                }
                break;
            }
        }
    }

    printf("Exiting...\n");

    return 0;
}

