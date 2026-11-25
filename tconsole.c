// tconsole - IML text console for a terminal (no X11).
//
// Instead of drawing the video buffer, this prints the characters the server writes to the
// text console (IO_CON_REGISTER and IO_CON_CR) on stdout, as they are written. It connects
// with IO_CMD_CLIENTALIVE byte = IO_CLIENT_TEXTSTREAM, which makes the server send each
// character as an IO_CMD_CONCHAR message. Video modes 0-7 show nothing, and the cursor
// position and clear screen soft switches are ignored.
//
// Keys go to the server like fconsole sends them: Enter = 13, Backspace = 8, arrow keys =
// 8/9/10/11 (left/up/down/right). Ctrl-Alt-End sends a warm reset. Ctrl-C quits.

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <signal.h>
#include <fcntl.h>
#include <unistd.h>
#include <termios.h>
#include <getopt.h>

#include "memio_driver.h"

struct option g_options[] = {
	{ "exec", required_argument, NULL, 'e' },
	{ NULL, 0, NULL, 0 }
};

static struct termios g_saved_termios;
static int g_termios_saved = 0;
static int g_stdin_tty = 0;
static volatile sig_atomic_t g_run = 1;

static void restore_terminal(void)
{
	if (g_termios_saved)
		tcsetattr(STDIN_FILENO, TCSANOW, &g_saved_termios);
}

static void raw_terminal(void)
{
	struct termios t;

	if (!isatty(STDIN_FILENO) || tcgetattr(STDIN_FILENO, &g_saved_termios) < 0) {
		// not a terminal (a pipe or a file): just don't block reading it
		fcntl(STDIN_FILENO, F_SETFL, fcntl(STDIN_FILENO, F_GETFL) | O_NONBLOCK);
		return;
	}
	g_termios_saved = 1;
	g_stdin_tty = 1;
	atexit(restore_terminal);
	t = g_saved_termios;
	t.c_lflag &= ~(ICANON | ECHO);   // keys one at a time, no echo; ISIG stays so Ctrl-C quits
	t.c_iflag &= ~(ICRNL | INLCR | IXON); // Enter arrives as 13, Ctrl-S/Ctrl-Q are just keys
	t.c_cc[VMIN] = 0;
	t.c_cc[VTIME] = 0;
	tcsetattr(STDIN_FILENO, TCSANOW, &t);
}

static void quit_handler(int a_sig)
{
	(void)a_sig;
	g_run = 0;
}

// start the server in its own process group (so Ctrl-C only reaches us) with its status
// messages thrown away (so they don't land in the middle of the console output)
void load_server(char *path)
{
	int pid = fork();
	if (pid == 0) {
		setpgid(0, 0);
		int fd = open("/dev/null", O_RDWR);
		if (fd >= 0) {
			dup2(fd, 0);
			dup2(fd, 1);
			dup2(fd, 2);
		}
		char *execargs[2] = { path, NULL };
		execvp(path, execargs);
		_exit(-1);
	}
	if (pid < 0) {
		fprintf(stderr, "tconsole: fork of server failed. errno=%d (%s)\n", errno, strerror(errno));
		exit(-1);
	}
}

// print one console character
static void put_con_char(uint8_t a_char)
{
	switch (a_char) {
		case 0x0d: // carriage return: next line
		case 0x0a: // ctrl-J (cursor down)
			putchar('\n');
			break;
		case 0x08: // ctrl-H (cursor left), used for backspace as 8,' ',8
			putchar('\b');
			break;
		default:
			if ((a_char >= 0x20) && (a_char < 0x7f))
				putchar(a_char);
			// other control codes (ctrl-I cursor up, ctrl-K cursor right) and the
			// graphics characters above 0x7e have no stream equivalent
			break;
	}
}

// a terminal escape sequence (after ESC) to a key for the server; -1 = nothing to send
static int escape_key(const char *a_seq)
{
	if (!strcmp(a_seq, "[A") || !strcmp(a_seq, "OA"))
		return 0x09; // up
	if (!strcmp(a_seq, "[B") || !strcmp(a_seq, "OB"))
		return 0x0a; // down
	if (!strcmp(a_seq, "[C") || !strcmp(a_seq, "OC"))
		return 0x0b; // right
	if (!strcmp(a_seq, "[D") || !strcmp(a_seq, "OD"))
		return 0x08; // left
	if (!strcmp(a_seq, "[1;7F") || !strcmp(a_seq, "[4;7~") || !strcmp(a_seq, "[8;7~"))
		return -2; // ctrl-alt-end: warm reset
	return -1;
}

// read whatever keys are waiting and send them to the server
static void read_keys(void)
{
	unsigned char buf[64];
	ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));

	for (ssize_t i = 0; i < n; ++i) {
		uint8_t c = buf[i];
		if ((c == 0x1b) && (i + 1 < n) && ((buf[i + 1] == '[') || (buf[i + 1] == 'O'))) {
			// escape sequence: up to the final byte (a letter or ~)
			char seq[16];
			int l = 0;
			seq[l++] = buf[++i];
			while ((i + 1 < n) && (l < 15)) {
				char d = buf[++i];
				seq[l++] = d;
				if (((d >= 'A') && (d <= 'Z')) || ((d >= 'a') && (d <= 'z')) || (d == '~'))
					break;
			}
			seq[l] = 0;
			int k = escape_key(seq);
			if (k == -2)
				io_driver_post_backchannel(IO_CMD_WARMRESET, 0);
			else if (k >= 0)
				io_driver_post_backchannel(IO_CMD_KEYPRESS, k);
			continue;
		}
		if (c == 0x7f)
			c = 0x08; // Backspace key
		if ((c == 0x0a) && !g_stdin_tty)
			c = 0x0d; // a newline from a pipe or file is Enter
		io_driver_post_backchannel(IO_CMD_KEYPRESS, c);
	}
}

int main(int argc, char **argv)
{
	int opt;
	char *server = NULL;

	while ((opt = getopt_long(argc, argv, "e:", g_options, NULL)) != -1) {
		switch (opt) {
			case 'e':
				server = optarg;
				break;
			default:
				fprintf(stderr, "usage: tconsole [-e server]\n");
				exit(-1);
		}
	}

	mem_driver_startup();
	io_driver_startup();
	if (server)
		load_server(server);

	struct sigaction sa;
	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = quit_handler;
	sigemptyset(&sa.sa_mask);
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);
	sigaction(SIGHUP, &sa, NULL);  // terminal closed
	sigaction(SIGPIPE, &sa, NULL); // output pipe closed: still tell the server we're leaving

	struct timespec ts;
	io_message_t msg;
	// wait for SERVERALIVE. Nothing to do if the server isn't there
	fprintf(stderr, "tconsole: waiting for server to appear...\n");
	while (io_driver_wait_forward(&msg) == -1) {
		if (!g_run) {
			mem_driver_shutdown();
			return 0;
		}
		ts.tv_sec = 0;
		ts.tv_nsec = 20000000; // 20ms
		nanosleep(&ts, NULL);
	}
	if (msg.address != IO_CMD_SERVERALIVE) {
		fprintf(stderr, "tconsole: expected IO_CMD_SERVERALIVE from server!\n");
		exit(-1);
	}
	// connect, asking for the console as a character stream
	io_driver_post_backchannel(IO_CMD_CLIENTALIVE, IO_CLIENT_TEXTSTREAM);
	fprintf(stderr, "tconsole: connected. Ctrl-C quits, Ctrl-Alt-End resets.\n");

	raw_terminal();
	int server_died = 0;
	while (g_run) {
		int busy = 0;
		while (io_driver_wait_forward(&msg) == 0) {
			busy = 1;
			if (msg.address == IO_CMD_CONCHAR) {
				put_con_char(msg.byte);
			} else if (msg.address == IO_CMD_SERVERDEAD) {
				server_died = 1;
				g_run = 0;
				break;
			}
			// video mode changes and anything else: nothing to show
		}
		if (busy)
			fflush(stdout);
		read_keys();
		if (!busy) {
			ts.tv_sec = 0;
			ts.tv_nsec = 1000000; // 1ms
			nanosleep(&ts, NULL);
		}
	}

	restore_terminal();
	putchar('\n');
	fflush(stdout);
	if (server_died) {
		fprintf(stderr, "tconsole: server died.\n");
	} else {
		io_driver_post_backchannel(IO_CMD_CLIENTDEAD, 0);
		ts.tv_sec = 0;
		ts.tv_nsec = 500000000; // 500ms
		nanosleep(&ts, NULL); // wait for the server to receive CLIENTDEAD
	}
	mem_driver_shutdown();
	fprintf(stderr, "tconsole: exiting...\n");
	return 0;
}
