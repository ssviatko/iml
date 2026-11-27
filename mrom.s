; Motorola 68000 monitor
;
; Assemble with vasm (Motorola syntax): vasmm68k_mot -Fbin -m68000 -o mrom.bin mrom.s
; The image is loaded at $1c0000.
;
; Commands (all numbers are hex):
;   D [start [end]]       dump memory with ASCII
;   E addr byte...        enter bytes
;   F start end byte      fill memory
;   T start end dest      transfer (move) memory
;   M mode                set the video mode: 8 = 40 columns, 9 = 80 columns
;   C start end other     compare two ranges
;   S start end byte...   search for bytes
;   U [start [end]]       unassemble (disassemble), a screenful if no end is given
;   G addr                call a routine in supervisor mode (it can return with RTS)
;   R                     show the registers saved by the last exception
;   ! [addr]              mini-assembler (empty line to leave, addr: to move)
;   H                     halt the processor (STOP)
;   B                     BASIC, cold start (clears the BASIC program)
;   W                     BASIC, warm start (keeps the program and variables)
;   ?                     help
;
; Memory map:
;   $000000-$0003ff  exception vectors (RAM, copied from the start of the ROM at reset)
;   $000400-$000fff  monitor variables
;   $001000-$001003  BASIC: where its buffer (LOMEM) is
;   $001004-$00ffff  supervisor stack (the stack pointer starts at $010000)
;   $010000-$17ffff  user RAM (BASIC uses $010000-$16ffff by default)
;   $180000-$1bfbff  video buffer
;   $1bfc00-$1bffff  soft switches
;   $1c0000-$1fffff  ROM (write protected): this vector table, then the monitor at $1c0400,
;                    then BASIC at the next $1000 boundary after the monitor
;
; Any exception other than TRAP #15 prints the exception and the registers and
; returns to the monitor. TRAP #15 is a system call, function number in D0.B:
;   0 putc D1.B          1 getc -> D1.B         2 puts (A1)
;   3 print D1.B hex     4 print D1.W hex       5 print D1.L hex
;   6 newline            7 getline -> A1        8 key waiting? -> D1.B (0 = none)
;   9 return to the monitor
; All other registers are preserved.

IO		equ	$1bfc00
IO_KEYQ_SIZE	equ	IO+$00
IO_KEYQ_WAITING	equ	IO+$01
IO_KEYQ_DEQUEUE	equ	IO+$02
IO_CON_CLS	equ	IO+$10
IO_CON_COLOR	equ	IO+$11
IO_CON_CHAROUT	equ	IO+$12
IO_CON_REGISTER	equ	IO+$13
IO_CON_CURSORH	equ	IO+$14
IO_CON_CURSORV	equ	IO+$15
IO_CON_CURSOR	equ	IO+$16
IO_VIDMODE	equ	IO+$20

ROMBASE		equ	$1c0000
STACK		equ	$10000		; supervisor stack top
USERRAM		equ	$10000

; RAM variables
VARS		equ	$400
v_cur		equ	VARS+$00	; current address (dump, unassemble, enter, assemble)
v_end		equ	VARS+$04	; end of range
v_out		equ	VARS+$08	; output buffer pointer (when v_buf is set)
v_buf		equ	VARS+$0c	; nonzero: putc stores into the buffer instead of the screen
r_valid		equ	VARS+$0d	; nonzero: the register save area is valid
r_regs		equ	VARS+$20	; D0-D7/A0-A6 at the last exception
r_pc		equ	VARS+$60
r_ssp		equ	VARS+$64
r_usp		equ	VARS+$68
r_aa		equ	VARS+$6c	; access address (bus/address error)
r_sr		equ	VARS+$70
r_ir		equ	VARS+$72	; instruction register (bus/address error)
r_fc		equ	VARS+$74	; function code word (bus/address error)
r_vec		equ	VARS+$76	; vector number
patbuf		equ	VARS+$100	; search pattern
linebuf		equ	VARS+$140	; input line
outbuf		equ	VARS+$1c0	; disassembly text
tmpbuf		equ	VARS+$220	; disassembly: first operand of a reversed instruction
a_name		equ	VARS+$260	; assembler: mnemonic, padded with spaces
a_sfx		equ	VARS+$268	; assembler: size suffix letter or 0
a_nops		equ	VARS+$269	; assembler: number of operands
a_cc		equ	VARS+$26a	; assembler: condition code
a_len		equ	VARS+$26c	; assembler: length of the encoded instruction
opnd1		equ	VARS+$280	; assembler: first operand
opnd2		equ	VARS+$290	; assembler: second operand
abuf		equ	VARS+$2a0	; assembler: encoded instruction
inbuf		equ	VARS+$2c0	; assembler: normalized input line

; parsed operand: type, mode index, register, index register, value
O_TYPE		equ	0
O_MI		equ	1		; 0-6 = modes 0-6, 7 abs.W, 8 abs.L, 9 d16(PC), 10 d8(PC,Xn), 11 #imm
O_REG		equ	2
O_X		equ	3		; index register 0-15 (D0-D7, A0-A7), bit 4 set for .L
O_VAL		equ	4
T_EA		equ	1
T_RL		equ	2
T_CCR		equ	3
T_SR		equ	4
T_USP		equ	5

; instruction table: size codes
SZ_NONE		equ	0		; unsized
SZ_STD		equ	1		; bits 7-6: 00 = B, 01 = W, 10 = L
SZ_MOVE		equ	2		; bits 13-12: 01 = B, 11 = W, 10 = L
SZ_B6		equ	3		; bit 6: 0 = W, 1 = L
SZ_B8		equ	4		; bit 8: 0 = W, 1 = L
SZ_FB		equ	5		; always byte (no suffix shown)
SZ_FW		equ	6		; always word
SZ_FL		equ	7		; always long
SZ_BR		equ	8		; branch: .S (8 bit displacement) or .W

; instruction table: operand kinds. 1-20 are effective addresses (a mode/register field)
K_EALL		equ	1		; any mode, bits 5-0
K_EDATA		equ	2		; data
K_EMEM		equ	3		; memory
K_ECTRL		equ	4		; control
K_EALT		equ	5		; alterable
K_EDALT		equ	6		; data alterable
K_EMALT		equ	7		; memory alterable
K_EBTST		equ	8		; data, not immediate (static BTST)
K_EMMR		equ	9		; MOVEM registers to memory
K_EMRM		equ	10		; MOVEM memory to registers
K_MDST		equ	11		; MOVE destination, bits 11-6
K_DN0		equ	12		; Dn in bits 2-0
K_DN9		equ	13		; Dn in bits 11-9
K_AN0		equ	14
K_AN9		equ	15
K_PD0		equ	16		; -(An)
K_PD9		equ	17
K_PI0		equ	18		; (An)+
K_PI9		equ	19
K_DA0		equ	20		; d16(An) (MOVEP)
K_IMM		equ	21		; #imm of the instruction size
K_Q3		equ	22		; #1-8 in bits 11-9
K_Q8		equ	23		; MOVEQ #data
K_VEC		equ	24		; TRAP #0-15
K_DISP8		equ	25		; Bcc target
K_DISP16	equ	26		; DBcc target
K_RLIST		equ	27		; MOVEM register list
K_CCR		equ	28
K_SR		equ	29
K_USP		equ	30
K_IMMB		equ	31		; #imm in a byte (bit number)
K_IMMW		equ	32		; #imm word (STOP, LINK)

; instruction table: flags
F_REV		equ	1		; operands are written in the opposite order
F_NOCC01	equ	2		; condition must not be T or F
F_NOB		equ	4		; no byte size

; print the character \1, keeps all registers
	macro PUTCH
	move.l d0,-(sp)
	moveq #\1,d0
	bsr putc
	move.l (sp)+,d0
	endm

; print the string \1, keeps all registers
	macro PUTS
	bsr pstr
	dc.b \1,0
	even
	endm

; instruction table entry: name, match, mask, size code, operand 1, operand 2, flags
	macro INS
.n\@:	dc.b \1
	dcb.b 8-(*-.n\@),' '
	dc.w \2,\3
	dc.b \4,\5,\6,\7
	endm

; ---------------------------------------------------------------- vectors

; the machine copies these to $000000 at power on and warm reset
	org ROMBASE

	dc.l STACK
	dc.l romstart
n	set 2
	rept 254
	if n=47
	dc.l trap15
	else
	dc.l stubs+(n-2)*4
	endif
n	set n+1
	endr

; ---------------------------------------------------------------- monitor

	org ROMBASE+$400

romstart:
	move.w #$2700,sr
	lea STACK,sp
	clr.b v_buf
	clr.b r_valid
	move.b #$80,IO_CON_CURSOR
	move.b #7,IO_CON_COLOR		; light grey on black
	moveq #9,d0
	bsr setmode			; 80 column text mode
	move.l #USERRAM,v_cur
	PUTS <"68000 Monitor, ? for help",13>

main:
	lea STACK,sp
	clr.b v_buf
	moveq #'>',d0
	bsr putc
	bsr getline
	bsr skipsp
	move.b (a0)+,d0
	beq.s main
	bsr upcase
	lea cmdtab,a1
.l:
	move.w (a1)+,d1
	beq.s .bad
	move.l (a1)+,a2
	cmp.b d1,d0
	bne.s .l
	jsr (a2)
	bra.s main
.bad:
	bsr err
	bra.s main

cmdtab:
	dc.w 'D'
	dc.l cmd_d
	dc.w 'E'
	dc.l cmd_e
	dc.w 'F'
	dc.l cmd_f
	dc.w 'T'
	dc.l cmd_t
	dc.w 'M'
	dc.l cmd_m
	dc.w 'C'
	dc.l cmd_c
	dc.w 'S'
	dc.l cmd_s
	dc.w 'U'
	dc.l cmd_u
	dc.w 'G'
	dc.l cmd_g
	dc.w 'R'
	dc.l cmd_r
	dc.w '!'
	dc.l cmd_asm
	dc.w 'H'
	dc.l cmd_h
	dc.w 'B'
	dc.l cmd_b
	dc.w 'W'
	dc.l cmd_w
	dc.w '?'
	dc.l cmd_help
	dc.w 0

err:
	PUTCH '?'
crlf:
	move.l d0,-(sp)
	moveq #13,d0
	bsr putc
	move.l (sp)+,d0
	rts

space:
	PUTCH ' '
	rts

; ---------------------------------------------------------------- console i/o

; print D0.B, on the screen or (when v_buf is set) into the output buffer. keeps all registers
putc:
	tst.b v_buf
	bne.s .buf
	move.b d0,IO_CON_CHAROUT
	move.b d0,IO_CON_REGISTER
	rts
.buf:
	move.l a0,-(sp)
	move.l v_out,a0
	move.b d0,(a0)+
	move.l a0,v_out
	move.l (sp)+,a0
	rts

; print the zero terminated string that follows the call. keeps all registers
pstr:
	move.l a0,-(sp)
	move.l d0,-(sp)
	move.l 8(sp),a0
.l:
	move.b (a0)+,d0
	beq.s .e
	bsr putc
	bra.s .l
.e:
	move.l a0,d0
	addq.l #1,d0
	and.b #$fe,d0
	move.l d0,8(sp)
	move.l (sp)+,d0
	move.l (sp)+,a0
	rts

; print the zero terminated string at A0. keeps all registers
puts:
	movem.l d0/a0,-(sp)
.l:
	move.b (a0)+,d0
	beq.s .e
	bsr putc
	bra.s .l
.e:
	movem.l (sp)+,d0/a0
	rts

; print D0 in hex: long, 24 bit address, word, byte, nibble. keep all registers
phex32:
	swap d0
	bsr phex16
	swap d0
	bra.s phex16
phex24:
	swap d0
	bsr phex8
	swap d0
phex16:
	ror.w #8,d0
	bsr phex8
	rol.w #8,d0
phex8:
	move.l d0,-(sp)
	lsr.b #4,d0
	bsr pnib
	move.l (sp),d0
	bsr pnib
	move.l (sp)+,d0
	rts
pnib:					; this one changes D0
	and.b #$0f,d0
	cmp.b #10,d0
	bcs.s pdig
	addq.b #7,d0
pdig:					; print digit D0, changes D0
	add.b #'0',d0
	bra putc

; wait for a key, return it in D0
getc:
	tst.b IO_KEYQ_SIZE
	beq.s getc
	moveq #0,d0
	move.b IO_KEYQ_WAITING,d0
	move.b d0,IO_KEYQ_DEQUEUE
	rts

; read a line into linebuf (backspace edits). returns A0 = linebuf
getline:
	movem.l d0-d1,-(sp)
	lea linebuf,a0
	moveq #0,d1
.l:
	bsr getc
	cmp.b #13,d0
	beq.s .cr
	cmp.b #8,d0
	beq.s .bs
	cmp.b #$20,d0
	bcs.s .l
	cmp.w #76,d1
	bcc.s .l
	move.b d0,(a0)+
	addq.w #1,d1
	bsr putc
	bra.s .l
.bs:
	tst.w d1
	beq.s .l
	subq.w #1,d1
	subq.l #1,a0
	PUTS <8,' ',8>
	bra.s .l
.cr:
	clr.b (a0)
	bsr crlf
	movem.l (sp)+,d0-d1
	lea linebuf,a0
	rts

; ---------------------------------------------------------------- parsing

skipsp:				; skip spaces at A0
	cmp.b #' ',(a0)
	bne.s .e
	addq.l #1,a0
	bra.s skipsp
.e:
	rts

upcase:				; fold D0.B to upper case
	cmp.b #'a',d0
	bcs.s .e
	cmp.b #'z'+1,d0
	bcc.s .e
	sub.b #$20,d0
.e:
	rts

; parse a hex number (an optional $, then digits) at A0 into D0. carry set if there was none
gethex:
	bsr skipsp
	movem.l d1-d2,-(sp)
	cmp.b #'$',(a0)
	bne.s .s
	addq.l #1,a0
.s:
	moveq #0,d0
	moveq #0,d2
.l:
	move.b (a0),d1
	bsr hexval
	bcs.s .e
	lsl.l #4,d0
	or.b d1,d0
	addq.l #1,a0
	addq.w #1,d2
	bra.s .l
.e:
	cmp.w #1,d2			; carry if no digits
	movem.l (sp)+,d1-d2
	rts

; character in D1.B to a nibble, carry set if not hex
hexval:
	cmp.b #'a',d1
	bcs.s .u
	sub.b #$20,d1
.u:
	sub.b #'0',d1
	bcs.s .no
	cmp.b #10,d1
	bcs.s .ok
	subq.b #7,d1
	cmp.b #10,d1
	bcs.s .no
	cmp.b #16,d1
	bcc.s .no
.ok:
	andi.b #$fe,ccr
	rts
.no:
	ori.b #1,ccr
	rts

; parse an optional start into v_cur, and an optional end into v_end. the end defaults
; to start+D1
getse:
	bsr gethex
	bcs.s .s
	move.l d0,v_cur
.s:
	bsr gethex
	bcc.s .e
	move.l v_cur,d0
	add.l d1,d0
.e:
	move.l d0,v_end
	rts

; ---------------------------------------------------------------- commands

cmd_d:
	moveq #$7f,d1
	bsr getse
	move.l v_cur,a2
.line:
	move.l a2,d0
	bsr phex24
	PUTCH ':'
	move.l a2,a3
	moveq #15,d2
.hex:
	bsr space
	move.b (a3)+,d0
	bsr phex8
	dbra d2,.hex
	bsr space
	bsr space
	moveq #15,d2
.asc:
	move.b (a2)+,d0
	cmp.b #$20,d0
	bcs.s .dot
	cmp.b #$7f,d0
	bcs.s .ok
.dot:
	moveq #'.',d0
.ok:
	bsr putc
	dbra d2,.asc
	bsr crlf
	cmpa.l v_end,a2
	bls.s .line
	move.l a2,v_cur
	rts

cmd_e:
	bsr gethex
	bcs.s .s
	move.l d0,v_cur
.s:
	move.l v_cur,a2
.l:
	bsr gethex
	bcs.s .e
	move.b d0,(a2)+
	bra.s .l
.e:
	move.l a2,v_cur
	rts

cmd_f:
	moveq #0,d1
	bsr getse
	bsr gethex
	bcs err
	move.l v_cur,a2
.l:
	move.b d0,(a2)+
	cmpa.l v_end,a2
	bls.s .l
	rts

cmd_t:
	moveq #0,d1
	bsr getse
	bsr gethex
	bcs err
	move.l d0,a3			; destination
	move.l v_cur,a2			; source
	move.l v_end,d2
	sub.l a2,d2			; count - 1
	bcs err
	cmpa.l a2,a3
	bhi.s .back			; destination above source: copy backwards
.f:
	move.b (a2)+,(a3)+
	subq.l #1,d2
	bcc.s .f
	rts
.back:
	addq.l #1,d2
	adda.l d2,a2
	adda.l d2,a3
.b:
	move.b -(a2),-(a3)
	subq.l #1,d2
	bne.s .b
	rts

; M mode: set the video mode (8 or 9) and clear the screen
cmd_m:
	bsr gethex
	bcs err
	cmp.l #8,d0
	beq.s setmode
	cmp.l #9,d0
	bne err
setmode:			; set video mode D0, cursor to the top left, clear the screen
	move.b d0,IO_VIDMODE
	move.b #0,IO_CON_CURSORH
	move.b #0,IO_CON_CURSORV
	move.b #' ',IO_CON_CHAROUT	; the clear screen fills with this character
	move.b d0,IO_CON_CLS		; any write clears the screen
	rts

cmd_c:
	moveq #0,d1
	bsr getse
	bsr gethex
	bcs err
	move.l d0,a3
	move.l v_cur,a2
.l:
	move.b (a2),d0
	cmp.b (a3),d0
	beq.s .n
	move.l a2,d0
	bsr phex24
	bsr space
	move.b (a2),d0
	bsr phex8
	bsr space
	bsr space
	move.l a3,d0
	bsr phex24
	bsr space
	move.b (a3),d0
	bsr phex8
	bsr crlf
.n:
	addq.l #1,a2
	addq.l #1,a3
	cmpa.l v_end,a2
	bls.s .l
	rts

cmd_s:
	moveq #0,d1
	bsr getse
	lea patbuf,a2
.p:
	bsr gethex
	bcs.s .pe
	move.b d0,(a2)+
	bra.s .p
.pe:
	move.l a2,d3
	sub.l #patbuf,d3		; pattern length
	beq err
	subq.w #1,d3
	move.l v_cur,a2
.l:
	lea patbuf,a1
	move.l a2,a3
	move.w d3,d2
.c:
	cmpm.b (a1)+,(a3)+
	bne.s .n
	dbra d2,.c
	move.l a2,d0
	bsr phex24
	bsr crlf
.n:
	addq.l #1,a2
	cmpa.l v_end,a2
	bls.s .l
	rts

cmd_g:
	bsr gethex
	bcs err
	move.l d0,a0
	jmp (a0)			; an RTS goes back to the main loop

cmd_r:
	tst.b r_valid
	beq err
	bra showregs

cmd_h:
	stop #$2700
	rts

; B: BASIC, cold start (a new, empty program). W: BASIC, warm start (keeps the program)
cmd_b:
	moveq #0,d0
	bra.s basic
cmd_w:
	moveq #4,d0
basic:
	lea BASIC+8,a0			; is it there?
	lea .sig(pc),a1
	moveq #7,d1
.c:
	cmpm.b (a0)+,(a1)+
	bne err
	dbra d1,.c
	lea BASIC,a0
	jmp (a0,d0.w)
.sig:
	dc.b "IMLBASIC"

cmd_help:
	PUTS <"D [s [e]]  dump",13>
	PUTS <"E a b..    enter",13>
	PUTS <"F s e b    fill",13>
	PUTS <"T s e d    move",13>
	PUTS <"M 8|9      video mode",13>
	PUTS <"C s e o    compare",13>
	PUTS <"S s e b..  search",13>
	PUTS <"U [s [e]]  unassemble",13>
	PUTS <"G a        go (JSR)",13>
	PUTS <"R          registers at the last exception",13>
	PUTS <"! [a]      assemble",13>
	PUTS <"H          halt",13>
	PUTS <"B          BASIC (cold start)",13>
	PUTS <"W          BASIC (warm start)",13>
	rts

; ---------------------------------------------------------------- exceptions

; every vector except TRAP #15 points to one of these. the return address tells which one.
stubs:
	rept 254
	dc.w $6100			; bsr.w exc_common
	dc.w exc_common-*
	endr

exc_common:
	movem.l d0-d7/a0-a6,r_regs
	move.l (sp)+,d0
	sub.l #stubs,d0
	lsr.l #2,d0
	addq.l #1,d0			; vector number
	move.w d0,r_vec
	cmp.w #3,d0
	bhi.s .g
	move.w (sp)+,r_fc		; bus and address errors have a longer frame
	move.l (sp)+,r_aa
	move.w (sp)+,r_ir
.g:
	move.w (sp)+,r_sr
	move.l (sp)+,r_pc
	move.l sp,r_ssp
	move.l usp,a0
	move.l a0,r_usp
	st r_valid
	lea STACK,sp
	clr.b v_buf
	tst.b IO_CON_CURSORH
	beq.s .c
	bsr crlf
.c:
	bsr excname
	bsr showregs
	bra main

; print the name of the exception in r_vec
excname:
	move.w r_vec,d1
	lea excnames,a0
	cmp.w #11,d1
	bhi.s .o
	subq.w #2,d1
	bra.s .sk
.s:
	tst.b (a0)+
	bne.s .s
.sk:
	dbra d1,.s
	bra.s .p
.o:
	lea s_trap,a0
	cmp.w #48,d1
	bcc.s .x
	cmp.w #32,d1
	bcc.s .p
	lea s_int,a0
	cmp.w #24,d1
	bhi.s .p
.x:
	lea s_exc,a0
.p:
	bsr puts
	PUTS " (VECTOR $"
	move.w r_vec,d0
	bsr phex8
	PUTCH ')'
	bra crlf

excnames:
	dc.b "BUS ERROR",0
	dc.b "ADDRESS ERROR",0
	dc.b "ILLEGAL INSTRUCTION",0
	dc.b "ZERO DIVIDE",0
	dc.b "CHK",0
	dc.b "TRAPV",0
	dc.b "PRIVILEGE VIOLATION",0
	dc.b "TRACE",0
	dc.b "LINE A",0
	dc.b "LINE F",0
s_trap:	dc.b "TRAP",0
s_int:	dc.b "INTERRUPT",0
s_exc:	dc.b "EXCEPTION",0
	even

; show the registers saved by the last exception
showregs:
	PUTS "PC="
	move.l r_pc,d0
	bsr phex32
	PUTS " SR="
	move.w r_sr,d0
	bsr phex16
	PUTS " USP="
	move.l r_usp,d0
	bsr phex32
	PUTS " SSP="
	move.l r_ssp,d0
	bsr phex32
	bsr crlf
	cmp.w #3,r_vec
	bhi.s .r
	PUTS "ACCESS="
	move.l r_aa,d0
	bsr phex32
	PUTS " IR="
	move.w r_ir,d0
	bsr phex16
	PUTS " FC="
	move.w r_fc,d0
	bsr phex16
	bsr crlf
.r:
	lea r_regs,a2
	PUTS "D0"
	moveq #7,d2
.d:
	bsr space
	move.l (a2)+,d0
	bsr phex32
	dbra d2,.d
	bsr crlf
	PUTS "A0"
	moveq #6,d2
.a:
	bsr space
	move.l (a2)+,d0
	bsr phex32
	dbra d2,.a
	bsr space
	move.l r_usp,d0			; A7 is the stack pointer of the interrupted mode
	btst #5,r_sr
	beq.s .u
	move.l r_ssp,d0
.u:
	bsr phex32
	bra crlf

; TRAP #15 system calls, function in D0.B
trap15:
	cmp.b #9,d0
	bhi.s .x
	move.l d0,-(sp)
	and.w #$ff,d0
	add.w d0,d0
	move.w .t(pc,d0.w),d0
	jsr .t(pc,d0.w)
	move.l (sp)+,d0
.x:
	rte
.t:
	dc.w t_putc-.t,t_getc-.t,t_puts-.t,t_hex8-.t,t_hex16-.t
	dc.w t_hex32-.t,crlf-.t,t_getline-.t,t_key-.t,t_exit-.t

t_putc:
	move.b d1,d0
	bra putc
t_getc:
	bsr getc
	move.b d0,d1
	rts
t_puts:
	move.l a0,-(sp)
	move.l a1,a0
	bsr puts
	move.l (sp)+,a0
	rts
t_hex8:
	move.b d1,d0
	bra phex8
t_hex16:
	move.w d1,d0
	bra phex16
t_hex32:
	move.l d1,d0
	bra phex32
t_getline:
	move.l a0,-(sp)
	bsr getline
	move.l a0,a1
	move.l (sp)+,a0
	rts
t_key:
	moveq #0,d1
	tst.b IO_KEYQ_SIZE
	beq.s .e
	move.b IO_KEYQ_WAITING,d1
	move.b d1,IO_KEYQ_DEQUEUE
.e:
	rts
t_exit:
	move.w #$2700,sr
	lea STACK,sp
	bra main

; ---------------------------------------------------------------- disassembler

; U [start [end]]: with an end address, disassemble up to it. otherwise disassemble
; as many instructions as the screen is tall minus 2 (the command line and the next prompt).
cmd_u:
	bsr gethex
	bcs.s .s
	move.l d0,v_cur
.s:
	bsr gethex
	bcc.s .range
	moveq #14,d3			; 40 columns: 17 rows
	cmp.b #9,IO_VIDMODE
	bne.s .f
	moveq #31,d3			; 80 columns: 34 rows
.f:
	move.l v_cur,a4
.fl:
	bsr dline
	dbra d3,.fl
	move.l a4,v_cur
	rts
.range:
	move.l d0,v_end
	move.l v_cur,a4
.rl:
	bsr dline
	cmpa.l v_end,a4
	bls.s .rl
	move.l a4,v_cur
	rts

; print the address, the words and the disassembly of the instruction at A4.
; A4 advances to the next instruction. keeps the other registers
dline:
	movem.l d0-d2/a0/a3,-(sp)
	move.l a4,a3
	bsr disasm
	move.l a3,d0
	bsr phex24
	bsr space
	bsr space
	moveq #4,d2			; up to 5 words
.w:
	cmpa.l a4,a3
	bcc.s .pad
	move.b (a3)+,d0
	lsl.w #8,d0
	move.b (a3)+,d0
	bsr phex16
	bsr space
	bra.s .n
.pad:
	PUTS "     "
.n:
	dbra d2,.w
	lea outbuf,a0
	bsr puts
	bsr crlf
	movem.l (sp)+,d0-d2/a0/a3
	rts

; read the word at A4 (it may be at an odd address) into D0
getw:
	moveq #0,d0
	move.b (a4)+,d0
	lsl.w #8,d0
	move.b (a4)+,d0
	rts

getl:
	move.l d1,-(sp)
	bsr getw
	move.w d0,d1
	swap d1
	bsr getw
	move.w d0,d1
	move.l d1,d0
	move.l (sp)+,d1
	rts

; disassemble the instruction at A4 into outbuf as zero terminated text.
; A4 advances to the next instruction. keeps the other registers.
; while decoding: A3 = instruction address, A5 = table entry, D7 = opcode, D6 = size
; (0 = B, 1 = W, 2 = L), D5 = condition
disasm:
	movem.l d0-d7/a0-a3/a5,-(sp)
	move.l #outbuf,v_out
	st v_buf
	move.l a4,a3
	bsr getw
	move.w d0,d7
	lea itab,a5
.next:
	tst.b (a5)
	beq.s .unk
	move.w d7,d1
	and.w 10(a5),d1
	cmp.w 8(a5),d1
	bne.s .skip
	bsr dcheck
	bcc.s .found
.skip:
	lea 16(a5),a5
	bra.s .next
.unk:
	PUTS "DC.W    $"
	move.w d7,d0
	bsr phex16
	bra.s .done
.found:
	bsr dprint
.done:
	moveq #0,d0
	bsr putc
	clr.b v_buf
	movem.l (sp)+,d0-d7/a0-a3/a5
	rts

; check that the opcode in D7 really is the instruction of entry A5: sets D6 and D5.
; carry set if not
dcheck:
	moveq #0,d0
	move.b 12(a5),d0
	bsr dsize
	bcs.s .bad
	btst #2,15(a5)			; F_NOB
	beq.s .c
	tst.w d6
	beq.s .bad
.c:
	moveq #0,d5
	bsr findcc
	bcc.s .o
	move.w d7,d5
	lsr.w #8,d5
	and.w #15,d5
	btst #1,15(a5)			; F_NOCC01
	beq.s .o
	cmp.w #2,d5
	bcs.s .bad
.o:
	moveq #0,d0
	move.b 13(a5),d0
	bsr dvalid
	bcs.s .bad
	moveq #0,d0
	move.b 14(a5),d0
	bsr dvalid
	bcs.s .bad
	andi.b #$fe,ccr
	rts
.bad:
	ori.b #1,ccr
	rts

; operand size for size code D0 and opcode D7 into D6. carry set if invalid
dsize:
	moveq #1,d6
	tst.w d0
	beq.s .ok
	cmp.w #SZ_STD,d0
	bne.s .1
	move.w d7,d6
	lsr.w #6,d6
	and.w #3,d6
	cmp.w #3,d6
	beq.s .bad
	bra.s .ok
.1:
	cmp.w #SZ_MOVE,d0
	bne.s .2
	move.w d7,d6
	rol.w #4,d6
	and.w #3,d6
	beq.s .bad
	cmp.w #2,d6
	beq.s .ok
	subq.w #1,d6			; 1 = B -> 0, 3 = W -> 2
	beq.s .ok
	moveq #1,d6
	bra.s .ok
.2:
	cmp.w #SZ_B6,d0
	bne.s .3
	btst #6,d7
	beq.s .ok
	moveq #2,d6
	bra.s .ok
.3:
	cmp.w #SZ_B8,d0
	bne.s .4
	btst #8,d7
	beq.s .ok
	moveq #2,d6
	bra.s .ok
.4:
	cmp.w #SZ_BR,d0
	beq.s .ok
	move.w d0,d6
	subq.w #SZ_FB,d6
.ok:
	andi.b #$fe,ccr
	rts
.bad:
	ori.b #1,ccr
	rts

; carry set if the name of entry A5 has a condition (@). keeps all registers
findcc:
	movem.l d0/a0,-(sp)
	move.l a5,a0
	moveq #7,d0
.l:
	cmp.b #'@',(a0)+
	beq.s .y
	dbra d0,.l
	movem.l (sp)+,d0/a0
	andi.b #$fe,ccr
	rts
.y:
	movem.l (sp)+,d0/a0
	ori.b #1,ccr
	rts

; check that operand kind D0 is valid for opcode D7 (size D6). carry set if not
dvalid:
	tst.w d0
	beq.s .ok
	cmp.w #20,d0
	bhi.s .ok
	movem.l d0-d2/a0,-(sp)
	move.w d0,d2
	bsr kfield
	bsr eai
	bcs.s .bad
	cmp.w #1,d0			; no byte access to an address register
	bne.s .m
	tst.w d6
	beq.s .bad
.m:
	cmp.w #11,d2
	bhi.s .ok2
	add.w d2,d2
	lea kmask-2,a0
	move.w 0(a0,d2.w),d1
	btst d0,d1
	beq.s .bad
.ok2:
	movem.l (sp)+,d0-d2/a0
.ok:
	andi.b #$fe,ccr
	rts
.bad:
	movem.l (sp)+,d0-d2/a0
	ori.b #1,ccr
	rts

; allowed mode indexes for the effective address kinds 1-11
kmask:
	dc.w $fff,$ffd,$ffc,$7e4,$1ff,$1fd,$1fc,$7fd,$1f4,$7ec,$1fd
; addressing mode of the register kinds 12-20
kmode:
	dc.b 0,0,1,1,4,4,3,3,5,0

; mode/register field of operand kind D0 (1-20) from opcode D7, into D0
kfield:
	cmp.w #11,d0
	bcs.s .ea
	beq.s .md
	move.l d1,-(sp)
	move.l a0,-(sp)
	lea kmode-12,a0
	move.w d0,d1
	moveq #0,d0
	move.b 0(a0,d1.w),d0
	lsl.w #3,d0
	btst #0,d1
	bne.s .9
	move.w d7,d1
	bra.s .r
.9:
	move.w d7,d1
	lsr.w #8,d1
	lsr.w #1,d1
.r:
	and.w #7,d1
	or.w d1,d0
	move.l (sp)+,a0
	move.l (sp)+,d1
	rts
.ea:
	move.w d7,d0
	and.w #$3f,d0
	rts
.md:
	move.l d1,-(sp)
	move.w d7,d0
	lsr.w #8,d0
	lsr.w #1,d0
	and.w #7,d0
	move.w d7,d1
	lsr.w #3,d1
	and.w #$38,d1
	or.w d1,d0
	move.l (sp)+,d1
	rts

; mode/register field D0 to a mode index (0-11) in D0. carry set if invalid
eai:
	move.l d1,-(sp)
	move.w d0,d1
	lsr.w #3,d1
	and.w #7,d1
	cmp.w #7,d1
	beq.s .7
	move.w d1,d0
	bra.s .ok
.7:
	and.w #7,d0
	cmp.w #4,d0
	bhi.s .bad
	addq.w #7,d0
.ok:
	move.l (sp)+,d1
	andi.b #$fe,ccr
	rts
.bad:
	move.l (sp)+,d1
	ori.b #1,ccr
	rts

; print the instruction for entry A5
dprint:
	move.l a5,a0
	moveq #7,d2
.n:
	move.b (a0)+,d0
	cmp.b #' ',d0
	beq.s .sfx
	cmp.b #'@',d0
	bne.s .c
	bsr pcc
	bra.s .nx
.c:
	bsr putc
.nx:
	dbra d2,.n
.sfx:
	move.b 12(a5),d0
	beq.s .pad
	cmp.b #SZ_B8,d0
	bhi.s .br
	PUTCH '.'
	lea szch,a0
	move.b 0(a0,d6.w),d0
	bsr putc
	bra.s .pad
.br:
	cmp.b #SZ_BR,d0
	bne.s .pad
	PUTCH '.'
	moveq #'S',d0
	tst.b d7
	bne.s .bs
	moveq #'W',d0
.bs:
	bsr putc
.pad:
	move.l v_out,d0
	sub.l #outbuf,d0
	cmp.w #8,d0
	bcc.s .ops
	PUTCH ' '
	bra.s .pad
.ops:
	moveq #0,d0
	move.b 13(a5),d0
	beq.s .end
	btst #0,15(a5)			; F_REV
	bne.s .rev
	bsr dop
	moveq #0,d0
	move.b 14(a5),d0
	beq.s .end
	PUTCH ','
	bsr dop
.end:
	rts
.rev:
	move.l v_out,-(sp)		; the first operand goes into tmpbuf
	move.l #tmpbuf,v_out
	bsr dop
	moveq #0,d0
	bsr putc
	move.l (sp)+,v_out
	moveq #0,d0
	move.b 14(a5),d0
	bsr dop
	PUTCH ','
	lea tmpbuf,a0
	bra puts

szch:
	dc.b "BWL",0

; print condition D5. keeps all registers
pcc:
	movem.l d0/a0,-(sp)
	lea cctab,a0
	move.w d5,d0
	add.w d0,d0
	adda.w d0,a0
	move.b (a0)+,d0
	bsr putc
	move.b (a0),d0
	cmp.b #' ',d0
	beq.s .x
	bsr putc
.x:
	movem.l (sp)+,d0/a0
	rts

cctab:
	dc.b "T F HILSCCCSNEEQVCVSPLMIGELTGTLE"
	dc.b "HSLO"			; aliases for CC and CS
	even

; print operand kind D0. reads extension words at A4. may change D0-D1/A0-A1
dop:
	cmp.w #20,d0
	bhi.s .ne
	bsr kfield
	bra dea
.ne:
	sub.w #21,d0
	add.w d0,d0
	move.w .t(pc,d0.w),d0
	jmp .t(pc,d0.w)
.t:
	dc.w dimm-.t,d_q3-.t,d_q8-.t,d_vec-.t,d_disp8-.t,d_disp16-.t
	dc.w d_rlist-.t,d_ccr-.t,d_sr-.t,d_usp-.t,d_immb-.t,d_immw-.t

d_q3:
	PUTCH '#'
	move.w d7,d0
	lsr.w #8,d0
	lsr.w #1,d0
	and.w #7,d0
	bne.s .p
	moveq #8,d0
.p:
	bra pdig
d_q8:
	PUTCH '#'
	move.w d7,d0
	bra psx8
d_vec:
	PUTCH '#'
	PUTCH '$'
	move.w d7,d0
	bra pnib
d_disp8:
	move.b d7,d0
	ext.w d0
	ext.l d0
	tst.b d7
	bne.s .s
	bsr getw
	ext.l d0
.s:
	add.l a3,d0
	addq.l #2,d0
	PUTCH '$'
	bra phex24
d_disp16:
	bsr getw
	ext.l d0
	add.l a3,d0
	addq.l #2,d0
	PUTCH '$'
	bra phex24
d_rlist:
	bsr getw
	move.w d7,d1
	and.w #$38,d1
	cmp.w #$20,d1			; -(An): the list is reversed
	bne.s .p
	bsr rev16
.p:
	bra prlist
d_ccr:
	PUTS "CCR"
	rts
d_sr:
	PUTS "SR"
	rts
d_usp:
	PUTS "USP"
	rts
d_immb:
	PUTCH '#'
	PUTCH '$'
	bsr getw
	bra phex8
d_immw:
	PUTCH '#'
	PUTCH '$'
	bsr getw
	bra phex16

; print an immediate of size D6
dimm:
	PUTCH '#'
	PUTCH '$'
	cmp.w #2,d6
	beq.s .l
	bsr getw
	tst.w d6
	beq phex8
	bra phex16
.l:
	bsr getl
	bra phex32

; print D0.W as a signed hex word
psx16:
	move.l d0,-(sp)
	tst.w d0
	bpl.s .p
	PUTCH '-'
	neg.w d0
.p:
	PUTCH '$'
	bsr phex16
	move.l (sp)+,d0
	rts

; print D0.B as a signed hex byte
psx8:
	move.l d0,-(sp)
	tst.b d0
	bpl.s .p
	PUTCH '-'
	neg.b d0
.p:
	PUTCH '$'
	bsr phex8
	move.l (sp)+,d0
	rts

; print register D0 (0-7 = D0-D7, 8-15 = A0-A7)
prreg:
	move.l d0,-(sp)
	cmp.w #8,d0
	bcc.s .a
	PUTCH 'D'
	bra.s .n
.a:
	PUTCH 'A'
	subq.w #8,d0
.n:
	bsr pdig
	move.l (sp)+,d0
	rts

; reverse the 16 bits of D0
rev16:
	movem.l d1-d2,-(sp)
	moveq #15,d2
	moveq #0,d1
.l:
	lsr.w #1,d0
	roxl.w #1,d1
	dbra d2,.l
	move.w d1,d0
	movem.l (sp)+,d1-d2
	rts

; print register list D0 (bit 0 = D0 ... bit 15 = A7)
prlist:
	movem.l d0-d4,-(sp)
	move.w d0,d3
	moveq #0,d1
	moveq #0,d4
.l:
	cmp.w #16,d1
	bcc.s .x
	btst d1,d3
	beq.s .nx
	move.w d1,d2			; find the end of the run, not crossing from D7 to A0
.e:
	cmp.w #7,d2
	beq.s .pe
	cmp.w #15,d2
	beq.s .pe
	move.w d2,d0
	addq.w #1,d0
	btst d0,d3
	beq.s .pe
	addq.w #1,d2
	bra.s .e
.pe:
	tst.w d4
	beq.s .f
	PUTCH '/'
.f:
	moveq #1,d4
	move.w d1,d0
	bsr prreg
	cmp.w d1,d2
	beq.s .one
	PUTCH '-'
	move.w d2,d0
	bsr prreg
.one:
	move.w d2,d1
.nx:
	addq.w #1,d1
	bra.s .l
.x:
	movem.l (sp)+,d0-d4
	rts

; print effective address field D0 for an operand of size D6. reads extension words at A4
dea:
	movem.l d0-d3,-(sp)
	move.w d0,d1
	and.w #7,d1
	lsr.w #3,d0
	and.w #7,d0
	add.w d0,d0
	move.w .t(pc,d0.w),d0
	jmp .t(pc,d0.w)
.t:
	dc.w .m0-.t,.m1-.t,.m2-.t,.m3-.t,.m4-.t,.m5-.t,.m6-.t,.m7-.t
.m0:
	PUTCH 'D'
	move.w d1,d0
	bsr pdig
	bra .x
.m1:
	bsr .an
	bra .x
.m2:
	bsr .ind
	bra .x
.m3:
	bsr .ind
	PUTCH '+'
	bra .x
.m4:
	PUTCH '-'
	bsr .ind
	bra .x
.m5:
	bsr getw
	bsr psx16
	bsr .ind
	bra .x
.m6:
	bsr getw
	move.w d0,d2
	bsr psx8
	PUTCH '('
	bsr .an
	bsr .idx
	bra .x
.m7:
	cmp.w #1,d1
	bcs.s .aw
	beq.s .al
	cmp.w #3,d1
	bcs.s .pc
	beq.s .pcx
	bsr dimm
	bra .x
.aw:
	PUTCH '$'
	bsr getw
	bsr phex16
	PUTS ".W"
	bra .x
.al:
	PUTCH '$'
	bsr getl
	bsr phex32
	bra .x
.pc:
	move.l a4,d2
	bsr getw
	ext.l d0
	add.l d2,d0
	PUTCH '$'
	bsr phex24
	PUTS "(PC)"
	bra .x
.pcx:
	move.l a4,d3
	bsr getw
	move.w d0,d2
	ext.w d0
	ext.l d0
	add.l d3,d0
	PUTCH '$'
	bsr phex24
	PUTS "(PC"
	bsr .idx
.x:
	movem.l (sp)+,d0-d3
	rts
.an:					; print An, register D1
	PUTCH 'A'
	move.w d1,d0
	bra pdig
.ind:					; print (An)
	PUTCH '('
	bsr .an
	PUTCH ')'
	rts
.idx:					; print ,Xn.S) from extension word D2
	PUTCH ','
	move.w d2,d0
	rol.w #4,d0
	and.w #15,d0
	bsr prreg
	PUTCH '.'
	moveq #'W',d0
	btst #11,d2
	beq.s .iw
	moveq #'L',d0
.iw:
	bsr putc
	PUTCH ')'
	rts

; ---------------------------------------------------------------- mini-assembler
;
; Like the Apple II mini-assembler. Each line is assembled at the current address and
; shown as a disassembly. "addr:" at the start of a line sets the address. An empty
; line leaves the assembler. Numbers are hex, with a leading $ or starting with a digit
; (so $A0 is a number and A0 is a register), and may have a leading minus sign.
; Absolute addresses are long unless written with .W; branch and PC relative operands
; are written as the target address. DC.B, DC.W and DC.L store a single value.

cmd_asm:
	bsr gethex
	bcs.s .l
	move.l d0,v_cur
.l:
	move.l v_cur,d0
	bsr phex24
	PUTCH '>'
	bsr space
	bsr getline
	bsr skipsp
	tst.b (a0)
	beq.s .x			; empty line: back to the monitor
	move.l a0,a2
	bsr gethex
	bcs.s .na
	cmp.b #':',(a0)
	bne.s .na
	addq.l #1,a0			; "addr:" sets the address
	move.l d0,v_cur
	bsr skipsp
	tst.b (a0)
	beq.s .l
	bra.s .as
.na:
	move.l a2,a0
.as:
	bsr norm
	bsr asmline
	bcc.s .l
	bsr err
	bra.s .l
.x:
	rts

; copy the line at A0 to inbuf: upper case, and no spaces except one after the mnemonic
norm:
	lea inbuf,a1
	moveq #0,d1			; space pending
	moveq #0,d2			; mnemonic finished
.l:
	move.b (a0)+,d0
	beq.s .e
	cmp.b #' ',d0
	bne.s .c
	tst.b d2
	bne.s .l
	cmpa.l #inbuf,a1
	beq.s .l			; leading space
	moveq #1,d1
	bra.s .l
.c:
	tst.b d1
	beq.s .u
	move.b #' ',(a1)+
	moveq #0,d1
	moveq #1,d2
.u:
	bsr upcase
	move.b d0,(a1)+
	bra.s .l
.e:
	clr.b (a1)
	rts

; assemble inbuf at v_cur. carry set if it can't be assembled
asmline:
	lea inbuf,a0
	lea a_name,a1
	moveq #7,d1
.f:
	move.b #' ',(a1)+
	dbra d1,.f
	lea a_name,a1
	moveq #0,d1
.m:
	move.b (a0),d0
	cmp.b #'A',d0
	bcs.s .me
	cmp.b #'Z',d0
	bhi.s .me
	cmp.w #8,d1
	bcc .bad
	move.b d0,(a1)+
	addq.w #1,d1
	addq.l #1,a0
	bra.s .m
.me:
	tst.w d1
	beq .bad
	clr.b a_sfx
	cmp.b #'.',(a0)
	bne.s .ns
	addq.l #1,a0
	move.b (a0)+,a_sfx
.ns:
	cmp.b #' ',(a0)
	bne.s .np
	addq.l #1,a0
.np:
	clr.b a_nops
	clr.b opnd1
	clr.b opnd2
	tst.b (a0)
	beq.s .go
	lea opnd1,a1
	bsr parseop
	bcs .bad
	move.b #1,a_nops
	cmp.b #',',(a0)
	bne.s .e
	addq.l #1,a0
	lea opnd2,a1
	bsr parseop
	bcs .bad
	move.b #2,a_nops
.e:
	tst.b (a0)
	bne .bad
.go:
	bsr asmdc			; DC.B/W/L
	bcc.s .ok
	lea itab,a5
.t:
	tst.b (a5)
	beq.s .bad
	bsr namematch
	bcs.s .sk
	bsr aenc
	bcc.s .ok
.sk:
	lea 16(a5),a5
	bra.s .t
.ok:
	move.l v_cur,a2			; store the instruction
	lea abuf,a1
	move.w a_len,d1
	subq.w #1,d1
.c:
	move.b (a1)+,(a2)+
	dbra d1,.c
	move.l v_cur,a4			; and show what was assembled
	bsr dline
	move.l a2,v_cur
	andi.b #$fe,ccr
	rts
.bad:
	ori.b #1,ccr
	rts

; DC.B, DC.W, DC.L with one value into abuf. carry set if the line is something else
asmdc:
	cmp.l #'DC  ',a_name
	bne.s .no
	cmp.l #'    ',a_name+4
	bne.s .no
	cmp.b #1,a_nops
	bne.s .no
	lea opnd1,a1
	cmp.b #T_EA,(a1)
	bne.s .no
	cmp.b #8,O_MI(a1)		; a bare number
	bne.s .no
	move.l O_VAL(a1),d0
	move.b a_sfx,d1
	cmp.b #'B',d1
	beq.s .b
	cmp.b #'L',d1
	beq.s .l
	tst.b d1
	beq.s .w
	cmp.b #'W',d1
	bne.s .no
.w:
	bsr fitsw
	bcs.s .no
	move.w d0,abuf
	moveq #2,d0
	bra.s .s
.l:
	move.l d0,abuf
	moveq #4,d0
	bra.s .s
.b:
	bsr fitsb
	bcs.s .no
	move.b d0,abuf
	moveq #1,d0
.s:
	move.w d0,a_len
	andi.b #$fe,ccr
	rts
.no:
	ori.b #1,ccr
	rts

; carry clear if the name of entry A5 matches a_name (a condition is put in a_cc)
namematch:
	lea a_name,a0
	move.l a5,a1
	moveq #7,d1
.l:
	move.b (a1)+,d0
	cmp.b #'@',d0
	beq.s .cc
	cmp.b (a0)+,d0
	bne.s .no
	dbra d1,.l
	bra.s .yes
.cc:
	lea cctab,a2
	moveq #0,d2
.cl:
	move.b (a2),d0
	cmp.b (a0),d0
	bne.s .cn
	move.b 1(a2),d0
	cmp.b 1(a0),d0
	bne.s .cn
	cmp.b #' ',d0
	beq.s .cf			; one letter condition (T, F)
	cmp.b #' ',2(a0)
	bne.s .cn
.cf:
	cmp.w #16,d2
	bcs.s .cs
	sub.w #12,d2			; HS = CC, LO = CS
.cs:
	move.b d2,a_cc
.yes:
	andi.b #$fe,ccr
	rts
.cn:
	addq.l #2,a2
	addq.w #1,d2
	cmp.w #18,d2
	bcs.s .cl
.no:
	ori.b #1,ccr
	rts

; encode the parsed instruction as entry A5 into abuf. carry set if it doesn't fit.
; D7 = opcode being built, D6 = size, A4 = extension word output
aenc:
	moveq #0,d0
	tst.b 13(a5)
	beq.s .c
	addq.w #1,d0
	tst.b 14(a5)
	beq.s .c
	addq.w #1,d0
.c:
	cmp.b a_nops,d0
	bne afail
	moveq #0,d7
	move.w 8(a5),d7
	moveq #0,d1
	move.b 12(a5),d1
	move.b a_sfx,d0
	bsr asize
	bcs afail
	bsr findcc
	bcc.s .nc
	moveq #0,d0
	move.b a_cc,d0
	btst #1,15(a5)			; F_NOCC01
	beq.s .cc
	cmp.w #2,d0
	bcs afail
.cc:
	lsl.w #8,d0
	or.w d0,d7
.nc:
	lea abuf+2,a4
	lea opnd1,a1
	lea opnd2,a2
	btst #0,15(a5)			; F_REV
	beq.s .o
	exg a1,a2
.o:
	moveq #0,d0
	move.b 13(a5),d0
	beq.s .done
	bsr aop
	bcs afail
	exg a1,a2
	moveq #0,d0
	move.b 14(a5),d0
	beq.s .done
	bsr aop
	bcs afail
.done:
	move.w d7,abuf
	move.l a4,d0
	sub.l #abuf,d0
	move.w d0,a_len
aok:
	andi.b #$fe,ccr
	rts
afail:
	ori.b #1,ccr
	rts

; size for size code D1 and suffix D0 into D6, and its bits into D7. carry set if invalid
asize:
	tst.b d1
	bne.s .1
	moveq #1,d6
	tst.b d0
	bne afail
	bra aok
.1:
	cmp.b #SZ_B8,d1
	bhi.s .fix
	moveq #1,d6			; variable size: W unless given
	tst.b d0
	beq.s .v
	moveq #0,d6
	cmp.b #'B',d0
	beq.s .v
	moveq #1,d6
	cmp.b #'W',d0
	beq.s .v
	moveq #2,d6
	cmp.b #'L',d0
	bne afail
.v:
	tst.w d6
	bne.s .v2
	cmp.b #SZ_B6,d1			; B6 and B8 have no byte size
	bcc afail
	btst #2,15(a5)			; F_NOB
	bne afail
.v2:
	cmp.b #SZ_STD,d1
	bne.s .v3
	move.w d6,d0
	lsl.w #6,d0
	or.w d0,d7
	bra aok
.v3:
	cmp.b #SZ_MOVE,d1
	bne.s .v4
	lea mvsz,a0
	move.w d6,d0
	add.w d0,d0
	move.w 0(a0,d0.w),d0
	or.w d0,d7
	bra aok
.v4:
	cmp.w #2,d6
	bne aok
	cmp.b #SZ_B6,d1
	bne.s .v5
	or.w #$40,d7
	bra aok
.v5:
	or.w #$100,d7
	bra aok
.fix:
	cmp.b #SZ_BR,d1
	bne.s .f2
	moveq #1,d6
	tst.b d0
	beq aok
	cmp.b #'S',d0
	beq aok
	cmp.b #'B',d0
	beq aok
	cmp.b #'W',d0
	beq aok
	bra afail
.f2:
	move.w d1,d6
	subq.w #SZ_FB,d6
	tst.b d0
	beq aok
	lea szch,a0
	cmp.b 0(a0,d6.w),d0
	beq aok
	bra afail

mvsz:
	dc.w $1000,$3000,$2000

; encode operand A1 as kind D0 (A2 is the other operand). carry set if it doesn't fit
aop:
	cmp.w #20,d0
	bhi aop_ne
	cmp.b #T_EA,(a1)
	bne afail
	moveq #0,d1
	move.b O_MI(a1),d1
	cmp.w #1,d1			; no byte access to an address register
	bne.s .1
	tst.w d6
	beq afail
.1:
	cmp.w #11,d0
	bhi.s .fx
	lea kmask-2,a0
	move.w d0,d2
	add.w d2,d2
	move.w 0(a0,d2.w),d2
	btst d1,d2
	beq afail
	bsr mkfield
	cmp.w #11,d0
	beq.s .md
	or.w d2,d7
	bra.s aext
.md:
	move.w d2,d3			; MOVE destination: register in 11-9, mode in 8-6
	and.w #7,d3
	lsl.w #8,d3
	add.w d3,d3
	or.w d3,d7
	and.w #$38,d2
	lsl.w #3,d2
	or.w d2,d7
	bra.s aext
.fx:
	lea kmode-12,a0
	cmp.b 0(a0,d0.w),d1
	bne afail
	moveq #0,d2
	move.b O_REG(a1),d2
	btst #0,d0
	beq.s .r0
	lsl.w #8,d2
	add.w d2,d2
.r0:
	or.w d2,d7
				; fall through
; store the extension words of effective address A1 (size D6) at A4
aext:
	moveq #0,d1
	move.b O_MI(a1),d1
	move.l O_VAL(a1),d0
	cmp.w #5,d1
	bcs aok
	beq.s .w16
	cmp.w #6,d1
	beq.s .ix
	cmp.w #7,d1
	beq.s .aw
	cmp.w #8,d1
	beq.s .l
	cmp.w #9,d1
	beq.s .pc
	cmp.w #10,d1
	beq.s .pcx
	bra.s aimm
.w16:
	bsr fits16
	bcs afail
	move.w d0,(a4)+
	bra aok
.ix:
	bsr fits8
	bcs afail
	bra.s ixw
.aw:
	bsr fitsw
	bcs afail
	move.w d0,(a4)+
	bra aok
.l:
	move.l d0,(a4)+
	bra aok
.pc:
	bsr pcdisp
	bsr fits16
	bcs afail
	move.w d0,(a4)+
	bra aok
.pcx:
	bsr pcdisp
	bsr fits8
	bcs afail
ixw:					; index extension word: displacement D0, register from A1
	and.w #$ff,d0
	moveq #0,d2
	move.b O_X(a1),d2
	move.w d2,d3
	and.w #15,d2
	ror.w #4,d2
	btst #4,d3
	beq.s .w
	or.w #$800,d2
.w:
	or.w d2,d0
	move.w d0,(a4)+
	bra aok

; immediate D0 of size D6
aimm:
	tst.w d6
	bne.s .w
	bsr fitsb
	bcs afail
	and.w #$ff,d0
	move.w d0,(a4)+
	bra aok
.w:
	cmp.w #1,d6
	bne.s .l
	bsr fitsw
	bcs afail
	move.w d0,(a4)+
	bra aok
.l:
	move.l d0,(a4)+
	bra aok

; target D0 to a displacement from the extension word about to be stored at A4
pcdisp:
	move.l a4,d2
	sub.l #abuf,d2
	add.l v_cur,d2
	sub.l d2,d0
	rts

; mode/register field of operand A1 into D2
mkfield:
	moveq #0,d2
	move.b O_MI(a1),d2
	cmp.w #7,d2
	bcc.s .7
	lsl.w #3,d2
	or.b O_REG(a1),d2
	rts
.7:
	add.w #$38-7,d2
	rts

; range checks on D0, carry set if it doesn't fit. keep D0
fits16:					; signed word
	move.l d2,-(sp)
	move.w d0,d2
	ext.l d2
	bra.s fitcmp
fits8:					; signed byte
	move.l d2,-(sp)
	move.b d0,d2
	ext.w d2
	ext.l d2
fitcmp:
	cmp.l d0,d2
	movem.l (sp)+,d2		; MOVEM keeps the flags
	beq aok
	bra afail
fitsw:					; signed or unsigned word
	cmp.l #$ffff,d0
	bls aok
	bra.s fits16
fitsb:					; signed or unsigned byte
	cmp.l #$ff,d0
	bls aok
	bra.s fits8

aop_ne:
	sub.w #21,d0
	add.w d0,d0
	move.w .t(pc,d0.w),d0
	jmp .t(pc,d0.w)
.t:
	dc.w a_imm-.t,a_q3-.t,a_q8-.t,a_vec-.t,a_d8-.t,a_d16-.t
	dc.w a_rl-.t,a_ccr-.t,a_sr-.t,a_usp-.t,a_immb-.t,a_immw-.t

; operand A1 must be #imm: its value into D0
a_isimm:
	cmp.b #T_EA,(a1)
	bne afail
	cmp.b #11,O_MI(a1)
	bne afail
	move.l O_VAL(a1),d0
	bra aok
a_imm:
	bsr a_isimm
	bcs afail
	bra aimm
a_immb:
	bsr a_isimm
	bcs afail
	bsr fitsb
	bcs afail
	and.w #$ff,d0
	move.w d0,(a4)+
	bra aok
a_immw:
	bsr a_isimm
	bcs afail
	bsr fitsw
	bcs afail
	move.w d0,(a4)+
	bra aok
a_q3:
	bsr a_isimm
	bcs afail
	subq.l #1,d0
	cmp.l #7,d0
	bhi afail
	addq.w #1,d0
	and.w #7,d0
	lsl.w #8,d0
	add.w d0,d0
	or.w d0,d7
	bra aok
a_q8:
	bsr a_isimm
	bcs afail
	bsr fitsb
	bcs afail
	and.w #$ff,d0
	or.w d0,d7
	bra aok
a_vec:
	bsr a_isimm
	bcs afail
	cmp.l #15,d0
	bhi afail
	or.w d0,d7
	bra aok
; operand A1 must be an address: displacement from the opcode + 2 into D0
a_isaddr:
	cmp.b #T_EA,(a1)
	bne afail
	cmp.b #7,O_MI(a1)
	beq.s .y
	cmp.b #8,O_MI(a1)
	bne afail
.y:
	move.l O_VAL(a1),d0
	sub.l v_cur,d0
	subq.l #2,d0
	bra aok
a_d16:
	bsr a_isaddr
	bcs afail
	bsr fits16
	bcs afail
	move.w d0,(a4)+
	bra aok
a_d8:
	bsr a_isaddr
	bcs afail
	move.b a_sfx,d1
	cmp.b #'W',d1
	beq.s .w
	tst.b d1
	beq.s .a
	tst.l d0			; .S: must fit in the opcode
	beq afail
	bsr fits8
	bcs afail
	bra.s .s
.a:
	tst.l d0			; no size: short if it fits
	beq.s .w
	bsr fits8
	bcs.s .w
.s:
	and.w #$ff,d0
	or.w d0,d7
	bra aok
.w:
	bsr fits16
	bcs afail
	move.w d0,(a4)+
	bra aok
a_rl:
	cmp.b #T_RL,(a1)
	beq.s .m
	cmp.b #T_EA,(a1)		; a single register
	bne afail
	cmp.b #1,O_MI(a1)
	bhi afail
	moveq #0,d1
	move.b O_REG(a1),d1
	tst.b O_MI(a1)
	beq.s .d
	addq.w #8,d1
.d:
	moveq #0,d0
	bset d1,d0
	bra.s .c
.m:
	move.l O_VAL(a1),d0
.c:
	cmp.b #T_EA,(a2)		; -(An): the list is reversed
	bne.s .s
	cmp.b #4,O_MI(a2)
	bne.s .s
	bsr rev16
.s:
	move.w d0,(a4)+
	bra aok
a_ccr:
	cmp.b #T_CCR,(a1)
	bne afail
	bra aok
a_sr:
	cmp.b #T_SR,(a1)
	bne afail
	bra aok
a_usp:
	cmp.b #T_USP,(a1)
	bne afail
	bra aok

; parse the operand at A0 into A1. A0 stops at the ',' or the end. carry set if invalid
parseop:
	movem.l d1-d5/a2-a3,-(sp)
	clr.l (a1)
	clr.l O_VAL(a1)
	move.b #T_EA,(a1)
	move.b (a0),d0
	cmp.b #'#',d0
	bne.s .kw
	addq.l #1,a0			; #imm
	bsr getnum
	bcs .bad
	move.l d0,O_VAL(a1)
	move.b #11,O_MI(a1)
	bra .ok
.kw:
	lea kwtab,a2			; CCR, SR, USP
.k:
	move.b (a2)+,d1
	beq.s .nkw
	move.l a0,a3
.kc:
	move.b (a2)+,d0
	beq.s .ke
	cmp.b (a3)+,d0
	beq.s .kc
.ks:
	tst.b (a2)+
	bne.s .ks
	bra.s .k
.ke:
	move.b (a3),d0
	beq.s .kok
	cmp.b #',',d0
	bne.s .k
.kok:
	move.b d1,(a1)
	move.l a3,a0
	bra .ok
.nkw:
	bsr preg
	bcs.s .nr
	cmp.b #'-',(a0)
	beq.s .rl
	cmp.b #'/',(a0)
	beq.s .rl
	cmp.w #8,d0			; Dn or An
	bcs.s .dn
	move.b #1,O_MI(a1)
.dn:
	and.b #7,d0
	move.b d0,O_REG(a1)
	bra .ok
.rl:					; register list
	moveq #0,d3
.rr:
	move.w d0,d4
	move.w d0,d5
	cmp.b #'-',(a0)
	bne.s .rs
	addq.l #1,a0
	bsr preg
	bcs .bad
	move.w d0,d5
	cmp.w d4,d5
	bcs .bad
.rs:
	bset d4,d3
	addq.w #1,d4
	cmp.w d5,d4
	bls.s .rs
	cmp.b #'/',(a0)
	bne.s .re
	addq.l #1,a0
	bsr preg
	bcs .bad
	bra.s .rr
.re:
	move.b #T_RL,(a1)
	move.l d3,O_VAL(a1)
	bra .ok
.nr:
	move.b (a0),d0
	cmp.b #'-',d0			; -(An)
	bne.s .np
	cmp.b #'(',1(a0)
	bne.s .np
	addq.l #2,a0
	bsr pan
	bcs .bad
	cmp.b #')',(a0)+
	bne .bad
	move.b d0,O_REG(a1)
	move.b #4,O_MI(a1)
	bra .ok
.np:
	moveq #0,d2			; displacement
	moveq #0,d3			; no number given
	cmp.b #'(',d0
	beq.s .par
	bsr getnum
	bcs .bad
	move.l d0,d2
	moveq #1,d3
	cmp.b #'(',(a0)
	beq.s .par
	move.l d2,O_VAL(a1)		; absolute
	moveq #8,d1
	cmp.b #'.',(a0)
	bne.s .abs
	move.b 1(a0),d0
	addq.l #2,a0
	cmp.b #'L',d0
	beq.s .abs
	moveq #7,d1
	cmp.b #'W',d0
	bne .bad
.abs:
	move.b d1,O_MI(a1)
	bra .ok
.par:
	addq.l #1,a0
	move.l d2,O_VAL(a1)
	cmp.b #'P',(a0)
	bne.s .an
	cmp.b #'C',1(a0)
	bne.s .an
	addq.l #2,a0
	moveq #9,d1			; d16(PC)
	bra.s .aft
.an:
	bsr pan
	bcs .bad
	move.b d0,O_REG(a1)
	moveq #5,d1			; d16(An)
.aft:
	cmp.b #')',(a0)
	bne.s .idx
	addq.l #1,a0
	tst.w d3
	bne.s .mi
	cmp.w #9,d1			; no displacement: (An) or (An)+
	beq .bad
	moveq #2,d1
	cmp.b #'+',(a0)
	bne.s .mi
	addq.l #1,a0
	moveq #3,d1
.mi:
	move.b d1,O_MI(a1)
	bra.s .ok
.idx:
	cmp.b #',',(a0)+
	bne.s .bad
	bsr preg
	bcs.s .bad
	cmp.b #'.',(a0)
	bne.s .xw
	addq.l #1,a0
	move.b (a0)+,d4
	cmp.b #'W',d4
	beq.s .xw
	cmp.b #'L',d4
	bne.s .bad
	bset #4,d0
.xw:
	move.b d0,O_X(a1)
	cmp.b #')',(a0)+
	bne.s .bad
	addq.w #1,d1			; d8(An,Xn) or d8(PC,Xn)
	move.b d1,O_MI(a1)
.ok:
	movem.l (sp)+,d1-d5/a2-a3
	andi.b #$fe,ccr
	rts
.bad:
	movem.l (sp)+,d1-d5/a2-a3
	ori.b #1,ccr
	rts

kwtab:
	dc.b T_CCR,"CCR",0
	dc.b T_SR,"SR",0
	dc.b T_USP,"USP",0
	dc.b 0
	even

; parse a register at A0: D0 = 0-7 for D0-D7, 8-15 for A0-A7 (SP = A7). carry set if none
preg:
	move.l d1,-(sp)
	move.b (a0),d0
	cmp.b #'S',d0
	bne.s .r
	cmp.b #'P',1(a0)
	bne.s .no
	moveq #15,d0
	bra.s .e
.r:
	moveq #0,d1
	cmp.b #'D',d0
	beq.s .n
	moveq #8,d1
	cmp.b #'A',d0
	bne.s .no
.n:
	move.b 1(a0),d0
	sub.b #'0',d0
	bcs.s .no
	cmp.b #8,d0
	bcc.s .no
	and.w #7,d0
	add.w d1,d0
.e:
	move.b 2(a0),d1			; must not run on into a name or number
	cmp.b #'0',d1
	bcs.s .y
	cmp.b #'9',d1
	bls.s .no
	cmp.b #'A',d1
	bcs.s .y
	cmp.b #'Z',d1
	bls.s .no
.y:
	addq.l #2,a0
	move.l (sp)+,d1
	andi.b #$fe,ccr
	rts
.no:
	move.l (sp)+,d1
	ori.b #1,ccr
	rts

; parse an address register at A0 into D0 (0-7). carry set if none
pan:
	bsr preg
	bcs.s .x
	sub.w #8,d0			; a data register leaves carry set
.x:
	rts

; parse a number at A0 into D0: optional -, then $ and hex digits, or hex digits starting
; with a decimal digit. carry set if none
getnum:
	movem.l d1-d3,-(sp)
	moveq #0,d3
	cmp.b #'-',(a0)
	bne.s .s
	addq.l #1,a0
	moveq #1,d3
.s:
	cmp.b #'$',(a0)
	beq.s .h
	move.b (a0),d1
	cmp.b #'0',d1
	bcs.s .bad
	cmp.b #'9',d1
	bhi.s .bad
	bra.s .p
.h:
	addq.l #1,a0
.p:
	moveq #0,d0
	moveq #0,d2
.l:
	move.b (a0),d1
	bsr hexval
	bcs.s .e
	lsl.l #4,d0
	or.b d1,d0
	addq.l #1,a0
	addq.w #1,d2
	bra.s .l
.e:
	tst.w d2
	beq.s .bad
	tst.w d3
	beq.s .ok
	neg.l d0
.ok:
	movem.l (sp)+,d1-d3
	andi.b #$fe,ccr
	rts
.bad:
	movem.l (sp)+,d1-d3
	ori.b #1,ccr
	rts

; ---------------------------------------------------------------- instruction table
;
; name (@ = condition), match, mask, size code, operand 1, operand 2, flags.
; The disassembler takes the first entry whose match/mask fits and whose operands are
; valid; the assembler takes the first entry with the name whose operands fit.

itab:
	INS "ORI",$003c,$ffff,SZ_FB,K_IMM,K_CCR,0
	INS "ORI",$007c,$ffff,SZ_FW,K_IMM,K_SR,0
	INS "ORI",$0000,$ff00,SZ_STD,K_IMM,K_EDALT,0
	INS "ANDI",$023c,$ffff,SZ_FB,K_IMM,K_CCR,0
	INS "ANDI",$027c,$ffff,SZ_FW,K_IMM,K_SR,0
	INS "ANDI",$0200,$ff00,SZ_STD,K_IMM,K_EDALT,0
	INS "SUBI",$0400,$ff00,SZ_STD,K_IMM,K_EDALT,0
	INS "ADDI",$0600,$ff00,SZ_STD,K_IMM,K_EDALT,0
	INS "EORI",$0a3c,$ffff,SZ_FB,K_IMM,K_CCR,0
	INS "EORI",$0a7c,$ffff,SZ_FW,K_IMM,K_SR,0
	INS "EORI",$0a00,$ff00,SZ_STD,K_IMM,K_EDALT,0
	INS "CMPI",$0c00,$ff00,SZ_STD,K_IMM,K_EDALT,0
	INS "MOVEP",$0108,$f1b8,SZ_B6,K_DA0,K_DN9,0
	INS "MOVEP",$0188,$f1b8,SZ_B6,K_DN9,K_DA0,0
	INS "BTST",$0100,$f1c0,SZ_NONE,K_DN9,K_EDATA,0
	INS "BCHG",$0140,$f1c0,SZ_NONE,K_DN9,K_EDALT,0
	INS "BCLR",$0180,$f1c0,SZ_NONE,K_DN9,K_EDALT,0
	INS "BSET",$01c0,$f1c0,SZ_NONE,K_DN9,K_EDALT,0
	INS "BTST",$0800,$ffc0,SZ_NONE,K_IMMB,K_EBTST,0
	INS "BCHG",$0840,$ffc0,SZ_NONE,K_IMMB,K_EDALT,0
	INS "BCLR",$0880,$ffc0,SZ_NONE,K_IMMB,K_EDALT,0
	INS "BSET",$08c0,$ffc0,SZ_NONE,K_IMMB,K_EDALT,0
	INS "MOVEA",$0040,$c1c0,SZ_MOVE,K_EALL,K_AN9,F_NOB
	INS "MOVE",$0000,$c000,SZ_MOVE,K_EALL,K_MDST,0
	INS "MOVE",$40c0,$ffc0,SZ_FW,K_SR,K_EDALT,0
	INS "MOVE",$44c0,$ffc0,SZ_FW,K_EDATA,K_CCR,0
	INS "MOVE",$46c0,$ffc0,SZ_FW,K_EDATA,K_SR,0
	INS "MOVE",$4e60,$fff8,SZ_FL,K_AN0,K_USP,0
	INS "MOVE",$4e68,$fff8,SZ_FL,K_USP,K_AN0,0
	INS "NEGX",$4000,$ff00,SZ_STD,K_EDALT,0,0
	INS "CLR",$4200,$ff00,SZ_STD,K_EDALT,0,0
	INS "NEG",$4400,$ff00,SZ_STD,K_EDALT,0,0
	INS "NOT",$4600,$ff00,SZ_STD,K_EDALT,0,0
	INS "EXT",$4880,$ffb8,SZ_B6,K_DN0,0,0
	INS "NBCD",$4800,$ffc0,SZ_FB,K_EDALT,0,0
	INS "SWAP",$4840,$fff8,SZ_NONE,K_DN0,0,0
	INS "PEA",$4840,$ffc0,SZ_FL,K_ECTRL,0,0
	INS "ILLEGAL",$4afc,$ffff,SZ_NONE,0,0,0
	INS "TAS",$4ac0,$ffc0,SZ_FB,K_EDALT,0,0
	INS "TST",$4a00,$ff00,SZ_STD,K_EDALT,0,0
	INS "TRAP",$4e40,$fff0,SZ_NONE,K_VEC,0,0
	INS "LINK",$4e50,$fff8,SZ_NONE,K_AN0,K_IMMW,0
	INS "UNLK",$4e58,$fff8,SZ_NONE,K_AN0,0,0
	INS "RESET",$4e70,$ffff,SZ_NONE,0,0,0
	INS "NOP",$4e71,$ffff,SZ_NONE,0,0,0
	INS "STOP",$4e72,$ffff,SZ_NONE,K_IMMW,0,0
	INS "RTE",$4e73,$ffff,SZ_NONE,0,0,0
	INS "RTS",$4e75,$ffff,SZ_NONE,0,0,0
	INS "TRAPV",$4e76,$ffff,SZ_NONE,0,0,0
	INS "RTR",$4e77,$ffff,SZ_NONE,0,0,0
	INS "JSR",$4e80,$ffc0,SZ_NONE,K_ECTRL,0,0
	INS "JMP",$4ec0,$ffc0,SZ_NONE,K_ECTRL,0,0
	INS "MOVEM",$4880,$ff80,SZ_B6,K_RLIST,K_EMMR,0
	INS "MOVEM",$4c80,$ff80,SZ_B6,K_RLIST,K_EMRM,F_REV
	INS "LEA",$41c0,$f1c0,SZ_FL,K_ECTRL,K_AN9,0
	INS "CHK",$4180,$f1c0,SZ_FW,K_EDATA,K_DN9,0
	INS "DBRA",$51c8,$fff8,SZ_NONE,K_DN0,K_DISP16,0
	INS "DB@",$50c8,$f0f8,SZ_NONE,K_DN0,K_DISP16,0
	INS "S@",$50c0,$f0c0,SZ_FB,K_EDALT,0,0
	INS "ADDQ",$5000,$f100,SZ_STD,K_Q3,K_EALT,0
	INS "SUBQ",$5100,$f100,SZ_STD,K_Q3,K_EALT,0
	INS "BRA",$6000,$ff00,SZ_BR,K_DISP8,0,0
	INS "BSR",$6100,$ff00,SZ_BR,K_DISP8,0,0
	INS "B@",$6000,$f000,SZ_BR,K_DISP8,0,F_NOCC01
	INS "MOVEQ",$7000,$f100,SZ_FL,K_Q8,K_DN9,0
	INS "DIVU",$80c0,$f1c0,SZ_FW,K_EDATA,K_DN9,0
	INS "DIVS",$81c0,$f1c0,SZ_FW,K_EDATA,K_DN9,0
	INS "SBCD",$8100,$f1f8,SZ_FB,K_DN0,K_DN9,0
	INS "SBCD",$8108,$f1f8,SZ_FB,K_PD0,K_PD9,0
	INS "OR",$8000,$f100,SZ_STD,K_EDATA,K_DN9,0
	INS "OR",$8100,$f100,SZ_STD,K_DN9,K_EMALT,0
	INS "SUBA",$90c0,$f0c0,SZ_B8,K_EALL,K_AN9,0
	INS "SUBX",$9100,$f138,SZ_STD,K_DN0,K_DN9,0
	INS "SUBX",$9108,$f138,SZ_STD,K_PD0,K_PD9,0
	INS "SUB",$9000,$f100,SZ_STD,K_EALL,K_DN9,0
	INS "SUB",$9100,$f100,SZ_STD,K_DN9,K_EMALT,0
	INS "CMPA",$b0c0,$f0c0,SZ_B8,K_EALL,K_AN9,0
	INS "CMPM",$b108,$f138,SZ_STD,K_PI0,K_PI9,0
	INS "CMP",$b000,$f100,SZ_STD,K_EALL,K_DN9,0
	INS "EOR",$b100,$f100,SZ_STD,K_DN9,K_EDALT,0
	INS "MULU",$c0c0,$f1c0,SZ_FW,K_EDATA,K_DN9,0
	INS "MULS",$c1c0,$f1c0,SZ_FW,K_EDATA,K_DN9,0
	INS "ABCD",$c100,$f1f8,SZ_FB,K_DN0,K_DN9,0
	INS "ABCD",$c108,$f1f8,SZ_FB,K_PD0,K_PD9,0
	INS "EXG",$c140,$f1f8,SZ_NONE,K_DN9,K_DN0,0
	INS "EXG",$c148,$f1f8,SZ_NONE,K_AN9,K_AN0,0
	INS "EXG",$c188,$f1f8,SZ_NONE,K_DN9,K_AN0,0
	INS "AND",$c000,$f100,SZ_STD,K_EDATA,K_DN9,0
	INS "AND",$c100,$f100,SZ_STD,K_DN9,K_EMALT,0
	INS "ADDA",$d0c0,$f0c0,SZ_B8,K_EALL,K_AN9,0
	INS "ADDX",$d100,$f138,SZ_STD,K_DN0,K_DN9,0
	INS "ADDX",$d108,$f138,SZ_STD,K_PD0,K_PD9,0
	INS "ADD",$d000,$f100,SZ_STD,K_EALL,K_DN9,0
	INS "ADD",$d100,$f100,SZ_STD,K_DN9,K_EMALT,0
	INS "ASR",$e0c0,$ffc0,SZ_FW,K_EMALT,0,0
	INS "ASL",$e1c0,$ffc0,SZ_FW,K_EMALT,0,0
	INS "LSR",$e2c0,$ffc0,SZ_FW,K_EMALT,0,0
	INS "LSL",$e3c0,$ffc0,SZ_FW,K_EMALT,0,0
	INS "ROXR",$e4c0,$ffc0,SZ_FW,K_EMALT,0,0
	INS "ROXL",$e5c0,$ffc0,SZ_FW,K_EMALT,0,0
	INS "ROR",$e6c0,$ffc0,SZ_FW,K_EMALT,0,0
	INS "ROL",$e7c0,$ffc0,SZ_FW,K_EMALT,0,0
	INS "ASR",$e000,$f138,SZ_STD,K_Q3,K_DN0,0
	INS "ASR",$e020,$f138,SZ_STD,K_DN9,K_DN0,0
	INS "ASL",$e100,$f138,SZ_STD,K_Q3,K_DN0,0
	INS "ASL",$e120,$f138,SZ_STD,K_DN9,K_DN0,0
	INS "LSR",$e008,$f138,SZ_STD,K_Q3,K_DN0,0
	INS "LSR",$e028,$f138,SZ_STD,K_DN9,K_DN0,0
	INS "LSL",$e108,$f138,SZ_STD,K_Q3,K_DN0,0
	INS "LSL",$e128,$f138,SZ_STD,K_DN9,K_DN0,0
	INS "ROXR",$e010,$f138,SZ_STD,K_Q3,K_DN0,0
	INS "ROXR",$e030,$f138,SZ_STD,K_DN9,K_DN0,0
	INS "ROXL",$e110,$f138,SZ_STD,K_Q3,K_DN0,0
	INS "ROXL",$e130,$f138,SZ_STD,K_DN9,K_DN0,0
	INS "ROR",$e018,$f138,SZ_STD,K_Q3,K_DN0,0
	INS "ROR",$e038,$f138,SZ_STD,K_DN9,K_DN0,0
	INS "ROL",$e118,$f138,SZ_STD,K_Q3,K_DN0,0
	INS "ROL",$e138,$f138,SZ_STD,K_DN9,K_DN0,0
	dc.b 0
	even

; ---------------------------------------------------------------- end

; BASIC (basic.bin) is loaded at the next $1000 boundary after the monitor
romend:
BASIC		equ	(romend+$fff)&$fffff000
