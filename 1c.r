
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
    29                          scratch1 = $2f
    30                          enterbytes = $30
    31                          enterbytes_m = $31
    32                          enterbytes_h = $32
    33                          rangehigh = $33
    34                          monrange = $35
    35                          monlast = $36
    36                          parseptr = $37
    37                          parseptr_m = $38
    38                          parseptr_h = $39
    39                          mondump = $3a
    40                          mondump_m = $3b
    41                          mondump_h = $3c
    42                          dpla = $3d
    43                          dpla_m = $3e
    44                          dpla_h = $3f
    45                          
    46                          inbuff = $170400
    47                          
    48                          x1crominit
    49  0000 4b                 	phk
    50  0001 ab                 	plb
    51  0002 c210               	rep #$10
    52                          	!rl
    53  0004 e220               	sep #$20
    54                          	!as
    55  0006 a26204             	ldx #initstring
    56  0009 863d               	stx dpla
    57  000b a91c               	lda #$1c
    58  000d 853f               	sta dpla_h
    59  000f 2249041c           	jsl l_prcdpla
    60  0013 4c5d01             	jmp+2 monstart
    61                          
    62                          parse_setup
    63  0016 a20004             	ldx #$0400
    64  0019 8637               	stx parseptr
    65  001b a917               	lda #$17
    66  001d 8539               	sta parseptr_h
    67  001f 60                 	rts
    68                          	
    69                          	!zone parse_getchar
    70                          parse_getchar			;get char from inbuff, assumes 8 bit A, 16 bit X
    71  0020 a737               	lda [parseptr]
    72  0022 48                 	pha
    73  0023 e637               	inc parseptr
    74  0025 d006               	bne .local2
    75  0027 e638               	inc parseptr_m
    76  0029 d002               	bne .local2
    77  002b e639               	inc parseptr_h
    78                          .local2
    79  002d 68                 	pla
    80  002e 60                 	rts
    81                          	
    82                          	!zone parse_addr
    83                          parse_addr				;see if user specified an address on line.
    84  002f a900               	lda #$00
    85  0031 48                 	pha
    86  0032 48                 	pha					;make space for working value on the stack
    87  0033 8535               	sta monrange		;clear range flag
    88                          .throwaway
    89  0035 202000             	jsr+2 parse_getchar
    90  0038 c920               	cmp #' '
    91  003a f0f9               	beq .throwaway		;throw away leading spaces
    92  003c 209800             	jsr+2 parse_getnib2	;get first nibble. call 2nd entry point since we already have character
    93  003f 9051               	bcc .no				;didn't even get one hex character, so return false
    94  0041 8301               	sta 1,s				;save it on the stack for now
    95  0043 209500             	jsr+2 parse_getnib	;get second nibble
    96  0046 9047               	bcc .yes			;if not hex then bail
    97  0048 48                 	pha
    98  0049 a302               	lda 2,s
    99  004b 0a                 	asl
   100  004c 0a                 	asl
   101  004d 0a                 	asl
   102  004e 0a                 	asl
   103  004f 0301               	ora 1,s
   104  0051 8302               	sta 2,s
   105  0053 68                 	pla					;add to stack
   106  0054 209500             	jsr+2 parse_getnib	;get possible third nibble
   107  0057 9036               	bcc .yes
   108  0059 c230               	rep #$30			;we're dealing with a 16 bit value now
   109                          	!al
   110  005b 290f00             	and #$000f
   111  005e 48                 	pha
   112  005f a303               	lda 3,s
   113  0061 0a                 	asl
   114  0062 0a                 	asl
   115  0063 0a                 	asl
   116  0064 0a                 	asl
   117  0065 0301               	ora 1,s
   118  0067 8303               	sta 3,s
   119  0069 68                 	pla
   120  006a e220               	sep #$20
   121                          	!as
   122  006c 209500             	jsr+2 parse_getnib
   123  006f 901e               	bcc .yes
   124  0071 c230               	rep #$30
   125                          	!al
   126  0073 290f00             	and #$000f
   127  0076 48                 	pha
   128  0077 a303               	lda 3,s
   129  0079 0a                 	asl
   130  007a 0a                 	asl
   131  007b 0a                 	asl
   132  007c 0a                 	asl
   133  007d 0301               	ora 1,s
   134  007f 8303               	sta 3,s
   135  0081 68                 	pla
   136  0082 e220               	sep #$20			;fall thru to yes on 4th nibble
   137                          	!as
   138  0084 202000             	jsr parse_getchar	;check to see if next char is a . so we can specify ranges
   139  0087 c92e               	cmp #'.'
   140  0089 d004               	bne .yes
   141  008b a980               	lda #$80
   142  008d 8535               	sta monrange
   143                          .yes
   144  008f 7a                 	ply					;get 16 bit work address off of stack
   145  0090 38                 	sec					;got address, return
   146  0091 60                 	rts
   147                          .no
   148  0092 7a                 	ply					;clear stack
   149  0093 18                 	clc					;no address found, return
   150  0094 60                 	rts
   151                          parse_getnib
   152  0095 202000             	jsr parse_getchar
   153                          parse_getnib2			;enter here after we've thrown away leading spaces
   154  0098 c920               	cmp #' '
   155  009a f021               	beq .outrng			;space = end of value
   156  009c c92e               	cmp #'.'
   157  009e d006               	bne .notrange
   158  00a0 a980               	lda #$80
   159  00a2 8535               	sta monrange		;this is the start of a range specification
   160  00a4 18                 	clc
   161  00a5 60                 	rts
   162                          .notrange
   163  00a6 c941               	cmp #$41
   164  00a8 900b               	bcc .outrnga
   165  00aa c947               	cmp #$47
   166  00ac b007               	bcs .outrnga
   167  00ae 38                 	sec
   168  00af e907               	sbc #$07			;in range of A-F
   169                          .success
   170  00b1 290f               	and #$0f
   171  00b3 38                 	sec
   172  00b4 60                 	rts
   173                          .outrnga				;test if 0-9
   174  00b5 c930               	cmp #$30
   175  00b7 9004               	bcc .outrng
   176  00b9 c93a               	cmp #$3a
   177  00bb 90f4               	bcc .success		;less than 3a, but >= 30, else fall thru to outrng
   178                          .outrng
   179  00bd 18                 	clc
   180  00be 60                 	rts
   181                          	
   182                          prdumpaddr
   183  00bf a53c               	lda mondump_h			;print long address
   184  00c1 205403             	jsr+2 prhex
   185  00c4 a92f               	lda #'/'
   186  00c6 8f12fc1b           	sta IO_CON_CHAROUT
   187  00ca 8f13fc1b           	sta IO_CON_REGISTER
   188  00ce a63a               	ldx mondump
   189  00d0 204a03             	jsr+2 prhex16
   190  00d3 a92d               	lda #'-'
   191  00d5 8f12fc1b           	sta IO_CON_CHAROUT
   192  00d9 8f13fc1b           	sta IO_CON_REGISTER
   193  00dd a920               	lda #' '
   194  00df 8f12fc1b           	sta IO_CON_CHAROUT
   195  00e3 8f13fc1b           	sta IO_CON_REGISTER
   196  00e7 60                 	rts
   197                          	
   198                          adjdumpaddr					;add 8 to dump address
   199  00e8 c230               	rep #$30
   200                          	!al
   201  00ea a53a               	lda mondump
   202  00ec 18                 	clc
   203  00ed 690800             	adc #$0008
   204  00f0 853a               	sta mondump
   205  00f2 e220               	sep #$20
   206                          	!as
   207  00f4 08                 	php						;save carry state.. did we carry to the bank?
   208  00f5 a53c               	lda mondump_h
   209  00f7 6900               	adc #$00
   210  00f9 853c               	sta mondump_h
   211  00fb 28                 	plp
   212  00fc 60                 	rts
   213                          	
   214                          bankcmd
   215  00fd 202f00             	jsr parse_addr
   216  0100 9006               	bcc monerror
   217  0102 98                 	tya
   218  0103 853c               	sta mondump_h
   219  0105 4c7001             	jmp moncmd
   220                          monerror
   221  0108 a21801             	ldx #monsynerr
   222  010b 863d               	stx dpla
   223  010d a91c               	lda #$1c
   224  010f 853f               	sta dpla_h
   225  0111 2249041c           	jsl l_prcdpla
   226  0115 4c7001             	jmp moncmd
   227                          monsynerr
   228  0118 53796e7461782065...	!tx "Syntax error!"
   229  0125 0d00               	!byte $0d, $00
   230                          
   231                          colorcmd
   232  0127 202f00             	jsr parse_addr
   233  012a 90dc               	bcc monerror
   234  012c 98                 	tya
   235  012d 8f11fc1b           	sta IO_CON_COLOR
   236  0131 4c7001             	jmp moncmd
   237                          	
   238                          modecmd
   239  0134 202f00             	jsr parse_addr
   240  0137 90cf               	bcc monerror
   241  0139 98                 	tya
   242  013a c908               	cmp #$08
   243  013c 90ca               	bcc monerror
   244  013e c90a               	cmp #$0a
   245  0140 b0c6               	bcs monerror
   246  0142 8f20fc1b           	sta IO_VIDMODE
   247  0146 a900               	lda #$00
   248  0148 8f14fc1b           	sta IO_CON_CURSORH
   249  014c 8f15fc1b           	sta IO_CON_CURSORV
   250  0150 a920               	lda #$20
   251  0152 8f12fc1b           	sta IO_CON_CHAROUT
   252  0156 8f10fc1b           	sta IO_CON_CLS
   253  015a 4c7001             	jmp moncmd
   254                          	
   255                          monstart				;main entry point for system monitor
   256  015d 4b                 	phk
   257  015e ab                 	plb
   258  015f c210               	rep #$10
   259                          	!rl
   260  0161 e220               	sep #$20
   261                          	!as
   262  0163 a20000             	ldx #$0000
   263  0166 863a               	stx mondump
   264  0168 a91c               	lda #$1c
   265  016a 853c               	sta mondump_h
   266  016c a944               	lda #'D'
   267  016e 8536               	sta monlast
   268                          	
   269                          	!zone moncmd
   270                          moncmd
   271  0170 a93e               	lda #promptchar
   272  0172 8f12fc1b           	sta IO_CON_CHAROUT
   273  0176 8f13fc1b           	sta IO_CON_REGISTER
   274  017a 22c7031c           	jsl l_getline
   275  017e 22a5031c           	jsl l_ucline
   276  0182 201600             	jsr parse_setup
   277  0185 202000             	jsr parse_getchar
   278                          .local3
   279  0188 c951               	cmp #'Q'
   280  018a f051               	beq haltcmd
   281  018c c944               	cmp #'D'
   282  018e d003               	bne .local4
   283  0190 4c9902             	jmp+2 dumpcmd
   284                          .local4
   285  0193 c90d               	cmp #$0d
   286  0195 d008               	bne .local2
   287  0197 a536               	lda monlast			;recall previously executed command
   288  0199 c920               	cmp #$20			;make sure it isn't a control character
   289  019b b0eb               	bcs .local3			;and retry it
   290  019d 80d1               	bra moncmd			;else recycle and try a new command
   291                          .local2
   292  019f c941               	cmp #'A'
   293  01a1 f060               	beq asciidumpcmd
   294  01a3 c942               	cmp #'B'
   295  01a5 d003               	bne .local5
   296  01a7 4cfd00             	jmp+2 bankcmd
   297                          .local5
   298  01aa c943               	cmp #'C'
   299  01ac d003               	bne .local6
   300  01ae 4c2701             	jmp+2 colorcmd
   301                          .local6
   302  01b1 c94d               	cmp #'M'
   303  01b3 d003               	bne .local7
   304  01b5 4c3401             	jmp+2 modecmd
   305                          .local7
   306  01b8 c945               	cmp #'E'
   307  01ba d003               	bne .local8
   308  01bc 4c7403             	jmp+2 entercmd
   309                          .local8
   310  01bf c94c               	cmp #'L'
   311  01c1 d003               	bne .local9
   312  01c3 4ca203             	jmp+2 listcmd
   313                          .local9
   314  01c6 c93f               	cmp #'?'
   315  01c8 f003               	beq helpcmd
   316  01ca 4c7001             	jmp moncmd
   317                          	
   318                          helpcmd
   319  01cd a28d04             	ldx #helpmsg
   320  01d0 863d               	stx dpla
   321  01d2 a91c               	lda #$1c
   322  01d4 853f               	sta dpla_h
   323  01d6 2249041c           	jsl l_prcdpla
   324  01da 4c7001             	jmp moncmd
   325                          	
   326                          haltcmd
   327  01dd a2eb01             	ldx #haltmsg
   328  01e0 863d               	stx dpla
   329  01e2 a91c               	lda #$1c
   330  01e4 853f               	sta dpla_h
   331  01e6 2249041c           	jsl l_prcdpla
   332  01ea db                 	stp
   333                          haltmsg
   334  01eb 48616c74696e6720...	!tx "Halting 65816 engine.."
   335  0201 0d00               	!byte $0d,$00
   336                          	
   337                          	!zone asciidumpcmd
   338                          asciidumpcmd
   339  0203 8536               	sta monlast
   340  0205 202f00             	jsr parse_addr
   341  0208 9021               	bcc .local3
   342  020a 843a               	sty mondump
   343  020c 8433               	sty rangehigh
   344  020e 2435               	bit monrange			;user asking for a range?
   345  0210 1019               	bpl .local3
   346  0212 202f00             	jsr parse_addr			;get the remaining half of the range
   347  0215 8433               	sty rangehigh
   348  0217 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   349  0219 8535               	sta monrange
   350  021b a433               	ldy rangehigh
   351  021d d003               	bne .local6
   352  021f 4c0801             	jmp+2 monerror			;top of range can't be zero
   353                          .local6
   354  0222 a43a               	ldy mondump
   355  0224 c433               	cpy rangehigh
   356  0226 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   357  0228 4c0801             	jmp+2 monerror
   358                          .local3
   359  022b 20bf00             	jsr prdumpaddr
   360  022e a00000             	ldy #$0000
   361                          .local2
   362  0231 b73a               	lda [mondump],y
   363  0233 c920               	cmp #$20
   364  0235 b002               	bcs .local4
   365  0237 a92e               	lda #'.'				;substitute control character with a period
   366                          .local4
   367  0239 8f12fc1b           	sta IO_CON_CHAROUT
   368  023d 8f13fc1b           	sta IO_CON_REGISTER
   369  0241 c8                 	iny
   370  0242 af20fc1b           	lda IO_VIDMODE
   371  0246 c909               	cmp #$09
   372  0248 d007               	bne .lores1
   373  024a c04000             	cpy #$0040
   374  024d d0e2               	bne .local2
   375  024f 8005               	bra .lores2
   376                          .lores1
   377  0251 c01000             	cpy #$0010
   378  0254 d0db               	bne .local2
   379                          .lores2
   380  0256 8f17fc1b           	sta IO_CON_CR
   381  025a 20e800             	jsr adjdumpaddr
   382  025d b035               	bcs .local5				;carry to bank, exit even if we're processing a range
   383  025f 20e800             	jsr adjdumpaddr
   384  0262 b030               	bcs .local5	
   385  0264 af20fc1b           	lda IO_VIDMODE
   386  0268 c909               	cmp #$09
   387  026a d01e               	bne .lores3
   388  026c 20e800             	jsr adjdumpaddr
   389  026f b023               	bcs .local5	
   390  0271 20e800             	jsr adjdumpaddr
   391  0274 b01e               	bcs .local5	
   392  0276 20e800             	jsr adjdumpaddr
   393  0279 b019               	bcs .local5	
   394  027b 20e800             	jsr adjdumpaddr
   395  027e b014               	bcs .local5	
   396  0280 20e800             	jsr adjdumpaddr
   397  0283 b00f               	bcs .local5	
   398  0285 20e800             	jsr adjdumpaddr
   399  0288 b00a               	bcs .local5	
   400                          .lores3
   401  028a 2435               	bit monrange			;ranges on?
   402  028c 1006               	bpl .local5
   403  028e a433               	ldy rangehigh
   404  0290 c43a               	cpy mondump
   405  0292 b097               	bcs .local3
   406                          .local5
   407  0294 6435               	stz monrange
   408  0296 4c7001             	jmp moncmd
   409                          	
   410                          	!zone dumpcmd
   411                          dumpcmd
   412  0299 8536               	sta monlast
   413  029b 202f00             	jsr parse_addr
   414  029e 9021               	bcc .local3
   415  02a0 843a               	sty mondump				;if address was specified, store 16 bit y at low 16 bits of mondump address
   416  02a2 8433               	sty rangehigh
   417  02a4 2435               	bit monrange			;user asking for a range?
   418  02a6 1019               	bpl .local3
   419  02a8 202f00             	jsr parse_addr			;get the remaining half of the range
   420  02ab 8433               	sty rangehigh
   421  02ad a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   422  02af 8535               	sta monrange
   423  02b1 a433               	ldy rangehigh
   424  02b3 d003               	bne .local6
   425  02b5 4c0801             	jmp+2 monerror			;top of range can't be zero
   426                          .local6
   427  02b8 a43a               	ldy mondump
   428  02ba c433               	cpy rangehigh
   429  02bc 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   430  02be 4c0801             	jmp+2 monerror
   431                          .local3
   432  02c1 20bf00             	jsr prdumpaddr
   433  02c4 a00000             	ldy #$0000
   434                          .local2
   435  02c7 b73a               	lda [mondump],y
   436  02c9 205403             	jsr+2 prhex
   437  02cc a920               	lda #' '
   438  02ce 8f12fc1b           	sta IO_CON_CHAROUT
   439  02d2 8f13fc1b           	sta IO_CON_REGISTER
   440  02d6 c8                 	iny
   441  02d7 af20fc1b           	lda IO_VIDMODE
   442  02db c909               	cmp #$09
   443  02dd d03e               	bne .lores1
   444  02df c01000             	cpy #$0010
   445  02e2 d0e3               	bne .local2
   446  02e4 a920               	lda #' '
   447  02e6 8f12fc1b           	sta IO_CON_CHAROUT
   448  02ea 8f13fc1b           	sta IO_CON_REGISTER
   449  02ee a92d               	lda #'-'
   450  02f0 8f12fc1b           	sta IO_CON_CHAROUT
   451  02f4 8f13fc1b           	sta IO_CON_REGISTER
   452  02f8 a920               	lda #' '
   453  02fa 8f12fc1b           	sta IO_CON_CHAROUT
   454  02fe 8f13fc1b           	sta IO_CON_REGISTER
   455  0302 a00000             	ldy #$0000				;print 16 bytes as ASCII... bonus when in mode 9!
   456                          .asc2
   457  0305 b73a               	lda [mondump],y
   458  0307 c920               	cmp #$20
   459  0309 b002               	bcs .asc4
   460  030b a92e               	lda #'.'				;substitute control character with a period
   461                          .asc4
   462  030d 8f12fc1b           	sta IO_CON_CHAROUT
   463  0311 8f13fc1b           	sta IO_CON_REGISTER
   464  0315 c8                 	iny
   465  0316 c01000             	cpy #$0010
   466  0319 d0ea               	bne .asc2
   467  031b 8005               	bra .lores2
   468                          .lores1
   469  031d c00800             	cpy #$0008
   470  0320 d0a5               	bne .local2
   471                          .lores2
   472  0322 8f17fc1b           	sta IO_CON_CR
   473  0326 20e800             	jsr adjdumpaddr
   474  0329 b01a               	bcs .local5				;carry to bank, exit even if we're processing a range
   475  032b af20fc1b           	lda IO_VIDMODE
   476  032f c909               	cmp #$09
   477  0331 d005               	bne .lores3
   478  0333 20e800             	jsr adjdumpaddr
   479  0336 b00d               	bcs .local5
   480                          .lores3
   481  0338 2435               	bit monrange			;ranges on?
   482  033a 1009               	bpl .local5
   483  033c a433               	ldy rangehigh
   484  033e c43a               	cpy mondump
   485  0340 9003               	bcc .local5
   486  0342 4cc102             	jmp+2 .local3
   487                          .local5
   488  0345 6435               	stz monrange
   489  0347 4c7001             	jmp moncmd
   490                          	
   491                          prhex16
   492  034a c230               	rep #$30
   493  034c 8a                 	txa
   494  034d e220               	sep #$20
   495  034f eb                 	xba
   496  0350 205403             	jsr+2 prhex
   497  0353 eb                 	xba
   498                          prhex
   499  0354 48                 	pha
   500  0355 4a                 	lsr
   501  0356 4a                 	lsr
   502  0357 4a                 	lsr
   503  0358 4a                 	lsr
   504  0359 205f03             	jsr+2 prhexnib
   505  035c 68                 	pla
   506  035d 290f               	and #$0f
   507                          prhexnib
   508  035f 0930               	ora #$30
   509  0361 c93a               	cmp #$3a
   510  0363 9003               	bcc prhexnofix
   511  0365 18                 	clc
   512  0366 6907               	adc #$07
   513                          prhexnofix
   514  0368 8f12fc1b           	sta IO_CON_CHAROUT
   515  036c 8f13fc1b           	sta IO_CON_REGISTER
   516  0370 60                 	rts
   517                          
   518                          	!zone entercmd
   519                          .local1
   520  0371 4c0801             	jmp monerror
   521                          entercmd
   522  0374 202f00             	jsr parse_addr
   523  0377 90f8               	bcc .local1
   524  0379 2435               	bit monrange
   525  037b 30f4               	bmi .local1			;ranges not allowed
   526  037d 8430               	sty enterbytes
   527  037f a53c               	lda mondump_h
   528  0381 8532               	sta enterbytes_h	;retrieve bank from mondump
   529                          .local2
   530  0383 202f00             	jsr parse_addr		;start grabbing bytes
   531  0386 9017               	bcc .enterdone
   532  0388 2435               	bit monrange
   533  038a 30e5               	bmi .local1			;stop that happening here too
   534  038c c230               	rep #$30
   535  038e 98                 	tya
   536  038f e220               	sep #$20			;get low byte of parsed address into A
   537  0391 8730               	sta [enterbytes]
   538  0393 e630               	inc enterbytes
   539  0395 d006               	bne .local3
   540  0397 e631               	inc enterbytes_m
   541  0399 d002               	bne .local3
   542  039b e632               	inc enterbytes_h
   543                          .local3
   544  039d 80e4               	bra .local2
   545                          .enterdone
   546  039f 4c7001             	jmp moncmd
   547                          	
   548                          	!zone listcmd
   549                          listcmd
   550  03a2 4c7001             	jmp moncmd
   551                          	
   552                          	!zone ucline
   553                          ucline					;convert inbuff at $170400 to upper case
   554  03a5 08                 	php
   555  03a6 c210               	rep #$10
   556  03a8 e220               	sep #$20
   557                          	!as
   558                          	!rl
   559  03aa a20000             	ldx #$0000
   560                          .local2
   561  03ad bf000417           	lda inbuff,x
   562  03b1 f012               	beq .local4			;hit the zero, so bail
   563  03b3 c961               	cmp #'a'
   564  03b5 900b               	bcc .local3			;less then lowercase a, so ignore
   565  03b7 c97b               	cmp #'z' + 1		;less than next character after lowercase z?
   566  03b9 b007               	bcs .local3			;greater than or equal, so ignore
   567  03bb 38                 	sec
   568  03bc e920               	sbc #('z' - 'Z')	;make upper case
   569  03be 9f000417           	sta inbuff,x
   570                          .local3
   571  03c2 e8                 	inx
   572  03c3 80e8               	bra .local2
   573                          .local4
   574  03c5 28                 	plp
   575  03c6 6b                 	rtl
   576                          	
   577                          	!zone getline
   578                          getline
   579  03c7 08                 	php
   580  03c8 c210               	rep #$10
   581  03ca e220               	sep #$20
   582                          	!as
   583                          	!rl
   584  03cc a20000             	ldx #$0000
   585                          .local2
   586  03cf af00fc1b           	lda IO_KEYQ_SIZE
   587  03d3 f0fa               	beq .local2
   588  03d5 af01fc1b           	lda IO_KEYQ_WAITING
   589  03d9 8f02fc1b           	sta IO_KEYQ_DEQUEUE
   590  03dd c90d               	cmp #$0d			;carriage return yet?
   591  03df f01c               	beq .local3
   592  03e1 c908               	cmp #$08			;backspace/back arrow?
   593  03e3 f029               	beq .local4
   594  03e5 c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
   595  03e7 90e6               	bcc .local2		 		;yes, so ignore it
   596  03e9 9f000417           	sta inbuff,x 		;any other character, so register it and store it
   597  03ed 8f12fc1b           	sta IO_CON_CHAROUT
   598  03f1 8f13fc1b           	sta IO_CON_REGISTER
   599  03f5 e8                 	inx
   600  03f6 a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
   601  03f8 e0fe03             	cpx #$3fe			;overrun end of buffer yet?
   602  03fb d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
   603                          .local3
   604  03fd 9f000417           	sta inbuff,x		;store CR
   605  0401 8f17fc1b           	sta IO_CON_CR
   606  0405 e8                 	inx
   607  0406 a900               	lda #$00			;store zero to end it all
   608  0408 9f000417           	sta inbuff,x
   609  040c 28                 	plp
   610  040d 6b                 	rtl
   611                          .local4
   612  040e e00000             	cpx #$0000
   613  0411 f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
   614  0413 a908               	lda #$08
   615  0415 8f12fc1b           	sta IO_CON_CHAROUT
   616  0419 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
   617  041d a920               	lda #$20
   618  041f 8f12fc1b           	sta IO_CON_CHAROUT
   619  0423 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
   620  0427 a908               	lda #$08
   621  0429 8f12fc1b           	sta IO_CON_CHAROUT
   622  042d 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
   623  0431 ca                 	dex
   624  0432 809b               	bra .local2
   625                          	
   626                          prinbuff				;feed location of input buffer into dpla and then print
   627  0434 08                 	php
   628  0435 c210               	rep #$10
   629  0437 e220               	sep #$20
   630                          	!as
   631                          	!rl
   632  0439 a917               	lda #$17
   633  043b 853f               	sta dpla_h
   634  043d a904               	lda #$04
   635  043f 853e               	sta dpla_m
   636  0441 643d               	stz dpla
   637  0443 2249041c           	jsl l_prcdpla
   638  0447 28                 	plp
   639  0448 6b                 	rtl
   640                          	
   641                          	!zone prcdpla
   642                          prcdpla					; print C string pointed to by dp locations $3d-$3f
   643  0449 08                 	php
   644  044a c210               	rep #$10
   645  044c e220               	sep #$20
   646                          	!as
   647                          	!rl
   648  044e a00000             	ldy #$0000
   649                          .local2
   650  0451 b73d               	lda [dpla],y
   651  0453 f00b               	beq .local3
   652  0455 8f12fc1b           	sta IO_CON_CHAROUT
   653  0459 8f13fc1b           	sta IO_CON_REGISTER
   654  045d c8                 	iny
   655  045e 80f1               	bra .local2
   656                          .local3
   657  0460 28                 	plp
   658  0461 6b                 	rtl
   659                          
   660                          initstring
   661  0462 494d4c2036353831...	!tx "IML 65816 1C Firmware v00"
   662  047b 0d                 	!byte 0x0d
   663  047c 53797374656d204d...	!tx "System Monitor"
   664  048a 0d                 	!byte 0x0d
   665  048b 0d                 	!byte 0x0d
   666  048c 00                 	!byte 0
   667                          
   668                          helpmsg
   669  048d 494d4c2036353831...	!tx "IML 65816 Monitor Commands"
   670  04a7 0d                 	!byte $0d
   671  04a8 41203c616464723e...	!tx "A <addr>  Dump ASCII"
   672  04bc 0d                 	!byte $0d
   673  04bd 42203c62616e6b3e...	!tx "B <bank>  Change bank"
   674  04d2 0d                 	!byte $0d
   675  04d3 43203c636f6c6f72...	!tx "C <color> Change terminal colors"
   676  04f3 0d                 	!byte $0d
   677  04f4 44203c616464723e...	!tx "D <addr>  Dump hex"
   678  0506 0d                 	!byte $0d
   679  0507 45203c616464723e...	!tx "E <addr> <byte> <byte>...  Enter bytes"
   680  052d 0d                 	!byte $0d
   681  052e 4c203c616464723e...	!tx "L <addr>  Disassemble 65816 Instructions"
   682  0556 0d                 	!byte $0d
   683  0557 4d203c6d6f64653e...	!tx "M <mode>  Change video mode, 8/9"
   684  0577 0d                 	!byte $0d
   685  0578 5120202020202020...	!tx "Q         Halt the processor"
   686  0594 0d                 	!byte $0d
   687  0595 3f20202020202020...	!tx "?         This menu"
   688  05a8 0d                 	!byte $0d
   689  05a9 3c656e7465723e20...	!tx "<enter>   Repeat last dump command"
   690  05cb 0d                 	!byte $0d
   691  05cc 546f207370656369...	!tx "To specify range, use <addr1.addr2>"
   692  05ef 0d00               	!byte $0d, 00
   693                          	
   694  05f1 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
   695                          
