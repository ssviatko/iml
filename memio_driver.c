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
	g_shm_ptr[IOSTART + IO_CON_CURSORH] = 0;
	g_shm_ptr[IOSTART + IO_CON_CURSORV] = 0; // cursor at top left corner
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
	if ((a_address >= 0x1c0000) && (a_address <= 0x1fffff))
		return; // no write to ROM
	if ((a_address >= 0xe400) && (a_address <= 0xffff))
		return; // no write to ROM
	if (a_address == IOSTART + IO_KEYQ_DEQUEUE)
		kbd_dequeue();
	if (a_address == IOSTART + IO_KEYQ_CLEAR)
		kbd_clear();
	if (a_address == IOSTART + IO_CON_CLS)
		con_cls();
	if (a_address == IOSTART + IO_CON_REGISTER)
		con_register();
	if (a_address == IOSTART + IO_CON_CR)
		con_cr();
	if (a_address == IOSTART + IO_VIDMODE) {
		// if we're on the text screen, reset the cursor to the top left
		if (a_byte >= 8) {
			g_shm_ptr[IOSTART + IO_CON_CURSORH] = 0;
			g_shm_ptr[IOSTART + IO_CON_CURSORV] = 0;
		}
	}
	g_shm_ptr[a_address] = a_byte;
	// addresses we need to report to the console
	switch (a_address) {
		case IOSTART + IO_VIDMODE:
			io_driver_post_forward(a_address - IOSTART, a_byte);
			break;
		default:
			break;
	}
}

uint8_t mem_driver_read(uint32_t a_address)
{
	// protect reading out of memory range
	a_address &= 0x1fffff;
	return g_shm_ptr[a_address];
}

// keyboard queue
static uint8_t kbd_q[256];
static uint8_t kbd_qsize = 0;

void kbd_enqueue(uint8_t a_char)
{
	if (kbd_qsize == 255)
		return; // queue full
	kbd_q[kbd_qsize++] = a_char;
	g_shm_ptr[IOSTART + IO_KEYQ_SIZE] = kbd_qsize;
	g_shm_ptr[IOSTART + IO_KEYQ_WAITING] = kbd_q[0];
}

uint8_t kbd_dequeue()
{
	if (kbd_qsize == 0)
		return 0;
	if (kbd_qsize == 1) {
		kbd_qsize = 0;
		kbd_q[0] = 0;
	} else {
		for (uint8_t i = 1; i <= kbd_qsize; ++i)
			kbd_q[i -1] = kbd_q[i];
	}
	g_shm_ptr[IOSTART + IO_KEYQ_SIZE] = kbd_qsize;
	g_shm_ptr[IOSTART + IO_KEYQ_WAITING] = kbd_q[0];

	return kbd_q[0];
}

void kbd_clear()
{
	kbd_qsize = 0;
	g_shm_ptr[IOSTART + IO_KEYQ_SIZE] = 0;
	g_shm_ptr[IOSTART + IO_KEYQ_WAITING] = 0;
}

void con_cls()
{
	// clear the text screen
	uint8_t l_w;
	uint8_t l_h;
	if (g_shm_ptr[IOSTART + IO_VIDMODE] == 0x08) {
		l_w = 40;
		l_h = 17;
	} else if (g_shm_ptr[IOSTART + IO_VIDMODE] == 0x09) {
		l_w = 80;
		l_h = 34;
	} else {
		// not in either of the text modes, so do nothing
		l_w = 0;
		l_h = 0;
	}
	for (unsigned int h = 0; h < l_h; ++h) {
		for (unsigned int w = 0; w < l_w; ++w) {
			g_shm_ptr[VIDSTART + (h * l_w * 2) + (w * 2)] = g_shm_ptr[IOSTART + IO_CON_CHAROUT];
			g_shm_ptr[VIDSTART + (h * l_w * 2) + (w * 2) + 1] = g_shm_ptr[IOSTART + IO_CON_COLOR];
		}
	}
}

static void scrollup()
{
	uint8_t l_w = 0;
	uint8_t l_h = 0;
	if (g_shm_ptr[IOSTART + IO_VIDMODE] == 0x08) {
		l_w = 40;
		l_h = 17;
	} else if (g_shm_ptr[IOSTART + IO_VIDMODE] == 0x09) {
		l_w = 80;
		l_h = 34;
	}
	if (g_shm_ptr[IOSTART + IO_CON_CURSORV] >= l_h) {
		g_shm_ptr[IOSTART + IO_CON_CURSORV] = l_h - 1;
		// scroll the screen
		for (uint32_t d = VIDSTART; d < VIDSTART + (l_w * 2) * (l_h - 1); ++d) {
			g_shm_ptr[d] = g_shm_ptr[d + (l_w * 2)];
		}
		// blank out the last line
		for (uint32_t d = VIDSTART + (l_w * 2) * (l_h - 1); d < VIDSTART + (l_w * 2) * l_h; d += 2) {
			g_shm_ptr[d] = 0x20;
			g_shm_ptr[d + 1] = g_shm_ptr[IOSTART + IO_CON_COLOR];
		}
	}
}

void con_register()
{
	uint8_t l_w;
	if (g_shm_ptr[IOSTART + IO_VIDMODE] == 0x08) {
		l_w = 40;
	} else if (g_shm_ptr[IOSTART + IO_VIDMODE] == 0x09) {
		l_w = 80;
	} else {
		// not in either of the text modes, so print no character
		return;
	}
	// check for CR
	if (g_shm_ptr[IOSTART + IO_CON_CHAROUT] == 0x0d) {
		con_cr();
		return;
	}
	// ctrl-H (0x08)
	if (g_shm_ptr[IOSTART + IO_CON_CHAROUT] == 0x08) {
		if (g_shm_ptr[IOSTART + IO_CON_CURSORH] != 0) {
			g_shm_ptr[IOSTART + IO_CON_CURSORH]--;
		} else {
			if (g_shm_ptr[IOSTART + IO_CON_CURSORV] != 0) {
				g_shm_ptr[IOSTART + IO_CON_CURSORV]--;
				g_shm_ptr[IOSTART + IO_CON_CURSORH] = l_w - 1;
			}
		}
		return;
	}
	// ctrl-I (0x09)
	if (g_shm_ptr[IOSTART + IO_CON_CHAROUT] == 0x09) {
		if (g_shm_ptr[IOSTART + IO_CON_CURSORV] != 0) {
			g_shm_ptr[IOSTART + IO_CON_CURSORV]--;
		}
		return;
	}
	// ctrl-J (0x0a)
	if (g_shm_ptr[IOSTART + IO_CON_CHAROUT] == 0x0a) {
		g_shm_ptr[IOSTART + IO_CON_CURSORV] += 1;
		scrollup();
		return;
	}
	// ctrl-k (0x0b)
	if (g_shm_ptr[IOSTART + IO_CON_CHAROUT] == 0x0b) {
		goto register_advance;
	}
	// place the character at the cursor position
	uint32_t l_base = VIDSTART + (g_shm_ptr[IOSTART + IO_CON_CURSORH] * 2) + (l_w * g_shm_ptr[IOSTART + IO_CON_CURSORV] * 2);
    g_shm_ptr[l_base] = g_shm_ptr[IOSTART + IO_CON_CHAROUT];
    g_shm_ptr[l_base + 1] = g_shm_ptr[IOSTART + IO_CON_COLOR];
	// advance the cursor
register_advance:
	g_shm_ptr[IOSTART + IO_CON_CURSORH] += 1;
	if (g_shm_ptr[IOSTART + IO_CON_CURSORH] >= l_w) {
		g_shm_ptr[IOSTART + IO_CON_CURSORH] = 0;
		g_shm_ptr[IOSTART + IO_CON_CURSORV] += 1;
		scrollup();
	}
}

void con_cr()
{
	g_shm_ptr[IOSTART + IO_CON_CURSORH] = 0;
	g_shm_ptr[IOSTART + IO_CON_CURSORV] += 1;
	scrollup();
}

/* z80 support */

static uint8_t g_z80_window_8;
static uint8_t g_z80_window_a;
static uint8_t g_z80_window_c;
static uint8_t g_z80_window_e;

void z80_driver_startup()
{
	g_z80_window_8 = 0x04; // default to 0x008000
	g_z80_window_a = 0x05; // default to 0x00a000
	g_z80_window_c = 0x06; // default to 0x00c000
	g_z80_window_e = VIDSTART / 0x2000; // default to 0x180000 (VIDSTART)
}

void z80_driver_shutdown()
{
}

// these routines replace the mem_driver versions above, to allow for
// mapping of higher memory to the 8, a, c, and e windows

uint8_t z80_mem_read(uint16_t a_address)
{
	if (a_address < 0x8000) {
		// straight address, just return value from buffer
		return g_shm_ptr[a_address];
	} else {
		// windowed memory
		uint32_t l_effadr = z80_effadr(a_address);
//		printf("z80_mem_read: computed effective address %x for specified address %x.\n", l_effadr, a_address);
		return mem_driver_read(l_effadr);
	}
}

void z80_mem_write(uint16_t a_address, uint8_t a_byte)
{
	// note that the conventional rules about writing to ROM areas also apply:
	// no writing to 0x00e400-0x00ffff
	// no writing to 0x1c0000-0x1fffff
	// normally the E window will be mapped to video, but if it's ever remapped
	// back to page 7 (e000-ffff) this will be a concern.
	// pages 0xc0-0xff are read-only even in z80 mode.
	if (a_address <= Z80_ROM_END)
		return; // ROM area, leave it alone
	if (a_address < 0x8000) {
		// straight address, write to buffer
		mem_driver_write(a_address, a_byte);
	} else {
		// windowed memory
		uint32_t l_effadr = z80_effadr(a_address);
//		printf("z80_mem_write: computed effective address %x for specified address %x.\n", l_effadr, a_address);
		mem_driver_write(l_effadr, a_byte);
	}
}

uint32_t z80_effadr(uint32_t a_address)
{
	// assumes we're getting passed a value of $8000-$ffff
	if ((a_address < 0x8000) || (a_address > 0xffff))
		return a_address;
	uint8_t hinib = (a_address & 0xf000) >> 12;
	uint32_t lopart = a_address & 0x1fff;
	uint32_t ret = 0;
	switch (hinib) {
		case 0x8:
		case 0x9:
			ret = lopart + (g_z80_window_8 * 0x2000);
			break;
		case 0xa:
		case 0xb:
			ret = lopart + (g_z80_window_a * 0x2000);
			break;
		case 0xc:
		case 0xd:
			ret = lopart + (g_z80_window_c * 0x2000);
			break;
		case 0xe:
		case 0xf:
			ret = lopart + (g_z80_window_e * 0x2000);
			break;
		default:
			fprintf(stderr, "z80_effadr error: %x\n", hinib);
			exit(-1);
			break;
	}
	return ret;
}

// z80 I/O support:
// a_address maps to IOSTART + a_address
// if you want to use soft switches 0x100-0x3ff,
// map page 0xdf (0x1be000-0x1bffff) to any window.

uint8_t z80_io_read(uint8_t a_address)
{
	// z80 specific I/O
	if ((a_address <= IO_Z80_WINDOW_E) && (a_address >= IO_Z80_WINDOW_8)) {
		switch (a_address) {
			case IO_Z80_WINDOW_8:
				return g_z80_window_8;
				break;
			case IO_Z80_WINDOW_A:
				return g_z80_window_a;
				break;
			case IO_Z80_WINDOW_C:
				return g_z80_window_c;
				break;
			case IO_Z80_WINDOW_E:
				return g_z80_window_e;
				break;
		}
	}
	
	return mem_driver_read(IOSTART + a_address);
}

void z80_io_write(uint8_t a_address, uint8_t a_byte)
{
	// z80 specific I/O
	if ((a_address <= IO_Z80_WINDOW_E) && (a_address >= IO_Z80_WINDOW_8)) {
		switch (a_address) {
			case IO_Z80_WINDOW_8:
				g_z80_window_8 = a_byte;
				break;
			case IO_Z80_WINDOW_A:
				g_z80_window_a = a_byte;
				break;
			case IO_Z80_WINDOW_C:
				g_z80_window_c = a_byte;
				break;
			case IO_Z80_WINDOW_E:
				g_z80_window_e = a_byte;
				break;
		}
		return;
	}
	
	mem_driver_write(IOSTART + a_address, a_byte);
}
