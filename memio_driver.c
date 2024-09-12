#include "memio_driver.h"

static int g_qid_forward;
static int g_qid_backchannel;

void io_driver_startup()
{
	key_t l_key_forward = ftok("token", 'A');
	if (l_key_forward == -1) {
		fprintf(stderr, "ftok error(A)\n");
		exit(-1);
	}
	key_t l_key_backchannel = ftok("token", 'B');
	if (l_key_backchannel == -1) {
		fprintf(stderr, "ftok error(B)\n");
		exit(-1);
	}
	if ((g_qid_forward = msgget(l_key_forward, IPC_CREAT | MSQ_MODE)) == -1) {
		fprintf(stderr, "msgget error(forward)\n");
		exit(-1);
    }
	if ((g_qid_backchannel = msgget(l_key_backchannel, IPC_CREAT | MSQ_MODE)) == -1) {
		fprintf(stderr, "msgget error(backchannel)\n");
		exit(-1);
    }
}

int io_driver_qid_forward()
{
	return g_qid_forward;
}

int io_driver_qid_backchannel()
{
	return g_qid_backchannel;
}

void io_driver_shutdown()
{
	if (msgctl(g_qid_forward, IPC_RMID, NULL) == -1) {
		fprintf(stderr, "msgctl IPC_RMID(forward)\n");
		exit(-1);
	}
	if (msgctl(g_qid_backchannel, IPC_RMID, NULL) == -1) {
		fprintf(stderr, "msgctl IPC_RMID(backchannel)\n");
		exit(-1);
	}
}

void io_driver_post_forward(uint16_t a_address, uint8_t a_byte)
{
//	printf("posting forward %04X %02X\n", a_address, a_byte);
	io_message_t msg;
	msg.type = 1;
	msg.address = a_address;
	msg.byte = a_byte;
	if (msgsnd(g_qid_forward, &msg, sizeof(io_message_t) - sizeof(long), 0) == -1) {  
		fprintf(stderr, "msgsnd(forward) %s qid=%d addr=%04X byte=%02X\n", strerror(errno), g_qid_forward, msg.address, msg.byte);
		io_driver_shutdown();
		exit(-1);
	}
}

void io_driver_post_backchannel(uint16_t a_address, uint8_t a_byte)
{
	io_message_t msg;
	msg.type = 1;
	msg.address = a_address;
	msg.byte = a_byte;
	if (msgsnd(g_qid_backchannel, &msg, sizeof(io_message_t) - sizeof(long), 0) == -1) {  
		fprintf(stderr, "msgsnd(backchannel) %s qid=%d addr=%04X byte=%02X\n", strerror(errno), g_qid_backchannel, msg.address, msg.byte);
		io_driver_shutdown();
		exit(-1);
	}
}

int io_driver_wait_forward(io_message_t *a_msg)
{
	if (msgrcv(g_qid_forward, a_msg, sizeof(io_message_t), 0, IPC_NOWAIT) == -1) {
		if (errno == ENOMSG)
			return -1;
		fprintf(stderr, "msgrcv(forward) %s qid=%d\n", strerror(errno), g_qid_forward);
		exit(-1);
	}
	return 0;
}

int io_driver_wait_backchannel(io_message_t *a_msg)
{
	if (msgrcv(g_qid_backchannel, a_msg, sizeof(io_message_t), 0, IPC_NOWAIT) == -1) {
		if (errno == ENOMSG)
			return -1;
		fprintf(stderr, "msgrcv(backchannel) %s qid=%d\n", strerror(errno), g_qid_backchannel);
		exit(-1);
	}
	return 0;
}

// memory stuff

static int g_shmid;
static char *g_shm_ptr;

static int get_shm(char **a_shm_ptr)
{
	int l_shmid;
	char *l_shm_ptr;
	key_t l_key = ftok("token", 'A');
	if (l_key == -1) {
		fprintf(stderr, "ftok error\n");
		exit(-1);
	}
	if ((l_shmid = shmget(l_key, SHM_SIZE, SHM_MODE | IPC_CREAT)) < 0) {
		fprintf(stderr, "shmget error\n");
		exit(-1);
	}
	if ((l_shm_ptr = shmat(l_shmid, 0, 0)) == (void *)-1) {
		fprintf(stderr, "shmat error\n");
		exit(-1);
	}
	*a_shm_ptr = l_shm_ptr;
	return l_shmid;
}

void mem_driver_startup()
{
	g_shmid = get_shm(&g_shm_ptr);
	// init soft switches
	g_shm_ptr[IOSTART + IO_VIDMODE] = 8; // Lo-res text
	g_shm_ptr[IOSTART + IO_CON_CURSOR] = 0; // cursor off
}

void mem_driver_shutdown()
{
	shmdt(g_shm_ptr);
}

void mem_driver_dispose_shared()
{
	shmctl(g_shmid, IPC_RMID, NULL);
}

int mem_driver_shmid()
{
	return g_shmid;
}

unsigned char *mem_driver_buffer()
{
	return (unsigned char *)g_shm_ptr;
}

void mem_driver_write(uint32_t a_address, uint8_t a_byte)
{
	// addresses we need to report to the console
	switch (a_address) {
		case IOSTART + IO_VIDMODE:
		case IOSTART + IO_KEYQ_CLEAR:
		case IOSTART + IO_KEYQ_DEQUEUE:
		case IOSTART + IO_CON_REGISTER:
		case IOSTART + IO_CON_CR:
		case IOSTART + IO_CON_CLS:
			io_driver_post_forward(a_address - IOSTART, a_byte);
			break;
		default:
			break;
	}
	g_shm_ptr[a_address] = a_byte;
}
