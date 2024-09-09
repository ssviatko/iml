#include "io_driver.h"

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

void io_driver_post_forward(io_message_t *a_msg)
{
	if (msgsnd (g_qid_forward, a_msg, sizeof(io_message_t), 0) == -1) {  
		fprintf(stderr, "msgsnd(forward)\n");
		exit(-1);
	}
}

void io_driver_post_backchannel(io_message_t *a_msg)
{
	if (msgsnd (g_qid_backchannel, a_msg, sizeof(io_message_t), 0) == -1) {  
		fprintf(stderr, "msgsnd(backchannel)\n");
		exit(-1);
	}
}

int io_driver_wait_forward(io_message_t *a_msg)
{
	if (msgrcv(g_qid_forward, a_msg, sizeof(io_message_t), 0, IPC_NOWAIT) == -1) {
		if (errno == ENOMSG)
			return -1;
		fprintf(stderr, "msgrcv(forward)\n");
		exit(-1);
	}
	return 0;
}

int io_driver_wait_backchannel(io_message_t *a_msg)
{
	if (msgrcv(g_qid_backchannel, a_msg, sizeof(io_message_t), 0, IPC_NOWAIT) == -1) {
		if (errno == ENOMSG)
			return -1;
		fprintf(stderr, "msgrcv(backchannel)\n");
		exit(-1);
	}
	return 0;
}
