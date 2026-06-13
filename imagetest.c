// Source - https://stackoverflow.com/a/64758878
// Posted by AtomClock
// Retrieved 2026-06-13, License - CC BY-SA 4.0

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>

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

    int width, height;
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

    width = 960;
    height = 544;

    framebuf = (int *) malloc((width*height)*4);

    for (i = 0; i < (width*height); i++)
    {
        framebuf[i] = 0xff7f00ff;
    }

    win = XCreateWindow(dpy, parent, 100, 100, width, height, 0, depth, InputOutput,
                        visual, CWBackPixel | CWColormap | CWBorderPixel, &attrs);

    ximage = XCreateImage(dpy, vinfo.visual, depth, ZPixmap, 0, (char *)framebuf, width, height, 8, width*4);

    if (ximage == 0)
    {
        printf("ximage is null!\n");
    }

    XSync(dpy, True);

    XSelectInput(dpy, win, ExposureMask | KeyPressMask);

    XGCValues gcv;
    unsigned long gcm;
    GC NormalGC;

    gcm = GCGraphicsExposures;
    gcv.graphics_exposures = 0;
    NormalGC = XCreateGC(dpy, parent, gcm, &gcv);

    XMapWindow(dpy, win);

    int runflag = 1;
    while (runflag == 1) {

        struct timespec l_frame_ts;
        l_frame_ts.tv_nsec = 33000000;
        l_frame_ts.tv_sec = 0;
        nanosleep(&l_frame_ts, NULL);

        // randomize the screen
        for (i = 0; i < (width*height); i++)
        {
            framebuf[i] = rand();
            framebuf[i] |= 0xff000000;
        }

        XPutImage(dpy, win, NormalGC, ximage, 0, 0, 0, 0, width, height);

        while (XPending(dpy)) {
            XNextEvent(dpy, &event);
            switch(event.type)
            {
            case Expose:
                printf("I have been exposed!\n");
                XPutImage(dpy, win, NormalGC, ximage, 0, 0, 0, 0, width, height);
                break;
            }
        }
    }

    printf("No error\n");

    return 0;
}

