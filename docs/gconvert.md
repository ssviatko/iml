Proposal for GConvert utility

The purpose of gconvert is to take existing graphics files (BMP, Targa, and JPEG) and convert them to IML graphics formats. There are 3 formats of interest:

Mode 4: 120x68, 4096 colors
Mode 5: 240x136, 4096 colors
Mode 6: 480x272, 4096 colors

The pixels for the 4096 color modes are arranged linearly going horizontally through the pixels of one line, then wrapping to the next line, starting at $180000. Each pixel is 16 bits wide, with the red channel occypying bits 8-11, green on bits 4-7, and blue on bits 0-3.

The structure of the command is as follows:

gconvert -i input_file.(bmp/tga/jpg) -o screendump.scr -m (4/5/6) [optional: -s]

long argument correlations:

-i --input
-o --output
-m --mode
-s --scale

The --input file can be any bitmap, targa, or jpeg file that can be processed. The resolution is expected to not exceed the selected mode, or an error will be thrown reminding the user to specify -s or --scale.

The --output file is the screen image which will be loaded at $180000.

The --mode specifier selects modes 4, 5, or 6, which correspond to 120x68, 240x136, and 480x272.

The --scale specifier turns on a flag which allows a graphics image to be scaled to the target resolution. If there is a discrepancy in aspect ratio, then the program should scale the image to fit and black out unused portions of the screen.

Errors:

- no input file, no outputfile specified, no mode specified
- unable to open input file
- unable to write to output file
- mode specifier not 4, 5, or 6
- input file not a BMP, Targa, or JPG
- Any other errors that arise from processing an image


