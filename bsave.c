// bsave - save a block of IML shared memory to a file
//
// bsave --address <addr> --length <len> filename
//
// addr and len are 24 bit values, decimal or hex with a $ prefix (quote it in the shell: '$1c0000').

#include <getopt.h>
#include <unistd.h>

#include "binio.h"

static struct option g_options[] = {
	{ "address", required_argument, NULL, 'a' },
	{ "length", required_argument, NULL, 'l' },
	{ "help", no_argument, NULL, 'h' },
	{ NULL, 0, NULL, 0 }
};

static void usage(void)
{
	fprintf(stderr, "usage: bsave --address <addr> --length <len> filename\n"
		"       addr and len are decimal, or hex with a $ prefix (e.g. '$1c0000')\n");
}

int main(int argc, char **argv)
{
	int opt;
	int have_address = 0, have_length = 0;
	uint32_t address = 0, length = 0;

	while ((opt = getopt_long(argc, argv, "a:l:h", g_options, NULL)) != -1) {
		switch (opt) {
			case 'a':
				if (binio_parse(optarg, &address) < 0) {
					fprintf(stderr, "bsave: bad address '%s' (must be 0 to $ffffff)\n", optarg);
					return 1;
				}
				have_address = 1;
				break;
			case 'l':
				if (binio_parse(optarg, &length) < 0) {
					fprintf(stderr, "bsave: bad length '%s' (must be 1 to $ffffff)\n", optarg);
					return 1;
				}
				have_length = 1;
				break;
			default:
				usage();
				return 1;
		}
	}
	if (!have_address || !have_length || (optind != argc - 1)) {
		usage();
		return 1;
	}
	const char *filename = argv[optind];
	if (length == 0) {
		fprintf(stderr, "bsave: length must be at least 1\n");
		return 1;
	}
	if ((uint64_t)address + length > BINIO_MAX_ADDRESS) {
		fprintf(stderr, "bsave: $%06x + $%06x runs past the end of the 16MB address space\n", address, length);
		return 1;
	}

	uint32_t size;
	unsigned char *mem = binio_attach("bsave", &size);
	if (!mem)
		return 1;
	if ((uint64_t)address + length > size) {
		fprintf(stderr, "bsave: $%06x-$%06x is outside shared memory ($000000-$%06x)\n",
			address, address + length - 1, size - 1);
		shmdt(mem);
		return 1;
	}

	FILE *f = fopen(filename, "wb");
	if (!f) {
		fprintf(stderr, "bsave: can't create %s: %s\n", filename, strerror(errno));
		shmdt(mem);
		return 1;
	}
	size_t n = fwrite(mem + address, 1, length, f);
	int err = (n != length) ? errno : 0;
	if (fclose(f) != 0 && !err)
		err = errno ? errno : EIO;
	shmdt(mem);
	if (err || n != length) {
		fprintf(stderr, "bsave: error writing %s: %s\n", filename, strerror(err ? err : EIO));
		unlink(filename); // don't leave a partial file
		return 1;
	}
	printf("bsave: saved $%06x bytes from $%06x-$%06x to %s\n", length, address, address + length - 1, filename);
	return 0;
}
