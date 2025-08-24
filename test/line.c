#include <stdio.h>
#include <stdlib.h>

void usage()
{
	printf("usage: line <x> <y> <xdest> <ydest>\n");
	exit(-1);
}

void point(unsigned int a_x, unsigned int a_y)
{
	printf("point %d,%d\n", a_x, a_y);
}

void vlin(unsigned int a_y, unsigned int a_ydest, unsigned int a_x)
{
	unsigned int temp;
	// make y's ascend
	if (a_ydest < a_y) {
		temp = a_y;
		a_y = a_ydest;
		a_ydest = temp;
	}
	printf("vlin %d to %d at %d\n", a_y, a_ydest, a_x);
	for (unsigned int l_ystep = a_y; l_ystep <= a_ydest; ++l_ystep)
		point(a_x, l_ystep);
}

void hlin(unsigned int a_x, unsigned int a_xdest, unsigned int a_y)
{
	unsigned int temp;
	// make x's ascend
	if (a_xdest < a_x) {
		temp = a_x;
		a_x = a_xdest;
		a_xdest = temp;
	}
	printf("hlin %d to %d at %d\n", a_x, a_xdest, a_y);
	for (unsigned int l_xstep = a_x; l_xstep <= a_xdest; ++l_xstep)
		point(l_xstep, a_y);
}

void line(unsigned int a_x, unsigned int a_y, unsigned int a_xdest, unsigned int a_ydest)
{
	// edge case of single point
	if ((a_x == a_xdest) && (a_y == a_ydest)) {
		// point
		point(a_x, a_y);
		return;
	}

	// edge cases of a_x == a_xdest or a_y == a_ydest
	if (a_x == a_xdest) {
		// vlin
		vlin(a_y, a_ydest, a_x);
		return;
	}
	if (a_y == a_ydest) {
		// hlin
		hlin(a_x, a_xdest, a_y);
		return;
	}

	// diagonal line, check which side is longest
	int longside; // 0 = x, 1 = y
	if (abs(a_xdest - a_x) > abs(a_ydest - a_y)) {
		longside = 0; // x is longer
		printf("x side is longest\n");
	} else {
		longside = 1;
		printf("y side is longest\n");
	}

	unsigned int l_xstep;
	unsigned int l_ystep;

	if (longside == 0) {
		// if xdest is less than x, swap x,y and xdest,ydest so that x is always ascending
		if (a_xdest < a_x) {
			unsigned int temp;
			temp = a_x;
			a_x = a_xdest;
			a_xdest = temp;
			temp = a_y;
			a_y = a_ydest;
			a_ydest = temp;
		}
		unsigned int l_totalxdist = a_xdest - a_x;
		int l_totalydelta = a_ydest - a_y;
		unsigned int l_xstepdist = 0;
		for (l_xstep = a_x; l_xstep <= a_xdest; ++l_xstep, ++l_xstepdist) {
			int l_ystepdist = (((int)l_xstepdist * l_totalydelta) / (int)l_totalxdist);
			point(l_xstep, (unsigned int)(a_y + l_ystepdist));
		}
	} else if (longside == 1) {
		// if ydest is less than y, swap x,y and xdest,ydest so that y is always ascending
		if (a_ydest < a_y) {
			unsigned int temp;
			temp = a_x;
			a_x = a_xdest;
			a_xdest = temp;
			temp = a_y;
			a_y = a_ydest;
			a_ydest = temp;
		}
		unsigned int l_totalydist = a_ydest - a_y;
		int l_totalxdelta = a_xdest - a_x;
		unsigned int l_ystepdist = 0;
		for (l_ystep = a_y; l_ystep <= a_ydest; ++l_ystep, ++l_ystepdist) {
			int l_xstepdist = (((int)l_ystepdist * l_totalxdelta) / (int)l_totalydist);
			point((unsigned int)(a_x + l_xstepdist), l_ystep);
		}
	}
}

int main(int argc, char **argv)
{
	if (argc != 5)
		usage();

	unsigned int x = atoi(argv[1]);
	unsigned int y = atoi(argv[2]);
	unsigned int xdest = atoi(argv[3]);
	unsigned int ydest = atoi(argv[4]);

	printf("line from %d,%d to %d,%d\n", x, y, xdest, ydest);

	line(x, y, xdest, ydest);

	return 0;
}

