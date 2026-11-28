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

// nonzero when the connected client wants the text console as a character stream (tconsole)
static int g_con_stream = 0;

int io_driver_wait_backchannel(io_message_t *a_msg)
{
	if (msgrcv(g_qid_backchannel, a_msg, sizeof(io_message_t), 0, IPC_NOWAIT) == -1) {
		if (errno == ENOMSG)
			return -1;
		fprintf(stderr, "msgrcv(backchannel) %s qid=%d\n", strerror(errno), g_qid_backchannel);
		exit(-1);
	}
	// every server sees the client connect and disconnect here, so this is where we learn
	// whether to stream console characters to it
	if (a_msg->address == IO_CMD_CLIENTALIVE)
		g_con_stream = (a_msg->byte == IO_CLIENT_TEXTSTREAM);
	else if (a_msg->address == IO_CMD_CLIENTDEAD)
		g_con_stream = 0;
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

static void window_defaults(void);

void mem_driver_startup()
{
	srand(time(NULL));
	g_shmid = get_shm(&g_shm_ptr);
	window_defaults(); // windows start out unmapped
	// init soft switches
	g_shm_ptr[IOSTART + IO_VIDMODE] = 8; // Lo-res text
	g_shm_ptr[IOSTART + IO_CON_CURSOR] = 0; // cursor off
	g_shm_ptr[IOSTART + IO_CON_CURSORH] = 0;
	g_shm_ptr[IOSTART + IO_CON_CURSORV] = 0; // cursor at top left corner
	clock_update(); // the clock registers hold something sensible from the start
}

// read the clock into the IO_CLOCK registers (all little endian)
void clock_update(void)
{
	struct timespec l_ts;
	struct tm l_tm;
	clock_gettime(CLOCK_REALTIME, &l_ts);
	time_t l_secs = l_ts.tv_sec;
	localtime_r(&l_secs, &l_tm);
	uint64_t l_epoch = (uint64_t)(int64_t)l_ts.tv_sec;
	for (int i = 0; i < 8; ++i)
		g_shm_ptr[IOSTART + IO_CLOCK_EPOCH + i] = (l_epoch >> (i * 8)) & 0xff;
	unsigned int l_ms = l_ts.tv_nsec / 1000000;
	g_shm_ptr[IOSTART + IO_CLOCK_MS] = l_ms & 0xff;
	g_shm_ptr[IOSTART + IO_CLOCK_MS + 1] = l_ms >> 8;
	g_shm_ptr[IOSTART + IO_CLOCK_HOUR] = l_tm.tm_hour;
	g_shm_ptr[IOSTART + IO_CLOCK_MINUTE] = l_tm.tm_min;
	g_shm_ptr[IOSTART + IO_CLOCK_SECOND] = l_tm.tm_sec;
	g_shm_ptr[IOSTART + IO_CLOCK_MONTH] = l_tm.tm_mon;
	g_shm_ptr[IOSTART + IO_CLOCK_DOM] = l_tm.tm_mday;
	unsigned int l_year = l_tm.tm_year + 1900;
	g_shm_ptr[IOSTART + IO_CLOCK_YEAR] = l_year & 0xff;
	g_shm_ptr[IOSTART + IO_CLOCK_YEAR + 1] = (l_year >> 8) & 0xff;
	g_shm_ptr[IOSTART + IO_CLOCK_DOW] = l_tm.tm_wday;
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

// shadowed memory windows. g_window[0..3] holds the 8K section number mapped at
// 0x6000, 0x8000, 0xa000 and 0xc000. Defaults map each window onto itself (unmapped).
static uint8_t g_window[4];

static void window_defaults(void)
{
	int i;

	for (i = 0; i < 4; i++) {
		g_window[i] = 3 + i; // section 3 = 0x6000, 4 = 0x8000, 5 = 0xa000, 6 = 0xc000
		g_shm_ptr[IOSTART + IO_Z80_WINDOW_8 + ((i + 3) & 3)] = g_window[i];
	}
}

// translate a CPU address to a physical address. Only 0x6000-0xe3ff is ever translated:
// the soft switch bank shows through at 0xe000-0xe3ff, and the 8K windows at 0x6000-0xdfff
// are redirected into upper memory according to the window switches.
uint32_t mem_driver_effadr(uint32_t a_address)
{
	if ((a_address < SHADOWSTART) || (a_address > SHADOWEND))
		return a_address;
	if (a_address >= IOSHADOWSTART)
		return IOSTART + (a_address - IOSHADOWSTART);
	return ((uint32_t)g_window[(a_address >> 13) - 3] << 13) | (a_address & 0x1fff);
}

static void mem_write_phys(uint32_t a_address, uint8_t a_byte);

void mem_driver_write(uint32_t a_address, uint8_t a_byte)
{
	if ((a_address - SHADOWSTART) <= (SHADOWEND - SHADOWSTART)) // unsigned compare: 0x6000-0xe3ff
		a_address = mem_driver_effadr(a_address);
	mem_write_phys(a_address, a_byte);
}

static void mem_write_phys(uint32_t a_address, uint8_t a_byte)
{
	// fast path: everything below the I/O area is plain RAM (or ROM that can't be written)
	if (a_address < IOSTART) {
		if ((a_address >= 0xe400) && (a_address <= 0xffff))
			return; // no write to ROM
		g_shm_ptr[a_address] = a_byte;
		return;
	}

	// dealbreakers, check these right off the bat
	if (a_address > MEMTOP)
		return; // no memory there
	if ((a_address >= 0x1c0000) && (a_address <= 0x1fffff))
		return; // no write to ROM
	if ((a_address >= 0xe400) && (a_address <= 0xffff))
		return; // no write to ROM
		
	// soft switch functions
	if (a_address == IOSTART + IO_KEYQ_DEQUEUE) {
		kbd_dequeue();
	} else if (a_address == IOSTART + IO_KEYQ_CLEAR) {
		kbd_clear();
	} else if (a_address == IOSTART + IO_KEYQ_FIND) {
		g_shm_ptr[IOSTART + IO_KEYQ_FOUND] = kbd_remove(a_byte);
	} else if (a_address == IOSTART + IO_CON_CLS) {
		con_cls();
	} else if (a_address == IOSTART + IO_CON_REGISTER) {
		con_register();
	} else if (a_address == IOSTART + IO_CON_CR) {
		con_cr();
	} else if (a_address == IOSTART + IO_VIDMODE) {
		// if we're on the text screen, reset the cursor to the top left
		if (a_byte >= 8) {
			g_shm_ptr[IOSTART + IO_CON_CURSORH] = 0;
			g_shm_ptr[IOSTART + IO_CON_CURSORV] = 0;
		}
	} else if (a_address == IOSTART + IO_Z80_WINDOW_6) {
		g_window[0] = a_byte;
	} else if (a_address == IOSTART + IO_Z80_WINDOW_8) {
		g_window[1] = a_byte;
	} else if (a_address == IOSTART + IO_Z80_WINDOW_A) {
		g_window[2] = a_byte;
	} else if (a_address == IOSTART + IO_Z80_WINDOW_C) {
		g_window[3] = a_byte;
	} else if (a_address == IOSTART + IO_CLOCK_UPDATE) {
		clock_update();
	} else if (a_address == IOSTART + IO_RANDBYTE) {
		// implement the random byte feature right here
		a_byte = rand() % 256;
		// and then fall through to where we write it out below
	} else if (a_address == IOSTART + IO_FP_INIT_CONSTANT) {
		fp_init_constant(a_byte);
	} else if (a_address == IOSTART + IO_FP_TO_ASCII) {
		fp_to_ascii(a_byte);
	} else if (a_address == IOSTART + IO_FP_MULTIPLY) {
		fp_multiply(a_byte);
	} else if (a_address == IOSTART + IO_FP_DIVIDE) {
		fp_divide(a_byte);
	} else if (a_address == IOSTART + IO_FP_ADD) {
		fp_add(a_byte);
	} else if (a_address == IOSTART + IO_FP_SUBTRACT) {
		fp_subtract(a_byte);
	} else if (a_address == IOSTART + IO_FP_LN) {
		fp_ln(a_byte);
	} else if (a_address == IOSTART + IO_FP_EXP) {
		fp_exp(a_byte);
	} else if (a_address == IOSTART + IO_FP_ILOAD) {
		fp_iload(a_byte);
	} else if (a_address == IOSTART + IO_FP_ISAVE) {
		fp_isave(a_byte);
	} else if (a_address == IOSTART + IO_FP_SIN) {
		fp_sin(a_byte);
	} else if (a_address == IOSTART + IO_FP_COS) {
		fp_cos(a_byte);
	} else if (a_address == IOSTART + IO_FP_TAN) {
		fp_tan(a_byte);
	} else if (a_address == IOSTART + IO_FP_ATN) {
		fp_atn(a_byte);
	} else if (a_address == IOSTART + IO_FP_POWER) {
		fp_power(a_byte);
	} else if (a_address == IOSTART + IO_FP_COMPARE) {
		fp_compare(a_byte);
	} else if (a_address == IOSTART + IO_FP_FROM_ASCII) {
		fp_from_ascii(a_byte);
	} else if (a_address == IOSTART + IO_FP_TO_ASCII_G) {
		fp_to_ascii_g(a_byte);
	} else if (a_address == IOSTART + IO_FP_FUNC) {
		fp_func(a_byte);
	} else if (a_address == IOSTART + IO_FP_CLASSIFY) {
		fp_classify(a_byte);
	} else if (a_address == IOSTART + IO_FP_ISAVE_CHECKED) {
		fp_isave_checked(a_byte);
	} else if (a_address == IOSTART + IO_FP_TO_ASCII_F) {
		fp_to_ascii_fe(a_byte, 0);
	} else if (a_address == IOSTART + IO_FP_TO_ASCII_E) {
		fp_to_ascii_fe(a_byte, 1);
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
	if ((a_address - SHADOWSTART) <= (SHADOWEND - SHADOWSTART)) // unsigned compare: 0x6000-0xe3ff
		a_address = mem_driver_effadr(a_address);
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
		for (uint8_t i = 1; i < kbd_qsize; ++i)
			kbd_q[i - 1] = kbd_q[i];
		--kbd_qsize;
	}
	g_shm_ptr[IOSTART + IO_KEYQ_SIZE] = kbd_qsize;
	g_shm_ptr[IOSTART + IO_KEYQ_WAITING] = kbd_q[0];

	return kbd_q[0];
}

// remove the first a_char in the queue, wherever it is (other keys stay in order).
// returns 1 if there was one
uint8_t kbd_remove(uint8_t a_char)
{
	for (unsigned int i = 0; i < kbd_qsize; ++i) {
		if (kbd_q[i] == a_char) {
			for (unsigned int j = i + 1; j < kbd_qsize; ++j)
				kbd_q[j - 1] = kbd_q[j];
			--kbd_qsize;
			if (kbd_qsize == 0)
				kbd_q[0] = 0;
			g_shm_ptr[IOSTART + IO_KEYQ_SIZE] = kbd_qsize;
			g_shm_ptr[IOSTART + IO_KEYQ_WAITING] = kbd_q[0];
			return 1;
		}
	}
	return 0;
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

// send a console character to a text stream client (in the text modes only)
static void con_stream(uint8_t a_char)
{
	uint8_t l_mode = g_shm_ptr[IOSTART + IO_VIDMODE];

	if (g_con_stream && ((l_mode == 0x08) || (l_mode == 0x09)))
		io_driver_post_forward(IO_CMD_CONCHAR, a_char);
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
	if (g_shm_ptr[IOSTART + IO_CON_CHAROUT] != 0x0d)
		con_stream(g_shm_ptr[IOSTART + IO_CON_CHAROUT]); // (CR is sent by con_cr)
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
	con_stream(0x0d);
	g_shm_ptr[IOSTART + IO_CON_CURSORH] = 0;
	g_shm_ptr[IOSTART + IO_CON_CURSORV] += 1;
	scrollup();
}

/* z80 support */

// The Z80 sees the same 64K address space as bank 0 of the 65816, including the shadowed
// windows (0x6000-0xdfff) and soft switch bank (0xe000-0xe3ff) handled by the memory driver.

void z80_driver_startup()
{
	window_defaults(); // memory windows start out unmapped
}

void z80_driver_shutdown()
{
}

uint8_t z80_mem_read(uint16_t a_address)
{
	return mem_driver_read(a_address);
}

void z80_mem_write(uint16_t a_address, uint8_t a_byte)
{
	// the conventional rules about writing to ROM areas also apply
	// (0x00e400-0x00ffff and 0x1c0000-0x1fffff), and in Z80 mode the bottom 8K is ROM too,
	// whether it is reached directly or through a window.
	uint32_t l_effadr = mem_driver_effadr(a_address);

	if (l_effadr <= Z80_ROM_END)
		return; // ROM area, leave it alone
	mem_write_phys(l_effadr, a_byte);
}

// z80 I/O support:
// a_address maps to IOSTART + a_address (soft switches 0x00-0xff)

uint8_t z80_io_read(uint8_t a_address)
{
	return mem_driver_read(IOSTART + a_address);
}

void z80_io_write(uint8_t a_address, uint8_t a_byte)
{
	mem_driver_write(IOSTART + a_address, a_byte);
}

/* m68k support */

// The 68000 sees the 2MB space flat (no shadow windows), big endian, with the address
// bus mirrored every 2MB. Everything below the video buffer is RAM (the 65816 ROM area at
// 0xe400-0xffff is not protected here); the ROM at 0x1c0000-0x1fffff is. Accesses are broken into bytes so that word and long writes to
// the soft switches trigger them in address order.

void m68k_driver_startup()
{
	window_defaults();
}

uint8_t m68k_mem_read8(uint32_t a_address)
{
	return g_shm_ptr[a_address & MEMTOP];
}

uint16_t m68k_mem_read16(uint32_t a_address)
{
	a_address &= MEMTOP;
	if (a_address < MEMTOP)
		return ((uint16_t)(uint8_t)g_shm_ptr[a_address] << 8) | (uint8_t)g_shm_ptr[a_address + 1];
	return ((uint16_t)(uint8_t)g_shm_ptr[a_address] << 8) | (uint8_t)g_shm_ptr[0];
}

uint32_t m68k_mem_read32(uint32_t a_address)
{
	return ((uint32_t)m68k_mem_read16(a_address) << 16) | m68k_mem_read16(a_address + 2);
}

void m68k_mem_write8(uint32_t a_address, uint8_t a_byte)
{
	a_address &= MEMTOP;
	if (a_address < IOSTART) {
		g_shm_ptr[a_address] = a_byte; // fast path for plain RAM
		return;
	}
	mem_write_phys(a_address, a_byte); // soft switches; the ROM at 0x1c0000 is write protected
}

void m68k_mem_write16(uint32_t a_address, uint16_t a_word)
{
	m68k_mem_write8(a_address, a_word >> 8);
	m68k_mem_write8(a_address + 1, a_word & 0xff);
}

void m68k_mem_write32(uint32_t a_address, uint32_t a_long)
{
	m68k_mem_write16(a_address, a_long >> 16);
	m68k_mem_write16(a_address + 2, a_long & 0xffff);
}

// floating point support

unsigned int fp_width;
unsigned int fp_reg;
unsigned int fp_extended;
unsigned int fp_cmd;
uint32_t fp_addr;

void fp_parse_command(uint8_t a_byte)
{
	// split up command byte into its components
	fp_width = (a_byte & 0x80) >> 7;
	fp_reg = (a_byte & 0x40) >> 6;
	fp_extended = (a_byte & 0x20) >> 5;
	fp_cmd = a_byte & 0x1f;
	fp_addr = fp_reg ? FPARGUMENT : FPACCUMULATOR;
}

void fp_writeback(long double a_wb)
{
	// writes back a_wb to FPACCUMULATOR or FPARGUMENT
	// register is dependent on fp_addr
	// size depends on fp_width and/or fp_extended (as set by fp_parse_command)

	int i;
	double fp_const_d = 0.0;
	float fp_const_f = 0.0;
	
	// zero out entire register space
	for (i = 0; i < 16; ++i)
		g_shm_ptr[fp_addr + i] = 0;
	
	// extended?
	if (fp_extended > 0) {
		uint8_t *fp_const_ptr = (uint8_t *)&a_wb;
		for (i = 0; i < 10; ++i) {
			g_shm_ptr[fp_addr + i] = fp_const_ptr[i];
		}
		return;
	}
	
	// little endian copy of IEEE real to our memory space
	if (fp_width > 0) {
		// double
		fp_const_d = a_wb;
		uint8_t *fp_const_d_ptr = (uint8_t *)&fp_const_d;
		for (i = 0; i < 8; ++i) {
			g_shm_ptr[fp_addr + i] = fp_const_d_ptr[i];
		}
	} else {
		// float
		fp_const_f = a_wb;
		uint8_t *fp_const_f_ptr = (uint8_t *)&fp_const_f;
		for (i = 0; i < 4; ++i) {
			g_shm_ptr[fp_addr + i] = fp_const_f_ptr[i];
		}
	}
}

long double fp_read_extended(int a_reg)
{
	union {
		long double ld;
		uint8_t ld_buff[10];
	} ldu;
	int i;
	uint32_t read_addr = a_reg ? FPARGUMENT : FPACCUMULATOR;
	for (i = 0; i < 10; ++i) {
		ldu.ld_buff[i] = g_shm_ptr[read_addr + i];
	}
	return ldu.ld;
}

long double fp_read_double(int a_reg)
{
	union {
		double d;
		uint8_t d_buff[8];
	} du;
	int i;
	long double ret;
	uint32_t read_addr = a_reg ? FPARGUMENT : FPACCUMULATOR;
	for (i = 0; i < 8; ++i) {
		du.d_buff[i] = g_shm_ptr[read_addr + i];
	}
	ret = (long double)du.d;
	return ret;
}

long double fp_read_float(int a_reg)
{
	union {
		float f;
		uint8_t f_buff[4];
	} fu;
	int i;
	long double ret;
	uint32_t read_addr = a_reg ? FPARGUMENT : FPACCUMULATOR;
	for (i = 0; i < 4; ++i) {
		fu.f_buff[i] = g_shm_ptr[read_addr + i];
	}
	ret = (long double)fu.f;
	return ret;
}

long double fp_read_specified(int a_width, int a_extended, int a_reg)
{
	if (a_extended > 0) {
		return fp_read_extended(a_reg);
	} else {
		if (a_width > 0) {
			return fp_read_double(a_reg);
		} else {
			return fp_read_float(a_reg);
		}
	}
}

void fp_init_constant(uint8_t a_byte)
{
	// command format:
	// bit 7: float/double
	// bit 6: acc/arg
	// bit 5: extended
	// bits 0-4: constant to select
	
	long double fp_const = 0.0;
	
	fp_parse_command(a_byte);
	
	switch (fp_cmd) {
		case 0:
			fp_const = 0.0L;
			break;
		case 1:
			fp_const = 1.0L;
			break;
		case 2:
			fp_const = 2.0L;
			break;
		case 3:
			fp_const = 3.0L;
			break;
		case 4:
			fp_const = 4.0L;
			break;
		case 5:
			fp_const = 5.0L;
			break;
		case 6:
			fp_const = 10.0L;
			break;
		case 7:
			fp_const = 100.0L;
			break;
		case 8:
			fp_const = -1.0L;
			break;
		case 9:
			fp_const = -2.0L;
			break;
		case 10:
			fp_const = -3.0L;
			break;
		case 11:
			fp_const = -4.0L;
			break;
		case 12:
			fp_const = -5.0L;
			break;
		case 13:
			fp_const = -10.0L;
			break;
		case 16:
			fp_const = 3.141592653589793238462643383279L;
			break;
		case 17:
			fp_const = 2.7182818284590452353602874L;
			break;
		case 18:
			fp_const = 1.414213562373095048801688724209698078569671875376948073176679L;
			break;
		case 19:
			fp_const = 1.6180339887498948482045868343656381177203091798057628621354486227L;
			break;
		default:
			fp_const = 0.0L;
			break;
	}
	fp_writeback(fp_const);
	g_shm_ptr[FPCOND] = 0;
}

void fp_to_ascii(uint8_t a_byte)
{
	// command format:
	// bit 7: float/double
	// bit 6: acc/arg
	// bit 5: extended
	// bits 0-4: ignored
	
	char buff[24];
	memset(buff, 0, 24);
	long double fp_val = 0.0L;
	int i;
	fp_parse_command(a_byte);
	
	// acquire the value we need
	fp_val = fp_read_specified(fp_width, fp_extended, fp_reg);
	
	// convert it to ascii and write buffer out to 1bfcc0
//	printf("fp_val is %20.20Lf\n", fp_val);
	snprintf(buff, 24, "%20.20Lf", fp_val);
	for (i = 0; i < 24; ++i)
		g_shm_ptr[FPASCII + i] = buff[i];
	return;
}

void fp_multiply(uint8_t a_byte)
{
	// preforms FPACCUMULATOR * FPARGUMENT
	//
	// command format:
	// bit 7: float/double
	// bit 6: acc/arg (location to write back to)
	// bit 5: extended
	// bits 0-4: ignored
	long double acc, arg, res;
	fp_parse_command(a_byte);
	acc = fp_read_specified(fp_width, fp_extended, 0);
	arg = fp_read_specified(fp_width, fp_extended, 1);
	res = acc * arg;
	fp_writeback(res);
	g_shm_ptr[FPCOND] = 0;
}

void fp_divide(uint8_t a_byte)
{
	// preforms FPACCUMULATOR / FPARGUMENT
	//
	// command format:
	// bit 7: float/double
	// bit 6: acc/arg (location to write back to)
	// bit 5: extended
	// bits 0-4: ignored
	long double acc, arg, res;
	fp_parse_command(a_byte);
	acc = fp_read_specified(fp_width, fp_extended, 0);
	arg = fp_read_specified(fp_width, fp_extended, 1);
	// test for division by zero
	if (arg == 0.0) {
		g_shm_ptr[FPCOND] = 0x80;
		return;
	}
	res = acc / arg;
	fp_writeback(res);
	g_shm_ptr[FPCOND] = 0;
}

void fp_add(uint8_t a_byte)
{
	// preforms FPACCUMULATOR + FPARGUMENT
	//
	// command format:
	// bit 7: float/double
	// bit 6: acc/arg (location to write back to)
	// bit 5: extended
	// bits 0-4: ignored
	long double acc, arg, res;
	fp_parse_command(a_byte);
	acc = fp_read_specified(fp_width, fp_extended, 0);
	arg = fp_read_specified(fp_width, fp_extended, 1);
	res = acc + arg;
	fp_writeback(res);
	g_shm_ptr[FPCOND] = 0;
}
void fp_subtract(uint8_t a_byte)
{
	// preforms FPACCUMULATOR - FPARGUMENT
	//
	// command format:
	// bit 7: float/double
	// bit 6: acc/arg (location to write back to)
	// bit 5: extended
	// bits 0-4: ignored
	long double acc, arg, res;
	fp_parse_command(a_byte);
	acc = fp_read_specified(fp_width, fp_extended, 0);
	arg = fp_read_specified(fp_width, fp_extended, 1);
	res = acc - arg;
	fp_writeback(res);
	g_shm_ptr[FPCOND] = 0;
}

void fp_ln(uint8_t a_byte)
{
	// preforms ln(FACC/FARG)
	// chooses register based on bit 6 of command
	// writes back to itself
	long double op;
	fp_parse_command(a_byte);
	op = fp_read_specified(fp_width, fp_extended, fp_reg);
	op = logl(op);
	fp_writeback(op);
	g_shm_ptr[FPCOND] = 0;
}

void fp_exp(uint8_t a_byte)
{
	// preforms ln(FACC/FARG)
	// chooses register based on bit 6 of command
	// writes back to itself
	long double op;
	fp_parse_command(a_byte);
	op = fp_read_specified(fp_width, fp_extended, fp_reg);
	op = expl(op);
	fp_writeback(op);
	g_shm_ptr[FPCOND] = 0;
}

void fp_iload(uint8_t a_byte)
{
	union {
		int64_t i64;
		char bytes[8];
	} l_fpint;
	// loads 64 byte integer at FPINT into
	// floating point register.
	fp_parse_command(a_byte);
	for (int i = 0; i < 8; ++i)
		l_fpint.bytes[i] = g_shm_ptr[FPINT + i];
	long double op = (long double)l_fpint.i64;
	fp_writeback(op);
	g_shm_ptr[FPCOND] = 0;
}

void fp_isave(uint8_t a_byte)
{
	union {
		int64_t i64;
		char bytes[8];
	} l_fpint;
	// saves integer portion of register as 64 byte integer at FPINT
	fp_parse_command(a_byte);
	long double op;
	op = fp_read_specified(fp_width, fp_extended, fp_reg);
	l_fpint.i64 = (int64_t)op;
	for (int i = 0; i < 8; ++i)
		g_shm_ptr[FPINT + i] = l_fpint.bytes[i];
	g_shm_ptr[FPCOND] = 0;
}

// unary functions: like fp_ln/fp_exp, they work on FACC or FARG (bit 6 of the command)
// and write the result back to the same register
static void fp_unary(uint8_t a_byte, long double (*a_fn)(long double))
{
	long double op;
	fp_parse_command(a_byte);
	op = fp_read_specified(fp_width, fp_extended, fp_reg);
	op = a_fn(op);
	fp_writeback(op);
	g_shm_ptr[FPCOND] = 0;
}

void fp_sin(uint8_t a_byte)
{
	// sin(FACC/FARG), radians
	fp_unary(a_byte, sinl);
}

void fp_cos(uint8_t a_byte)
{
	// cos(FACC/FARG), radians
	fp_unary(a_byte, cosl);
}

void fp_tan(uint8_t a_byte)
{
	// tan(FACC/FARG), radians
	fp_unary(a_byte, tanl);
}

void fp_atn(uint8_t a_byte)
{
	// atan(FACC/FARG), result in radians
	fp_unary(a_byte, atanl);
}

void fp_power(uint8_t a_byte)
{
	// performs FPACCUMULATOR ^ FPARGUMENT
	// bit 6 selects the register to write back to, like multiply/divide/add/subtract
	long double acc, arg;
	fp_parse_command(a_byte);
	acc = fp_read_specified(fp_width, fp_extended, 0);
	arg = fp_read_specified(fp_width, fp_extended, 1);
	fp_writeback(powl(acc, arg));
	g_shm_ptr[FPCOND] = 0;
}

void fp_compare(uint8_t a_byte)
{
	// compares FPACCUMULATOR with FPARGUMENT. Nothing is written back. FPCOND gets:
	// bit 0 = equal, bit 1 = FACC < FARG, bit 2 = FACC > FARG, bit 3 = unordered (a NaN)
	long double acc, arg;
	uint8_t cond = 0;
	fp_parse_command(a_byte);
	acc = fp_read_specified(fp_width, fp_extended, 0);
	arg = fp_read_specified(fp_width, fp_extended, 1);
	if (isnan(acc) || isnan(arg))
		cond = 0x08;
	else if (acc == arg)
		cond = 0x01;
	else if (acc < arg)
		cond = 0x02;
	else
		cond = 0x04;
	g_shm_ptr[FPCOND] = cond;
}

void fp_from_ascii(uint8_t a_byte)
{
	// converts the zero terminated text in FPASCII to a number in FACC/FARG (bit 6). The
	// text can be up to 31 characters long, running on into FPINT. Leading and trailing
	// spaces are allowed. If the text isn't a number, the register gets 0 and FPCOND bit 6
	// is set; otherwise FPCOND is 0.
	char buff[33];
	char *end;
	long double val;
	int i;
	fp_parse_command(a_byte);
	for (i = 0; i < 32; ++i)
		buff[i] = g_shm_ptr[FPASCII + i];
	buff[32] = 0;
	val = strtold(buff, &end);
	while (*end == ' ')
		++end;
	if ((end == buff) || (*end != 0) || isnan(val)) {
		fp_writeback(0.0L);
		g_shm_ptr[FPCOND] = 0x40;
		return;
	}
	fp_writeback(val);
	g_shm_ptr[FPCOND] = 0;
}

void fp_to_ascii_g(uint8_t a_byte)
{
	// converts FACC/FARG (bit 6) to text in the shortest of fixed or exponent form, with
	// the number of significant digits in bits 0-4 (0 = 18), e.g. "0.5", "-12", "1.5E+20".
	// The zero terminated text is written to FPASCII and can be up to 32 bytes long, so
	// it may run on into FPINT.
	char buff[32];
	long double val;
	int digits, i;
	fp_parse_command(a_byte);
	digits = fp_cmd ? fp_cmd : 18;
	val = fp_read_specified(fp_width, fp_extended, fp_reg);
	memset(buff, 0, sizeof(buff));
	snprintf(buff, sizeof(buff), "%.*Lg", digits, val);
	for (i = 0; i < 32; ++i) {
		char c = buff[i];
		if (c == 'e')
			c = 'E';
		g_shm_ptr[FPASCII + i] = c;
	}
}

static long double fp_negl(long double a) { return -a; }

void fp_func(uint8_t a_byte)
{
	// more unary functions on FACC/FARG (bit 6), written back to the same register.
	// bits 0-4 select the function:
	// 0 = log10, 1 = square root, 2 = absolute value, 3 = negate, 4 = floor, 5 = ceiling,
	// 6 = truncate (toward zero), 7 = round (halves away from zero), 8 = arcsin, 9 = arccos
	static long double (* const fns[])(long double) = {
		log10l, sqrtl, fabsl, fp_negl, floorl, ceill, truncl, roundl, asinl, acosl
	};
	fp_parse_command(a_byte);
	if (fp_cmd >= sizeof(fns) / sizeof(fns[0])) {
		g_shm_ptr[FPCOND] = 0;
		return;
	}
	fp_unary(a_byte, fns[fp_cmd]);
}

void fp_classify(uint8_t a_byte)
{
	// describes FACC/FARG (bit 6) in FPCOND:
	// bit 0 = zero, bit 1 = negative, bit 4 = not a number, bit 5 = infinite
	long double val;
	uint8_t cond = 0;
	fp_parse_command(a_byte);
	val = fp_read_specified(fp_width, fp_extended, fp_reg);
	if (isnan(val))
		cond |= 0x10;
	else if (isinf(val))
		cond |= 0x20;
	else if (val == 0.0L)
		cond |= 0x01;
	if (!isnan(val) && signbit(val) && (val != 0.0L))
		cond |= 0x02;
	g_shm_ptr[FPCOND] = cond;
}

void fp_isave_checked(uint8_t a_byte)
{
	// like fp_isave (the integer part of FACC/FARG to the 64 bit integer at FPINT), but
	// sets FPCOND bit 5 and stores 0 if the value doesn't fit in 64 bits (or isn't a number)
	union {
		int64_t i64;
		char bytes[8];
	} l_fpint;
	long double op;
	fp_parse_command(a_byte);
	op = fp_read_specified(fp_width, fp_extended, fp_reg);
	g_shm_ptr[FPCOND] = 0;
	// -2^63 <= op < 2^63 after truncation
	if (isnan(op) || (op >= 9223372036854775808.0L) || (op <= -9223372036854775809.0L)) {
		l_fpint.i64 = 0;
		g_shm_ptr[FPCOND] = 0x20;
	} else {
		l_fpint.i64 = (int64_t)op;
	}
	for (int i = 0; i < 8; ++i)
		g_shm_ptr[FPINT + i] = l_fpint.bytes[i];
}

void fp_to_ascii_fe(uint8_t a_byte, int a_exp)
{
	// converts FACC/FARG (bit 6) to text with bits 0-4 digits after the point: fixed
	// ("1234.50") or with an exponent ("1.23E+03"). The zero terminated text goes to
	// FPASCII and can be up to 32 bytes long (running on into FPINT); if it would be
	// longer, FPASCII gets "" and FPCOND bit 5 is set
	char buff[64];
	long double val;
	int i, n;
	fp_parse_command(a_byte);
	val = fp_read_specified(fp_width, fp_extended, fp_reg);
	n = snprintf(buff, sizeof(buff), a_exp ? "%.*LE" : "%.*Lf", (int)fp_cmd, val);
	g_shm_ptr[FPCOND] = 0;
	if ((n < 0) || (n > 31)) {
		buff[0] = 0;
		g_shm_ptr[FPCOND] = 0x20;
	}
	for (i = 0; i < 32; ++i)
		g_shm_ptr[FPASCII + i] = (i <= n) ? buff[i] : 0;
}
