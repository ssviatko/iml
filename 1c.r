
; ******** Source: 1c.a
     1                          	!to "1c.o",plain
     2                          	!cpu 65816
     3                          
     4                          	*= $0000
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
    26                          l_prcdpla = $1c0000 + prcdpla
    27                          l_ucline = $1c0000 + ucline
    28                          
    29                          rangehigh = $33
    30                          monrange = $35
    31                          monlast = $36
    32                          parseptr = $37
    33                          parseptr_m = $38
    34                          parseptr_h = $39
    35                          mondump = $3a
    36                          mondump_m = $3b
    37                          mondump_h = $3c
    38                          dpla = $3d
    39                          dpla_m = $3e
    40                          dpla_h = $3f
    41                          
    42                          inbuff = $170400
    43                          
    44                          x1crominit
    45  0000 4b                 	phk
    46  0001 ab                 	plb
    47  0002 c210               	rep #$10
    48                          	!rl
    49  0004 e220               	sep #$20
    50                          	!as
    51  0006 a23303             	ldx #initstring
    52  0009 863d               	stx dpla
    53  000b a91c               	lda #$1c
    54  000d 853f               	sta dpla_h
    55  000f 221a031c           	jsl l_prcdpla
    56  0013 4c2001             	jmp+2 monstart
    57                          
    58                          parse_setup
    59  0016 a20004             	ldx #$0400
    60  0019 8637               	stx parseptr
    61  001b a917               	lda #$17
    62  001d 8539               	sta parseptr_h
    63  001f 60                 	rts
    64                          	
    65                          	!zone parse_getchar
    66                          parse_getchar			;get char from inbuff, assumes 8 bit A, 16 bit X
    67  0020 a737               	lda [parseptr]
    68  0022 48                 	pha
    69  0023 e637               	inc parseptr
    70  0025 d006               	bne .local2
    71  0027 e638               	inc parseptr_m
    72  0029 d002               	bne .local2
    73  002b e639               	inc parseptr_h
    74                          .local2
    75  002d 68                 	pla
    76  002e 60                 	rts
    77                          	
    78                          	!zone parse_addr
    79                          parse_addr				;see if user specified an address on line.
    80  002f a900               	lda #$00
    81  0031 48                 	pha
    82  0032 48                 	pha					;make space for working value on the stack
    83  0033 8535               	sta monrange		;clear range flag
    84  0035 208e00             	jsr+2 parse_getnib	;get first nibble
    85  0038 9051               	bcc .no				;didn't even get one hex character, so return false
    86  003a 8301               	sta 1,s				;save it on the stack for now
    87  003c 208e00             	jsr+2 parse_getnib	;get second nibble
    88  003f 9047               	bcc .yes			;if not hex then bail
    89  0041 48                 	pha
    90  0042 a302               	lda 2,s
    91  0044 0a                 	asl
    92  0045 0a                 	asl
    93  0046 0a                 	asl
    94  0047 0a                 	asl
    95  0048 0301               	ora 1,s
    96  004a 8302               	sta 2,s
    97  004c 68                 	pla					;add to stack
    98  004d 208e00             	jsr+2 parse_getnib	;get possible third nibble
    99  0050 9036               	bcc .yes
   100  0052 c230               	rep #$30			;we're dealing with a 16 bit value now
   101                          	!al
   102  0054 290f00             	and #$000f
   103  0057 48                 	pha
   104  0058 a303               	lda 3,s
   105  005a 0a                 	asl
   106  005b 0a                 	asl
   107  005c 0a                 	asl
   108  005d 0a                 	asl
   109  005e 0301               	ora 1,s
   110  0060 8303               	sta 3,s
   111  0062 68                 	pla
   112  0063 e220               	sep #$20
   113                          	!as
   114  0065 208e00             	jsr+2 parse_getnib
   115  0068 901e               	bcc .yes
   116  006a c230               	rep #$30
   117                          	!al
   118  006c 290f00             	and #$000f
   119  006f 48                 	pha
   120  0070 a303               	lda 3,s
   121  0072 0a                 	asl
   122  0073 0a                 	asl
   123  0074 0a                 	asl
   124  0075 0a                 	asl
   125  0076 0301               	ora 1,s
   126  0078 8303               	sta 3,s
   127  007a 68                 	pla
   128  007b e220               	sep #$20			;fall thru to yes on 4th nibble
   129                          	!as
   130  007d 202000             	jsr parse_getchar	;check to see if next char is a . so we can specify ranges
   131  0080 c92e               	cmp #'.'
   132  0082 d004               	bne .yes
   133  0084 a980               	lda #$80
   134  0086 8535               	sta monrange
   135                          .yes
   136  0088 7a                 	ply					;get 16 bit work address off of stack
   137  0089 38                 	sec					;got address, return
   138  008a 60                 	rts
   139                          .no
   140  008b 7a                 	ply					;clear stack
   141  008c 18                 	clc					;no address found, return
   142  008d 60                 	rts
   143                          parse_getnib
   144  008e 202000             	jsr parse_getchar
   145  0091 c920               	cmp #' '
   146  0093 f0f9               	beq parse_getnib	;throw away spaces.
   147  0095 c92e               	cmp #'.'
   148  0097 d006               	bne .notrange
   149  0099 a980               	lda #$80
   150  009b 8535               	sta monrange		;this is the start of a range specification
   151  009d 18                 	clc
   152  009e 60                 	rts
   153                          .notrange
   154  009f c941               	cmp #$41
   155  00a1 900b               	bcc .outrnga
   156  00a3 c947               	cmp #$47
   157  00a5 b007               	bcs .outrnga
   158  00a7 38                 	sec
   159  00a8 e907               	sbc #$07			;in range of A-F
   160                          .success
   161  00aa 290f               	and #$0f
   162  00ac 38                 	sec
   163  00ad 60                 	rts
   164                          .outrnga				;test if 0-9
   165  00ae c930               	cmp #$30
   166  00b0 9004               	bcc .outrng
   167  00b2 c93a               	cmp #$3a
   168  00b4 90f4               	bcc .success		;less than 3a, but >= 30, else fall thru to outrng
   169                          .outrng
   170  00b6 18                 	clc
   171  00b7 60                 	rts
   172                          	
   173                          prdumpaddr
   174  00b8 a53c               	lda mondump_h			;print long address
   175  00ba 205902             	jsr+2 prhex
   176  00bd a92f               	lda #'/'
   177  00bf 8f12fc1b           	sta IO_CON_CHAROUT
   178  00c3 8f13fc1b           	sta IO_CON_REGISTER
   179  00c7 a63a               	ldx mondump
   180  00c9 204f02             	jsr+2 prhex16
   181  00cc a92d               	lda #'-'
   182  00ce 8f12fc1b           	sta IO_CON_CHAROUT
   183  00d2 8f13fc1b           	sta IO_CON_REGISTER
   184  00d6 a920               	lda #' '
   185  00d8 8f12fc1b           	sta IO_CON_CHAROUT
   186  00dc 8f13fc1b           	sta IO_CON_REGISTER
   187  00e0 60                 	rts
   188                          	
   189                          adjdumpaddr					;add 8 to dump address
   190  00e1 c230               	rep #$30
   191                          	!al
   192  00e3 a53a               	lda mondump
   193  00e5 18                 	clc
   194  00e6 690800             	adc #$0008
   195  00e9 853a               	sta mondump
   196  00eb e220               	sep #$20
   197                          	!as
   198  00ed 08                 	php						;save carry state.. did we carry to the bank?
   199  00ee a53c               	lda mondump_h
   200  00f0 6900               	adc #$00
   201  00f2 853c               	sta mondump_h
   202  00f4 28                 	plp
   203  00f5 60                 	rts
   204                          	
   205                          bankcmd
   206  00f6 202f00             	jsr parse_addr
   207  00f9 9006               	bcc monerror
   208  00fb 98                 	tya
   209  00fc 853c               	sta mondump_h
   210  00fe 4c3301             	jmp moncmd
   211                          monerror
   212  0101 a21101             	ldx #monsynerr
   213  0104 863d               	stx dpla
   214  0106 a91c               	lda #$1c
   215  0108 853f               	sta dpla_h
   216  010a 221a031c           	jsl l_prcdpla
   217  010e 4c3301             	jmp moncmd
   218                          monsynerr
   219  0111 53796e7461782065...	!tx "Syntax error!"
   220  011e 0d00               	!byte $0d, $00
   221                          
   222                          monstart				;main entry point for system monitor
   223  0120 4b                 	phk
   224  0121 ab                 	plb
   225  0122 c210               	rep #$10
   226                          	!rl
   227  0124 e220               	sep #$20
   228                          	!as
   229  0126 a20000             	ldx #$0000
   230  0129 863a               	stx mondump
   231  012b a91c               	lda #$1c
   232  012d 853c               	sta mondump_h
   233  012f a944               	lda #'D'
   234  0131 8536               	sta monlast
   235                          	
   236                          	!zone moncmd
   237                          moncmd
   238  0133 a93e               	lda #promptchar
   239  0135 8f12fc1b           	sta IO_CON_CHAROUT
   240  0139 8f13fc1b           	sta IO_CON_REGISTER
   241  013d 2298021c           	jsl l_getline
   242  0141 2276021c           	jsl l_ucline
   243  0145 201600             	jsr parse_setup
   244  0148 202000             	jsr parse_getchar
   245                          .local3
   246  014b c951               	cmp #'Q'
   247  014d f01e               	beq haltcmd
   248  014f c944               	cmp #'D'
   249  0151 d003               	bne .local4
   250  0153 4cf401             	jmp+2 dumpcmd
   251                          .local4
   252  0156 c90d               	cmp #$0d
   253  0158 d008               	bne .local2
   254  015a a536               	lda monlast			;recall previously executed command
   255  015c c920               	cmp #$20			;make sure it isn't a control character
   256  015e b0eb               	bcs .local3			;and retry it
   257  0160 80d1               	bra moncmd			;else recycle and try a new command
   258                          .local2
   259  0162 c941               	cmp #'A'
   260  0164 f02d               	beq asciidumpcmd
   261  0166 c942               	cmp #'B'
   262  0168 f08c               	beq bankcmd
   263  016a 4c3301             	jmp moncmd
   264                          	
   265                          haltcmd
   266  016d a27b01             	ldx #haltmsg
   267  0170 863d               	stx dpla
   268  0172 a91c               	lda #$1c
   269  0174 853f               	sta dpla_h
   270  0176 221a031c           	jsl l_prcdpla
   271  017a db                 	stp
   272                          haltmsg
   273  017b 48616c74696e6720...	!tx "Halting 65816 engine.."
   274  0191 0d00               	!byte $0d,$00
   275                          	
   276                          	!zone asciidumpcmd
   277                          asciidumpcmd
   278  0193 8536               	sta monlast
   279  0195 202f00             	jsr parse_addr
   280  0198 9021               	bcc .local3
   281  019a 843a               	sty mondump
   282  019c 8433               	sty rangehigh
   283  019e 2435               	bit monrange			;user asking for a range?
   284  01a0 1019               	bpl .local3
   285  01a2 202f00             	jsr parse_addr			;get the remaining half of the range
   286  01a5 8433               	sty rangehigh
   287  01a7 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   288  01a9 8535               	sta monrange
   289  01ab a433               	ldy rangehigh
   290  01ad d003               	bne .local6
   291  01af 4c0101             	jmp+2 monerror			;top of range can't be zero
   292                          .local6
   293  01b2 a43a               	ldy mondump
   294  01b4 c433               	cpy rangehigh
   295  01b6 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   296  01b8 4c0101             	jmp+2 monerror
   297                          .local3
   298  01bb 20b800             	jsr prdumpaddr
   299  01be a00000             	ldy #$0000
   300                          .local2
   301  01c1 b73a               	lda [mondump],y
   302  01c3 c920               	cmp #$20
   303  01c5 b002               	bcs .local4
   304  01c7 a92e               	lda #'.'				;substitute control character with a period
   305                          .local4
   306  01c9 8f12fc1b           	sta IO_CON_CHAROUT
   307  01cd 8f13fc1b           	sta IO_CON_REGISTER
   308  01d1 c8                 	iny
   309  01d2 c01000             	cpy #$0010
   310  01d5 d0ea               	bne .local2
   311  01d7 8f17fc1b           	sta IO_CON_CR
   312  01db 20e100             	jsr adjdumpaddr
   313  01de b00f               	bcs .local5				;carry to bank, exit even if we're processing a range
   314  01e0 20e100             	jsr adjdumpaddr
   315  01e3 b00a               	bcs .local5				;carry to bank, exit even if we're processing a range
   316  01e5 2435               	bit monrange			;ranges on?
   317  01e7 1006               	bpl .local5
   318  01e9 a433               	ldy rangehigh
   319  01eb c43a               	cpy mondump
   320  01ed b0cc               	bcs .local3
   321                          .local5
   322  01ef 6435               	stz monrange
   323  01f1 4c3301             	jmp moncmd
   324                          	
   325                          	!zone dumpcmd
   326                          dumpcmd
   327  01f4 8536               	sta monlast
   328  01f6 202f00             	jsr parse_addr
   329  01f9 9021               	bcc .local3
   330  01fb 843a               	sty mondump				;if address was specified, store 16 bit y at low 16 bits of mondump address
   331  01fd 8433               	sty rangehigh
   332  01ff 2435               	bit monrange			;user asking for a range?
   333  0201 1019               	bpl .local3
   334  0203 202f00             	jsr parse_addr			;get the remaining half of the range
   335  0206 8433               	sty rangehigh
   336  0208 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   337  020a 8535               	sta monrange
   338  020c a433               	ldy rangehigh
   339  020e d003               	bne .local6
   340  0210 4c0101             	jmp+2 monerror			;top of range can't be zero
   341                          .local6
   342  0213 a43a               	ldy mondump
   343  0215 c433               	cpy rangehigh
   344  0217 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   345  0219 4c0101             	jmp+2 monerror
   346                          .local3
   347  021c 20b800             	jsr prdumpaddr
   348  021f a00000             	ldy #$0000
   349                          .local2
   350  0222 b73a               	lda [mondump],y
   351  0224 205902             	jsr+2 prhex
   352  0227 a920               	lda #' '
   353  0229 8f12fc1b           	sta IO_CON_CHAROUT
   354  022d 8f13fc1b           	sta IO_CON_REGISTER
   355  0231 c8                 	iny
   356  0232 c00800             	cpy #$0008
   357  0235 d0eb               	bne .local2
   358  0237 8f17fc1b           	sta IO_CON_CR
   359  023b 20e100             	jsr adjdumpaddr
   360  023e b00a               	bcs .local5				;carry to bank, exit even if we're processing a range
   361  0240 2435               	bit monrange			;ranges on?
   362  0242 1006               	bpl .local5
   363  0244 a433               	ldy rangehigh
   364  0246 c43a               	cpy mondump
   365  0248 b0d2               	bcs .local3
   366                          .local5
   367  024a 6435               	stz monrange
   368  024c 4c3301             	jmp moncmd
   369                          	
   370                          prhex16
   371  024f c230               	rep #$30
   372  0251 8a                 	txa
   373  0252 e220               	sep #$20
   374  0254 eb                 	xba
   375  0255 205902             	jsr+2 prhex
   376  0258 eb                 	xba
   377                          prhex
   378  0259 48                 	pha
   379  025a 4a                 	lsr
   380  025b 4a                 	lsr
   381  025c 4a                 	lsr
   382  025d 4a                 	lsr
   383  025e 206402             	jsr+2 prhexnib
   384  0261 68                 	pla
   385  0262 290f               	and #$0f
   386                          prhexnib
   387  0264 0930               	ora #$30
   388  0266 c93a               	cmp #$3a
   389  0268 9003               	bcc prhexnofix
   390  026a 18                 	clc
   391  026b 6907               	adc #$07
   392                          prhexnofix
   393  026d 8f12fc1b           	sta IO_CON_CHAROUT
   394  0271 8f13fc1b           	sta IO_CON_REGISTER
   395  0275 60                 	rts
   396                          
   397                          	!zone ucline
   398                          ucline					;convert inbuff at $170400 to upper case
   399  0276 08                 	php
   400  0277 c210               	rep #$10
   401  0279 e220               	sep #$20
   402                          	!as
   403                          	!rl
   404  027b a20000             	ldx #$0000
   405                          .local2
   406  027e bf000417           	lda inbuff,x
   407  0282 f012               	beq .local4			;hit the zero, so bail
   408  0284 c961               	cmp #'a'
   409  0286 900b               	bcc .local3			;less then lowercase a, so ignore
   410  0288 c97b               	cmp #'z' + 1		;less than next character after lowercase z?
   411  028a b007               	bcs .local3			;greater than or equal, so ignore
   412  028c 38                 	sec
   413  028d e920               	sbc #('z' - 'Z')	;make upper case
   414  028f 9f000417           	sta inbuff,x
   415                          .local3
   416  0293 e8                 	inx
   417  0294 80e8               	bra .local2
   418                          .local4
   419  0296 28                 	plp
   420  0297 6b                 	rtl
   421                          	
   422                          	!zone getline
   423                          getline
   424  0298 08                 	php
   425  0299 c210               	rep #$10
   426  029b e220               	sep #$20
   427                          	!as
   428                          	!rl
   429  029d a20000             	ldx #$0000
   430                          .local2
   431  02a0 af00fc1b           	lda IO_KEYQ_SIZE
   432  02a4 f0fa               	beq .local2
   433  02a6 af01fc1b           	lda IO_KEYQ_WAITING
   434  02aa 8f02fc1b           	sta IO_KEYQ_DEQUEUE
   435  02ae c90d               	cmp #$0d			;carriage return yet?
   436  02b0 f01c               	beq .local3
   437  02b2 c908               	cmp #$08			;backspace/back arrow?
   438  02b4 f029               	beq .local4
   439  02b6 c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
   440  02b8 90e6               	bcc .local2		 		;yes, so ignore it
   441  02ba 9f000417           	sta inbuff,x 		;any other character, so register it and store it
   442  02be 8f12fc1b           	sta IO_CON_CHAROUT
   443  02c2 8f13fc1b           	sta IO_CON_REGISTER
   444  02c6 e8                 	inx
   445  02c7 a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
   446  02c9 e0fe03             	cpx #$3fe			;overrun end of buffer yet?
   447  02cc d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
   448                          .local3
   449  02ce 9f000417           	sta inbuff,x		;store CR
   450  02d2 8f17fc1b           	sta IO_CON_CR
   451  02d6 e8                 	inx
   452  02d7 a900               	lda #$00			;store zero to end it all
   453  02d9 9f000417           	sta inbuff,x
   454  02dd 28                 	plp
   455  02de 6b                 	rtl
   456                          .local4
   457  02df e00000             	cpx #$0000
   458  02e2 f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
   459  02e4 a908               	lda #$08
   460  02e6 8f12fc1b           	sta IO_CON_CHAROUT
   461  02ea 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
   462  02ee a920               	lda #$20
   463  02f0 8f12fc1b           	sta IO_CON_CHAROUT
   464  02f4 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
   465  02f8 a908               	lda #$08
   466  02fa 8f12fc1b           	sta IO_CON_CHAROUT
   467  02fe 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
   468  0302 ca                 	dex
   469  0303 809b               	bra .local2
   470                          	
   471                          prinbuff				;feed location of input buffer into dpla and then print
   472  0305 08                 	php
   473  0306 c210               	rep #$10
   474  0308 e220               	sep #$20
   475                          	!as
   476                          	!rl
   477  030a a917               	lda #$17
   478  030c 853f               	sta dpla_h
   479  030e a904               	lda #$04
   480  0310 853e               	sta dpla_m
   481  0312 643d               	stz dpla
   482  0314 221a031c           	jsl l_prcdpla
   483  0318 28                 	plp
   484  0319 6b                 	rtl
   485                          	
   486                          	!zone prcdpla
   487                          prcdpla					; print C string pointed to by dp locations $3d-$3f
   488  031a 08                 	php
   489  031b c210               	rep #$10
   490  031d e220               	sep #$20
   491                          	!as
   492                          	!rl
   493  031f a00000             	ldy #$0000
   494                          .local2
   495  0322 b73d               	lda [dpla],y
   496  0324 f00b               	beq .local3
   497  0326 8f12fc1b           	sta IO_CON_CHAROUT
   498  032a 8f13fc1b           	sta IO_CON_REGISTER
   499  032e c8                 	iny
   500  032f 80f1               	bra .local2
   501                          .local3
   502  0331 28                 	plp
   503  0332 6b                 	rtl
   504                          
   505                          initstring
   506  0333 494d4c2036353831...	!tx "IML 65816 1C Firmware v00"
   507  034c 0d                 	!byte 0x0d
   508  034d 53797374656d204d...	!tx "System Monitor"
   509  035b 0d                 	!byte 0x0d
   510  035c 0d                 	!byte 0x0d
   511  035d 00                 	!byte 0
   512                          
   513  035e 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
   514                          
