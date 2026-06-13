// Source - https://stackoverflow.com/a/64758878
// Posted by AtomClock
// Retrieved 2026-06-13, License - CC BY-SA 4.0

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>

int main(int argc, char **argv)
{
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

    //Change to this line
    //if (!XMatchVisualInfo(dpy, XDefaultScreen(dpy), 32, TrueColor, &vinfo))
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

    width = 1000;
    height = 700;

    framebuf = (int *) malloc((width*height)*4);

    for (i = 0; i < (width*height); i++)
    {
        framebuf[i] = 0xFF00FFFF;
    }

    win = XCreateWindow(dpy, parent, 100, 100, width, height, 0, depth, InputOutput,
                        visual, CWBackPixel | CWColormap | CWBorderPixel, &attrs);

    //Change to this line
    //ximage = XCreateImage(dpy, vinfo.visual, 32, XYPixmap, 0, (char *)framebuf, width, height, 8, width*4);
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

    //gcm = GCForeground | GCBackground | GCGraphicsExposures;
    //gcv.foreground = BlackPixel(dpy, parent);
    //gcv.background = WhitePixel(dpy, parent);
    gcm = GCGraphicsExposures;
    gcv.graphics_exposures = 0;
    NormalGC = XCreateGC(dpy, parent, gcm, &gcv);

    XMapWindow(dpy, win);

    while(!XNextEvent(dpy, &event))
    {
        switch(event.type)
        {
        case Expose:
            printf("I have been exposed!\n");
            XPutImage(dpy, win, NormalGC, ximage, 0, 0, 0, 0, width, height);
            break;
        }
    }

    printf("No error\n");

    return 0;
}

