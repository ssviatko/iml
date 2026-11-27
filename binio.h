// binio.h - shared helpers for bsave and bload (see docs/load-save.md)

#ifndef BINIO_H
#define BINIO_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <stdint.h>
#include <sys/ipc.h>
#include <sys/shm.h>

#define BINIO_MAX_ADDRESS 0x1000000 // 24 bit address space (16MB)

// parse a 24 bit value: hex with an h or H suffix (1c0000h), or decimal. Returns 0 if ok,
// -1 on a bad or out of range value
static int binio_parse(const char *a_str, uint32_t *a_value)
{
	char digits[32];
	size_t len = strlen(a_str);
	int base = 10;

	if ((len > 0) && ((a_str[len - 1] == 'h') || (a_str[len - 1] == 'H'))) {
		base = 16;
		--len;
	}
	if ((len == 0) || (len >= sizeof(digits)))
		return -1;
	memcpy(digits, a_str, len);
	digits[len] = 0;
	// digits only: strtoul would also take a sign, leading spaces and (in base 16) a 0x prefix
	if (strspn(digits, (base == 16) ? "0123456789abcdefABCDEF" : "0123456789") != len)
		return -1;
	errno = 0;
	unsigned long v = strtoul(digits, NULL, base);
	if ((errno != 0) || (v >= BINIO_MAX_ADDRESS))
		return -1;
	*a_value = (uint32_t)v;
	return 0;
}

// attach to the existing IML shared memory segment, without creating it. Returns the
// segment, or NULL (with a message printed) if there is no server running or it can't be used.
// a_size gets the size of the segment.
static unsigned char *binio_attach(const char *a_prog, uint32_t *a_size)
{
	key_t key = ftok("token", 'A');
	if (key == -1) {
		fprintf(stderr, "%s: can't find the IML token file (run from the IML directory): %s\n", a_prog, strerror(errno));
		return NULL;
	}
	int shmid = shmget(key, 0, 0);
	if (shmid < 0) {
		if (errno == ENOENT)
			fprintf(stderr, "%s: shared memory is not loaded (is an IML server running?)\n", a_prog);
		else
			fprintf(stderr, "%s: can't access shared memory: %s\n", a_prog, strerror(errno));
		return NULL;
	}
	struct shmid_ds ds;
	if (shmctl(shmid, IPC_STAT, &ds) < 0) {
		fprintf(stderr, "%s: can't query shared memory: %s\n", a_prog, strerror(errno));
		return NULL;
	}
	void *p = shmat(shmid, NULL, 0);
	if (p == (void *)-1) {
		fprintf(stderr, "%s: can't attach shared memory: %s\n", a_prog, strerror(errno));
		return NULL;
	}
	*a_size = (ds.shm_segsz < BINIO_MAX_ADDRESS) ? (uint32_t)ds.shm_segsz : BINIO_MAX_ADDRESS;
	return (unsigned char *)p;
}

#endif // BINIO_H
