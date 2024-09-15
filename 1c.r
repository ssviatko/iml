
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
    46                          	!zone getline
    47                          getline
    48  0019 08                 	php
    49  001a c210               	rep #$10
    50  001c e220               	sep #$20
    51                          	!as
    52                          	!rl
    53  001e a20000             	ldx #$0000
    54                          .local2
    55  0021 af00fc1b           	lda IO_KEYQ_SIZE
    56  0025 f0fa               	beq .local2
    57  0027 af01fc1b           	lda IO_KEYQ_WAITING
    58  002b 8f02fc1b           	sta IO_KEYQ_DEQUEUE
    59  002f c90d               	cmp #$0d			;carriage return yet?
    60  0031 f01c               	beq .local3
    61  0033 c908               	cmp #$08			;backspace/back arrow?
    62  0035 f029               	beq .local4
    63  0037 c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
    64  0039 90e6               	bcc .local2		 		;yes, so ignore it
    65  003b 9f000417           	sta inbuff,x 		;any other character, so register it and store it
    66  003f 8f12fc1b           	sta IO_CON_CHAROUT
    67  0043 8f13fc1b           	sta IO_CON_REGISTER
    68  0047 e8                 	inx
    69  0048 a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
    70  004a e0fe03             	cpx #$3fe			;overrun end of buffer yet?
    71  004d d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
    72                          .local3
    73  004f 9f000417           	sta inbuff,x		;store CR
    74  0053 8f17fc1b           	sta IO_CON_CR
    75  0057 e8                 	inx
    76  0058 a900               	lda #$00			;store zero to end it all
    77  005a 9f000417           	sta inbuff,x
    78  005e 28                 	plp
    79  005f 6b                 	rtl
    80                          .local4
    81  0060 e00000             	cpx #$0000
    82  0063 f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
    83  0065 a908               	lda #$08
    84  0067 8f12fc1b           	sta IO_CON_CHAROUT
    85  006b 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
    86  006f a920               	lda #$20
    87  0071 8f12fc1b           	sta IO_CON_CHAROUT
    88  0075 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
    89  0079 a908               	lda #$08
    90  007b 8f12fc1b           	sta IO_CON_CHAROUT
    91  007f 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
    92  0083 ca                 	dex
    93  0084 809b               	bra .local2
    94                          	
    95                          	!zone prinbuff
    96                          prinbuff
    97  0086 08                 	php
    98  0087 c210               	rep #$10
    99  0089 e220               	sep #$20
   100                          	!as
   101                          	!rl
   102  008b a20000             	ldx #$0000
   103                          .local2
   104  008e bf000417           	lda inbuff,x
   105  0092 f00b               	beq .local3
   106  0094 8f12fc1b           	sta IO_CON_CHAROUT
   107  0098 8f13fc1b           	sta IO_CON_REGISTER
   108  009c e8                 	inx
   109  009d 80ef               	bra .local2
   110                          .local3
   111  009f 28                 	plp
   112  00a0 6b                 	rtl
   113                          
   114  00a1 0000000000000000...	!align $ffff, $ffff,$00	;fill up to top of memory
   115                          
