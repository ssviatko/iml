
; ******** Source: 1c.a
     1                          	!to "1c.o",plain
     2                          	!cpu 65816
     3                          
     4                          	*= $1c0000
     5                          
     6                          IO_KEYQ_SIZE = $1bfc00
     7                          IO_KEYQ_WAITING = $1bfc01
     8                          IO_KEYQ_DEQUEUE = $1bfc02
     9                          IO_KEYQ_CLEAR = $1bfc03
    10                          
    11                          IO_CON_CLS = $1bfc10
    12                          IO_CON_COLOR = $1bfc11
    13                          IO_CON_CHAROUT = $1bfc12
    14                          IO_CON_REGISTER = $1bfc13
    15                          IO_CON_CURSORH = $1bfc14;
    16                          IO_CON_CURSORV = $1bfc15;
    17                          IO_CON_CURSOR = $1bfc16;
    18                          IO_CON_CR = $1bfc17
    19                          
    20                          IO_VIDMODE = $1bfc20
    21                          
    22                          promptchar = '>'
    23                          
    24                          l_getline = $1c0000 + getline
    25                          l_prinbuff = $1c0000 + prinbuff
    26                          
    27                          inbuff = $170400
    28                          
    29                          x1crominit
    30  0000 4b                 	phk
    31  0001 ab                 	plb
    32  0002 c230               	rep #$30
    33                          	!al
    34                          	!rl
    35                          	
    36                          monstart
    37  0004 e220               	sep #$20
    38                          	!as
    39  0006 a93e               	lda #promptchar
    40  0008 8f12fc1b           	sta IO_CON_CHAROUT
    41  000c 8f13fc1b           	sta IO_CON_REGISTER
    42  0010 2219001c           	jsl l_getline
    43  0014 2286001c           	jsl l_prinbuff
    44  0018 db                 	stp
    45                          	
    46                          getline
    47  0019 08                 	php
    48  001a c210               	rep #$10
    49  001c e220               	sep #$20
    50                          	!as
    51                          	!rl
    52  001e a20000             	ldx #$0000
    53                          getline2
    54  0021 af00fc1b           	lda IO_KEYQ_SIZE
    55  0025 f0fa               	beq getline2
    56  0027 af01fc1b           	lda IO_KEYQ_WAITING
    57  002b 8f02fc1b           	sta IO_KEYQ_DEQUEUE
    58  002f c90d               	cmp #$0d			;carriage return yet?
    59  0031 f01c               	beq getline3
    60  0033 c908               	cmp #$08			;backspace/back arrow?
    61  0035 f029               	beq getline4
    62  0037 c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
    63  0039 90e6               	bcc getline2 		;yes, so ignore it
    64  003b 9f000417           	sta inbuff,x 		;any other character, so register it and store it
    65  003f 8f12fc1b           	sta IO_CON_CHAROUT
    66  0043 8f13fc1b           	sta IO_CON_REGISTER
    67  0047 e8                 	inx
    68  0048 a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
    69  004a e0fe03             	cpx #$3fe			;overrun end of buffer yet?
    70  004d d0d2               	bne getline2		;no, so get another char.. otherwise fall thru
    71                          getline3
    72  004f 9f000417           	sta inbuff,x		;store CR
    73  0053 8f17fc1b           	sta IO_CON_CR
    74  0057 e8                 	inx
    75  0058 a900               	lda #$00			;store zero to end it all
    76  005a 9f000417           	sta inbuff,x
    77  005e 28                 	plp
    78  005f 6b                 	rtl
    79                          getline4
    80  0060 e00000             	cpx #$0000
    81  0063 f0bc               	beq getline2		;no data in buffer yet, so nothing to backspace over
    82  0065 a908               	lda #$08
    83  0067 8f12fc1b           	sta IO_CON_CHAROUT
    84  006b 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
    85  006f a920               	lda #$20
    86  0071 8f12fc1b           	sta IO_CON_CHAROUT
    87  0075 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
    88  0079 a908               	lda #$08
    89  007b 8f12fc1b           	sta IO_CON_CHAROUT
    90  007f 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
    91  0083 ca                 	dex
    92  0084 809b               	bra getline2
    93                          	
    94                          prinbuff
    95  0086 08                 	php
    96  0087 c210               	rep #$10
    97  0089 e220               	sep #$20
    98                          	!as
    99                          	!rl
   100  008b a20000             	ldx #$0000
   101                          prinbuff2
   102  008e bf000417           	lda inbuff,x
   103  0092 f00b               	beq prinbuff3
   104  0094 8f12fc1b           	sta IO_CON_CHAROUT
   105  0098 8f13fc1b           	sta IO_CON_REGISTER
   106  009c e8                 	inx
   107  009d 80ef               	bra prinbuff2
   108                          prinbuff3
   109  009f 28                 	plp
   110  00a0 6b                 	rtl
   111                          
   112  00a1 0000000000000000...	!align $ffff, $ffff,$00	;fill up to top of memory
   113                          
