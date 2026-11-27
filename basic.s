; IML BASIC for the 68000 (see docs/basic68.md)
;
; Assemble with vasm (Motorola syntax):
;   vasmm68k_mot -Fbin -m68000 -opt-brajmp -DBASE=<address> -o basic.bin basic.s
; BASE is the next $1000 boundary above the end of the monitor; the Makefile works it out
; from the size of mrom.bin, and m68k.c loads basic.bin there.
;
; Entry points: BASE+0 cold start (clears everything), BASE+4 warm start (keeps the program
; and the variables). The monitor's B and W commands call them, and MONITOR (or BYE) goes
; back to the monitor.
;
; Memory: everything BASIC keeps is between LOMEM and HIMEM (default $10000-$16ffff), so
; that block can be saved with bsave and loaded back with bload:
;   LOMEM            BASIC's internal variables, buffers and FOR/GOSUB/WHILE/REPEAT stack
;   LOMEM+D_SIZE     the program, growing up
;   after it         the string heap, growing up
;   ...              free; temporary strings are made at the top of the free space
;   HIMEM            the variable table, growing down from HIMEM
; The long at $001000 holds LOMEM, so that the warm start can find it.
;
; Registers while BASIC runs: A5 = text pointer, A6 = LOMEM (the internal variables).
; Every other register is scratch: a routine can change D0-D7/A0-A4 unless it says it doesn't.

	ifnd BASE
BASE	equ	$1c3000
	endif

; ---------------------------------------------------------------- hardware

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
IO_VIDMODE	equ	IO+$20
IO_RANDBYTE	equ	IO+$21

FP_INIT		equ	IO+$40		; FP commands: bit 6 = 0 FACC / 1 FARG, $20 = 80 bit
FP_MUL		equ	IO+$42
FP_DIV		equ	IO+$43
FP_ADD		equ	IO+$44
FP_SUB		equ	IO+$45
FP_LN		equ	IO+$46
FP_ILOAD	equ	IO+$47
FP_EXP		equ	IO+$49
FP_SIN		equ	IO+$4a
FP_COS		equ	IO+$4b
FP_TAN		equ	IO+$4c
FP_ATN		equ	IO+$4d
FP_POW		equ	IO+$4e
FP_CMP		equ	IO+$4f
FP_FROMA	equ	IO+$50
FP_TOA		equ	IO+$51
FP_FUNC		equ	IO+$52		; low bits: 0 log10 1 sqrt 2 abs 3 neg 4 floor 5 ceil 6 trunc 7 round 8 asin 9 acos
FP_CLASS	equ	IO+$53		; FPCOND: 1 zero, 2 negative, $10 NaN, $20 infinite
FP_ISAVEC	equ	IO+$54		; to FPINT, FPCOND $20 if out of range
FP_TOAF		equ	IO+$55		; fixed point text, low bits = decimals
FP_TOAE		equ	IO+$56		; exponent text
FPCOND		equ	$1bfcbf
FPASCII		equ	$1bfcc0
FPINT		equ	$1bfcd8
FPACC		equ	$1bfce0
FPARG		equ	$1bfcf0
X		equ	$20		; extended (80 bit) operation on FACC
XA		equ	$60		; extended operation on FARG

BPTR		equ	$1000		; LOMEM of the BASIC in memory (for the warm start)
STACKTOP	equ	$10000		; the 68000 stack (shared with the monitor)
STKLIMIT	equ	$3000		; expressions nested deeper than this: FORMULA TOO COMPLEX
DEF_LOMEM	equ	$10000
DEF_HIMEM	equ	$16ffff
RAMTOP		equ	$180000		; video memory starts here
MAGIC		equ	'IMLE'		; (changes when the layout of the block does)

; ---------------------------------------------------------------- internal variables (at LOMEM, A6)

D_MAGIC		equ	0
D_LOMEM		equ	4		; where this block was set up (checked by the warm start)
D_HIMEM		equ	8		; HIMEM as given (last usable byte)
D_MEMTOP	equ	12		; HIMEM+1, even: the variable table grows down from here
D_PRGEND	equ	16		; the zero word that ends the program
D_VARBOT	equ	20		; bottom of the variable table
D_STRBOT	equ	24		; string heap: start
D_STRTOP	equ	28		; string heap: next free byte
D_TMPPTR	equ	32		; temporary strings: grow down from VARBOT, reset every statement
D_GARBAGE	equ	36		; bytes of dead strings in the heap
D_CURLIN	equ	40		; line being run (D_DIRBUF for a direct command)
D_STMT		equ	44		; start of the statement being run
D_CSP		equ	48		; control stack pointer (grows down)
D_DATLIN	equ	52		; READ position: line,
D_DATPTR	equ	56		; and text pointer
D_CONTLIN	equ	60		; CONT: line,
D_CONTPTR	equ	64		; and text pointer (0 = can't continue)
D_GCROOT	equ	68		; garbage collection: one more string pointer to update
D_FORVAR	equ	72		; FOR: variable address
D_INSAVE	equ	76		; INPUT: start of the statement, to redo it
D_SWDEFP	equ	80		; SWITCH: DEFAULT text pointer (0 = none),
D_SWDEFL	equ	84		; and line
D_SLIF		equ	88		; .b running the THEN part of a one line IF
D_TRACE		equ	89		; .b TRON
D_DATIN		equ	90		; .b READ: 0 = find a DATA statement, 1 = at its first item, 2 = after an item
D_FORKIND	equ	92		; .w FOR: variable kind
D_NAMELEN	equ	94		; .w name just parsed
D_NAME		equ	96		; 32 bytes
D_VA		equ	128		; value accumulator (16 bytes)
D_VB		equ	144		; left operand
D_VC		equ	160		; scratch value
D_VZERO		equ	176		; 16 zero bytes: the value of a missing array element
D_SWVAL		equ	192		; SWITCH value
D_FORLIM	equ	208		; FOR limit
D_FORSTEP	equ	224		; FOR step
D_WORK		equ	240		; 8 bytes
D_NUMBUF	equ	256		; 64 bytes: number to text
D_SCRATCH	equ	320		; 64 bytes: text to number
D_WORD		equ	384		; 64 bytes: keyword being crunched
D_GARG		equ	448		; 8 longs: graphics statement arguments
D_GCNT		equ	480		; .w how many
D_GRCOLOR	equ	482		; .w GRCOLOR
D_GW		equ	484		; .w screen width in pixels
D_GH		equ	486		; .w height
D_GROW		equ	488		; .w bytes per row
D_GDEEP		equ	490		; .b 1 = 4096 colors (2 bytes per pixel)
D_INBUF		equ	512		; 256 bytes: input line
D_ONERR		equ	1800		; ON ERROR GOTO line
D_ERRLIN	equ	1804		; the line (pointer) of the last trapped error
D_ERRSTMT	equ	1808		; and its statement
D_FNFRAME	equ	1812		; the innermost FN call's parameters (0 = none)
D_UFMT		equ	1816		; PRINT USING: the format,
D_UFLEN		equ	1820		; its length,
D_UPOS		equ	1824		; where we are in it
D_ERRNUM	equ	1828		; ERR
D_ERRLINE	equ	1832		; ERL
D_ERRCODE	equ	1836		; .w the error (our number)
D_ONERRF	equ	1838		; .b ON ERROR is set
D_INERR		equ	1839		; .b running an error handler
D_UNL		equ	1840		; .b PRINT USING: no new line at the end
D_UTYPE		equ	1841		; .b field: 1 number, 2 !, 3 \ \, 4 &
D_UBEF		equ	1842		; .w positions before the point
D_UDIG		equ	1844		; .w # positions before the point
D_UDEC		equ	1846		; .w digits after the point
D_UPT		equ	1848		; .b there is a point
D_UCOMMA	equ	1849		; .b commas
D_UPLUS		equ	1850		; .b leading +
D_UTRAIL	equ	1851		; .b trailing sign: 1 -, 2 +
D_USTAR		equ	1852		; .b ** fill
D_UDOLLAR	equ	1853		; .b $
D_UEXP		equ	1854		; .b ^^^^
D_UWID		equ	1856		; .w \ \ width
D_RNEW		equ	1860		; RENUM: new first number,
D_RFROM		equ	1864		; from this old line,
D_RSTEP		equ	1868		; step
D_LBLCNT	equ	1872		; .w labels in the cache
D_LBLOK		equ	1874		; .b 0 = no cache, 1 = all labels in it, 2 = too many for it
D_CRUNCH	equ	768		; 512 bytes: crunched program line
D_DIRBUF	equ	1280		; a direct command as a line: length, $ffff, text, then a zero word
D_CSTBOT	equ	2048		; control stack
D_CSTTOP	equ	10240
D_LBLTAB	equ	10240		; label cache: LBLMAX entries of LB_SIZE
D_SIZE		equ	16384		; the program starts here

; label cache entries (built when a label is first looked up, dropped when the program
; or the variables are cleared)
LB_NAME		equ	0		; the name, in the program text (after the *)
LB_LINE		equ	4		; the line it starts
LB_HASH		equ	8		; .w
LB_LEN		equ	10		; .w
LB_SIZE		equ	12
LBLMAX		equ	(D_SIZE-D_LBLTAB)/LB_SIZE

MAXLINE		equ	500		; crunched line length limit

; an FN call's parameters, on the stack: entries are laid out like variables
FN_PREV		equ	0		; the call outside this one
FN_CNT		equ	4		; .w parameters
FN_KIND		equ	6		; .w the function's kind
FN_CALLER	equ	8		; the caller's text pointer
FN_EXPR		equ	12		; the definition's expression
FN_ENT		equ	16
FN_ESIZE	equ	56		; size.l, kind.b, namelen.b, name (32), data (16)
FN_MAX		equ	8
FN_SIZE		equ	FN_ENT+FN_MAX*FN_ESIZE

; a program line: length.w (whole line, even), number.l, the crunched text, a zero
LNUM		equ	2		; offset of the line number
LH		equ	6		; offset of the text
DIRECT		equ	$ffffffff	; the line number of a direct command

; values: a 16 byte block. +0 type.w, +4 data: int64 (hi.l, lo.l), 80 bit float (Intel
; byte order, 10 bytes), or string (pointer.l, length.l)
T_INT		equ	1
T_FLT		equ	2
T_STR		equ	3

; variable kinds (the suffix): %, &, none, $. Bit 7 set = array
K_INT		equ	1		; 32 bit integer (4 bytes)
K_LONG		equ	2		; 64 bit integer (8 bytes)
K_FLT		equ	3		; 80 bit float (10 bytes)
K_STR		equ	4		; string descriptor: pointer.l, length.l (8 bytes)

; variable table entry: size.l, kind.b, namelen.b, name (padded to even), data
; array data: ndims.w, count.l * ndims, elements
; string heap block: owner.l (the descriptor), length.l, the characters (padded to even)

; control stack frames
FRAME		equ	52
F_FOR		equ	1
F_GOSUB		equ	2
F_WHILE		equ	3
F_REPEAT	equ	4
FR_TYPE		equ	0		; .w
FR_KIND		equ	2		; .w FOR: variable kind
FR_VAR		equ	4		; FOR: variable address
FR_LINE		equ	8
FR_TEXT		equ	12
FR_LIMIT	equ	16		; FOR: limit value (16)
FR_STEP		equ	32		; FOR: step value (16)
FR_SLIF		equ	48		; .b

; operators for binop
OP_ADD		equ	1
OP_SUB		equ	2
OP_MUL		equ	3
OP_DIV		equ	4
OP_IDIV		equ	5
OP_MOD		equ	6
OP_POW		equ	7
OP_AND		equ	8
OP_OR		equ	9
OP_XOR		equ	10
OP_REL		equ	16		; relational: OP_REL + mask of 1 = equal, 2 = less, 4 = greater
OP_EQ		equ	OP_REL+1
OP_LT		equ	OP_REL+2
OP_LE		equ	OP_REL+3
OP_GT		equ	OP_REL+4
OP_GE		equ	OP_REL+5
OP_NE		equ	OP_REL+6

; error numbers (index into errmsgs)
E_SN		equ	0		; syntax
E_OM		equ	1		; out of memory
E_US		equ	2		; undefined statement (line)
E_TM		equ	3		; type mismatch
E_OV		equ	4		; overflow
E_DZ		equ	5		; division by zero
E_FC		equ	6		; illegal function call
E_NF		equ	7		; NEXT without FOR
E_RG		equ	8		; RETURN without GOSUB
E_OD		equ	9		; out of data
E_BS		equ	10		; bad subscript
E_DD		equ	11		; redimensioned array
E_LS		equ	12		; string too long
E_CN		equ	13		; can't continue
E_ST		equ	14		; formula too complex
E_WW		equ	15		; WEND without WHILE
E_UR		equ	16		; UNTIL without REPEAT
E_WH		equ	17		; WHILE without WEND
E_IF		equ	18		; IF without ENDIF
E_SW		equ	19		; SWITCH without ENDSWITCH
E_LL		equ	20		; line too long
E_UF		equ	21		; undefined function
E_RW		equ	22		; RESUME without error
E_UP		equ	23		; unprintable error (ERROR n with a number BASIC doesn't use)
E_ID		equ	24		; illegal direct
E_UL		equ	25		; undefined label
E_AN		equ	26		; array not dimensioned

; ---------------------------------------------------------------- tokens

TK_END		equ	$80		; statements, in the order of stmttab
TK_FOR		equ	$81
TK_NEXT		equ	$82
TK_DATA		equ	$83
TK_INPUT	equ	$84
TK_DIM		equ	$85
TK_READ		equ	$86
TK_LET		equ	$87
TK_GOTO		equ	$88
TK_RUN		equ	$89
TK_IF		equ	$8a
TK_RESTORE	equ	$8b
TK_GOSUB	equ	$8c
TK_RETURN	equ	$8d
TK_REM		equ	$8e
TK_STOP		equ	$8f
TK_ON		equ	$90
TK_POKE		equ	$91
TK_PRINT	equ	$92
TK_CONT		equ	$93
TK_LIST		equ	$94
TK_CLEAR	equ	$95
TK_NEW		equ	$96
TK_CLS		equ	$97
TK_LOCATE	equ	$98
TK_COLOR	equ	$99
TK_WHILE	equ	$9a
TK_WEND		equ	$9b
TK_REPEAT	equ	$9c
TK_UNTIL	equ	$9d
TK_SWITCH	equ	$9e
TK_CASE		equ	$9f
TK_DEFAULT	equ	$a0
TK_ENDSWITCH	equ	$a1
TK_ELSE		equ	$a2
TK_ENDIF	equ	$a3
TK_CALL		equ	$a4
TK_MONITOR	equ	$a5
TK_BYE		equ	$a6
TK_DELETE	equ	$a7
TK_RANDOMIZE	equ	$a8
TK_TRON		equ	$a9
TK_TROFF	equ	$aa
TK_LINE		equ	$ab
TK_APOS		equ	$ac		; ' (a REM)
TK_LOMEM	equ	$ad
TK_HIMEM	equ	$ae
TK_GR		equ	$af
TK_TEXT		equ	$b0
TK_GRCLS	equ	$b1
TK_PLOT		equ	$b2
TK_GRCOLOR	equ	$b3
TK_RECTANGLE	equ	$b4
TK_CIRCLE	equ	$b5
TK_FILLRECT	equ	$b6
TK_FILLCIRCLE	equ	$b7
TK_DEF		equ	$b8
TK_SWAP		equ	$b9
TK_RENUM	equ	$ba
TK_RESUME	equ	$bb
TK_ERROR	equ	$bc
TK_ELSEIF	equ	$bd
TK_LABELS	equ	$be
TK_ARRAYS	equ	$bf
TK_LASTST	equ	$bf		; last statement token
TK_THEN		equ	$c0		; other keywords
TK_TO		equ	$c1
TK_STEP		equ	$c2
TK_AND		equ	$c3
TK_OR		equ	$c4
TK_XOR		equ	$c5
TK_NOT		equ	$c6
TK_MOD		equ	$c7
TK_TAB		equ	$c8
TK_SPC		equ	$c9
TK_USING	equ	$ca
TK_FN		equ	$cb
TK_FIRSTFN	equ	$cc		; functions, in the order of fntab
TK_MID		equ	TK_FIRSTFN+27
TK_LASTFN	equ	$f3

; ---------------------------------------------------------------- macros

	macro ERROR
	moveq #\1,d0
	jmp error
	endm

; print the string that follows (zero terminated). keeps all registers
	macro PRINTS
	bsr pstr
	dc.b \1,0
	even
	endm

; ---------------------------------------------------------------- entry

	org BASE

	bra.w cold
	bra.w warm
	dc.b "IMLBASIC"			; the monitor and m68k.c look for this
	dc.l BASE			; where this was assembled for
	dc.w $0100			; version 1.0

cold:
	lea STACKTOP,sp
	move.l #DEF_LOMEM,a6
	move.l #DEF_HIMEM,d0
	bsr setup
	bsr do_new
	bsr banner
	bra ready

warm:
	lea STACKTOP,sp
	move.l BPTR,a6			; where BASIC was last
	bsr checkblock
	beq .ok
	move.l #DEF_LOMEM,a6		; or the default place (an image just loaded with bload)
	bsr checkblock
	bne cold
.ok:
	move.l a6,BPTR
	bsr checkprog			; the program could have been changed from outside
	beq .same
	PRINTS <"Program changed: variables cleared",13>
	bsr clear_all
.same:
	clr.b D_LBLOK(a6)
	clr.l D_CONTPTR(a6)
	lea D_CSTTOP(a6),a0
	move.l a0,D_CSP(a6)
	bsr banner
	bra ready

; is there a BASIC block at A6? Z set if so
checkblock:
	move.l a6,d0
	btst #0,d0
	bne .no
	cmp.l #DEF_LOMEM,d0
	bcs .no
	cmp.l #RAMTOP-D_SIZE,d0
	bcc .no
	cmp.l #MAGIC,D_MAGIC(a6)
	bne .no
	cmp.l D_LOMEM(a6),d0
	rts
.no:
	moveq #1,d0			; clear Z
	rts

; walk the program: Z set if it's intact and ends at D_PRGEND. Otherwise it's cut off at
; the first bad line (or emptied), D_PRGEND is updated and Z is clear
checkprog:
	lea D_SIZE(a6),a0
	move.l D_MEMTOP(a6),a2
	moveq #0,d3			; the next line number must be at least this
.l:
	move.w (a0),d0
	beq .end
	btst #0,d0
	bne .bad
	cmp.w #LH+1,d0
	bcs .bad
	move.l LNUM(a0),d1
	cmp.l #DIRECT,d1
	bcc .bad
	cmp.l d3,d1
	bcs .bad
	move.l d1,d3
	addq.l #1,d3
	lea (a0,d0.w),a1
	cmpa.l a2,a1
	bcc .bad
	move.l a1,a0
	bra .l
.bad:
	clr.w (a0)
.end:
	cmpa.l D_PRGEND(a6),a0
	beq .r
	move.l a0,D_PRGEND(a6)
	moveq #1,d0			; changed: clear Z
.r:
	rts

; set up an empty block at A6 with HIMEM D0
setup:
	move.l a6,BPTR
	move.l #MAGIC,D_MAGIC(a6)
	move.l a6,D_LOMEM(a6)
	move.l d0,D_HIMEM(a6)
	addq.l #1,d0
	and.b #$fe,d0
	move.l d0,D_MEMTOP(a6)
	clr.b D_TRACE(a6)
	move.w #$fff,D_GRCOLOR(a6)	; white in every mode
	lea D_VZERO(a6),a0
	clr.l (a0)+
	clr.l (a0)+
	clr.l (a0)+
	clr.l (a0)+
	rts

banner:
	PRINTS <"IML BASIC 68000 1.0",13>
	bsr fre
	bsr pint
	PRINTS <" bytes free",13>
	rts

; free bytes in D0:D1 (as an int64)
fre:
	move.l D_TMPPTR(a6),d1
	sub.l D_STRTOP(a6),d1
	add.l D_GARBAGE(a6),d1
	moveq #0,d0
	rts

; ---------------------------------------------------------------- command loop

ready:
	lea STACKTOP,sp
	bsr col0
	PRINTS <"Ready",13>
main:
	lea STACKTOP,sp
	move.l D_VARBOT(a6),D_TMPPTR(a6)
	bsr inputline
	bmi main			; Ctrl-C
	move.l a0,a5
	bsr peek
	beq main
	cmp.b #'0',d0
	bcs .direct
	cmp.b #'9'+1,d0
	bcs .number
.direct:
	lea D_DIRBUF+LH(a6),a1
	bsr crunch
	lea D_DIRBUF(a6),a0
	move.l a1,d0
	sub.l a0,d0
	addq.l #1,d0
	and.b #$fe,d0
	move.w d0,(a0)
	move.l #DIRECT,LNUM(a0)
	clr.w (a0,d0.w)			; no line after it
	move.l a0,D_CURLIN(a6)
	lea LH(a0),a5
	clr.b D_SLIF(a6)
	jmp newstmt

.number:
	bsr linenum
	move.l d0,d7
	bsr skipsp
	lea D_CRUNCH(a6),a1
	bsr crunch
	lea D_CRUNCH(a6),a0
	move.l a1,d6
	sub.l a0,d6			; length with the final zero
	cmp.l #1,d6
	bne .ins
	moveq #0,d6			; no text: delete the line
.ins:
	bsr edit_line
	bsr clear_all
	clr.l D_CONTPTR(a6)
	bra main

; parse a line number at A5 into D0 (0-4294967294). keeps D2-D7
linenum:
	bsr peek
	cmp.b #'0',d0
	bcs .sn
	cmp.b #'9'+1,d0
	bcc .sn
	move.l d2,-(sp)
	moveq #0,d0
	moveq #0,d1
.l:
	move.b (a5),d1
	sub.b #'0',d1
	bcs .e
	cmp.b #10,d1
	bcc .e
	addq.l #1,a5
	cmp.l #429496729,d0		; *10 would overflow
	bhi .sn2
	move.l d0,d2
	lsl.l #3,d0
	add.l d2,d0
	add.l d2,d0
	add.l d1,d0
	bcs .sn2
	cmp.l #DIRECT,d0
	beq .sn2
	bra .l
.e:
	move.l (sp)+,d2
	rts
.sn2:
	move.l (sp)+,d2
.sn:
	ERROR E_SN

; is D0.B the start of a jump target (a digit or the * of a label)? carry clear if so
isjump:
	cmp.b #'*',d0
	bne isdigit
	andi.b #$fe,ccr
	rts

; a line number or a *label at A5 -> D0 = the line number. keeps D2-D7
jumpline:
	bsr peek
	cmp.b #'*',d0
	bne linenum
	movem.l d2/a0-a2,-(sp)
	addq.l #1,a5
	move.l a5,a2			; the name
.n:
	move.b (a5),d0
	bsr islabel
	bcs .e
	addq.l #1,a5
	bra .n
.e:
	move.l a5,d2
	sub.l a2,d2			; its length
	beq .sn
	bsr lblfind
	move.l a0,d0
	beq .ul
	move.l LNUM(a0),d0
	movem.l (sp)+,d2/a0-a2
	rts
.ul:
	movem.l (sp)+,d2/a0-a2
	ERROR E_UL
.sn:
	movem.l (sp)+,d2/a0-a2
	ERROR E_SN

; the line that label A2 (D2 characters) starts -> A0, or 0. keeps D2/A2
lblfind:
	movem.l d1/d3-d4/a1/a3,-(sp)
	tst.b D_LBLOK(a6)
	bne .c
	bsr lblbuild
.c:
	bsr lblhash			; -> D3
	lea D_LBLTAB(a6),a3
	move.w D_LBLCNT(a6),d4
	bra .e
.l:
	cmp.w LB_HASH(a3),d3
	bne .n
	cmp.w LB_LEN(a3),d2
	bne .n
	move.l LB_NAME(a3),a0
	move.l a2,a1
	move.w d2,d1
	subq.w #1,d1
.cc:
	cmpm.b (a0)+,(a1)+
	bne .n
	dbra d1,.cc
	move.l LB_LINE(a3),a0
	bra .r
.n:
	lea LB_SIZE(a3),a3
.e:
	dbra d4,.l
	suba.l a0,a0
	cmp.b #2,D_LBLOK(a6)
	bne .r
	bsr lblscan			; the cache is full: look through the program
.r:
	movem.l (sp)+,d1/d3-d4/a1/a3
	rts

; hash of the label A2 (D2 characters) -> D3.W. keeps the rest
lblhash:
	movem.l d0-d1/a2,-(sp)
	moveq #0,d3
	move.w d2,d1
	subq.w #1,d1
.l:
	move.w d3,d0
	lsl.w #5,d3
	sub.w d0,d3			; * 31
	moveq #0,d0
	move.b (a2)+,d0
	add.w d0,d3
	dbra d1,.l
	movem.l (sp)+,d0-d1/a2
	rts

; the label at the start of line A0 -> A1 = its name, D0 = its length (0 if none)
lblat:
	lea LH(a0),a1
.s:
	cmp.b #' ',(a1)+
	beq .s
	moveq #0,d0
	cmp.b #'*',-1(a1)
	bne .r
	move.l a1,-(sp)
.l:
	move.b (a1)+,d0
	bsr islabel
	bcc .l
	move.l a1,d0
	move.l (sp)+,a1
	sub.l a1,d0
	subq.l #1,d0
.r:
	rts

; build the label cache from the program (the first line with a label wins)
lblbuild:
	movem.l d0-d4/a0-a4,-(sp)
	clr.w D_LBLCNT(a6)
	move.b #1,D_LBLOK(a6)
	lea D_SIZE(a6),a0
.l:
	tst.w (a0)
	beq .done
	bsr lblat
	tst.l d0
	beq .nx
	move.l a1,a2
	move.l d0,d2
	bsr lblhash
	; already there?
	lea D_LBLTAB(a6),a3
	move.w D_LBLCNT(a6),d4
	bra .de
.dl:
	cmp.w LB_HASH(a3),d3
	bne .dn
	cmp.w LB_LEN(a3),d2
	bne .dn
	move.l LB_NAME(a3),a4
	move.l a2,a1
	move.w d2,d1
	subq.w #1,d1
.dc:
	cmpm.b (a4)+,(a1)+
	bne .dn
	dbra d1,.dc
	bra .nx				; a duplicate: the first one counts
.dn:
	lea LB_SIZE(a3),a3
.de:
	dbra d4,.dl
	cmp.w #LBLMAX,D_LBLCNT(a6)
	bcs .add
	move.b #2,D_LBLOK(a6)		; full: the rest are found by looking
	bra .nx
.add:
	move.l a2,LB_NAME(a3)
	move.l a0,LB_LINE(a3)
	move.w d3,LB_HASH(a3)
	move.w d2,LB_LEN(a3)
	addq.w #1,D_LBLCNT(a6)
.nx:
	adda.w (a0),a0
	bra .l
.done:
	movem.l (sp)+,d0-d4/a0-a4
	rts

; look through the program for label A2 (D2 characters) -> A0 line, or 0. keeps D2/A2
lblscan:
	movem.l d0-d1/a1/a3,-(sp)
	lea D_SIZE(a6),a0
.l:
	tst.w (a0)
	beq .no
	bsr lblat
	cmp.l d2,d0
	bne .n
	move.l a2,a3
	move.w d2,d1
	subq.w #1,d1
.c:
	cmpm.b (a1)+,(a3)+
	bne .n
	dbra d1,.c
	bra .r
.n:
	adda.w (a0),a0
	bra .l
.no:
	suba.l a0,a0
.r:
	movem.l (sp)+,d0-d1/a1/a3
	rts

; ARRAYS: list the arrays (in the order they were made): name(largest indexes),
; elements, bytes
st_arrays:
	; count them first, then show the oldest (highest in memory) first
	moveq #0,d5
	move.l D_VARBOT(a6),a0
.c:
	cmpa.l D_MEMTOP(a6),a0
	bcc .show
	tst.b 4(a0)
	bpl .cn
	addq.l #1,d5
.cn:
	adda.l (a0),a0
	bra .c
.show:
	tst.l d5
	beq .r
	subq.l #1,d5			; the one to show: number D5 from the bottom
	move.l D_VARBOT(a6),a0
	move.l d5,d4
.f:
	tst.b 4(a0)
	bpl .fn
	subq.l #1,d4
	bmi .got
.fn:
	adda.l (a0),a0
	bra .f
.got:
	move.l a0,a4
	; the name and its suffix
	lea 6(a4),a0
	moveq #0,d1
	move.b 5(a4),d1
	bsr putn
	moveq #0,d0
	move.b 4(a4),d0
	and.b #$7f,d0
	lea .sfx(pc),a0
	move.b (a0,d0.w),d0
	beq .np
	bsr putc
.np:
	moveq #'(',d0
	bsr putc
	move.l a4,a0
	bsr vardata			; A1 = ndims.w, counts
	move.w (a1)+,d3
	subq.w #1,d3
	moveq #1,d6			; elements
.d:
	move.l (a1)+,d1
	move.l d1,-(sp)
	subq.l #1,d1			; the largest index
	moveq #0,d0
	movem.l d3/a1,-(sp)
	bsr pint
	movem.l (sp)+,d3/a1
	move.l (sp)+,d1
	move.l d6,d0
	bsr mul32lo
	move.l d0,d6
	tst.w d3
	beq .de
	moveq #',',d0
	bsr putc
.de:
	dbra d3,.d
	moveq #')',d0
	bsr putc
.p1:
	bsr space
	cmp.b #24,IO_CON_CURSORH
	bcs .p1
	moveq #0,d0
	move.l d6,d1
	bsr pint
	PRINTS " elements, "
	moveq #0,d0
	move.l (a4),d1			; the whole entry
	bsr pint
	PRINTS <" bytes",13>
	bsr brkkey
	bne .r
	bra .show
.r:
	rts
.sfx:
	dc.b 0,'%','&',0,'$'
	even

; LABELS: list the labels and their lines
st_labels:
	lea D_SIZE(a6),a0
.l:
	tst.w (a0)
	beq .r
	bsr lblat
	tst.l d0
	beq .nx
	movem.l a0,-(sp)
	move.l a1,a2
	move.l d0,d2
	moveq #'*',d0
	bsr putc
	move.l a2,a0
	move.l d2,d1
	bsr putn
.pad:
	bsr space			; the line number in column 20 (or after a space)
	cmp.b #20,IO_CON_CURSORH
	bcs .pad
	movem.l (sp),a0
	moveq #0,d0
	move.l LNUM(a0),d1
	bsr pint
	bsr lblfind			; the one a jump would go to
	cmpa.l (sp),a0
	beq .ok
	PRINTS "  (duplicate: not used)"
.ok:
	bsr crlf
	movem.l (sp)+,a0
	bsr brkkey
	bne .r
.nx:
	adda.w (a0),a0
	bra .l
.r:
	rts

; can D0.B be in a label (letters, digits, _)? carry clear if so
islabel:
	cmp.b #'_',d0
	beq .y
	bsr isalpha
	bcc .y
	bra isdigit
.y:
	andi.b #$fe,ccr
	rts

; ---------------------------------------------------------------- program lines

; line D0 -> A0 = the first line with that number or above (or the end of the program).
; D1 = 1 if it's that line exactly. keeps D0
findline:
	lea D_SIZE(a6),a0
findfrom:
	moveq #0,d1
.l:
	tst.w (a0)
	beq .r
	cmp.l LNUM(a0),d0
	bls .f
	adda.w (a0),a0
	bra .l
.f:
	bne .r
	moveq #1,d1
.r:
	rts

; replace, insert or delete line D7 with the D6 bytes at D_CRUNCH (D6 = 0: delete)
edit_line:
	move.l d7,d0
	bsr findline
	tst.l d1
	beq .ins
	; delete the old line
	moveq #0,d0
	move.w (a0),d0
	lea (a0,d0.l),a1		; from
	move.l D_PRGEND(a6),d1
	addq.l #2,d1
	sub.l a1,d1			; bytes to move
	move.l a0,a2
	bsr movedown
	sub.l d0,D_PRGEND(a6)
.ins:
	tst.l d6
	beq .r
	move.l d6,d5
	addq.l #LH+1,d5
	and.b #$fe,d5			; new line size
	move.l D_PRGEND(a6),a1
	lea (a1,d5.l),a1
	lea 2+1024(a1),a1
	cmpa.l D_MEMTOP(a6),a1
	bcc .om
	; open a gap
	move.l D_PRGEND(a6),a1
	addq.l #2,a1			; end of the block to move
	move.l a1,d1
	sub.l a0,d1			; bytes
	bsr moveup			; moves [A0, A1) up by D5
	add.l d5,D_PRGEND(a6)
	move.w d5,(a0)+
	move.l d7,(a0)+
	lea D_CRUNCH(a6),a1
	move.l d6,d0
	subq.w #1,d0
.c:
	move.b (a1)+,(a0)+
	dbra d0,.c
	btst #0,d6			; LH + an odd length: there's a padding byte
	beq .r
	clr.b (a0)
.r:
	rts
.om:
	ERROR E_OM

; copy D1 bytes from A1 down to A2 (A2 < A1), word aligned. keeps D0/D5
movedown:
	lsr.l #1,d1
	beq .r
	subq.l #1,d1
.l:
	move.w (a1)+,(a2)+
	subq.l #1,d1
	bpl .l
.r:
	rts

; move the D1 bytes ending at A1 up by D5 bytes (word aligned). keeps A0/D5
moveup:
	lea (a1,d5.l),a2
	lsr.l #1,d1
	beq .r
	subq.l #1,d1
.l:
	move.w -(a1),-(a2)
	subq.l #1,d1
	bpl .l
.r:
	rts

; NEW: no program, nothing else either
do_new:
	lea D_SIZE(a6),a0
	clr.w (a0)
	move.l a0,D_PRGEND(a6)
	clr.l D_CONTPTR(a6)
	; fall into clear_all

; CLEAR: forget the variables, strings, the control stack and the READ position
clear_all:
	move.l D_MEMTOP(a6),a0
	move.l a0,D_VARBOT(a6)
	move.l a0,D_TMPPTR(a6)
	move.l D_PRGEND(a6),a0
	addq.l #2,a0
	move.l a0,D_STRBOT(a6)
	move.l a0,D_STRTOP(a6)
	clr.l D_GARBAGE(a6)
	clr.l D_GCROOT(a6)
	clr.b D_ONERRF(a6)
	clr.b D_INERR(a6)
	clr.b D_LBLOK(a6)
	lea D_CSTTOP(a6),a0
	move.l a0,D_CSP(a6)
	lea D_SIZE(a6),a0
	; fall into restore_at

; RESTORE to the line at A0
restore_at:
	move.l a0,D_DATLIN(a6)
	addq.l #LH,a0
	move.l a0,D_DATPTR(a6)
	clr.b D_DATIN(a6)
	rts

; ---------------------------------------------------------------- console

; print D0.B. keeps all registers
putc:
	move.b d0,IO_CON_CHAROUT
	move.b d0,IO_CON_REGISTER
	rts

crlf:
	move.l d0,-(sp)
	moveq #13,d0
	bsr putc
	move.l (sp)+,d0
	rts

space:
	move.l d0,-(sp)
	moveq #' ',d0
	bsr putc
	move.l (sp)+,d0
	rts

; start a new line unless the cursor is at the left edge
col0:
	tst.b IO_CON_CURSORH
	beq .r
	bsr crlf
.r:
	rts

; print the zero terminated string after the call. keeps all registers
pstr:
	move.l a0,-(sp)
	move.l d0,-(sp)
	move.l 8(sp),a0
.l:
	move.b (a0)+,d0
	beq .e
	bsr putc
	bra .l
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
	beq .e
	bsr putc
	bra .l
.e:
	movem.l (sp)+,d0/a0
	rts

; print D1 bytes at A0
putn:
	tst.l d1
	beq .r
.l:
	move.b (a0)+,d0
	bsr putc
	subq.l #1,d1
	bne .l
.r:
	rts

; print D0:D1 as a signed decimal number
pint:
	bsr itoa
	bra puts

; wait for a key -> D0
getkey:
	tst.b IO_KEYQ_SIZE
	beq getkey
	moveq #0,d0
	move.b IO_KEYQ_WAITING,d0
	move.b d0,IO_KEYQ_DEQUEUE
	rts

; read a line into D_INBUF -> A0. N set (D0 = -1) if Ctrl-C was pressed
inputline:
	lea D_INBUF(a6),a0
	moveq #0,d1
.l:
	bsr getkey
	cmp.b #13,d0
	beq .cr
	cmp.b #8,d0
	beq .bs
	cmp.b #3,d0
	beq .brk
	cmp.b #' ',d0
	bcs .l
	cmp.w #250,d1
	bcc .l
	move.b d0,(a0)+
	addq.w #1,d1
	bsr putc
	bra .l
.bs:
	tst.w d1
	beq .l
	subq.w #1,d1
	subq.l #1,a0
	PRINTS <8," ",8>
	bra .l
.cr:
	clr.b (a0)
	bsr crlf
	lea D_INBUF(a6),a0
	moveq #0,d0
	rts
.brk:
	PRINTS <"^C",13>
	moveq #-1,d0
	rts

; ---------------------------------------------------------------- text scanning

; skip spaces at A5
skipsp:
	cmp.b #' ',(a5)+
	beq skipsp
	subq.l #1,a5
	rts

; skip spaces at A5, then D0 = the next character (not taken). Z set at the end of the line
peek:
	cmp.b #' ',(a5)
	bne .p
	addq.l #1,a5
	bra peek
.p:
	move.b (a5),d0
	rts

; the next character must be D0, take it
expect:
	move.l d0,-(sp)
	bsr peek
	cmp.b 3(sp),d0
	bne .sn
	addq.l #1,a5
	addq.l #4,sp
	rts
.sn:
	ERROR E_SN

	macro EXPECT
	moveq #\1,d0
	bsr expect
	endm

; is D0.B a letter? carry clear if so
isalpha:
	cmp.b #'A',d0
	bcs .no
	cmp.b #'Z'+1,d0
	bcs .yes
	cmp.b #'a',d0
	bcs .no
	cmp.b #'z'+1,d0
	bcc .no
.yes:
	andi.b #$fe,ccr
	rts
.no:
	ori.b #1,ccr
	rts

; is D0.B a digit? carry clear if so
isdigit:
	cmp.b #'0',d0
	bcs .no
	cmp.b #'9'+1,d0
	bcc .no
	andi.b #$fe,ccr
	rts
.no:
	ori.b #1,ccr
	rts

; A0 at a statement: move it to the ':' or the zero that ends it (keeps D1-D7/A1-A4)
skipstmt:
.l:
	move.b (a0),d0
	beq .e
	cmp.b #':',d0
	beq .e
	cmp.b #'"',d0
	bne .t
	addq.l #1,a0
.q:
	move.b (a0),d0
	beq .e
	addq.l #1,a0
	cmp.b #'"',d0
	bne .q
	bra .l
.t:
	cmp.b #TK_REM,d0
	beq skipeol
	cmp.b #TK_APOS,d0
	beq skipeol
	addq.l #1,a0
	bra .l
.e:
	rts

; A0 to the zero at the end of the line
skipeol:
	tst.b (a0)+
	bne skipeol
	subq.l #1,a0
	rts

; A0 at the ':' or zero after a statement in line A1: go to the start of the next statement
; (into the next line if need be). N set (D0 = -1) at the end of the program
nextstmt:
	tst.b (a0)
	beq .nl
	addq.l #1,a0
	moveq #0,d0
	rts
.nl:
	adda.w (a1),a1
	tst.w (a1)
	beq .end
	lea LH(a1),a0
	moveq #0,d0
	rts
.end:
	moveq #-1,d0
	rts

; skip spaces at A0, D0 = the next byte
peeka0:
	cmp.b #' ',(a0)
	bne .p
	addq.l #1,a0
	bra peeka0
.p:
	move.b (a0),d0
	rts

; ---------------------------------------------------------------- tokenizer

; crunch the text at A5 into tokens at A1. Keywords are whole words, so they have to be
; separated from names (FOR I=1 TO 10, not FORI=1TO10). Letters outside strings, REM and
; DATA are made upper case. Returns A1 after the final zero
crunch:
	move.l a1,a3			; start, for the length check
.l:
	move.l a1,d0
	sub.l a3,d0
	cmp.l #MAXLINE,d0
	bcc .ll
	move.b (a5)+,d0
	beq .end
	cmp.b #'"',d0
	beq .str
	cmp.b #'?',d0
	beq .print
	cmp.b #$27,d0
	beq .apos
	cmp.b #'*',d0
	beq .star
	bsr isalpha
	bcc .word
	move.b d0,(a1)+
	bra .l
.print:
	move.b #TK_PRINT,(a1)+
	bra .l
.star:
	; *name is a label at the start of a statement or after GOTO, GOSUB, THEN, ELSE,
	; RESTORE, RUN, RESUME or a comma (ON ... GOTO); anywhere else * multiplies
	move.b d0,(a1)+
	move.b (a5),d0
	bsr isalpha
	bcs .l
	move.l a1,a2
	subq.l #1,a2
.sb:
	cmpa.l a3,a2
	beq .lab			; the start of the line
	move.b -(a2),d0
	cmp.b #' ',d0
	beq .sb
	lea .after(pc),a4
.sa:
	tst.b (a4)
	beq .l
	cmp.b (a4)+,d0
	bne .sa
.lab:
	move.b (a5),d0
	bsr islabel
	bcs .l
	addq.l #1,a5
	cmp.b #'a',d0
	bcs .lu
	cmp.b #'z'+1,d0
	bcc .lu
	sub.b #$20,d0
.lu:
	move.b d0,(a1)+
	bra .lab
.after:
	dc.b ':',',',TK_GOTO,TK_GOSUB,TK_THEN,TK_ELSE,TK_RESTORE,TK_RUN,TK_RESUME,0
	even
.apos:
	move.b #TK_APOS,(a1)+
	bra .raw
.str:
	move.b d0,(a1)+
.sl:
	move.b (a5)+,d0
	beq .end
	move.b d0,(a1)+
	cmp.b #'"',d0
	bne .sl
	bra .l
.word:
	; a name or a keyword: letters and digits, then maybe $ % &
	lea D_WORD(a6),a2
	moveq #0,d2			; length
	subq.l #1,a5
.wl:
	move.b (a5),d0
	bsr isalpha
	bcc .wc
	bsr isdigit
	bcs .wsfx
.wc:
	cmp.b #'a',d0
	bcs .wu
	sub.b #$20,d0
.wu:
	addq.l #1,a5
	cmp.w #40,d2
	bcc .wl			; much too long to be anything; the name check catches it
	move.b d0,(a2)+
	addq.w #1,d2
	bra .wl
.wsfx:
	cmp.b #'$',d0
	beq .ws
	cmp.b #'%',d0
	beq .ws
	cmp.b #'&',d0
	bne .we
	cmp.b #'H',1(a5)		; A&H.. would be odd; &H after a name is not a suffix
	beq .we
	cmp.b #'h',1(a5)
	beq .we
.ws:
	addq.l #1,a5
	move.b d0,(a2)+
	addq.w #1,d2
.we:
	clr.b (a2)
	bsr findkw
	tst.b d0
	bne .kw
	; FNname: the FN keyword, then the name
	lea D_WORD(a6),a2
	cmp.b #'F',(a2)
	bne .name
	cmp.b #'N',1(a2)
	bne .name
	move.b 2(a2),d0
	bsr isalpha
	bcs .name
	move.b #TK_FN,(a1)+
	addq.l #2,a2
	bra .nl
.kw:
	move.b d0,(a1)+
	cmp.b #TK_REM,d0
	beq .raw
	cmp.b #TK_DATA,d0
	beq .data
	bra .l
.name:
	lea D_WORD(a6),a2
.nl:
	move.b (a2)+,d0
	beq .l
	move.b d0,(a1)+
	bra .nl
.raw:
	; the rest of the line as it is
	move.l a1,d0
	sub.l a3,d0
	cmp.l #MAXLINE,d0
	bcc .ll
	move.b (a5)+,d0
	beq .end
	move.b d0,(a1)+
	bra .raw
.data:
	; as it is, up to a ':' outside quotes
	moveq #0,d1			; in quotes
.dl:
	move.l a1,d0
	sub.l a3,d0
	cmp.l #MAXLINE,d0
	bcc .ll
	move.b (a5),d0
	beq .end0
	cmp.b #'"',d0
	bne .dq
	not.b d1
.dq:
	tst.b d1
	bne .dc
	cmp.b #':',d0
	beq .l
.dc:
	addq.l #1,a5
	move.b d0,(a1)+
	bra .dl
.end0:
	addq.l #1,a5
.end:
	clr.b (a1)+
	rts
.ll:
	ERROR E_LL

; look up the word at D_WORD. D0 = its token, or 0
findkw:
	movem.l a0/a2/d1,-(sp)
	lea kwtab(pc),a0
	move.w #$80,d1
.l:
	tst.b (a0)
	beq .no			; end of the table
	lea D_WORD(a6),a2
.c:
	move.b (a0)+,d0
	cmp.b (a2)+,d0
	bne .skip
	tst.b d0
	bne .c
	move.w d1,d0
	bra .r
.skip:
	tst.b d0
	beq .n
.s:
	tst.b (a0)+
	bne .s
.n:
	addq.w #1,d1
	bra .l
.no:
	moveq #0,d0
.r:
	movem.l (sp)+,a0/a2/d1
	rts

; print keyword D0 (a token)
putkw:
	movem.l d0-d1/a0,-(sp)
	lea kwtab(pc),a0
	and.w #$7f,d0
	bra .f
.s:
	tst.b (a0)+
	bne .s
.f:
	dbra d0,.s
	bsr puts
	movem.l (sp)+,d0-d1/a0
	rts

; the keywords in token order (from $80). A word is a keyword only if it matches exactly
kwtab:
	dc.b "END",0,"FOR",0,"NEXT",0,"DATA",0,"INPUT",0,"DIM",0,"READ",0,"LET",0
	dc.b "GOTO",0,"RUN",0,"IF",0,"RESTORE",0,"GOSUB",0,"RETURN",0,"REM",0,"STOP",0
	dc.b "ON",0,"POKE",0,"PRINT",0,"CONT",0,"LIST",0,"CLEAR",0,"NEW",0,"CLS",0
	dc.b "LOCATE",0,"COLOR",0,"WHILE",0,"WEND",0,"REPEAT",0,"UNTIL",0,"SWITCH",0,"CASE",0
	dc.b "DEFAULT",0,"ENDSWITCH",0,"ELSE",0,"ENDIF",0,"CALL",0,"MONITOR",0,"BYE",0,"DELETE",0
	dc.b "RANDOMIZE",0,"TRON",0,"TROFF",0,"LINE",0,"'",0,"LOMEM",0,"HIMEM",0
	dc.b "GR",0,"TEXT",0,"GRCLS",0,"PLOT",0,"GRCOLOR",0,"RECTANGLE",0,"CIRCLE",0
	dc.b "FILLRECTANGLE",0,"FILLCIRCLE",0
	dc.b "DEF",0,"SWAP",0,"RENUM",0,"RESUME",0,"ERROR",0,"ELSEIF",0,"LABELS",0,"ARRAYS",0
	; $c0
	dc.b "THEN",0,"TO",0,"STEP",0,"AND",0,"OR",0,"XOR",0,"NOT",0,"MOD",0,"TAB",0,"SPC",0
	dc.b "USING",0,"FN",0
	; $cc: functions
	dc.b "SGN",0,"INT",0,"FIX",0,"ABS",0,"SQR",0,"RND",0,"LOG",0,"LN",0
	dc.b "LOG10",0,"EXP",0,"SIN",0,"COS",0,"TAN",0,"ATN",0,"ASN",0,"ACS",0
	dc.b "PI",0,"ROOT",0,"PEEK",0,"FRE",0,"LEN",0,"ASC",0,"VAL",0,"CHR$",0
	dc.b "STR$",0,"LEFT$",0,"RIGHT$",0,"MID$",0,"HEX$",0,"DEC",0,"INSTR",0
	dc.b "STRING$",0,"SPACE$",0,"UCASE$",0,"LCASE$",0,"INKEY$",0,"POS",0,"CINT",0
	dc.b "ERR",0,"ERL",0
	dc.b 0
	even

; ---------------------------------------------------------------- LIST, DELETE

; parse a line range at A5: [n][-[m]] -> D6 = from, D7 = to. D5 = 1 if anything was given
range:
	moveq #0,d6
	move.l #DIRECT-1,d7
	moveq #0,d5
	bsr peek
	bsr isdigit
	bcs .dash
	bsr linenum
	move.l d0,d6
	move.l d0,d7
	moveq #1,d5
	bsr peek
.dash:
	cmp.b #'-',d0
	bne .r
	addq.l #1,a5
	moveq #1,d5
	move.l #DIRECT-1,d7
	bsr peek
	bsr isdigit
	bcs .r
	bsr linenum
	move.l d0,d7
.r:
	rts

st_list:
	bsr range
	move.l d6,d0
	bsr findline
.l:
	tst.w (a0)
	beq .done
	move.l LNUM(a0),d0
	cmp.l d7,d0
	bhi .done
	bsr listline
	adda.w (a0),a0
	bsr brkkey
	beq .l
.done:
	jmp ready

; print line A0 (number, a space, the text). keeps A0
listline:
	movem.l a0-a1,-(sp)
	move.l a0,a1
	move.l LNUM(a1),d1
	moveq #0,d0
	bsr pint
	bsr space
	lea LH(a1),a1
	moveq #0,d1			; in quotes
.l:
	move.b (a1)+,d0
	beq .e
	cmp.b #'"',d0
	bne .t
	not.b d1
.t:
	tst.b d1
	bne .c
	tst.b d0
	bpl .c
	bsr putkw
	cmp.b #TK_REM,d0
	beq .raw
	cmp.b #TK_APOS,d0
	beq .raw
	bra .l
.c:
	bsr putc
	bra .l
.raw:
	move.b (a1)+,d0
	beq .e
	bsr putc
	bra .raw
.e:
	bsr crlf
	movem.l (sp)+,a0-a1
	rts

; Ctrl-C waiting? Z clear (and the key taken) if so
brkkey:
	tst.b IO_KEYQ_SIZE
	beq .r
	cmp.b #3,IO_KEYQ_WAITING
	bne .no
	move.b d0,IO_KEYQ_DEQUEUE
	moveq #1,d0
	rts
.no:
	moveq #0,d0
.r:
	rts

st_delete:
	bsr range
	tst.l d5
	beq .sn
.l:
	move.l d6,d0
	bsr findline
	tst.w (a0)
	beq .done
	move.l LNUM(a0),d0
	cmp.l d7,d0
	bhi .done
	move.l d0,d6			; delete this one
	movem.l d6-d7,-(sp)
	move.l d0,d7
	moveq #0,d6
	bsr edit_line
	movem.l (sp)+,d6-d7
	bra .l
.done:
	bsr clear_all
	clr.l D_CONTPTR(a6)
	jmp ready
.sn:
	ERROR E_SN

; ---------------------------------------------------------------- running

; start the statement at A5 (or the ':' or end of line before it)
newstmt:
	lea STACKTOP,sp
	tst.b IO_KEYQ_SIZE		; Ctrl-C?
	beq .nb
	cmp.b #3,IO_KEYQ_WAITING
	bne .nb
	move.b d0,IO_KEYQ_DEQUEUE
	bra do_break
.nb:
	move.l D_VARBOT(a6),D_TMPPTR(a6)
	; low on space and some of the heap is dead: compact it now, while no temporary
	; string can be pointing into it
	tst.l D_GARBAGE(a6)
	beq .s
	move.l D_TMPPTR(a6),d0
	sub.l D_STRTOP(a6),d0
	cmp.l #$22000,d0
	bcc .s
	bsr gc
.s:
	move.b (a5)+,d0
	cmp.b #' ',d0
	beq .s
	cmp.b #':',d0
	beq .s
	tst.b d0
	beq nextline
	lea -1(a5),a0
	move.l a0,D_STMT(a6)
	clr.l D_FNFRAME(a6)
	tst.b d0
	bpl ns_let
	cmp.b #TK_MID,d0
	bne .nm
	bsr st_midset
	bra after_stmt
.nm:
	cmp.b #TK_LASTST,d0
	bhi ns_sn
	and.w #$7f,d0
	add.w d0,d0
	add.w d0,d0
	lea stmttab(pc),a0
	move.l (a0,d0.w),a0
	jsr (a0)
after_stmt:
	bsr peek
	beq newstmt
	cmp.b #':',d0
	beq newstmt
	cmp.b #TK_ELSE,d0
	beq newstmt
ns_sn:
	ERROR E_SN
ns_let:
	cmp.b #'*',d0			; *label: nothing to do
	bne .nl
.lb:
	move.b (a5),d0
	bsr islabel
	bcs after_stmt
	addq.l #1,a5
	bra .lb
.nl:
	subq.l #1,a5
	bsr isalpha
	bcs ns_sn
	bsr st_let
	bra after_stmt

stmttab:
	dc.l st_end,st_for,st_next,st_data,st_input,st_dim,st_read,st_let
	dc.l st_goto,st_run,st_if,st_restore,st_gosub,st_return,st_rem,st_stop
	dc.l st_on,st_poke,st_print,st_cont,st_list,st_clear,st_new,st_cls
	dc.l st_locate,st_color,st_while,st_wend,st_repeat,st_until,st_switch,st_case
	dc.l st_case,st_endsw,st_else,st_endif,st_call,st_monitor,st_monitor,st_delete
	dc.l st_randomize,st_tron,st_troff,st_line,st_rem,st_lomem,st_himem
	dc.l st_gr,st_text,st_grcls,st_plot,st_grcolor,st_rect,st_circle,st_fillrect,st_fillcircle
	dc.l st_def,st_swap,st_renum,st_resume,st_error,st_elseif,st_labels,st_arrays

; the end of a line: go on to the next one
nextline:
	move.l D_CURLIN(a6),a0
	cmp.l #DIRECT,LNUM(a0)
	beq .direct
	adda.w (a0),a0
	tst.w (a0)
	beq .end
	bsr enterline
	bra newstmt
.direct:
.end:
	jmp ready

; make A0 the current line, A5 its start
enterline:
	move.l a0,D_CURLIN(a6)
	lea LH(a0),a5
	clr.b D_SLIF(a6)
	tst.b D_TRACE(a6)
	beq .r
	moveq #'[',d0
	bsr putc
	moveq #0,d0
	move.l LNUM(a0),d1
	bsr pint
	moveq #']',d0
	bsr putc
	move.l D_CURLIN(a6),a0
.r:
	rts

; go to line D0
goline:
	bsr findline
	tst.l d1
	beq .us
	bsr enterline
	bra newstmt
.us:
	ERROR E_US

; ---------------------------------------------------------------- errors and break

error:
	lea STACKTOP,sp
	clr.l D_FNFRAME(a6)
	cmp.w #E_UP,d0
	beq .num
	lea gwnum(pc),a0
	moveq #0,d1
	move.b (a0,d0.w),d1
	move.l d1,D_ERRNUM(a6)
.num:
	move.w d0,D_ERRCODE(a6)
	move.l D_CURLIN(a6),a0
	move.l LNUM(a0),D_ERRLINE(a6)
	cmp.l #DIRECT,LNUM(a0)
	bne .p
	clr.l D_ERRLINE(a6)
	bra .show			; direct commands aren't trapped
.p:
	tst.b D_ONERRF(a6)
	beq .show
	tst.b D_INERR(a6)
	bne .show			; an error in the handler stops the program
	move.l a0,D_ERRLIN(a6)
	move.l D_STMT(a6),D_ERRSTMT(a6)
	move.l d0,d7
	move.l D_ONERR(a6),d0
	bsr findline
	tst.l d1
	beq .nh
	st D_INERR(a6)
	bsr enterline
	jmp newstmt
.nh:
	move.l d7,d0
.show:
	clr.b D_INERR(a6)
	move.l d0,d7
	bsr textback
	bsr col0
	moveq #'?',d0
	bsr putc
	lea errmsgs(pc),a0
	bra .f
.s:
	tst.b (a0)+
	bne .s
.f:
	dbra d7,.s
	bsr puts
	cmp.w #E_UP,D_ERRCODE(a6)
	bne .e
	moveq #0,d0
	move.l D_ERRNUM(a6),d1
	bsr space
	bsr pint
.e:
	PRINTS " error"
	bsr inline
	bsr crlf
	clr.l D_CONTPTR(a6)
	lea D_CSTTOP(a6),a0
	move.l a0,D_CSP(a6)
	jmp ready

; print " in <line>" unless it was a direct command
inline:
	move.l D_CURLIN(a6),a0
	cmp.l #DIRECT,LNUM(a0)
	beq .r
	PRINTS " in "
	moveq #0,d0
	move.l LNUM(a0),d1
	bsr pint
.r:
	rts

errmsgs:
	dc.b "Syntax",0,"Out of memory",0,"Undefined line",0,"Type mismatch",0
	dc.b "Overflow",0,"Division by zero",0,"Illegal function call",0
	dc.b "NEXT without FOR",0,"RETURN without GOSUB",0,"Out of DATA",0
	dc.b "Bad subscript",0,"Redimensioned array",0,"String too long",0
	dc.b "Can't continue",0,"Formula too complex",0,"WEND without WHILE",0
	dc.b "UNTIL without REPEAT",0,"WHILE without WEND",0,"IF without ENDIF",0
	dc.b "SWITCH without ENDSWITCH",0,"Line too long",0,"Undefined function",0
	dc.b "RESUME without",0,"Unprintable",0,"Illegal direct",0,"Undefined label",0,"Array not dimensioned",0
	even

; the error numbers ERR gives (the GW-BASIC numbers where there is one), by error
gwnum:
	dc.b 2,7,8,13,6,11,5,1,3,4,9,10,15,17,16,30,31,29,32,33,23,18,20,0,12,8,35
	even

; Ctrl-C: stop, remembering where for CONT
do_break:
	bsr textback
	bsr col0
	move.l a5,D_CONTPTR(a6)
	move.l D_CURLIN(a6),a0
	move.l a0,D_CONTLIN(a6)
	cmp.l #DIRECT,LNUM(a0)
	bne .p
	clr.l D_CONTPTR(a6)		; can't continue a direct command
.p:
	PRINTS "Break"
	bsr inline
	bsr crlf
	jmp ready

; ---------------------------------------------------------------- simple statements

st_end:
	clr.l D_CONTPTR(a6)
	jmp ready

st_stop:
	bra do_break

st_new:
	bsr do_new
	jmp ready

st_clear:
	bra clear_all

st_cont:
	move.l D_CONTPTR(a6),d0
	beq .cn
	move.l d0,a5
	clr.l D_CONTPTR(a6)
	move.l D_CONTLIN(a6),D_CURLIN(a6)
	clr.b D_SLIF(a6)
	bra newstmt
.cn:
	ERROR E_CN

st_rem:
	move.l a5,a0
	bsr skipeol
	move.l a0,a5
	rts

st_data:
	move.l a5,a0
	bsr skipstmt
	move.l a0,a5
	rts

st_monitor:
	moveq #9,d0
	trap #15

st_tron:
	st D_TRACE(a6)
	rts
st_troff:
	clr.b D_TRACE(a6)
	rts

st_randomize:
	bsr peek			; the random numbers come from the machine: nothing to seed
	beq .r
	cmp.b #':',d0
	beq .r
	bsr eval
.r:
	rts

st_cls:
	move.b #' ',IO_CON_CHAROUT
	move.b d0,IO_CON_CLS
	clr.b IO_CON_CURSORH
	clr.b IO_CON_CURSORV
	rts

; LOCATE(column, row) or LOCATE(row): move the text cursor (0 based)
st_locate:
	moveq #1,d0
	moveq #2,d1
	bsr gargs
	move.l D_GARG(a6),d3		; column
	move.l D_GARG+4(a6),d2		; row
	cmp.w #1,D_GCNT(a6)
	bne .chk
	move.l d3,d2			; just a row: column 0
	moveq #0,d3
.chk:
	moveq #80,d0
	moveq #34,d1
	cmp.b #9,IO_VIDMODE
	beq .s
	moveq #40,d0
	moveq #17,d1
.s:
	cmp.l d0,d3
	bcc .fc
	cmp.l d1,d2
	bcc .fc
	move.b d3,IO_CON_CURSORH
	move.b d2,IO_CON_CURSORV
	rts
.fc:
	ERROR E_FC

; COLOR(foreground [, background]): text colors, 0-15
st_color:
	moveq #1,d0
	moveq #2,d1
	bsr gargs
	move.l D_GARG(a6),d1
	cmp.l #16,d1
	bcc .fc
	move.b IO_CON_COLOR,d2
	and.b #$f0,d2
	or.b d1,d2
	cmp.w #2,D_GCNT(a6)
	bne .set
	move.l D_GARG+4(a6),d1
	cmp.l #16,d1
	bcc .fc
	lsl.b #4,d1
	and.b #$0f,d2
	or.b d1,d2
.set:
	move.b d2,IO_CON_COLOR
	rts
.fc:
	ERROR E_FC

; POKE address, byte
st_poke:
	bsr evaladdr
	move.l d1,-(sp)
	EXPECT ','
	bsr evalbyte
	move.l (sp)+,a0
	move.b d1,(a0)
	rts

; CALL address [, D0 [, D1 ...]]
st_call:
	bsr docall
	rts

; ---------------------------------------------------------------- RUN, GOTO, GOSUB, ON

st_run:
	bsr peek
	bsr isjump
	bcs .top
	bsr jumpline
	move.l d0,-(sp)
	bsr clear_all
	clr.l D_CONTPTR(a6)
	move.l (sp)+,d0
	bra goline
.top:
	bsr clear_all
	clr.l D_CONTPTR(a6)
	lea D_SIZE(a6),a0
	tst.w (a0)
	beq .r
	bsr enterline
	bra newstmt
.r:
	jmp ready

st_goto:
	bsr jumpline
	bra goline

st_gosub:
	bsr jumpline
	move.l d0,-(sp)
	bsr gosubframe
	move.l (sp)+,d0
	bra goline

; push a GOSUB frame returning to A5
gosubframe:
	bsr pushframe
	move.w #F_GOSUB,FR_TYPE(a0)
	move.l D_CURLIN(a6),FR_LINE(a0)
	move.l a5,FR_TEXT(a0)
	move.b D_SLIF(a6),FR_SLIF(a0)
	rts

; make room for a frame on the control stack -> A0
pushframe:
	move.l D_CSP(a6),a0
	lea -FRAME(a0),a0
	lea D_CSTBOT(a6),a1
	cmpa.l a1,a0
	bcs .om
	move.l a0,D_CSP(a6)
	rts
.om:
	ERROR E_OM

st_return:
	move.l D_CSP(a6),a0
	lea D_CSTTOP(a6),a1
.l:
	cmpa.l a1,a0
	bcc .rg
	cmp.w #F_GOSUB,FR_TYPE(a0)
	beq .f
	lea FRAME(a0),a0
	bra .l
.f:
	move.l FR_LINE(a0),D_CURLIN(a6)
	move.l FR_TEXT(a0),a5
	move.b FR_SLIF(a0),D_SLIF(a6)
	lea FRAME(a0),a0
	move.l a0,D_CSP(a6)
	bra after_stmt
.rg:
	ERROR E_RG

; ON expr GOTO/GOSUB line, line, ...
st_on:
	bsr peek
	cmp.b #TK_ERROR,d0
	beq st_onerror
	bsr evalint
	move.l d1,d7			; the choice (only the low long matters if the high is 0)
	tst.l d0
	beq .k
	moveq #0,d7			; way out of range: nothing chosen
.k:
	bsr peek
	move.b d0,d6
	cmp.b #TK_GOTO,d0
	beq .ok
	cmp.b #TK_GOSUB,d0
	bne .sn
.ok:
	addq.l #1,a5
	moveq #0,d5			; the line chosen, if any
	moveq #0,d4			; found one
.l:
	bsr jumpline
	subq.l #1,d7
	bne .n
	move.l d0,d5
	moveq #1,d4
.n:
	bsr peek
	cmp.b #',',d0
	bne .e
	addq.l #1,a5
	bra .l
.e:
	tst.l d4
	beq .r
	cmp.b #TK_GOSUB,d6
	bne .g
	move.l d5,-(sp)
	bsr gosubframe
	move.l (sp)+,d5
.g:
	move.l d5,d0
	bra goline
.r:
	rts
.sn:
	ERROR E_SN

; ---------------------------------------------------------------- IF, ELSE, ENDIF

; IF cond THEN stmts [ELSE stmts]      on one line
; IF cond THEN line [ELSE line]
; IF cond GOTO line [ELSE ...]
; IF cond THEN                         with nothing after THEN: a block, up to ENDIF,
;   ... [ELSE ...] ENDIF               with an optional ELSE on a line of its own
st_if:
	bsr evaltruth
	move.l d0,d7
	bsr peek
	cmp.b #TK_GOTO,d0
	beq .goto
	cmp.b #TK_THEN,d0
	bne .sn
	addq.l #1,a5
	bsr peek
	beq .block
	cmp.b #TK_REM,d0
	beq .block
	cmp.b #TK_APOS,d0
	beq .block
	tst.l d7
	beq .false
	bsr isjump
	bcs .stmts
	bsr jumpline
	bra goline
.stmts:
	st D_SLIF(a6)
	bra newstmt
.goto:
	addq.l #1,a5
	tst.l d7
	beq .false
	bsr jumpline
	bra goline
.block:
	tst.l d7
	beq .bfalse
	move.l a5,a0			; true: on to the next line
	bsr skipeol
	move.l a0,a5
	rts
.bfalse:
	moveq #0,d6			; find ELSE or ENDIF
	bra skipblock
.false:
	; find this IF's ELSE on the same line (IFs nested on the line have their own ELSEs)
	move.l a5,a0
	moveq #0,d1
.fl:
	move.b (a0)+,d0
	beq .none
	cmp.b #'"',d0
	bne .ft
.fq:
	move.b (a0)+,d0
	beq .none
	cmp.b #'"',d0
	bne .fq
	bra .fl
.ft:
	cmp.b #TK_REM,d0
	beq .none
	cmp.b #TK_APOS,d0
	beq .none
	cmp.b #TK_IF,d0
	bne .fe
	addq.l #1,d1
	bra .fl
.fe:
	cmp.b #TK_ELSE,d0
	bne .fl
	subq.l #1,d1
	bpl .fl
	move.l a0,a5			; after the ELSE
	bsr peek
	bsr isjump
	bcs newstmt
	bsr jumpline
	bra goline
.none:
	bra nextline
.sn:
	ERROR E_SN

; ELSE reached by running: the end of a THEN part
st_else:
	tst.b D_SLIF(a6)
	beq .block
	clr.b D_SLIF(a6)
	bra nextline
.block:
	moveq #1,d6			; find ENDIF
	; fall into skipblock

; skip the rest of an IF block from A5: D6 = 0 to stop after ELSE or ENDIF, 1 for ENDIF only
skipblock:
	move.l a5,a0
	move.l D_CURLIN(a6),a1
	moveq #0,d5			; nesting
	bsr skipstmt
.l:
	bsr nextstmt
	bmi .if
	bsr peeka0
	cmp.b #TK_IF,d0
	beq .nif
	cmp.b #TK_ENDIF,d0
	beq .end
	cmp.b #TK_ELSE,d0
	beq .else
	cmp.b #TK_ELSEIF,d0
	beq .elseif
.sk:
	bsr skipstmt
	bra .l
.elseif:
	tst.l d5
	bne .sk1
	tst.l d6
	bne .sk1
	; test it: true runs this part, false keeps looking
	lea 1(a0),a5
	move.l a1,D_CURLIN(a6)
	bsr evaltruth
	move.l d0,d7
	bsr peek
	cmp.b #TK_THEN,d0
	bne .et
	addq.l #1,a5
.et:
	clr.b D_SLIF(a6)
	tst.l d7
	bne newstmt
	move.l a5,a0
	move.l D_CURLIN(a6),a1
	moveq #0,d5
	moveq #0,d6
	bra .sk
.nif:
	bsr isblockif
	bne .nb
	addq.l #1,d5
.nb:
	bsr skipeol
	bra .l
.end:
	subq.l #1,d5
	bpl .sk1
	addq.l #1,a0			; found: carry on after ENDIF
	bra .found
.sk1:
	addq.l #1,a0
	bra .sk
.else:
	tst.l d5
	bne .sk1
	tst.l d6
	bne .sk1
	addq.l #1,a0
.found:
	move.l a0,a5
	move.l a1,D_CURLIN(a6)
	clr.b D_SLIF(a6)
	bra newstmt
.if:
	ERROR E_IF

; is the IF at A0 the start of a block (nothing after its THEN)? Z set if so. keeps A0
isblockif:
	move.l a0,a2
.l:
	move.b (a2)+,d0
	beq .no
	cmp.b #'"',d0
	bne .t
.q:
	move.b (a2)+,d0
	beq .no
	cmp.b #'"',d0
	bne .q
	bra .l
.t:
	cmp.b #TK_REM,d0
	beq .no
	cmp.b #TK_APOS,d0
	beq .no
	cmp.b #TK_THEN,d0
	bne .l
.s:
	move.b (a2)+,d0
	cmp.b #' ',d0
	beq .s
	tst.b d0
	beq .yes
	cmp.b #TK_REM,d0
	beq .yes
	cmp.b #TK_APOS,d0
	beq .yes
.no:
	moveq #1,d0
	rts
.yes:
	moveq #0,d0
	rts

st_endif:
	rts

; ---------------------------------------------------------------- WHILE, REPEAT

st_while:
	bsr evaltruth
	tst.l d0
	beq .skip
	; true: push a frame that comes back to this WHILE, unless it's already there
	move.l D_CSP(a6),a0
	lea D_CSTTOP(a6),a1
	cmpa.l a1,a0
	bcc .push
	cmp.w #F_WHILE,FR_TYPE(a0)
	bne .push
	move.l D_STMT(a6),d0
	cmp.l FR_TEXT(a0),d0
	beq .r
.push:
	bsr pushframe
	move.w #F_WHILE,FR_TYPE(a0)
	move.l D_CURLIN(a6),FR_LINE(a0)
	move.l D_STMT(a6),FR_TEXT(a0)
	move.b D_SLIF(a6),FR_SLIF(a0)
.r:
	rts
.skip:
	; false: drop this WHILE's frame if it's on top, then go past the matching WEND
	move.l D_CSP(a6),a0
	lea D_CSTTOP(a6),a1
	cmpa.l a1,a0
	bcc .s
	cmp.w #F_WHILE,FR_TYPE(a0)
	bne .s
	move.l D_STMT(a6),d0
	cmp.l FR_TEXT(a0),d0
	bne .s
	lea FRAME(a0),a0
	move.l a0,D_CSP(a6)
.s:
	move.l a5,a0
	move.l D_CURLIN(a6),a1
	moveq #0,d5
	bsr skipstmt
.l:
	bsr nextstmt
	bmi .wh
	bsr peeka0
	cmp.b #TK_WHILE,d0
	bne .w
	addq.l #1,d5
	bra .n
.w:
	cmp.b #TK_WEND,d0
	bne .n
	subq.l #1,d5
	bpl .n
	addq.l #1,a0
	move.l a0,a5
	move.l a1,D_CURLIN(a6)
	clr.b D_SLIF(a6)
	bra after_stmt
.n:
	bsr skipstmt
	bra .l
.wh:
	ERROR E_WH

; WEND: back to the WHILE, which tests again
st_wend:
	move.l D_CSP(a6),a0
	lea D_CSTTOP(a6),a1
	cmpa.l a1,a0
	bcc .ww
	cmp.w #F_WHILE,FR_TYPE(a0)
	bne .ww
	move.l FR_LINE(a0),D_CURLIN(a6)
	move.l FR_TEXT(a0),a5
	move.b FR_SLIF(a0),D_SLIF(a6)
	bra newstmt
.ww:
	ERROR E_WW

st_repeat:
	bsr pushframe
	move.w #F_REPEAT,FR_TYPE(a0)
	move.l D_CURLIN(a6),FR_LINE(a0)
	move.l a5,FR_TEXT(a0)
	move.b D_SLIF(a6),FR_SLIF(a0)
	rts

st_until:
	move.l D_CSP(a6),a0
	lea D_CSTTOP(a6),a1
	cmpa.l a1,a0
	bcc .ur
	cmp.w #F_REPEAT,FR_TYPE(a0)
	bne .ur
	bsr evaltruth
	move.l D_CSP(a6),a0
	tst.l d0
	bne .done
	move.l FR_LINE(a0),D_CURLIN(a6)
	move.l FR_TEXT(a0),a5
	move.b FR_SLIF(a0),D_SLIF(a6)
	bra newstmt
.done:
	lea FRAME(a0),a0
	move.l a0,D_CSP(a6)
	rts
.ur:
	ERROR E_UR

; ---------------------------------------------------------------- SWITCH

; SWITCH expr
; CASE value [, value ...]     (statements for the case; the next CASE/DEFAULT ends them)
; DEFAULT                      (statements when no CASE matches)
; ENDSWITCH
st_switch:
	bsr eval
	lea D_VA(a6),a0
	lea D_SWVAL(a6),a1
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	clr.l D_SWDEFP(a6)
	move.l a5,a0
	move.l D_CURLIN(a6),a1
	moveq #0,d5			; nesting
	bsr skipstmt
.l:
	bsr nextstmt
	bmi .sw
	bsr peeka0
	cmp.b #TK_SWITCH,d0
	beq .nest
	cmp.b #TK_ENDSWITCH,d0
	beq .endsw
	tst.l d5
	bne .n
	cmp.b #TK_DEFAULT,d0
	beq .def
	cmp.b #TK_CASE,d0
	beq .case
.n:
	bsr skipstmt
	bra .l
.nest:
	addq.l #1,d5
	bra .n
.endsw:
	subq.l #1,d5
	bpl .n1
	; no CASE matched
	move.l D_SWDEFP(a6),d0
	beq .past
	move.l d0,a0
	move.l D_SWDEFL(a6),a1
	bra .go
.past:
	addq.l #1,a0
.go:
	move.l a0,a5
	move.l a1,D_CURLIN(a6)
	clr.b D_SLIF(a6)
	bra newstmt
.n1:
	addq.l #1,a0
	bra .n
.def:
	tst.l D_SWDEFP(a6)
	bne .n1
	lea 1(a0),a2
	move.l a2,D_SWDEFP(a6)
	move.l a1,D_SWDEFL(a6)
	bra .n1
.case:
	lea 1(a0),a5
	move.l a1,D_CURLIN(a6)		; for errors in the values
.cl:
	bsr eval
	lea D_SWVAL(a6),a0
	lea D_VB(a6),a1
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	moveq #OP_EQ,d0
	bsr binop
	tst.l D_VA+8(a6)
	bne .match
	bsr peek
	cmp.b #',',d0
	bne .cn
	addq.l #1,a5
	bra .cl
.cn:
	move.l a5,a0
	move.l D_CURLIN(a6),a1
	moveq #0,d5
	bra .n
.match:
	move.l a5,a0
	bsr skipstmt			; past the rest of the values
	move.l a0,a5
	clr.b D_SLIF(a6)
	bra newstmt
.sw:
	ERROR E_SW

; CASE or DEFAULT reached by running: the end of a case. Go past ENDSWITCH
st_case:
	move.l a5,a0
	move.l D_CURLIN(a6),a1
	moveq #0,d5
	bsr skipstmt
.l:
	bsr nextstmt
	bmi .sw
	bsr peeka0
	cmp.b #TK_SWITCH,d0
	bne .e
	addq.l #1,d5
	bra .n
.e:
	cmp.b #TK_ENDSWITCH,d0
	bne .n
	subq.l #1,d5
	bpl .n
	addq.l #1,a0
	move.l a0,a5
	move.l a1,D_CURLIN(a6)
	clr.b D_SLIF(a6)
	bra after_stmt
.n:
	bsr skipstmt
	bra .l
.sw:
	ERROR E_SW

st_endsw:
	rts

; ---------------------------------------------------------------- FOR, NEXT

st_for:
	bsr getname
	cmp.b #'(',(a5)
	beq .sn
	cmp.w #K_STR,d7
	beq .tm
	bsr scalar			; -> A1
	move.l a1,D_FORVAR(a6)
	move.w d7,D_FORKIND(a6)
	EXPECT '='
	bsr evalnum
	move.l D_FORVAR(a6),a1
	move.w D_FORKIND(a6),d7
	bsr assign
	bsr peek
	cmp.b #TK_TO,d0
	bne .sn
	addq.l #1,a5
	bsr evalnum
	bsr forconv
	lea D_VA(a6),a0
	lea D_FORLIM(a6),a1
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	bsr peek
	cmp.b #TK_STEP,d0
	bne .one
	addq.l #1,a5
	bsr evalnum
	bra .st
.one:
	lea D_VA(a6),a0
	move.w #T_INT,(a0)
	clr.l 4(a0)
	move.l #1,8(a0)
.st:
	bsr forconv
	lea D_VA(a6),a0
	lea D_FORSTEP(a6),a1
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	; a FOR for the same variable that's still on the stack goes, with everything above it
	move.l D_CSP(a6),a0
	lea D_CSTTOP(a6),a1
	move.l D_FORVAR(a6),d1
.fl:
	cmpa.l a1,a0
	bcc .push
	cmp.w #F_FOR,FR_TYPE(a0)
	bne .fn
	cmp.l FR_VAR(a0),d1
	bne .fn
	lea FRAME(a0),a0
	move.l a0,D_CSP(a6)
	bra .push
.fn:
	lea FRAME(a0),a0
	bra .fl
.push:
	bsr pushframe
	move.w #F_FOR,FR_TYPE(a0)
	move.w D_FORKIND(a6),FR_KIND(a0)
	move.l D_FORVAR(a6),FR_VAR(a0)
	move.l D_CURLIN(a6),FR_LINE(a0)
	move.l a5,FR_TEXT(a0)
	move.b D_SLIF(a6),FR_SLIF(a0)
	lea D_FORLIM(a6),a1
	lea FR_LIMIT(a0),a2
	moveq #7,d0
.c1:
	move.l (a1)+,(a2)+		; limit and step (they're next to each other)
	dbra d0,.c1
	rts
.sn:
	ERROR E_SN
.tm:
	ERROR E_TM

; the FOR limit or step in VA to the type of the loop variable
forconv:
	lea D_VA(a6),a0
	cmp.w #K_FLT,D_FORKIND(a6)
	beq toflt
	bra toint

st_next:
	moveq #0,d7			; variable address, 0 = any
	bsr peek
	bsr isalpha
	bcs .find
	bsr getname
	bsr findvar
	move.l a0,d0
	beq .nf
	bsr vardata
	move.l a1,d7
.find:
	move.l D_CSP(a6),a2
	lea D_CSTTOP(a6),a1
.l:
	cmpa.l a1,a2
	bcc .nf
	cmp.w #F_FOR,FR_TYPE(a2)
	bne .skip
	tst.l d7
	beq .found
	cmp.l FR_VAR(a2),d7
	beq .found
.skip:
	cmp.w #F_GOSUB,FR_TYPE(a2)
	beq .nf
	lea FRAME(a2),a2
	bra .l
.found:
	move.l a2,D_CSP(a6)
	move.l FR_VAR(a2),a1
	move.w FR_KIND(a2),d0
	cmp.w #K_FLT,d0
	beq .flt
	; integer: var += step, compare with the limit
	cmp.w #K_INT,d0
	bne .long
	move.l (a1),d1
	smi d0
	ext.w d0
	ext.l d0
	bra .ia
.long:
	move.l (a1),d0
	move.l 4(a1),d1
.ia:
	add.l FR_STEP+8(a2),d1
	move.l FR_STEP+4(a2),d2
	addx.l d2,d0
	cmp.w #K_INT,FR_KIND(a2)
	bne .sl
	move.l d1,(a1)
	move.l d1,d0			; compare the 32 bit value, sign extended
	smi d0
	ext.w d0
	ext.l d0
	bra .ic
.sl:
	move.l d0,(a1)
	move.l d1,4(a1)
.ic:
	move.l FR_LIMIT+4(a2),d2
	move.l FR_LIMIT+8(a2),d3
	bsr cmp64			; D4 = 1 equal, 2 less, 4 greater (var vs limit)
	tst.l FR_STEP+4(a2)
	bra .test
.flt:
	move.l a1,a0
	lea FPACC,a3
	bsr fcopy
	lea FR_STEP+4(a2),a0
	lea FPARG,a3
	bsr fcopy
	move.b #X,FP_ADD
	bsr fcheck
	lea FPACC,a0
	move.l a1,a3
	bsr fcopy
	lea FR_LIMIT+4(a2),a0
	lea FPARG,a3
	bsr fcopy
	move.b #X,FP_CMP
	moveq #0,d4
	move.b FPCOND,d4
	tst.b FR_STEP+13(a2)		; the sign of the step
.test:
	bmi .neg
	and.b #3,d4			; step >= 0: go on while var <= limit
	bra .t
.neg:
	and.b #5,d4			; step < 0: go on while var >= limit
.t:
	beq .done
	move.l FR_LINE(a2),D_CURLIN(a6)
	move.l FR_TEXT(a2),a5
	move.b FR_SLIF(a2),D_SLIF(a6)
	bra newstmt
.done:
	lea FRAME(a2),a2
	move.l a2,D_CSP(a6)
	bsr peek
	cmp.b #',',d0
	bne .r
	addq.l #1,a5
	bra st_next
.r:
	rts
.nf:
	ERROR E_NF

; ---------------------------------------------------------------- LET, PRINT

st_let:
	bsr target			; -> A1, D7
	move.l a1,-(sp)
	move.w d7,-(sp)
	EXPECT '='
	bsr eval
	move.w (sp)+,d7
	move.l (sp)+,a1
	bra assign

st_print:
	bsr peek
	cmp.b #TK_USING,d0
	beq st_using
	moveq #0,d7			; 1: the last item was ; or , (no new line)
.l:
	bsr peek
	beq .end
	cmp.b #':',d0
	beq .end
	cmp.b #TK_ELSE,d0
	beq .end
	moveq #1,d7
	cmp.b #';',d0
	bne .c
	addq.l #1,a5
	bra .l
.c:
	cmp.b #',',d0
	bne .t
	addq.l #1,a5
.z:
	bsr space			; to the next 14 column zone
	moveq #0,d0
	move.b IO_CON_CURSORH,d0
	divu #14,d0
	swap d0
	tst.w d0
	bne .z
	bra .l
.t:
	cmp.b #TK_TAB,d0
	bne .s
	addq.l #1,a5
	bsr parenbyte			; TAB(0) is the first column
.tl:
	cmp.b IO_CON_CURSORH,d1
	bls .l
	bsr space
	bra .tl
.s:
	cmp.b #TK_SPC,d0
	bne .e
	addq.l #1,a5
	bsr parenbyte
.sl:
	tst.b d1
	beq .l
	bsr space
	subq.b #1,d1
	bra .sl
.e:
	bsr eval
	bsr printva
	moveq #0,d7
	bra .l
.end:
	tst.l d7
	bne .r
	bsr crlf
.r:
	rts

; ( byte expression ) -> D1
parenbyte:
	EXPECT '('
	bsr evalbyte
	EXPECT ')'
	rts

; print VA: strings as they are, numbers with a space (or -) in front and a space after
printva:
	cmp.w #T_STR,D_VA(a6)
	bne .n
	move.l D_VA+4(a6),a0
	move.l D_VA+8(a6),d1
	bra putn
.n:
	bsr numtext			; -> A0
	cmp.b #'-',(a0)
	beq .p
	bsr space
.p:
	bsr puts
	bra space

; ---------------------------------------------------------------- INPUT, LINE INPUT

st_input:
	move.l a5,D_INSAVE(a6)
.again:
	bsr peek
	cmp.b #'"',d0
	bne .q
	bsr eval			; the prompt
	bsr printva
	bsr peek
	cmp.b #',',d0
	beq .np
	EXPECT ';'
	bra .q
.np:
	addq.l #1,a5
	bra .read
.q:
	PRINTS "? "
.read:
	move.l a5,-(sp)
	bsr inputline
	bmi .brk
	move.l (sp)+,a5
	move.l a0,a3			; the typed line
.var:
	move.l a3,-(sp)
	bsr target			; -> A1, D7
	move.l (sp)+,a3
	movem.l a1/a3,-(sp)
	move.w d7,-(sp)
	move.l a3,a0
	bsr field			; -> A0 = text, D1 = length, A3 after the field
	move.w (sp)+,d7
	move.l (sp)+,a1
	addq.l #4,sp
	cmp.w #K_STR,d7
	bne .num
	move.l a0,D_VA+4(a6)
	move.l d1,D_VA+8(a6)
	move.w #T_STR,D_VA(a6)
	bra .set
.num:
	move.l d1,d0
	movem.l a1/a3,-(sp)
	move.w d7,-(sp)
	bsr strnum
	move.w (sp)+,d7
	movem.l (sp)+,a1/a3
	tst.l d0
	bne .redo
.set:
	move.l a3,-(sp)
	bsr assign
	move.l (sp)+,a3
	bsr peek
	cmp.b #',',d0
	bne .done
	addq.l #1,a5
	move.l a3,a0
	bsr peeka0
	tst.b d0
	beq .redo			; not enough typed
	bra .var
.done:
	move.l a3,a0
	bsr peeka0
	tst.b d0
	beq .r
	PRINTS <"?Extra ignored",13>
.r:
	rts
.redo:
	PRINTS <"?Redo from start",13>
	move.l D_INSAVE(a6),a5
	bra .again
.brk:
	move.l D_STMT(a6),a5
	bra do_break

; the next field of an INPUT line at A0: a quoted string, or text up to a comma (spaces
; around it removed). -> A0 = start, D1 = length, A3 = after it (and after its comma)
field:
	bsr peeka0
	cmp.b #'"',d0
	bne .u
	addq.l #1,a0
	move.l a0,a2
.q:
	move.b (a0),d0
	beq .qe
	addq.l #1,a0
	cmp.b #'"',d0
	bne .q
	move.l a0,d1
	subq.l #1,d1
	bra .ql
.qe:
	move.l a0,d1
.ql:
	sub.l a2,d1
	bsr peeka0
	bra .comma
.u:
	move.l a0,a2
.ul:
	move.b (a0),d0
	beq .ue
	cmp.b #',',d0
	beq .ue
	addq.l #1,a0
	bra .ul
.ue:
	move.l a0,a1			; trim spaces off the end
.ut:
	cmpa.l a2,a1
	bls .uz
	cmp.b #' ',-1(a1)
	bne .uz
	subq.l #1,a1
	bra .ut
.uz:
	move.l a1,d1
	sub.l a2,d1
.comma:
	cmp.b #',',(a0)
	bne .r
	addq.l #1,a0
.r:
	move.l a0,a3
	move.l a2,a0
	rts

; LINE INPUT ["prompt";] string variable: the whole line
st_line:
	bsr peek
	cmp.b #TK_INPUT,d0
	bne st_gline
	addq.l #1,a5
	bsr peek
	cmp.b #'"',d0
	bne .v
	bsr eval
	bsr printva
	bsr peek
	cmp.b #',',d0
	beq .c
	EXPECT ';'
	bra .v
.c:
	addq.l #1,a5
.v:
	bsr target
	cmp.w #K_STR,d7
	bne .tm
	movem.l a1,-(sp)
	move.l a5,-(sp)
	bsr inputline
	bmi .brk
	move.l (sp)+,a5
	movem.l (sp)+,a1
	move.l a0,D_VA+4(a6)
	move.w #T_STR,D_VA(a6)
	moveq #-1,d1
.len:
	addq.l #1,d1
	tst.b (a0)+
	bne .len
	move.l d1,D_VA+8(a6)
	moveq #K_STR,d7
	bra assign
.brk:
	move.l D_STMT(a6),a5
	bra do_break
.sn:
	ERROR E_SN
.tm:
	ERROR E_TM

; ---------------------------------------------------------------- READ, DATA, RESTORE

st_read:
.l:
	bsr target			; -> A1, D7
	movem.l a1,-(sp)
	move.w d7,-(sp)
	bsr dataitem			; -> A0, D1
	move.w (sp)+,d7
	movem.l (sp)+,a1
	cmp.w #K_STR,d7
	bne .num
	move.l a0,D_VA+4(a6)
	move.l d1,D_VA+8(a6)
	move.w #T_STR,D_VA(a6)
	bra .set
.num:
	move.l d1,d0
	movem.l a1,-(sp)
	move.w d7,-(sp)
	bsr strnum
	move.w (sp)+,d7
	movem.l (sp)+,a1
	tst.l d0
	bne .sn
.set:
	bsr assign
	bsr peek
	cmp.b #',',d0
	bne .r
	addq.l #1,a5
	bra .l
.r:
	rts
.sn:
	move.l D_DATLIN(a6),D_CURLIN(a6)	; the error is in the DATA line
	ERROR E_SN

; the next DATA item -> A0 = text, D1 = length
dataitem:
	move.l D_DATPTR(a6),a0
	move.l D_DATLIN(a6),a1
	move.b D_DATIN(a6),d0
	beq .search
	cmp.b #1,d0
	beq .item
	bsr peeka0			; after an item: a comma, or the end of the statement
	cmp.b #',',d0
	bne .search
	addq.l #1,a0
	bra .item
.search:
	tst.w (a1)			; no program at all
	beq .od
.sl:
	bsr peeka0
	beq .next
	cmp.b #':',d0
	beq .next
	cmp.b #TK_DATA,d0
	beq .found
	bsr skipstmt
.next:
	bsr nextstmt
	bmi .od
	bra .sl
.found:
	addq.l #1,a0
.item:
	bsr peeka0
	cmp.b #'"',d0
	bne .u
	addq.l #1,a0
	move.l a0,a2
.q:
	move.b (a0),d0
	beq .qe
	addq.l #1,a0
	cmp.b #'"',d0
	bne .q
	move.l a0,d1
	subq.l #1,d1
	bra .ql
.qe:
	move.l a0,d1
.ql:
	sub.l a2,d1
	bra .save
.u:
	move.l a0,a2
.ul:
	move.b (a0),d0
	beq .ue
	cmp.b #',',d0
	beq .ue
	cmp.b #':',d0
	beq .ue
	addq.l #1,a0
	bra .ul
.ue:
	move.l a0,a3
.ut:
	cmpa.l a2,a3
	bls .uz
	cmp.b #' ',-1(a3)
	bne .uz
	subq.l #1,a3
	bra .ut
.uz:
	move.l a3,d1
	sub.l a2,d1
.save:
	move.l a0,D_DATPTR(a6)
	move.l a1,D_DATLIN(a6)
	move.b #2,D_DATIN(a6)
	move.l a2,a0
	rts
.od:
	ERROR E_OD

; RESTORE [line]
st_restore:
	bsr peek
	bsr isjump
	bcs .top
	bsr jumpline
	bsr findline
	tst.l d1
	beq .us
	bra restore_at
.top:
	lea D_SIZE(a6),a0
	bra restore_at
.us:
	ERROR E_US

; ---------------------------------------------------------------- DIM

st_dim:
	bsr getname
	cmp.b #'(',(a5)
	bne .sn
	lea -SUBBLK(sp),sp
	bsr subscripts			; -> D6 = number of dimensions, the largest indexes at (sp)
	move.l sp,a0
	move.w d6,d0
	subq.w #1,d0
.c:
	addq.l #1,(a0)+			; counts are one more than the largest index
	dbra d0,.c
	or.b #$80,d7
	bsr findvar
	move.l a0,d0
	bne .dd
	move.l sp,a2
	bsr makearray
	lea SUBBLK(sp),sp
	bsr peek
	cmp.b #',',d0
	bne .r
	addq.l #1,a5
	bra st_dim
.r:
	rts
.sn:
	ERROR E_SN
.dd:
	ERROR E_DD

; ---------------------------------------------------------------- LOMEM, HIMEM

; LOMEM address: use the BASIC buffer there, or start a new empty one there
st_lomem:
	bsr evaladdr
	move.l d1,d0
	btst #0,d0
	bne .fc
	cmp.l #DEF_LOMEM,d0
	bcs .fc
	move.l a6,-(sp)
	move.l d0,a6
	bsr checkblock
	beq .use
	; nothing there: a new buffer, up to the same HIMEM (or the default HIMEM if the
	; current one is below the new buffer)
	move.l (sp),a0
	move.l D_HIMEM(a0),d0
	move.l a6,d1
	add.l #D_SIZE+1024,d1
	cmp.l d1,d0
	bcc .hm
	move.l #DEF_HIMEM,d0
	cmp.l d1,d0
	bcs .fc1
.hm:
	bsr setup
	bsr do_new
	addq.l #4,sp
	jmp ready
.use:
	addq.l #4,sp
	move.l a6,BPTR
	clr.b D_LBLOK(a6)
	bsr checkprog
	beq .ok
	bsr clear_all
.ok:
	clr.l D_CONTPTR(a6)
	lea D_CSTTOP(a6),a0
	move.l a0,D_CSP(a6)
	jmp ready
.fc1:
	move.l (sp)+,a6
.fc:
	ERROR E_FC

; HIMEM address: the last byte the variables can use. Clears the variables
st_himem:
	bsr evaladdr
	move.l d1,d0
	cmp.l #RAMTOP,d0
	bcc .fc
	move.l D_PRGEND(a6),d2
	add.l #1024,d2
	cmp.l d2,d0
	bcs .fc
	move.l d0,D_HIMEM(a6)
	addq.l #1,d0
	and.b #$fe,d0
	move.l d0,D_MEMTOP(a6)
	bra clear_all
.fc:
	ERROR E_FC

; ---------------------------------------------------------------- variables

; parse a name at A5 into D_NAME/D_NAMELEN. D7 = its kind from the suffix
getname:
	bsr peek
	bsr isalpha
	bcs .sn
	lea D_NAME(a6),a0
	moveq #0,d1
.l:
	move.b (a5),d0
	bsr isalpha
	bcc .c
	bsr isdigit
	bcs .sfx
.c:
	cmp.b #'a',d0			; (crunch made it upper case already, apart from DATA/INPUT text)
	bcs .u
	sub.b #$20,d0
.u:
	addq.l #1,a5
	cmp.w #32,d1
	bcc .sn
	move.b d0,(a0)+
	addq.w #1,d1
	bra .l
.sfx:
	move.w d1,D_NAMELEN(a6)
	moveq #K_FLT,d7
	cmp.b #'$',d0
	bne .i
	moveq #K_STR,d7
	bra .t
.i:
	cmp.b #'%',d0
	bne .lg
	moveq #K_INT,d7
	bra .t
.lg:
	cmp.b #'&',d0
	bne .r
	cmp.b #'H',1(a5)		; &H after a name starts a number, not a suffix
	beq .r
	moveq #K_LONG,d7
.t:
	addq.l #1,a5
.r:
	rts
.sn:
	ERROR E_SN

; find the variable D_NAME of kind D7 (bit 7 = array) -> A0 entry, or 0. keeps D7
findvar:
	move.l D_FNFRAME(a6),d0
	beq .vars
	cmp.b #$40,d7
	bcc .vars
	move.l d0,a2
	move.w D_NAMELEN(a6),d2
.fr:
	move.w FN_CNT(a2),d1
	lea FN_ENT(a2),a0
	bra .fe
.fl:
	cmp.b 4(a0),d7
	bne .fn
	cmp.b 5(a0),d2
	bne .fn
	lea 6(a0),a1
	lea D_NAME(a6),a3
	move.w d2,d0
	subq.w #1,d0
.fc:
	cmpm.b (a1)+,(a3)+
	bne .fn
	dbra d0,.fc
	rts				; a parameter: A0 is laid out like a variable
.fn:
	lea FN_ESIZE(a0),a0
.fe:
	dbra d1,.fl
	move.l FN_PREV(a2),d0		; the next call out
	move.l d0,a2
	bne .fr
.vars:
	move.l D_VARBOT(a6),a0
	move.l D_MEMTOP(a6),a2
	move.w D_NAMELEN(a6),d2
.l:
	cmpa.l a2,a0
	bcc .nf
	cmp.b 4(a0),d7
	bne .nx
	cmp.b 5(a0),d2
	bne .nx
	lea 6(a0),a1
	lea D_NAME(a6),a3
	move.w d2,d1
	subq.w #1,d1
.c:
	cmpm.b (a1)+,(a3)+
	bne .nx
	dbra d1,.c
	rts
.nx:
	adda.l (a0),a0
	bra .l
.nf:
	suba.l a0,a0
	rts

; A0 = a variable entry -> A1 = its data
vardata:
	moveq #0,d0
	move.b 5(a0),d0
	addq.w #1,d0
	and.b #$fe,d0
	lea 6(a0,d0.w),a1
	rts

; sizes of the kinds
ksize:
	dc.b 0,4,8,10,8
	even

; the scalar D_NAME of kind D7: find it or make it -> A1 data. keeps D7
scalar:
	bsr findvar
	move.l a0,d0
	beq .new
	bra vardata
.new:
	moveq #0,d6
	lea ksize(pc),a0
	move.b (a0,d7.w),d6
	bra newvar

; make a variable D_NAME of kind D7 with D6 bytes of data (even) -> A0 entry, A1 data
; (zeroed). Only done when no temporary strings are in use. keeps D7
newvar:
	move.w D_NAMELEN(a6),d0
	addq.w #1,d0
	and.w #$fffe,d0
	ext.l d0
	addq.l #6,d0
	add.l d6,d0			; entry size
	bsr .room
	bcc .ok
	tst.l D_GARBAGE(a6)
	beq .om
	movem.l d0/d6-d7,-(sp)
	bsr gc
	movem.l (sp)+,d0/d6-d7
	bsr .room
	bcs .om
.ok:
	move.l D_VARBOT(a6),a0
	suba.l d0,a0
	move.l a0,D_VARBOT(a6)
	move.l a0,D_TMPPTR(a6)
	move.l d0,(a0)
	move.b d7,4(a0)
	move.w D_NAMELEN(a6),d0
	move.b d0,5(a0)
	lea 6(a0),a1
	lea D_NAME(a6),a2
	subq.w #1,d0
.n:
	move.b (a2)+,(a1)+
	dbra d0,.n
	bsr vardata
	move.l a1,a2
	move.l d6,d0
	beq .r
	lsr.l #1,d0
	subq.l #1,d0
.z:
	clr.w (a2)+
	subq.l #1,d0
	bpl .z
.r:
	rts
.om:
	ERROR E_OM
.room:					; carry set if D0 bytes don't fit below the variables
	move.l D_VARBOT(a6),d1
	sub.l D_STRTOP(a6),d1
	sub.l #256,d1
	bcs .rr
	cmp.l d0,d1
.rr:
	rts

; an assignment target at A5 (variable or array element) -> A1 data, D7 kind
target:
	bsr getname
	cmp.b #'(',(a5)
	bne scalar
	moveq #1,d5			; make the array if it isn't there
	bra arrayref

; subscripts in parentheses at A5, for the array D_NAME of kind D7. The caller makes
; SUBBLK bytes on the stack: the values go there (up to 8). D6 = how many. Keeps the name
; and D7 (expressions in the subscripts can use other variables)
SUBBLK		equ	72
subscripts:
	move.w D_NAMELEN(a6),4+32(sp)
	move.w d7,4+34(sp)
	lea D_NAME(a6),a0
	lea 4+36(sp),a1
	moveq #7,d0
.sv:
	move.l (a0)+,(a1)+
	dbra d0,.sv
	clr.w 4+68(sp)
	addq.l #1,a5			; the (
.l:
	bsr eval
	lea D_VA(a6),a0
	bsr toint
	tst.l d0
	bne .bs
	cmp.l #$1000000,d1
	bcc .bs
	move.w 4+68(sp),d0
	cmp.w #8,d0
	bcc .bs
	add.w d0,d0
	add.w d0,d0
	move.l d1,4(sp,d0.w)
	addq.w #1,4+68(sp)
	bsr peek
	addq.l #1,a5
	cmp.b #',',d0
	beq .l
	cmp.b #')',d0
	bne .sn
	move.w 4+32(sp),D_NAMELEN(a6)
	move.w 4+34(sp),d7
	lea 4+36(sp),a0
	lea D_NAME(a6),a1
	moveq #7,d0
.rs:
	move.l (a0)+,(a1)+
	dbra d0,.rs
	move.w 4+68(sp),d6
	ext.l d6
	rts
.bs:
	ERROR E_BS
.sn:
	ERROR E_SN

; an array element: D_NAME, kind D7, A5 at the (. The array has to have been made with
; DIM (D5 isn't used any more)
; -> A1 element, D7 kind
arrayref:
	move.w d5,-(sp)
	lea -SUBBLK(sp),sp
	bsr subscripts
	move.w SUBBLK(sp),d5
	or.b #$80,d7
	bsr findvar
	move.l a0,d0
	bne .have
	ERROR E_AN			; no DIM for it
.have:
	bsr vardata			; A1 = ndims.w, counts
	cmp.w (a1)+,d6
	bne .bs
	; offset = ((i0 * c1 + i1) * c2 + i2) ...
	moveq #0,d0
	move.l sp,a2			; indexes
	move.w d6,d3
	subq.w #1,d3
.o:
	move.l (a1)+,d1			; count
	move.l (a2)+,d2			; index
	cmp.l d1,d2
	bcc .bs
	bsr mul32lo			; D0 = D0 * D1
	add.l d2,d0
	dbra d3,.o
	moveq #0,d1
	and.w #$7f,d7
	lea ksize(pc),a0
	move.b (a0,d7.w),d1
	bsr mul32lo
	add.l d0,a1
.r:
	and.w #$7f,d7
	lea SUBBLK+2(sp),sp
	rts
.bs:
	ERROR E_BS

; make array D_NAME of kind D7 (bit 7 set or not) with D6 dimensions, counts at A2
makearray:
	or.b #$80,d7
	moveq #1,d4			; elements
	move.l a2,a3
	move.w d6,d3
	subq.w #1,d3
.t:
	move.l d4,d0
	move.l (a3)+,d1
	beq .fc
	bsr umul32
	tst.l d0
	bne .fc
	cmp.l #$1000000,d1
	bcc .fc
	move.l d1,d4
	dbra d3,.t
	moveq #0,d1
	move.b d7,d1
	and.b #$7f,d1
	lea ksize(pc),a0
	move.b (a0,d1.w),d1
	move.l d4,d0
	bsr mul32lo			; bytes of elements
	movem.l d6/a2,-(sp)
	move.l d6,d1
	add.l d1,d1
	add.l d1,d1
	addq.l #2,d1
	add.l d1,d0
	move.l d0,d6			; data size
	bsr newvar
	movem.l (sp)+,d6/a2
	move.w d6,(a1)+
	subq.w #1,d6
.c:
	move.l (a2)+,(a1)+
	dbra d6,.c
	rts
.fc:
	ERROR E_FC

; store VA in the variable at A1 of kind D7
assign:
	cmp.w #K_STR,d7
	beq .str
	cmp.w #T_STR,D_VA(a6)
	beq .tm
	lea D_VA(a6),a0
	cmp.w #K_FLT,d7
	beq .flt
	movem.l a1/d7,-(sp)
	bsr toint
	movem.l (sp)+,a1/d7
	cmp.w #K_INT,d7
	beq .i32
	move.l d0,(a1)+
.i32:
	move.l d1,(a1)
	rts
.flt:
	move.l a1,-(sp)
	bsr toflt
	move.l (sp)+,a3
	lea D_VA+4(a6),a0
	bra fcopy
.str:
	cmp.w #T_STR,D_VA(a6)
	bne .tm
	bra strassign
.tm:
	ERROR E_TM

; load the variable at A1 of kind D7 into VA
loadvar:
	lea D_VA(a6),a0
	cmp.w #K_STR,d7
	beq .str
	cmp.w #K_FLT,d7
	beq .flt
	move.w #T_INT,(a0)
	cmp.w #K_INT,d7
	beq .i32
	move.l (a1)+,4(a0)
	move.l (a1),8(a0)
	rts
.i32:
	move.l (a1),d1
	move.l d1,8(a0)
	smi d0
	ext.w d0
	ext.l d0
	move.l d0,4(a0)
	rts
.flt:
	move.w #T_FLT,(a0)
	move.l (a1)+,4(a0)
	move.l (a1)+,8(a0)
	move.w (a1),12(a0)
	rts
.str:
	move.w #T_STR,(a0)
	move.l (a1)+,4(a0)
	move.l (a1),8(a0)
	rts

; ---------------------------------------------------------------- expressions

; evaluate the expression at A5 into VA
eval:
	cmpa.l #STKLIMIT,sp
	bcs .st
	bra ex_xor
.st:
	ERROR E_ST

; push VA on the stack (keeps D0 and D7), pop into VB
	macro PUSHVA
	movem.l D_VA(a6),d1-d4
	movem.l d1-d4,-(sp)
	endm
	macro POPVB
	movem.l (sp)+,d1-d4
	movem.l d1-d4,D_VB(a6)
	endm

ex_xor:
	bsr ex_or
.l:
	bsr peek
	cmp.b #TK_XOR,d0
	bne .r
	addq.l #1,a5
	PUSHVA
	bsr ex_or
	POPVB
	moveq #OP_XOR,d0
	bsr binop
	bra .l
.r:
	rts

ex_or:
	bsr ex_and
.l:
	bsr peek
	cmp.b #TK_OR,d0
	bne .r
	addq.l #1,a5
	PUSHVA
	bsr ex_and
	POPVB
	moveq #OP_OR,d0
	bsr binop
	bra .l
.r:
	rts

ex_and:
	bsr ex_not
.l:
	bsr peek
	cmp.b #TK_AND,d0
	bne .r
	addq.l #1,a5
	PUSHVA
	bsr ex_not
	POPVB
	moveq #OP_AND,d0
	bsr binop
	bra .l
.r:
	rts

ex_not:
	bsr peek
	cmp.b #TK_NOT,d0
	bne ex_rel
	addq.l #1,a5
	bsr ex_not
	lea D_VA(a6),a0
	bsr toint
	not.l d0
	not.l d1
	movem.l d0-d1,D_VA+4(a6)
	rts

ex_rel:
	bsr ex_add
.l:
	bsr peek
	moveq #0,d7			; mask
.o:
	cmp.b #'=',d0
	bne .lt
	or.b #1,d7
	bra .n
.lt:
	cmp.b #'<',d0
	bne .gt
	or.b #2,d7
	bra .n
.gt:
	cmp.b #'>',d0
	bne .e
	or.b #4,d7
.n:
	addq.l #1,a5
	move.b (a5),d0
	bra .o
.e:
	tst.b d7
	beq .r
	cmp.b #7,d7			; <=> isn't an operator
	beq .sn
	move.w d7,-(sp)
	PUSHVA
	bsr ex_add
	POPVB
	move.w (sp)+,d0
	add.w #OP_REL,d0
	bsr binop
	bra .l
.r:
	rts
.sn:
	ERROR E_SN

ex_add:
	bsr ex_mod
.l:
	bsr peek
	moveq #OP_ADD,d7
	cmp.b #'+',d0
	beq .o
	moveq #OP_SUB,d7
	cmp.b #'-',d0
	bne .r
.o:
	addq.l #1,a5
	move.w d7,-(sp)
	PUSHVA
	bsr ex_mod
	POPVB
	move.w (sp)+,d0
	bsr binop
	bra .l
.r:
	rts

ex_mod:
	bsr ex_idiv
.l:
	bsr peek
	cmp.b #TK_MOD,d0
	bne .r
	addq.l #1,a5
	PUSHVA
	bsr ex_idiv
	POPVB
	moveq #OP_MOD,d0
	bsr binop
	bra .l
.r:
	rts

ex_idiv:
	bsr ex_mul
.l:
	bsr peek
	cmp.b #'\',d0
	bne .r
	addq.l #1,a5
	PUSHVA
	bsr ex_mul
	POPVB
	moveq #OP_IDIV,d0
	bsr binop
	bra .l
.r:
	rts

ex_mul:
	bsr ex_neg
.l:
	bsr peek
	moveq #OP_MUL,d7
	cmp.b #'*',d0
	beq .o
	moveq #OP_DIV,d7
	cmp.b #'/',d0
	bne .r
.o:
	addq.l #1,a5
	move.w d7,-(sp)
	PUSHVA
	bsr ex_neg
	POPVB
	move.w (sp)+,d0
	bsr binop
	bra .l
.r:
	rts

; unary minus binds less tightly than ^ (-2^2 is -4)
ex_neg:
	bsr peek
	cmp.b #'-',d0
	beq .neg
	cmp.b #'+',d0
	bne ex_pow
	addq.l #1,a5
	bra ex_neg
.neg:
	addq.l #1,a5
	bsr ex_neg
	bra negva

ex_pow:
	bsr primary
.l:
	bsr peek
	cmp.b #'^',d0
	bne .r
	addq.l #1,a5
	PUSHVA
	bsr powarg
	POPVB
	moveq #OP_POW,d0
	bsr binop
	bra .l
.r:
	rts
powarg:					; the right side of ^ can have a sign (2^-1)
	bsr peek
	cmp.b #'-',d0
	beq .neg
	cmp.b #'+',d0
	bne primary
	addq.l #1,a5
	bra powarg
.neg:
	addq.l #1,a5
	bsr powarg
	bra negva

; VA = -VA
negva:
	move.w D_VA(a6),d0
	cmp.w #T_INT,d0
	bne .f
	movem.l D_VA+4(a6),d0-d1
	neg.l d1
	negx.l d0
	movem.l d0-d1,D_VA+4(a6)
	rts
.f:
	cmp.w #T_FLT,d0
	bne .tm
	eor.b #$80,D_VA+13(a6)		; the sign is the top bit of the last byte
	rts
.tm:
	ERROR E_TM

primary:
	cmpa.l #STKLIMIT,sp
	bcs .st
	bsr peek
	bsr isdigit
	bcc .num
	cmp.b #'.',d0
	beq .num
	cmp.b #'&',d0
	beq .num
	cmp.b #'"',d0
	beq .str
	cmp.b #'(',d0
	beq .par
	bsr isalpha
	bcc .var
	cmp.b #TK_FIRSTFN,d0
	bcs .kw
	cmp.b #TK_LASTFN,d0
	bhi .sn
	addq.l #1,a5
	sub.b #TK_FIRSTFN,d0
	and.w #$ff,d0
	add.w d0,d0
	add.w d0,d0
	lea fntab(pc),a0
	move.l (a0,d0.w),a0
	jmp (a0)
.kw:
	addq.l #1,a5
	cmp.b #TK_CALL,d0
	beq fn_call
	cmp.b #TK_LOMEM,d0
	beq fn_lomem
	cmp.b #TK_HIMEM,d0
	beq fn_himem
	cmp.b #TK_FN,d0
	beq fn_user
.sn:
	ERROR E_SN
.st:
	ERROR E_ST
.num:
	move.l a5,a0
	bsr parsenum
	bmi .sn
	move.l a0,a5
	rts
.str:
	addq.l #1,a5
	move.l a5,a0
.sl:
	move.b (a5),d0
	beq .se
	addq.l #1,a5
	cmp.b #'"',d0
	bne .sl
	move.l a5,d1
	subq.l #1,d1
	bra .sz
.se:
	move.l a5,d1
.sz:
	sub.l a0,d1
	move.w #T_STR,D_VA(a6)
	move.l a0,D_VA+4(a6)
	move.l d1,D_VA+8(a6)
	rts
.par:
	addq.l #1,a5
	bsr eval
	EXPECT ')'
	rts
.var:
	bsr getname
	cmp.b #'(',(a5)
	bne .scalar
	moveq #0,d5
	bsr arrayref
	bra loadvar
.scalar:
	bsr findvar
	move.l a0,d0
	beq .zero
	bsr vardata
	bra loadvar
.zero:
	lea D_VZERO(a6),a1		; a variable that doesn't exist yet reads as 0 or ""
	bra loadvar

fntab:
	dc.l fn_sgn,fn_int,fn_fix,fn_abs,fn_sqr,fn_rnd,fn_log,fn_log
	dc.l fn_log10,fn_exp,fn_sin,fn_cos,fn_tan,fn_atn,fn_asn,fn_acs
	dc.l fn_pi,fn_root,fn_peek,fn_fre,fn_len,fn_asc,fn_val,fn_chr
	dc.l fn_str,fn_left,fn_right,fn_mid,fn_hex,fn_dec,fn_instr
	dc.l fn_string,fn_space,fn_ucase,fn_lcase,fn_inkey,fn_pos,fn_cint,fn_err,fn_erl

; ---------------------------------------------------------------- operators

; VA = VB op VA, D0 = the operator
binop:
	move.w d0,d7
	move.w D_VB(a6),d1
	move.w D_VA(a6),d2
	cmp.w #T_STR,d1
	beq .str
	cmp.w #T_STR,d2
	beq .tm
	cmp.w #OP_DIV,d7
	beq .float
	cmp.w #OP_POW,d7
	beq .float
	cmp.w #OP_IDIV,d7
	beq .int
	cmp.w #OP_MOD,d7
	beq .int
	cmp.w #OP_AND,d7
	bcc .int0			; AND OR XOR (and the comparisons, checked next)
	bra .mixed
.int0:
	cmp.w #OP_REL,d7
	bcs .int
.mixed:
	cmp.w #T_INT,d1			; + - * and comparisons: integers if both are
	bne .float
	cmp.w #T_INT,d2
	bne .float
.int:
	lea D_VB(a6),a0
	bsr toint
	movem.l d0-d1,-(sp)
	lea D_VA(a6),a0
	bsr toint
	move.l d0,d2
	move.l d1,d3
	movem.l (sp)+,d0-d1
	; D0:D1 = left, D2:D3 = right
	cmp.w #OP_REL,d7
	bcc .icmp
	move.w d7,d4
	add.w d4,d4
	move.w .it-2(pc,d4.w),d4
	jsr .it(pc,d4.w)
.iset:
	move.w #T_INT,D_VA(a6)
	movem.l d0-d1,D_VA+4(a6)
	rts
.it:
	dc.w .iadd-.it,.isub-.it,.imul-.it,0,.idiv-.it,.imod-.it,0,.iand-.it,.ior-.it,.ixor-.it
.iadd:
	add.l d3,d1
	addx.l d2,d0
	rts
.isub:
	sub.l d3,d1
	subx.l d2,d0
	rts
.imul:
	bra mul64
.idiv:
	bra divs64
.imod:
	bsr divs64
	move.l d2,d0
	move.l d3,d1
	rts
.iand:
	and.l d2,d0
	and.l d3,d1
	rts
.ior:
	or.l d2,d0
	or.l d3,d1
	rts
.ixor:
	eor.l d2,d0
	eor.l d3,d1
	rts
.icmp:
	bsr cmp64
	bra .relres
.float:
	lea D_VB(a6),a0
	bsr toflt
	lea D_VA(a6),a0
	bsr toflt
	lea D_VB+4(a6),a0
	lea FPACC,a3
	bsr fcopy
	lea D_VA+4(a6),a0
	lea FPARG,a3
	bsr fcopy
	cmp.w #OP_REL,d7
	bcc .fcmp
	move.w d7,d4
	lsl.w #2,d4
	lea .ft-4(pc),a0
	move.l (a0,d4.w),a0
	move.b #X,(a0)
	cmp.w #OP_DIV,d7
	bne .fk
	tst.b FPCOND
	bmi .dz
.fk:
	bsr fcheck
	lea FPACC,a0
	lea D_VA+4(a6),a3
	bsr fcopy
	move.w #T_FLT,D_VA(a6)
	rts
.ft:
	dc.l FP_ADD,FP_SUB,FP_MUL,FP_DIV,0,0,FP_POW
.fcmp:
	move.b #X,FP_CMP
	moveq #0,d4
	move.b FPCOND,d4
.relres:
	; D4 = what was found (1 equal, 2 less, 4 greater); the operator wants D7-OP_REL
	sub.w #OP_REL,d7
	and.b d7,d4
	sne d0
	ext.w d0
	ext.l d0
	move.l d0,d1
	bra .iset
.str:
	cmp.w #T_STR,d2
	bne .tm
	cmp.w #OP_ADD,d7
	beq concat
	cmp.w #OP_REL,d7
	bcs .tm
	bsr strcmp
	bra .relres
.dz:
	ERROR E_DZ
.tm:
	ERROR E_TM

; ---------------------------------------------------------------- graphics

VIDSTART	equ	$180000

; arguments for a statement, with or without parentheses: D0 = fewest, D1 = most.
; -> D_GARG (each a 32 bit integer), D_GCNT
gargs:
	movem.w d0-d1,-(sp)
	clr.w D_GCNT(a6)
	moveq #0,d0
	move.w d0,-(sp)			; parentheses?
	bsr peek
	cmp.b #'(',d0
	bne .l
	addq.l #1,a5
	move.w #1,(sp)
.l:
	bsr evalint
	move.l d1,d2			; it has to fit in 32 bits, signed
	smi d2
	ext.w d2
	ext.l d2
	cmp.l d2,d0
	bne .fc
	move.w D_GCNT(a6),d0
	cmp.w 4(sp),d0
	bcc .sn				; too many
	lsl.w #2,d0
	lea D_GARG(a6),a0
	move.l d1,(a0,d0.w)
	addq.w #1,D_GCNT(a6)
	bsr peek
	cmp.b #',',d0
	bne .e
	addq.l #1,a5
	bra .l
.e:
	tst.w (sp)+
	beq .c
	EXPECT ')'
.c:
	movem.w (sp)+,d0-d1
	cmp.w D_GCNT(a6),d0
	bhi .sn
	rts
.sn:
	ERROR E_SN
.fc:
	ERROR E_FC

; after an error or Ctrl-C in a graphics mode, go back to text so the message shows
textback:
	cmp.b #8,IO_VIDMODE
	bcc .r
	move.b #9,IO_VIDMODE
	bsr st_cls
.r:
	rts

; GR(mode): 0, 1, 2 (16 colors) or 4, 5, 6 (4096 colors). Clears the screen
st_gr:
	moveq #1,d0
	moveq #1,d1
	bsr gargs
	move.l D_GARG(a6),d0
	cmp.l #7,d0
	bcc .fc
	cmp.b #3,d0
	beq .fc
	move.b d0,IO_VIDMODE
	bra st_grcls
.fc:
	ERROR E_FC

; TEXT(mode): 8 (40 columns) or 9 (80 columns). Clears the screen
st_text:
	moveq #1,d0
	moveq #1,d1
	bsr gargs
	move.l D_GARG(a6),d0
	cmp.l #8,d0
	beq .ok
	cmp.l #9,d0
	bne .fc
.ok:
	move.b d0,IO_VIDMODE
	bra st_cls
.fc:
	ERROR E_FC

; the size of the graphics mode now in use -> D_GW, D_GH, D_GROW, D_GDEEP. Not a
; graphics mode: Illegal function call
gsetup:
	moveq #0,d0
	move.b IO_VIDMODE,d0
	cmp.w #7,d0
	bcc .fc
	cmp.w #3,d0
	beq .fc
	lsl.w #3,d0
	lea .t(pc,d0.w),a0
	move.w (a0)+,D_GW(a6)
	move.w (a0)+,D_GH(a6)
	move.w (a0)+,D_GROW(a6)
	move.w (a0)+,d0
	move.b d0,D_GDEEP(a6)
	rts
.t:
	dc.w 120,68,60,0, 240,136,120,0, 480,272,240,0, 0,0,0,0
	dc.w 120,68,240,1, 240,136,480,1, 480,272,960,1
.fc:
	ERROR E_FC

; GRCLS: clear the graphics screen to black
st_grcls:
	bsr gsetup
	move.w D_GH(a6),d0
	mulu D_GROW(a6),d0
	lsr.l #2,d0
	subq.l #1,d0
	lea VIDSTART,a0
.c:
	clr.l (a0)+
	subq.l #1,d0
	bpl .c
	rts

; GRCOLOR(color): the color for drawing when none is given
st_grcolor:
	moveq #1,d0
	moveq #1,d1
	bsr gargs
	move.l D_GARG(a6),d0
	cmp.l #$10000,d0
	bcc .fc
	move.w d0,D_GRCOLOR(a6)
	rts
.fc:
	ERROR E_FC

; D7 = the color to draw with: argument D0 if there are more than D0 arguments, otherwise
; GRCOLOR. 16 color modes: 0-15 (GRCOLOR uses its low 4 bits), put in both nibbles.
; 4096 color modes: 16 bits, bytes swapped (video memory is low byte first)
gcolor:
	cmp.w D_GCNT(a6),d0
	bcc .def
	lsl.w #2,d0
	lea D_GARG(a6),a0
	move.l (a0,d0.w),d7
	tst.b D_GDEEP(a6)
	bne .deep
	cmp.l #16,d7
	bcc .fc
	bra .nib
.deep:
	cmp.l #$10000,d7
	bcc .fc
	bra .sw
.def:
	moveq #0,d7
	move.w D_GRCOLOR(a6),d7
	tst.b D_GDEEP(a6)
	bne .sw
	and.w #15,d7
.nib:
	move.b d7,d0
	lsl.b #4,d0
	or.b d0,d7
	rts
.sw:
	ror.w #8,d7
	rts
.fc:
	ERROR E_FC

; coordinates in D_GARG must be within -32768..32767
gcoords:
	lea D_GARG(a6),a0
	move.w D_GCNT(a6),d1
	subq.w #1,d1
.l:
	move.l (a0)+,d0
	cmp.l #-32768,d0
	blt .fc
	cmp.l #32767,d0
	bgt .fc
	dbra d1,.l
	rts
.fc:
	ERROR E_FC

; plot (D2, D3) in color D7 (off the screen: nothing). keeps everything but D0/D1/A0
pset:
	cmp.w D_GW(a6),d2
	bcc .r
	cmp.w D_GH(a6),d3
	bcc .r
	move.w d3,d0
	mulu D_GROW(a6),d0
	lea VIDSTART,a0
	add.l d0,a0
	moveq #0,d1
	move.w d2,d1
	tst.b D_GDEEP(a6)
	beq .n
	add.l d1,d1
	move.w d7,(a0,d1.l)
	rts
.n:
	lsr.w #1,d1
	add.l d1,a0
	move.b (a0),d1
	btst #0,d2
	bne .odd
	and.b #$0f,d1			; the even pixel is the high nibble
	move.b d7,d0
	and.b #$f0,d0
	bra .s
.odd:
	and.b #$f0,d1
	move.b d7,d0
	and.b #$0f,d0
.s:
	or.b d0,d1
	move.b d1,(a0)
.r:
	rts

; a horizontal line from D2 to D4 on row D3 (D2 <= D4). keeps D2-D7
hline:
	cmp.w D_GH(a6),d3
	bcc .r
	movem.l d2/d4,-(sp)
	tst.l d2
	bpl .a
	moveq #0,d2
.a:
	moveq #0,d0
	move.w D_GW(a6),d0
	subq.l #1,d0
	cmp.l d0,d4
	ble .b
	move.l d0,d4
.b:
	cmp.l d4,d2
	bgt .e
	bsr pset
	addq.l #1,d2
	bra .b
.e:
	movem.l (sp)+,d2/d4
.r:
	rts

; a line from (D2, D3) to (D4, D5) in color D7 (Bresenham)
dline:
	move.l d4,d0
	sub.l d2,d0
	moveq #1,d1
	tst.l d0
	bpl .x
	neg.l d0
	moveq #-1,d1
.x:
	move.l d0,a1			; dx
	move.l d1,a3			; sx
	move.l d5,d0
	sub.l d3,d0
	moveq #1,d1
	tst.l d0
	bpl .y
	neg.l d0
	moveq #-1,d1
.y:
	neg.l d0
	move.l d0,a2			; -dy
	move.l d1,a4			; sy
	move.l a1,d6
	add.l a2,d6			; err
.l:
	bsr pset
	cmp.l d4,d2
	bne .s
	cmp.l d5,d3
	beq .r
.s:
	move.l d6,d0
	add.l d0,d0			; e2
	cmp.l a2,d0
	blt .n1
	add.l a2,d6
	add.l a3,d2
.n1:
	cmp.l a1,d0
	bgt .l
	add.l a1,d6
	add.l a4,d3
	bra .l
.r:
	rts

; PLOT(x, y [, color])
st_plot:
	moveq #2,d0
	moveq #3,d1
	bsr gargs
	bsr gsetup
	moveq #2,d0
	bsr gcolor
	movem.l D_GARG(a6),d2-d3
	bra pset

; LINE(x1, y1, x2, y2 [, color])
st_gline:
	bsr gfour
	bra dline

; the four corners and the color of LINE, RECTANGLE and CIRCLE -> D2-D5, D7
gfour:
	moveq #4,d0
	moveq #5,d1
	bsr gargs
	bsr gcoords
	bsr gsetup
	moveq #4,d0
	bsr gcolor
	movem.l D_GARG(a6),d2-d5
	rts

; put the corners in order: D2 <= D4, D3 <= D5
gorder:
	cmp.l d4,d2
	ble .x
	exg d2,d4
.x:
	cmp.l d5,d3
	ble .y
	exg d3,d5
.y:
	rts

; RECTANGLE(x1, y1, x2, y2 [, color])
st_rect:
	bsr gfour
	bsr gorder
	bsr hline			; top
	exg d3,d5
	bsr hline			; bottom
	exg d3,d5
	movem.l d2-d5,-(sp)
	move.l d2,d4
	bsr dline			; left
	movem.l (sp)+,d2-d5
	move.l d4,d2
	bra dline			; right

; FILLRECTANGLE(x1, y1, x2, y2 [, color])
st_fillrect:
	bsr gfour
	bsr gorder
	tst.l d3			; only the rows on the screen
	bpl .a
	moveq #0,d3
.a:
	moveq #0,d0
	move.w D_GH(a6),d0
	subq.l #1,d0
	cmp.l d0,d5
	ble .l
	move.l d0,d5
.l:
	cmp.l d5,d3
	bgt .r
	bsr hline
	addq.l #1,d3
	bra .l
.r:
	rts

; CIRCLE(x1, y1, x2, y2 [, color]): the circle (or ellipse) that fits in the rectangle
st_circle:
	moveq #0,d6
	bra ellipse
; FILLCIRCLE(x1, y1, x2, y2 [, color])
st_fillcircle:
	moveq #1,d6

; Alois Zingl's ellipse in a rectangle. D6 = 1 to fill. The rectangle can be at most 512
; pixels wide and high (to keep the arithmetic in 32 bits)
E_X0		equ	-4
E_Y0		equ	-8
E_X1		equ	-12
E_Y1		equ	-16
E_A		equ	-20
E_B		equ	-24
E_B1		equ	-28
E_DX		equ	-32
E_DY		equ	-36
E_ERR		equ	-40
E_FILL		equ	-44
ellipse:
	move.l d6,-(sp)
	bsr gfour
	move.l (sp)+,d6
	bsr gorder
	link a4,#-44
	move.l d6,E_FILL(a4)
	move.l d4,d0
	sub.l d2,d0			; a
	move.l d5,d1
	sub.l d3,d1			; b
	cmp.l #512,d0
	bhi .fc
	cmp.l #512,d1
	bhi .fc
	move.l d0,E_A(a4)
	move.l d1,E_B(a4)
	moveq #1,d6
	and.l d1,d6			; b1 = b & 1
	; dx = 4*(1-a)*b*b
	move.l d1,d0
	mulu d1,d0			; b*b
	move.l E_A(a4),d1
	subq.l #1,d1			; a-1 (0 or more)
	bsr mul32lo
	lsl.l #2,d0
	neg.l d0
	move.l d0,E_DX(a4)
	; dy = 4*(b1+1)*a*a
	move.l E_A(a4),d0
	mulu d0,d0			; a*a
	move.l d0,d1
	lsl.l #2,d1
	tst.l d6
	beq .d1
	add.l d1,d1
.d1:
	move.l d1,E_DY(a4)
	; err = dx + dy + b1*a*a
	move.l E_DX(a4),d1
	add.l E_DY(a4),d1
	tst.l d6
	beq .e1
	add.l d0,d1
.e1:
	move.l d1,E_ERR(a4)
	; y0 += (b+1)/2, y1 = y0 - b1
	move.l E_B(a4),d1
	addq.l #1,d1
	asr.l #1,d1
	add.l d1,d3
	move.l d3,d5
	sub.l d6,d5
	; a = 8*a*a, b1 = 8*b*b
	lsl.l #3,d0
	move.l d0,E_A(a4)
	move.l E_B(a4),d0
	mulu d0,d0
	lsl.l #3,d0
	move.l d0,E_B1(a4)
	move.l d2,E_X0(a4)
	move.l d3,E_Y0(a4)
	move.l d4,E_X1(a4)
	move.l d5,E_Y1(a4)
.loop:
	move.l E_X0(a4),d2
	move.l E_X1(a4),d4
	move.l E_Y0(a4),d3
	bsr .row
	move.l E_Y1(a4),d3
	bsr .row
	move.l E_ERR(a4),d0
	add.l d0,d0			; e2
	cmp.l E_DY(a4),d0
	bgt .nx
	addq.l #1,E_Y0(a4)		; y step
	subq.l #1,E_Y1(a4)
	move.l E_A(a4),d1
	add.l d1,E_DY(a4)
	move.l E_DY(a4),d1
	add.l d1,E_ERR(a4)
.nx:
	cmp.l E_DX(a4),d0
	bge .xs
	move.l E_ERR(a4),d1
	add.l d1,d1
	cmp.l E_DY(a4),d1
	ble .ny
.xs:
	addq.l #1,E_X0(a4)		; x step
	subq.l #1,E_X1(a4)
	move.l E_B1(a4),d1
	add.l d1,E_DX(a4)
	move.l E_DX(a4),d1
	add.l d1,E_ERR(a4)
.ny:
	move.l E_X0(a4),d0
	cmp.l E_X1(a4),d0
	ble .loop
	; flat ellipses: finish the tips
.tip:
	move.l E_Y0(a4),d0
	sub.l E_Y1(a4),d0
	move.l d5,d1
	move.l E_B(a4),d1
	cmp.l d1,d0
	bge .done
	move.l E_X0(a4),d2
	subq.l #1,d2
	move.l E_X1(a4),d4
	addq.l #1,d4
	move.l E_Y0(a4),d3
	bsr .row
	addq.l #1,E_Y0(a4)
	move.l E_Y1(a4),d3
	bsr .row
	subq.l #1,E_Y1(a4)
	bra .tip
.done:
	unlk a4
	rts
.fc:
	unlk a4
	ERROR E_FC
; row D3: the points D2 and D4, or everything between them
.row:
	tst.l E_FILL(a4)
	bne hline
	bsr pset
	exg d2,d4
	bsr pset
	exg d2,d4
	rts

; ---------------------------------------------------------------- DEF FN

; DEF FNname[(param, ...)] = expression     (in a program)
st_def:
	move.l D_CURLIN(a6),a0
	cmp.l #DIRECT,LNUM(a0)
	beq .id
	bsr peek
	cmp.b #TK_FN,d0
	bne .sn
	addq.l #1,a5
	bsr getname
	or.b #$40,d7
	bsr findvar
	move.l a0,d0
	beq .new
	bsr vardata
	bra .set
.new:
	moveq #8,d6
	bsr newvar
.set:
	move.l a5,(a1)			; the parameters, then = expression
	move.l D_CURLIN(a6),4(a1)
	move.l a5,a0
	bsr skipstmt
	move.l a0,a5
	rts
.sn:
	ERROR E_SN
.id:
	ERROR E_ID

; FNname[(arg, ...)]: a user function
fn_user:
	bsr getname
	or.b #$40,d7
	bsr findvar
	move.l a0,d0
	beq .uf
	bsr vardata
	lea -FN_SIZE(sp),sp
	clr.w FN_CNT(sp)
	and.w #$3f,d7
	move.w d7,FN_KIND(sp)
	move.l a5,FN_CALLER(sp)
	move.l (a1),a5			; the definition
	; the parameter names
	bsr peek
	cmp.b #'(',d0
	bne .np
	addq.l #1,a5
.pl:
	move.w FN_CNT(sp),d0
	cmp.w #FN_MAX,d0
	bcc .sn
	mulu #FN_ESIZE,d0
	lea FN_ENT(sp,d0.l),a2
	move.l a2,-(sp)
	bsr getname
	move.l (sp)+,a2
	move.b d7,4(a2)
	move.w D_NAMELEN(a6),d0
	move.b d0,5(a2)
	lea 6(a2),a3
	lea D_NAME(a6),a0
	subq.w #1,d0
.cn:
	move.b (a0)+,(a3)+
	dbra d0,.cn
	addq.w #1,FN_CNT(sp)
	bsr peek
	addq.l #1,a5
	cmp.b #',',d0
	beq .pl
	cmp.b #')',d0
	bne .sn
.np:
	EXPECT '='
	move.l a5,FN_EXPR(sp)
	; the arguments, worked out where the function is used
	move.l FN_CALLER(sp),a5
	tst.w FN_CNT(sp)
	beq .go
	EXPECT '('
	moveq #0,d0
.al:
	move.w d0,-(sp)
	bsr eval
	move.w (sp)+,d0
	move.w d0,d1
	mulu #FN_ESIZE,d1
	lea FN_ENT(sp,d1.l),a0
	move.w d0,-(sp)
	bsr vardata			; A1 = the parameter's data
	moveq #0,d7
	move.b 4(a0),d7
	cmp.w #K_STR,d7
	bne .an
	cmp.w #T_STR,D_VA(a6)
	bne .tm
	move.l D_VA+4(a6),(a1)		; strings are passed as they are
	move.l D_VA+8(a6),4(a1)
	bra .ad
.an:
	bsr assign
.ad:
	move.w (sp)+,d0
	addq.w #1,d0
	cmp.w FN_CNT(sp),d0
	beq .ae
	move.w d0,-(sp)
	EXPECT ','
	move.w (sp)+,d0
	bra .al
.ae:
	EXPECT ')'
.go:
	; run the definition with the parameters in scope
	move.l D_FNFRAME(a6),FN_PREV(sp)
	move.l sp,D_FNFRAME(a6)
	move.l a5,FN_CALLER(sp)
	move.l FN_EXPR(sp),a5
	bsr eval
	bsr peek			; the definition has to end there
	beq .end
	cmp.b #':',d0
	bne .sn
.end:
	move.l FN_PREV(sp),D_FNFRAME(a6)
	move.l FN_CALLER(sp),a5
	move.w FN_KIND(sp),d7
	lea FN_SIZE(sp),sp
	; the result as the function's type
	cmp.w #K_STR,d7
	bne .rn
	cmp.w #T_STR,D_VA(a6)
	bne .tm
	rts
.rn:
	cmp.w #T_STR,D_VA(a6)
	beq .tm
	lea D_VA(a6),a0
	cmp.w #K_FLT,d7
	beq toflt
	bsr toint
	cmp.w #K_INT,d7
	bne .r
	move.l d1,d0			; 32 bits
	smi d0
	ext.w d0
	ext.l d0
	bra setint
.r:
	rts
.uf:
	ERROR E_UF
.sn:
	ERROR E_SN
.tm:
	ERROR E_TM

; ---------------------------------------------------------------- SWAP, MID$ =

; SWAP var, var (the same type)
st_swap:
	bsr target
	movem.l a1/d7,-(sp)
	EXPECT ','
	bsr target
	movem.l (sp)+,a2/d6
	cmp.w d6,d7
	bne .tm
	lea ksize(pc),a0
	moveq #0,d0
	move.b (a0,d7.w),d0
	lsr.w #1,d0
	subq.w #1,d0
	move.l a1,a0
	move.l a2,a3
.s:
	move.w (a0),d1
	move.w (a3),(a0)+
	move.w d1,(a3)+
	dbra d0,.s
	cmp.w #K_STR,d7
	bne .r
	; the heap blocks know who owns them
	move.l a1,a0
	move.l a2,a3
	bsr .own
	move.l a2,a0
	move.l a1,a3
.own:					; A0 now holds what A3 had
	move.l (a0),d0
	beq .r
	move.l d0,a4
	subq.l #8,a4
	cmpa.l (a4),a3
	bne .r
	move.l a0,(a4)
.r:
	rts
.tm:
	ERROR E_TM

; MID$(var$, start [, n]) = string: replace characters (the length doesn't change)
st_midset:
	EXPECT '('
	bsr target
	cmp.w #K_STR,d7
	bne .tm
	move.l a1,-(sp)
	EXPECT ','
	bsr evalint
	tst.l d0
	bne .fc
	tst.l d1
	beq .fc
	move.l d1,-(sp)
	move.l #65535,d1
	bsr peek
	cmp.b #',',d0
	bne .nn
	addq.l #1,a5
	bsr evalint
	tst.l d0
	bne .fc
.nn:
	move.l d1,-(sp)
	EXPECT ')'
	EXPECT '='
	bsr evalstr
	move.l (sp)+,d2			; n
	move.l (sp)+,d1			; start
	move.l (sp)+,a1			; the variable
	move.l 4(a1),d3			; its length
	cmp.l d3,d1
	bhi .fc
	sub.l d1,d3
	addq.l #1,d3			; room from start to the end
	move.l D_VA+8(a6),d0
	cmp.l d2,d0
	bls .a
	move.l d2,d0
.a:
	cmp.l d3,d0
	bls .b
	move.l d3,d0
.b:
	move.l (a1),a1
	add.l d1,a1
	subq.l #1,a1
	move.l D_VA+4(a6),a0
	bra movebytes
.fc:
	ERROR E_FC
.tm:
	ERROR E_TM

; copy D0 bytes from A0 to A1, the right way round if they overlap
movebytes:
	tst.l d0
	beq .r
	cmpa.l a0,a1
	bcs copyb
	beq .r
	add.l d0,a0
	add.l d0,a1
.l:
	move.b -(a0),-(a1)
	subq.l #1,d0
	bne .l
.r:
	rts

; ELSEIF reached by running: the end of a THEN part, go past ENDIF
st_elseif:
	moveq #1,d6
	bra skipblock

; ---------------------------------------------------------------- ON ERROR, RESUME, ERROR

; ON ERROR GOTO line (0 = off)
st_onerror:
	addq.l #1,a5
	bsr peek
	cmp.b #TK_GOTO,d0
	bne .sn
	addq.l #1,a5
	bsr jumpline
	tst.l d0
	beq .off
	move.l d0,D_ONERR(a6)
	st D_ONERRF(a6)
	rts
.off:
	clr.b D_ONERRF(a6)
	tst.b D_INERR(a6)
	beq .r
	; inside the handler: stop with the error after all
	clr.b D_INERR(a6)
	move.l D_ERRLIN(a6),D_CURLIN(a6)
	moveq #0,d0
	move.w D_ERRCODE(a6),d0
	jmp error
.r:
	rts
.sn:
	ERROR E_SN

; RESUME [0 | NEXT | line]
st_resume:
	tst.b D_INERR(a6)
	beq .rw
	bsr peek
	beq .same
	cmp.b #':',d0
	beq .same
	cmp.b #TK_ELSE,d0
	beq .same
	cmp.b #TK_NEXT,d0
	beq .next
	bsr jumpline
	tst.l d0
	beq .same
	clr.b D_INERR(a6)
	bra goline
.same:
	clr.b D_INERR(a6)
	move.l D_ERRLIN(a6),D_CURLIN(a6)
	move.l D_ERRSTMT(a6),a5
	clr.b D_SLIF(a6)
	bra newstmt
.next:
	clr.b D_INERR(a6)
	move.l D_ERRLIN(a6),D_CURLIN(a6)
	move.l D_ERRSTMT(a6),a0
	bsr skipstmt
	move.l a0,a5
	clr.b D_SLIF(a6)
	bra newstmt
.rw:
	ERROR E_RW

; ERROR n: cause error n (1-255)
st_error:
	bsr evalint
	tst.l d0
	bne .fc
	tst.l d1
	beq .fc
	cmp.l #256,d1
	bcc .fc
	lea gwnum(pc),a0
	moveq #0,d0
.l:
	cmp.b (a0,d0.w),d1
	beq .e
	addq.w #1,d0
	cmp.w #E_AN+1,d0
	bcs .l
	move.l d1,D_ERRNUM(a6)
	moveq #E_UP,d0
.e:
	jmp error
.fc:
	ERROR E_FC

fn_err:
	move.l D_ERRNUM(a6),d1
	moveq #0,d0
	bra setint
fn_erl:
	move.l D_ERRLINE(a6),d1
	moveq #0,d0
	bra setint

; ---------------------------------------------------------------- PRINT USING

; PRINT USING format$; item [, or ; item ...]
st_using:
	addq.l #1,a5
	bsr evalstr
	move.l D_VA+4(a6),D_UFMT(a6)
	move.l D_VA+8(a6),D_UFLEN(a6)
	beq .fc
	clr.l D_UPOS(a6)
	clr.b D_UNL(a6)
	bsr peek
	cmp.b #';',d0
	beq .s
	cmp.b #',',d0
	bne .sn
.s:
	addq.l #1,a5
.item:
	bsr peek
	beq .fin
	cmp.b #':',d0
	beq .fin
	cmp.b #TK_ELSE,d0
	beq .fin
	moveq #1,d0			; print up to the next field, going round if need be
	bsr ufield
	bsr eval
	cmp.b #1,D_UTYPE(a6)
	beq .num
	cmp.w #T_STR,D_VA(a6)
	bne .tm
	bsr ustr
	bra .sep
.num:
	cmp.w #T_STR,D_VA(a6)
	beq .tm
	bsr unum
.sep:
	clr.b D_UNL(a6)
	bsr peek
	cmp.b #';',d0
	beq .more
	cmp.b #',',d0
	bne .fin
.more:
	addq.l #1,a5
	st D_UNL(a6)
	bra .item
.fin:
	tst.b D_UNL(a6)
	bne .r
	moveq #0,d0			; the text after the last field
	bsr ufield
	bsr crlf
.r:
	rts
.fc:
	ERROR E_FC
.sn:
	ERROR E_SN
.tm:
	ERROR E_TM

; print the format's text from D_UPOS up to the next field and read that field into D_U...
; D0 = 1: go round to the start at the end (there must be a field somewhere); 0: stop at
; the end
ufield:
	move.l d0,d4
	moveq #0,d5			; went round already
	move.l D_UFMT(a6),a2
.l:
	move.l D_UPOS(a6),d3
	cmp.l D_UFLEN(a6),d3
	bcs .c
	tst.l d4
	beq .none
	tst.l d5
	bne .fc
	moveq #1,d5
	clr.l D_UPOS(a6)
	bra .l
.c:
	lea (a2,d3.l),a0
	bsr ustart			; a field here?
	tst.b D_UTYPE(a6)
	bne .r
	move.b (a0),d0
	cmp.b #'_',d0			; _ prints the next character as it is
	bne .p
	addq.l #1,D_UPOS(a6)
	move.l D_UPOS(a6),d3
	cmp.l D_UFLEN(a6),d3
	bcc .l
	move.b 1(a0),d0
.p:
	bsr putc
	addq.l #1,D_UPOS(a6)
	bra .l
.none:
	clr.b D_UTYPE(a6)
.r:
	rts
.fc:
	ERROR E_FC

; is there a field at A0 (position D_UPOS)? sets D_UTYPE (0 = no) and moves D_UPOS past it
ustart:
	clr.b D_UTYPE(a6)
	move.l D_UFMT(a6),a1
	add.l D_UFLEN(a6),a1		; the end
	move.b (a0),d0
	cmp.b #'!',d0
	bne .bs
	move.b #2,D_UTYPE(a6)
	addq.l #1,D_UPOS(a6)
	rts
.bs:
	cmp.b #'&',d0
	bne .bk
	move.b #4,D_UTYPE(a6)
	addq.l #1,D_UPOS(a6)
	rts
.bk:
	cmp.b #'\',d0
	bne .n
	lea 1(a0),a3
.bl:
	cmpa.l a1,a3
	bcc .no				; no closing \: just text
	cmp.b #' ',(a3)
	bne .be
	addq.l #1,a3
	bra .bl
.be:
	cmp.b #'\',(a3)
	bne .no
	addq.l #1,a3
	move.l a3,d0
	sub.l a0,d0
	move.w d0,D_UWID(a6)
	add.l d0,D_UPOS(a6)
	move.b #3,D_UTYPE(a6)
	rts
.n:
	; a number field? + # . $$ ** **$
	move.l a0,a3
	clr.l D_UBEF(a6)		; UBEF and UDIG
	clr.w D_UDEC(a6)
	clr.l D_UPT(a6)			; UPT UCOMMA UPLUS UTRAIL
	clr.l D_USTAR(a6)		; USTAR UDOLLAR UEXP
	cmp.b #'+',(a3)
	bne .st
	; + only starts a field if # or . (then #) or $$ or ** follows
	lea 1(a3),a4
	bsr .numahead
	bcs .no
	st D_UPLUS(a6)
	addq.w #1,D_UBEF(a6)
	addq.l #1,a3
.st:
	bsr .is2star
	bne .dl
	st D_USTAR(a6)
	addq.w #2,D_UBEF(a6)
	addq.l #2,a3
	cmpa.l a1,a3
	bcc .digs
	cmp.b #'$',(a3)
	bne .digs
	st D_UDOLLAR(a6)
	addq.w #1,D_UBEF(a6)
	addq.l #1,a3
	bra .digs
.dl:
	cmp.b #'$',(a3)
	bne .digs0
	lea 1(a3),a4
	cmpa.l a1,a4
	bcc .no
	cmp.b #'$',(a4)
	bne .no
	st D_UDOLLAR(a6)
	addq.w #2,D_UBEF(a6)
	addq.l #2,a3
	bra .digs
.digs0:
	; it has to start with # or .#
	move.l a3,a4
	bsr .numahead
	bcs .no
.digs:
	cmpa.l a1,a3
	bcc .end
	move.b (a3),d0
	cmp.b #'#',d0
	bne .cm
	addq.w #1,D_UBEF(a6)
	addq.w #1,D_UDIG(a6)
	addq.l #1,a3
	bra .digs
.cm:
	cmp.b #',',d0
	bne .pt
	tst.w D_UBEF(a6)		; a comma only counts inside the digits
	beq .end
	st D_UCOMMA(a6)
	addq.w #1,D_UBEF(a6)
	addq.l #1,a3
	bra .digs
.pt:
	cmp.b #'.',d0
	bne .ex
	st D_UPT(a6)
	addq.l #1,a3
.dd:
	cmpa.l a1,a3
	bcc .end
	cmp.b #'#',(a3)
	bne .ex
	addq.w #1,D_UDEC(a6)
	addq.l #1,a3
	bra .dd
.ex:
	; ^^^^
	lea 4(a3),a4
	cmpa.l a1,a4
	bhi .tr
	cmp.b #'^',(a3)
	bne .tr
	cmp.b #'^',1(a3)
	bne .tr
	cmp.b #'^',2(a3)
	bne .tr
	cmp.b #'^',3(a3)
	bne .tr
	st D_UEXP(a6)
	addq.l #4,a3
.tr:
	cmpa.l a1,a3
	bcc .end
	cmp.b #'-',(a3)
	bne .tp
	move.b #1,D_UTRAIL(a6)
	addq.l #1,a3
	bra .end
.tp:
	tst.b D_UPLUS(a6)
	bne .end
	cmp.b #'+',(a3)
	bne .end
	move.b #2,D_UTRAIL(a6)
	addq.l #1,a3
.end:
	move.b #1,D_UTYPE(a6)
	move.l a3,d0
	sub.l a0,d0
	add.l d0,D_UPOS(a6)
.no:
	rts
; does a number field start at A4? (# or .# or $$ or **) carry clear if so
.numahead:
	cmpa.l a1,a4
	bcc .nah
	move.b (a4),d0
	cmp.b #'#',d0
	beq .yes
	cmp.b #'.',d0
	bne .na2
	lea 1(a4),a4
	cmpa.l a1,a4
	bcc .nah
	cmp.b #'#',(a4)
	beq .yes
	bra .nah
.na2:
	cmp.b #'$',d0
	beq .na3
	cmp.b #'*',d0
	bne .nah
.na3:
	lea 1(a4),a4
	cmpa.l a1,a4
	bcc .nah
	cmp.b (a4),d0
	beq .yes
.nah:
	ori.b #1,ccr
	rts
.yes:
	andi.b #$fe,ccr
	rts
; ** at A3? Z set if so
.is2star:
	lea 1(a3),a4
	cmpa.l a1,a4
	bcc .n2
	cmp.b #'*',(a3)
	bne .n2
	cmp.b #'*',(a4)
	rts
.n2:
	moveq #1,d0
	rts

; print the string VA in the field just read
ustr:
	move.l D_VA+4(a6),a0
	move.l D_VA+8(a6),d1
	cmp.b #4,D_UTYPE(a6)
	beq putn			; & all of it
	moveq #1,d2			; ! one character
	cmp.b #2,D_UTYPE(a6)
	beq .w
	move.w D_UWID(a6),d2
.w:
	cmp.l d2,d1
	bls .p
	move.l d2,d1
.p:
	sub.l d1,d2			; padding
	bsr putn
.sp:
	tst.l d2
	beq .r
	bsr space
	subq.l #1,d2
	bra .sp
.r:
	rts

; print the number VA in the field just read
unum:
	lea D_VA(a6),a0
	bsr toflt
	lea D_VA+4(a6),a0
	lea FPACC,a3
	bsr fcopy
	move.b #X,FP_CLASS
	moveq #2,d7
	and.b FPCOND,d7			; D7 = negative
	move.b #X+2,FP_FUNC		; |x|
	moveq #0,d0
	move.w D_UDEC(a6),d0
	cmp.w #20,d0
	bcs .dc
	moveq #19,d0
.dc:
	or.b #X,d0
	tst.b D_UEXP(a6)
	bne .e
	move.b d0,FP_TOAF
	bra .t
.e:
	move.b d0,FP_TOAE
.t:
	btst #5,FPCOND
	bne .over
	; the digits before the point (or the mantissa's one digit), then the rest
	lea FPASCII,a0
	lea D_SCRATCH(a6),a1
	moveq #0,d3			; integer digits
.i:
	move.b (a0),d0
	beq .ie
	cmp.b #'.',d0
	beq .ie
	cmp.b #'E',d0
	beq .ie
	move.b d0,(a1)+
	addq.l #1,a0
	addq.w #1,d3
	bra .i
.ie:
	move.l a0,a4			; the rest: .digits and/or E+nn
	; "0" with no # before the point prints nothing there
	cmp.w #1,d3
	bne .bl
	cmp.b #'0',D_SCRATCH(a6)
	bne .bl
	tst.w D_UDIG(a6)
	bne .bl
	moveq #0,d3
.bl:
	; build the left part at D_NUMBUF: sign, $, digits with commas
	lea D_NUMBUF(a6),a1
	tst.b D_UPLUS(a6)
	beq .ns
	moveq #'+',d0
	tst.b d7
	beq .ps
	moveq #'-',d0
.ps:
	move.b d0,(a1)+
	bra .dol
.ns:
	tst.b D_UTRAIL(a6)
	bne .dol
	tst.b d7
	beq .dol
	move.b #'-',(a1)+
.dol:
	tst.b D_UDOLLAR(a6)
	beq .dg
	move.b #'$',(a1)+
.dg:
	lea D_SCRATCH(a6),a0
	move.w d3,d4			; digits left
	bra .de
.dl:
	move.b (a0)+,(a1)+
	subq.w #1,d4
	beq .de
	tst.b D_UCOMMA(a6)
	beq .de
	moveq #0,d0
	move.w d4,d0
	divu #3,d0
	swap d0
	tst.w d0
	bne .de
	move.b #',',(a1)+
.de:
	tst.w d4
	bne .dl
	; pad to the width
	move.l a1,d1
	lea D_NUMBUF(a6),a0
	sub.l a0,d1			; length
	moveq #0,d2
	move.w D_UBEF(a6),d2
	sub.l d1,d2
	bcc .pad
	moveq #'%',d0			; too wide: % and all of it
	bsr putc
	moveq #0,d2
.pad:
	moveq #' ',d0
	tst.b D_USTAR(a6)
	beq .pl
	moveq #'*',d0
.pl:
	tst.l d2
	beq .pp
	bsr putc
	subq.l #1,d2
	bra .pl
.pp:
	bsr putn
	; the point, the decimals and the exponent
	move.l a4,a0
	bsr puts
	; a trailing sign
	move.b D_UTRAIL(a6),d1
	beq .r
	moveq #'-',d0
	tst.b d7
	bne .tc
	moveq #' ',d0
	cmp.b #2,d1
	bne .tc
	moveq #'+',d0
.tc:
	bra putc
.r:
	rts
.over:
	moveq #'%',d0			; doesn't fit at all
	bsr putc
	bsr numtext
	bra puts

; ---------------------------------------------------------------- RENUM

; RENUM [new [, from [, step]]]: renumber the lines from line "from" on (default: all),
; starting at new (default 10), step apart (default 10), and change the line numbers in
; GOTO, GOSUB, THEN, ELSE, ON ... GOTO/GOSUB, RESTORE, RUN and RESUME to match
st_renum:
	moveq #10,d0
	move.l d0,D_RNEW(a6)
	move.l d0,D_RSTEP(a6)
	clr.l D_RFROM(a6)
	bsr peek
	bsr isdigit
	bcs .a2
	bsr linenum
	move.l d0,D_RNEW(a6)
	bsr peek
.a2:
	cmp.b #',',d0
	bne .go
	addq.l #1,a5
	bsr peek
	bsr isdigit
	bcs .a3
	bsr linenum
	move.l d0,D_RFROM(a6)
	bsr peek
.a3:
	cmp.b #',',d0
	bne .go
	addq.l #1,a5
	bsr linenum
	tst.l d0
	beq .fc
	move.l d0,D_RSTEP(a6)
.go:
	; the line before "from" has to stay below the new numbers, and the last new number
	; has to fit
	lea D_SIZE(a6),a0
	moveq #0,d4			; lines being renumbered
	moveq #-1,d5			; the line before "from" (none)
	move.l D_RFROM(a6),d0
.c:
	tst.w (a0)
	beq .ce
	cmp.l LNUM(a0),d0
	bls .in
	move.l LNUM(a0),d5
	bra .cn
.in:
	addq.l #1,d4
.cn:
	adda.w (a0),a0
	bra .c
.ce:
	tst.l d4
	beq .done
	cmp.l #-1,d5
	beq .lo
	cmp.l D_RNEW(a6),d5
	bcc .fc
.lo:
	move.l d4,d0
	subq.l #1,d0
	move.l D_RSTEP(a6),d1
	bsr umul32
	tst.l d0
	bne .fc
	add.l D_RNEW(a6),d1
	bcs .fc
	cmp.l #DIRECT,d1
	bcc .fc
	; pass 1: the references (the line numbers aren't changed yet)
	lea D_SIZE(a6),a0
.p1:
	tst.w (a0)
	beq .p2
	move.l a0,-(sp)
	bsr rnline
	move.l (sp)+,a0
	adda.w (a0),a0
	bra .p1
.p2:
	; pass 2: the line numbers
	lea D_SIZE(a6),a0
	move.l D_RNEW(a6),d1
	move.l D_RFROM(a6),d0
.q:
	tst.w (a0)
	beq .done
	cmp.l LNUM(a0),d0
	bhi .qn
	move.l d1,LNUM(a0)
	add.l D_RSTEP(a6),d1
.qn:
	adda.w (a0),a0
	bra .q
.done:
	bsr clear_all
	clr.l D_CONTPTR(a6)
	jmp ready
.fc:
	ERROR E_FC

; the new number for old line D0 -> D1, carry set if there's no such line
rnmap:
	movem.l d2/a0,-(sp)
	lea D_SIZE(a6),a0
	moveq #0,d2			; index among the renumbered lines
.l:
	tst.w (a0)
	beq .no
	cmp.l LNUM(a0),d0
	bne .n
	move.l d0,d1			; found; it keeps its number if it's before "from"
	cmp.l D_RFROM(a6),d0
	bcs .yes
	move.l d2,d0
	move.l D_RSTEP(a6),d1
	bsr mul32lo
	add.l D_RNEW(a6),d0
	move.l d0,d1
	bra .yes
.n:
	move.l LNUM(a0),d1
	cmp.l D_RFROM(a6),d1
	bcs .nx
	addq.l #1,d2
.nx:
	adda.w (a0),a0
	bra .l
.yes:
	movem.l (sp)+,d2/a0
	andi.b #$fe,ccr
	rts
.no:
	movem.l (sp)+,d2/a0
	ori.b #1,ccr
	rts

; rewrite the references in line A0 (into D_CRUNCH, then back into the line)
rnline:
	move.l a0,a4			; the line
	lea LH(a0),a2			; from
	lea D_CRUNCH(a6),a3		; to
.l:
	move.b (a2)+,d0
	move.b d0,(a3)+
	beq .end
	cmp.b #'"',d0
	beq .str
	cmp.b #TK_REM,d0
	beq .raw
	cmp.b #TK_APOS,d0
	beq .raw
	cmp.b #TK_DATA,d0
	beq .data
	cmp.b #TK_GOTO,d0
	beq .list
	cmp.b #TK_GOSUB,d0
	beq .list
	cmp.b #TK_THEN,d0
	beq .one
	cmp.b #TK_ELSE,d0
	beq .one
	cmp.b #TK_RESTORE,d0
	beq .one
	cmp.b #TK_RUN,d0
	beq .one
	cmp.b #TK_RESUME,d0
	beq .one
	bra .l
.str:
	move.b (a2)+,d0
	move.b d0,(a3)+
	beq .end
	cmp.b #'"',d0
	bne .str
	bra .l
.raw:
	move.b (a2)+,(a3)+
	bne .raw
	bra .end
.data:
	moveq #0,d1
.dl:
	move.b (a2),d0
	beq .l
	cmp.b #'"',d0
	bne .dq
	not.b d1
.dq:
	tst.b d1
	bne .dc
	cmp.b #':',d0
	beq .l
.dc:
	move.b (a2)+,(a3)+
	bra .dl
.one:
	bsr .num
	bra .l
.list:
	bsr .num
	bcs .l
.ll:
	move.b (a2),d0			; , another number (ON ... GOTO)
	cmp.b #' ',d0
	bne .lc
	move.b (a2)+,(a3)+
	bra .ll
.lc:
	cmp.b #',',d0
	bne .l
	move.b (a2)+,(a3)+
	bsr .num
	bcc .ll
	bra .l
; spaces, then a line number to change. carry set if there was no number
.num:
	move.b (a2),d0
	cmp.b #' ',d0
	bne .nd
	move.b (a2)+,(a3)+
	bra .num
.nd:
	bsr isdigit
	bcs .nno
	; read it (an overflowing number is left alone)
	move.l a2,a1
	moveq #0,d0
	moveq #0,d1
.nr:
	move.b (a2),d1
	sub.b #'0',d1
	bcs .ne
	cmp.b #10,d1
	bcc .ne
	addq.l #1,a2
	cmp.l #429496729,d0
	bhi .nbig
	move.l d0,d2
	lsl.l #3,d0
	add.l d2,d0
	add.l d2,d0
	add.l d1,d0
	bcs .nbig
	bra .nr
.nbig:
	moveq #-1,d0
	bra .nr
.ne:
	move.l d0,d5
	bsr rnmap
	bcs .nf
	; write the new number
	moveq #0,d0
	movem.l a2-a4,-(sp)
	bsr itoa
	movem.l (sp)+,a2-a4
.nw:
	move.b (a0)+,d0
	beq .nok
	move.b d0,(a3)+
	bra .nw
.nf:
	; no such line: leave it, and say so
	movem.l a1-a4,-(sp)
	PRINTS "Undefined line "
	moveq #0,d0
	move.l d5,d1
	bsr pint
	PRINTS " in "
	moveq #0,d0
	move.l LNUM(a4),d1
	bsr pint
	bsr crlf
	movem.l (sp)+,a1-a4
.nc:
	cmpa.l a2,a1
	bcc .nok
	move.b (a1)+,(a3)+
	bra .nc
.nok:
	andi.b #$fe,ccr
	rts
.nno:
	ori.b #1,ccr
	rts
.end:
	; put it back in the line, which may be longer or shorter now
	move.l a3,d6
	lea D_CRUNCH(a6),a0
	sub.l a0,d6			; the text with its zero
	cmp.l #MAXLINE,d6
	bhi .ll2
	move.l d6,d5
	addq.l #LH+1,d5
	and.b #$fe,d5			; the new size
	moveq #0,d4
	move.w (a4),d4			; the old size
	move.l d5,d1
	sub.l d4,d1			; how much longer
	beq .copy
	bmi .shrink
	move.l D_PRGEND(a6),a1
	add.l d1,a1
	lea 2+1024(a1),a1
	cmpa.l D_MEMTOP(a6),a1
	bcc .om
	movem.l d1/d4-d6/a4,-(sp)
	lea (a4,d4.l),a0		; the rest of the program moves up
	move.l D_PRGEND(a6),a1
	addq.l #2,a1
	move.l d1,d5
	move.l a1,d1
	sub.l a0,d1
	bsr moveup
	movem.l (sp)+,d1/d4-d6/a4
	add.l d1,D_PRGEND(a6)
	bra .copy
.shrink:
	movem.l d1/d4-d6/a4,-(sp)
	lea (a4,d4.l),a1		; the rest of the program moves down
	lea (a4,d5.l),a2
	move.l D_PRGEND(a6),d1
	addq.l #2,d1
	sub.l a1,d1
	bsr movedown
	movem.l (sp)+,d1/d4-d6/a4
	add.l d1,D_PRGEND(a6)
.copy:
	move.w d5,(a4)
	lea LH(a4),a1
	lea D_CRUNCH(a6),a0
	move.l d6,d0
	bsr copyb
	btst #0,d6			; LH + an odd length: there's a padding byte
	beq .np
	clr.b (a1)
.np:
	rts
.om:
	ERROR E_OM
.ll2:
	ERROR E_LL

; ---------------------------------------------------------------- numbers

; the 10 byte float at A0 to A3. keeps all registers
fcopy:
	move.l (a0),(a3)
	move.l 4(a0),4(a3)
	move.w 8(a0),8(a3)
	rts

; FACC after an operation: infinite -> Overflow, not a number -> Illegal function call
fcheck:
	move.b #X,FP_CLASS
	btst #5,FPCOND
	bne .ov
	btst #4,FPCOND
	bne .fc
	rts
.ov:
	ERROR E_OV
.fc:
	ERROR E_FC

; D0:D1 to FPINT (little endian). keeps all registers
wrfpint:
	movem.l d0-d2/a3,-(sp)
	lea FPINT,a3
	moveq #3,d2
.l:
	move.b d1,(a3)+
	lsr.l #8,d1
	dbra d2,.l
	moveq #3,d2
.h:
	move.b d0,(a3)+
	lsr.l #8,d0
	dbra d2,.h
	movem.l (sp)+,d0-d2/a3
	rts

; FPINT -> D0:D1
rdfpint:
	move.l a3,-(sp)
	move.l d2,-(sp)
	lea FPINT+8,a3
	moveq #3,d2
.h:
	lsl.l #8,d0
	move.b -(a3),d0
	dbra d2,.h
	moveq #3,d2
.l:
	lsl.l #8,d1
	move.b -(a3),d1
	dbra d2,.l
	move.l (sp)+,d2
	move.l (sp)+,a3
	rts

; the value at A0 to an integer (floats are rounded), in place -> D0:D1. keeps A0-A2
toint:
	cmp.w #T_INT,(a0)
	bne .f
	movem.l 4(a0),d0-d1
	rts
.f:
	cmp.w #T_FLT,(a0)
	bne .tm
	move.l a3,-(sp)
	lea 4(a0),a0
	lea FPACC,a3
	bsr fcopy
	subq.l #4,a0
	move.b #X+7,FP_FUNC		; round
	move.b #X,FP_ISAVEC
	btst #5,FPCOND
	bne .ov
	bsr rdfpint
	move.w #T_INT,(a0)
	movem.l d0-d1,4(a0)
	move.l (sp)+,a3
	rts
.tm:
	ERROR E_TM
.ov:
	ERROR E_OV

; the value at A0 to a float, in place. keeps A0-A2
toflt:
	cmp.w #T_FLT,(a0)
	beq .r
	cmp.w #T_INT,(a0)
	bne .tm
	movem.l d0-d1/a3,-(sp)
	movem.l 4(a0),d0-d1
	bsr wrfpint
	move.b #X,FP_ILOAD
	move.w #T_FLT,(a0)+
	addq.l #2,a0
	lea FPACC,a3
	exg a0,a3
	bsr fcopy
	exg a0,a3
	subq.l #4,a0
	movem.l (sp)+,d0-d1/a3
.r:
	rts
.tm:
	ERROR E_TM

; compare D0:D1 with D2:D3 (signed) -> D4 = 1 equal, 2 less, 4 greater
cmp64:
	cmp.l d2,d0
	blt .lt
	bgt .gt
	cmp.l d3,d1
	bcs .lt
	bhi .gt
	moveq #1,d4
	rts
.lt:
	moveq #2,d4
	rts
.gt:
	moveq #4,d4
	rts

; D0 = D0 * D1, the low 32 bits. keeps D1-D7
mul32lo:
	movem.l d1-d3,-(sp)
	move.l d0,d2
	mulu d1,d2			; alo*blo
	move.l d0,d3
	swap d3
	mulu d1,d3			; ahi*blo
	swap d1
	mulu d1,d0			; alo*bhi
	add.w d3,d0
	swap d0
	clr.w d0
	add.l d2,d0
	movem.l (sp)+,d1-d3
	rts

; D0:D1 = D0 * D1 (unsigned 32 x 32 -> 64). keeps D2-D7
umul32:
	movem.l d2-d5,-(sp)
	move.l d0,d2
	swap d2				; ahi
	move.l d1,d3
	swap d3				; bhi
	move.w d0,d4
	mulu d1,d4			; P0 = alo*blo
	move.w d2,d5
	mulu d1,d5			; P1 = ahi*blo
	mulu d3,d0			; P2 = alo*bhi
	mulu d2,d3			; P3 = ahi*bhi
	moveq #0,d2
	add.l d5,d0			; mid = P1+P2
	addx.w d2,d2			; its carry
	swap d2				; carry << 16
	swap d0
	move.l d0,d5
	clr.w d5			; mid << 16 (low 32 bits)
	and.l #$ffff,d0
	add.l d2,d0			; mid >> 16
	add.l d5,d4			; lo
	moveq #0,d5
	addx.l d5,d3
	add.l d0,d3			; hi
	move.l d3,d0
	move.l d4,d1
	movem.l (sp)+,d2-d5
	rts

; D0:D1 = D0:D1 * D2:D3 (the low 64 bits)
mul64:
	movem.l d2-d7,-(sp)
	move.l d0,d6			; ahi
	move.l d2,d7			; bhi
	move.l d1,d4			; alo
	move.l d3,d5			; blo
	move.l d4,d0
	move.l d5,d1
	bsr umul32
	move.l d0,d2
	move.l d1,d3
	move.l d6,d0
	move.l d5,d1
	bsr mul32lo
	add.l d0,d2
	move.l d4,d0
	move.l d7,d1
	bsr mul32lo
	add.l d0,d2
	move.l d2,d0
	move.l d3,d1
	movem.l (sp)+,d2-d7
	rts

; D0:D1 / D2:D3 (signed, rounding toward zero) -> D0:D1 quotient, D2:D3 remainder (with
; the sign of the dividend)
divs64:
	movem.l d4-d7,-(sp)
	move.l d2,d4
	or.l d3,d4
	beq .dz
	moveq #0,d6
	tst.l d0
	bpl .p1
	neg.l d1
	negx.l d0
	eori.b #3,d6
.p1:
	tst.l d2
	bpl .p2
	neg.l d3
	negx.l d2
	eori.b #1,d6
.p2:
	moveq #0,d4
	moveq #0,d5
	moveq #63,d7
.l:
	add.l d1,d1
	addx.l d0,d0
	addx.l d5,d5
	addx.l d4,d4
	cmp.l d2,d4
	bhi .sub
	bcs .nx
	cmp.l d3,d5
	bcs .nx
.sub:
	sub.l d3,d5
	subx.l d2,d4
	addq.l #1,d1
.nx:
	dbra d7,.l
	move.l d4,d2
	move.l d5,d3
	btst #0,d6
	beq .q
	neg.l d1
	negx.l d0
.q:
	btst #1,d6
	beq .r
	neg.l d3
	negx.l d2
.r:
	movem.l (sp)+,d4-d7
	rts
.dz:
	ERROR E_DZ

; D0:D1 as signed decimal text -> A0 (zero terminated, in D_NUMBUF). keeps D2-D7
itoa:
	movem.l d2-d5/a1,-(sp)
	lea D_NUMBUF+40(a6),a0
	clr.b (a0)
	moveq #0,d5
	tst.l d0
	bpl .p
	neg.l d1
	negx.l d0
	moveq #1,d5
.p:
	movem.l d0-d1,D_WORK(a6)
.l:
	; divide the 4 words at D_WORK by 10
	lea D_WORK(a6),a1
	moveq #0,d2			; remainder
	moveq #3,d3
.d:
	swap d2
	move.w (a1),d2
	divu #10,d2
	move.w d2,(a1)+
	clr.w d2
	swap d2
	dbra d3,.d
	add.b #'0',d2
	move.b d2,-(a0)
	tst.l D_WORK(a6)
	bne .l
	tst.l D_WORK+4(a6)
	bne .l
	tst.l d5
	beq .r
	move.b #'-',-(a0)
.r:
	movem.l (sp)+,d2-d5/a1
	rts

; VA (a number) as text -> A0 (zero terminated), no spaces added
numtext:
	cmp.w #T_INT,D_VA(a6)
	bne .f
	movem.l D_VA+4(a6),d0-d1
	bra itoa
.f:
	lea D_VA+4(a6),a0
	lea FPACC,a3
	bsr fcopy
	move.b #X+18,FP_TOA		; 18 significant digits
	lea FPASCII,a1
	lea D_NUMBUF(a6),a0
	moveq #31,d0
.c:
	move.b (a1)+,(a0)+
	dbeq d0,.c
	clr.b (a0)
	lea D_NUMBUF(a6),a0
	cmp.b #'-',(a0)			; -0 is 0
	bne .r
	cmp.b #'0',1(a0)
	bne .r
	tst.b 2(a0)
	bne .r
	addq.l #1,a0
.r:
	rts

; is D0.B a hex digit? -> D0 = its value, carry clear if so
hexval:
	cmp.b #'a',d0
	bcs .u
	sub.b #$20,d0
.u:
	sub.b #'0',d0
	bcs .no
	cmp.b #10,d0
	bcs .ok
	subq.b #7,d0
	cmp.b #10,d0
	bcs .no
	cmp.b #16,d0
	bcc .no
.ok:
	andi.b #$fe,ccr
	rts
.no:
	ori.b #1,ccr
	rts

; hex digits at A0 -> D0:D1, D2 = how many. Overflow if more than 16
hexnum:
	moveq #0,d0
	moveq #0,d1
	moveq #0,d2
.l:
	move.b (a0),d3
	exg d0,d3
	bsr hexval
	exg d0,d3
	bcs .e
	addq.l #1,a0
	addq.w #1,d2
	cmp.w #16,d2
	bhi .ov
	moveq #3,d4
.s:
	add.l d1,d1
	addx.l d0,d0
	dbra d4,.s
	or.b d3,d1
	bra .l
.e:
	rts
.ov:
	ERROR E_OV

; a number at A0 -> VA, A0 after it. N set (D0 = -1) if there isn't one. Forms: 123 (an
; integer), 1.5 or 1E10 (a float), &HFF or 0FFh (hex, 64 bits)
parsenum:
	cmp.b #'&',(a0)
	bne .h
	move.b 1(a0),d0
	cmp.b #'H',d0
	beq .amp
	cmp.b #'h',d0
	bne .fail
.amp:
	addq.l #2,a0
	bsr hexnum
	tst.w d2
	beq .fail
	bra .int
.h:
	; hex with an h at the end? (it has to start with a digit)
	move.l a0,a1
.hl:
	move.b (a1),d0
	bsr hexval
	bcs .he
	addq.l #1,a1
	bra .hl
.he:
	cmpa.l a0,a1
	beq .dec
	move.b (a1),d0
	cmp.b #'H',d0
	beq .hx
	cmp.b #'h',d0
	bne .dec
.hx:
	bsr hexnum
	addq.l #1,a0			; the h
	bra .int
.dec:
	move.l a0,a2			; start
	moveq #0,d2			; digits
	moveq #0,d3			; float?
.d1:
	move.b (a0),d0
	bsr isdigit
	bcs .pt
	addq.l #1,a0
	addq.w #1,d2
	bra .d1
.pt:
	cmp.b #'.',d0
	bne .ex
	moveq #1,d3
	addq.l #1,a0
.d2:
	move.b (a0),d0
	bsr isdigit
	bcs .ex
	addq.l #1,a0
	addq.w #1,d2
	bra .d2
.ex:
	tst.w d2
	beq .fail
	move.b (a0),d0
	cmp.b #'E',d0
	beq .e1
	cmp.b #'e',d0
	bne .chk
.e1:
	lea 1(a0),a1
	move.b (a1),d0
	cmp.b #'+',d0
	beq .e2
	cmp.b #'-',d0
	bne .e3
.e2:
	addq.l #1,a1
.e3:
	move.b (a1),d0
	bsr isdigit
	bcs .chk			; not an exponent after all
	moveq #1,d3
	move.l a1,a0
.e4:
	move.b (a0),d0
	bsr isdigit
	bcs .chk
	addq.l #1,a0
	bra .e4
.chk:
	tst.w d3
	bne .flt
	cmp.w #19,d2
	bhi .flt
	; an integer of up to 19 digits (too big for 64 bits signed: a float)
	move.l a2,a1
	moveq #0,d0
	moveq #0,d1
.il:
	cmpa.l a0,a1
	bcc .ichk
	moveq #0,d2
	move.b (a1)+,d2
	sub.b #'0',d2
	add.l d1,d1			; *10
	addx.l d0,d0
	move.l d0,d4
	move.l d1,d5
	add.l d1,d1
	addx.l d0,d0
	add.l d1,d1
	addx.l d0,d0
	add.l d5,d1
	addx.l d4,d0
	add.l d2,d1
	moveq #0,d2
	addx.l d2,d0
	bra .il
.ichk:
	tst.l d0
	bmi .flt
.int:
	move.w #T_INT,D_VA(a6)
	movem.l d0-d1,D_VA+4(a6)
	moveq #0,d0
	rts
.flt:
	; the driver reads it
	move.l a0,d0
	sub.l a2,d0
	cmp.l #31,d0
	bhi .fail
	lea FPASCII,a1
	subq.w #1,d0
.fc:
	move.b (a2)+,(a1)+
	dbra d0,.fc
	clr.b (a1)
	move.b #X,FP_FROMA
	btst #6,FPCOND
	bne .fail
	bsr fcheck
	move.l a0,-(sp)
	lea FPACC,a0
	lea D_VA+4(a6),a3
	bsr fcopy
	move.l (sp)+,a0
	move.w #T_FLT,D_VA(a6)
	moveq #0,d0
	rts
.fail:
	moveq #-1,d0
	rts

; text at A0, length D0, to a number in VA. D0 = 0 if it was all a number (spaces around
; it are fine), 1 if a number had other text after it, -1 if there was no number (VA = 0)
strnum:
	cmp.l #63,d0
	bls .c
	moveq #63,d0
.c:
	lea D_SCRATCH(a6),a1
	bra .ce
.cl:
	move.b (a0)+,(a1)+
.ce:
	dbra d0,.cl
	clr.b (a1)
	lea D_SCRATCH(a6),a0
	bsr peeka0
	moveq #0,d7			; negative
	cmp.b #'-',d0
	bne .pl
	moveq #1,d7
	bra .sg
.pl:
	cmp.b #'+',d0
	bne .n
.sg:
	addq.l #1,a0
.n:
	move.b (a0),d0
	cmp.b #'.',d0
	beq .p
	cmp.b #'&',d0
	beq .p
	bsr isdigit
	bcs .none
.p:
	move.l d7,-(sp)
	bsr parsenum
	move.l (sp)+,d7
	tst.l d0
	bmi .none
	tst.l d7
	beq .e
	move.l a0,-(sp)
	bsr negva
	move.l (sp)+,a0
.e:
	bsr peeka0
	tst.b d0
	sne d0
	ext.w d0
	ext.l d0
	neg.l d0
	rts
.none:
	move.w #T_INT,D_VA(a6)
	clr.l D_VA+4(a6)
	clr.l D_VA+8(a6)
	moveq #-1,d0
	rts

; ---------------------------------------------------------------- strings

; room for D0 bytes of temporary string -> A0. keeps D0
talloc:
	move.l D_TMPPTR(a6),a0
	move.l d0,d1
	addq.l #1,d1
	and.b #$fe,d1
	suba.l d1,a0
	cmpa.l D_STRTOP(a6),a0
	bcs .om
	move.l a0,D_TMPPTR(a6)
	rts
.om:
	ERROR E_OM

; copy D0 bytes from A0 to A1
copyb:
	tst.l d0
	beq .r
.l:
	move.b (a0)+,(a1)+
	subq.l #1,d0
	bne .l
.r:
	rts

; VA = a new temporary string of D0 bytes -> A0 = where to put them. keeps D0
mkstr:
	cmp.l #65535,d0
	bhi .ls
	bsr talloc
	move.w #T_STR,D_VA(a6)
	move.l a0,D_VA+4(a6)
	move.l d0,D_VA+8(a6)
	rts
.ls:
	ERROR E_LS

; VA = VB + VA (strings)
concat:
	move.l D_VB+8(a6),d0
	add.l D_VA+8(a6),d0
	cmp.l #65535,d0
	bhi .ls
	bsr talloc
	move.l a0,a1
	move.l a0,-(sp)
	move.l d0,-(sp)
	move.l D_VB+4(a6),a0
	move.l D_VB+8(a6),d0
	bsr copyb
	move.l D_VA+4(a6),a0
	move.l D_VA+8(a6),d0
	bsr copyb
	move.l (sp)+,D_VA+8(a6)
	move.l (sp)+,D_VA+4(a6)
	move.w #T_STR,D_VA(a6)
	rts
.ls:
	ERROR E_LS

; compare the strings VB and VA -> D4 = 1 equal, 2 less, 4 greater
strcmp:
	move.l D_VB+4(a6),a0
	move.l D_VB+8(a6),d0
	move.l D_VA+4(a6),a1
	move.l D_VA+8(a6),d1
	move.l d0,d2
	cmp.l d1,d2
	bls .m
	move.l d1,d2
.m:
	tst.l d2
	beq .len
.l:
	cmpm.b (a1)+,(a0)+
	bcs .lt
	bhi .gt
	subq.l #1,d2
	bne .l
.len:
	cmp.l d1,d0
	bcs .lt
	bhi .gt
	moveq #1,d4
	rts
.lt:
	moveq #2,d4
	rts
.gt:
	moveq #4,d4
	rts

; size of a heap block holding D0 characters -> D1
	macro BLKSIZE
	move.l d0,d1
	addq.l #1,d1
	and.b #$fe,d1
	addq.l #8,d1
	endm

; store the string VA in the descriptor at A1 (a string variable)
strassign:
	move.l D_VA+8(a6),d0
	beq .empty
	BLKSIZE
	move.l D_STRTOP(a6),a0
	lea (a0,d1.l),a2
	cmpa.l D_TMPPTR(a6),a2
	bls .ok
	movem.l d0-d1/a1,-(sp)
	lea D_VA+4(a6),a0
	move.l a0,D_GCROOT(a6)		; the source can move too
	bsr gc
	movem.l (sp)+,d0-d1/a1
	move.l D_STRTOP(a6),a0
	lea (a0,d1.l),a2
	cmpa.l D_TMPPTR(a6),a2
	bhi .om
.ok:
	move.l a2,D_STRTOP(a6)
	move.l a1,(a0)+			; owner
	move.l d0,(a0)+			; length
	move.l a0,a3			; the characters
	movem.l d0/a1/a3,-(sp)
	move.l a0,a1
	move.l D_VA+4(a6),a0
	bsr copyb
	movem.l (sp)+,d0/a1/a3
	bsr freestr
	move.l a3,(a1)
	move.l d0,4(a1)
	rts
.empty:
	bsr freestr
	clr.l (a1)
	clr.l 4(a1)
	rts
.om:
	ERROR E_OM

; the descriptor at A1 lets go of its heap block. keeps D0/A1/A3
freestr:
	move.l (a1),d2
	beq .r
	move.l d2,a2
	subq.l #8,a2
	cmpa.l (a2),a1
	bne .r
	clr.l (a2)
	move.l d0,-(sp)
	move.l 4(a2),d0
	BLKSIZE
	add.l d1,D_GARBAGE(a6)
	move.l (sp)+,d0
.r:
	rts

; garbage collection: slide the live strings in the heap down over the dead ones. A live
; block's owner still points at it. D_GCROOT, if set, is one more string pointer to update
gc:
	movem.l d0-d7/a0-a4,-(sp)
	move.l D_STRBOT(a6),a0		; from
	move.l a0,a1			; to
	move.l D_STRTOP(a6),a2
.l:
	cmpa.l a2,a0
	bcc .done
	move.l 4(a0),d0
	BLKSIZE
	move.l (a0),d2			; owner
	beq .dead
	move.l d2,a3
	lea 8(a0),a4
	cmpa.l (a3),a4
	bne .dead
	lea 8(a1),a4
	move.l a4,(a3)			; the owner points at the new place
	move.l D_GCROOT(a6),d2
	beq .mv
	move.l d2,a3
	move.l (a3),d3			; root pointer
	lea 8(a0),a4
	cmp.l a4,d3
	bcs .mv
	add.l d0,a4
	cmp.l a4,d3
	bhi .mv
	add.l a1,d3
	sub.l a0,d3
	move.l d3,(a3)
.mv:
	cmpa.l a0,a1
	beq .same
	move.l d1,d3
	lsr.l #1,d3
	subq.l #1,d3
.c:
	move.w (a0)+,(a1)+
	subq.l #1,d3
	bpl .c
	bra .l
.same:
	adda.l d1,a0
	adda.l d1,a1
	bra .l
.dead:
	adda.l d1,a0
	bra .l
.done:
	move.l a1,D_STRTOP(a6)
	clr.l D_GARBAGE(a6)
	clr.l D_GCROOT(a6)
	movem.l (sp)+,d0-d7/a0-a4
	rts

; ---------------------------------------------------------------- evaluation helpers

evalnum:
	bsr eval
	cmp.w #T_STR,D_VA(a6)
	beq .tm
	rts
.tm:
	ERROR E_TM

evalstr:
	bsr eval
	cmp.w #T_STR,D_VA(a6)
	bne .tm
	rts
.tm:
	ERROR E_TM

; -> D0:D1
evalint:
	bsr evalnum
	lea D_VA(a6),a0
	bra toint

; a 24 bit address -> D1
evaladdr:
	bsr evalint
	tst.l d0
	bne .fc
	cmp.l #$1000000,d1
	bcc .fc
	rts
.fc:
	ERROR E_FC

; 0-255 -> D1
evalbyte:
	bsr evalint
	tst.l d0
	bne .fc
	cmp.l #256,d1
	bcc .fc
	rts
.fc:
	ERROR E_FC

; a condition -> D0 = 0 if false
evaltruth:
	bsr evalnum
	cmp.w #T_INT,D_VA(a6)
	bne .f
	move.l D_VA+4(a6),d0
	or.l D_VA+8(a6),d0
	rts
.f:
	lea D_VA+4(a6),a0
	lea FPACC,a3
	bsr fcopy
	move.b #X,FP_CLASS
	moveq #1,d0
	and.b FPCOND,d0
	eor.b #1,d0
	rts

; ( number ) -> VA
pnum:
	EXPECT '('
	bsr evalnum
	EXPECT ')'
	rts

; ( string ) -> VA
pstrarg:
	EXPECT '('
	bsr evalstr
	EXPECT ')'
	rts

; VA = the integer D0:D1
setint:
	move.w #T_INT,D_VA(a6)
	movem.l d0-d1,D_VA+4(a6)
	rts

; ---------------------------------------------------------------- numeric functions

; ( number ) as a float in FACC
pflt:
	bsr pnum
	lea D_VA(a6),a0
	bsr toflt
	lea D_VA+4(a6),a0
	lea FPACC,a3
	bra fcopy

; FACC -> VA, after checking it
fresult:
	bsr fcheck
	lea FPACC,a0
	lea D_VA+4(a6),a3
	bsr fcopy
	move.w #T_FLT,D_VA(a6)
	rts

; FPCOND after FP_CLASS: zero or negative -> Illegal function call (for logs)
	macro POSITIVE
	move.b #X,FP_CLASS
	moveq #3,d0
	and.b FPCOND,d0
	bne fcerr
	endm

fcerr:
	ERROR E_FC

fn_sgn:
	bsr pnum
	cmp.w #T_INT,D_VA(a6)
	bne .f
	movem.l D_VA+4(a6),d0-d1
	tst.l d0
	bmi .neg
	or.l d0,d1
	beq .set
	moveq #1,d1
	bra .set
.f:
	lea D_VA+4(a6),a0
	lea FPACC,a3
	bsr fcopy
	move.b #X,FP_CLASS
	moveq #0,d1
	btst #0,FPCOND
	bne .set
	moveq #1,d1
	btst #1,FPCOND
	beq .set
.neg:
	moveq #-1,d1
.set:
	move.l d1,d0
	smi d0
	ext.w d0
	ext.l d0
	bra setint

; INT(number or string): the largest integer not above it. A string that isn't a number is 0
fn_int:
	moveq #X+4,d6			; floor
fn_round:
	EXPECT '('
	bsr eval
	EXPECT ')'
	cmp.w #T_STR,D_VA(a6)
	bne .n
	move.l D_VA+4(a6),a0
	move.l D_VA+8(a6),d0
	move.w d6,-(sp)
	bsr strnum
	move.w (sp)+,d6
	tst.l d0
	beq .n
	moveq #0,d0
	moveq #0,d1
	bra setint
.n:
	cmp.w #T_INT,D_VA(a6)
	beq .r
	lea D_VA+4(a6),a0
	lea FPACC,a3
	bsr fcopy
	move.b d6,FP_FUNC
	move.b #X,FP_ISAVEC
	btst #5,FPCOND
	bne .ov
	bsr rdfpint
	bra setint
.r:
	rts
.ov:
	ERROR E_OV

fn_fix:
	moveq #X+6,d6			; toward zero
	bra fn_round
fn_cint:
	moveq #X+7,d6			; nearest
	bra fn_round

fn_abs:
	bsr pnum
	cmp.w #T_INT,D_VA(a6)
	bne .f
	tst.l D_VA+4(a6)
	bmi negva
	rts
.f:
	and.b #$7f,D_VA+13(a6)
	rts

fn_sqr:
	bsr pflt
	move.b #X,FP_CLASS
	btst #1,FPCOND
	bne fcerr
	move.b #X+1,FP_FUNC
	bra fresult

fn_log:
	bsr pflt
	POSITIVE
	move.b #X,FP_LN
	bra fresult

fn_log10:
	bsr pflt
	POSITIVE
	move.b #X+0,FP_FUNC
	bra fresult

fn_exp:
	bsr pflt
	move.b #X,FP_EXP
	bra fresult

fn_sin:
	bsr pflt
	move.b #X,FP_SIN
	bra fresult
fn_cos:
	bsr pflt
	move.b #X,FP_COS
	bra fresult
fn_tan:
	bsr pflt
	move.b #X,FP_TAN
	bra fresult
fn_atn:
	bsr pflt
	move.b #X,FP_ATN
	bra fresult
fn_asn:
	bsr pflt
	move.b #X+8,FP_FUNC
	bra fresult
fn_acs:
	bsr pflt
	move.b #X+9,FP_FUNC
	bra fresult

fn_pi:
	move.b #X+16,FP_INIT
	bra fresult

; RND or RND(x): a random number from 0 up to (not including) 1
fn_rnd:
	bsr peek
	cmp.b #'(',d0
	bne .g
	bsr pnum
.g:
	moveq #7,d2
.b:
	move.b d0,IO_RANDBYTE		; makes a new random byte
	lsl.l #8,d1
	move.b IO_RANDBYTE,d1
	exg d0,d1
	dbra d2,.b			; (D0 and D1 swap each time: 8 bytes in all)
	and.l #$3fffffff,d0		; 62 bits
	bsr wrfpint
	move.b #X,FP_ILOAD
	move.l #$40000000,d0		; 2^62
	moveq #0,d1
	bsr wrfpint
	move.b #XA,FP_ILOAD
	move.b #X,FP_DIV
	bra fresult

; ROOT(x, n): the nth root of x (an odd root of a negative number is negative)
fn_root:
	EXPECT '('
	bsr evalnum
	lea D_VA(a6),a0
	bsr toflt
	PUSHVA
	EXPECT ','
	bsr evalnum
	EXPECT ')'
	POPVB				; VB = x, VA = n
	lea D_VA(a6),a0
	bsr toflt
	; VC = 1/n
	lea D_VA+4(a6),a0
	lea FPARG,a3
	bsr fcopy
	move.b #XA,FP_CLASS
	btst #0,FPCOND
	bne fcerr			; n = 0
	move.b #X+1,FP_INIT
	move.b #X,FP_DIV
	lea FPACC,a0
	lea D_VC+4(a6),a3
	bsr fcopy
	moveq #0,d7			; negate the result?
	lea D_VB+4(a6),a0
	lea FPACC,a3
	bsr fcopy
	move.b #X,FP_CLASS
	btst #1,FPCOND
	beq .pos
	; x < 0: n has to be an odd integer. FACC = n, FARG = n rounded
	lea D_VA+4(a6),a0
	lea FPACC,a3
	bsr fcopy
	move.b #X+7,FP_FUNC
	lea FPACC,a0
	lea FPARG,a3
	bsr fcopy
	lea D_VA+4(a6),a0
	lea FPACC,a3
	bsr fcopy
	move.b #X,FP_CMP
	btst #0,FPCOND
	beq fcerr			; not an integer
	lea D_VA(a6),a0
	bsr toint
	btst #0,d1
	beq fcerr			; even
	lea D_VB+4(a6),a0
	lea FPACC,a3
	bsr fcopy
	move.b #X+2,FP_FUNC		; |x|
	moveq #1,d7
.pos:
	lea D_VC+4(a6),a0
	lea FPARG,a3
	bsr fcopy
	move.b #X,FP_POW
	tst.l d7
	beq fresult
	move.b #X+3,FP_FUNC		; negate
	bra fresult

fn_peek:
	EXPECT '('
	bsr evaladdr
	EXPECT ')'
	move.l d1,a0
	moveq #0,d1
	move.b (a0),d1
	moveq #0,d0
	bra setint

fn_fre:
	bsr pnum0
	bsr fre
	bra setint

; ( anything ), ignored
pnum0:
	EXPECT '('
	bsr eval
	EXPECT ')'
	rts

fn_pos:
	bsr pnum0
	moveq #0,d1
	move.b IO_CON_CURSORH,d1	; 0 = the first column, like LOCATE
	moveq #0,d0
	bra setint

fn_lomem:
	move.l a6,d1
	moveq #0,d0
	bra setint
fn_himem:
	move.l D_HIMEM(a6),d1
	moveq #0,d0
	bra setint

; ---------------------------------------------------------------- CALL

; CALL address [, D0 [, D1 ...]]    (a statement)
; CALL(address [, D0 ...])          (a function: the value of D0 when it returns)
docall:
	moveq #0,d5
	bra callcore
fn_call:
	EXPECT '('
	moveq #1,d5
callcore:
	lea -44(sp),sp			; D0-D7, the address, the count, the form
	move.l sp,a0
	moveq #9,d0
.z:
	clr.l (a0)+
	dbra d0,.z
	move.w d5,40(sp)
	bsr evaladdr
	move.l d1,32(sp)
.l:
	bsr peek
	cmp.b #',',d0
	bne .e
	addq.l #1,a5
	bsr evalint
	move.l 36(sp),d0
	cmp.l #8,d0
	bcc fcerr
	lsl.l #2,d0
	move.l d1,(sp,d0.w)
	addq.l #1,36(sp)
	bra .l
.e:
	tst.w 40(sp)
	beq .go
	EXPECT ')'
.go:
	move.l 32(sp),a0
	movem.l (sp),d0-d7
	movem.l a5-a6,-(sp)
	jsr (a0)
	movem.l (sp)+,a5-a6
	lea 44(sp),sp
	move.l d0,d1
	smi d0
	ext.w d0
	ext.l d0
	bra setint

; ---------------------------------------------------------------- string functions

fn_len:
	bsr pstrarg
	move.l D_VA+8(a6),d1
	moveq #0,d0
	bra setint

fn_asc:
	bsr pstrarg
	tst.l D_VA+8(a6)
	beq fcerr
	move.l D_VA+4(a6),a0
	moveq #0,d1
	move.b (a0),d1
	moveq #0,d0
	bra setint

; VAL(string): the number at the start of it (0 if none)
fn_val:
	bsr pstrarg
	move.l D_VA+4(a6),a0
	move.l D_VA+8(a6),d0
	bra strnum

fn_chr:
	bsr pnum
	lea D_VA(a6),a0
	bsr toint
	tst.l d0
	bne fcerr
	cmp.l #256,d1
	bcc fcerr
	move.l d1,d2
	moveq #1,d0
	bsr mkstr
	move.b d2,(a0)
	rts

fn_str:
	bsr pnum
	bsr numtext
	moveq #0,d2			; add a space?
	cmp.b #'-',(a0)
	beq .l
	moveq #1,d2
.l:
	move.l a0,a2
	moveq #0,d0
.n:
	tst.b (a2)+
	beq .m
	addq.l #1,d0
	bra .n
.m:
	add.l d2,d0
	move.l a0,a2
	bsr mkstr
	tst.l d2
	beq .c
	move.b #' ',(a0)+
.c:
	move.b (a2)+,(a0)+
	bne .c
	rts

; ( string , n ) -> VA = the string, D1 = n (0-65535)
strn:
	EXPECT '('
	bsr evalstr
	PUSHVA
	EXPECT ','
	bsr evalint
	tst.l d0
	bne fcerr
	cmp.l #65536,d1
	bcc fcerr
	move.l d1,-(sp)
	EXPECT ')'
	move.l (sp)+,d5
	POPVB
	movem.l D_VB(a6),d0-d3
	movem.l d0-d3,D_VA(a6)
	move.l d5,d1
	rts

fn_left:
	bsr strn
	cmp.l D_VA+8(a6),d1
	bcc .r
	move.l d1,D_VA+8(a6)
.r:
	rts

fn_right:
	bsr strn
	move.l D_VA+8(a6),d0
	cmp.l d0,d1
	bcc .r
	sub.l d1,d0
	add.l d0,D_VA+4(a6)
	move.l d1,D_VA+8(a6)
.r:
	rts

; MID$(string, start [, length])
fn_mid:
	EXPECT '('
	bsr evalstr
	PUSHVA
	EXPECT ','
	bsr evalint
	tst.l d0
	bne fcerr
	tst.l d1
	beq fcerr
	cmp.l #65536,d1
	bcc fcerr
	move.l d1,-(sp)
	move.l #65535,d1		; the length if none is given
	bsr peek
	cmp.b #',',d0
	bne .nl
	addq.l #1,a5
	bsr evalint
	tst.l d0
	bne fcerr
	cmp.l #65536,d1
	bcc fcerr
.nl:
	move.l d1,-(sp)
	EXPECT ')'
	move.l (sp)+,d5			; length
	move.l (sp)+,d6			; start
	POPVB
	movem.l D_VB(a6),d1-d4
	movem.l d1-d4,D_VA(a6)
	move.l d5,d2
	move.l d6,d1
	move.l D_VA+8(a6),d0
	subq.l #1,d1
	cmp.l d0,d1
	bcs .in
	clr.l D_VA+8(a6)		; past the end
	rts
.in:
	add.l d1,D_VA+4(a6)
	sub.l d1,d0			; what's left
	cmp.l d0,d2
	bcc .all
	move.l d2,d0
.all:
	move.l d0,D_VA+8(a6)
	rts

; D0:D1 as hex digits (at least D2 of them) -> A0 text, D0 length
hextext:
	lea D_NUMBUF+40(a6),a0
	clr.b (a0)
	moveq #0,d3
.l:
	move.l d1,d4
	and.w #15,d4
	move.b .dig(pc,d4.w),-(a0)
	addq.w #1,d3
	moveq #3,d4
.s:
	lsr.l #1,d0
	roxr.l #1,d1
	dbra d4,.s
	cmp.w d2,d3
	bcs .l
	move.l d0,d4
	or.l d1,d4
	bne .l
	moveq #0,d0
	move.w d3,d0
	rts
.dig:
	dc.b "0123456789ABCDEF"

; VA = a temporary copy of D0 bytes at A0
copystr:
	move.l a0,a2
	bsr mkstr
	move.l a0,a1
	move.l a2,a0
	bra copyb

; HEX$(n): hex digits without leading zeros. A negative number is shown as its 64 bit
; two's complement (HEX$(-1) = "FFFFFFFFFFFFFFFF")
fn_hex:
	bsr pnum
	lea D_VA(a6),a0
	bsr toint
	moveq #1,d2
	bsr hextext
	bra copystr

; DEC(hex string): its value. A $, 0x or &H in front or an h after are allowed. Anything
; else that isn't hex gives 0
fn_dec:
	bsr pstrarg
	move.l D_VA+4(a6),a0
	move.l D_VA+8(a6),d0
	cmp.l #63,d0
	bls .c
	moveq #63,d0
.c:
	lea D_SCRATCH(a6),a1
	bra .ce
.cl:
	move.b (a0)+,(a1)+
.ce:
	dbra d0,.cl
	clr.b (a1)
	lea D_SCRATCH(a6),a0
	bsr peeka0
	cmp.b #'$',d0
	beq .p1
	cmp.b #'&',d0
	beq .amp
	cmp.b #'0',d0
	bne .num
	move.b 1(a0),d0
	cmp.b #'x',d0
	beq .p2
	cmp.b #'X',d0
	beq .p2
	bra .num
.amp:
	move.b 1(a0),d0
	cmp.b #'H',d0
	beq .p2
	cmp.b #'h',d0
	bne .zero
.p2:
	addq.l #1,a0
.p1:
	addq.l #1,a0
.num:
	bsr hexnum
	tst.w d2
	beq .zero
	move.b (a0),d2
	cmp.b #'h',d2
	beq .h
	cmp.b #'H',d2
	bne .e
.h:
	addq.l #1,a0
.e:
	movem.l d0-d1,-(sp)
	bsr peeka0
	movem.l (sp)+,d0-d1
	tst.b (a0)
	bne .zero
	bra setint
.zero:
	moveq #0,d0
	moveq #0,d1
	bra setint

; INSTR([start,] string, find): where find is in string (1 = the first character), or 0
fn_instr:
	EXPECT '('
	moveq #1,d1
	move.l d1,-(sp)			; start
	bsr eval
	cmp.w #T_STR,D_VA(a6)
	beq .s
	lea D_VA(a6),a0
	bsr toint
	tst.l d0
	bne fcerr
	tst.l d1
	beq fcerr
	move.l d1,(sp)
	EXPECT ','
	bsr evalstr
.s:
	PUSHVA
	EXPECT ','
	bsr evalstr
	EXPECT ')'
	POPVB
	move.l (sp)+,d5			; start
	move.l D_VB+4(a6),a0		; string
	move.l D_VB+8(a6),d0
	move.l D_VA+4(a6),a1		; find
	move.l D_VA+8(a6),d1
	move.l d0,d2
	sub.l d1,d2			; last place it could start (0 based)
	bcs .no
	move.l d5,d3
	subq.l #1,d3			; place (0 based)
.l:
	cmp.l d2,d3
	bhi .no
	lea (a0,d3.l),a2
	move.l a1,a3
	move.l d1,d4
	beq .yes
.c:
	cmpm.b (a3)+,(a2)+
	bne .n
	subq.l #1,d4
	bne .c
.yes:
	move.l d3,d1
	addq.l #1,d1
	moveq #0,d0
	bra setint
.n:
	addq.l #1,d3
	bra .l
.no:
	moveq #0,d0
	moveq #0,d1
	bra setint

; STRING$(n, character code or string)
fn_string:
	EXPECT '('
	bsr evalint
	tst.l d0
	bne fcerr
	cmp.l #65536,d1
	bcc fcerr
	move.l d1,-(sp)
	EXPECT ','
	bsr eval
	EXPECT ')'
	cmp.w #T_STR,D_VA(a6)
	bne .n
	tst.l D_VA+8(a6)
	beq fcerr
	move.l D_VA+4(a6),a0
	moveq #0,d2
	move.b (a0),d2
	bra .m
.n:
	lea D_VA(a6),a0
	bsr toint
	tst.l d0
	bne fcerr
	cmp.l #256,d1
	bcc fcerr
	move.l d1,d2
.m:
	move.l (sp)+,d0
fillstr:
	bsr mkstr
	tst.l d0
	beq .r
.f:
	move.b d2,(a0)+
	subq.l #1,d0
	bne .f
.r:
	rts

fn_space:
	bsr pnum
	lea D_VA(a6),a0
	bsr toint
	tst.l d0
	bne fcerr
	cmp.l #65536,d1
	bcc fcerr
	move.l d1,d0
	moveq #' ',d2
	bra fillstr

fn_ucase:
	moveq #0,d5
	bra casestr
fn_lcase:
	moveq #1,d5
casestr:
	bsr pstrarg
	move.l D_VA+4(a6),a0
	move.l D_VA+8(a6),d0
	move.l a0,a2
	bsr mkstr
	tst.l d0
	beq .r
.l:
	move.b (a2)+,d1
	tst.b d5
	bne .lo
	cmp.b #'a',d1
	bcs .s
	cmp.b #'z'+1,d1
	bcc .s
	sub.b #$20,d1
	bra .s
.lo:
	cmp.b #'A',d1
	bcs .s
	cmp.b #'Z'+1,d1
	bcc .s
	add.b #$20,d1
.s:
	move.b d1,(a0)+
	subq.l #1,d0
	bne .l
.r:
	rts

; INKEY$: the key waiting, or "" if there's none
fn_inkey:
	moveq #0,d0
	tst.b IO_KEYQ_SIZE
	beq mkstr
	move.b IO_KEYQ_WAITING,d2
	move.b d0,IO_KEYQ_DEQUEUE
	moveq #1,d0
	bsr mkstr
	move.b d2,(a0)
	rts

	dc.b "END OF BASIC"
	even
