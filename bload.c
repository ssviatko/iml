// bload - load a file into IML shared memory
//
// bload --address <addr> filename
//
// addr is a 24 bit value, decimal or hex with a $ prefix (quote it in the shell: '$10000').

#include <getopt.h>
#include <sys/stat.h>

#include "binio.h"

static struct option g_options[] = {
	{ "address", required_argument, NULL, 'a' },
	{ "help", no_argument, NULL, 'h' },
	{ NULL, 0, NULL, 0 }
};

static void usage(void)
{
	fprintf(stderr, "usage: bload --address <addr> filename\n"
		"       addr is decimal, or hex with a $ prefix (e.g. '$10000')\n");
}

int main(int argc, char **argv)
{
	int opt;
	int have_address = 0;
	uint32_t address = 0;

	while ((opt = getopt_long(argc, argv, "a:h", g_options, NULL)) != -1) {
		switch (opt) {
			case 'a':
				if (binio_parse(optarg, &address) < 0) {
					fprintf(stderr, "bload: bad address '%s' (must be 0 to $ffffff)\n", optarg);
					return 1;
				}
				have_address = 1;
				break;
			default:
				usage();
				return 1;
		}
	}
	if (!have_address || (optind != argc - 1)) {
		usage();
		return 1;
	}
	const char *filename = argv[optind];

	FILE *f = fopen(filename, "rb");
	if (!f) {
		fprintf(stderr, "bload: can't open %s: %s\n", filename, strerror(errno));
		return 1;
	}
	struct stat st;
	if (fstat(fileno(f), &st) < 0) {
		fprintf(stderr, "bload: can't stat %s: %s\n", filename, strerror(errno));
		fclose(f);
		return 1;
	}
	if (!S_ISREG(st.st_mode)) {
		fprintf(stderr, "bload: %s is not a regular file\n", filename);
		fclose(f);
		return 1;
	}
	if (st.st_size == 0) {
		fprintf(stderr, "bload: %s is empty\n", filename);
		fclose(f);
		return 1;
	}
	if ((uint64_t)address + (uint64_t)st.st_size > BINIO_MAX_ADDRESS) {
		fprintf(stderr, "bload: %s ($%llx bytes) at $%06x runs past the end of the 16MB address space\n",
			filename, (unsigned long long)st.st_size, address);
		fclose(f);
		return 1;
	}
	uint32_t length = (uint32_t)st.st_size;

	uint32_t size;
	unsigned char *mem = binio_attach("bload", &size);
	if (!mem) {
		fclose(f);
		return 1;
	}
	if ((uint64_t)address + length > size) {
		fprintf(stderr, "bload: $%06x-$%06x is outside shared memory ($000000-$%06x)\n",
			address, address + length - 1, size - 1);
		fclose(f);
		shmdt(mem);
		return 1;
	}

	// read into a buffer first, so a read error doesn't leave memory half loaded
	unsigned char *buf = malloc(length);
	if (!buf) {
		fprintf(stderr, "bload: out of memory\n");
		fclose(f);
		shmdt(mem);
		return 1;
	}
	size_t n = fread(buf, 1, length, f);
	int err = ferror(f);
	fclose(f);
	if (err || n != length) {
		fprintf(stderr, "bload: error reading %s\n", filename);
		free(buf);
		shmdt(mem);
		return 1;
	}
	memcpy(mem + address, buf, length);
	free(buf);
	shmdt(mem);
	printf("bload: loaded $%06x bytes from %s to $%06x-$%06x\n", length, filename, address, address + length - 1);
	return 0;
}
