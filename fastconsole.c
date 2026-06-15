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

#include "memio_driver.h"
#include "char_rom.h"

#define DEFAULTX 480
#define DEFAULTY 272

struct option g_options[] = {
    { "scale", required_argument, NULL, 's' },
    { "exec", required_argument, NULL, 'e' },
    { NULL, 0, NULL, 0 }
};

unsigned int g_width = DEFAULTX;
unsigned int g_height = DEFAULTY;
unsigned int g_scale = 2;
int *framebuf;
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

void load_server(char *path)
{
    int pid = fork();
    if (pid == 0) {
        char *execargs[1] = { NULL };
        int success = execvp(path, execargs);
        if (success < 0) {
            fprintf(stderr, "fconsole: exec of server binary failed. errno=%d (%s)\n", errno, strerror(errno));
            exit(-1);
        }
        // don't clutter the screen
        close(0);
        close(1);
        close(2);
    }
}

void draw_text(unsigned int a_cols, unsigned int a_rows, unsigned int a_scale)
{
    unsigned char *mem = mem_driver_buffer();
    uint32_t l_baseaddr = VIDSTART;
    for (unsigned int cur_row = 0; cur_row < a_rows; ++cur_row) {
        for (unsigned int cur_col = 0; cur_col < a_cols; ++cur_col) {
            uint32_t l_framebase = (cur_col * a_scale * 6) + (cur_row * a_scale * 8 * g_width);
            uint8_t l_char = mem[l_baseaddr];
            uint8_t l_color = mem[l_baseaddr + 1] & 0x0f;
            uint8_t l_backcolor = (mem[l_baseaddr + 1] >> 4) & 0x0f;
            l_baseaddr += 2;
            if ((mem[IOSTART + IO_CON_CURSOR] >= 0x80) && ((mem[IOSTART + IO_CON_CURSORH] == cur_col) && (mem[IOSTART + IO_CON_CURSORV] == cur_row))) {
                // invert this block if it's the cursor'
                uint8_t l_temp = l_color;
                l_color = l_backcolor;
                l_backcolor = l_temp;
            }
//            printf("cur_row=%d cur_col=%d a_scale=%d l_framebase %d l_char=%02X\n", cur_row, cur_col, a_scale, l_framebase, l_char);
            for (unsigned int iy = 0; iy <= 7; ++iy) {
                for (unsigned int ix = 0; ix <= 5; ++ix) {
                    if (((g_char_rom[l_char][iy] << (ix + 2)) & 0x80) == 0x80) {
                        // color in character body
                        for (unsigned int scalecounth = 0; scalecounth < a_scale; ++scalecounth) {
                            for (unsigned int scalecountv = 0; scalecountv < a_scale; ++scalecountv) {
                                framebuf[(l_framebase + (ix * a_scale) + (iy * a_scale * g_width)) + (scalecountv * g_width) + scalecounth] = g_standard_colors[l_color];
                            }
                        }
                    } else {
                        // color in background color
                        for (unsigned int scalecounth = 0; scalecounth < a_scale; ++scalecounth) {
                            for (unsigned int scalecountv = 0; scalecountv < a_scale; ++scalecountv) {
                                framebuf[(l_framebase + (ix * a_scale) + (iy * a_scale * g_width)) + (scalecountv * g_width) + scalecounth] = g_standard_colors[l_backcolor];
                            }
                        }
                    }
                }
            }
        }
    }
}

void draw()
{
    unsigned char *mem = mem_driver_buffer();
    int l_video_mode = mem[IOSTART + IO_VIDMODE];
    switch(l_video_mode) {
        case 8:
            draw_text(40, 17, g_scale * 2);
            break;
        case 9:
            draw_text(80, 34, g_scale * 1);
            break;
        default:
            break;
    }
}

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
                load_server(optarg);
                break;
        }
    }

    // sanity check the scale
    if ((g_scale <2) || (g_scale > 8)) {
        fprintf(stderr, "fconsole: scale value must be between 1-8.\n");
        exit(-1);
    }

    // set height/g_width
    g_width = DEFAULTX * g_scale;
    g_height = DEFAULTY * g_scale;
    printf("fconsole: selecting %dx%d window (scale %d)\n", g_width, g_height, g_scale);

    printf("fconsole: starting up memory and io driver..\n");
    mem_driver_startup();
    io_driver_startup();
    printf("fconsole: started up memory driver, shmid = %d buffer = %016llX\n", mem_driver_shmid(), (long long)mem_driver_buffer());

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

    framebuf = (int *) malloc((g_width * g_height) * 4);

    // clear frame buffer to black
    for (i = 0; i < (g_width * g_height); i++)
    {
        framebuf[i] = 0xff000000;
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

    // we want to get MapNotify events
    XSelectInput(dpy, win, StructureNotifyMask | ExposureMask | ButtonPressMask | PointerMotionMask | KeyPressMask | KeyReleaseMask | ButtonReleaseMask);

    Atom wm_delete = XInternAtom(dpy, "WM_DELETE_WINDOW", 1);
    XSetWMProtocols(dpy, win, &wm_delete, 1);

    // set the window's title
    XStoreName(dpy, win, "IML Fast Console");

    struct timespec ts;
    io_message_t msg;
    // wait indefinitely for SERVERALIVE. Nothing to do if the server isn't there
    printf("fconsole: waiting for server to appear...\n");
    while (io_driver_wait_forward(&msg) == -1) {
        ts.tv_sec = 0;
        ts.tv_nsec = 20000000; // 20ms
        nanosleep(&ts, NULL);
    }
    if (msg.address != IO_CMD_SERVERALIVE) {
        fprintf(stderr, "fconsole: expected IO_CMD_SERVERALIVE from server!\n");
        exit(-1);
    }
    // send CLIENTALIVE
    io_driver_post_backchannel(IO_CMD_CLIENTALIVE, 0);

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
    int ShiftState = 0, ControlState = 0, AltState = 0;
    int runFlag = 1;
    while (runFlag == 1) {

        struct timespec l_frame_ts;
        // cap at 120 frames per second to prevent 100% cpu usage
        l_frame_ts.tv_nsec = 8000000;
        l_frame_ts.tv_sec = 0;
        nanosleep(&l_frame_ts, NULL);

        draw();
        XPutImage(dpy, win, NormalGC, ximage, 0, 0, 0, 0, g_width, g_height);
        g_frames++;

        while (XPending(dpy)) {
            XNextEvent(dpy, &event);
            KeySym key_symbol;
            char xlat[10];
            if ((event.type == KeyPress) || (event.type == KeyRelease))
                XLookupString(&event.xkey, xlat, 10, &key_symbol, NULL);

            switch(event.type) {
            case Expose:
//                printf("I have been exposed!\n");
                XPutImage(dpy, win, NormalGC, ximage, 0, 0, 0, 0, g_width, g_height);
                g_frames++;
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
                        //							printf("Key: %04X ShiftState: %d ControlState: %d AltState: %d XLookupString '%s' (0x%02X)\n", (unsigned int)key_symbol, ShiftState, ControlState, AltState, xlat, xlat[0]);
                        if ((ShiftState == 0) && (ControlState == 1) && (AltState == 1) && (key_symbol == 0xff57)) {
                            // control-alt-end to reset
                            io_driver_post_backchannel(IO_CMD_WARMRESET, 0);
                            break;
                        }
                        if (key_symbol == 0xff51)
                            xlat[0] = 0x8;
                        if (key_symbol == 0xff52)
                            xlat[0] = 0x9;
                        if (key_symbol == 0xff53)
                            xlat[0] = 0xb;
                        if (key_symbol == 0xff54)
                            xlat[0] = 0xa;
                        io_driver_post_backchannel(IO_CMD_KEYPRESS, xlat[0]);
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
                printf("console: Button %d at: X%d, Y%d\n",event.xbutton.button,event.xbutton.x,event.xbutton.y);
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

    printf("fconsole: Shutting down X Windows...\n");
    XFreeGC(dpy, NormalGC);
    XCloseDisplay(dpy);
    io_driver_post_backchannel(IO_CMD_CLIENTDEAD, 0);
    printf("fconsole: shutting down memory driver...\n");
    mem_driver_shutdown();
    ts.tv_sec = 0;
    ts.tv_nsec = 500000000; // 500ms
    nanosleep(&ts, NULL); // wait for server to receive CLIENTDEAD

    gettimeofday(&end_time, NULL);
    long elapsed_secs = end_time.tv_sec - start_time.tv_sec - ((end_time.tv_usec - start_time.tv_usec < 0) ? 1 : 0); // subtract 1 if there was a usec rollover
    long elapsed_usecs = end_time.tv_usec - start_time.tv_usec + ((end_time.tv_usec - start_time.tv_usec < 0) ? 1000000 : 0); // bump usecs by 1 million usec for rollover
    printf("fconsole: %ld frames displayed in %ld seconds %ld usecs.\n", g_frames, elapsed_secs, elapsed_usecs);
    printf("fconsole: estimated console FPS: %f\n", (double)g_frames / ((double)elapsed_secs + (double)(elapsed_usecs / 1000000.0)));

    printf("fconsole: exiting...\n");

    return 0;
}

