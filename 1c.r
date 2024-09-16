
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
    51  0006 a21904             	ldx #initstring
    52  0009 863d               	stx dpla
    53  000b a91c               	lda #$1c
    54  000d 853f               	sta dpla_h
    55  000f 2200041c           	jsl l_prcdpla
    56  0013 4c5601             	jmp+2 monstart
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
   175  00ba 203f03             	jsr+2 prhex
   176  00bd a92f               	lda #'/'
   177  00bf 8f12fc1b           	sta IO_CON_CHAROUT
   178  00c3 8f13fc1b           	sta IO_CON_REGISTER
   179  00c7 a63a               	ldx mondump
   180  00c9 203503             	jsr+2 prhex16
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
   210  00fe 4c6901             	jmp moncmd
   211                          monerror
   212  0101 a21101             	ldx #monsynerr
   213  0104 863d               	stx dpla
   214  0106 a91c               	lda #$1c
   215  0108 853f               	sta dpla_h
   216  010a 2200041c           	jsl l_prcdpla
   217  010e 4c6901             	jmp moncmd
   218                          monsynerr
   219  0111 53796e7461782065...	!tx "Syntax error!"
   220  011e 0d00               	!byte $0d, $00
   221                          
   222                          colorcmd
   223  0120 202f00             	jsr parse_addr
   224  0123 90dc               	bcc monerror
   225  0125 98                 	tya
   226  0126 8f11fc1b           	sta IO_CON_COLOR
   227  012a 4c6901             	jmp moncmd
   228                          	
   229                          modecmd
   230  012d 202f00             	jsr parse_addr
   231  0130 90cf               	bcc monerror
   232  0132 98                 	tya
   233  0133 c908               	cmp #$08
   234  0135 90ca               	bcc monerror
   235  0137 c90a               	cmp #$0a
   236  0139 b0c6               	bcs monerror
   237  013b 8f20fc1b           	sta IO_VIDMODE
   238  013f a900               	lda #$00
   239  0141 8f14fc1b           	sta IO_CON_CURSORH
   240  0145 8f15fc1b           	sta IO_CON_CURSORV
   241  0149 a920               	lda #$20
   242  014b 8f12fc1b           	sta IO_CON_CHAROUT
   243  014f 8f10fc1b           	sta IO_CON_CLS
   244  0153 4c6901             	jmp moncmd
   245                          	
   246                          monstart				;main entry point for system monitor
   247  0156 4b                 	phk
   248  0157 ab                 	plb
   249  0158 c210               	rep #$10
   250                          	!rl
   251  015a e220               	sep #$20
   252                          	!as
   253  015c a20000             	ldx #$0000
   254  015f 863a               	stx mondump
   255  0161 a91c               	lda #$1c
   256  0163 853c               	sta mondump_h
   257  0165 a944               	lda #'D'
   258  0167 8536               	sta monlast
   259                          	
   260                          	!zone moncmd
   261                          moncmd
   262  0169 a93e               	lda #promptchar
   263  016b 8f12fc1b           	sta IO_CON_CHAROUT
   264  016f 8f13fc1b           	sta IO_CON_REGISTER
   265  0173 227e031c           	jsl l_getline
   266  0177 225c031c           	jsl l_ucline
   267  017b 201600             	jsr parse_setup
   268  017e 202000             	jsr parse_getchar
   269                          .local3
   270  0181 c951               	cmp #'Q'
   271  0183 f043               	beq haltcmd
   272  0185 c944               	cmp #'D'
   273  0187 d003               	bne .local4
   274  0189 4c8402             	jmp+2 dumpcmd
   275                          .local4
   276  018c c90d               	cmp #$0d
   277  018e d008               	bne .local2
   278  0190 a536               	lda monlast			;recall previously executed command
   279  0192 c920               	cmp #$20			;make sure it isn't a control character
   280  0194 b0eb               	bcs .local3			;and retry it
   281  0196 80d1               	bra moncmd			;else recycle and try a new command
   282                          .local2
   283  0198 c941               	cmp #'A'
   284  019a f052               	beq asciidumpcmd
   285  019c c942               	cmp #'B'
   286  019e d003               	bne .local5
   287  01a0 4cf600             	jmp+2 bankcmd
   288                          .local5
   289  01a3 c943               	cmp #'C'
   290  01a5 d003               	bne .local6
   291  01a7 4c2001             	jmp+2 colorcmd
   292                          .local6
   293  01aa c94d               	cmp #'M'
   294  01ac d003               	bne .local7
   295  01ae 4c2d01             	jmp+2 modecmd
   296                          .local7
   297  01b1 c93f               	cmp #'?'
   298  01b3 f003               	beq helpcmd
   299  01b5 4c6901             	jmp moncmd
   300                          	
   301                          helpcmd
   302  01b8 a24404             	ldx #helpmsg
   303  01bb 863d               	stx dpla
   304  01bd a91c               	lda #$1c
   305  01bf 853f               	sta dpla_h
   306  01c1 2200041c           	jsl l_prcdpla
   307  01c5 4c6901             	jmp moncmd
   308                          	
   309                          haltcmd
   310  01c8 a2d601             	ldx #haltmsg
   311  01cb 863d               	stx dpla
   312  01cd a91c               	lda #$1c
   313  01cf 853f               	sta dpla_h
   314  01d1 2200041c           	jsl l_prcdpla
   315  01d5 db                 	stp
   316                          haltmsg
   317  01d6 48616c74696e6720...	!tx "Halting 65816 engine.."
   318  01ec 0d00               	!byte $0d,$00
   319                          	
   320                          	!zone asciidumpcmd
   321                          asciidumpcmd
   322  01ee 8536               	sta monlast
   323  01f0 202f00             	jsr parse_addr
   324  01f3 9021               	bcc .local3
   325  01f5 843a               	sty mondump
   326  01f7 8433               	sty rangehigh
   327  01f9 2435               	bit monrange			;user asking for a range?
   328  01fb 1019               	bpl .local3
   329  01fd 202f00             	jsr parse_addr			;get the remaining half of the range
   330  0200 8433               	sty rangehigh
   331  0202 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   332  0204 8535               	sta monrange
   333  0206 a433               	ldy rangehigh
   334  0208 d003               	bne .local6
   335  020a 4c0101             	jmp+2 monerror			;top of range can't be zero
   336                          .local6
   337  020d a43a               	ldy mondump
   338  020f c433               	cpy rangehigh
   339  0211 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   340  0213 4c0101             	jmp+2 monerror
   341                          .local3
   342  0216 20b800             	jsr prdumpaddr
   343  0219 a00000             	ldy #$0000
   344                          .local2
   345  021c b73a               	lda [mondump],y
   346  021e c920               	cmp #$20
   347  0220 b002               	bcs .local4
   348  0222 a92e               	lda #'.'				;substitute control character with a period
   349                          .local4
   350  0224 8f12fc1b           	sta IO_CON_CHAROUT
   351  0228 8f13fc1b           	sta IO_CON_REGISTER
   352  022c c8                 	iny
   353  022d af20fc1b           	lda IO_VIDMODE
   354  0231 c909               	cmp #$09
   355  0233 d007               	bne .lores1
   356  0235 c04000             	cpy #$0040
   357  0238 d0e2               	bne .local2
   358  023a 8005               	bra .lores2
   359                          .lores1
   360  023c c01000             	cpy #$0010
   361  023f d0db               	bne .local2
   362                          .lores2
   363  0241 8f17fc1b           	sta IO_CON_CR
   364  0245 20e100             	jsr adjdumpaddr
   365  0248 b035               	bcs .local5				;carry to bank, exit even if we're processing a range
   366  024a 20e100             	jsr adjdumpaddr
   367  024d b030               	bcs .local5	
   368  024f af20fc1b           	lda IO_VIDMODE
   369  0253 c909               	cmp #$09
   370  0255 d01e               	bne .lores3
   371  0257 20e100             	jsr adjdumpaddr
   372  025a b023               	bcs .local5	
   373  025c 20e100             	jsr adjdumpaddr
   374  025f b01e               	bcs .local5	
   375  0261 20e100             	jsr adjdumpaddr
   376  0264 b019               	bcs .local5	
   377  0266 20e100             	jsr adjdumpaddr
   378  0269 b014               	bcs .local5	
   379  026b 20e100             	jsr adjdumpaddr
   380  026e b00f               	bcs .local5	
   381  0270 20e100             	jsr adjdumpaddr
   382  0273 b00a               	bcs .local5	
   383                          .lores3
   384  0275 2435               	bit monrange			;ranges on?
   385  0277 1006               	bpl .local5
   386  0279 a433               	ldy rangehigh
   387  027b c43a               	cpy mondump
   388  027d b097               	bcs .local3
   389                          .local5
   390  027f 6435               	stz monrange
   391  0281 4c6901             	jmp moncmd
   392                          	
   393                          	!zone dumpcmd
   394                          dumpcmd
   395  0284 8536               	sta monlast
   396  0286 202f00             	jsr parse_addr
   397  0289 9021               	bcc .local3
   398  028b 843a               	sty mondump				;if address was specified, store 16 bit y at low 16 bits of mondump address
   399  028d 8433               	sty rangehigh
   400  028f 2435               	bit monrange			;user asking for a range?
   401  0291 1019               	bpl .local3
   402  0293 202f00             	jsr parse_addr			;get the remaining half of the range
   403  0296 8433               	sty rangehigh
   404  0298 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   405  029a 8535               	sta monrange
   406  029c a433               	ldy rangehigh
   407  029e d003               	bne .local6
   408  02a0 4c0101             	jmp+2 monerror			;top of range can't be zero
   409                          .local6
   410  02a3 a43a               	ldy mondump
   411  02a5 c433               	cpy rangehigh
   412  02a7 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   413  02a9 4c0101             	jmp+2 monerror
   414                          .local3
   415  02ac 20b800             	jsr prdumpaddr
   416  02af a00000             	ldy #$0000
   417                          .local2
   418  02b2 b73a               	lda [mondump],y
   419  02b4 203f03             	jsr+2 prhex
   420  02b7 a920               	lda #' '
   421  02b9 8f12fc1b           	sta IO_CON_CHAROUT
   422  02bd 8f13fc1b           	sta IO_CON_REGISTER
   423  02c1 c8                 	iny
   424  02c2 af20fc1b           	lda IO_VIDMODE
   425  02c6 c909               	cmp #$09
   426  02c8 d03e               	bne .lores1
   427  02ca c01000             	cpy #$0010
   428  02cd d0e3               	bne .local2
   429  02cf a920               	lda #' '
   430  02d1 8f12fc1b           	sta IO_CON_CHAROUT
   431  02d5 8f13fc1b           	sta IO_CON_REGISTER
   432  02d9 a92d               	lda #'-'
   433  02db 8f12fc1b           	sta IO_CON_CHAROUT
   434  02df 8f13fc1b           	sta IO_CON_REGISTER
   435  02e3 a920               	lda #' '
   436  02e5 8f12fc1b           	sta IO_CON_CHAROUT
   437  02e9 8f13fc1b           	sta IO_CON_REGISTER
   438  02ed a00000             	ldy #$0000				;print 16 bytes as ASCII... bonus when in mode 9!
   439                          .asc2
   440  02f0 b73a               	lda [mondump],y
   441  02f2 c920               	cmp #$20
   442  02f4 b002               	bcs .asc4
   443  02f6 a92e               	lda #'.'				;substitute control character with a period
   444                          .asc4
   445  02f8 8f12fc1b           	sta IO_CON_CHAROUT
   446  02fc 8f13fc1b           	sta IO_CON_REGISTER
   447  0300 c8                 	iny
   448  0301 c01000             	cpy #$0010
   449  0304 d0ea               	bne .asc2
   450  0306 8005               	bra .lores2
   451                          .lores1
   452  0308 c00800             	cpy #$0008
   453  030b d0a5               	bne .local2
   454                          .lores2
   455  030d 8f17fc1b           	sta IO_CON_CR
   456  0311 20e100             	jsr adjdumpaddr
   457  0314 b01a               	bcs .local5				;carry to bank, exit even if we're processing a range
   458  0316 af20fc1b           	lda IO_VIDMODE
   459  031a c909               	cmp #$09
   460  031c d005               	bne .lores3
   461  031e 20e100             	jsr adjdumpaddr
   462  0321 b00d               	bcs .local5
   463                          .lores3
   464  0323 2435               	bit monrange			;ranges on?
   465  0325 1009               	bpl .local5
   466  0327 a433               	ldy rangehigh
   467  0329 c43a               	cpy mondump
   468  032b 9003               	bcc .local5
   469  032d 4cac02             	jmp+2 .local3
   470                          .local5
   471  0330 6435               	stz monrange
   472  0332 4c6901             	jmp moncmd
   473                          	
   474                          prhex16
   475  0335 c230               	rep #$30
   476  0337 8a                 	txa
   477  0338 e220               	sep #$20
   478  033a eb                 	xba
   479  033b 203f03             	jsr+2 prhex
   480  033e eb                 	xba
   481                          prhex
   482  033f 48                 	pha
   483  0340 4a                 	lsr
   484  0341 4a                 	lsr
   485  0342 4a                 	lsr
   486  0343 4a                 	lsr
   487  0344 204a03             	jsr+2 prhexnib
   488  0347 68                 	pla
   489  0348 290f               	and #$0f
   490                          prhexnib
   491  034a 0930               	ora #$30
   492  034c c93a               	cmp #$3a
   493  034e 9003               	bcc prhexnofix
   494  0350 18                 	clc
   495  0351 6907               	adc #$07
   496                          prhexnofix
   497  0353 8f12fc1b           	sta IO_CON_CHAROUT
   498  0357 8f13fc1b           	sta IO_CON_REGISTER
   499  035b 60                 	rts
   500                          
   501                          	!zone ucline
   502                          ucline					;convert inbuff at $170400 to upper case
   503  035c 08                 	php
   504  035d c210               	rep #$10
   505  035f e220               	sep #$20
   506                          	!as
   507                          	!rl
   508  0361 a20000             	ldx #$0000
   509                          .local2
   510  0364 bf000417           	lda inbuff,x
   511  0368 f012               	beq .local4			;hit the zero, so bail
   512  036a c961               	cmp #'a'
   513  036c 900b               	bcc .local3			;less then lowercase a, so ignore
   514  036e c97b               	cmp #'z' + 1		;less than next character after lowercase z?
   515  0370 b007               	bcs .local3			;greater than or equal, so ignore
   516  0372 38                 	sec
   517  0373 e920               	sbc #('z' - 'Z')	;make upper case
   518  0375 9f000417           	sta inbuff,x
   519                          .local3
   520  0379 e8                 	inx
   521  037a 80e8               	bra .local2
   522                          .local4
   523  037c 28                 	plp
   524  037d 6b                 	rtl
   525                          	
   526                          	!zone getline
   527                          getline
   528  037e 08                 	php
   529  037f c210               	rep #$10
   530  0381 e220               	sep #$20
   531                          	!as
   532                          	!rl
   533  0383 a20000             	ldx #$0000
   534                          .local2
   535  0386 af00fc1b           	lda IO_KEYQ_SIZE
   536  038a f0fa               	beq .local2
   537  038c af01fc1b           	lda IO_KEYQ_WAITING
   538  0390 8f02fc1b           	sta IO_KEYQ_DEQUEUE
   539  0394 c90d               	cmp #$0d			;carriage return yet?
   540  0396 f01c               	beq .local3
   541  0398 c908               	cmp #$08			;backspace/back arrow?
   542  039a f029               	beq .local4
   543  039c c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
   544  039e 90e6               	bcc .local2		 		;yes, so ignore it
   545  03a0 9f000417           	sta inbuff,x 		;any other character, so register it and store it
   546  03a4 8f12fc1b           	sta IO_CON_CHAROUT
   547  03a8 8f13fc1b           	sta IO_CON_REGISTER
   548  03ac e8                 	inx
   549  03ad a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
   550  03af e0fe03             	cpx #$3fe			;overrun end of buffer yet?
   551  03b2 d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
   552                          .local3
   553  03b4 9f000417           	sta inbuff,x		;store CR
   554  03b8 8f17fc1b           	sta IO_CON_CR
   555  03bc e8                 	inx
   556  03bd a900               	lda #$00			;store zero to end it all
   557  03bf 9f000417           	sta inbuff,x
   558  03c3 28                 	plp
   559  03c4 6b                 	rtl
   560                          .local4
   561  03c5 e00000             	cpx #$0000
   562  03c8 f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
   563  03ca a908               	lda #$08
   564  03cc 8f12fc1b           	sta IO_CON_CHAROUT
   565  03d0 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
   566  03d4 a920               	lda #$20
   567  03d6 8f12fc1b           	sta IO_CON_CHAROUT
   568  03da 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
   569  03de a908               	lda #$08
   570  03e0 8f12fc1b           	sta IO_CON_CHAROUT
   571  03e4 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
   572  03e8 ca                 	dex
   573  03e9 809b               	bra .local2
   574                          	
   575                          prinbuff				;feed location of input buffer into dpla and then print
   576  03eb 08                 	php
   577  03ec c210               	rep #$10
   578  03ee e220               	sep #$20
   579                          	!as
   580                          	!rl
   581  03f0 a917               	lda #$17
   582  03f2 853f               	sta dpla_h
   583  03f4 a904               	lda #$04
   584  03f6 853e               	sta dpla_m
   585  03f8 643d               	stz dpla
   586  03fa 2200041c           	jsl l_prcdpla
   587  03fe 28                 	plp
   588  03ff 6b                 	rtl
   589                          	
   590                          	!zone prcdpla
   591                          prcdpla					; print C string pointed to by dp locations $3d-$3f
   592  0400 08                 	php
   593  0401 c210               	rep #$10
   594  0403 e220               	sep #$20
   595                          	!as
   596                          	!rl
   597  0405 a00000             	ldy #$0000
   598                          .local2
   599  0408 b73d               	lda [dpla],y
   600  040a f00b               	beq .local3
   601  040c 8f12fc1b           	sta IO_CON_CHAROUT
   602  0410 8f13fc1b           	sta IO_CON_REGISTER
   603  0414 c8                 	iny
   604  0415 80f1               	bra .local2
   605                          .local3
   606  0417 28                 	plp
   607  0418 6b                 	rtl
   608                          
   609                          initstring
   610  0419 494d4c2036353831...	!tx "IML 65816 1C Firmware v00"
   611  0432 0d                 	!byte 0x0d
   612  0433 53797374656d204d...	!tx "System Monitor"
   613  0441 0d                 	!byte 0x0d
   614  0442 0d                 	!byte 0x0d
   615  0443 00                 	!byte 0
   616                          
   617                          helpmsg
   618  0444 494d4c2036353831...	!tx "IML 65816 Monitor Commands"
   619  045e 0d                 	!byte $0d
   620  045f 41203c616464723e...	!tx "A <addr>  Dump ASCII"
   621  0473 0d                 	!byte $0d
   622  0474 42203c62616e6b3e...	!tx "B <bank>  Change bank"
   623  0489 0d                 	!byte $0d
   624  048a 43203c636f6c6f72...	!tx "C <color> Change terminal colors"
   625  04aa 0d                 	!byte $0d
   626  04ab 44203c616464723e...	!tx "D <addr>  Dump hex"
   627  04bd 0d                 	!byte $0d
   628  04be 4d203c6d6f64653e...	!tx "M <mode>  Change video mode, 8/9"
   629  04de 0d                 	!byte $0d
   630  04df 5120202020202020...	!tx "Q         Halt the processor"
   631  04fb 0d                 	!byte $0d
   632  04fc 3f20202020202020...	!tx "?         This menu"
   633  050f 0d                 	!byte $0d
   634  0510 3c656e7465723e20...	!tx "<enter>   Repeat last dump command"
   635  0532 0d                 	!byte $0d
   636  0533 546f207370656369...	!tx "To specify range, use <addr1.addr2>"
   637  0556 0d00               	!byte $0d, 00
   638                          	
   639  0558 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
   640                          
