
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
    29                          scratch2 = $2a
    30                          scratch2_m = $2b
    31                          scratch2_h = $2c
    32                          alarge = $2d
    33                          xlarge = $2e
    34                          scratch1 = $2f
    35                          enterbytes = $30
    36                          enterbytes_m = $31
    37                          enterbytes_h = $32
    38                          rangehigh = $33
    39                          monrange = $35
    40                          monlast = $36
    41                          parseptr = $37
    42                          parseptr_m = $38
    43                          parseptr_h = $39
    44                          mondump = $3a
    45                          mondump_m = $3b
    46                          mondump_h = $3c
    47                          dpla = $3d
    48                          dpla_m = $3e
    49                          dpla_h = $3f
    50                          
    51                          inbuff = $170400
    52                          
    53                          x1crominit
    54  0000 4b                 	phk
    55  0001 ab                 	plb
    56  0002 c210               	rep #$10
    57                          	!rl
    58  0004 e220               	sep #$20
    59                          	!as
    60  0006 a2770a             	ldx #initstring
    61  0009 863d               	stx dpla
    62  000b a91c               	lda #$1c
    63  000d 853f               	sta dpla_h
    64  000f 225e0a1c           	jsl l_prcdpla
    65  0013 4c5d01             	jmp+2 monstart
    66                          
    67                          parse_setup
    68  0016 a20004             	ldx #$0400
    69  0019 8637               	stx parseptr
    70  001b a917               	lda #$17
    71  001d 8539               	sta parseptr_h
    72  001f 60                 	rts
    73                          	
    74                          	!zone parse_getchar
    75                          parse_getchar			;get char from inbuff, assumes 8 bit A, 16 bit X
    76  0020 a737               	lda [parseptr]
    77  0022 48                 	pha
    78  0023 e637               	inc parseptr
    79  0025 d006               	bne .local2
    80  0027 e638               	inc parseptr_m
    81  0029 d002               	bne .local2
    82  002b e639               	inc parseptr_h
    83                          .local2
    84  002d 68                 	pla
    85  002e 60                 	rts
    86                          	
    87                          	!zone parse_addr
    88                          parse_addr				;see if user specified an address on line.
    89  002f a900               	lda #$00
    90  0031 48                 	pha
    91  0032 48                 	pha					;make space for working value on the stack
    92  0033 8535               	sta monrange		;clear range flag
    93                          .throwaway
    94  0035 202000             	jsr+2 parse_getchar
    95  0038 c920               	cmp #' '
    96  003a f0f9               	beq .throwaway		;throw away leading spaces
    97  003c 209800             	jsr+2 parse_getnib2	;get first nibble. call 2nd entry point since we already have character
    98  003f 9051               	bcc .no				;didn't even get one hex character, so return false
    99  0041 8301               	sta 1,s				;save it on the stack for now
   100  0043 209500             	jsr+2 parse_getnib	;get second nibble
   101  0046 9047               	bcc .yes			;if not hex then bail
   102  0048 48                 	pha
   103  0049 a302               	lda 2,s
   104  004b 0a                 	asl
   105  004c 0a                 	asl
   106  004d 0a                 	asl
   107  004e 0a                 	asl
   108  004f 0301               	ora 1,s
   109  0051 8302               	sta 2,s
   110  0053 68                 	pla					;add to stack
   111  0054 209500             	jsr+2 parse_getnib	;get possible third nibble
   112  0057 9036               	bcc .yes
   113  0059 c230               	rep #$30			;we're dealing with a 16 bit value now
   114                          	!al
   115  005b 290f00             	and #$000f
   116  005e 48                 	pha
   117  005f a303               	lda 3,s
   118  0061 0a                 	asl
   119  0062 0a                 	asl
   120  0063 0a                 	asl
   121  0064 0a                 	asl
   122  0065 0301               	ora 1,s
   123  0067 8303               	sta 3,s
   124  0069 68                 	pla
   125  006a e220               	sep #$20
   126                          	!as
   127  006c 209500             	jsr+2 parse_getnib
   128  006f 901e               	bcc .yes
   129  0071 c230               	rep #$30
   130                          	!al
   131  0073 290f00             	and #$000f
   132  0076 48                 	pha
   133  0077 a303               	lda 3,s
   134  0079 0a                 	asl
   135  007a 0a                 	asl
   136  007b 0a                 	asl
   137  007c 0a                 	asl
   138  007d 0301               	ora 1,s
   139  007f 8303               	sta 3,s
   140  0081 68                 	pla
   141  0082 e220               	sep #$20			;fall thru to yes on 4th nibble
   142                          	!as
   143  0084 202000             	jsr parse_getchar	;check to see if next char is a . so we can specify ranges
   144  0087 c92e               	cmp #'.'
   145  0089 d004               	bne .yes
   146  008b a980               	lda #$80
   147  008d 8535               	sta monrange
   148                          .yes
   149  008f 7a                 	ply					;get 16 bit work address off of stack
   150  0090 38                 	sec					;got address, return
   151  0091 60                 	rts
   152                          .no
   153  0092 7a                 	ply					;clear stack
   154  0093 18                 	clc					;no address found, return
   155  0094 60                 	rts
   156                          parse_getnib
   157  0095 202000             	jsr parse_getchar
   158                          parse_getnib2			;enter here after we've thrown away leading spaces
   159  0098 c920               	cmp #' '
   160  009a f021               	beq .outrng			;space = end of value
   161  009c c92e               	cmp #'.'
   162  009e d006               	bne .notrange
   163  00a0 a980               	lda #$80
   164  00a2 8535               	sta monrange		;this is the start of a range specification
   165  00a4 18                 	clc
   166  00a5 60                 	rts
   167                          .notrange
   168  00a6 c941               	cmp #$41
   169  00a8 900b               	bcc .outrnga
   170  00aa c947               	cmp #$47
   171  00ac b007               	bcs .outrnga
   172  00ae 38                 	sec
   173  00af e907               	sbc #$07			;in range of A-F
   174                          .success
   175  00b1 290f               	and #$0f
   176  00b3 38                 	sec
   177  00b4 60                 	rts
   178                          .outrnga				;test if 0-9
   179  00b5 c930               	cmp #$30
   180  00b7 9004               	bcc .outrng
   181  00b9 c93a               	cmp #$3a
   182  00bb 90f4               	bcc .success		;less than 3a, but >= 30, else fall thru to outrng
   183                          .outrng
   184  00bd 18                 	clc
   185  00be 60                 	rts
   186                          	
   187                          prdumpaddr
   188  00bf a53c               	lda mondump_h			;print long address
   189  00c1 205403             	jsr+2 prhex
   190  00c4 a92f               	lda #'/'
   191  00c6 8f12fc1b           	sta IO_CON_CHAROUT
   192  00ca 8f13fc1b           	sta IO_CON_REGISTER
   193  00ce a63a               	ldx mondump
   194  00d0 204a03             	jsr+2 prhex16
   195  00d3 a92d               	lda #'-'
   196  00d5 8f12fc1b           	sta IO_CON_CHAROUT
   197  00d9 8f13fc1b           	sta IO_CON_REGISTER
   198  00dd a920               	lda #' '
   199  00df 8f12fc1b           	sta IO_CON_CHAROUT
   200  00e3 8f13fc1b           	sta IO_CON_REGISTER
   201  00e7 60                 	rts
   202                          	
   203                          adjdumpaddr					;add 8 to dump address
   204  00e8 c230               	rep #$30
   205                          	!al
   206  00ea a53a               	lda mondump
   207  00ec 18                 	clc
   208  00ed 690800             	adc #$0008
   209  00f0 853a               	sta mondump
   210  00f2 e220               	sep #$20
   211                          	!as
   212  00f4 08                 	php						;save carry state.. did we carry to the bank?
   213  00f5 a53c               	lda mondump_h
   214  00f7 6900               	adc #$00
   215  00f9 853c               	sta mondump_h
   216  00fb 28                 	plp
   217  00fc 60                 	rts
   218                          	
   219                          bankcmd
   220  00fd 202f00             	jsr parse_addr
   221  0100 9006               	bcc monerror
   222  0102 98                 	tya
   223  0103 853c               	sta mondump_h
   224  0105 4c7001             	jmp moncmd
   225                          monerror
   226  0108 a21801             	ldx #monsynerr
   227  010b 863d               	stx dpla
   228  010d a91c               	lda #$1c
   229  010f 853f               	sta dpla_h
   230  0111 225e0a1c           	jsl l_prcdpla
   231  0115 4c7001             	jmp moncmd
   232                          monsynerr
   233  0118 53796e7461782065...	!tx "Syntax error!"
   234  0125 0d00               	!byte $0d, $00
   235                          
   236                          colorcmd
   237  0127 202f00             	jsr parse_addr
   238  012a 90dc               	bcc monerror
   239  012c 98                 	tya
   240  012d 8f11fc1b           	sta IO_CON_COLOR
   241  0131 4c7001             	jmp moncmd
   242                          	
   243                          modecmd
   244  0134 202f00             	jsr parse_addr
   245  0137 90cf               	bcc monerror
   246  0139 98                 	tya
   247  013a c908               	cmp #$08
   248  013c 90ca               	bcc monerror
   249  013e c90a               	cmp #$0a
   250  0140 b0c6               	bcs monerror
   251  0142 8f20fc1b           	sta IO_VIDMODE
   252  0146 a900               	lda #$00
   253  0148 8f14fc1b           	sta IO_CON_CURSORH
   254  014c 8f15fc1b           	sta IO_CON_CURSORV
   255  0150 a920               	lda #$20
   256  0152 8f12fc1b           	sta IO_CON_CHAROUT
   257  0156 8f10fc1b           	sta IO_CON_CLS
   258  015a 4c7001             	jmp moncmd
   259                          	
   260                          monstart				;main entry point for system monitor
   261  015d 4b                 	phk
   262  015e ab                 	plb
   263  015f c210               	rep #$10
   264                          	!rl
   265  0161 e220               	sep #$20
   266                          	!as
   267  0163 a20000             	ldx #$0000
   268  0166 863a               	stx mondump
   269  0168 a91c               	lda #$1c
   270  016a 853c               	sta mondump_h
   271  016c a944               	lda #'D'
   272  016e 8536               	sta monlast
   273                          	
   274                          	!zone moncmd
   275                          moncmd
   276  0170 a93e               	lda #promptchar
   277  0172 8f12fc1b           	sta IO_CON_CHAROUT
   278  0176 8f13fc1b           	sta IO_CON_REGISTER
   279  017a 22dc091c           	jsl l_getline
   280  017e 22ba091c           	jsl l_ucline
   281  0182 201600             	jsr parse_setup
   282  0185 202000             	jsr parse_getchar
   283                          .local3
   284  0188 c951               	cmp #'Q'
   285  018a f051               	beq haltcmd
   286  018c c944               	cmp #'D'
   287  018e d003               	bne .local4
   288  0190 4c9902             	jmp+2 dumpcmd
   289                          .local4
   290  0193 c90d               	cmp #$0d
   291  0195 d008               	bne .local2
   292  0197 a536               	lda monlast			;recall previously executed command
   293  0199 c920               	cmp #$20			;make sure it isn't a control character
   294  019b b0eb               	bcs .local3			;and retry it
   295  019d 80d1               	bra moncmd			;else recycle and try a new command
   296                          .local2
   297  019f c941               	cmp #'A'
   298  01a1 f060               	beq asciidumpcmd
   299  01a3 c942               	cmp #'B'
   300  01a5 d003               	bne .local5
   301  01a7 4cfd00             	jmp+2 bankcmd
   302                          .local5
   303  01aa c943               	cmp #'C'
   304  01ac d003               	bne .local6
   305  01ae 4c2701             	jmp+2 colorcmd
   306                          .local6
   307  01b1 c94d               	cmp #'M'
   308  01b3 d003               	bne .local7
   309  01b5 4c3401             	jmp+2 modecmd
   310                          .local7
   311  01b8 c945               	cmp #'E'
   312  01ba d003               	bne .local8
   313  01bc 4c7403             	jmp+2 entercmd
   314                          .local8
   315  01bf c94c               	cmp #'L'
   316  01c1 d003               	bne .local9
   317  01c3 4ca203             	jmp+2 listcmd
   318                          .local9
   319  01c6 c93f               	cmp #'?'
   320  01c8 f003               	beq helpcmd
   321  01ca 4c7001             	jmp moncmd
   322                          	
   323                          helpcmd
   324  01cd a2a20a             	ldx #helpmsg
   325  01d0 863d               	stx dpla
   326  01d2 a91c               	lda #$1c
   327  01d4 853f               	sta dpla_h
   328  01d6 225e0a1c           	jsl l_prcdpla
   329  01da 4c7001             	jmp moncmd
   330                          	
   331                          haltcmd
   332  01dd a2eb01             	ldx #haltmsg
   333  01e0 863d               	stx dpla
   334  01e2 a91c               	lda #$1c
   335  01e4 853f               	sta dpla_h
   336  01e6 225e0a1c           	jsl l_prcdpla
   337  01ea db                 	stp
   338                          haltmsg
   339  01eb 48616c74696e6720...	!tx "Halting 65816 engine.."
   340  0201 0d00               	!byte $0d,$00
   341                          	
   342                          	!zone asciidumpcmd
   343                          asciidumpcmd
   344  0203 8536               	sta monlast
   345  0205 202f00             	jsr parse_addr
   346  0208 9021               	bcc .local3
   347  020a 843a               	sty mondump
   348  020c 8433               	sty rangehigh
   349  020e 2435               	bit monrange			;user asking for a range?
   350  0210 1019               	bpl .local3
   351  0212 202f00             	jsr parse_addr			;get the remaining half of the range
   352  0215 8433               	sty rangehigh
   353  0217 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   354  0219 8535               	sta monrange
   355  021b a433               	ldy rangehigh
   356  021d d003               	bne .local6
   357  021f 4c0801             	jmp+2 monerror			;top of range can't be zero
   358                          .local6
   359  0222 a43a               	ldy mondump
   360  0224 c433               	cpy rangehigh
   361  0226 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   362  0228 4c0801             	jmp+2 monerror
   363                          .local3
   364  022b 20bf00             	jsr prdumpaddr
   365  022e a00000             	ldy #$0000
   366                          .local2
   367  0231 b73a               	lda [mondump],y
   368  0233 c920               	cmp #$20
   369  0235 b002               	bcs .local4
   370  0237 a92e               	lda #'.'				;substitute control character with a period
   371                          .local4
   372  0239 8f12fc1b           	sta IO_CON_CHAROUT
   373  023d 8f13fc1b           	sta IO_CON_REGISTER
   374  0241 c8                 	iny
   375  0242 af20fc1b           	lda IO_VIDMODE
   376  0246 c909               	cmp #$09
   377  0248 d007               	bne .lores1
   378  024a c04000             	cpy #$0040
   379  024d d0e2               	bne .local2
   380  024f 8005               	bra .lores2
   381                          .lores1
   382  0251 c01000             	cpy #$0010
   383  0254 d0db               	bne .local2
   384                          .lores2
   385  0256 8f17fc1b           	sta IO_CON_CR
   386  025a 20e800             	jsr adjdumpaddr
   387  025d b035               	bcs .local5				;carry to bank, exit even if we're processing a range
   388  025f 20e800             	jsr adjdumpaddr
   389  0262 b030               	bcs .local5	
   390  0264 af20fc1b           	lda IO_VIDMODE
   391  0268 c909               	cmp #$09
   392  026a d01e               	bne .lores3
   393  026c 20e800             	jsr adjdumpaddr
   394  026f b023               	bcs .local5	
   395  0271 20e800             	jsr adjdumpaddr
   396  0274 b01e               	bcs .local5	
   397  0276 20e800             	jsr adjdumpaddr
   398  0279 b019               	bcs .local5	
   399  027b 20e800             	jsr adjdumpaddr
   400  027e b014               	bcs .local5	
   401  0280 20e800             	jsr adjdumpaddr
   402  0283 b00f               	bcs .local5	
   403  0285 20e800             	jsr adjdumpaddr
   404  0288 b00a               	bcs .local5	
   405                          .lores3
   406  028a 2435               	bit monrange			;ranges on?
   407  028c 1006               	bpl .local5
   408  028e a433               	ldy rangehigh
   409  0290 c43a               	cpy mondump
   410  0292 b097               	bcs .local3
   411                          .local5
   412  0294 6435               	stz monrange
   413  0296 4c7001             	jmp moncmd
   414                          	
   415                          	!zone dumpcmd
   416                          dumpcmd
   417  0299 8536               	sta monlast
   418  029b 202f00             	jsr parse_addr
   419  029e 9021               	bcc .local3
   420  02a0 843a               	sty mondump				;if address was specified, store 16 bit y at low 16 bits of mondump address
   421  02a2 8433               	sty rangehigh
   422  02a4 2435               	bit monrange			;user asking for a range?
   423  02a6 1019               	bpl .local3
   424  02a8 202f00             	jsr parse_addr			;get the remaining half of the range
   425  02ab 8433               	sty rangehigh
   426  02ad a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   427  02af 8535               	sta monrange
   428  02b1 a433               	ldy rangehigh
   429  02b3 d003               	bne .local6
   430  02b5 4c0801             	jmp+2 monerror			;top of range can't be zero
   431                          .local6
   432  02b8 a43a               	ldy mondump
   433  02ba c433               	cpy rangehigh
   434  02bc 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   435  02be 4c0801             	jmp+2 monerror
   436                          .local3
   437  02c1 20bf00             	jsr prdumpaddr
   438  02c4 a00000             	ldy #$0000
   439                          .local2
   440  02c7 b73a               	lda [mondump],y
   441  02c9 205403             	jsr+2 prhex
   442  02cc a920               	lda #' '
   443  02ce 8f12fc1b           	sta IO_CON_CHAROUT
   444  02d2 8f13fc1b           	sta IO_CON_REGISTER
   445  02d6 c8                 	iny
   446  02d7 af20fc1b           	lda IO_VIDMODE
   447  02db c909               	cmp #$09
   448  02dd d03e               	bne .lores1
   449  02df c01000             	cpy #$0010
   450  02e2 d0e3               	bne .local2
   451  02e4 a920               	lda #' '
   452  02e6 8f12fc1b           	sta IO_CON_CHAROUT
   453  02ea 8f13fc1b           	sta IO_CON_REGISTER
   454  02ee a92d               	lda #'-'
   455  02f0 8f12fc1b           	sta IO_CON_CHAROUT
   456  02f4 8f13fc1b           	sta IO_CON_REGISTER
   457  02f8 a920               	lda #' '
   458  02fa 8f12fc1b           	sta IO_CON_CHAROUT
   459  02fe 8f13fc1b           	sta IO_CON_REGISTER
   460  0302 a00000             	ldy #$0000				;print 16 bytes as ASCII... bonus when in mode 9!
   461                          .asc2
   462  0305 b73a               	lda [mondump],y
   463  0307 c920               	cmp #$20
   464  0309 b002               	bcs .asc4
   465  030b a92e               	lda #'.'				;substitute control character with a period
   466                          .asc4
   467  030d 8f12fc1b           	sta IO_CON_CHAROUT
   468  0311 8f13fc1b           	sta IO_CON_REGISTER
   469  0315 c8                 	iny
   470  0316 c01000             	cpy #$0010
   471  0319 d0ea               	bne .asc2
   472  031b 8005               	bra .lores2
   473                          .lores1
   474  031d c00800             	cpy #$0008
   475  0320 d0a5               	bne .local2
   476                          .lores2
   477  0322 8f17fc1b           	sta IO_CON_CR
   478  0326 20e800             	jsr adjdumpaddr
   479  0329 b01a               	bcs .local5				;carry to bank, exit even if we're processing a range
   480  032b af20fc1b           	lda IO_VIDMODE
   481  032f c909               	cmp #$09
   482  0331 d005               	bne .lores3
   483  0333 20e800             	jsr adjdumpaddr
   484  0336 b00d               	bcs .local5
   485                          .lores3
   486  0338 2435               	bit monrange			;ranges on?
   487  033a 1009               	bpl .local5
   488  033c a433               	ldy rangehigh
   489  033e c43a               	cpy mondump
   490  0340 9003               	bcc .local5
   491  0342 4cc102             	jmp+2 .local3
   492                          .local5
   493  0345 6435               	stz monrange
   494  0347 4c7001             	jmp moncmd
   495                          	
   496                          prhex16
   497  034a c230               	rep #$30
   498  034c 8a                 	txa
   499  034d e220               	sep #$20
   500  034f eb                 	xba
   501  0350 205403             	jsr+2 prhex
   502  0353 eb                 	xba
   503                          prhex
   504  0354 48                 	pha
   505  0355 4a                 	lsr
   506  0356 4a                 	lsr
   507  0357 4a                 	lsr
   508  0358 4a                 	lsr
   509  0359 205f03             	jsr+2 prhexnib
   510  035c 68                 	pla
   511  035d 290f               	and #$0f
   512                          prhexnib
   513  035f 0930               	ora #$30
   514  0361 c93a               	cmp #$3a
   515  0363 9003               	bcc prhexnofix
   516  0365 18                 	clc
   517  0366 6907               	adc #$07
   518                          prhexnofix
   519  0368 8f12fc1b           	sta IO_CON_CHAROUT
   520  036c 8f13fc1b           	sta IO_CON_REGISTER
   521  0370 60                 	rts
   522                          
   523                          	!zone entercmd
   524                          .local1
   525  0371 4c0801             	jmp monerror
   526                          entercmd
   527  0374 202f00             	jsr parse_addr
   528  0377 90f8               	bcc .local1			;address is mandatory
   529  0379 2435               	bit monrange
   530  037b 30f4               	bmi .local1			;ranges not allowed
   531  037d 8430               	sty enterbytes
   532  037f a53c               	lda mondump_h
   533  0381 8532               	sta enterbytes_h	;retrieve bank from mondump
   534                          .local2
   535  0383 202f00             	jsr parse_addr		;start grabbing bytes
   536  0386 9017               	bcc .enterdone
   537  0388 2435               	bit monrange
   538  038a 30e5               	bmi .local1			;stop that happening here too
   539  038c c230               	rep #$30
   540  038e 98                 	tya
   541  038f e220               	sep #$20			;get low byte of parsed address into A
   542  0391 8730               	sta [enterbytes]
   543  0393 e630               	inc enterbytes
   544  0395 d006               	bne .local3
   545  0397 e631               	inc enterbytes_m
   546  0399 d002               	bne .local3
   547  039b e632               	inc enterbytes_h
   548                          .local3
   549  039d 80e4               	bra .local2
   550                          .enterdone
   551  039f 4c7001             	jmp moncmd
   552                          	
   553                          	!zone listcmd
   554                          listcmd
   555  03a2 202f00             	jsr parse_addr
   556  03a5 9002               	bcc .listmany				;address is optional
   557  03a7 843a               	sty mondump
   558                          .listmany
   559  03a9 af20fc1b           	lda IO_VIDMODE
   560  03ad c909               	cmp #$09
   561  03af d005               	bne .listmany1
   562  03b1 a22000             	ldx #32
   563  03b4 8003               	bra .listmany2
   564                          .listmany1
   565  03b6 a20f00             	ldx #15
   566                          .listmany2
   567  03b9 da                 	phx
   568  03ba 20c403             	jsr+2 .listsingle
   569  03bd fa                 	plx
   570  03be ca                 	dex
   571  03bf d0f8               	bne .listmany2
   572  03c1 4c7001             	jmp moncmd
   573                          .listsingle
   574  03c4 a00000             	ldy #$0000
   575  03c7 20bf00             	jsr prdumpaddr
   576  03ca a900               	lda #$00
   577  03cc eb                 	xba					;clear B
   578  03cd a73a               	lda [mondump]				;get opcode
   579  03cf c980               	cmp #$80
   580  03d1 9003               	bcc .dunno2
   581  03d3 4c6204             	jmp .dunno
   582                          .dunno2
   583  03d6 48                 	pha					;save opcode
   584  03d7 aa                 	tax
   585  03d8 bd3008             	lda mnemlenmode,x
   586  03db 4a                 	lsr
   587  03dc 4a                 	lsr
   588  03dd 4a                 	lsr
   589  03de 4a                 	lsr
   590  03df 4a                 	lsr					;isolage opcode len
   591  03e0 852f               	sta scratch1
   592  03e2 a73a               	lda [mondump]
   593  03e4 20d907             	jsr+2 is816
   594  03e7 a52f               	lda scratch1
   595  03e9 aa                 	tax
   596  03ea a00000             	ldy #$0000
   597                          .nextbyte
   598  03ed b73a               	lda [mondump],y
   599  03ef 205403             	jsr prhex			;print hex
   600  03f2 a920               	lda #' '
   601  03f4 8f12fc1b           	sta IO_CON_CHAROUT
   602  03f8 8f13fc1b           	sta IO_CON_REGISTER	;print space
   603  03fc c8                 	iny
   604  03fd ca                 	dex
   605  03fe d0ed               	bne .nextbyte
   606  0400 a916               	lda #$16
   607  0402 8f14fc1b           	sta IO_CON_CURSORH	;tab over
   608  0406 68                 	pla					;get opcode back
   609  0407 aa                 	tax
   610  0408 bdb008             	lda mnemlist,x
   611  040b da                 	phx					;stash our opcode
   612  040c 0a                 	asl
   613  040d 18                 	clc
   614  040e 7db008             	adc mnemlist,x		;multiply by 3
   615  0411 aa                 	tax
   616  0412 bd3009             	lda mnems, x
   617  0415 8f12fc1b           	sta IO_CON_CHAROUT
   618  0419 8f13fc1b           	sta IO_CON_REGISTER
   619  041d e8                 	inx
   620  041e bd3009             	lda mnems, x
   621  0421 8f12fc1b           	sta IO_CON_CHAROUT
   622  0425 8f13fc1b           	sta IO_CON_REGISTER
   623  0429 e8                 	inx
   624  042a bd3009             	lda mnems, x
   625  042d 8f12fc1b           	sta IO_CON_CHAROUT
   626  0431 8f13fc1b           	sta IO_CON_REGISTER
   627  0435 a920               	lda #' '
   628  0437 8f12fc1b           	sta IO_CON_CHAROUT
   629  043b 8f13fc1b           	sta IO_CON_REGISTER
   630  043f fa                 	plx					;get our opcode back in index
   631  0440 bd3008             	lda mnemlenmode,x
   632  0443 291f               	and #$1f			;isolate the addressing mode
   633  0445 0a                 	asl					;multiply by two
   634  0446 aa                 	tax
   635  0447 fc0808             	jsr (listamod,x)
   636  044a 8f17fc1b           	sta IO_CON_CR
   637                          .fixup
   638  044e a52f               	lda scratch1		;get our fixup
   639  0450 18                 	clc
   640  0451 653a               	adc mondump
   641  0453 853a               	sta mondump
   642  0455 a53b               	lda mondump_m
   643  0457 6900               	adc #$00
   644  0459 853b               	sta mondump_m
   645  045b a53c               	lda mondump_h
   646  045d 6900               	adc #$00
   647  045f 853c               	sta mondump_h
   648                          .goback
   649  0461 60                 	rts
   650                          .dunno
   651  0462 205403             	jsr prhex
   652  0465 a916               	lda #$16
   653  0467 8f14fc1b           	sta IO_CON_CURSORH
   654  046b a901               	lda #$01
   655  046d 852f               	sta scratch1		;fix up one byte
   656  046f a93f               	lda #'?'
   657  0471 8f12fc1b           	sta IO_CON_CHAROUT
   658  0475 8f13fc1b           	sta IO_CON_REGISTER
   659  0479 8f13fc1b           	sta IO_CON_REGISTER
   660  047d 8f13fc1b           	sta IO_CON_REGISTER
   661  0481 8f17fc1b           	sta IO_CON_CR
   662  0485 80c7               	bra .fixup
   663                          
   664                          amod0
   665  0487 a924               	lda #'$'
   666  0489 8f12fc1b           	sta IO_CON_CHAROUT
   667  048d 8f13fc1b           	sta IO_CON_REGISTER
   668  0491 a00100             	ldy #$0001
   669  0494 b73a               	lda [mondump],y
   670  0496 205403             	jsr prhex
   671  0499 60                 	rts
   672                          amod1
   673  049a a928               	lda #'('
   674  049c 8f12fc1b           	sta IO_CON_CHAROUT
   675  04a0 8f13fc1b           	sta IO_CON_REGISTER
   676  04a4 a924               	lda #'$'
   677  04a6 8f12fc1b           	sta IO_CON_CHAROUT
   678  04aa 8f13fc1b           	sta IO_CON_REGISTER
   679  04ae a00100             	ldy #$0001
   680  04b1 b73a               	lda [mondump],y
   681  04b3 205403             	jsr prhex
   682  04b6 a92c               	lda #','
   683  04b8 8f12fc1b           	sta IO_CON_CHAROUT
   684  04bc 8f13fc1b           	sta IO_CON_REGISTER
   685  04c0 a958               	lda #'X'
   686  04c2 8f12fc1b           	sta IO_CON_CHAROUT
   687  04c6 8f13fc1b           	sta IO_CON_REGISTER
   688  04ca a929               	lda #')'
   689  04cc 8f12fc1b           	sta IO_CON_CHAROUT
   690  04d0 8f13fc1b           	sta IO_CON_REGISTER
   691  04d4 60                 	rts
   692                          amod2
   693  04d5 a00100             	ldy #$0001
   694  04d8 b73a               	lda [mondump],y
   695  04da 205403             	jsr prhex
   696  04dd a92c               	lda #','
   697  04df 8f12fc1b           	sta IO_CON_CHAROUT
   698  04e3 8f13fc1b           	sta IO_CON_REGISTER
   699  04e7 a953               	lda #'S'
   700  04e9 8f12fc1b           	sta IO_CON_CHAROUT
   701  04ed 8f13fc1b           	sta IO_CON_REGISTER
   702  04f1 60                 	rts
   703                          amod3
   704  04f2 a95b               	lda #'['
   705  04f4 8f12fc1b           	sta IO_CON_CHAROUT
   706  04f8 8f13fc1b           	sta IO_CON_REGISTER
   707  04fc a924               	lda #'$'
   708  04fe 8f12fc1b           	sta IO_CON_CHAROUT
   709  0502 8f13fc1b           	sta IO_CON_REGISTER
   710  0506 a00100             	ldy #$0001
   711  0509 b73a               	lda [mondump],y
   712  050b 205403             	jsr prhex
   713  050e a95d               	lda #']'
   714  0510 8f12fc1b           	sta IO_CON_CHAROUT
   715  0514 8f13fc1b           	sta IO_CON_REGISTER
   716                          amod4
   717  0518 60                 	rts
   718                          	!zone amod5
   719                          amod5
   720  0519 a923               	lda #'#'
   721  051b 8f12fc1b           	sta IO_CON_CHAROUT
   722  051f 8f13fc1b           	sta IO_CON_REGISTER
   723  0523 a924               	lda #'$'
   724  0525 8f12fc1b           	sta IO_CON_CHAROUT
   725  0529 8f13fc1b           	sta IO_CON_REGISTER
   726  052d a52f               	lda scratch1
   727  052f c902               	cmp #$02
   728  0531 f008               	beq .amod508
   729                          .amod516
   730  0533 a00200             	ldy #$0002
   731  0536 b73a               	lda [mondump],y
   732  0538 205403             	jsr prhex
   733                          .amod508
   734  053b a00100             	ldy #$0001
   735  053e b73a               	lda [mondump],y
   736  0540 205403             	jsr prhex
   737  0543 60                 	rts
   738                          amod6
   739  0544 a924               	lda #'$'
   740  0546 8f12fc1b           	sta IO_CON_CHAROUT
   741  054a 8f13fc1b           	sta IO_CON_REGISTER
   742  054e a00200             	ldy #$0002
   743  0551 b73a               	lda [mondump],y
   744  0553 205403             	jsr prhex
   745  0556 88                 	dey
   746  0557 b73a               	lda [mondump],y
   747  0559 4c5403             	jmp prhex
   748                          amod7
   749  055c a924               	lda #'$'
   750  055e 8f12fc1b           	sta IO_CON_CHAROUT
   751  0562 8f13fc1b           	sta IO_CON_REGISTER
   752  0566 a00300             	ldy #$0003
   753  0569 b73a               	lda [mondump],y
   754  056b 205403             	jsr prhex
   755  056e 88                 	dey
   756  056f b73a               	lda [mondump],y
   757  0571 205403             	jsr prhex
   758  0574 88                 	dey
   759  0575 b73a               	lda [mondump],y
   760  0577 4c5403             	jmp prhex
   761                          amod11
   762  057a a00300             	ldy #$0003
   763  057d 842a               	sty scratch2			;number of bytes to bump offset
   764  057f a00200             	ldy #$0002
   765  0582 b73a               	lda [mondump],y
   766  0584 eb                 	xba
   767  0585 88                 	dey
   768  0586 b73a               	lda [mondump],y
   769  0588 8014               	bra amod8nosign
   770                          amod8
   771  058a a00200             	ldy #$0002
   772  058d 842a               	sty scratch2
   773  058f a900               	lda #$00
   774  0591 eb                 	xba						;clear high byte of A
   775                          amod8a
   776  0592 a00100             	ldy #$0001
   777  0595 b73a               	lda [mondump],y			;get rel byte
   778  0597 1005               	bpl amod8nosign
   779  0599 48                 	pha
   780  059a a9ff               	lda #$ff
   781  059c eb                 	xba						;sign extend if negative
   782  059d 68                 	pla
   783                          amod8nosign
   784  059e c230               	rep #$30
   785                          	!al
   786  05a0 18                 	clc
   787  05a1 653a               	adc mondump				;add to our current disassembly address
   788  05a3 18                 	clc
   789  05a4 652a               	adc scratch2			;add offset for instruction size
   790  05a6 aa                 	tax
   791  05a7 e220               	sep #$20
   792                          	!as
   793  05a9 a924               	lda #'$'
   794  05ab 8f12fc1b           	sta IO_CON_CHAROUT
   795  05af 8f13fc1b           	sta IO_CON_REGISTER
   796  05b3 204a03             	jsr prhex16
   797  05b6 60                 	rts
   798                          amod9
   799  05b7 a928               	lda #'('
   800  05b9 8f12fc1b           	sta IO_CON_CHAROUT
   801  05bd 8f13fc1b           	sta IO_CON_REGISTER
   802  05c1 a924               	lda #'$'
   803  05c3 8f12fc1b           	sta IO_CON_CHAROUT
   804  05c7 8f13fc1b           	sta IO_CON_REGISTER
   805  05cb a00100             	ldy #$0001
   806  05ce b73a               	lda [mondump],y
   807  05d0 205403             	jsr prhex
   808  05d3 a929               	lda #')'
   809  05d5 8f12fc1b           	sta IO_CON_CHAROUT
   810  05d9 8f13fc1b           	sta IO_CON_REGISTER
   811  05dd a92c               	lda #','
   812  05df 8f12fc1b           	sta IO_CON_CHAROUT
   813  05e3 8f13fc1b           	sta IO_CON_REGISTER
   814  05e7 a959               	lda #'Y'
   815  05e9 8f12fc1b           	sta IO_CON_CHAROUT
   816  05ed 8f13fc1b           	sta IO_CON_REGISTER
   817  05f1 60                 	rts
   818                          amoda
   819  05f2 a928               	lda #'('
   820  05f4 8f12fc1b           	sta IO_CON_CHAROUT
   821  05f8 8f13fc1b           	sta IO_CON_REGISTER
   822  05fc a924               	lda #'$'
   823  05fe 8f12fc1b           	sta IO_CON_CHAROUT
   824  0602 8f13fc1b           	sta IO_CON_REGISTER
   825  0606 a00100             	ldy #$0001
   826  0609 b73a               	lda [mondump],y
   827  060b 205403             	jsr prhex
   828  060e a929               	lda #')'
   829  0610 8f12fc1b           	sta IO_CON_CHAROUT
   830  0614 8f13fc1b           	sta IO_CON_REGISTER
   831  0618 60                 	rts
   832                          amodb
   833  0619 a928               	lda #'('
   834  061b 8f12fc1b           	sta IO_CON_CHAROUT
   835  061f 8f13fc1b           	sta IO_CON_REGISTER
   836  0623 a924               	lda #'$'
   837  0625 8f12fc1b           	sta IO_CON_CHAROUT
   838  0629 8f13fc1b           	sta IO_CON_REGISTER
   839  062d a00100             	ldy #$0001
   840  0630 b73a               	lda [mondump],y
   841  0632 205403             	jsr prhex
   842  0635 a92c               	lda #','
   843  0637 8f12fc1b           	sta IO_CON_CHAROUT
   844  063b 8f13fc1b           	sta IO_CON_REGISTER
   845  063f a953               	lda #'S'
   846  0641 8f12fc1b           	sta IO_CON_CHAROUT
   847  0645 8f13fc1b           	sta IO_CON_REGISTER
   848  0649 a929               	lda #')'
   849  064b 8f12fc1b           	sta IO_CON_CHAROUT
   850  064f 8f13fc1b           	sta IO_CON_REGISTER
   851  0653 a92c               	lda #','
   852  0655 8f12fc1b           	sta IO_CON_CHAROUT
   853  0659 8f13fc1b           	sta IO_CON_REGISTER
   854  065d a959               	lda #'Y'
   855  065f 8f12fc1b           	sta IO_CON_CHAROUT
   856  0663 8f13fc1b           	sta IO_CON_REGISTER
   857  0667 60                 	rts
   858                          amodc
   859  0668 a924               	lda #'$'
   860  066a 8f12fc1b           	sta IO_CON_CHAROUT
   861  066e 8f13fc1b           	sta IO_CON_REGISTER
   862  0672 a00100             	ldy #$0001
   863  0675 b73a               	lda [mondump],y
   864  0677 205403             	jsr prhex
   865  067a a92c               	lda #','
   866  067c 8f12fc1b           	sta IO_CON_CHAROUT
   867  0680 8f13fc1b           	sta IO_CON_REGISTER
   868  0684 a958               	lda #'X'
   869  0686 8f12fc1b           	sta IO_CON_CHAROUT
   870  068a 8f13fc1b           	sta IO_CON_REGISTER
   871  068e 60                 	rts
   872                          amodd
   873  068f a95b               	lda #'['
   874  0691 8f12fc1b           	sta IO_CON_CHAROUT
   875  0695 8f13fc1b           	sta IO_CON_REGISTER
   876  0699 a924               	lda #'$'
   877  069b 8f12fc1b           	sta IO_CON_CHAROUT
   878  069f 8f13fc1b           	sta IO_CON_REGISTER
   879  06a3 a00100             	ldy #$0001
   880  06a6 b73a               	lda [mondump],y
   881  06a8 205403             	jsr prhex
   882  06ab a95d               	lda #']'
   883  06ad 8f12fc1b           	sta IO_CON_CHAROUT
   884  06b1 8f13fc1b           	sta IO_CON_REGISTER
   885  06b5 a92c               	lda #','
   886  06b7 8f12fc1b           	sta IO_CON_CHAROUT
   887  06bb 8f13fc1b           	sta IO_CON_REGISTER
   888  06bf a959               	lda #'Y'
   889  06c1 8f12fc1b           	sta IO_CON_CHAROUT
   890  06c5 8f13fc1b           	sta IO_CON_REGISTER
   891  06c9 60                 	rts
   892                          amode
   893  06ca a924               	lda #'$'
   894  06cc 8f12fc1b           	sta IO_CON_CHAROUT
   895  06d0 8f13fc1b           	sta IO_CON_REGISTER
   896  06d4 a00200             	ldy #$0002
   897  06d7 b73a               	lda [mondump],y
   898  06d9 205403             	jsr prhex
   899  06dc 88                 	dey
   900  06dd b73a               	lda [mondump],y
   901  06df 205403             	jsr prhex
   902  06e2 a92c               	lda #','
   903  06e4 8f12fc1b           	sta IO_CON_CHAROUT
   904  06e8 8f13fc1b           	sta IO_CON_REGISTER
   905  06ec a958               	lda #'X'
   906  06ee 8f12fc1b           	sta IO_CON_CHAROUT
   907  06f2 8f13fc1b           	sta IO_CON_REGISTER
   908  06f6 60                 	rts
   909                          amodf
   910  06f7 a924               	lda #'$'
   911  06f9 8f12fc1b           	sta IO_CON_CHAROUT
   912  06fd 8f13fc1b           	sta IO_CON_REGISTER
   913  0701 a00200             	ldy #$0002
   914  0704 b73a               	lda [mondump],y
   915  0706 205403             	jsr prhex
   916  0709 88                 	dey
   917  070a b73a               	lda [mondump],y
   918  070c 205403             	jsr prhex
   919  070f a92c               	lda #','
   920  0711 8f12fc1b           	sta IO_CON_CHAROUT
   921  0715 8f13fc1b           	sta IO_CON_REGISTER
   922  0719 a959               	lda #'Y'
   923  071b 8f12fc1b           	sta IO_CON_CHAROUT
   924  071f 8f13fc1b           	sta IO_CON_REGISTER
   925  0723 60                 	rts
   926                          amod10
   927  0724 a924               	lda #'$'
   928  0726 8f12fc1b           	sta IO_CON_CHAROUT
   929  072a 8f13fc1b           	sta IO_CON_REGISTER
   930  072e a00300             	ldy #$0003
   931  0731 b73a               	lda [mondump],y
   932  0733 205403             	jsr prhex
   933  0736 88                 	dey
   934  0737 b73a               	lda [mondump],y
   935  0739 205403             	jsr prhex
   936  073c 88                 	dey
   937  073d b73a               	lda [mondump],y
   938  073f 205403             	jsr prhex
   939  0742 a92c               	lda #','
   940  0744 8f12fc1b           	sta IO_CON_CHAROUT
   941  0748 8f13fc1b           	sta IO_CON_REGISTER
   942  074c a958               	lda #'X'
   943  074e 8f12fc1b           	sta IO_CON_CHAROUT
   944  0752 8f13fc1b           	sta IO_CON_REGISTER
   945  0756 60                 	rts
   946                          amod12
   947  0757 a928               	lda #'('
   948  0759 8f12fc1b           	sta IO_CON_CHAROUT
   949  075d 8f13fc1b           	sta IO_CON_REGISTER
   950  0761 a924               	lda #'$'
   951  0763 8f12fc1b           	sta IO_CON_CHAROUT
   952  0767 8f13fc1b           	sta IO_CON_REGISTER
   953  076b a00200             	ldy #$0002
   954  076e b73a               	lda [mondump],y
   955  0770 205403             	jsr prhex
   956  0773 88                 	dey
   957  0774 b73a               	lda [mondump],y
   958  0776 205403             	jsr prhex
   959  0779 a929               	lda #')'
   960  077b 8f12fc1b           	sta IO_CON_CHAROUT
   961  077f 8f13fc1b           	sta IO_CON_REGISTER
   962  0783 60                 	rts
   963                          amod13
   964  0784 a928               	lda #'('
   965  0786 8f12fc1b           	sta IO_CON_CHAROUT
   966  078a 8f13fc1b           	sta IO_CON_REGISTER
   967  078e a924               	lda #'$'
   968  0790 8f12fc1b           	sta IO_CON_CHAROUT
   969  0794 8f13fc1b           	sta IO_CON_REGISTER
   970  0798 a00200             	ldy #$0002
   971  079b b73a               	lda [mondump],y
   972  079d 205403             	jsr prhex
   973  07a0 88                 	dey
   974  07a1 b73a               	lda [mondump],y
   975  07a3 205403             	jsr prhex
   976  07a6 a92c               	lda #','
   977  07a8 8f12fc1b           	sta IO_CON_CHAROUT
   978  07ac 8f13fc1b           	sta IO_CON_REGISTER
   979  07b0 a958               	lda #'X'
   980  07b2 8f12fc1b           	sta IO_CON_CHAROUT
   981  07b6 8f13fc1b           	sta IO_CON_REGISTER
   982  07ba a929               	lda #')'
   983  07bc 8f12fc1b           	sta IO_CON_CHAROUT
   984  07c0 8f13fc1b           	sta IO_CON_REGISTER
   985  07c4 60                 	rts
   986                          	
   987                          						;test branches for disassembly purposes..
   988  07c5 7090               	bvs amod12
   989  07c7 7010               	bvs is816
   990  07c9 70b9               	bvs amod13
   991  07cb 703b               	bvs listamod
   992  07cd 6287ff             	per amod12
   993  07d0 620600             	per is816
   994  07d3 624eff             	per amod10
   995  07d6 622f00             	per listamod
   996                          	
   997                          	!zone is816
   998                          is816
   999  07d9 48                 	pha
  1000  07da 291f               	and #$1f
  1001  07dc c909               	cmp #$09				;09, 29, 49, etc?
  1002  07de d006               	bne .testx
  1003  07e0 242d               	bit alarge				;16 bit?
  1004  07e2 301e               	bmi .is16
  1005  07e4 1016               	bpl .is8
  1006                          .testx
  1007  07e6 c9a0               	cmp #$a0
  1008  07e8 f00e               	beq .isx
  1009  07ea c9a2               	cmp #$a2
  1010  07ec f00a               	beq .isx
  1011  07ee c9c0               	cmp #$c0
  1012  07f0 f006               	beq .isx
  1013  07f2 c9e0               	cmp #$e0
  1014  07f4 f002               	beq .isx
  1015  07f6 68                 	pla						;made it here, not an accumulator or index instruction
  1016  07f7 60                 	rts
  1017                          .isx
  1018  07f8 242e               	bit xlarge
  1019  07fa 3006               	bmi .is16				;or else fall thru
  1020                          .is8
  1021  07fc a902               	lda #$2
  1022  07fe 852f               	sta scratch1
  1023  0800 68                 	pla
  1024  0801 60                 	rts
  1025                          .is16
  1026  0802 a903               	lda #$3
  1027  0804 852f               	sta scratch1
  1028  0806 68                 	pla
  1029  0807 60                 	rts
  1030                          	
  1031                          listamod
  1032  0808 8704               	!16 amod0			;$xx
  1033  080a 9a04               	!16 amod1			;($xx,X)
  1034  080c d504               	!16 amod2			;x,S
  1035  080e f204               	!16 amod3			;[$xx]
  1036  0810 1805               	!16 amod4			;implied
  1037  0812 1905               	!16 amod5			;#$xx (or #$yyxx)
  1038  0814 4405               	!16 amod6			;$yyxx
  1039  0816 5c05               	!16 amod7			;$zzyyxx
  1040  0818 8a05               	!16 amod8			;rel8
  1041  081a b705               	!16 amod9			;($xx),Y
  1042  081c f205               	!16 amoda			;($xx)
  1043  081e 1906               	!16 amodb			;(xx,S),Y
  1044  0820 6806               	!16 amodc			;$xx,X
  1045  0822 8f06               	!16 amodd			;[$xx],Y
  1046  0824 ca06               	!16 amode			;$yyxx,X
  1047  0826 f706               	!16 amodf			;$yyxx,Y
  1048  0828 2407               	!16 amod10			;$zzyyxx,X
  1049  082a 7a05               	!16 amod11			;rel16
  1050  082c 5707               	!16 amod12			;($yyxx)
  1051  082e 8407               	!16 amod13			;($yyxx,X)
  1052                          	
  1053                          mnemlenmode
  1054  0830 40                 	!byte %01000000		;00 brk 2/$xx
  1055  0831 41                 	!byte %01000001		;01 ora 2/($xx,x)
  1056  0832 40                 	!byte %01000000		;02 cop 2/$xx
  1057  0833 42                 	!byte %01000010		;03 ora 2/x,s
  1058  0834 40                 	!byte %01000000		;04 tsb 2/$xx
  1059  0835 40                 	!byte %01000000		;05 ora 2/$xx
  1060  0836 40                 	!byte %01000000		;06 asl 2/$xx
  1061  0837 43                 	!byte %01000011		;07 ora 2/[$xx]
  1062  0838 24                 	!byte %00100100		;08 php 1
  1063  0839 45                 	!byte %01000101		;09 ora 2/#imm
  1064  083a 24                 	!byte %00100100		;0a asl 1
  1065  083b 24                 	!byte %00100100		;0b phd 1
  1066  083c 66                 	!byte %01100110		;0c tsb 3/$yyxx
  1067  083d 66                 	!byte %01100110		;0d ora 3/$yyxx
  1068  083e 66                 	!byte %01100110		;0e asl 3/$yyxx
  1069  083f 87                 	!byte %10000111		;0f ora 4/$zzyyxx
  1070  0840 48                 	!byte %01001000		;10 bpl 2/rel8
  1071  0841 49                 	!byte %01001001		;11 ora 2/($xx),Y
  1072  0842 4a                 	!byte %01001010		;12 ora 2/($xx)
  1073  0843 4b                 	!byte %01001011		;13 ora 2/(x,s),Y
  1074  0844 40                 	!byte %01000000		;14 trb 2/$xx
  1075  0845 4c                 	!byte %01001100		;15 ora 2/$xx,X
  1076  0846 4c                 	!byte %01001100		;16 asl 2/$xx,X
  1077  0847 4d                 	!byte %01001101		;17 ora 2/[$xx],Y
  1078  0848 24                 	!byte %00100100		;18 clc 1
  1079  0849 6f                 	!byte %01101111		;19 ora 3/$yyxx,Y
  1080  084a 24                 	!byte %00100100		;1a inc 1
  1081  084b 24                 	!byte %00100100		;1b tcs 1
  1082  084c 66                 	!byte %01100110		;1c trb 3/$yyxx
  1083  084d 6e                 	!byte %01101110		;1d ora 3/$yyxx,X
  1084  084e 6e                 	!byte %01101110		;1e asl 3/$yyxx,X
  1085  084f 90                 	!byte %10010000		;1f ora 4/$zzyyxx,X
  1086  0850 66                 	!byte %01100110		;20 jsr 3/$yyxx
  1087  0851 41                 	!byte %01000001		;21 and 2/($xx,x)
  1088  0852 87                 	!byte %10000111		;22 jsl 4/$zzyyxx
  1089  0853 42                 	!byte %01000010		;23 and 2/x,s
  1090  0854 40                 	!byte %01000000		;24 bit 2/$xx
  1091  0855 40                 	!byte %01000000		;25 and 2/$xx
  1092  0856 40                 	!byte %01000000		;26 rol 2/$xx
  1093  0857 43                 	!byte %01000011		;27 and 2/[$xx]
  1094  0858 24                 	!byte %00100100		;28 plp 1
  1095  0859 45                 	!byte %01000101		;29 and 2/#imm
  1096  085a 24                 	!byte %00100100		;2a rol 1
  1097  085b 24                 	!byte %00100100		;2b pld 1
  1098  085c 66                 	!byte %01100110		;2c bit 3/$yyxx
  1099  085d 66                 	!byte %01100110		;2d and 3/$yyxx
  1100  085e 66                 	!byte %01100110		;2e rol 3/$yyxx
  1101  085f 87                 	!byte %10000111		;2f and 4/$zzyyxx
  1102  0860 48                 	!byte %01001000		;30 bmi 2/rel8
  1103  0861 49                 	!byte %01001001		;31 and 2/($xx),Y
  1104  0862 4a                 	!byte %01001010		;32 and 2/($xx)
  1105  0863 4b                 	!byte %01001011		;33 and 2/(x,s),Y
  1106  0864 4c                 	!byte %01001100		;34 bit 2/$xx,X
  1107  0865 4c                 	!byte %01001100		;35 and 2/$xx,X
  1108  0866 4c                 	!byte %01001100		;36 rol 2/$xx,X
  1109  0867 4d                 	!byte %01001101		;37 and 2/[$xx],Y
  1110  0868 24                 	!byte %00100100		;38 sec 1
  1111  0869 6f                 	!byte %01101111		;39 and 3/$yyxx,Y
  1112  086a 24                 	!byte %00100100		;3a dec 1
  1113  086b 24                 	!byte %00100100		;3b tsc 1
  1114  086c 6e                 	!byte %01101110		;3c bit 3/$yyxx,X
  1115  086d 6e                 	!byte %01101110		;3d and 3/$yyxx,X
  1116  086e 6e                 	!byte %01101110		;3e rol 3/$yyxx,X
  1117  086f 90                 	!byte %10010000		;3f and 4/$zzyyxx,X
  1118  0870 24                 	!byte %00100100		;40 ???
  1119  0871 41                 	!byte %01000001		;41 eor 2/($xx,x)
  1120  0872 40                 	!byte %01000000		;42 wdm 2/$00
  1121  0873 42                 	!byte %01000010		;43 eor 2/x,s
  1122  0874 24                 	!byte %00100100		;44 ???
  1123  0875 40                 	!byte %01000000		;45 eor 2/$xx
  1124  0876 40                 	!byte %01000000		;46 lsr 2/$xx
  1125  0877 43                 	!byte %01000011		;47 eor 2/[$xx]
  1126  0878 24                 	!byte %00100100		;48 pha 1
  1127  0879 45                 	!byte %01000101		;49 eor 2/#imm
  1128  087a 24                 	!byte %00100100		;4a lsr 1
  1129  087b 24                 	!byte %00100100		;4b phk 1
  1130  087c 66                 	!byte %01100110		;4c jmp 3/$yyxx
  1131  087d 66                 	!byte %01100110		;4d eor 3/$yyxx
  1132  087e 66                 	!byte %01100110		;4e lsr 3/$yyxx
  1133  087f 87                 	!byte %10000111		;4f eor 4/$zzyyxx
  1134  0880 48                 	!byte %01001000		;50 bvc 2/rel8
  1135  0881 49                 	!byte %01001001		;51 eor 2/($xx),Y
  1136  0882 4a                 	!byte %01001010		;52 eor 2/($xx)
  1137  0883 4b                 	!byte %01001011		;53 eor 2/(x,s),Y
  1138  0884 24                 	!byte %00100100		;54 ???
  1139  0885 4c                 	!byte %01001100		;55 eor 2/$xx,X
  1140  0886 4c                 	!byte %01001100		;56 lsr 2/$xx,X
  1141  0887 4d                 	!byte %01001101		;57 eor 2/[$xx],Y
  1142  0888 24                 	!byte %00100100		;58 cli 1
  1143  0889 6f                 	!byte %01101111		;59 eor 3/$yyxx,Y
  1144  088a 24                 	!byte %00100100		;5a phy 1
  1145  088b 24                 	!byte %00100100		;5b tcd 1
  1146  088c 87                 	!byte %10000111		;5c jml 4/$zzyyxx
  1147  088d 6e                 	!byte %01101110		;5d eor 3/$yyxx,X
  1148  088e 6e                 	!byte %01101110		;5e lsr 3/$yyxx,X
  1149  088f 90                 	!byte %10010000		;5f eor 4/$zzyyxx,X
  1150  0890 24                 	!byte %00100100		;60 rts
  1151  0891 41                 	!byte %01000001		;61 adc 2/($xx,x)
  1152  0892 71                 	!byte %01110001		;62 per 3/rel16
  1153  0893 42                 	!byte %01000010		;63 adc 2/x,s
  1154  0894 40                 	!byte %01000000		;64 stz 2/$xx
  1155  0895 40                 	!byte %01000000		;65 adc 2/$xx
  1156  0896 40                 	!byte %01000000		;66 ror 2/$xx
  1157  0897 43                 	!byte %01000011		;67 adc 2/[$xx]
  1158  0898 24                 	!byte %00100100		;68 pla 1
  1159  0899 45                 	!byte %01000101		;69 adc 2/#imm
  1160  089a 24                 	!byte %00100100		;6a ror 1
  1161  089b 24                 	!byte %00100100		;6b rtl 1
  1162  089c 72                 	!byte %01110010		;6c jmp 3/($yyxx)
  1163  089d 66                 	!byte %01100110		;6d adc 3/$yyxx
  1164  089e 66                 	!byte %01100110		;6e ror 3/$yyxx
  1165  089f 87                 	!byte %10000111		;6f adc 4/$zzyyxx
  1166  08a0 48                 	!byte %01001000		;70 bvs 2/rel8
  1167  08a1 49                 	!byte %01001001		;71 adc 2/($xx),Y
  1168  08a2 4a                 	!byte %01001010		;72 adc 2/($xx)
  1169  08a3 4b                 	!byte %01001011		;73 adc 2/(x,s),Y
  1170  08a4 4c                 	!byte %01001100		;74 stz 2/$xx,X
  1171  08a5 4c                 	!byte %01001100		;75 adc 2/$xx,X
  1172  08a6 4c                 	!byte %01001100		;76 ror 2/$xx,X
  1173  08a7 4d                 	!byte %01001101		;77 adc 2/[$xx],Y
  1174  08a8 24                 	!byte %00100100		;78 sei 1
  1175  08a9 6f                 	!byte %01101111		;79 adc 3/$yyxx,Y
  1176  08aa 24                 	!byte %00100100		;7a ply 1
  1177  08ab 24                 	!byte %00100100		;7b tdc 1
  1178  08ac 73                 	!byte %01110011		;7c jmp 3/($yyxx,X)
  1179  08ad 6e                 	!byte %01101110		;7d adc 3/$yyxx,X
  1180  08ae 6e                 	!byte %01101110		;7e lsr 3/$yyxx,X
  1181  08af 90                 	!byte %10010000		;7f adc 4/$zzyyxx,X
  1182                          mnemlist
  1183  08b0 00                 	!byte $00			;00 brk
  1184  08b1 02                 	!byte $02			;01 ora
  1185  08b2 01                 	!byte $01			;02 cop
  1186  08b3 02                 	!byte $02			;03 ora
  1187  08b4 03                 	!byte $03			;04 tsb
  1188  08b5 02                 	!byte $02			;05 ora
  1189  08b6 04                 	!byte $04			;06 asl
  1190  08b7 02                 	!byte $02			;07 ora
  1191  08b8 05                 	!byte $05			;08 php
  1192  08b9 02                 	!byte $02			;09 ora
  1193  08ba 04                 	!byte $04			;0a asl
  1194  08bb 06                 	!byte $06			;0b phd
  1195  08bc 03                 	!byte $03			;0c tsb
  1196  08bd 02                 	!byte $02			;0d ora
  1197  08be 04                 	!byte $04			;0e asl
  1198  08bf 02                 	!byte $02			;0f ora
  1199  08c0 07                 	!byte $07			;10 bpl
  1200  08c1 02                 	!byte $02			;11 ora
  1201  08c2 02                 	!byte $02			;12 ora
  1202  08c3 02                 	!byte $02			;13 ora
  1203  08c4 08                 	!byte $08			;14 trb
  1204  08c5 02                 	!byte $02			;15 ora
  1205  08c6 04                 	!byte $04			;16 asl
  1206  08c7 02                 	!byte $02			;17 ora
  1207  08c8 09                 	!byte $09			;18 clc
  1208  08c9 02                 	!byte $02			;19 ora
  1209  08ca 0a                 	!byte $0a			;1a inc
  1210  08cb 0b                 	!byte $0b			;1b tcs
  1211  08cc 08                 	!byte $08			;1c trb
  1212  08cd 02                 	!byte $02			;1d ora
  1213  08ce 04                 	!byte $04			;1e asl
  1214  08cf 02                 	!byte $02			;1f ora
  1215  08d0 0d                 	!byte $0d			;20 jsr
  1216  08d1 0c                 	!byte $0c			;21 and
  1217  08d2 0e                 	!byte $0e			;22 jsl
  1218  08d3 0c                 	!byte $0c			;23 and
  1219  08d4 10                 	!byte $10			;24 bit
  1220  08d5 0c                 	!byte $0c			;25 and
  1221  08d6 11                 	!byte $11			;26 rol
  1222  08d7 0c                 	!byte $0c			;27 and
  1223  08d8 12                 	!byte $12			;28 plp
  1224  08d9 0c                 	!byte $0c			;29 and
  1225  08da 11                 	!byte $11			;2a rol
  1226  08db 13                 	!byte $13			;2b pld
  1227  08dc 10                 	!byte $10			;2c bit
  1228  08dd 0c                 	!byte $0c			;2d and
  1229  08de 11                 	!byte $11			;2e rol
  1230  08df 0c                 	!byte $0c			;2f and
  1231  08e0 14                 	!byte $14			;30 bmi
  1232  08e1 0c                 	!byte $0c			;31 and
  1233  08e2 0c                 	!byte $0c			;32 and
  1234  08e3 0c                 	!byte $0c			;33 and
  1235  08e4 11                 	!byte $11			;34 bit
  1236  08e5 0c                 	!byte $0c			;35 and
  1237  08e6 11                 	!byte $11			;36 rol
  1238  08e7 0c                 	!byte $0c			;37 and
  1239  08e8 15                 	!byte $15			;38 sec
  1240  08e9 0c                 	!byte $0c			;39 and
  1241  08ea 0f                 	!byte $0f			;3a dec
  1242  08eb 16                 	!byte $16			;3b tsc
  1243  08ec 11                 	!byte $11			;3c bit
  1244  08ed 0c                 	!byte $0c			;3d and
  1245  08ee 11                 	!byte $11			;3e rol
  1246  08ef 0c                 	!byte $0c			;3f and
  1247  08f0 17                 	!byte $17			;40 ???
  1248  08f1 18                 	!byte $18			;41 eor
  1249  08f2 19                 	!byte $19			;42 wdm
  1250  08f3 18                 	!byte $18			;43 eor
  1251  08f4 17                 	!byte $17			;44 ???
  1252  08f5 18                 	!byte $18			;45 eor
  1253  08f6 1a                 	!byte $1a			;46 lsr
  1254  08f7 18                 	!byte $18			;47 eor
  1255  08f8 1b                 	!byte $1b			;48 pha
  1256  08f9 18                 	!byte $18			;49 eor
  1257  08fa 1a                 	!byte $1a			;4a lsr
  1258  08fb 1c                 	!byte $1c			;4b phk
  1259  08fc 1d                 	!byte $1d			;4c jmp
  1260  08fd 18                 	!byte $18			;4d eor
  1261  08fe 1a                 	!byte $1a			;4e lsr
  1262  08ff 18                 	!byte $18			;4f eor
  1263  0900 1e                 	!byte $1e			;50 bvc
  1264  0901 18                 	!byte $18			;51 eor
  1265  0902 18                 	!byte $18			;52 eor
  1266  0903 18                 	!byte $18			;53 eor
  1267  0904 17                 	!byte $17			;54 ???
  1268  0905 18                 	!byte $18			;55 eor
  1269  0906 1a                 	!byte $1a			;56 lsr
  1270  0907 18                 	!byte $18			;57 eor
  1271  0908 1f                 	!byte $1f			;58 cli
  1272  0909 18                 	!byte $18			;59 eor
  1273  090a 20                 	!byte $20			;5a phy
  1274  090b 21                 	!byte $21			;5b tcd
  1275  090c 22                 	!byte $22			;5c jml
  1276  090d 18                 	!byte $18			;5d eor
  1277  090e 1a                 	!byte $1a			;5e lsr
  1278  090f 18                 	!byte $18			;5f eor
  1279  0910 23                 	!byte $23			;60 rts
  1280  0911 24                 	!byte $24			;61 adc
  1281  0912 25                 	!byte $25			;62 per
  1282  0913 24                 	!byte $24			;63 adc
  1283  0914 26                 	!byte $26			;64 stz
  1284  0915 24                 	!byte $24			;65 adc
  1285  0916 27                 	!byte $27			;66 ror
  1286  0917 24                 	!byte $24			;67 adc
  1287  0918 28                 	!byte $28			;68 pla
  1288  0919 24                 	!byte $24			;69 adc
  1289  091a 27                 	!byte $27			;6a ror
  1290  091b 29                 	!byte $29			;6b rtl
  1291  091c 1d                 	!byte $1d			;6c jmp
  1292  091d 24                 	!byte $24			;6d adc
  1293  091e 27                 	!byte $27			;6e ror
  1294  091f 24                 	!byte $24			;6f adc
  1295  0920 2a                 	!byte $2a			;70 bvs
  1296  0921 24                 	!byte $24			;71 adc
  1297  0922 24                 	!byte $24			;72 adc
  1298  0923 24                 	!byte $24			;73 adc
  1299  0924 26                 	!byte $26			;74 stz
  1300  0925 24                 	!byte $24			;75 adc
  1301  0926 27                 	!byte $27			;76 ror
  1302  0927 24                 	!byte $24			;77 adc
  1303  0928 2b                 	!byte $2b			;78 sei
  1304  0929 24                 	!byte $24			;79 adc
  1305  092a 2c                 	!byte $2c			;7a ply
  1306  092b 2d                 	!byte $2d			;7b tdc
  1307  092c 1d                 	!byte $1d			;7c jmp
  1308  092d 24                 	!byte $24			;7d adc
  1309  092e 27                 	!byte $27			;7e ror
  1310  092f 24                 	!byte $24			;7f adc
  1311                          mnems
  1312  0930 42524b             	!tx "BRK"			;0
  1313  0933 434f50             	!tx "COP"			;1
  1314  0936 4f5241             	!tx "ORA"			;2
  1315  0939 545342             	!tx "TSB"			;3
  1316  093c 41534c             	!tx "ASL"			;4
  1317  093f 504850             	!tx "PHP"			;5
  1318  0942 504844             	!tx "PHD"			;6
  1319  0945 42504c             	!tx "BPL"			;7
  1320  0948 545242             	!tx "TRB"			;8
  1321  094b 434c43             	!tx "CLC"			;9
  1322  094e 494e43             	!tx "INC"			;a
  1323  0951 544353             	!tx "TCS"			;b
  1324  0954 414e44             	!tx "AND"			;c
  1325  0957 4a5352             	!tx "JSR"			;d
  1326  095a 4a534c             	!tx "JSL"			;e
  1327  095d 444543             	!tx "DEC"			;f
  1328  0960 424954             	!tx "BIT"			;10
  1329  0963 524f4c             	!tx "ROL"			;11
  1330  0966 504c50             	!tx "PLP"			;12
  1331  0969 504c44             	!tx "PLD"			;13
  1332  096c 424d49             	!tx "BMI"			;14
  1333  096f 534543             	!tx "SEC"			;15
  1334  0972 545343             	!tx "TSC"			;16
  1335  0975 3f3f3f             	!tx "???"			;17
  1336  0978 454f52             	!tx "EOR"			;18
  1337  097b 57444d             	!tx "WDM"			;19
  1338  097e 4c5352             	!tx "LSR"			;1a
  1339  0981 504841             	!tx "PHA"			;1b
  1340  0984 50484b             	!tx "PHK"			;1c
  1341  0987 4a4d50             	!tx "JMP"			;1d
  1342  098a 425643             	!tx "BVC"			;1e
  1343  098d 434c49             	!tx "CLI"			;1f
  1344  0990 504859             	!tx "PHY"			;20
  1345  0993 544344             	!tx "TCD"			;21
  1346  0996 4a4d4c             	!tx "JML"			;22
  1347  0999 525453             	!tx "RTS"			;23
  1348  099c 414443             	!tx "ADC"			;24
  1349  099f 504552             	!tx "PER"			;25
  1350  09a2 53545a             	!tx "STZ"			;26
  1351  09a5 524f52             	!tx "ROR"			;27
  1352  09a8 504c41             	!tx "PLA"			;28
  1353  09ab 52544c             	!tx "RTL"			;29
  1354  09ae 425653             	!tx "BVS"			;2a
  1355  09b1 534549             	!tx "SEI"			;2b
  1356  09b4 504c59             	!tx "PLY"			;2c
  1357  09b7 544443             	!tx "TDC"			;2d
  1358                          	
  1359                          	!zone ucline
  1360                          ucline					;convert inbuff at $170400 to upper case
  1361  09ba 08                 	php
  1362  09bb c210               	rep #$10
  1363  09bd e220               	sep #$20
  1364                          	!as
  1365                          	!rl
  1366  09bf a20000             	ldx #$0000
  1367                          .local2
  1368  09c2 bf000417           	lda inbuff,x
  1369  09c6 f012               	beq .local4			;hit the zero, so bail
  1370  09c8 c961               	cmp #'a'
  1371  09ca 900b               	bcc .local3			;less then lowercase a, so ignore
  1372  09cc c97b               	cmp #'z' + 1		;less than next character after lowercase z?
  1373  09ce b007               	bcs .local3			;greater than or equal, so ignore
  1374  09d0 38                 	sec
  1375  09d1 e920               	sbc #('z' - 'Z')	;make upper case
  1376  09d3 9f000417           	sta inbuff,x
  1377                          .local3
  1378  09d7 e8                 	inx
  1379  09d8 80e8               	bra .local2
  1380                          .local4
  1381  09da 28                 	plp
  1382  09db 6b                 	rtl
  1383                          	
  1384                          	!zone getline
  1385                          getline
  1386  09dc 08                 	php
  1387  09dd c210               	rep #$10
  1388  09df e220               	sep #$20
  1389                          	!as
  1390                          	!rl
  1391  09e1 a20000             	ldx #$0000
  1392                          .local2
  1393  09e4 af00fc1b           	lda IO_KEYQ_SIZE
  1394  09e8 f0fa               	beq .local2
  1395  09ea af01fc1b           	lda IO_KEYQ_WAITING
  1396  09ee 8f02fc1b           	sta IO_KEYQ_DEQUEUE
  1397  09f2 c90d               	cmp #$0d			;carriage return yet?
  1398  09f4 f01c               	beq .local3
  1399  09f6 c908               	cmp #$08			;backspace/back arrow?
  1400  09f8 f029               	beq .local4
  1401  09fa c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
  1402  09fc 90e6               	bcc .local2		 		;yes, so ignore it
  1403  09fe 9f000417           	sta inbuff,x 		;any other character, so register it and store it
  1404  0a02 8f12fc1b           	sta IO_CON_CHAROUT
  1405  0a06 8f13fc1b           	sta IO_CON_REGISTER
  1406  0a0a e8                 	inx
  1407  0a0b a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
  1408  0a0d e0fe03             	cpx #$3fe			;overrun end of buffer yet?
  1409  0a10 d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
  1410                          .local3
  1411  0a12 9f000417           	sta inbuff,x		;store CR
  1412  0a16 8f17fc1b           	sta IO_CON_CR
  1413  0a1a e8                 	inx
  1414  0a1b a900               	lda #$00			;store zero to end it all
  1415  0a1d 9f000417           	sta inbuff,x
  1416  0a21 28                 	plp
  1417  0a22 6b                 	rtl
  1418                          .local4
  1419  0a23 e00000             	cpx #$0000
  1420  0a26 f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
  1421  0a28 a908               	lda #$08
  1422  0a2a 8f12fc1b           	sta IO_CON_CHAROUT
  1423  0a2e 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
  1424  0a32 a920               	lda #$20
  1425  0a34 8f12fc1b           	sta IO_CON_CHAROUT
  1426  0a38 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
  1427  0a3c a908               	lda #$08
  1428  0a3e 8f12fc1b           	sta IO_CON_CHAROUT
  1429  0a42 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
  1430  0a46 ca                 	dex
  1431  0a47 809b               	bra .local2
  1432                          	
  1433                          prinbuff				;feed location of input buffer into dpla and then print
  1434  0a49 08                 	php
  1435  0a4a c210               	rep #$10
  1436  0a4c e220               	sep #$20
  1437                          	!as
  1438                          	!rl
  1439  0a4e a917               	lda #$17
  1440  0a50 853f               	sta dpla_h
  1441  0a52 a904               	lda #$04
  1442  0a54 853e               	sta dpla_m
  1443  0a56 643d               	stz dpla
  1444  0a58 225e0a1c           	jsl l_prcdpla
  1445  0a5c 28                 	plp
  1446  0a5d 6b                 	rtl
  1447                          	
  1448                          	!zone prcdpla
  1449                          prcdpla					; print C string pointed to by dp locations $3d-$3f
  1450  0a5e 08                 	php
  1451  0a5f c210               	rep #$10
  1452  0a61 e220               	sep #$20
  1453                          	!as
  1454                          	!rl
  1455  0a63 a00000             	ldy #$0000
  1456                          .local2
  1457  0a66 b73d               	lda [dpla],y
  1458  0a68 f00b               	beq .local3
  1459  0a6a 8f12fc1b           	sta IO_CON_CHAROUT
  1460  0a6e 8f13fc1b           	sta IO_CON_REGISTER
  1461  0a72 c8                 	iny
  1462  0a73 80f1               	bra .local2
  1463                          .local3
  1464  0a75 28                 	plp
  1465  0a76 6b                 	rtl
  1466                          
  1467                          initstring
  1468  0a77 494d4c2036353831...	!tx "IML 65816 1C Firmware v00"
  1469  0a90 0d                 	!byte 0x0d
  1470  0a91 53797374656d204d...	!tx "System Monitor"
  1471  0a9f 0d                 	!byte 0x0d
  1472  0aa0 0d                 	!byte 0x0d
  1473  0aa1 00                 	!byte 0
  1474                          
  1475                          helpmsg
  1476  0aa2 494d4c2036353831...	!tx "IML 65816 Monitor Commands"
  1477  0abc 0d                 	!byte $0d
  1478  0abd 41203c616464723e...	!tx "A <addr>  Dump ASCII"
  1479  0ad1 0d                 	!byte $0d
  1480  0ad2 42203c62616e6b3e...	!tx "B <bank>  Change bank"
  1481  0ae7 0d                 	!byte $0d
  1482  0ae8 43203c636f6c6f72...	!tx "C <color> Change terminal colors"
  1483  0b08 0d                 	!byte $0d
  1484  0b09 44203c616464723e...	!tx "D <addr>  Dump hex"
  1485  0b1b 0d                 	!byte $0d
  1486  0b1c 45203c616464723e...	!tx "E <addr> <byte> <byte>...  Enter bytes"
  1487  0b42 0d                 	!byte $0d
  1488  0b43 4c203c616464723e...	!tx "L <addr>  Disassemble 65816 Instructions"
  1489  0b6b 0d                 	!byte $0d
  1490  0b6c 4d203c6d6f64653e...	!tx "M <mode>  Change video mode, 8/9"
  1491  0b8c 0d                 	!byte $0d
  1492  0b8d 5120202020202020...	!tx "Q         Halt the processor"
  1493  0ba9 0d                 	!byte $0d
  1494  0baa 3f20202020202020...	!tx "?         This menu"
  1495  0bbd 0d                 	!byte $0d
  1496  0bbe 3c656e7465723e20...	!tx "<enter>   Repeat last dump command"
  1497  0be0 0d                 	!byte $0d
  1498  0be1 546f207370656369...	!tx "To specify range, use <addr1.addr2>"
  1499  0c04 0d00               	!byte $0d, 00
  1500                          	
  1501  0c06 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
  1502                          
