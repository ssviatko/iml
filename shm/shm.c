#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/shm.h>
#include <sys/ipc.h> // for ftok

#define SHM_SIZE 4096
#define SHM_MODE 0600

int get_shm(char **a_shm_ptr)
{
	int shmid;
	char *shm_ptr;
	key_t key = ftok("token", 'A');
	if ((shmid = shmget(key, SHM_SIZE, SHM_MODE | IPC_CREAT)) < 0) {
		fprintf(stderr, "shmget error\n");
		exit(-1);
	}
	printf("shmid = %d\n", shmid);
	if ((shm_ptr = shmat(shmid, 0, 0)) == (void *)-1) {
		fprintf(stderr, "shmat error\n");
		exit(-1);
	}
	*a_shm_ptr = shm_ptr;
	return shmid;
}

void client(void)
{
	char *shm_ptr;
	int shmid = get_shm(&shm_ptr);
	printf("shared memory client\n");
	printf("shm_ptr = %016X\n", (long long)shm_ptr);
	// send cookie then detach/destroy
	uint32_t *cookie;
	cookie = (uint32_t *)shm_ptr + 0;
	*cookie = 0xc0edbabe;
	shmdt(shm_ptr);
	shmctl(shmid, IPC_RMID, NULL);
}

void server(void)
{
	char *shm_ptr;
	int shmid = get_shm(&shm_ptr);
	printf("shared memory server\n");
	printf("shm_ptr = %016X\n", (long long)shm_ptr);
	// wait for cookie to appear at byte 0 then quit
	uint32_t *cookie;
	int done = 0;
	do {
		sleep(1);
		printf("waiting for cookie...\n");
		cookie = (uint32_t *)shm_ptr + 0;
		if (*cookie == 0xc0edbabe)
			done = 1;
	} while (done == 0);
	printf("got cookie %08X\n", *cookie);
	shmdt(shm_ptr);
}

void usage(void)
{
	fprintf(stderr, "usage: shm [s|c]\n");
	exit(0);
}

int main(int argc, char **argv)
{
	if (argc != 2)
		usage();

	if (strcmp(argv[1], "s") == 0)
		server();
	else if (strcmp(argv[1], "c") == 0)
		client();
	else
		usage();

	return 0;
}

