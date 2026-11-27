Proposal for graphics commands for 68k BASIC interpreter

GR(x) command, where x specifies the graphics mode. 0, 1, 2, 4, 5, 6 are legal and any other number throws an error.
TEXT(x) command, where x specifies 8 or 9. Anything else throws an error.
CLS - clear text screen and put cursor at home position
LOCATE(x,y) - Move the text cursor to column x, row y
LOCATE(y) - move the text cursor to column 0, row y
COLOR(x) - Set foreground color to x
COLOR(x,y) - set foreground color to x, background to y

Graphics routines:

GRCLS - Clear graphics screen
PLOT(x, y) - plot pixel with current color
PLOT(x, y, c) - plot pixel with specified color (0-15 on modes 0, 1, and 2, 16 bit value on 4, 5, 6)
GRCOLOR(x) - set default color
LINE(x1, y1, x2, y2) - line from two anchors
LINE(x1, y1, x2, y2, c) - line with specified color
RECTANGLE(x1, y1, x2, y2) - rectangle from two anchors, which are opposite corners
RECTANGLE(x1, y1, x2, y2, c) - rectangle with specified color
CIRCLE() ... same as RECTANGLE except draws a circle
FILLRECTANGLE
FILLCIRCLE ... same as RECTANGLE and CIRCLE except filled with color

