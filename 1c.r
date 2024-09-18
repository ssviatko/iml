
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
    22                          promptchar = '*'
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
    60  0006 a2360c             	ldx #initstring
    61  0009 863d               	stx dpla
    62  000b a91c               	lda #$1c
    63  000d 853f               	sta dpla_h
    64  000f 221d0c1c           	jsl l_prcdpla
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
   230  0111 221d0c1c           	jsl l_prcdpla
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
   276  0170 a92a               	lda #promptchar
   277  0172 8f12fc1b           	sta IO_CON_CHAROUT
   278  0176 8f13fc1b           	sta IO_CON_REGISTER
   279  017a 229b0b1c           	jsl l_getline
   280  017e 22790b1c           	jsl l_ucline
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
   324  01cd a2610c             	ldx #helpmsg
   325  01d0 863d               	stx dpla
   326  01d2 a91c               	lda #$1c
   327  01d4 853f               	sta dpla_h
   328  01d6 221d0c1c           	jsl l_prcdpla
   329  01da 4c7001             	jmp moncmd
   330                          	
   331                          haltcmd
   332  01dd a2eb01             	ldx #haltmsg
   333  01e0 863d               	stx dpla
   334  01e2 a91c               	lda #$1c
   335  01e4 853f               	sta dpla_h
   336  01e6 221d0c1c           	jsl l_prcdpla
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
   579  03cf 48                 	pha					;save opcode
   580  03d0 aa                 	tax
   581  03d1 bd6508             	lda mnemlenmode,x
   582  03d4 4a                 	lsr
   583  03d5 4a                 	lsr
   584  03d6 4a                 	lsr
   585  03d7 4a                 	lsr
   586  03d8 4a                 	lsr					;isolage opcode len
   587  03d9 852f               	sta scratch1
   588  03db a73a               	lda [mondump]
   589  03dd 200a08             	jsr+2 is816
   590  03e0 a52f               	lda scratch1
   591  03e2 aa                 	tax
   592  03e3 a00000             	ldy #$0000
   593                          .nextbyte
   594  03e6 b73a               	lda [mondump],y
   595  03e8 205403             	jsr prhex			;print hex
   596  03eb a920               	lda #' '
   597  03ed 8f12fc1b           	sta IO_CON_CHAROUT
   598  03f1 8f13fc1b           	sta IO_CON_REGISTER	;print space
   599  03f5 c8                 	iny
   600  03f6 ca                 	dex
   601  03f7 d0ed               	bne .nextbyte
   602  03f9 a916               	lda #$16
   603  03fb 8f14fc1b           	sta IO_CON_CURSORH	;tab over
   604  03ff 68                 	pla					;get opcode back
   605  0400 aa                 	tax
   606  0401 bd6509             	lda mnemlist,x
   607  0404 8530               	sta enterbytes
   608  0406 6431               	stz enterbytes_m	;save for 16 bit add
   609  0408 da                 	phx					;stash our opcode
   610  0409 c230               	rep #$30
   611                          	!al
   612  040b 29ff00             	and #$00ff			;switch to 16 bits, clear top
   613  040e 0a                 	asl
   614  040f 18                 	clc
   615  0410 6530               	adc enterbytes		;multiply by 3
   616  0412 aa                 	tax
   617  0413 e220               	sep #$20
   618                          	!as
   619  0415 bd650a             	lda mnems, x
   620  0418 8f12fc1b           	sta IO_CON_CHAROUT
   621  041c 8f13fc1b           	sta IO_CON_REGISTER
   622  0420 e8                 	inx
   623  0421 bd650a             	lda mnems, x
   624  0424 8f12fc1b           	sta IO_CON_CHAROUT
   625  0428 8f13fc1b           	sta IO_CON_REGISTER
   626  042c e8                 	inx
   627  042d bd650a             	lda mnems, x
   628  0430 8f12fc1b           	sta IO_CON_CHAROUT
   629  0434 8f13fc1b           	sta IO_CON_REGISTER
   630  0438 a920               	lda #' '
   631  043a 8f12fc1b           	sta IO_CON_CHAROUT
   632  043e 8f13fc1b           	sta IO_CON_REGISTER
   633  0442 fa                 	plx					;get our opcode back in index
   634  0443 a900               	lda #$00
   635  0445 eb                 	xba					;clear top byte of A if it's dirty
   636  0446 bd6508             	lda mnemlenmode,x
   637  0449 291f               	and #$1f			;isolate the addressing mode
   638  044b 0a                 	asl					;multiply by two
   639  044c aa                 	tax
   640  044d fc3b08             	jsr (listamod,x)
   641  0450 af20fc1b           	lda IO_VIDMODE
   642  0454 c909               	cmp #$09
   643  0456 d01f               	bne .fixup1
   644  0458 a925               	lda #$25
   645  045a 8f14fc1b           	sta IO_CON_CURSORH		;tab over and print our bytes as ASCII in 80 column mode
   646  045e e230               	sep #$30				;8 bit indexes here
   647                          	!rs
   648  0460 a000               	ldy #$00				;print disassembly bytes as ASCII... bonus when in mode 9!
   649                          .asc2
   650  0462 b73a               	lda [mondump],y
   651  0464 c920               	cmp #$20
   652  0466 b002               	bcs .asc4
   653  0468 a92e               	lda #'.'				;substitute control character with a period
   654                          .asc4
   655  046a 8f12fc1b           	sta IO_CON_CHAROUT
   656  046e 8f13fc1b           	sta IO_CON_REGISTER
   657  0472 c8                 	iny
   658  0473 c42f               	cpy scratch1
   659  0475 d0eb               	bne .asc2
   660                          .fixup1
   661  0477 c210               	rep #$10
   662                          	!rl
   663  0479 8f17fc1b           	sta IO_CON_CR
   664                          .fixup
   665  047d a52f               	lda scratch1		;get our fixup
   666  047f 18                 	clc
   667  0480 653a               	adc mondump
   668  0482 853a               	sta mondump
   669  0484 a53b               	lda mondump_m
   670  0486 6900               	adc #$00
   671  0488 853b               	sta mondump_m
   672  048a a53c               	lda mondump_h
   673  048c 6900               	adc #$00
   674  048e 853c               	sta mondump_h
   675                          .goback
   676  0490 60                 	rts
   677                          
   678                          amod0
   679  0491 a924               	lda #'$'
   680  0493 8f12fc1b           	sta IO_CON_CHAROUT
   681  0497 8f13fc1b           	sta IO_CON_REGISTER
   682  049b a00100             	ldy #$0001
   683  049e b73a               	lda [mondump],y
   684  04a0 205403             	jsr prhex
   685  04a3 60                 	rts
   686                          amod1
   687  04a4 a928               	lda #'('
   688  04a6 8f12fc1b           	sta IO_CON_CHAROUT
   689  04aa 8f13fc1b           	sta IO_CON_REGISTER
   690  04ae a924               	lda #'$'
   691  04b0 8f12fc1b           	sta IO_CON_CHAROUT
   692  04b4 8f13fc1b           	sta IO_CON_REGISTER
   693  04b8 a00100             	ldy #$0001
   694  04bb b73a               	lda [mondump],y
   695  04bd 205403             	jsr prhex
   696  04c0 a92c               	lda #','
   697  04c2 8f12fc1b           	sta IO_CON_CHAROUT
   698  04c6 8f13fc1b           	sta IO_CON_REGISTER
   699  04ca a958               	lda #'X'
   700  04cc 8f12fc1b           	sta IO_CON_CHAROUT
   701  04d0 8f13fc1b           	sta IO_CON_REGISTER
   702  04d4 a929               	lda #')'
   703  04d6 8f12fc1b           	sta IO_CON_CHAROUT
   704  04da 8f13fc1b           	sta IO_CON_REGISTER
   705  04de 60                 	rts
   706                          amod2
   707  04df a00100             	ldy #$0001
   708  04e2 b73a               	lda [mondump],y
   709  04e4 205403             	jsr prhex
   710  04e7 a92c               	lda #','
   711  04e9 8f12fc1b           	sta IO_CON_CHAROUT
   712  04ed 8f13fc1b           	sta IO_CON_REGISTER
   713  04f1 a953               	lda #'S'
   714  04f3 8f12fc1b           	sta IO_CON_CHAROUT
   715  04f7 8f13fc1b           	sta IO_CON_REGISTER
   716  04fb 60                 	rts
   717                          amod3
   718  04fc a95b               	lda #'['
   719  04fe 8f12fc1b           	sta IO_CON_CHAROUT
   720  0502 8f13fc1b           	sta IO_CON_REGISTER
   721  0506 a924               	lda #'$'
   722  0508 8f12fc1b           	sta IO_CON_CHAROUT
   723  050c 8f13fc1b           	sta IO_CON_REGISTER
   724  0510 a00100             	ldy #$0001
   725  0513 b73a               	lda [mondump],y
   726  0515 205403             	jsr prhex
   727  0518 a95d               	lda #']'
   728  051a 8f12fc1b           	sta IO_CON_CHAROUT
   729  051e 8f13fc1b           	sta IO_CON_REGISTER
   730                          amod4
   731  0522 60                 	rts
   732                          	!zone amod5
   733                          amod5
   734  0523 a923               	lda #'#'
   735  0525 8f12fc1b           	sta IO_CON_CHAROUT
   736  0529 8f13fc1b           	sta IO_CON_REGISTER
   737  052d a924               	lda #'$'
   738  052f 8f12fc1b           	sta IO_CON_CHAROUT
   739  0533 8f13fc1b           	sta IO_CON_REGISTER
   740  0537 a52f               	lda scratch1
   741  0539 c902               	cmp #$02
   742  053b f008               	beq .amod508
   743                          .amod516
   744  053d a00200             	ldy #$0002
   745  0540 b73a               	lda [mondump],y
   746  0542 205403             	jsr prhex
   747                          .amod508
   748  0545 a00100             	ldy #$0001
   749  0548 b73a               	lda [mondump],y
   750  054a 205403             	jsr prhex
   751  054d 60                 	rts
   752                          amod6
   753  054e a924               	lda #'$'
   754  0550 8f12fc1b           	sta IO_CON_CHAROUT
   755  0554 8f13fc1b           	sta IO_CON_REGISTER
   756  0558 a00200             	ldy #$0002
   757  055b b73a               	lda [mondump],y
   758  055d 205403             	jsr prhex
   759  0560 88                 	dey
   760  0561 b73a               	lda [mondump],y
   761  0563 4c5403             	jmp prhex
   762                          amod7
   763  0566 a924               	lda #'$'
   764  0568 8f12fc1b           	sta IO_CON_CHAROUT
   765  056c 8f13fc1b           	sta IO_CON_REGISTER
   766  0570 a00300             	ldy #$0003
   767  0573 b73a               	lda [mondump],y
   768  0575 205403             	jsr prhex
   769  0578 88                 	dey
   770  0579 b73a               	lda [mondump],y
   771  057b 205403             	jsr prhex
   772  057e 88                 	dey
   773  057f b73a               	lda [mondump],y
   774  0581 4c5403             	jmp prhex
   775                          amod11
   776  0584 a00300             	ldy #$0003
   777  0587 842a               	sty scratch2			;number of bytes to bump offset
   778  0589 a00200             	ldy #$0002
   779  058c b73a               	lda [mondump],y
   780  058e eb                 	xba
   781  058f 88                 	dey
   782  0590 b73a               	lda [mondump],y
   783  0592 8014               	bra amod8nosign
   784                          amod8
   785  0594 a00200             	ldy #$0002
   786  0597 842a               	sty scratch2
   787  0599 a900               	lda #$00
   788  059b eb                 	xba						;clear high byte of A
   789                          amod8a
   790  059c a00100             	ldy #$0001
   791  059f b73a               	lda [mondump],y			;get rel byte
   792  05a1 1005               	bpl amod8nosign
   793  05a3 48                 	pha
   794  05a4 a9ff               	lda #$ff
   795  05a6 eb                 	xba						;sign extend if negative
   796  05a7 68                 	pla
   797                          amod8nosign
   798  05a8 c230               	rep #$30
   799                          	!al
   800  05aa 18                 	clc
   801  05ab 653a               	adc mondump				;add to our current disassembly address
   802  05ad 18                 	clc
   803  05ae 652a               	adc scratch2			;add offset for instruction size
   804  05b0 aa                 	tax
   805  05b1 e220               	sep #$20
   806                          	!as
   807  05b3 a924               	lda #'$'
   808  05b5 8f12fc1b           	sta IO_CON_CHAROUT
   809  05b9 8f13fc1b           	sta IO_CON_REGISTER
   810  05bd 204a03             	jsr prhex16
   811  05c0 60                 	rts
   812                          amod9
   813  05c1 a928               	lda #'('
   814  05c3 8f12fc1b           	sta IO_CON_CHAROUT
   815  05c7 8f13fc1b           	sta IO_CON_REGISTER
   816  05cb a924               	lda #'$'
   817  05cd 8f12fc1b           	sta IO_CON_CHAROUT
   818  05d1 8f13fc1b           	sta IO_CON_REGISTER
   819  05d5 a00100             	ldy #$0001
   820  05d8 b73a               	lda [mondump],y
   821  05da 205403             	jsr prhex
   822  05dd a929               	lda #')'
   823  05df 8f12fc1b           	sta IO_CON_CHAROUT
   824  05e3 8f13fc1b           	sta IO_CON_REGISTER
   825  05e7 a92c               	lda #','
   826  05e9 8f12fc1b           	sta IO_CON_CHAROUT
   827  05ed 8f13fc1b           	sta IO_CON_REGISTER
   828  05f1 a959               	lda #'Y'
   829  05f3 8f12fc1b           	sta IO_CON_CHAROUT
   830  05f7 8f13fc1b           	sta IO_CON_REGISTER
   831  05fb 60                 	rts
   832                          amoda
   833  05fc a928               	lda #'('
   834  05fe 8f12fc1b           	sta IO_CON_CHAROUT
   835  0602 8f13fc1b           	sta IO_CON_REGISTER
   836  0606 a924               	lda #'$'
   837  0608 8f12fc1b           	sta IO_CON_CHAROUT
   838  060c 8f13fc1b           	sta IO_CON_REGISTER
   839  0610 a00100             	ldy #$0001
   840  0613 b73a               	lda [mondump],y
   841  0615 205403             	jsr prhex
   842  0618 a929               	lda #')'
   843  061a 8f12fc1b           	sta IO_CON_CHAROUT
   844  061e 8f13fc1b           	sta IO_CON_REGISTER
   845  0622 60                 	rts
   846                          amodb
   847  0623 a928               	lda #'('
   848  0625 8f12fc1b           	sta IO_CON_CHAROUT
   849  0629 8f13fc1b           	sta IO_CON_REGISTER
   850  062d a924               	lda #'$'
   851  062f 8f12fc1b           	sta IO_CON_CHAROUT
   852  0633 8f13fc1b           	sta IO_CON_REGISTER
   853  0637 a00100             	ldy #$0001
   854  063a b73a               	lda [mondump],y
   855  063c 205403             	jsr prhex
   856  063f a92c               	lda #','
   857  0641 8f12fc1b           	sta IO_CON_CHAROUT
   858  0645 8f13fc1b           	sta IO_CON_REGISTER
   859  0649 a953               	lda #'S'
   860  064b 8f12fc1b           	sta IO_CON_CHAROUT
   861  064f 8f13fc1b           	sta IO_CON_REGISTER
   862  0653 a929               	lda #')'
   863  0655 8f12fc1b           	sta IO_CON_CHAROUT
   864  0659 8f13fc1b           	sta IO_CON_REGISTER
   865  065d a92c               	lda #','
   866  065f 8f12fc1b           	sta IO_CON_CHAROUT
   867  0663 8f13fc1b           	sta IO_CON_REGISTER
   868  0667 a959               	lda #'Y'
   869  0669 8f12fc1b           	sta IO_CON_CHAROUT
   870  066d 8f13fc1b           	sta IO_CON_REGISTER
   871  0671 60                 	rts
   872                          amodc
   873  0672 a924               	lda #'$'
   874  0674 8f12fc1b           	sta IO_CON_CHAROUT
   875  0678 8f13fc1b           	sta IO_CON_REGISTER
   876  067c a00100             	ldy #$0001
   877  067f b73a               	lda [mondump],y
   878  0681 205403             	jsr prhex
   879  0684 a92c               	lda #','
   880  0686 8f12fc1b           	sta IO_CON_CHAROUT
   881  068a 8f13fc1b           	sta IO_CON_REGISTER
   882  068e a958               	lda #'X'
   883  0690 8f12fc1b           	sta IO_CON_CHAROUT
   884  0694 8f13fc1b           	sta IO_CON_REGISTER
   885  0698 60                 	rts
   886                          amodd
   887  0699 a95b               	lda #'['
   888  069b 8f12fc1b           	sta IO_CON_CHAROUT
   889  069f 8f13fc1b           	sta IO_CON_REGISTER
   890  06a3 a924               	lda #'$'
   891  06a5 8f12fc1b           	sta IO_CON_CHAROUT
   892  06a9 8f13fc1b           	sta IO_CON_REGISTER
   893  06ad a00100             	ldy #$0001
   894  06b0 b73a               	lda [mondump],y
   895  06b2 205403             	jsr prhex
   896  06b5 a95d               	lda #']'
   897  06b7 8f12fc1b           	sta IO_CON_CHAROUT
   898  06bb 8f13fc1b           	sta IO_CON_REGISTER
   899  06bf a92c               	lda #','
   900  06c1 8f12fc1b           	sta IO_CON_CHAROUT
   901  06c5 8f13fc1b           	sta IO_CON_REGISTER
   902  06c9 a959               	lda #'Y'
   903  06cb 8f12fc1b           	sta IO_CON_CHAROUT
   904  06cf 8f13fc1b           	sta IO_CON_REGISTER
   905  06d3 60                 	rts
   906                          amode
   907  06d4 a924               	lda #'$'
   908  06d6 8f12fc1b           	sta IO_CON_CHAROUT
   909  06da 8f13fc1b           	sta IO_CON_REGISTER
   910  06de a00200             	ldy #$0002
   911  06e1 b73a               	lda [mondump],y
   912  06e3 205403             	jsr prhex
   913  06e6 88                 	dey
   914  06e7 b73a               	lda [mondump],y
   915  06e9 205403             	jsr prhex
   916  06ec a92c               	lda #','
   917  06ee 8f12fc1b           	sta IO_CON_CHAROUT
   918  06f2 8f13fc1b           	sta IO_CON_REGISTER
   919  06f6 a958               	lda #'X'
   920  06f8 8f12fc1b           	sta IO_CON_CHAROUT
   921  06fc 8f13fc1b           	sta IO_CON_REGISTER
   922  0700 60                 	rts
   923                          amodf
   924  0701 a924               	lda #'$'
   925  0703 8f12fc1b           	sta IO_CON_CHAROUT
   926  0707 8f13fc1b           	sta IO_CON_REGISTER
   927  070b a00200             	ldy #$0002
   928  070e b73a               	lda [mondump],y
   929  0710 205403             	jsr prhex
   930  0713 88                 	dey
   931  0714 b73a               	lda [mondump],y
   932  0716 205403             	jsr prhex
   933  0719 a92c               	lda #','
   934  071b 8f12fc1b           	sta IO_CON_CHAROUT
   935  071f 8f13fc1b           	sta IO_CON_REGISTER
   936  0723 a959               	lda #'Y'
   937  0725 8f12fc1b           	sta IO_CON_CHAROUT
   938  0729 8f13fc1b           	sta IO_CON_REGISTER
   939  072d 60                 	rts
   940                          amod10
   941  072e a924               	lda #'$'
   942  0730 8f12fc1b           	sta IO_CON_CHAROUT
   943  0734 8f13fc1b           	sta IO_CON_REGISTER
   944  0738 a00300             	ldy #$0003
   945  073b b73a               	lda [mondump],y
   946  073d 205403             	jsr prhex
   947  0740 88                 	dey
   948  0741 b73a               	lda [mondump],y
   949  0743 205403             	jsr prhex
   950  0746 88                 	dey
   951  0747 b73a               	lda [mondump],y
   952  0749 205403             	jsr prhex
   953  074c a92c               	lda #','
   954  074e 8f12fc1b           	sta IO_CON_CHAROUT
   955  0752 8f13fc1b           	sta IO_CON_REGISTER
   956  0756 a958               	lda #'X'
   957  0758 8f12fc1b           	sta IO_CON_CHAROUT
   958  075c 8f13fc1b           	sta IO_CON_REGISTER
   959  0760 60                 	rts
   960                          amod12
   961  0761 a928               	lda #'('
   962  0763 8f12fc1b           	sta IO_CON_CHAROUT
   963  0767 8f13fc1b           	sta IO_CON_REGISTER
   964  076b a924               	lda #'$'
   965  076d 8f12fc1b           	sta IO_CON_CHAROUT
   966  0771 8f13fc1b           	sta IO_CON_REGISTER
   967  0775 a00200             	ldy #$0002
   968  0778 b73a               	lda [mondump],y
   969  077a 205403             	jsr prhex
   970  077d 88                 	dey
   971  077e b73a               	lda [mondump],y
   972  0780 205403             	jsr prhex
   973  0783 a929               	lda #')'
   974  0785 8f12fc1b           	sta IO_CON_CHAROUT
   975  0789 8f13fc1b           	sta IO_CON_REGISTER
   976  078d 60                 	rts
   977                          amod13
   978  078e a928               	lda #'('
   979  0790 8f12fc1b           	sta IO_CON_CHAROUT
   980  0794 8f13fc1b           	sta IO_CON_REGISTER
   981  0798 a924               	lda #'$'
   982  079a 8f12fc1b           	sta IO_CON_CHAROUT
   983  079e 8f13fc1b           	sta IO_CON_REGISTER
   984  07a2 a00200             	ldy #$0002
   985  07a5 b73a               	lda [mondump],y
   986  07a7 205403             	jsr prhex
   987  07aa 88                 	dey
   988  07ab b73a               	lda [mondump],y
   989  07ad 205403             	jsr prhex
   990  07b0 a92c               	lda #','
   991  07b2 8f12fc1b           	sta IO_CON_CHAROUT
   992  07b6 8f13fc1b           	sta IO_CON_REGISTER
   993  07ba a958               	lda #'X'
   994  07bc 8f12fc1b           	sta IO_CON_CHAROUT
   995  07c0 8f13fc1b           	sta IO_CON_REGISTER
   996  07c4 a929               	lda #')'
   997  07c6 8f12fc1b           	sta IO_CON_CHAROUT
   998  07ca 8f13fc1b           	sta IO_CON_REGISTER
   999  07ce 60                 	rts
  1000                          amod14
  1001  07cf a924               	lda #'$'
  1002  07d1 8f12fc1b           	sta IO_CON_CHAROUT
  1003  07d5 8f13fc1b           	sta IO_CON_REGISTER
  1004  07d9 a00100             	ldy #$0001
  1005  07dc b73a               	lda [mondump],y
  1006  07de 205403             	jsr prhex
  1007  07e1 a92c               	lda #','
  1008  07e3 8f12fc1b           	sta IO_CON_CHAROUT
  1009  07e7 8f13fc1b           	sta IO_CON_REGISTER
  1010  07eb a959               	lda #'Y'
  1011  07ed 8f12fc1b           	sta IO_CON_CHAROUT
  1012  07f1 8f13fc1b           	sta IO_CON_REGISTER
  1013  07f5 60                 	rts
  1014                          	
  1015                          						;test branches for disassembly purposes..
  1016  07f6 70d7               	bvs amod14
  1017  07f8 7010               	bvs is816
  1018  07fa 7092               	bvs amod13
  1019  07fc 703d               	bvs listamod
  1020  07fe 6260ff             	per amod12
  1021  0801 620600             	per is816
  1022  0804 6227ff             	per amod10
  1023  0807 623100             	per listamod
  1024                          	
  1025                          	!zone is816
  1026                          is816
  1027  080a 48                 	pha
  1028  080b 291f               	and #$1f
  1029  080d c909               	cmp #$09				;09, 29, 49, etc?
  1030  080f d006               	bne .testx
  1031  0811 242d               	bit alarge				;16 bit?
  1032  0813 3020               	bmi .is16
  1033  0815 1018               	bpl .is8
  1034                          .testx
  1035  0817 68                 	pla
  1036  0818 48                 	pha
  1037  0819 c9a0               	cmp #$a0
  1038  081b f00e               	beq .isx
  1039  081d c9a2               	cmp #$a2
  1040  081f f00a               	beq .isx
  1041  0821 c9c0               	cmp #$c0
  1042  0823 f006               	beq .isx
  1043  0825 c9e0               	cmp #$e0
  1044  0827 f002               	beq .isx
  1045  0829 68                 	pla						;made it here, not an accumulator or index instruction
  1046  082a 60                 	rts
  1047                          .isx
  1048  082b 242e               	bit xlarge
  1049  082d 3006               	bmi .is16				;or else fall thru
  1050                          .is8
  1051  082f a902               	lda #$2
  1052  0831 852f               	sta scratch1
  1053  0833 68                 	pla
  1054  0834 60                 	rts
  1055                          .is16
  1056  0835 a903               	lda #$3
  1057  0837 852f               	sta scratch1
  1058  0839 68                 	pla
  1059  083a 60                 	rts
  1060                          	
  1061                          listamod
  1062  083b 9104               	!16 amod0			;$xx
  1063  083d a404               	!16 amod1			;($xx,X)
  1064  083f df04               	!16 amod2			;x,S
  1065  0841 fc04               	!16 amod3			;[$xx]
  1066  0843 2205               	!16 amod4			;implied
  1067  0845 2305               	!16 amod5			;#$xx (or #$yyxx)
  1068  0847 4e05               	!16 amod6			;$yyxx
  1069  0849 6605               	!16 amod7			;$zzyyxx
  1070  084b 9405               	!16 amod8			;rel8
  1071  084d c105               	!16 amod9			;($xx),Y
  1072  084f fc05               	!16 amoda			;($xx)
  1073  0851 2306               	!16 amodb			;(xx,S),Y
  1074  0853 7206               	!16 amodc			;$xx,X
  1075  0855 9906               	!16 amodd			;[$xx],Y
  1076  0857 d406               	!16 amode			;$yyxx,X
  1077  0859 0107               	!16 amodf			;$yyxx,Y
  1078  085b 2e07               	!16 amod10			;$zzyyxx,X
  1079  085d 8405               	!16 amod11			;rel16
  1080  085f 6107               	!16 amod12			;($yyxx)
  1081  0861 8e07               	!16 amod13			;($yyxx,X)
  1082  0863 cf07               	!16 amod14			;$xx,Y
  1083                          	
  1084                          mnemlenmode
  1085  0865 40                 	!byte %01000000		;00 brk 2/$xx
  1086  0866 41                 	!byte %01000001		;01 ora 2/($xx,x)
  1087  0867 40                 	!byte %01000000		;02 cop 2/$xx
  1088  0868 42                 	!byte %01000010		;03 ora 2/x,s
  1089  0869 40                 	!byte %01000000		;04 tsb 2/$xx
  1090  086a 40                 	!byte %01000000		;05 ora 2/$xx
  1091  086b 40                 	!byte %01000000		;06 asl 2/$xx
  1092  086c 43                 	!byte %01000011		;07 ora 2/[$xx]
  1093  086d 24                 	!byte %00100100		;08 php 1
  1094  086e 45                 	!byte %01000101		;09 ora 2/#imm
  1095  086f 24                 	!byte %00100100		;0a asl 1
  1096  0870 24                 	!byte %00100100		;0b phd 1
  1097  0871 66                 	!byte %01100110		;0c tsb 3/$yyxx
  1098  0872 66                 	!byte %01100110		;0d ora 3/$yyxx
  1099  0873 66                 	!byte %01100110		;0e asl 3/$yyxx
  1100  0874 87                 	!byte %10000111		;0f ora 4/$zzyyxx
  1101  0875 48                 	!byte %01001000		;10 bpl 2/rel8
  1102  0876 49                 	!byte %01001001		;11 ora 2/($xx),Y
  1103  0877 4a                 	!byte %01001010		;12 ora 2/($xx)
  1104  0878 4b                 	!byte %01001011		;13 ora 2/(x,s),Y
  1105  0879 40                 	!byte %01000000		;14 trb 2/$xx
  1106  087a 4c                 	!byte %01001100		;15 ora 2/$xx,X
  1107  087b 4c                 	!byte %01001100		;16 asl 2/$xx,X
  1108  087c 4d                 	!byte %01001101		;17 ora 2/[$xx],Y
  1109  087d 24                 	!byte %00100100		;18 clc 1
  1110  087e 6f                 	!byte %01101111		;19 ora 3/$yyxx,Y
  1111  087f 24                 	!byte %00100100		;1a inc 1
  1112  0880 24                 	!byte %00100100		;1b tcs 1
  1113  0881 66                 	!byte %01100110		;1c trb 3/$yyxx
  1114  0882 6e                 	!byte %01101110		;1d ora 3/$yyxx,X
  1115  0883 6e                 	!byte %01101110		;1e asl 3/$yyxx,X
  1116  0884 90                 	!byte %10010000		;1f ora 4/$zzyyxx,X
  1117  0885 66                 	!byte %01100110		;20 jsr 3/$yyxx
  1118  0886 41                 	!byte %01000001		;21 and 2/($xx,x)
  1119  0887 87                 	!byte %10000111		;22 jsl 4/$zzyyxx
  1120  0888 42                 	!byte %01000010		;23 and 2/x,s
  1121  0889 40                 	!byte %01000000		;24 bit 2/$xx
  1122  088a 40                 	!byte %01000000		;25 and 2/$xx
  1123  088b 40                 	!byte %01000000		;26 rol 2/$xx
  1124  088c 43                 	!byte %01000011		;27 and 2/[$xx]
  1125  088d 24                 	!byte %00100100		;28 plp 1
  1126  088e 45                 	!byte %01000101		;29 and 2/#imm
  1127  088f 24                 	!byte %00100100		;2a rol 1
  1128  0890 24                 	!byte %00100100		;2b pld 1
  1129  0891 66                 	!byte %01100110		;2c bit 3/$yyxx
  1130  0892 66                 	!byte %01100110		;2d and 3/$yyxx
  1131  0893 66                 	!byte %01100110		;2e rol 3/$yyxx
  1132  0894 87                 	!byte %10000111		;2f and 4/$zzyyxx
  1133  0895 48                 	!byte %01001000		;30 bmi 2/rel8
  1134  0896 49                 	!byte %01001001		;31 and 2/($xx),Y
  1135  0897 4a                 	!byte %01001010		;32 and 2/($xx)
  1136  0898 4b                 	!byte %01001011		;33 and 2/(x,s),Y
  1137  0899 4c                 	!byte %01001100		;34 bit 2/$xx,X
  1138  089a 4c                 	!byte %01001100		;35 and 2/$xx,X
  1139  089b 4c                 	!byte %01001100		;36 rol 2/$xx,X
  1140  089c 4d                 	!byte %01001101		;37 and 2/[$xx],Y
  1141  089d 24                 	!byte %00100100		;38 sec 1
  1142  089e 6f                 	!byte %01101111		;39 and 3/$yyxx,Y
  1143  089f 24                 	!byte %00100100		;3a dec 1
  1144  08a0 24                 	!byte %00100100		;3b tsc 1
  1145  08a1 6e                 	!byte %01101110		;3c bit 3/$yyxx,X
  1146  08a2 6e                 	!byte %01101110		;3d and 3/$yyxx,X
  1147  08a3 6e                 	!byte %01101110		;3e rol 3/$yyxx,X
  1148  08a4 90                 	!byte %10010000		;3f and 4/$zzyyxx,X
  1149  08a5 24                 	!byte %00100100		;40 ???
  1150  08a6 41                 	!byte %01000001		;41 eor 2/($xx,x)
  1151  08a7 40                 	!byte %01000000		;42 wdm 2/$00
  1152  08a8 42                 	!byte %01000010		;43 eor 2/x,s
  1153  08a9 24                 	!byte %00100100		;44 ???
  1154  08aa 40                 	!byte %01000000		;45 eor 2/$xx
  1155  08ab 40                 	!byte %01000000		;46 lsr 2/$xx
  1156  08ac 43                 	!byte %01000011		;47 eor 2/[$xx]
  1157  08ad 24                 	!byte %00100100		;48 pha 1
  1158  08ae 45                 	!byte %01000101		;49 eor 2/#imm
  1159  08af 24                 	!byte %00100100		;4a lsr 1
  1160  08b0 24                 	!byte %00100100		;4b phk 1
  1161  08b1 66                 	!byte %01100110		;4c jmp 3/$yyxx
  1162  08b2 66                 	!byte %01100110		;4d eor 3/$yyxx
  1163  08b3 66                 	!byte %01100110		;4e lsr 3/$yyxx
  1164  08b4 87                 	!byte %10000111		;4f eor 4/$zzyyxx
  1165  08b5 48                 	!byte %01001000		;50 bvc 2/rel8
  1166  08b6 49                 	!byte %01001001		;51 eor 2/($xx),Y
  1167  08b7 4a                 	!byte %01001010		;52 eor 2/($xx)
  1168  08b8 4b                 	!byte %01001011		;53 eor 2/(x,s),Y
  1169  08b9 24                 	!byte %00100100		;54 ???
  1170  08ba 4c                 	!byte %01001100		;55 eor 2/$xx,X
  1171  08bb 4c                 	!byte %01001100		;56 lsr 2/$xx,X
  1172  08bc 4d                 	!byte %01001101		;57 eor 2/[$xx],Y
  1173  08bd 24                 	!byte %00100100		;58 cli 1
  1174  08be 6f                 	!byte %01101111		;59 eor 3/$yyxx,Y
  1175  08bf 24                 	!byte %00100100		;5a phy 1
  1176  08c0 24                 	!byte %00100100		;5b tcd 1
  1177  08c1 87                 	!byte %10000111		;5c jml 4/$zzyyxx
  1178  08c2 6e                 	!byte %01101110		;5d eor 3/$yyxx,X
  1179  08c3 6e                 	!byte %01101110		;5e lsr 3/$yyxx,X
  1180  08c4 90                 	!byte %10010000		;5f eor 4/$zzyyxx,X
  1181  08c5 24                 	!byte %00100100		;60 rts
  1182  08c6 41                 	!byte %01000001		;61 adc 2/($xx,x)
  1183  08c7 71                 	!byte %01110001		;62 per 3/rel16
  1184  08c8 42                 	!byte %01000010		;63 adc 2/x,s
  1185  08c9 40                 	!byte %01000000		;64 stz 2/$xx
  1186  08ca 40                 	!byte %01000000		;65 adc 2/$xx
  1187  08cb 40                 	!byte %01000000		;66 ror 2/$xx
  1188  08cc 43                 	!byte %01000011		;67 adc 2/[$xx]
  1189  08cd 24                 	!byte %00100100		;68 pla 1
  1190  08ce 45                 	!byte %01000101		;69 adc 2/#imm
  1191  08cf 24                 	!byte %00100100		;6a ror 1
  1192  08d0 24                 	!byte %00100100		;6b rtl 1
  1193  08d1 72                 	!byte %01110010		;6c jmp 3/($yyxx)
  1194  08d2 66                 	!byte %01100110		;6d adc 3/$yyxx
  1195  08d3 66                 	!byte %01100110		;6e ror 3/$yyxx
  1196  08d4 87                 	!byte %10000111		;6f adc 4/$zzyyxx
  1197  08d5 48                 	!byte %01001000		;70 bvs 2/rel8
  1198  08d6 49                 	!byte %01001001		;71 adc 2/($xx),Y
  1199  08d7 4a                 	!byte %01001010		;72 adc 2/($xx)
  1200  08d8 4b                 	!byte %01001011		;73 adc 2/(x,s),Y
  1201  08d9 4c                 	!byte %01001100		;74 stz 2/$xx,X
  1202  08da 4c                 	!byte %01001100		;75 adc 2/$xx,X
  1203  08db 4c                 	!byte %01001100		;76 ror 2/$xx,X
  1204  08dc 4d                 	!byte %01001101		;77 adc 2/[$xx],Y
  1205  08dd 24                 	!byte %00100100		;78 sei 1
  1206  08de 6f                 	!byte %01101111		;79 adc 3/$yyxx,Y
  1207  08df 24                 	!byte %00100100		;7a ply 1
  1208  08e0 24                 	!byte %00100100		;7b tdc 1
  1209  08e1 73                 	!byte %01110011		;7c jmp 3/($yyxx,X)
  1210  08e2 6e                 	!byte %01101110		;7d adc 3/$yyxx,X
  1211  08e3 6e                 	!byte %01101110		;7e lsr 3/$yyxx,X
  1212  08e4 90                 	!byte %10010000		;7f adc 4/$zzyyxx,X
  1213  08e5 48                 	!byte %01001000		;80 bra 2/rel8
  1214  08e6 41                 	!byte %01000001		;81 sta 2/($xx,x)
  1215  08e7 71                 	!byte %01110001		;82 brl 3/rel16
  1216  08e8 42                 	!byte %01000010		;83 sta 2/x,s
  1217  08e9 40                 	!byte %01000000		;84 sty 2/$xx
  1218  08ea 40                 	!byte %01000000		;85 sta 2/$xx
  1219  08eb 40                 	!byte %01000000		;86 stx 2/$xx
  1220  08ec 43                 	!byte %01000011		;87 sta 2/[$xx]
  1221  08ed 24                 	!byte %00100100		;88 dey 1
  1222  08ee 45                 	!byte %01000101		;89 bit 2/#imm
  1223  08ef 24                 	!byte %00100100		;8a txa 1
  1224  08f0 24                 	!byte %00100100		;8b phb 1
  1225  08f1 66                 	!byte %01100110		;8c sty 3/$yyxx
  1226  08f2 66                 	!byte %01100110		;8d sta 3/$yyxx
  1227  08f3 66                 	!byte %01100110		;8e stx 3/$yyxx
  1228  08f4 87                 	!byte %10000111		;8f sta 4/$zzyyxx
  1229  08f5 48                 	!byte %01001000		;90 bcc 2/rel8
  1230  08f6 49                 	!byte %01001001		;91 sta 2/($xx),Y
  1231  08f7 4a                 	!byte %01001010		;92 sta 2/($xx)
  1232  08f8 4b                 	!byte %01001011		;93 sta 2/(x,s),Y
  1233  08f9 4c                 	!byte %01001100		;94 sty 2/$xx,X
  1234  08fa 4c                 	!byte %01001100		;95 sta 2/$xx,X
  1235  08fb 54                 	!byte %01010100		;96 stx 2/$xx,Y
  1236  08fc 4d                 	!byte %01001101		;97 sta 2/[$xx],Y
  1237  08fd 24                 	!byte %00100100		;98 txa 1
  1238  08fe 6f                 	!byte %01101111		;99 sta 3/$yyxx,Y
  1239  08ff 24                 	!byte %00100100		;9a txs 1
  1240  0900 24                 	!byte %00100100		;9b txy 1
  1241  0901 66                 	!byte %01100110		;9c stz 3/$yyxx
  1242  0902 6e                 	!byte %01101110		;9d sta 3/$yyxx,X
  1243  0903 6e                 	!byte %01101110		;9e stz 3/$yyxx,X
  1244  0904 90                 	!byte %10010000		;9f sta 4/$zzyyxx,X
  1245  0905 45                 	!byte %01000101		;a0 ldy 2/#imm
  1246  0906 41                 	!byte %01000001		;a1 lda 2/($xx,x)
  1247  0907 45                 	!byte %01000101		;a2 ldx 2/#imm
  1248  0908 42                 	!byte %01000010		;a3 lda 2/x,s
  1249  0909 40                 	!byte %01000000		;a4 ldy 2/$xx
  1250  090a 40                 	!byte %01000000		;a5 sta 2/$xx
  1251  090b 40                 	!byte %01000000		;a6 ldx 2/$xx
  1252  090c 43                 	!byte %01000011		;a7 lda 2/[$xx]
  1253  090d 24                 	!byte %00100100		;a8 tay 1
  1254  090e 45                 	!byte %01000101		;a9 lda 2/#imm
  1255  090f 24                 	!byte %00100100		;aa tax 1
  1256  0910 24                 	!byte %00100100		;ab plb 1
  1257  0911 66                 	!byte %01100110		;ac ldy 3/$yyxx
  1258  0912 66                 	!byte %01100110		;ad lda 3/$yyxx
  1259  0913 66                 	!byte %01100110		;ae ldx 3/$yyxx
  1260  0914 87                 	!byte %10000111		;af lda 4/$zzyyxx
  1261  0915 48                 	!byte %01001000		;b0 bcs 2/rel8
  1262  0916 49                 	!byte %01001001		;b1 lda 2/($xx),Y
  1263  0917 4a                 	!byte %01001010		;b2 lda 2/($xx)
  1264  0918 4b                 	!byte %01001011		;b3 lda 2/(x,s),Y
  1265  0919 4c                 	!byte %01001100		;b4 ldy 2/$xx,X
  1266  091a 4c                 	!byte %01001100		;b5 lda 2/$xx,X
  1267  091b 54                 	!byte %01010100		;b6 ldx 2/$xx,Y
  1268  091c 4d                 	!byte %01001101		;b7 lda 2/[$xx],Y
  1269  091d 24                 	!byte %00100100		;b8 clv 1
  1270  091e 6f                 	!byte %01101111		;b9 lda 3/$yyxx,Y
  1271  091f 24                 	!byte %00100100		;ba tsx 1
  1272  0920 24                 	!byte %00100100		;bb tyx 1
  1273  0921 66                 	!byte %01100110		;bc ldy 3/$yyxx
  1274  0922 6e                 	!byte %01101110		;bd lda 3/$yyxx,X
  1275  0923 6e                 	!byte %01101110		;be ldx 3/$yyxx,X
  1276  0924 90                 	!byte %10010000		;bf lda 4/$zzyyxx,X
  1277  0925 45                 	!byte %01000101		;c0 cpy 2/#imm
  1278  0926 41                 	!byte %01000001		;c1 cmp 2/($xx,x)
  1279  0927 45                 	!byte %01000101		;c2 rep 2/#imm
  1280  0928 42                 	!byte %01000010		;c3 cmp 2/x,s
  1281  0929 40                 	!byte %01000000		;c4 cpx 2/$xx
  1282  092a 40                 	!byte %01000000		;c5 cmp 2/$xx
  1283  092b 40                 	!byte %01000000		;c6 dec 2/$xx
  1284  092c 43                 	!byte %01000011		;c7 cmp 2/[$xx]
  1285  092d 24                 	!byte %00100100		;c8 iny 1
  1286  092e 45                 	!byte %01000101		;c9 cmp 2/#imm
  1287  092f 24                 	!byte %00100100		;ca dex 1
  1288  0930 24                 	!byte %00100100		;cb wai 1
  1289  0931 66                 	!byte %01100110		;cc cpy 3/$yyxx
  1290  0932 66                 	!byte %01100110		;cd cmp 3/$yyxx
  1291  0933 66                 	!byte %01100110		;ce dec 3/$yyxx
  1292  0934 87                 	!byte %10000111		;cf cmp 4/$zzyyxx
  1293  0935 48                 	!byte %01001000		;d0 bne 2/rel8
  1294  0936 49                 	!byte %01001001		;d1 cmp 2/($xx),Y
  1295  0937 4a                 	!byte %01001010		;d2 cmp 2/($xx)
  1296  0938 4b                 	!byte %01001011		;d3 cmp 2/(x,s),Y
  1297  0939 4a                 	!byte %01001010		;d4 pei 2/($xx)
  1298  093a 4c                 	!byte %01001100		;d5 cmp 2/$xx,X
  1299  093b 4c                 	!byte %01001100		;d6 dec 2/$xx,X
  1300  093c 4d                 	!byte %01001101		;d7 cmp 2/[$xx],Y
  1301  093d 24                 	!byte %00100100		;d8 cld 1
  1302  093e 6f                 	!byte %01101111		;d9 cmp 3/$yyxx,Y
  1303  093f 24                 	!byte %00100100		;da phx 1
  1304  0940 24                 	!byte %00100100		;db stp 1
  1305  0941 43                 	!byte %01000011		;dc jml 2/[$xx]
  1306  0942 6e                 	!byte %01101110		;dd cmp 3/$yyxx,X
  1307  0943 6e                 	!byte %01101110		;de dec 3/$yyxx,X
  1308  0944 90                 	!byte %10010000		;df cmp 4/$zzyyxx,X
  1309  0945 45                 	!byte %01000101		;e0 cpx 2/#imm
  1310  0946 41                 	!byte %01000001		;e1 sbc 2/($xx,x)
  1311  0947 45                 	!byte %01000101		;e2 sep 2/#imm
  1312  0948 42                 	!byte %01000010		;e3 sbc 2/x,s
  1313  0949 40                 	!byte %01000000		;e4 cpx 2/$xx
  1314  094a 40                 	!byte %01000000		;e5 sbc 2/$xx
  1315  094b 40                 	!byte %01000000		;e6 inc 2/$xx
  1316  094c 43                 	!byte %01000011		;e7 sbc 2/[$xx]
  1317  094d 24                 	!byte %00100100		;e8 inx 1
  1318  094e 45                 	!byte %01000101		;e9 sbc 2/#imm
  1319  094f 24                 	!byte %00100100		;ea nop 1
  1320  0950 24                 	!byte %00100100		;eb xba 1
  1321  0951 66                 	!byte %01100110		;ec cpx 3/$yyxx
  1322  0952 66                 	!byte %01100110		;ed sbc 3/$yyxx
  1323  0953 66                 	!byte %01100110		;ee inc 3/$yyxx
  1324  0954 87                 	!byte %10000111		;ef sbc 4/$zzyyxx
  1325  0955 48                 	!byte %01001000		;f0 beq 2/rel8
  1326  0956 49                 	!byte %01001001		;f1 sbc 2/($xx),Y
  1327  0957 4a                 	!byte %01001010		;f2 sbc 2/($xx)
  1328  0958 4b                 	!byte %01001011		;f3 sbc 2/(x,s),Y
  1329  0959 66                 	!byte %01100110		;f4 pea 3/$yyxx
  1330  095a 4c                 	!byte %01001100		;f5 sbc 2/$xx,X
  1331  095b 4c                 	!byte %01001100		;f6 inc 2/$xx,X
  1332  095c 4d                 	!byte %01001101		;f7 sbc 2/[$xx],Y
  1333  095d 24                 	!byte %00100100		;f8 sed 1
  1334  095e 6f                 	!byte %01101111		;f9 sbc 3/$yyxx,Y
  1335  095f 24                 	!byte %00100100		;fa plx 1
  1336  0960 24                 	!byte %00100100		;fb xce 1
  1337  0961 73                 	!byte %01110011		;fc jsr 3/($yyxx)
  1338  0962 6e                 	!byte %01101110		;fd sbc 3/$yyxx,X
  1339  0963 6e                 	!byte %01101110		;fe inc 3/$yyxx,X
  1340  0964 90                 	!byte %10010000		;ff sbc 4/$zzyyxx,X
  1341                          mnemlist
  1342  0965 00                 	!byte $00			;00 brk
  1343  0966 02                 	!byte $02			;01 ora
  1344  0967 01                 	!byte $01			;02 cop
  1345  0968 02                 	!byte $02			;03 ora
  1346  0969 03                 	!byte $03			;04 tsb
  1347  096a 02                 	!byte $02			;05 ora
  1348  096b 04                 	!byte $04			;06 asl
  1349  096c 02                 	!byte $02			;07 ora
  1350  096d 05                 	!byte $05			;08 php
  1351  096e 02                 	!byte $02			;09 ora
  1352  096f 04                 	!byte $04			;0a asl
  1353  0970 06                 	!byte $06			;0b phd
  1354  0971 03                 	!byte $03			;0c tsb
  1355  0972 02                 	!byte $02			;0d ora
  1356  0973 04                 	!byte $04			;0e asl
  1357  0974 02                 	!byte $02			;0f ora
  1358  0975 07                 	!byte $07			;10 bpl
  1359  0976 02                 	!byte $02			;11 ora
  1360  0977 02                 	!byte $02			;12 ora
  1361  0978 02                 	!byte $02			;13 ora
  1362  0979 08                 	!byte $08			;14 trb
  1363  097a 02                 	!byte $02			;15 ora
  1364  097b 04                 	!byte $04			;16 asl
  1365  097c 02                 	!byte $02			;17 ora
  1366  097d 09                 	!byte $09			;18 clc
  1367  097e 02                 	!byte $02			;19 ora
  1368  097f 0a                 	!byte $0a			;1a inc
  1369  0980 0b                 	!byte $0b			;1b tcs
  1370  0981 08                 	!byte $08			;1c trb
  1371  0982 02                 	!byte $02			;1d ora
  1372  0983 04                 	!byte $04			;1e asl
  1373  0984 02                 	!byte $02			;1f ora
  1374  0985 0d                 	!byte $0d			;20 jsr
  1375  0986 0c                 	!byte $0c			;21 and
  1376  0987 0e                 	!byte $0e			;22 jsl
  1377  0988 0c                 	!byte $0c			;23 and
  1378  0989 10                 	!byte $10			;24 bit
  1379  098a 0c                 	!byte $0c			;25 and
  1380  098b 11                 	!byte $11			;26 rol
  1381  098c 0c                 	!byte $0c			;27 and
  1382  098d 12                 	!byte $12			;28 plp
  1383  098e 0c                 	!byte $0c			;29 and
  1384  098f 11                 	!byte $11			;2a rol
  1385  0990 13                 	!byte $13			;2b pld
  1386  0991 10                 	!byte $10			;2c bit
  1387  0992 0c                 	!byte $0c			;2d and
  1388  0993 11                 	!byte $11			;2e rol
  1389  0994 0c                 	!byte $0c			;2f and
  1390  0995 14                 	!byte $14			;30 bmi
  1391  0996 0c                 	!byte $0c			;31 and
  1392  0997 0c                 	!byte $0c			;32 and
  1393  0998 0c                 	!byte $0c			;33 and
  1394  0999 11                 	!byte $11			;34 bit
  1395  099a 0c                 	!byte $0c			;35 and
  1396  099b 11                 	!byte $11			;36 rol
  1397  099c 0c                 	!byte $0c			;37 and
  1398  099d 15                 	!byte $15			;38 sec
  1399  099e 0c                 	!byte $0c			;39 and
  1400  099f 0f                 	!byte $0f			;3a dec
  1401  09a0 16                 	!byte $16			;3b tsc
  1402  09a1 11                 	!byte $11			;3c bit
  1403  09a2 0c                 	!byte $0c			;3d and
  1404  09a3 11                 	!byte $11			;3e rol
  1405  09a4 0c                 	!byte $0c			;3f and
  1406  09a5 17                 	!byte $17			;40 ???
  1407  09a6 18                 	!byte $18			;41 eor
  1408  09a7 19                 	!byte $19			;42 wdm
  1409  09a8 18                 	!byte $18			;43 eor
  1410  09a9 17                 	!byte $17			;44 ???
  1411  09aa 18                 	!byte $18			;45 eor
  1412  09ab 1a                 	!byte $1a			;46 lsr
  1413  09ac 18                 	!byte $18			;47 eor
  1414  09ad 1b                 	!byte $1b			;48 pha
  1415  09ae 18                 	!byte $18			;49 eor
  1416  09af 1a                 	!byte $1a			;4a lsr
  1417  09b0 1c                 	!byte $1c			;4b phk
  1418  09b1 1d                 	!byte $1d			;4c jmp
  1419  09b2 18                 	!byte $18			;4d eor
  1420  09b3 1a                 	!byte $1a			;4e lsr
  1421  09b4 18                 	!byte $18			;4f eor
  1422  09b5 1e                 	!byte $1e			;50 bvc
  1423  09b6 18                 	!byte $18			;51 eor
  1424  09b7 18                 	!byte $18			;52 eor
  1425  09b8 18                 	!byte $18			;53 eor
  1426  09b9 17                 	!byte $17			;54 ???
  1427  09ba 18                 	!byte $18			;55 eor
  1428  09bb 1a                 	!byte $1a			;56 lsr
  1429  09bc 18                 	!byte $18			;57 eor
  1430  09bd 1f                 	!byte $1f			;58 cli
  1431  09be 18                 	!byte $18			;59 eor
  1432  09bf 20                 	!byte $20			;5a phy
  1433  09c0 21                 	!byte $21			;5b tcd
  1434  09c1 22                 	!byte $22			;5c jml
  1435  09c2 18                 	!byte $18			;5d eor
  1436  09c3 1a                 	!byte $1a			;5e lsr
  1437  09c4 18                 	!byte $18			;5f eor
  1438  09c5 23                 	!byte $23			;60 rts
  1439  09c6 24                 	!byte $24			;61 adc
  1440  09c7 25                 	!byte $25			;62 per
  1441  09c8 24                 	!byte $24			;63 adc
  1442  09c9 26                 	!byte $26			;64 stz
  1443  09ca 24                 	!byte $24			;65 adc
  1444  09cb 27                 	!byte $27			;66 ror
  1445  09cc 24                 	!byte $24			;67 adc
  1446  09cd 28                 	!byte $28			;68 pla
  1447  09ce 24                 	!byte $24			;69 adc
  1448  09cf 27                 	!byte $27			;6a ror
  1449  09d0 29                 	!byte $29			;6b rtl
  1450  09d1 1d                 	!byte $1d			;6c jmp
  1451  09d2 24                 	!byte $24			;6d adc
  1452  09d3 27                 	!byte $27			;6e ror
  1453  09d4 24                 	!byte $24			;6f adc
  1454  09d5 2a                 	!byte $2a			;70 bvs
  1455  09d6 24                 	!byte $24			;71 adc
  1456  09d7 24                 	!byte $24			;72 adc
  1457  09d8 24                 	!byte $24			;73 adc
  1458  09d9 26                 	!byte $26			;74 stz
  1459  09da 24                 	!byte $24			;75 adc
  1460  09db 27                 	!byte $27			;76 ror
  1461  09dc 24                 	!byte $24			;77 adc
  1462  09dd 2b                 	!byte $2b			;78 sei
  1463  09de 24                 	!byte $24			;79 adc
  1464  09df 2c                 	!byte $2c			;7a ply
  1465  09e0 2d                 	!byte $2d			;7b tdc
  1466  09e1 1d                 	!byte $1d			;7c jmp
  1467  09e2 24                 	!byte $24			;7d adc
  1468  09e3 27                 	!byte $27			;7e ror
  1469  09e4 24                 	!byte $24			;7f adc
  1470  09e5 2e                 	!byte $2e			;80 bra
  1471  09e6 2f                 	!byte $2f			;81 sta
  1472  09e7 30                 	!byte $30			;82 brl
  1473  09e8 2f                 	!byte $2f			;83 sta
  1474  09e9 31                 	!byte $31			;84 sty
  1475  09ea 2f                 	!byte $2f			;85 sta
  1476  09eb 32                 	!byte $32			;86 stx
  1477  09ec 2f                 	!byte $2f			;87 sta
  1478  09ed 33                 	!byte $33			;88 dey
  1479  09ee 10                 	!byte $10			;89 bit
  1480  09ef 34                 	!byte $34			;8a txa
  1481  09f0 35                 	!byte $35			;8b phb
  1482  09f1 31                 	!byte $31			;8c sty
  1483  09f2 2f                 	!byte $2f			;8d sta
  1484  09f3 32                 	!byte $32			;8e stx
  1485  09f4 2f                 	!byte $2f			;8f sta
  1486  09f5 36                 	!byte $36			;90 bcc
  1487  09f6 2f                 	!byte $2f			;91 sta
  1488  09f7 2f                 	!byte $2f			;92 sta
  1489  09f8 2f                 	!byte $2f			;93 sta
  1490  09f9 31                 	!byte $31			;94 sty
  1491  09fa 2f                 	!byte $2f			;95 sta
  1492  09fb 32                 	!byte $32			;96 stx
  1493  09fc 2f                 	!byte $2f			;97 sta
  1494  09fd 37                 	!byte $37			;98 tya
  1495  09fe 2f                 	!byte $2f			;99 sta
  1496  09ff 38                 	!byte $38			;9a txs
  1497  0a00 39                 	!byte $39			;9b txy
  1498  0a01 26                 	!byte $26			;9c stz
  1499  0a02 2f                 	!byte $2f			;9d sta
  1500  0a03 26                 	!byte $26			;9e stz
  1501  0a04 2f                 	!byte $2f			;9f sta
  1502  0a05 3c                 	!byte $3c			;a0 ldy
  1503  0a06 3a                 	!byte $3a			;a1 lda
  1504  0a07 3b                 	!byte $3b			;a2 ldx
  1505  0a08 3a                 	!byte $3a			;a3 lda
  1506  0a09 3c                 	!byte $3c			;a4 ldy
  1507  0a0a 3a                 	!byte $3a			;a5 lda
  1508  0a0b 3b                 	!byte $3b			;a6 ldx
  1509  0a0c 3a                 	!byte $3a			;a7 lda
  1510  0a0d 3d                 	!byte $3d			;a8 tay
  1511  0a0e 3a                 	!byte $3a			;a9 lda
  1512  0a0f 3e                 	!byte $3e			;aa tax
  1513  0a10 3f                 	!byte $3f			;ab plb
  1514  0a11 3c                 	!byte $3c			;ac ldy
  1515  0a12 3a                 	!byte $3a			;ad lda
  1516  0a13 3b                 	!byte $3b			;ae ldx
  1517  0a14 3a                 	!byte $3a			;af lda
  1518  0a15 40                 	!byte $40			;b0 bcs
  1519  0a16 3a                 	!byte $3a			;b1 lda
  1520  0a17 3a                 	!byte $3a			;b2 lda
  1521  0a18 3a                 	!byte $3a			;b3 lda
  1522  0a19 3c                 	!byte $3c			;b4 ldy
  1523  0a1a 3a                 	!byte $3a			;b5 lda
  1524  0a1b 3b                 	!byte $3b			;b6 ldx
  1525  0a1c 3a                 	!byte $3a			;b7 lda
  1526  0a1d 41                 	!byte $41			;b8 clv
  1527  0a1e 3a                 	!byte $3a			;b9 lda
  1528  0a1f 42                 	!byte $42			;ba tsx
  1529  0a20 43                 	!byte $43			;bb tyx
  1530  0a21 3c                 	!byte $3c			;bc ldy
  1531  0a22 3a                 	!byte $3a			;bd lda
  1532  0a23 3b                 	!byte $3b			;be ldx
  1533  0a24 3a                 	!byte $3a			;bf lda
  1534  0a25 46                 	!byte $46			;c0 cpy
  1535  0a26 44                 	!byte $44			;c1 cmp
  1536  0a27 47                 	!byte $47			;c2 rep
  1537  0a28 44                 	!byte $44			;c3 cmp
  1538  0a29 46                 	!byte $46			;c4 cpy
  1539  0a2a 44                 	!byte $44			;c5 cmp
  1540  0a2b 48                 	!byte $48			;c6 dec
  1541  0a2c 44                 	!byte $44			;c7 cmp
  1542  0a2d 49                 	!byte $49			;c8 iny
  1543  0a2e 44                 	!byte $44			;c9 cmp
  1544  0a2f 4a                 	!byte $4a			;ca dex
  1545  0a30 4b                 	!byte $4b			;cb wai
  1546  0a31 46                 	!byte $46			;cc cpy
  1547  0a32 44                 	!byte $44			;cd cmp
  1548  0a33 48                 	!byte $48			;ce dec
  1549  0a34 44                 	!byte $44			;cf cmp
  1550  0a35 4c                 	!byte $4c			;d0 bne
  1551  0a36 44                 	!byte $44			;d1 cmp
  1552  0a37 44                 	!byte $44			;d2 cmp
  1553  0a38 44                 	!byte $44			;d3 cmp
  1554  0a39 4d                 	!byte $4d			;d4 pei
  1555  0a3a 44                 	!byte $44			;d5 cmp
  1556  0a3b 48                 	!byte $48			;d6 dec
  1557  0a3c 44                 	!byte $44			;d7 cmp
  1558  0a3d 4e                 	!byte $4e			;d8 cld
  1559  0a3e 44                 	!byte $44			;d9 cmp
  1560  0a3f 4f                 	!byte $4f			;da phx
  1561  0a40 50                 	!byte $50			;db stp
  1562  0a41 22                 	!byte $22			;dc jml
  1563  0a42 44                 	!byte $44			;dd cmp
  1564  0a43 48                 	!byte $48			;de dec
  1565  0a44 44                 	!byte $44			;df cmp
  1566  0a45 51                 	!byte $51			;e0 cpx
  1567  0a46 45                 	!byte $45			;e1 sbc
  1568  0a47 52                 	!byte $52			;e2 sep
  1569  0a48 45                 	!byte $45			;e3 sbc
  1570  0a49 51                 	!byte $51			;e4 cpx
  1571  0a4a 45                 	!byte $45			;e5 sbc
  1572  0a4b 53                 	!byte $53			;e6 inc
  1573  0a4c 45                 	!byte $45			;e7 sbc
  1574  0a4d 54                 	!byte $54			;e8 inx
  1575  0a4e 45                 	!byte $45			;e9 sbc
  1576  0a4f 55                 	!byte $55			;ea nop
  1577  0a50 56                 	!byte $56			;eb xba
  1578  0a51 51                 	!byte $51			;ec cpx
  1579  0a52 45                 	!byte $45			;ed sbc
  1580  0a53 53                 	!byte $53			;ee inc
  1581  0a54 45                 	!byte $45			;ef sbc
  1582  0a55 57                 	!byte $57			;f0 beq
  1583  0a56 45                 	!byte $45			;f1 sbc
  1584  0a57 45                 	!byte $45			;f2 sbc
  1585  0a58 45                 	!byte $45			;f3 sbc
  1586  0a59 58                 	!byte $58			;f4 pea
  1587  0a5a 45                 	!byte $45			;f5 sbc
  1588  0a5b 53                 	!byte $53			;f6 inc
  1589  0a5c 45                 	!byte $45			;f7 sbc
  1590  0a5d 59                 	!byte $59			;f8 sed
  1591  0a5e 45                 	!byte $45			;f9 sbc
  1592  0a5f 5a                 	!byte $5a			;fa plx
  1593  0a60 5b                 	!byte $5b			;fb xce
  1594  0a61 0d                 	!byte $0d			;fc jsr
  1595  0a62 45                 	!byte $45			;fd sbc
  1596  0a63 53                 	!byte $53			;fe inc
  1597  0a64 45                 	!byte $45			;ff sbc
  1598                          mnems
  1599  0a65 42524b             	!tx "BRK"			;0
  1600  0a68 434f50             	!tx "COP"			;1
  1601  0a6b 4f5241             	!tx "ORA"			;2
  1602  0a6e 545342             	!tx "TSB"			;3
  1603  0a71 41534c             	!tx "ASL"			;4
  1604  0a74 504850             	!tx "PHP"			;5
  1605  0a77 504844             	!tx "PHD"			;6
  1606  0a7a 42504c             	!tx "BPL"			;7
  1607  0a7d 545242             	!tx "TRB"			;8
  1608  0a80 434c43             	!tx "CLC"			;9
  1609  0a83 494e43             	!tx "INC"			;a
  1610  0a86 544353             	!tx "TCS"			;b
  1611  0a89 414e44             	!tx "AND"			;c
  1612  0a8c 4a5352             	!tx "JSR"			;d
  1613  0a8f 4a534c             	!tx "JSL"			;e
  1614  0a92 444543             	!tx "DEC"			;f
  1615  0a95 424954             	!tx "BIT"			;10
  1616  0a98 524f4c             	!tx "ROL"			;11
  1617  0a9b 504c50             	!tx "PLP"			;12
  1618  0a9e 504c44             	!tx "PLD"			;13
  1619  0aa1 424d49             	!tx "BMI"			;14
  1620  0aa4 534543             	!tx "SEC"			;15
  1621  0aa7 545343             	!tx "TSC"			;16
  1622  0aaa 3f3f3f             	!tx "???"			;17
  1623  0aad 454f52             	!tx "EOR"			;18
  1624  0ab0 57444d             	!tx "WDM"			;19
  1625  0ab3 4c5352             	!tx "LSR"			;1a
  1626  0ab6 504841             	!tx "PHA"			;1b
  1627  0ab9 50484b             	!tx "PHK"			;1c
  1628  0abc 4a4d50             	!tx "JMP"			;1d
  1629  0abf 425643             	!tx "BVC"			;1e
  1630  0ac2 434c49             	!tx "CLI"			;1f
  1631  0ac5 504859             	!tx "PHY"			;20
  1632  0ac8 544344             	!tx "TCD"			;21
  1633  0acb 4a4d4c             	!tx "JML"			;22
  1634  0ace 525453             	!tx "RTS"			;23
  1635  0ad1 414443             	!tx "ADC"			;24
  1636  0ad4 504552             	!tx "PER"			;25
  1637  0ad7 53545a             	!tx "STZ"			;26
  1638  0ada 524f52             	!tx "ROR"			;27
  1639  0add 504c41             	!tx "PLA"			;28
  1640  0ae0 52544c             	!tx "RTL"			;29
  1641  0ae3 425653             	!tx "BVS"			;2a
  1642  0ae6 534549             	!tx "SEI"			;2b
  1643  0ae9 504c59             	!tx "PLY"			;2c
  1644  0aec 544443             	!tx "TDC"			;2d
  1645  0aef 425241             	!tx "BRA"			;2e
  1646  0af2 535441             	!tx "STA"			;2f
  1647  0af5 42524c             	!tx "BRL"			;30
  1648  0af8 535459             	!tx "STY"			;31
  1649  0afb 535458             	!tx "STX"			;32
  1650  0afe 444559             	!tx "DEY"			;33
  1651  0b01 545841             	!tx "TXA"			;34
  1652  0b04 504842             	!tx "PHB"			;35
  1653  0b07 424343             	!tx "BCC"			;36
  1654  0b0a 545941             	!tx "TYA"			;37
  1655  0b0d 545853             	!tx "TXS"			;38
  1656  0b10 545859             	!tx "TXY"			;39
  1657  0b13 4c4441             	!tx "LDA"			;3a
  1658  0b16 4c4458             	!tx "LDX"			;3b
  1659  0b19 4c4459             	!tx "LDY"			;3c
  1660  0b1c 544159             	!tx "TAY"			;3d
  1661  0b1f 544158             	!tx "TAX"			;3e
  1662  0b22 504c42             	!tx "PLB"			;3f
  1663  0b25 424353             	!tx "BCS"			;40
  1664  0b28 434c56             	!tx "CLV"			;41
  1665  0b2b 545358             	!tx "TSX"			;42
  1666  0b2e 545958             	!tx "TYX"			;43
  1667  0b31 434d50             	!tx "CMP"			;44
  1668  0b34 534243             	!tx "SBC"			;45
  1669  0b37 435059             	!tx "CPY"			;46
  1670  0b3a 524550             	!tx "REP"			;47
  1671  0b3d 444543             	!tx "DEC"			;48
  1672  0b40 494e59             	!tx "INY"			;49
  1673  0b43 444558             	!tx "DEX"			;4a
  1674  0b46 574149             	!tx "WAI"			;4b
  1675  0b49 424e45             	!tx "BNE"			;4c
  1676  0b4c 504549             	!tx "PEI"			;4d
  1677  0b4f 434c44             	!tx "CLD"			;4e
  1678  0b52 504858             	!tx "PHX"			;4f
  1679  0b55 535450             	!tx "STP"			;50
  1680  0b58 435058             	!tx "CPX"			;51
  1681  0b5b 534550             	!tx "SEP"			;52
  1682  0b5e 494e43             	!tx "INC"			;53
  1683  0b61 494e58             	!tx "INX"			;54
  1684  0b64 4e4f50             	!tx "NOP"			;55
  1685  0b67 584241             	!tx "XBA"			;56
  1686  0b6a 424551             	!tx "BEQ"			;57
  1687  0b6d 504541             	!tx "PEA"			;58
  1688  0b70 534544             	!tx "SED"			;59
  1689  0b73 504c58             	!tx "PLX"			;5a
  1690  0b76 584345             	!tx "XCE"			;5b
  1691                          	
  1692                          	!zone ucline
  1693                          ucline					;convert inbuff at $170400 to upper case
  1694  0b79 08                 	php
  1695  0b7a c210               	rep #$10
  1696  0b7c e220               	sep #$20
  1697                          	!as
  1698                          	!rl
  1699  0b7e a20000             	ldx #$0000
  1700                          .local2
  1701  0b81 bf000417           	lda inbuff,x
  1702  0b85 f012               	beq .local4			;hit the zero, so bail
  1703  0b87 c961               	cmp #'a'
  1704  0b89 900b               	bcc .local3			;less then lowercase a, so ignore
  1705  0b8b c97b               	cmp #'z' + 1		;less than next character after lowercase z?
  1706  0b8d b007               	bcs .local3			;greater than or equal, so ignore
  1707  0b8f 38                 	sec
  1708  0b90 e920               	sbc #('z' - 'Z')	;make upper case
  1709  0b92 9f000417           	sta inbuff,x
  1710                          .local3
  1711  0b96 e8                 	inx
  1712  0b97 80e8               	bra .local2
  1713                          .local4
  1714  0b99 28                 	plp
  1715  0b9a 6b                 	rtl
  1716                          	
  1717                          	!zone getline
  1718                          getline
  1719  0b9b 08                 	php
  1720  0b9c c210               	rep #$10
  1721  0b9e e220               	sep #$20
  1722                          	!as
  1723                          	!rl
  1724  0ba0 a20000             	ldx #$0000
  1725                          .local2
  1726  0ba3 af00fc1b           	lda IO_KEYQ_SIZE
  1727  0ba7 f0fa               	beq .local2
  1728  0ba9 af01fc1b           	lda IO_KEYQ_WAITING
  1729  0bad 8f02fc1b           	sta IO_KEYQ_DEQUEUE
  1730  0bb1 c90d               	cmp #$0d			;carriage return yet?
  1731  0bb3 f01c               	beq .local3
  1732  0bb5 c908               	cmp #$08			;backspace/back arrow?
  1733  0bb7 f029               	beq .local4
  1734  0bb9 c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
  1735  0bbb 90e6               	bcc .local2		 		;yes, so ignore it
  1736  0bbd 9f000417           	sta inbuff,x 		;any other character, so register it and store it
  1737  0bc1 8f12fc1b           	sta IO_CON_CHAROUT
  1738  0bc5 8f13fc1b           	sta IO_CON_REGISTER
  1739  0bc9 e8                 	inx
  1740  0bca a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
  1741  0bcc e0fe03             	cpx #$3fe			;overrun end of buffer yet?
  1742  0bcf d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
  1743                          .local3
  1744  0bd1 9f000417           	sta inbuff,x		;store CR
  1745  0bd5 8f17fc1b           	sta IO_CON_CR
  1746  0bd9 e8                 	inx
  1747  0bda a900               	lda #$00			;store zero to end it all
  1748  0bdc 9f000417           	sta inbuff,x
  1749  0be0 28                 	plp
  1750  0be1 6b                 	rtl
  1751                          .local4
  1752  0be2 e00000             	cpx #$0000
  1753  0be5 f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
  1754  0be7 a908               	lda #$08
  1755  0be9 8f12fc1b           	sta IO_CON_CHAROUT
  1756  0bed 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
  1757  0bf1 a920               	lda #$20
  1758  0bf3 8f12fc1b           	sta IO_CON_CHAROUT
  1759  0bf7 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
  1760  0bfb a908               	lda #$08
  1761  0bfd 8f12fc1b           	sta IO_CON_CHAROUT
  1762  0c01 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
  1763  0c05 ca                 	dex
  1764  0c06 809b               	bra .local2
  1765                          	
  1766                          prinbuff				;feed location of input buffer into dpla and then print
  1767  0c08 08                 	php
  1768  0c09 c210               	rep #$10
  1769  0c0b e220               	sep #$20
  1770                          	!as
  1771                          	!rl
  1772  0c0d a917               	lda #$17
  1773  0c0f 853f               	sta dpla_h
  1774  0c11 a904               	lda #$04
  1775  0c13 853e               	sta dpla_m
  1776  0c15 643d               	stz dpla
  1777  0c17 221d0c1c           	jsl l_prcdpla
  1778  0c1b 28                 	plp
  1779  0c1c 6b                 	rtl
  1780                          	
  1781                          	!zone prcdpla
  1782                          prcdpla					; print C string pointed to by dp locations $3d-$3f
  1783  0c1d 08                 	php
  1784  0c1e c210               	rep #$10
  1785  0c20 e220               	sep #$20
  1786                          	!as
  1787                          	!rl
  1788  0c22 a00000             	ldy #$0000
  1789                          .local2
  1790  0c25 b73d               	lda [dpla],y
  1791  0c27 f00b               	beq .local3
  1792  0c29 8f12fc1b           	sta IO_CON_CHAROUT
  1793  0c2d 8f13fc1b           	sta IO_CON_REGISTER
  1794  0c31 c8                 	iny
  1795  0c32 80f1               	bra .local2
  1796                          .local3
  1797  0c34 28                 	plp
  1798  0c35 6b                 	rtl
  1799                          
  1800                          initstring
  1801  0c36 494d4c2036353831...	!tx "IML 65816 1C Firmware v00"
  1802  0c4f 0d                 	!byte 0x0d
  1803  0c50 53797374656d204d...	!tx "System Monitor"
  1804  0c5e 0d                 	!byte 0x0d
  1805  0c5f 0d                 	!byte 0x0d
  1806  0c60 00                 	!byte 0
  1807                          
  1808                          helpmsg
  1809  0c61 494d4c2036353831...	!tx "IML 65816 Monitor Commands"
  1810  0c7b 0d                 	!byte $0d
  1811  0c7c 41203c616464723e...	!tx "A <addr>  Dump ASCII"
  1812  0c90 0d                 	!byte $0d
  1813  0c91 42203c62616e6b3e...	!tx "B <bank>  Change bank"
  1814  0ca6 0d                 	!byte $0d
  1815  0ca7 43203c636f6c6f72...	!tx "C <color> Change terminal colors"
  1816  0cc7 0d                 	!byte $0d
  1817  0cc8 44203c616464723e...	!tx "D <addr>  Dump hex"
  1818  0cda 0d                 	!byte $0d
  1819  0cdb 45203c616464723e...	!tx "E <addr> <byte> <byte>...  Enter bytes"
  1820  0d01 0d                 	!byte $0d
  1821  0d02 4c203c616464723e...	!tx "L <addr>  Disassemble 65816 Instructions"
  1822  0d2a 0d                 	!byte $0d
  1823  0d2b 4d203c6d6f64653e...	!tx "M <mode>  Change video mode, 8/9"
  1824  0d4b 0d                 	!byte $0d
  1825  0d4c 5120202020202020...	!tx "Q         Halt the processor"
  1826  0d68 0d                 	!byte $0d
  1827  0d69 3f20202020202020...	!tx "?         This menu"
  1828  0d7c 0d                 	!byte $0d
  1829  0d7d 3c656e7465723e20...	!tx "<enter>   Repeat last dump command"
  1830  0d9f 0d                 	!byte $0d
  1831  0da0 546f207370656369...	!tx "To specify range, use <addr1.addr2>"
  1832  0dc3 0d00               	!byte $0d, 00
  1833                          	
  1834  0dc5 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
  1835                          
