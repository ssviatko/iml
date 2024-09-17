
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
    29                          alarge = $2d
    30                          xlarge = $2e
    31                          scratch1 = $2f
    32                          enterbytes = $30
    33                          enterbytes_m = $31
    34                          enterbytes_h = $32
    35                          rangehigh = $33
    36                          monrange = $35
    37                          monlast = $36
    38                          parseptr = $37
    39                          parseptr_m = $38
    40                          parseptr_h = $39
    41                          mondump = $3a
    42                          mondump_m = $3b
    43                          mondump_h = $3c
    44                          dpla = $3d
    45                          dpla_m = $3e
    46                          dpla_h = $3f
    47                          
    48                          inbuff = $170400
    49                          
    50                          x1crominit
    51  0000 4b                 	phk
    52  0001 ab                 	plb
    53  0002 c210               	rep #$10
    54                          	!rl
    55  0004 e220               	sep #$20
    56                          	!as
    57  0006 a26406             	ldx #initstring
    58  0009 863d               	stx dpla
    59  000b a91c               	lda #$1c
    60  000d 853f               	sta dpla_h
    61  000f 224b061c           	jsl l_prcdpla
    62  0013 4c5d01             	jmp+2 monstart
    63                          
    64                          parse_setup
    65  0016 a20004             	ldx #$0400
    66  0019 8637               	stx parseptr
    67  001b a917               	lda #$17
    68  001d 8539               	sta parseptr_h
    69  001f 60                 	rts
    70                          	
    71                          	!zone parse_getchar
    72                          parse_getchar			;get char from inbuff, assumes 8 bit A, 16 bit X
    73  0020 a737               	lda [parseptr]
    74  0022 48                 	pha
    75  0023 e637               	inc parseptr
    76  0025 d006               	bne .local2
    77  0027 e638               	inc parseptr_m
    78  0029 d002               	bne .local2
    79  002b e639               	inc parseptr_h
    80                          .local2
    81  002d 68                 	pla
    82  002e 60                 	rts
    83                          	
    84                          	!zone parse_addr
    85                          parse_addr				;see if user specified an address on line.
    86  002f a900               	lda #$00
    87  0031 48                 	pha
    88  0032 48                 	pha					;make space for working value on the stack
    89  0033 8535               	sta monrange		;clear range flag
    90                          .throwaway
    91  0035 202000             	jsr+2 parse_getchar
    92  0038 c920               	cmp #' '
    93  003a f0f9               	beq .throwaway		;throw away leading spaces
    94  003c 209800             	jsr+2 parse_getnib2	;get first nibble. call 2nd entry point since we already have character
    95  003f 9051               	bcc .no				;didn't even get one hex character, so return false
    96  0041 8301               	sta 1,s				;save it on the stack for now
    97  0043 209500             	jsr+2 parse_getnib	;get second nibble
    98  0046 9047               	bcc .yes			;if not hex then bail
    99  0048 48                 	pha
   100  0049 a302               	lda 2,s
   101  004b 0a                 	asl
   102  004c 0a                 	asl
   103  004d 0a                 	asl
   104  004e 0a                 	asl
   105  004f 0301               	ora 1,s
   106  0051 8302               	sta 2,s
   107  0053 68                 	pla					;add to stack
   108  0054 209500             	jsr+2 parse_getnib	;get possible third nibble
   109  0057 9036               	bcc .yes
   110  0059 c230               	rep #$30			;we're dealing with a 16 bit value now
   111                          	!al
   112  005b 290f00             	and #$000f
   113  005e 48                 	pha
   114  005f a303               	lda 3,s
   115  0061 0a                 	asl
   116  0062 0a                 	asl
   117  0063 0a                 	asl
   118  0064 0a                 	asl
   119  0065 0301               	ora 1,s
   120  0067 8303               	sta 3,s
   121  0069 68                 	pla
   122  006a e220               	sep #$20
   123                          	!as
   124  006c 209500             	jsr+2 parse_getnib
   125  006f 901e               	bcc .yes
   126  0071 c230               	rep #$30
   127                          	!al
   128  0073 290f00             	and #$000f
   129  0076 48                 	pha
   130  0077 a303               	lda 3,s
   131  0079 0a                 	asl
   132  007a 0a                 	asl
   133  007b 0a                 	asl
   134  007c 0a                 	asl
   135  007d 0301               	ora 1,s
   136  007f 8303               	sta 3,s
   137  0081 68                 	pla
   138  0082 e220               	sep #$20			;fall thru to yes on 4th nibble
   139                          	!as
   140  0084 202000             	jsr parse_getchar	;check to see if next char is a . so we can specify ranges
   141  0087 c92e               	cmp #'.'
   142  0089 d004               	bne .yes
   143  008b a980               	lda #$80
   144  008d 8535               	sta monrange
   145                          .yes
   146  008f 7a                 	ply					;get 16 bit work address off of stack
   147  0090 38                 	sec					;got address, return
   148  0091 60                 	rts
   149                          .no
   150  0092 7a                 	ply					;clear stack
   151  0093 18                 	clc					;no address found, return
   152  0094 60                 	rts
   153                          parse_getnib
   154  0095 202000             	jsr parse_getchar
   155                          parse_getnib2			;enter here after we've thrown away leading spaces
   156  0098 c920               	cmp #' '
   157  009a f021               	beq .outrng			;space = end of value
   158  009c c92e               	cmp #'.'
   159  009e d006               	bne .notrange
   160  00a0 a980               	lda #$80
   161  00a2 8535               	sta monrange		;this is the start of a range specification
   162  00a4 18                 	clc
   163  00a5 60                 	rts
   164                          .notrange
   165  00a6 c941               	cmp #$41
   166  00a8 900b               	bcc .outrnga
   167  00aa c947               	cmp #$47
   168  00ac b007               	bcs .outrnga
   169  00ae 38                 	sec
   170  00af e907               	sbc #$07			;in range of A-F
   171                          .success
   172  00b1 290f               	and #$0f
   173  00b3 38                 	sec
   174  00b4 60                 	rts
   175                          .outrnga				;test if 0-9
   176  00b5 c930               	cmp #$30
   177  00b7 9004               	bcc .outrng
   178  00b9 c93a               	cmp #$3a
   179  00bb 90f4               	bcc .success		;less than 3a, but >= 30, else fall thru to outrng
   180                          .outrng
   181  00bd 18                 	clc
   182  00be 60                 	rts
   183                          	
   184                          prdumpaddr
   185  00bf a53c               	lda mondump_h			;print long address
   186  00c1 205403             	jsr+2 prhex
   187  00c4 a92f               	lda #'/'
   188  00c6 8f12fc1b           	sta IO_CON_CHAROUT
   189  00ca 8f13fc1b           	sta IO_CON_REGISTER
   190  00ce a63a               	ldx mondump
   191  00d0 204a03             	jsr+2 prhex16
   192  00d3 a92d               	lda #'-'
   193  00d5 8f12fc1b           	sta IO_CON_CHAROUT
   194  00d9 8f13fc1b           	sta IO_CON_REGISTER
   195  00dd a920               	lda #' '
   196  00df 8f12fc1b           	sta IO_CON_CHAROUT
   197  00e3 8f13fc1b           	sta IO_CON_REGISTER
   198  00e7 60                 	rts
   199                          	
   200                          adjdumpaddr					;add 8 to dump address
   201  00e8 c230               	rep #$30
   202                          	!al
   203  00ea a53a               	lda mondump
   204  00ec 18                 	clc
   205  00ed 690800             	adc #$0008
   206  00f0 853a               	sta mondump
   207  00f2 e220               	sep #$20
   208                          	!as
   209  00f4 08                 	php						;save carry state.. did we carry to the bank?
   210  00f5 a53c               	lda mondump_h
   211  00f7 6900               	adc #$00
   212  00f9 853c               	sta mondump_h
   213  00fb 28                 	plp
   214  00fc 60                 	rts
   215                          	
   216                          bankcmd
   217  00fd 202f00             	jsr parse_addr
   218  0100 9006               	bcc monerror
   219  0102 98                 	tya
   220  0103 853c               	sta mondump_h
   221  0105 4c7001             	jmp moncmd
   222                          monerror
   223  0108 a21801             	ldx #monsynerr
   224  010b 863d               	stx dpla
   225  010d a91c               	lda #$1c
   226  010f 853f               	sta dpla_h
   227  0111 224b061c           	jsl l_prcdpla
   228  0115 4c7001             	jmp moncmd
   229                          monsynerr
   230  0118 53796e7461782065...	!tx "Syntax error!"
   231  0125 0d00               	!byte $0d, $00
   232                          
   233                          colorcmd
   234  0127 202f00             	jsr parse_addr
   235  012a 90dc               	bcc monerror
   236  012c 98                 	tya
   237  012d 8f11fc1b           	sta IO_CON_COLOR
   238  0131 4c7001             	jmp moncmd
   239                          	
   240                          modecmd
   241  0134 202f00             	jsr parse_addr
   242  0137 90cf               	bcc monerror
   243  0139 98                 	tya
   244  013a c908               	cmp #$08
   245  013c 90ca               	bcc monerror
   246  013e c90a               	cmp #$0a
   247  0140 b0c6               	bcs monerror
   248  0142 8f20fc1b           	sta IO_VIDMODE
   249  0146 a900               	lda #$00
   250  0148 8f14fc1b           	sta IO_CON_CURSORH
   251  014c 8f15fc1b           	sta IO_CON_CURSORV
   252  0150 a920               	lda #$20
   253  0152 8f12fc1b           	sta IO_CON_CHAROUT
   254  0156 8f10fc1b           	sta IO_CON_CLS
   255  015a 4c7001             	jmp moncmd
   256                          	
   257                          monstart				;main entry point for system monitor
   258  015d 4b                 	phk
   259  015e ab                 	plb
   260  015f c210               	rep #$10
   261                          	!rl
   262  0161 e220               	sep #$20
   263                          	!as
   264  0163 a20000             	ldx #$0000
   265  0166 863a               	stx mondump
   266  0168 a91c               	lda #$1c
   267  016a 853c               	sta mondump_h
   268  016c a944               	lda #'D'
   269  016e 8536               	sta monlast
   270                          	
   271                          	!zone moncmd
   272                          moncmd
   273  0170 a93e               	lda #promptchar
   274  0172 8f12fc1b           	sta IO_CON_CHAROUT
   275  0176 8f13fc1b           	sta IO_CON_REGISTER
   276  017a 22c9051c           	jsl l_getline
   277  017e 22a7051c           	jsl l_ucline
   278  0182 201600             	jsr parse_setup
   279  0185 202000             	jsr parse_getchar
   280                          .local3
   281  0188 c951               	cmp #'Q'
   282  018a f051               	beq haltcmd
   283  018c c944               	cmp #'D'
   284  018e d003               	bne .local4
   285  0190 4c9902             	jmp+2 dumpcmd
   286                          .local4
   287  0193 c90d               	cmp #$0d
   288  0195 d008               	bne .local2
   289  0197 a536               	lda monlast			;recall previously executed command
   290  0199 c920               	cmp #$20			;make sure it isn't a control character
   291  019b b0eb               	bcs .local3			;and retry it
   292  019d 80d1               	bra moncmd			;else recycle and try a new command
   293                          .local2
   294  019f c941               	cmp #'A'
   295  01a1 f060               	beq asciidumpcmd
   296  01a3 c942               	cmp #'B'
   297  01a5 d003               	bne .local5
   298  01a7 4cfd00             	jmp+2 bankcmd
   299                          .local5
   300  01aa c943               	cmp #'C'
   301  01ac d003               	bne .local6
   302  01ae 4c2701             	jmp+2 colorcmd
   303                          .local6
   304  01b1 c94d               	cmp #'M'
   305  01b3 d003               	bne .local7
   306  01b5 4c3401             	jmp+2 modecmd
   307                          .local7
   308  01b8 c945               	cmp #'E'
   309  01ba d003               	bne .local8
   310  01bc 4c7403             	jmp+2 entercmd
   311                          .local8
   312  01bf c94c               	cmp #'L'
   313  01c1 d003               	bne .local9
   314  01c3 4ca203             	jmp+2 listcmd
   315                          .local9
   316  01c6 c93f               	cmp #'?'
   317  01c8 f003               	beq helpcmd
   318  01ca 4c7001             	jmp moncmd
   319                          	
   320                          helpcmd
   321  01cd a28f06             	ldx #helpmsg
   322  01d0 863d               	stx dpla
   323  01d2 a91c               	lda #$1c
   324  01d4 853f               	sta dpla_h
   325  01d6 224b061c           	jsl l_prcdpla
   326  01da 4c7001             	jmp moncmd
   327                          	
   328                          haltcmd
   329  01dd a2eb01             	ldx #haltmsg
   330  01e0 863d               	stx dpla
   331  01e2 a91c               	lda #$1c
   332  01e4 853f               	sta dpla_h
   333  01e6 224b061c           	jsl l_prcdpla
   334  01ea db                 	stp
   335                          haltmsg
   336  01eb 48616c74696e6720...	!tx "Halting 65816 engine.."
   337  0201 0d00               	!byte $0d,$00
   338                          	
   339                          	!zone asciidumpcmd
   340                          asciidumpcmd
   341  0203 8536               	sta monlast
   342  0205 202f00             	jsr parse_addr
   343  0208 9021               	bcc .local3
   344  020a 843a               	sty mondump
   345  020c 8433               	sty rangehigh
   346  020e 2435               	bit monrange			;user asking for a range?
   347  0210 1019               	bpl .local3
   348  0212 202f00             	jsr parse_addr			;get the remaining half of the range
   349  0215 8433               	sty rangehigh
   350  0217 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   351  0219 8535               	sta monrange
   352  021b a433               	ldy rangehigh
   353  021d d003               	bne .local6
   354  021f 4c0801             	jmp+2 monerror			;top of range can't be zero
   355                          .local6
   356  0222 a43a               	ldy mondump
   357  0224 c433               	cpy rangehigh
   358  0226 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   359  0228 4c0801             	jmp+2 monerror
   360                          .local3
   361  022b 20bf00             	jsr prdumpaddr
   362  022e a00000             	ldy #$0000
   363                          .local2
   364  0231 b73a               	lda [mondump],y
   365  0233 c920               	cmp #$20
   366  0235 b002               	bcs .local4
   367  0237 a92e               	lda #'.'				;substitute control character with a period
   368                          .local4
   369  0239 8f12fc1b           	sta IO_CON_CHAROUT
   370  023d 8f13fc1b           	sta IO_CON_REGISTER
   371  0241 c8                 	iny
   372  0242 af20fc1b           	lda IO_VIDMODE
   373  0246 c909               	cmp #$09
   374  0248 d007               	bne .lores1
   375  024a c04000             	cpy #$0040
   376  024d d0e2               	bne .local2
   377  024f 8005               	bra .lores2
   378                          .lores1
   379  0251 c01000             	cpy #$0010
   380  0254 d0db               	bne .local2
   381                          .lores2
   382  0256 8f17fc1b           	sta IO_CON_CR
   383  025a 20e800             	jsr adjdumpaddr
   384  025d b035               	bcs .local5				;carry to bank, exit even if we're processing a range
   385  025f 20e800             	jsr adjdumpaddr
   386  0262 b030               	bcs .local5	
   387  0264 af20fc1b           	lda IO_VIDMODE
   388  0268 c909               	cmp #$09
   389  026a d01e               	bne .lores3
   390  026c 20e800             	jsr adjdumpaddr
   391  026f b023               	bcs .local5	
   392  0271 20e800             	jsr adjdumpaddr
   393  0274 b01e               	bcs .local5	
   394  0276 20e800             	jsr adjdumpaddr
   395  0279 b019               	bcs .local5	
   396  027b 20e800             	jsr adjdumpaddr
   397  027e b014               	bcs .local5	
   398  0280 20e800             	jsr adjdumpaddr
   399  0283 b00f               	bcs .local5	
   400  0285 20e800             	jsr adjdumpaddr
   401  0288 b00a               	bcs .local5	
   402                          .lores3
   403  028a 2435               	bit monrange			;ranges on?
   404  028c 1006               	bpl .local5
   405  028e a433               	ldy rangehigh
   406  0290 c43a               	cpy mondump
   407  0292 b097               	bcs .local3
   408                          .local5
   409  0294 6435               	stz monrange
   410  0296 4c7001             	jmp moncmd
   411                          	
   412                          	!zone dumpcmd
   413                          dumpcmd
   414  0299 8536               	sta monlast
   415  029b 202f00             	jsr parse_addr
   416  029e 9021               	bcc .local3
   417  02a0 843a               	sty mondump				;if address was specified, store 16 bit y at low 16 bits of mondump address
   418  02a2 8433               	sty rangehigh
   419  02a4 2435               	bit monrange			;user asking for a range?
   420  02a6 1019               	bpl .local3
   421  02a8 202f00             	jsr parse_addr			;get the remaining half of the range
   422  02ab 8433               	sty rangehigh
   423  02ad a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   424  02af 8535               	sta monrange
   425  02b1 a433               	ldy rangehigh
   426  02b3 d003               	bne .local6
   427  02b5 4c0801             	jmp+2 monerror			;top of range can't be zero
   428                          .local6
   429  02b8 a43a               	ldy mondump
   430  02ba c433               	cpy rangehigh
   431  02bc 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   432  02be 4c0801             	jmp+2 monerror
   433                          .local3
   434  02c1 20bf00             	jsr prdumpaddr
   435  02c4 a00000             	ldy #$0000
   436                          .local2
   437  02c7 b73a               	lda [mondump],y
   438  02c9 205403             	jsr+2 prhex
   439  02cc a920               	lda #' '
   440  02ce 8f12fc1b           	sta IO_CON_CHAROUT
   441  02d2 8f13fc1b           	sta IO_CON_REGISTER
   442  02d6 c8                 	iny
   443  02d7 af20fc1b           	lda IO_VIDMODE
   444  02db c909               	cmp #$09
   445  02dd d03e               	bne .lores1
   446  02df c01000             	cpy #$0010
   447  02e2 d0e3               	bne .local2
   448  02e4 a920               	lda #' '
   449  02e6 8f12fc1b           	sta IO_CON_CHAROUT
   450  02ea 8f13fc1b           	sta IO_CON_REGISTER
   451  02ee a92d               	lda #'-'
   452  02f0 8f12fc1b           	sta IO_CON_CHAROUT
   453  02f4 8f13fc1b           	sta IO_CON_REGISTER
   454  02f8 a920               	lda #' '
   455  02fa 8f12fc1b           	sta IO_CON_CHAROUT
   456  02fe 8f13fc1b           	sta IO_CON_REGISTER
   457  0302 a00000             	ldy #$0000				;print 16 bytes as ASCII... bonus when in mode 9!
   458                          .asc2
   459  0305 b73a               	lda [mondump],y
   460  0307 c920               	cmp #$20
   461  0309 b002               	bcs .asc4
   462  030b a92e               	lda #'.'				;substitute control character with a period
   463                          .asc4
   464  030d 8f12fc1b           	sta IO_CON_CHAROUT
   465  0311 8f13fc1b           	sta IO_CON_REGISTER
   466  0315 c8                 	iny
   467  0316 c01000             	cpy #$0010
   468  0319 d0ea               	bne .asc2
   469  031b 8005               	bra .lores2
   470                          .lores1
   471  031d c00800             	cpy #$0008
   472  0320 d0a5               	bne .local2
   473                          .lores2
   474  0322 8f17fc1b           	sta IO_CON_CR
   475  0326 20e800             	jsr adjdumpaddr
   476  0329 b01a               	bcs .local5				;carry to bank, exit even if we're processing a range
   477  032b af20fc1b           	lda IO_VIDMODE
   478  032f c909               	cmp #$09
   479  0331 d005               	bne .lores3
   480  0333 20e800             	jsr adjdumpaddr
   481  0336 b00d               	bcs .local5
   482                          .lores3
   483  0338 2435               	bit monrange			;ranges on?
   484  033a 1009               	bpl .local5
   485  033c a433               	ldy rangehigh
   486  033e c43a               	cpy mondump
   487  0340 9003               	bcc .local5
   488  0342 4cc102             	jmp+2 .local3
   489                          .local5
   490  0345 6435               	stz monrange
   491  0347 4c7001             	jmp moncmd
   492                          	
   493                          prhex16
   494  034a c230               	rep #$30
   495  034c 8a                 	txa
   496  034d e220               	sep #$20
   497  034f eb                 	xba
   498  0350 205403             	jsr+2 prhex
   499  0353 eb                 	xba
   500                          prhex
   501  0354 48                 	pha
   502  0355 4a                 	lsr
   503  0356 4a                 	lsr
   504  0357 4a                 	lsr
   505  0358 4a                 	lsr
   506  0359 205f03             	jsr+2 prhexnib
   507  035c 68                 	pla
   508  035d 290f               	and #$0f
   509                          prhexnib
   510  035f 0930               	ora #$30
   511  0361 c93a               	cmp #$3a
   512  0363 9003               	bcc prhexnofix
   513  0365 18                 	clc
   514  0366 6907               	adc #$07
   515                          prhexnofix
   516  0368 8f12fc1b           	sta IO_CON_CHAROUT
   517  036c 8f13fc1b           	sta IO_CON_REGISTER
   518  0370 60                 	rts
   519                          
   520                          	!zone entercmd
   521                          .local1
   522  0371 4c0801             	jmp monerror
   523                          entercmd
   524  0374 202f00             	jsr parse_addr
   525  0377 90f8               	bcc .local1			;address is mandatory
   526  0379 2435               	bit monrange
   527  037b 30f4               	bmi .local1			;ranges not allowed
   528  037d 8430               	sty enterbytes
   529  037f a53c               	lda mondump_h
   530  0381 8532               	sta enterbytes_h	;retrieve bank from mondump
   531                          .local2
   532  0383 202f00             	jsr parse_addr		;start grabbing bytes
   533  0386 9017               	bcc .enterdone
   534  0388 2435               	bit monrange
   535  038a 30e5               	bmi .local1			;stop that happening here too
   536  038c c230               	rep #$30
   537  038e 98                 	tya
   538  038f e220               	sep #$20			;get low byte of parsed address into A
   539  0391 8730               	sta [enterbytes]
   540  0393 e630               	inc enterbytes
   541  0395 d006               	bne .local3
   542  0397 e631               	inc enterbytes_m
   543  0399 d002               	bne .local3
   544  039b e632               	inc enterbytes_h
   545                          .local3
   546  039d 80e4               	bra .local2
   547                          .enterdone
   548  039f 4c7001             	jmp moncmd
   549                          	
   550                          	!zone listcmd
   551                          listcmd
   552  03a2 202f00             	jsr parse_addr
   553  03a5 9002               	bcc .listmany				;address is optional
   554  03a7 843a               	sty mondump
   555                          .listmany
   556  03a9 af20fc1b           	lda IO_VIDMODE
   557  03ad c909               	cmp #$09
   558  03af d005               	bne .listmany1
   559  03b1 a22000             	ldx #32
   560  03b4 8003               	bra .listmany2
   561                          .listmany1
   562  03b6 a20f00             	ldx #15
   563                          .listmany2
   564  03b9 da                 	phx
   565  03ba 20c403             	jsr+2 .listsingle
   566  03bd fa                 	plx
   567  03be ca                 	dex
   568  03bf d0f8               	bne .listmany2
   569  03c1 4c7001             	jmp moncmd
   570                          .listsingle
   571  03c4 a00000             	ldy #$0000
   572  03c7 20bf00             	jsr prdumpaddr
   573  03ca a900               	lda #$00
   574  03cc eb                 	xba					;clear B
   575  03cd a73a               	lda [mondump]				;get opcode
   576  03cf c90a               	cmp #$a
   577  03d1 9003               	bcc .dunno2
   578  03d3 4c6104             	jmp .dunno
   579                          .dunno2
   580  03d6 48                 	pha					;save opcode
   581  03d7 aa                 	tax
   582  03d8 bd7e05             	lda mnemlenmode,x
   583  03db 4a                 	lsr
   584  03dc 4a                 	lsr
   585  03dd 4a                 	lsr
   586  03de 4a                 	lsr					;isolage opcode len
   587  03df 852f               	sta scratch1
   588  03e1 a73a               	lda [mondump]
   589  03e3 204305             	jsr+2 is816
   590  03e6 a52f               	lda scratch1
   591  03e8 aa                 	tax
   592  03e9 a00000             	ldy #$0000
   593                          .nextbyte
   594  03ec b73a               	lda [mondump],y
   595  03ee 205403             	jsr prhex			;print hex
   596  03f1 a920               	lda #' '
   597  03f3 8f12fc1b           	sta IO_CON_CHAROUT
   598  03f7 8f13fc1b           	sta IO_CON_REGISTER	;print space
   599  03fb c8                 	iny
   600  03fc ca                 	dex
   601  03fd d0ed               	bne .nextbyte
   602  03ff a918               	lda #$18
   603  0401 8f14fc1b           	sta IO_CON_CURSORH	;tab over
   604  0405 68                 	pla					;get opcode back
   605  0406 aa                 	tax
   606  0407 bd8805             	lda mnemlist,x
   607  040a da                 	phx					;stash our opcode
   608  040b 0a                 	asl
   609  040c 18                 	clc
   610  040d 7d8805             	adc mnemlist,x		;multiply by 3
   611  0410 aa                 	tax
   612  0411 bd9205             	lda mnems, x
   613  0414 8f12fc1b           	sta IO_CON_CHAROUT
   614  0418 8f13fc1b           	sta IO_CON_REGISTER
   615  041c e8                 	inx
   616  041d bd9205             	lda mnems, x
   617  0420 8f12fc1b           	sta IO_CON_CHAROUT
   618  0424 8f13fc1b           	sta IO_CON_REGISTER
   619  0428 e8                 	inx
   620  0429 bd9205             	lda mnems, x
   621  042c 8f12fc1b           	sta IO_CON_CHAROUT
   622  0430 8f13fc1b           	sta IO_CON_REGISTER
   623  0434 a920               	lda #' '
   624  0436 8f12fc1b           	sta IO_CON_CHAROUT
   625  043a 8f13fc1b           	sta IO_CON_REGISTER
   626  043e fa                 	plx					;get our opcode back in index
   627  043f bd7e05             	lda mnemlenmode,x
   628  0442 290f               	and #$0f			;isolate the addressing mode
   629  0444 0a                 	asl					;multiply by two
   630  0445 aa                 	tax
   631  0446 fc7205             	jsr (listamod,x)
   632  0449 8f17fc1b           	sta IO_CON_CR
   633                          .fixup
   634  044d a52f               	lda scratch1		;get our fixup
   635  044f 18                 	clc
   636  0450 653a               	adc mondump
   637  0452 853a               	sta mondump
   638  0454 a53b               	lda mondump_m
   639  0456 6900               	adc #$00
   640  0458 853b               	sta mondump_m
   641  045a a53c               	lda mondump_h
   642  045c 6900               	adc #$00
   643  045e 853c               	sta mondump_h
   644                          .goback
   645  0460 60                 	rts
   646                          .dunno
   647  0461 205403             	jsr prhex
   648  0464 a918               	lda #$18
   649  0466 8f14fc1b           	sta IO_CON_CURSORH
   650  046a a901               	lda #$01
   651  046c 852f               	sta scratch1		;fix up one byte
   652  046e a93f               	lda #'?'
   653  0470 8f12fc1b           	sta IO_CON_CHAROUT
   654  0474 8f13fc1b           	sta IO_CON_REGISTER
   655  0478 8f13fc1b           	sta IO_CON_REGISTER
   656  047c 8f13fc1b           	sta IO_CON_REGISTER
   657  0480 8f17fc1b           	sta IO_CON_CR
   658  0484 80c7               	bra .fixup
   659                          
   660                          amod0
   661  0486 a924               	lda #'$'
   662  0488 8f12fc1b           	sta IO_CON_CHAROUT
   663  048c 8f13fc1b           	sta IO_CON_REGISTER
   664  0490 a00100             	ldy #$0001
   665  0493 b73a               	lda [mondump],y
   666  0495 205403             	jsr prhex
   667  0498 60                 	rts
   668                          amod1
   669  0499 a928               	lda #'('
   670  049b 8f12fc1b           	sta IO_CON_CHAROUT
   671  049f 8f13fc1b           	sta IO_CON_REGISTER
   672  04a3 a924               	lda #'$'
   673  04a5 8f12fc1b           	sta IO_CON_CHAROUT
   674  04a9 8f13fc1b           	sta IO_CON_REGISTER
   675  04ad a00100             	ldy #$0001
   676  04b0 b73a               	lda [mondump],y
   677  04b2 205403             	jsr prhex
   678  04b5 a92c               	lda #','
   679  04b7 8f12fc1b           	sta IO_CON_CHAROUT
   680  04bb 8f13fc1b           	sta IO_CON_REGISTER
   681  04bf a958               	lda #'X'
   682  04c1 8f12fc1b           	sta IO_CON_CHAROUT
   683  04c5 8f13fc1b           	sta IO_CON_REGISTER
   684  04c9 a929               	lda #')'
   685  04cb 8f12fc1b           	sta IO_CON_CHAROUT
   686  04cf 8f13fc1b           	sta IO_CON_REGISTER
   687  04d3 60                 	rts
   688                          amod2
   689  04d4 a00100             	ldy #$0001
   690  04d7 b73a               	lda [mondump],y
   691  04d9 205403             	jsr prhex
   692  04dc a92c               	lda #','
   693  04de 8f12fc1b           	sta IO_CON_CHAROUT
   694  04e2 8f13fc1b           	sta IO_CON_REGISTER
   695  04e6 a953               	lda #'S'
   696  04e8 8f12fc1b           	sta IO_CON_CHAROUT
   697  04ec 8f13fc1b           	sta IO_CON_REGISTER
   698  04f0 60                 	rts
   699                          amod3
   700  04f1 a95b               	lda #'['
   701  04f3 8f12fc1b           	sta IO_CON_CHAROUT
   702  04f7 8f13fc1b           	sta IO_CON_REGISTER
   703  04fb a924               	lda #'$'
   704  04fd 8f12fc1b           	sta IO_CON_CHAROUT
   705  0501 8f13fc1b           	sta IO_CON_REGISTER
   706  0505 a00100             	ldy #$0001
   707  0508 b73a               	lda [mondump],y
   708  050a 205403             	jsr prhex
   709  050d a95d               	lda #']'
   710  050f 8f12fc1b           	sta IO_CON_CHAROUT
   711  0513 8f13fc1b           	sta IO_CON_REGISTER
   712                          amod4
   713  0517 60                 	rts
   714                          	!zone amod5
   715                          amod5
   716  0518 a923               	lda #'#'
   717  051a 8f12fc1b           	sta IO_CON_CHAROUT
   718  051e 8f13fc1b           	sta IO_CON_REGISTER
   719  0522 a924               	lda #'$'
   720  0524 8f12fc1b           	sta IO_CON_CHAROUT
   721  0528 8f13fc1b           	sta IO_CON_REGISTER
   722  052c a52f               	lda scratch1
   723  052e c902               	cmp #$02
   724  0530 f008               	beq .amod508
   725                          .amod516
   726  0532 a00200             	ldy #$0002
   727  0535 b73a               	lda [mondump],y
   728  0537 205403             	jsr prhex
   729                          .amod508
   730  053a a00100             	ldy #$0001
   731  053d b73a               	lda [mondump],y
   732  053f 205403             	jsr prhex
   733  0542 60                 	rts
   734                          	
   735                          	!zone is816
   736                          is816
   737  0543 48                 	pha
   738  0544 291f               	and #$1f
   739  0546 c909               	cmp #$09				;09, 29, 49, etc?
   740  0548 d006               	bne .testx
   741  054a 242d               	bit alarge				;16 bit?
   742  054c 301e               	bmi .is16
   743  054e 1016               	bpl .is8
   744                          .testx
   745  0550 c9a0               	cmp #$a0
   746  0552 f00e               	beq .isx
   747  0554 c9a2               	cmp #$a2
   748  0556 f00a               	beq .isx
   749  0558 c9c0               	cmp #$c0
   750  055a f006               	beq .isx
   751  055c c9e0               	cmp #$e0
   752  055e f002               	beq .isx
   753  0560 68                 	pla						;made it here, not an accumulator or index instruction
   754  0561 60                 	rts
   755                          .isx
   756  0562 242e               	bit xlarge
   757  0564 3006               	bmi .is16				;or else fall thru
   758                          .is8
   759  0566 a902               	lda #$2
   760  0568 852f               	sta scratch1
   761  056a 68                 	pla
   762  056b 60                 	rts
   763                          .is16
   764  056c a903               	lda #$3
   765  056e 852f               	sta scratch1
   766  0570 68                 	pla
   767  0571 60                 	rts
   768                          	
   769                          listamod
   770  0572 8604               	!16 amod0
   771  0574 9904               	!16 amod1
   772  0576 d404               	!16 amod2
   773  0578 f104               	!16 amod3
   774  057a 1705               	!16 amod4
   775  057c 1805               	!16 amod5
   776                          	
   777                          mnemlenmode
   778  057e 20                 	!byte %00100000		;00 brk 2/$xx
   779  057f 21                 	!byte %00100001		;01 ora 2/($xx,x)
   780  0580 20                 	!byte %00100000		;02 cop 2/$xx
   781  0581 22                 	!byte %00100010		;03 ora 2/x,s
   782  0582 20                 	!byte %00100000		;04 tsb 2/$xx
   783  0583 20                 	!byte %00100000		;05 ora 2/$xx
   784  0584 20                 	!byte %00100000		;06 asl 2/$xx
   785  0585 23                 	!byte %00100011		;07 ora 2/[$xx]
   786  0586 14                 	!byte %00010100		;08 php 1
   787  0587 25                 	!byte %00100101		;09 ora 2/#imm
   788                          mnemlist
   789  0588 00                 	!byte $00			;00 brk
   790  0589 02                 	!byte $02			;01 ora
   791  058a 01                 	!byte $01			;02 cop
   792  058b 02                 	!byte $02			;03 ora
   793  058c 03                 	!byte $03			;04 tsb
   794  058d 02                 	!BYTE $02			;05 ora
   795  058e 04                 	!byte $04			;06 asl
   796  058f 02                 	!byte $02			;07 ora
   797  0590 05                 	!byte $05			;08 php
   798  0591 02                 	!byte $02			;09 ora
   799                          mnems
   800  0592 42524b             	!tx "BRK"
   801  0595 434f50             	!tx "COP"
   802  0598 4f5241             	!tx "ORA"
   803  059b 545342             	!tx "TSB"
   804  059e 41534c             	!tx "ASL"
   805  05a1 504850             	!tx "PHP"
   806  05a4 504844             	!tx "PHD"
   807                          	
   808                          	!zone ucline
   809                          ucline					;convert inbuff at $170400 to upper case
   810  05a7 08                 	php
   811  05a8 c210               	rep #$10
   812  05aa e220               	sep #$20
   813                          	!as
   814                          	!rl
   815  05ac a20000             	ldx #$0000
   816                          .local2
   817  05af bf000417           	lda inbuff,x
   818  05b3 f012               	beq .local4			;hit the zero, so bail
   819  05b5 c961               	cmp #'a'
   820  05b7 900b               	bcc .local3			;less then lowercase a, so ignore
   821  05b9 c97b               	cmp #'z' + 1		;less than next character after lowercase z?
   822  05bb b007               	bcs .local3			;greater than or equal, so ignore
   823  05bd 38                 	sec
   824  05be e920               	sbc #('z' - 'Z')	;make upper case
   825  05c0 9f000417           	sta inbuff,x
   826                          .local3
   827  05c4 e8                 	inx
   828  05c5 80e8               	bra .local2
   829                          .local4
   830  05c7 28                 	plp
   831  05c8 6b                 	rtl
   832                          	
   833                          	!zone getline
   834                          getline
   835  05c9 08                 	php
   836  05ca c210               	rep #$10
   837  05cc e220               	sep #$20
   838                          	!as
   839                          	!rl
   840  05ce a20000             	ldx #$0000
   841                          .local2
   842  05d1 af00fc1b           	lda IO_KEYQ_SIZE
   843  05d5 f0fa               	beq .local2
   844  05d7 af01fc1b           	lda IO_KEYQ_WAITING
   845  05db 8f02fc1b           	sta IO_KEYQ_DEQUEUE
   846  05df c90d               	cmp #$0d			;carriage return yet?
   847  05e1 f01c               	beq .local3
   848  05e3 c908               	cmp #$08			;backspace/back arrow?
   849  05e5 f029               	beq .local4
   850  05e7 c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
   851  05e9 90e6               	bcc .local2		 		;yes, so ignore it
   852  05eb 9f000417           	sta inbuff,x 		;any other character, so register it and store it
   853  05ef 8f12fc1b           	sta IO_CON_CHAROUT
   854  05f3 8f13fc1b           	sta IO_CON_REGISTER
   855  05f7 e8                 	inx
   856  05f8 a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
   857  05fa e0fe03             	cpx #$3fe			;overrun end of buffer yet?
   858  05fd d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
   859                          .local3
   860  05ff 9f000417           	sta inbuff,x		;store CR
   861  0603 8f17fc1b           	sta IO_CON_CR
   862  0607 e8                 	inx
   863  0608 a900               	lda #$00			;store zero to end it all
   864  060a 9f000417           	sta inbuff,x
   865  060e 28                 	plp
   866  060f 6b                 	rtl
   867                          .local4
   868  0610 e00000             	cpx #$0000
   869  0613 f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
   870  0615 a908               	lda #$08
   871  0617 8f12fc1b           	sta IO_CON_CHAROUT
   872  061b 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
   873  061f a920               	lda #$20
   874  0621 8f12fc1b           	sta IO_CON_CHAROUT
   875  0625 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
   876  0629 a908               	lda #$08
   877  062b 8f12fc1b           	sta IO_CON_CHAROUT
   878  062f 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
   879  0633 ca                 	dex
   880  0634 809b               	bra .local2
   881                          	
   882                          prinbuff				;feed location of input buffer into dpla and then print
   883  0636 08                 	php
   884  0637 c210               	rep #$10
   885  0639 e220               	sep #$20
   886                          	!as
   887                          	!rl
   888  063b a917               	lda #$17
   889  063d 853f               	sta dpla_h
   890  063f a904               	lda #$04
   891  0641 853e               	sta dpla_m
   892  0643 643d               	stz dpla
   893  0645 224b061c           	jsl l_prcdpla
   894  0649 28                 	plp
   895  064a 6b                 	rtl
   896                          	
   897                          	!zone prcdpla
   898                          prcdpla					; print C string pointed to by dp locations $3d-$3f
   899  064b 08                 	php
   900  064c c210               	rep #$10
   901  064e e220               	sep #$20
   902                          	!as
   903                          	!rl
   904  0650 a00000             	ldy #$0000
   905                          .local2
   906  0653 b73d               	lda [dpla],y
   907  0655 f00b               	beq .local3
   908  0657 8f12fc1b           	sta IO_CON_CHAROUT
   909  065b 8f13fc1b           	sta IO_CON_REGISTER
   910  065f c8                 	iny
   911  0660 80f1               	bra .local2
   912                          .local3
   913  0662 28                 	plp
   914  0663 6b                 	rtl
   915                          
   916                          initstring
   917  0664 494d4c2036353831...	!tx "IML 65816 1C Firmware v00"
   918  067d 0d                 	!byte 0x0d
   919  067e 53797374656d204d...	!tx "System Monitor"
   920  068c 0d                 	!byte 0x0d
   921  068d 0d                 	!byte 0x0d
   922  068e 00                 	!byte 0
   923                          
   924                          helpmsg
   925  068f 494d4c2036353831...	!tx "IML 65816 Monitor Commands"
   926  06a9 0d                 	!byte $0d
   927  06aa 41203c616464723e...	!tx "A <addr>  Dump ASCII"
   928  06be 0d                 	!byte $0d
   929  06bf 42203c62616e6b3e...	!tx "B <bank>  Change bank"
   930  06d4 0d                 	!byte $0d
   931  06d5 43203c636f6c6f72...	!tx "C <color> Change terminal colors"
   932  06f5 0d                 	!byte $0d
   933  06f6 44203c616464723e...	!tx "D <addr>  Dump hex"
   934  0708 0d                 	!byte $0d
   935  0709 45203c616464723e...	!tx "E <addr> <byte> <byte>...  Enter bytes"
   936  072f 0d                 	!byte $0d
   937  0730 4c203c616464723e...	!tx "L <addr>  Disassemble 65816 Instructions"
   938  0758 0d                 	!byte $0d
   939  0759 4d203c6d6f64653e...	!tx "M <mode>  Change video mode, 8/9"
   940  0779 0d                 	!byte $0d
   941  077a 5120202020202020...	!tx "Q         Halt the processor"
   942  0796 0d                 	!byte $0d
   943  0797 3f20202020202020...	!tx "?         This menu"
   944  07aa 0d                 	!byte $0d
   945  07ab 3c656e7465723e20...	!tx "<enter>   Repeat last dump command"
   946  07cd 0d                 	!byte $0d
   947  07ce 546f207370656369...	!tx "To specify range, use <addr1.addr2>"
   948  07f1 0d00               	!byte $0d, 00
   949                          	
   950  07f3 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
   951                          
