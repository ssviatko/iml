
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
    22                          IO_FP_INIT_CONSTANT = $1bfc40
    23                          IO_FP_TO_ASCII = $1bfc41
    24                          IO_FP_MULTIPLY = $1bfc42
    25                          IO_FP_DIVIDE = $1bfc43
    26                          IO_FP_ADD = $1bfc44
    27                          IO_FP_SUBTRACT = $1bfc45
    28                          IO_FP_LN = $1bfc46
    29                          IO_FP_ILOAD = $1bfc47
    30                          
    31                          FPCOND = $1bfcbf
    32                          FPASCII = $1bfcc0
    33                          FPASCII_LO16 = $fcc0
    34                          FPINT = $1bfcd8
    35                          FPACCUMULATOR = $1bfce0
    36                          FPARGUMENT = $1bfcf0
    37                          
    38                          promptchar = '*'
    39                          
    40                          l_getline = $1c0000 + getline
    41                          l_prinbuff = $1c0000 + prinbuff
    42                          l_prcdpla = $1c0000 + prcdpla
    43                          l_ucline = $1c0000 + ucline
    44                          
    45                          fpregspec = $28
    46                          fpmask = $29
    47                          scratch2 = $2a
    48                          scratch2_m = $2b
    49                          scratch2_h = $2c
    50                          alarge = $2d
    51                          xlarge = $2e
    52                          scratch1 = $2f
    53                          enterbytes = $30
    54                          enterbytes_m = $31
    55                          enterbytes_h = $32
    56                          rangehigh = $33
    57                          monrange = $35
    58                          monlast = $36
    59                          parseptr = $37
    60                          parseptr_m = $38
    61                          parseptr_h = $39
    62                          mondump = $3a
    63                          mondump_m = $3b
    64                          mondump_h = $3c
    65                          dpla = $3d
    66                          dpla_m = $3e
    67                          dpla_h = $3f
    68                          
    69                          inbuff = $170400
    70                          
    71                          x1crominit
    72  0000 4b                 	phk
    73  0001 ab                 	plb
    74  0002 c210               	rep #$10
    75                          	!rl
    76  0004 e220               	sep #$20
    77                          	!as
    78  0006 a29f0e             	ldx #initstring
    79  0009 863d               	stx dpla
    80  000b a91c               	lda #$1c
    81  000d 853f               	sta dpla_h
    82  000f 22860e1c           	jsl l_prcdpla
    83  0013 4cbc03             	jmp+2 monstart
    84                          
    85                          parse_setup
    86  0016 a20004             	ldx #$0400
    87  0019 8637               	stx parseptr
    88  001b a917               	lda #$17
    89  001d 8539               	sta parseptr_h
    90  001f 60                 	rts
    91                          	
    92                          	!zone parse_getchar
    93                          parse_getchar			;get char from inbuff, assumes 8 bit A, 16 bit X
    94  0020 a737               	lda [parseptr]
    95  0022 48                 	pha
    96  0023 e637               	inc parseptr
    97  0025 d006               	bne .local2
    98  0027 e638               	inc parseptr_m
    99  0029 d002               	bne .local2
   100  002b e639               	inc parseptr_h
   101                          .local2
   102  002d 68                 	pla
   103  002e 60                 	rts
   104                          	
   105                          	!zone parse_addr
   106                          parse_addr				;see if user specified an address on line.
   107  002f a900               	lda #$00
   108  0031 48                 	pha
   109  0032 48                 	pha					;make space for working value on the stack
   110  0033 8535               	sta monrange		;clear range flag
   111                          .throwaway
   112  0035 202000             	jsr+2 parse_getchar
   113  0038 c920               	cmp #' '
   114  003a f0f9               	beq .throwaway		;throw away leading spaces
   115  003c 209800             	jsr+2 parse_getnib2	;get first nibble. call 2nd entry point since we already have character
   116  003f 9051               	bcc .no				;didn't even get one hex character, so return false
   117  0041 8301               	sta 1,s				;save it on the stack for now
   118  0043 209500             	jsr+2 parse_getnib	;get second nibble
   119  0046 9047               	bcc .yes			;if not hex then bail
   120  0048 48                 	pha
   121  0049 a302               	lda 2,s
   122  004b 0a                 	asl
   123  004c 0a                 	asl
   124  004d 0a                 	asl
   125  004e 0a                 	asl
   126  004f 0301               	ora 1,s
   127  0051 8302               	sta 2,s
   128  0053 68                 	pla					;add to stack
   129  0054 209500             	jsr+2 parse_getnib	;get possible third nibble
   130  0057 9036               	bcc .yes
   131  0059 c230               	rep #$30			;we're dealing with a 16 bit value now
   132                          	!al
   133  005b 290f00             	and #$000f
   134  005e 48                 	pha
   135  005f a303               	lda 3,s
   136  0061 0a                 	asl
   137  0062 0a                 	asl
   138  0063 0a                 	asl
   139  0064 0a                 	asl
   140  0065 0301               	ora 1,s
   141  0067 8303               	sta 3,s
   142  0069 68                 	pla
   143  006a e220               	sep #$20
   144                          	!as
   145  006c 209500             	jsr+2 parse_getnib
   146  006f 901e               	bcc .yes
   147  0071 c230               	rep #$30
   148                          	!al
   149  0073 290f00             	and #$000f
   150  0076 48                 	pha
   151  0077 a303               	lda 3,s
   152  0079 0a                 	asl
   153  007a 0a                 	asl
   154  007b 0a                 	asl
   155  007c 0a                 	asl
   156  007d 0301               	ora 1,s
   157  007f 8303               	sta 3,s
   158  0081 68                 	pla
   159  0082 e220               	sep #$20			;fall thru to yes on 4th nibble
   160                          	!as
   161  0084 202000             	jsr parse_getchar	;check to see if next char is a . so we can specify ranges
   162  0087 c92e               	cmp #'.'
   163  0089 d004               	bne .yes
   164  008b a980               	lda #$80
   165  008d 8535               	sta monrange
   166                          .yes
   167  008f 7a                 	ply					;get 16 bit work address off of stack
   168  0090 38                 	sec					;got address, return
   169  0091 60                 	rts
   170                          .no
   171  0092 7a                 	ply					;clear stack
   172  0093 18                 	clc					;no address found, return
   173  0094 60                 	rts
   174                          parse_getnib
   175  0095 202000             	jsr parse_getchar
   176                          parse_getnib2			;enter here after we've thrown away leading spaces
   177  0098 c920               	cmp #' '
   178  009a f021               	beq .outrng			;space = end of value
   179  009c c92e               	cmp #'.'
   180  009e d006               	bne .notrange
   181  00a0 a980               	lda #$80
   182  00a2 8535               	sta monrange		;this is the start of a range specification
   183  00a4 18                 	clc
   184  00a5 60                 	rts
   185                          .notrange
   186  00a6 c941               	cmp #$41
   187  00a8 900b               	bcc .outrnga
   188  00aa c947               	cmp #$47
   189  00ac b007               	bcs .outrnga
   190  00ae 38                 	sec
   191  00af e907               	sbc #$07			;in range of A-F
   192                          .success
   193  00b1 290f               	and #$0f
   194  00b3 38                 	sec
   195  00b4 60                 	rts
   196                          .outrnga				;test if 0-9
   197  00b5 c930               	cmp #$30
   198  00b7 9004               	bcc .outrng
   199  00b9 c93a               	cmp #$3a
   200  00bb 90f4               	bcc .success		;less than 3a, but >= 30, else fall thru to outrng
   201                          .outrng
   202  00bd 18                 	clc
   203  00be 60                 	rts
   204                          	
   205                          prdumpaddr
   206  00bf a53c               	lda mondump_h			;print long address
   207  00c1 20bd05             	jsr+2 prhex
   208  00c4 a92f               	lda #'/'
   209  00c6 8f12fc1b           	sta IO_CON_CHAROUT
   210  00ca 8f13fc1b           	sta IO_CON_REGISTER
   211  00ce a63a               	ldx mondump
   212  00d0 20b305             	jsr+2 prhex16
   213  00d3 a92d               	lda #'-'
   214  00d5 8f12fc1b           	sta IO_CON_CHAROUT
   215  00d9 8f13fc1b           	sta IO_CON_REGISTER
   216  00dd a920               	lda #' '
   217  00df 8f12fc1b           	sta IO_CON_CHAROUT
   218  00e3 8f13fc1b           	sta IO_CON_REGISTER
   219  00e7 60                 	rts
   220                          	
   221                          adjdumpaddr					;add 8 to dump address
   222  00e8 c230               	rep #$30
   223                          	!al
   224  00ea a53a               	lda mondump
   225  00ec 18                 	clc
   226  00ed 690800             	adc #$0008
   227  00f0 853a               	sta mondump
   228  00f2 e220               	sep #$20
   229                          	!as
   230  00f4 08                 	php						;save carry state.. did we carry to the bank?
   231  00f5 a53c               	lda mondump_h
   232  00f7 6900               	adc #$00
   233  00f9 853c               	sta mondump_h
   234  00fb 28                 	plp
   235  00fc 60                 	rts
   236                          
   237                          	!zone fpcmd
   238                          fphelp
   239  00fd a24d10             	ldx #fphelpmsg
   240  0100 863d               	stx dpla
   241  0102 a91c               	lda #$1c
   242  0104 853f               	sta dpla_h
   243  0106 22860e1c           	jsl l_prcdpla
   244  010a 4ccf03             	jmp moncmd
   245                          fpcmd
   246  010d 202000             	jsr parse_getchar
   247  0110 c93f               	cmp #'?'
   248  0112 f0e9               	beq fphelp
   249  0114 c944               	cmp #'D'
   250  0116 d003               	bne .fpcmd1
   251  0118 4c4c02             	jmp fpdisp
   252                          .fpcmd1
   253  011b c943               	cmp #'C'
   254  011d d003               	bne .fpcmd2
   255  011f 4c2702             	jmp fploadconst
   256                          .fpcmd2
   257  0122 c92a               	cmp #'*'
   258  0124 d003               	bne .fpcmd6
   259  0126 4cbb01             	jmp fpmultiply
   260                          .fpcmd6
   261  0129 c92f               	cmp #'/'
   262  012b d003               	bne .fpcmd5
   263  012d 4cd601             	jmp fpdivide
   264                          .fpcmd5
   265  0130 c92b               	cmp #'+'
   266  0132 d003               	bne .fpcmd4
   267  0134 4cf101             	jmp fpadd
   268                          .fpcmd4
   269  0137 c92d               	cmp #'-'
   270  0139 d003               	bne .fpcmd3
   271  013b 4c0c02             	jmp fpsubtract
   272                          .fpcmd3
   273  013e c94e               	cmp #'N'
   274  0140 f05e               	beq fpln
   275  0142 c949               	cmp #'I'
   276  0144 f03f               	beq fpiload
   277  0146 4c6703             	jmp monerror			;unrecognized FP command so fall thru to syntax error
   278                          
   279                          fpgetmask					;construct mask from size specifier, carry set if unregognized
   280  0149 202000             	jsr parse_getchar
   281  014c c946               	cmp #'F'
   282  014e d006               	bne .local1
   283  0150 a900               	lda #$00
   284  0152 8529               	sta fpmask				;set bits 5/7 of fp mask to 0
   285  0154 8016               	bra .local4
   286                          .local1
   287  0156 c944               	cmp #'D'
   288  0158 d006               	bne .local2
   289  015a a980               	lda #$80				;bit 7=1, bit 5=0
   290  015c 8529               	sta fpmask
   291  015e 800c               	bra .local4
   292                          .local2
   293  0160 c945               	cmp #'E'
   294  0162 d006               	bne .local3
   295  0164 a920               	lda #$20				;bit 7=0, bit 5=1
   296  0166 8529               	sta fpmask
   297  0168 8002               	bra .local4
   298                          .local3
   299  016a 38                 	sec						;unknown size
   300  016b 60                 	rts
   301                          .local4
   302  016c 18                 	clc
   303  016d 60                 	rts
   304                          	
   305                          fpgetregspec
   306  016e 202000             	jsr parse_getchar		;set fpregspec to 00 or 40 depending on register specified
   307  0171 c941               	cmp #'A'
   308  0173 d004               	bne .localgrs1
   309  0175 6428               	stz fpregspec
   310  0177 8008               	bra .localgrs3
   311                          .localgrs1
   312  0179 c942               	cmp #'B'
   313  017b d006               	bne .localgrs4
   314  017d a940               	lda #$40
   315  017f 8528               	sta fpregspec
   316                          .localgrs3
   317  0181 18                 	clc
   318  0182 60                 	rts
   319                          .localgrs4
   320  0183 38                 	sec
   321  0184 60                 	rts
   322                          
   323                          fpiload
   324  0185 204901             	jsr fpgetmask
   325  0188 9003               	bcc .fpil1
   326  018a 4c6703             	jmp monerror
   327                          .fpil1
   328  018d 206e01             	jsr fpgetregspec
   329  0190 9003               	bcc .fpil2
   330  0192 4c6703             	jmp monerror
   331                          .fpil2
   332  0195 a529               	lda fpmask
   333  0197 0528               	ora fpregspec
   334  0199 8f47fc1b           	sta IO_FP_ILOAD
   335  019d 4ccf03             	jmp moncmd
   336                          
   337                          fpln
   338  01a0 204901             	jsr fpgetmask
   339  01a3 9003               	bcc .fpln1
   340  01a5 4c6703             	jmp monerror
   341                          .fpln1
   342  01a8 206e01             	jsr fpgetregspec
   343  01ab 9003               	bcc .fpln2
   344  01ad 4c6703             	jmp monerror
   345                          .fpln2
   346  01b0 a529               	lda fpmask
   347  01b2 0528               	ora fpregspec
   348  01b4 8f46fc1b           	sta IO_FP_LN
   349  01b8 4ccf03             	jmp moncmd
   350                          	
   351                          fpmultiply
   352  01bb 204901             	jsr fpgetmask
   353  01be 9003               	bcc .fpmultiply1
   354  01c0 4c6703             	jmp monerror
   355                          .fpmultiply1
   356  01c3 206e01             	jsr fpgetregspec
   357  01c6 9003               	bcc .fpmultiply2
   358  01c8 4c6703             	jmp monerror
   359                          .fpmultiply2
   360  01cb a529               	lda fpmask
   361  01cd 0528               	ora fpregspec
   362  01cf 8f42fc1b           	sta IO_FP_MULTIPLY
   363  01d3 4ccf03             	jmp moncmd
   364                          	
   365                          fpdivide
   366  01d6 204901             	jsr fpgetmask
   367  01d9 9003               	bcc .fpdivide1
   368  01db 4c6703             	jmp monerror
   369                          .fpdivide1
   370  01de 206e01             	jsr fpgetregspec
   371  01e1 9003               	bcc .fpdivide2
   372  01e3 4c6703             	jmp monerror
   373                          .fpdivide2
   374  01e6 a529               	lda fpmask
   375  01e8 0528               	ora fpregspec
   376  01ea 8f43fc1b           	sta IO_FP_DIVIDE
   377  01ee 4ccf03             	jmp moncmd
   378                          	
   379                          fpadd
   380  01f1 204901             	jsr fpgetmask
   381  01f4 9003               	bcc .fpadd1
   382  01f6 4c6703             	jmp monerror
   383                          .fpadd1
   384  01f9 206e01             	jsr fpgetregspec
   385  01fc 9003               	bcc .fpadd2
   386  01fe 4c6703             	jmp monerror
   387                          .fpadd2
   388  0201 a529               	lda fpmask
   389  0203 0528               	ora fpregspec
   390  0205 8f44fc1b           	sta IO_FP_ADD
   391  0209 4ccf03             	jmp moncmd
   392                          	
   393                          fpsubtract
   394  020c 204901             	jsr fpgetmask
   395  020f 9003               	bcc .fpsubtract1
   396  0211 4c6703             	jmp monerror
   397                          .fpsubtract1
   398  0214 206e01             	jsr fpgetregspec
   399  0217 9003               	bcc .fpsubtract2
   400  0219 4c6703             	jmp monerror
   401                          .fpsubtract2
   402  021c a529               	lda fpmask
   403  021e 0528               	ora fpregspec
   404  0220 8f45fc1b           	sta IO_FP_SUBTRACT
   405  0224 4ccf03             	jmp moncmd
   406                          	
   407                          fploadconst
   408  0227 204901             	jsr fpgetmask
   409  022a 9003               	bcc .fploadconst1
   410  022c 4c6703             	jmp monerror
   411                          .fploadconst1
   412  022f 206e01             	jsr fpgetregspec
   413  0232 9003               	bcc .fploadconst2
   414  0234 4c6703             	jmp monerror
   415                          .fploadconst2
   416  0237 202f00             	jsr parse_addr			;get const specifier
   417  023a c230               	rep #$30
   418  023c 98                 	tya
   419  023d e220               	sep #$20
   420  023f 291f               	and #$1f				;we're only interested in values 0-31
   421  0241 0529               	ora fpmask
   422  0243 0528               	ora fpregspec
   423  0245 8f40fc1b           	sta IO_FP_INIT_CONSTANT
   424  0249 4ccf03             	jmp moncmd
   425                          
   426                          fpdisp
   427  024c 204901             	jsr fpgetmask
   428  024f 9022               	bcc fpdisp2
   429  0251 4c6703             	jmp monerror
   430                          fpfacctxt
   431  0254 464143433a20       	!tx "FACC: "
   432  025a 00                 	!byte $00
   433                          fpfargtxt
   434  025b 464152473a20       	!tx "FARG: "
   435  0261 00                 	!byte $00
   436                          fpcondtxt
   437  0262 4650434f4e443a20   	!tx "FPCOND: "
   438  026a 00                 	!byte $00
   439                          fpinttxt
   440  026b 4650494e543a20     	!tx "FPINT: "
   441  0272 00                 	!byte $00
   442                          fpdisp2
   443  0273 a25402             	ldx #fpfacctxt			;print FACC: tag
   444  0276 863d               	stx dpla
   445  0278 a91c               	lda #$1c
   446  027a 853f               	sta dpla_h
   447  027c 22860e1c           	jsl l_prcdpla
   448  0280 a20900             	ldx #9
   449  0283 a529               	lda fpmask
   450  0285 2920               	and #$20
   451  0287 d00c               	bne .facchex			;bit 5 set, so fall through and print 10 bytes
   452  0289 a20700             	ldx #7
   453  028c a529               	lda fpmask
   454  028e 2980               	and #$80
   455  0290 d003               	bne .facchex			;bit 5 clear, but bit 7 set, print 8 bytes
   456  0292 a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   457                          .facchex					;print X number of hex bytes in reverse order
   458  0295 bfe0fc1b           	lda FPACCUMULATOR,x
   459  0299 20bd05             	jsr+2 prhex
   460  029c ca                 	dex
   461  029d 10f6               	bpl .facchex
   462  029f a529               	lda fpmask
   463  02a1 8f41fc1b           	sta IO_FP_TO_ASCII
   464  02a5 a92f               	lda #'/'
   465  02a7 8f12fc1b           	sta IO_CON_CHAROUT
   466  02ab 8f13fc1b           	sta IO_CON_REGISTER
   467  02af a2c0fc             	ldx #FPASCII_LO16
   468  02b2 863d               	stx dpla
   469  02b4 a91b               	lda #$1b
   470  02b6 853f               	sta dpla_h
   471  02b8 22860e1c           	jsl l_prcdpla
   472  02bc 8f17fc1b           	sta IO_CON_CR
   473                          	
   474  02c0 a25b02             	ldx #fpfargtxt			;print FARG: tag
   475  02c3 863d               	stx dpla
   476  02c5 a91c               	lda #$1c
   477  02c7 853f               	sta dpla_h
   478  02c9 22860e1c           	jsl l_prcdpla
   479  02cd a20900             	ldx #9
   480  02d0 a529               	lda fpmask
   481  02d2 2920               	and #$20
   482  02d4 d00c               	bne .farghex			;bit 5 set, so fall through and print 10 bytes
   483  02d6 a20700             	ldx #7
   484  02d9 a529               	lda fpmask
   485  02db 2980               	and #$80
   486  02dd d003               	bne .farghex			;bit 5 clear, but bit 7 set, print 8 bytes
   487  02df a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   488                          .farghex					;print X number of hex bytes in reverse order
   489  02e2 bff0fc1b           	lda FPARGUMENT,x
   490  02e6 20bd05             	jsr+2 prhex
   491  02e9 ca                 	dex
   492  02ea 10f6               	bpl .farghex
   493  02ec a529               	lda fpmask
   494  02ee 0940               	ora #$40				;select FARG this time
   495  02f0 8f41fc1b           	sta IO_FP_TO_ASCII
   496  02f4 a92f               	lda #'/'
   497  02f6 8f12fc1b           	sta IO_CON_CHAROUT
   498  02fa 8f13fc1b           	sta IO_CON_REGISTER
   499  02fe a2c0fc             	ldx #FPASCII_LO16
   500  0301 863d               	stx dpla
   501  0303 a91b               	lda #$1b
   502  0305 853f               	sta dpla_h
   503  0307 22860e1c           	jsl l_prcdpla
   504  030b 8f17fc1b           	sta IO_CON_CR
   505                          	
   506  030f a26202             	ldx #fpcondtxt			;print FPCOND: tag
   507  0312 863d               	stx dpla
   508  0314 a91c               	lda #$1c
   509  0316 853f               	sta dpla_h
   510  0318 22860e1c           	jsl l_prcdpla
   511  031c a920               	lda #' '
   512  031e 8f12fc1b           	sta IO_CON_CHAROUT
   513  0322 8f13fc1b           	sta IO_CON_REGISTER
   514  0326 afbffc1b           	lda FPCOND
   515  032a 20bd05             	jsr+2 prhex
   516  032d 8f17fc1b           	sta IO_CON_CR
   517                          	
   518  0331 a26b02             	ldx #fpinttxt			;print FPINT tab
   519  0334 863d               	stx dpla
   520  0336 a91c               	lda #$1c
   521  0338 853f               	sta dpla_h
   522  033a 22860e1c           	jsl l_prcdpla
   523  033e a920               	lda #' '
   524  0340 8f12fc1b           	sta IO_CON_CHAROUT
   525  0344 8f13fc1b           	sta IO_CON_REGISTER
   526  0348 a20700             	ldx #7
   527                          .fpdisp3
   528  034b bfd8fc1b           	lda FPINT,x
   529  034f 20bd05             	jsr+2 prhex
   530  0352 ca                 	dex
   531  0353 10f6               	bpl .fpdisp3
   532  0355 8f17fc1b           	sta IO_CON_CR
   533                          	
   534  0359 4ccf03             	jmp moncmd
   535                          	
   536                          bankcmd
   537  035c 202f00             	jsr parse_addr
   538  035f 9006               	bcc monerror
   539  0361 98                 	tya
   540  0362 853c               	sta mondump_h
   541  0364 4ccf03             	jmp moncmd
   542                          monerror
   543  0367 a27703             	ldx #monsynerr
   544  036a 863d               	stx dpla
   545  036c a91c               	lda #$1c
   546  036e 853f               	sta dpla_h
   547  0370 22860e1c           	jsl l_prcdpla
   548  0374 4ccf03             	jmp moncmd
   549                          monsynerr
   550  0377 53796e7461782065...	!tx "Syntax error!"
   551  0384 0d00               	!byte $0d, $00
   552                          
   553                          colorcmd
   554  0386 202f00             	jsr parse_addr
   555  0389 90dc               	bcc monerror
   556  038b 98                 	tya
   557  038c 8f11fc1b           	sta IO_CON_COLOR
   558  0390 4ccf03             	jmp moncmd
   559                          	
   560                          modecmd
   561  0393 202f00             	jsr parse_addr
   562  0396 90cf               	bcc monerror
   563  0398 98                 	tya
   564  0399 c908               	cmp #$08
   565  039b 90ca               	bcc monerror
   566  039d c90a               	cmp #$0a
   567  039f b0c6               	bcs monerror
   568  03a1 8f20fc1b           	sta IO_VIDMODE
   569  03a5 a900               	lda #$00
   570  03a7 8f14fc1b           	sta IO_CON_CURSORH
   571  03ab 8f15fc1b           	sta IO_CON_CURSORV
   572  03af a920               	lda #$20
   573  03b1 8f12fc1b           	sta IO_CON_CHAROUT
   574  03b5 8f10fc1b           	sta IO_CON_CLS
   575  03b9 4ccf03             	jmp moncmd
   576                          	
   577                          monstart				;main entry point for system monitor
   578  03bc 4b                 	phk
   579  03bd ab                 	plb
   580  03be c210               	rep #$10
   581                          	!rl
   582  03c0 e220               	sep #$20
   583                          	!as
   584  03c2 a20000             	ldx #$0000
   585  03c5 863a               	stx mondump
   586  03c7 a91c               	lda #$1c
   587  03c9 853c               	sta mondump_h
   588  03cb a944               	lda #'D'
   589  03cd 8536               	sta monlast
   590                          	
   591                          	!zone moncmd
   592                          moncmd
   593  03cf a92a               	lda #promptchar
   594  03d1 8f12fc1b           	sta IO_CON_CHAROUT
   595  03d5 8f13fc1b           	sta IO_CON_REGISTER
   596  03d9 22040e1c           	jsl l_getline
   597  03dd 22e20d1c           	jsl l_ucline
   598  03e1 201600             	jsr parse_setup
   599  03e4 202000             	jsr parse_getchar
   600                          .local3
   601  03e7 c951               	cmp #'Q'
   602  03e9 f05b               	beq haltcmd
   603  03eb c944               	cmp #'D'
   604  03ed d003               	bne .local4
   605  03ef 4c0205             	jmp+2 dumpcmd
   606                          .local4
   607  03f2 c90d               	cmp #$0d
   608  03f4 d008               	bne .local2
   609  03f6 a536               	lda monlast			;recall previously executed command
   610  03f8 c920               	cmp #$20			;make sure it isn't a control character
   611  03fa b0eb               	bcs .local3			;and retry it
   612  03fc 80d1               	bra moncmd			;else recycle and try a new command
   613                          .local2
   614  03fe c941               	cmp #'A'
   615  0400 f06a               	beq asciidumpcmd
   616  0402 c942               	cmp #'B'
   617  0404 d003               	bne .local5
   618  0406 4c5c03             	jmp+2 bankcmd
   619                          .local5
   620  0409 c943               	cmp #'C'
   621  040b d003               	bne .local6
   622  040d 4c8603             	jmp+2 colorcmd
   623                          .local6
   624  0410 c94d               	cmp #'M'
   625  0412 d003               	bne .local7
   626  0414 4c9303             	jmp+2 modecmd
   627                          .local7
   628  0417 c945               	cmp #'E'
   629  0419 d003               	bne .local8
   630  041b 4cdd05             	jmp+2 entercmd
   631                          .local8
   632  041e c94c               	cmp #'L'
   633  0420 d003               	bne .local9
   634  0422 4c0b06             	jmp+2 listcmd
   635                          .local9
   636  0425 c93f               	cmp #'?'
   637  0427 f00d               	beq helpcmd
   638  0429 c946               	cmp #'F'
   639  042b f003               	beq .localfp
   640  042d 4ccf03             	jmp moncmd
   641                          .localfp
   642  0430 200d01             	jsr fpcmd
   643  0433 4ccf03             	jmp moncmd
   644                          	
   645                          helpcmd
   646  0436 a2ca0e             	ldx #helpmsg
   647  0439 863d               	stx dpla
   648  043b a91c               	lda #$1c
   649  043d 853f               	sta dpla_h
   650  043f 22860e1c           	jsl l_prcdpla
   651  0443 4ccf03             	jmp moncmd
   652                          	
   653                          haltcmd
   654  0446 a25404             	ldx #haltmsg
   655  0449 863d               	stx dpla
   656  044b a91c               	lda #$1c
   657  044d 853f               	sta dpla_h
   658  044f 22860e1c           	jsl l_prcdpla
   659  0453 db                 	stp
   660                          haltmsg
   661  0454 48616c74696e6720...	!tx "Halting 65816 engine.."
   662  046a 0d00               	!byte $0d,$00
   663                          	
   664                          	!zone asciidumpcmd
   665                          asciidumpcmd
   666  046c 8536               	sta monlast
   667  046e 202f00             	jsr parse_addr
   668  0471 9021               	bcc .local3
   669  0473 843a               	sty mondump
   670  0475 8433               	sty rangehigh
   671  0477 2435               	bit monrange			;user asking for a range?
   672  0479 1019               	bpl .local3
   673  047b 202f00             	jsr parse_addr			;get the remaining half of the range
   674  047e 8433               	sty rangehigh
   675  0480 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   676  0482 8535               	sta monrange
   677  0484 a433               	ldy rangehigh
   678  0486 d003               	bne .local6
   679  0488 4c6703             	jmp+2 monerror			;top of range can't be zero
   680                          .local6
   681  048b a43a               	ldy mondump
   682  048d c433               	cpy rangehigh
   683  048f 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   684  0491 4c6703             	jmp+2 monerror
   685                          .local3
   686  0494 20bf00             	jsr prdumpaddr
   687  0497 a00000             	ldy #$0000
   688                          .local2
   689  049a b73a               	lda [mondump],y
   690  049c c920               	cmp #$20
   691  049e b002               	bcs .local4
   692  04a0 a92e               	lda #'.'				;substitute control character with a period
   693                          .local4
   694  04a2 8f12fc1b           	sta IO_CON_CHAROUT
   695  04a6 8f13fc1b           	sta IO_CON_REGISTER
   696  04aa c8                 	iny
   697  04ab af20fc1b           	lda IO_VIDMODE
   698  04af c909               	cmp #$09
   699  04b1 d007               	bne .lores1
   700  04b3 c04000             	cpy #$0040
   701  04b6 d0e2               	bne .local2
   702  04b8 8005               	bra .lores2
   703                          .lores1
   704  04ba c01000             	cpy #$0010
   705  04bd d0db               	bne .local2
   706                          .lores2
   707  04bf 8f17fc1b           	sta IO_CON_CR
   708  04c3 20e800             	jsr adjdumpaddr
   709  04c6 b035               	bcs .local5				;carry to bank, exit even if we're processing a range
   710  04c8 20e800             	jsr adjdumpaddr
   711  04cb b030               	bcs .local5	
   712  04cd af20fc1b           	lda IO_VIDMODE
   713  04d1 c909               	cmp #$09
   714  04d3 d01e               	bne .lores3
   715  04d5 20e800             	jsr adjdumpaddr
   716  04d8 b023               	bcs .local5	
   717  04da 20e800             	jsr adjdumpaddr
   718  04dd b01e               	bcs .local5	
   719  04df 20e800             	jsr adjdumpaddr
   720  04e2 b019               	bcs .local5	
   721  04e4 20e800             	jsr adjdumpaddr
   722  04e7 b014               	bcs .local5	
   723  04e9 20e800             	jsr adjdumpaddr
   724  04ec b00f               	bcs .local5	
   725  04ee 20e800             	jsr adjdumpaddr
   726  04f1 b00a               	bcs .local5	
   727                          .lores3
   728  04f3 2435               	bit monrange			;ranges on?
   729  04f5 1006               	bpl .local5
   730  04f7 a433               	ldy rangehigh
   731  04f9 c43a               	cpy mondump
   732  04fb b097               	bcs .local3
   733                          .local5
   734  04fd 6435               	stz monrange
   735  04ff 4ccf03             	jmp moncmd
   736                          	
   737                          	!zone dumpcmd
   738                          dumpcmd
   739  0502 8536               	sta monlast
   740  0504 202f00             	jsr parse_addr
   741  0507 9021               	bcc .local3
   742  0509 843a               	sty mondump				;if address was specified, store 16 bit y at low 16 bits of mondump address
   743  050b 8433               	sty rangehigh
   744  050d 2435               	bit monrange			;user asking for a range?
   745  050f 1019               	bpl .local3
   746  0511 202f00             	jsr parse_addr			;get the remaining half of the range
   747  0514 8433               	sty rangehigh
   748  0516 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   749  0518 8535               	sta monrange
   750  051a a433               	ldy rangehigh
   751  051c d003               	bne .local6
   752  051e 4c6703             	jmp+2 monerror			;top of range can't be zero
   753                          .local6
   754  0521 a43a               	ldy mondump
   755  0523 c433               	cpy rangehigh
   756  0525 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   757  0527 4c6703             	jmp+2 monerror
   758                          .local3
   759  052a 20bf00             	jsr prdumpaddr
   760  052d a00000             	ldy #$0000
   761                          .local2
   762  0530 b73a               	lda [mondump],y
   763  0532 20bd05             	jsr+2 prhex
   764  0535 a920               	lda #' '
   765  0537 8f12fc1b           	sta IO_CON_CHAROUT
   766  053b 8f13fc1b           	sta IO_CON_REGISTER
   767  053f c8                 	iny
   768  0540 af20fc1b           	lda IO_VIDMODE
   769  0544 c909               	cmp #$09
   770  0546 d03e               	bne .lores1
   771  0548 c01000             	cpy #$0010
   772  054b d0e3               	bne .local2
   773  054d a920               	lda #' '
   774  054f 8f12fc1b           	sta IO_CON_CHAROUT
   775  0553 8f13fc1b           	sta IO_CON_REGISTER
   776  0557 a92d               	lda #'-'
   777  0559 8f12fc1b           	sta IO_CON_CHAROUT
   778  055d 8f13fc1b           	sta IO_CON_REGISTER
   779  0561 a920               	lda #' '
   780  0563 8f12fc1b           	sta IO_CON_CHAROUT
   781  0567 8f13fc1b           	sta IO_CON_REGISTER
   782  056b a00000             	ldy #$0000				;print 16 bytes as ASCII... bonus when in mode 9!
   783                          .asc2
   784  056e b73a               	lda [mondump],y
   785  0570 c920               	cmp #$20
   786  0572 b002               	bcs .asc4
   787  0574 a92e               	lda #'.'				;substitute control character with a period
   788                          .asc4
   789  0576 8f12fc1b           	sta IO_CON_CHAROUT
   790  057a 8f13fc1b           	sta IO_CON_REGISTER
   791  057e c8                 	iny
   792  057f c01000             	cpy #$0010
   793  0582 d0ea               	bne .asc2
   794  0584 8005               	bra .lores2
   795                          .lores1
   796  0586 c00800             	cpy #$0008
   797  0589 d0a5               	bne .local2
   798                          .lores2
   799  058b 8f17fc1b           	sta IO_CON_CR
   800  058f 20e800             	jsr adjdumpaddr
   801  0592 b01a               	bcs .local5				;carry to bank, exit even if we're processing a range
   802  0594 af20fc1b           	lda IO_VIDMODE
   803  0598 c909               	cmp #$09
   804  059a d005               	bne .lores3
   805  059c 20e800             	jsr adjdumpaddr
   806  059f b00d               	bcs .local5
   807                          .lores3
   808  05a1 2435               	bit monrange			;ranges on?
   809  05a3 1009               	bpl .local5
   810  05a5 a433               	ldy rangehigh
   811  05a7 c43a               	cpy mondump
   812  05a9 9003               	bcc .local5
   813  05ab 4c2a05             	jmp+2 .local3
   814                          .local5
   815  05ae 6435               	stz monrange
   816  05b0 4ccf03             	jmp moncmd
   817                          	
   818                          prhex16
   819  05b3 c230               	rep #$30
   820  05b5 8a                 	txa
   821  05b6 e220               	sep #$20
   822  05b8 eb                 	xba
   823  05b9 20bd05             	jsr+2 prhex
   824  05bc eb                 	xba
   825                          prhex
   826  05bd 48                 	pha
   827  05be 4a                 	lsr
   828  05bf 4a                 	lsr
   829  05c0 4a                 	lsr
   830  05c1 4a                 	lsr
   831  05c2 20c805             	jsr+2 prhexnib
   832  05c5 68                 	pla
   833  05c6 290f               	and #$0f
   834                          prhexnib
   835  05c8 0930               	ora #$30
   836  05ca c93a               	cmp #$3a
   837  05cc 9003               	bcc prhexnofix
   838  05ce 18                 	clc
   839  05cf 6907               	adc #$07
   840                          prhexnofix
   841  05d1 8f12fc1b           	sta IO_CON_CHAROUT
   842  05d5 8f13fc1b           	sta IO_CON_REGISTER
   843  05d9 60                 	rts
   844                          
   845                          	!zone entercmd
   846                          .local1
   847  05da 4c6703             	jmp monerror
   848                          entercmd
   849  05dd 202f00             	jsr parse_addr
   850  05e0 90f8               	bcc .local1			;address is mandatory
   851  05e2 2435               	bit monrange
   852  05e4 30f4               	bmi .local1			;ranges not allowed
   853  05e6 8430               	sty enterbytes
   854  05e8 a53c               	lda mondump_h
   855  05ea 8532               	sta enterbytes_h	;retrieve bank from mondump
   856                          .local2
   857  05ec 202f00             	jsr parse_addr		;start grabbing bytes
   858  05ef 9017               	bcc .enterdone
   859  05f1 2435               	bit monrange
   860  05f3 30e5               	bmi .local1			;stop that happening here too
   861  05f5 c230               	rep #$30
   862  05f7 98                 	tya
   863  05f8 e220               	sep #$20			;get low byte of parsed address into A
   864  05fa 8730               	sta [enterbytes]
   865  05fc e630               	inc enterbytes
   866  05fe d006               	bne .local3
   867  0600 e631               	inc enterbytes_m
   868  0602 d002               	bne .local3
   869  0604 e632               	inc enterbytes_h
   870                          .local3
   871  0606 80e4               	bra .local2
   872                          .enterdone
   873  0608 4ccf03             	jmp moncmd
   874                          	
   875                          	!zone listcmd
   876                          listcmd
   877  060b 202f00             	jsr parse_addr
   878  060e 9002               	bcc .listmany				;address is optional
   879  0610 843a               	sty mondump
   880                          .listmany
   881  0612 af20fc1b           	lda IO_VIDMODE
   882  0616 c909               	cmp #$09
   883  0618 d005               	bne .listmany1
   884  061a a22000             	ldx #32
   885  061d 8003               	bra .listmany2
   886                          .listmany1
   887  061f a20f00             	ldx #15
   888                          .listmany2
   889  0622 da                 	phx
   890  0623 202d06             	jsr+2 .listsingle
   891  0626 fa                 	plx
   892  0627 ca                 	dex
   893  0628 d0f8               	bne .listmany2
   894  062a 4ccf03             	jmp moncmd
   895                          .listsingle
   896  062d a00000             	ldy #$0000
   897  0630 20bf00             	jsr prdumpaddr
   898  0633 a900               	lda #$00
   899  0635 eb                 	xba					;clear B
   900  0636 a73a               	lda [mondump]				;get opcode
   901  0638 48                 	pha					;save opcode
   902  0639 aa                 	tax
   903  063a bdce0a             	lda mnemlenmode,x
   904  063d 4a                 	lsr
   905  063e 4a                 	lsr
   906  063f 4a                 	lsr
   907  0640 4a                 	lsr
   908  0641 4a                 	lsr					;isolage opcode len
   909  0642 852f               	sta scratch1
   910  0644 a73a               	lda [mondump]
   911  0646 20730a             	jsr+2 is816
   912  0649 a52f               	lda scratch1
   913  064b aa                 	tax
   914  064c a00000             	ldy #$0000
   915                          .nextbyte
   916  064f b73a               	lda [mondump],y
   917  0651 20bd05             	jsr prhex			;print hex
   918  0654 a920               	lda #' '
   919  0656 8f12fc1b           	sta IO_CON_CHAROUT
   920  065a 8f13fc1b           	sta IO_CON_REGISTER	;print space
   921  065e c8                 	iny
   922  065f ca                 	dex
   923  0660 d0ed               	bne .nextbyte
   924  0662 a916               	lda #$16
   925  0664 8f14fc1b           	sta IO_CON_CURSORH	;tab over
   926  0668 68                 	pla					;get opcode back
   927  0669 aa                 	tax
   928  066a bdce0b             	lda mnemlist,x
   929  066d 8530               	sta enterbytes
   930  066f 6431               	stz enterbytes_m	;save for 16 bit add
   931  0671 da                 	phx					;stash our opcode
   932  0672 c230               	rep #$30
   933                          	!al
   934  0674 29ff00             	and #$00ff			;switch to 16 bits, clear top
   935  0677 0a                 	asl
   936  0678 18                 	clc
   937  0679 6530               	adc enterbytes		;multiply by 3
   938  067b aa                 	tax
   939  067c e220               	sep #$20
   940                          	!as
   941  067e bdce0c             	lda mnems, x
   942  0681 8f12fc1b           	sta IO_CON_CHAROUT
   943  0685 8f13fc1b           	sta IO_CON_REGISTER
   944  0689 e8                 	inx
   945  068a bdce0c             	lda mnems, x
   946  068d 8f12fc1b           	sta IO_CON_CHAROUT
   947  0691 8f13fc1b           	sta IO_CON_REGISTER
   948  0695 e8                 	inx
   949  0696 bdce0c             	lda mnems, x
   950  0699 8f12fc1b           	sta IO_CON_CHAROUT
   951  069d 8f13fc1b           	sta IO_CON_REGISTER
   952  06a1 a920               	lda #' '
   953  06a3 8f12fc1b           	sta IO_CON_CHAROUT
   954  06a7 8f13fc1b           	sta IO_CON_REGISTER
   955  06ab fa                 	plx					;get our opcode back in index
   956  06ac a900               	lda #$00
   957  06ae eb                 	xba					;clear top byte of A if it's dirty
   958  06af bdce0a             	lda mnemlenmode,x
   959  06b2 291f               	and #$1f			;isolate the addressing mode
   960  06b4 0a                 	asl					;multiply by two
   961  06b5 aa                 	tax
   962  06b6 fca40a             	jsr (listamod,x)
   963  06b9 af20fc1b           	lda IO_VIDMODE
   964  06bd c909               	cmp #$09
   965  06bf d01f               	bne .fixup1
   966  06c1 a925               	lda #$25
   967  06c3 8f14fc1b           	sta IO_CON_CURSORH		;tab over and print our bytes as ASCII in 80 column mode
   968  06c7 e230               	sep #$30				;8 bit indexes here
   969                          	!rs
   970  06c9 a000               	ldy #$00				;print disassembly bytes as ASCII... bonus when in mode 9!
   971                          .asc2
   972  06cb b73a               	lda [mondump],y
   973  06cd c920               	cmp #$20
   974  06cf b002               	bcs .asc4
   975  06d1 a92e               	lda #'.'				;substitute control character with a period
   976                          .asc4
   977  06d3 8f12fc1b           	sta IO_CON_CHAROUT
   978  06d7 8f13fc1b           	sta IO_CON_REGISTER
   979  06db c8                 	iny
   980  06dc c42f               	cpy scratch1
   981  06de d0eb               	bne .asc2
   982                          .fixup1
   983  06e0 c210               	rep #$10
   984                          	!rl
   985  06e2 8f17fc1b           	sta IO_CON_CR
   986                          .fixup
   987  06e6 a52f               	lda scratch1		;get our fixup
   988  06e8 18                 	clc
   989  06e9 653a               	adc mondump
   990  06eb 853a               	sta mondump
   991  06ed a53b               	lda mondump_m
   992  06ef 6900               	adc #$00
   993  06f1 853b               	sta mondump_m
   994  06f3 a53c               	lda mondump_h
   995  06f5 6900               	adc #$00
   996  06f7 853c               	sta mondump_h
   997                          .goback
   998  06f9 60                 	rts
   999                          
  1000                          amod0
  1001  06fa a924               	lda #'$'
  1002  06fc 8f12fc1b           	sta IO_CON_CHAROUT
  1003  0700 8f13fc1b           	sta IO_CON_REGISTER
  1004  0704 a00100             	ldy #$0001
  1005  0707 b73a               	lda [mondump],y
  1006  0709 20bd05             	jsr prhex
  1007  070c 60                 	rts
  1008                          amod1
  1009  070d a928               	lda #'('
  1010  070f 8f12fc1b           	sta IO_CON_CHAROUT
  1011  0713 8f13fc1b           	sta IO_CON_REGISTER
  1012  0717 a924               	lda #'$'
  1013  0719 8f12fc1b           	sta IO_CON_CHAROUT
  1014  071d 8f13fc1b           	sta IO_CON_REGISTER
  1015  0721 a00100             	ldy #$0001
  1016  0724 b73a               	lda [mondump],y
  1017  0726 20bd05             	jsr prhex
  1018  0729 a92c               	lda #','
  1019  072b 8f12fc1b           	sta IO_CON_CHAROUT
  1020  072f 8f13fc1b           	sta IO_CON_REGISTER
  1021  0733 a958               	lda #'X'
  1022  0735 8f12fc1b           	sta IO_CON_CHAROUT
  1023  0739 8f13fc1b           	sta IO_CON_REGISTER
  1024  073d a929               	lda #')'
  1025  073f 8f12fc1b           	sta IO_CON_CHAROUT
  1026  0743 8f13fc1b           	sta IO_CON_REGISTER
  1027  0747 60                 	rts
  1028                          amod2
  1029  0748 a00100             	ldy #$0001
  1030  074b b73a               	lda [mondump],y
  1031  074d 20bd05             	jsr prhex
  1032  0750 a92c               	lda #','
  1033  0752 8f12fc1b           	sta IO_CON_CHAROUT
  1034  0756 8f13fc1b           	sta IO_CON_REGISTER
  1035  075a a953               	lda #'S'
  1036  075c 8f12fc1b           	sta IO_CON_CHAROUT
  1037  0760 8f13fc1b           	sta IO_CON_REGISTER
  1038  0764 60                 	rts
  1039                          amod3
  1040  0765 a95b               	lda #'['
  1041  0767 8f12fc1b           	sta IO_CON_CHAROUT
  1042  076b 8f13fc1b           	sta IO_CON_REGISTER
  1043  076f a924               	lda #'$'
  1044  0771 8f12fc1b           	sta IO_CON_CHAROUT
  1045  0775 8f13fc1b           	sta IO_CON_REGISTER
  1046  0779 a00100             	ldy #$0001
  1047  077c b73a               	lda [mondump],y
  1048  077e 20bd05             	jsr prhex
  1049  0781 a95d               	lda #']'
  1050  0783 8f12fc1b           	sta IO_CON_CHAROUT
  1051  0787 8f13fc1b           	sta IO_CON_REGISTER
  1052                          amod4
  1053  078b 60                 	rts
  1054                          	!zone amod5
  1055                          amod5
  1056  078c a923               	lda #'#'
  1057  078e 8f12fc1b           	sta IO_CON_CHAROUT
  1058  0792 8f13fc1b           	sta IO_CON_REGISTER
  1059  0796 a924               	lda #'$'
  1060  0798 8f12fc1b           	sta IO_CON_CHAROUT
  1061  079c 8f13fc1b           	sta IO_CON_REGISTER
  1062  07a0 a52f               	lda scratch1
  1063  07a2 c902               	cmp #$02
  1064  07a4 f008               	beq .amod508
  1065                          .amod516
  1066  07a6 a00200             	ldy #$0002
  1067  07a9 b73a               	lda [mondump],y
  1068  07ab 20bd05             	jsr prhex
  1069                          .amod508
  1070  07ae a00100             	ldy #$0001
  1071  07b1 b73a               	lda [mondump],y
  1072  07b3 20bd05             	jsr prhex
  1073  07b6 60                 	rts
  1074                          amod6
  1075  07b7 a924               	lda #'$'
  1076  07b9 8f12fc1b           	sta IO_CON_CHAROUT
  1077  07bd 8f13fc1b           	sta IO_CON_REGISTER
  1078  07c1 a00200             	ldy #$0002
  1079  07c4 b73a               	lda [mondump],y
  1080  07c6 20bd05             	jsr prhex
  1081  07c9 88                 	dey
  1082  07ca b73a               	lda [mondump],y
  1083  07cc 4cbd05             	jmp prhex
  1084                          amod7
  1085  07cf a924               	lda #'$'
  1086  07d1 8f12fc1b           	sta IO_CON_CHAROUT
  1087  07d5 8f13fc1b           	sta IO_CON_REGISTER
  1088  07d9 a00300             	ldy #$0003
  1089  07dc b73a               	lda [mondump],y
  1090  07de 20bd05             	jsr prhex
  1091  07e1 88                 	dey
  1092  07e2 b73a               	lda [mondump],y
  1093  07e4 20bd05             	jsr prhex
  1094  07e7 88                 	dey
  1095  07e8 b73a               	lda [mondump],y
  1096  07ea 4cbd05             	jmp prhex
  1097                          amod11
  1098  07ed a00300             	ldy #$0003
  1099  07f0 842a               	sty scratch2			;number of bytes to bump offset
  1100  07f2 a00200             	ldy #$0002
  1101  07f5 b73a               	lda [mondump],y
  1102  07f7 eb                 	xba
  1103  07f8 88                 	dey
  1104  07f9 b73a               	lda [mondump],y
  1105  07fb 8014               	bra amod8nosign
  1106                          amod8
  1107  07fd a00200             	ldy #$0002
  1108  0800 842a               	sty scratch2
  1109  0802 a900               	lda #$00
  1110  0804 eb                 	xba						;clear high byte of A
  1111                          amod8a
  1112  0805 a00100             	ldy #$0001
  1113  0808 b73a               	lda [mondump],y			;get rel byte
  1114  080a 1005               	bpl amod8nosign
  1115  080c 48                 	pha
  1116  080d a9ff               	lda #$ff
  1117  080f eb                 	xba						;sign extend if negative
  1118  0810 68                 	pla
  1119                          amod8nosign
  1120  0811 c230               	rep #$30
  1121                          	!al
  1122  0813 18                 	clc
  1123  0814 653a               	adc mondump				;add to our current disassembly address
  1124  0816 18                 	clc
  1125  0817 652a               	adc scratch2			;add offset for instruction size
  1126  0819 aa                 	tax
  1127  081a e220               	sep #$20
  1128                          	!as
  1129  081c a924               	lda #'$'
  1130  081e 8f12fc1b           	sta IO_CON_CHAROUT
  1131  0822 8f13fc1b           	sta IO_CON_REGISTER
  1132  0826 20b305             	jsr prhex16
  1133  0829 60                 	rts
  1134                          amod9
  1135  082a a928               	lda #'('
  1136  082c 8f12fc1b           	sta IO_CON_CHAROUT
  1137  0830 8f13fc1b           	sta IO_CON_REGISTER
  1138  0834 a924               	lda #'$'
  1139  0836 8f12fc1b           	sta IO_CON_CHAROUT
  1140  083a 8f13fc1b           	sta IO_CON_REGISTER
  1141  083e a00100             	ldy #$0001
  1142  0841 b73a               	lda [mondump],y
  1143  0843 20bd05             	jsr prhex
  1144  0846 a929               	lda #')'
  1145  0848 8f12fc1b           	sta IO_CON_CHAROUT
  1146  084c 8f13fc1b           	sta IO_CON_REGISTER
  1147  0850 a92c               	lda #','
  1148  0852 8f12fc1b           	sta IO_CON_CHAROUT
  1149  0856 8f13fc1b           	sta IO_CON_REGISTER
  1150  085a a959               	lda #'Y'
  1151  085c 8f12fc1b           	sta IO_CON_CHAROUT
  1152  0860 8f13fc1b           	sta IO_CON_REGISTER
  1153  0864 60                 	rts
  1154                          amoda
  1155  0865 a928               	lda #'('
  1156  0867 8f12fc1b           	sta IO_CON_CHAROUT
  1157  086b 8f13fc1b           	sta IO_CON_REGISTER
  1158  086f a924               	lda #'$'
  1159  0871 8f12fc1b           	sta IO_CON_CHAROUT
  1160  0875 8f13fc1b           	sta IO_CON_REGISTER
  1161  0879 a00100             	ldy #$0001
  1162  087c b73a               	lda [mondump],y
  1163  087e 20bd05             	jsr prhex
  1164  0881 a929               	lda #')'
  1165  0883 8f12fc1b           	sta IO_CON_CHAROUT
  1166  0887 8f13fc1b           	sta IO_CON_REGISTER
  1167  088b 60                 	rts
  1168                          amodb
  1169  088c a928               	lda #'('
  1170  088e 8f12fc1b           	sta IO_CON_CHAROUT
  1171  0892 8f13fc1b           	sta IO_CON_REGISTER
  1172  0896 a924               	lda #'$'
  1173  0898 8f12fc1b           	sta IO_CON_CHAROUT
  1174  089c 8f13fc1b           	sta IO_CON_REGISTER
  1175  08a0 a00100             	ldy #$0001
  1176  08a3 b73a               	lda [mondump],y
  1177  08a5 20bd05             	jsr prhex
  1178  08a8 a92c               	lda #','
  1179  08aa 8f12fc1b           	sta IO_CON_CHAROUT
  1180  08ae 8f13fc1b           	sta IO_CON_REGISTER
  1181  08b2 a953               	lda #'S'
  1182  08b4 8f12fc1b           	sta IO_CON_CHAROUT
  1183  08b8 8f13fc1b           	sta IO_CON_REGISTER
  1184  08bc a929               	lda #')'
  1185  08be 8f12fc1b           	sta IO_CON_CHAROUT
  1186  08c2 8f13fc1b           	sta IO_CON_REGISTER
  1187  08c6 a92c               	lda #','
  1188  08c8 8f12fc1b           	sta IO_CON_CHAROUT
  1189  08cc 8f13fc1b           	sta IO_CON_REGISTER
  1190  08d0 a959               	lda #'Y'
  1191  08d2 8f12fc1b           	sta IO_CON_CHAROUT
  1192  08d6 8f13fc1b           	sta IO_CON_REGISTER
  1193  08da 60                 	rts
  1194                          amodc
  1195  08db a924               	lda #'$'
  1196  08dd 8f12fc1b           	sta IO_CON_CHAROUT
  1197  08e1 8f13fc1b           	sta IO_CON_REGISTER
  1198  08e5 a00100             	ldy #$0001
  1199  08e8 b73a               	lda [mondump],y
  1200  08ea 20bd05             	jsr prhex
  1201  08ed a92c               	lda #','
  1202  08ef 8f12fc1b           	sta IO_CON_CHAROUT
  1203  08f3 8f13fc1b           	sta IO_CON_REGISTER
  1204  08f7 a958               	lda #'X'
  1205  08f9 8f12fc1b           	sta IO_CON_CHAROUT
  1206  08fd 8f13fc1b           	sta IO_CON_REGISTER
  1207  0901 60                 	rts
  1208                          amodd
  1209  0902 a95b               	lda #'['
  1210  0904 8f12fc1b           	sta IO_CON_CHAROUT
  1211  0908 8f13fc1b           	sta IO_CON_REGISTER
  1212  090c a924               	lda #'$'
  1213  090e 8f12fc1b           	sta IO_CON_CHAROUT
  1214  0912 8f13fc1b           	sta IO_CON_REGISTER
  1215  0916 a00100             	ldy #$0001
  1216  0919 b73a               	lda [mondump],y
  1217  091b 20bd05             	jsr prhex
  1218  091e a95d               	lda #']'
  1219  0920 8f12fc1b           	sta IO_CON_CHAROUT
  1220  0924 8f13fc1b           	sta IO_CON_REGISTER
  1221  0928 a92c               	lda #','
  1222  092a 8f12fc1b           	sta IO_CON_CHAROUT
  1223  092e 8f13fc1b           	sta IO_CON_REGISTER
  1224  0932 a959               	lda #'Y'
  1225  0934 8f12fc1b           	sta IO_CON_CHAROUT
  1226  0938 8f13fc1b           	sta IO_CON_REGISTER
  1227  093c 60                 	rts
  1228                          amode
  1229  093d a924               	lda #'$'
  1230  093f 8f12fc1b           	sta IO_CON_CHAROUT
  1231  0943 8f13fc1b           	sta IO_CON_REGISTER
  1232  0947 a00200             	ldy #$0002
  1233  094a b73a               	lda [mondump],y
  1234  094c 20bd05             	jsr prhex
  1235  094f 88                 	dey
  1236  0950 b73a               	lda [mondump],y
  1237  0952 20bd05             	jsr prhex
  1238  0955 a92c               	lda #','
  1239  0957 8f12fc1b           	sta IO_CON_CHAROUT
  1240  095b 8f13fc1b           	sta IO_CON_REGISTER
  1241  095f a958               	lda #'X'
  1242  0961 8f12fc1b           	sta IO_CON_CHAROUT
  1243  0965 8f13fc1b           	sta IO_CON_REGISTER
  1244  0969 60                 	rts
  1245                          amodf
  1246  096a a924               	lda #'$'
  1247  096c 8f12fc1b           	sta IO_CON_CHAROUT
  1248  0970 8f13fc1b           	sta IO_CON_REGISTER
  1249  0974 a00200             	ldy #$0002
  1250  0977 b73a               	lda [mondump],y
  1251  0979 20bd05             	jsr prhex
  1252  097c 88                 	dey
  1253  097d b73a               	lda [mondump],y
  1254  097f 20bd05             	jsr prhex
  1255  0982 a92c               	lda #','
  1256  0984 8f12fc1b           	sta IO_CON_CHAROUT
  1257  0988 8f13fc1b           	sta IO_CON_REGISTER
  1258  098c a959               	lda #'Y'
  1259  098e 8f12fc1b           	sta IO_CON_CHAROUT
  1260  0992 8f13fc1b           	sta IO_CON_REGISTER
  1261  0996 60                 	rts
  1262                          amod10
  1263  0997 a924               	lda #'$'
  1264  0999 8f12fc1b           	sta IO_CON_CHAROUT
  1265  099d 8f13fc1b           	sta IO_CON_REGISTER
  1266  09a1 a00300             	ldy #$0003
  1267  09a4 b73a               	lda [mondump],y
  1268  09a6 20bd05             	jsr prhex
  1269  09a9 88                 	dey
  1270  09aa b73a               	lda [mondump],y
  1271  09ac 20bd05             	jsr prhex
  1272  09af 88                 	dey
  1273  09b0 b73a               	lda [mondump],y
  1274  09b2 20bd05             	jsr prhex
  1275  09b5 a92c               	lda #','
  1276  09b7 8f12fc1b           	sta IO_CON_CHAROUT
  1277  09bb 8f13fc1b           	sta IO_CON_REGISTER
  1278  09bf a958               	lda #'X'
  1279  09c1 8f12fc1b           	sta IO_CON_CHAROUT
  1280  09c5 8f13fc1b           	sta IO_CON_REGISTER
  1281  09c9 60                 	rts
  1282                          amod12
  1283  09ca a928               	lda #'('
  1284  09cc 8f12fc1b           	sta IO_CON_CHAROUT
  1285  09d0 8f13fc1b           	sta IO_CON_REGISTER
  1286  09d4 a924               	lda #'$'
  1287  09d6 8f12fc1b           	sta IO_CON_CHAROUT
  1288  09da 8f13fc1b           	sta IO_CON_REGISTER
  1289  09de a00200             	ldy #$0002
  1290  09e1 b73a               	lda [mondump],y
  1291  09e3 20bd05             	jsr prhex
  1292  09e6 88                 	dey
  1293  09e7 b73a               	lda [mondump],y
  1294  09e9 20bd05             	jsr prhex
  1295  09ec a929               	lda #')'
  1296  09ee 8f12fc1b           	sta IO_CON_CHAROUT
  1297  09f2 8f13fc1b           	sta IO_CON_REGISTER
  1298  09f6 60                 	rts
  1299                          amod13
  1300  09f7 a928               	lda #'('
  1301  09f9 8f12fc1b           	sta IO_CON_CHAROUT
  1302  09fd 8f13fc1b           	sta IO_CON_REGISTER
  1303  0a01 a924               	lda #'$'
  1304  0a03 8f12fc1b           	sta IO_CON_CHAROUT
  1305  0a07 8f13fc1b           	sta IO_CON_REGISTER
  1306  0a0b a00200             	ldy #$0002
  1307  0a0e b73a               	lda [mondump],y
  1308  0a10 20bd05             	jsr prhex
  1309  0a13 88                 	dey
  1310  0a14 b73a               	lda [mondump],y
  1311  0a16 20bd05             	jsr prhex
  1312  0a19 a92c               	lda #','
  1313  0a1b 8f12fc1b           	sta IO_CON_CHAROUT
  1314  0a1f 8f13fc1b           	sta IO_CON_REGISTER
  1315  0a23 a958               	lda #'X'
  1316  0a25 8f12fc1b           	sta IO_CON_CHAROUT
  1317  0a29 8f13fc1b           	sta IO_CON_REGISTER
  1318  0a2d a929               	lda #')'
  1319  0a2f 8f12fc1b           	sta IO_CON_CHAROUT
  1320  0a33 8f13fc1b           	sta IO_CON_REGISTER
  1321  0a37 60                 	rts
  1322                          amod14
  1323  0a38 a924               	lda #'$'
  1324  0a3a 8f12fc1b           	sta IO_CON_CHAROUT
  1325  0a3e 8f13fc1b           	sta IO_CON_REGISTER
  1326  0a42 a00100             	ldy #$0001
  1327  0a45 b73a               	lda [mondump],y
  1328  0a47 20bd05             	jsr prhex
  1329  0a4a a92c               	lda #','
  1330  0a4c 8f12fc1b           	sta IO_CON_CHAROUT
  1331  0a50 8f13fc1b           	sta IO_CON_REGISTER
  1332  0a54 a959               	lda #'Y'
  1333  0a56 8f12fc1b           	sta IO_CON_CHAROUT
  1334  0a5a 8f13fc1b           	sta IO_CON_REGISTER
  1335  0a5e 60                 	rts
  1336                          	
  1337                          						;test branches for disassembly purposes..
  1338  0a5f 70d7               	bvs amod14
  1339  0a61 7010               	bvs is816
  1340  0a63 7092               	bvs amod13
  1341  0a65 703d               	bvs listamod
  1342  0a67 6260ff             	per amod12
  1343  0a6a 620600             	per is816
  1344  0a6d 6227ff             	per amod10
  1345  0a70 623100             	per listamod
  1346                          	
  1347                          	!zone is816
  1348                          is816
  1349  0a73 48                 	pha
  1350  0a74 291f               	and #$1f
  1351  0a76 c909               	cmp #$09				;09, 29, 49, etc?
  1352  0a78 d006               	bne .testx
  1353  0a7a 242d               	bit alarge				;16 bit?
  1354  0a7c 3020               	bmi .is16
  1355  0a7e 1018               	bpl .is8
  1356                          .testx
  1357  0a80 68                 	pla
  1358  0a81 48                 	pha
  1359  0a82 c9a0               	cmp #$a0
  1360  0a84 f00e               	beq .isx
  1361  0a86 c9a2               	cmp #$a2
  1362  0a88 f00a               	beq .isx
  1363  0a8a c9c0               	cmp #$c0
  1364  0a8c f006               	beq .isx
  1365  0a8e c9e0               	cmp #$e0
  1366  0a90 f002               	beq .isx
  1367  0a92 68                 	pla						;made it here, not an accumulator or index instruction
  1368  0a93 60                 	rts
  1369                          .isx
  1370  0a94 242e               	bit xlarge
  1371  0a96 3006               	bmi .is16				;or else fall thru
  1372                          .is8
  1373  0a98 a902               	lda #$2
  1374  0a9a 852f               	sta scratch1
  1375  0a9c 68                 	pla
  1376  0a9d 60                 	rts
  1377                          .is16
  1378  0a9e a903               	lda #$3
  1379  0aa0 852f               	sta scratch1
  1380  0aa2 68                 	pla
  1381  0aa3 60                 	rts
  1382                          	
  1383                          listamod
  1384  0aa4 fa06               	!16 amod0			;$xx
  1385  0aa6 0d07               	!16 amod1			;($xx,X)
  1386  0aa8 4807               	!16 amod2			;x,S
  1387  0aaa 6507               	!16 amod3			;[$xx]
  1388  0aac 8b07               	!16 amod4			;implied
  1389  0aae 8c07               	!16 amod5			;#$xx (or #$yyxx)
  1390  0ab0 b707               	!16 amod6			;$yyxx
  1391  0ab2 cf07               	!16 amod7			;$zzyyxx
  1392  0ab4 fd07               	!16 amod8			;rel8
  1393  0ab6 2a08               	!16 amod9			;($xx),Y
  1394  0ab8 6508               	!16 amoda			;($xx)
  1395  0aba 8c08               	!16 amodb			;(xx,S),Y
  1396  0abc db08               	!16 amodc			;$xx,X
  1397  0abe 0209               	!16 amodd			;[$xx],Y
  1398  0ac0 3d09               	!16 amode			;$yyxx,X
  1399  0ac2 6a09               	!16 amodf			;$yyxx,Y
  1400  0ac4 9709               	!16 amod10			;$zzyyxx,X
  1401  0ac6 ed07               	!16 amod11			;rel16
  1402  0ac8 ca09               	!16 amod12			;($yyxx)
  1403  0aca f709               	!16 amod13			;($yyxx,X)
  1404  0acc 380a               	!16 amod14			;$xx,Y
  1405                          	
  1406                          mnemlenmode
  1407  0ace 40                 	!byte %01000000		;00 brk 2/$xx
  1408  0acf 41                 	!byte %01000001		;01 ora 2/($xx,x)
  1409  0ad0 40                 	!byte %01000000		;02 cop 2/$xx
  1410  0ad1 42                 	!byte %01000010		;03 ora 2/x,s
  1411  0ad2 40                 	!byte %01000000		;04 tsb 2/$xx
  1412  0ad3 40                 	!byte %01000000		;05 ora 2/$xx
  1413  0ad4 40                 	!byte %01000000		;06 asl 2/$xx
  1414  0ad5 43                 	!byte %01000011		;07 ora 2/[$xx]
  1415  0ad6 24                 	!byte %00100100		;08 php 1
  1416  0ad7 45                 	!byte %01000101		;09 ora 2/#imm
  1417  0ad8 24                 	!byte %00100100		;0a asl 1
  1418  0ad9 24                 	!byte %00100100		;0b phd 1
  1419  0ada 66                 	!byte %01100110		;0c tsb 3/$yyxx
  1420  0adb 66                 	!byte %01100110		;0d ora 3/$yyxx
  1421  0adc 66                 	!byte %01100110		;0e asl 3/$yyxx
  1422  0add 87                 	!byte %10000111		;0f ora 4/$zzyyxx
  1423  0ade 48                 	!byte %01001000		;10 bpl 2/rel8
  1424  0adf 49                 	!byte %01001001		;11 ora 2/($xx),Y
  1425  0ae0 4a                 	!byte %01001010		;12 ora 2/($xx)
  1426  0ae1 4b                 	!byte %01001011		;13 ora 2/(x,s),Y
  1427  0ae2 40                 	!byte %01000000		;14 trb 2/$xx
  1428  0ae3 4c                 	!byte %01001100		;15 ora 2/$xx,X
  1429  0ae4 4c                 	!byte %01001100		;16 asl 2/$xx,X
  1430  0ae5 4d                 	!byte %01001101		;17 ora 2/[$xx],Y
  1431  0ae6 24                 	!byte %00100100		;18 clc 1
  1432  0ae7 6f                 	!byte %01101111		;19 ora 3/$yyxx,Y
  1433  0ae8 24                 	!byte %00100100		;1a inc 1
  1434  0ae9 24                 	!byte %00100100		;1b tcs 1
  1435  0aea 66                 	!byte %01100110		;1c trb 3/$yyxx
  1436  0aeb 6e                 	!byte %01101110		;1d ora 3/$yyxx,X
  1437  0aec 6e                 	!byte %01101110		;1e asl 3/$yyxx,X
  1438  0aed 90                 	!byte %10010000		;1f ora 4/$zzyyxx,X
  1439  0aee 66                 	!byte %01100110		;20 jsr 3/$yyxx
  1440  0aef 41                 	!byte %01000001		;21 and 2/($xx,x)
  1441  0af0 87                 	!byte %10000111		;22 jsl 4/$zzyyxx
  1442  0af1 42                 	!byte %01000010		;23 and 2/x,s
  1443  0af2 40                 	!byte %01000000		;24 bit 2/$xx
  1444  0af3 40                 	!byte %01000000		;25 and 2/$xx
  1445  0af4 40                 	!byte %01000000		;26 rol 2/$xx
  1446  0af5 43                 	!byte %01000011		;27 and 2/[$xx]
  1447  0af6 24                 	!byte %00100100		;28 plp 1
  1448  0af7 45                 	!byte %01000101		;29 and 2/#imm
  1449  0af8 24                 	!byte %00100100		;2a rol 1
  1450  0af9 24                 	!byte %00100100		;2b pld 1
  1451  0afa 66                 	!byte %01100110		;2c bit 3/$yyxx
  1452  0afb 66                 	!byte %01100110		;2d and 3/$yyxx
  1453  0afc 66                 	!byte %01100110		;2e rol 3/$yyxx
  1454  0afd 87                 	!byte %10000111		;2f and 4/$zzyyxx
  1455  0afe 48                 	!byte %01001000		;30 bmi 2/rel8
  1456  0aff 49                 	!byte %01001001		;31 and 2/($xx),Y
  1457  0b00 4a                 	!byte %01001010		;32 and 2/($xx)
  1458  0b01 4b                 	!byte %01001011		;33 and 2/(x,s),Y
  1459  0b02 4c                 	!byte %01001100		;34 bit 2/$xx,X
  1460  0b03 4c                 	!byte %01001100		;35 and 2/$xx,X
  1461  0b04 4c                 	!byte %01001100		;36 rol 2/$xx,X
  1462  0b05 4d                 	!byte %01001101		;37 and 2/[$xx],Y
  1463  0b06 24                 	!byte %00100100		;38 sec 1
  1464  0b07 6f                 	!byte %01101111		;39 and 3/$yyxx,Y
  1465  0b08 24                 	!byte %00100100		;3a dec 1
  1466  0b09 24                 	!byte %00100100		;3b tsc 1
  1467  0b0a 6e                 	!byte %01101110		;3c bit 3/$yyxx,X
  1468  0b0b 6e                 	!byte %01101110		;3d and 3/$yyxx,X
  1469  0b0c 6e                 	!byte %01101110		;3e rol 3/$yyxx,X
  1470  0b0d 90                 	!byte %10010000		;3f and 4/$zzyyxx,X
  1471  0b0e 24                 	!byte %00100100		;40 ???
  1472  0b0f 41                 	!byte %01000001		;41 eor 2/($xx,x)
  1473  0b10 40                 	!byte %01000000		;42 wdm 2/$00
  1474  0b11 42                 	!byte %01000010		;43 eor 2/x,s
  1475  0b12 24                 	!byte %00100100		;44 ???
  1476  0b13 40                 	!byte %01000000		;45 eor 2/$xx
  1477  0b14 40                 	!byte %01000000		;46 lsr 2/$xx
  1478  0b15 43                 	!byte %01000011		;47 eor 2/[$xx]
  1479  0b16 24                 	!byte %00100100		;48 pha 1
  1480  0b17 45                 	!byte %01000101		;49 eor 2/#imm
  1481  0b18 24                 	!byte %00100100		;4a lsr 1
  1482  0b19 24                 	!byte %00100100		;4b phk 1
  1483  0b1a 66                 	!byte %01100110		;4c jmp 3/$yyxx
  1484  0b1b 66                 	!byte %01100110		;4d eor 3/$yyxx
  1485  0b1c 66                 	!byte %01100110		;4e lsr 3/$yyxx
  1486  0b1d 87                 	!byte %10000111		;4f eor 4/$zzyyxx
  1487  0b1e 48                 	!byte %01001000		;50 bvc 2/rel8
  1488  0b1f 49                 	!byte %01001001		;51 eor 2/($xx),Y
  1489  0b20 4a                 	!byte %01001010		;52 eor 2/($xx)
  1490  0b21 4b                 	!byte %01001011		;53 eor 2/(x,s),Y
  1491  0b22 24                 	!byte %00100100		;54 ???
  1492  0b23 4c                 	!byte %01001100		;55 eor 2/$xx,X
  1493  0b24 4c                 	!byte %01001100		;56 lsr 2/$xx,X
  1494  0b25 4d                 	!byte %01001101		;57 eor 2/[$xx],Y
  1495  0b26 24                 	!byte %00100100		;58 cli 1
  1496  0b27 6f                 	!byte %01101111		;59 eor 3/$yyxx,Y
  1497  0b28 24                 	!byte %00100100		;5a phy 1
  1498  0b29 24                 	!byte %00100100		;5b tcd 1
  1499  0b2a 87                 	!byte %10000111		;5c jml 4/$zzyyxx
  1500  0b2b 6e                 	!byte %01101110		;5d eor 3/$yyxx,X
  1501  0b2c 6e                 	!byte %01101110		;5e lsr 3/$yyxx,X
  1502  0b2d 90                 	!byte %10010000		;5f eor 4/$zzyyxx,X
  1503  0b2e 24                 	!byte %00100100		;60 rts
  1504  0b2f 41                 	!byte %01000001		;61 adc 2/($xx,x)
  1505  0b30 71                 	!byte %01110001		;62 per 3/rel16
  1506  0b31 42                 	!byte %01000010		;63 adc 2/x,s
  1507  0b32 40                 	!byte %01000000		;64 stz 2/$xx
  1508  0b33 40                 	!byte %01000000		;65 adc 2/$xx
  1509  0b34 40                 	!byte %01000000		;66 ror 2/$xx
  1510  0b35 43                 	!byte %01000011		;67 adc 2/[$xx]
  1511  0b36 24                 	!byte %00100100		;68 pla 1
  1512  0b37 45                 	!byte %01000101		;69 adc 2/#imm
  1513  0b38 24                 	!byte %00100100		;6a ror 1
  1514  0b39 24                 	!byte %00100100		;6b rtl 1
  1515  0b3a 72                 	!byte %01110010		;6c jmp 3/($yyxx)
  1516  0b3b 66                 	!byte %01100110		;6d adc 3/$yyxx
  1517  0b3c 66                 	!byte %01100110		;6e ror 3/$yyxx
  1518  0b3d 87                 	!byte %10000111		;6f adc 4/$zzyyxx
  1519  0b3e 48                 	!byte %01001000		;70 bvs 2/rel8
  1520  0b3f 49                 	!byte %01001001		;71 adc 2/($xx),Y
  1521  0b40 4a                 	!byte %01001010		;72 adc 2/($xx)
  1522  0b41 4b                 	!byte %01001011		;73 adc 2/(x,s),Y
  1523  0b42 4c                 	!byte %01001100		;74 stz 2/$xx,X
  1524  0b43 4c                 	!byte %01001100		;75 adc 2/$xx,X
  1525  0b44 4c                 	!byte %01001100		;76 ror 2/$xx,X
  1526  0b45 4d                 	!byte %01001101		;77 adc 2/[$xx],Y
  1527  0b46 24                 	!byte %00100100		;78 sei 1
  1528  0b47 6f                 	!byte %01101111		;79 adc 3/$yyxx,Y
  1529  0b48 24                 	!byte %00100100		;7a ply 1
  1530  0b49 24                 	!byte %00100100		;7b tdc 1
  1531  0b4a 73                 	!byte %01110011		;7c jmp 3/($yyxx,X)
  1532  0b4b 6e                 	!byte %01101110		;7d adc 3/$yyxx,X
  1533  0b4c 6e                 	!byte %01101110		;7e lsr 3/$yyxx,X
  1534  0b4d 90                 	!byte %10010000		;7f adc 4/$zzyyxx,X
  1535  0b4e 48                 	!byte %01001000		;80 bra 2/rel8
  1536  0b4f 41                 	!byte %01000001		;81 sta 2/($xx,x)
  1537  0b50 71                 	!byte %01110001		;82 brl 3/rel16
  1538  0b51 42                 	!byte %01000010		;83 sta 2/x,s
  1539  0b52 40                 	!byte %01000000		;84 sty 2/$xx
  1540  0b53 40                 	!byte %01000000		;85 sta 2/$xx
  1541  0b54 40                 	!byte %01000000		;86 stx 2/$xx
  1542  0b55 43                 	!byte %01000011		;87 sta 2/[$xx]
  1543  0b56 24                 	!byte %00100100		;88 dey 1
  1544  0b57 45                 	!byte %01000101		;89 bit 2/#imm
  1545  0b58 24                 	!byte %00100100		;8a txa 1
  1546  0b59 24                 	!byte %00100100		;8b phb 1
  1547  0b5a 66                 	!byte %01100110		;8c sty 3/$yyxx
  1548  0b5b 66                 	!byte %01100110		;8d sta 3/$yyxx
  1549  0b5c 66                 	!byte %01100110		;8e stx 3/$yyxx
  1550  0b5d 87                 	!byte %10000111		;8f sta 4/$zzyyxx
  1551  0b5e 48                 	!byte %01001000		;90 bcc 2/rel8
  1552  0b5f 49                 	!byte %01001001		;91 sta 2/($xx),Y
  1553  0b60 4a                 	!byte %01001010		;92 sta 2/($xx)
  1554  0b61 4b                 	!byte %01001011		;93 sta 2/(x,s),Y
  1555  0b62 4c                 	!byte %01001100		;94 sty 2/$xx,X
  1556  0b63 4c                 	!byte %01001100		;95 sta 2/$xx,X
  1557  0b64 54                 	!byte %01010100		;96 stx 2/$xx,Y
  1558  0b65 4d                 	!byte %01001101		;97 sta 2/[$xx],Y
  1559  0b66 24                 	!byte %00100100		;98 txa 1
  1560  0b67 6f                 	!byte %01101111		;99 sta 3/$yyxx,Y
  1561  0b68 24                 	!byte %00100100		;9a txs 1
  1562  0b69 24                 	!byte %00100100		;9b txy 1
  1563  0b6a 66                 	!byte %01100110		;9c stz 3/$yyxx
  1564  0b6b 6e                 	!byte %01101110		;9d sta 3/$yyxx,X
  1565  0b6c 6e                 	!byte %01101110		;9e stz 3/$yyxx,X
  1566  0b6d 90                 	!byte %10010000		;9f sta 4/$zzyyxx,X
  1567  0b6e 45                 	!byte %01000101		;a0 ldy 2/#imm
  1568  0b6f 41                 	!byte %01000001		;a1 lda 2/($xx,x)
  1569  0b70 45                 	!byte %01000101		;a2 ldx 2/#imm
  1570  0b71 42                 	!byte %01000010		;a3 lda 2/x,s
  1571  0b72 40                 	!byte %01000000		;a4 ldy 2/$xx
  1572  0b73 40                 	!byte %01000000		;a5 sta 2/$xx
  1573  0b74 40                 	!byte %01000000		;a6 ldx 2/$xx
  1574  0b75 43                 	!byte %01000011		;a7 lda 2/[$xx]
  1575  0b76 24                 	!byte %00100100		;a8 tay 1
  1576  0b77 45                 	!byte %01000101		;a9 lda 2/#imm
  1577  0b78 24                 	!byte %00100100		;aa tax 1
  1578  0b79 24                 	!byte %00100100		;ab plb 1
  1579  0b7a 66                 	!byte %01100110		;ac ldy 3/$yyxx
  1580  0b7b 66                 	!byte %01100110		;ad lda 3/$yyxx
  1581  0b7c 66                 	!byte %01100110		;ae ldx 3/$yyxx
  1582  0b7d 87                 	!byte %10000111		;af lda 4/$zzyyxx
  1583  0b7e 48                 	!byte %01001000		;b0 bcs 2/rel8
  1584  0b7f 49                 	!byte %01001001		;b1 lda 2/($xx),Y
  1585  0b80 4a                 	!byte %01001010		;b2 lda 2/($xx)
  1586  0b81 4b                 	!byte %01001011		;b3 lda 2/(x,s),Y
  1587  0b82 4c                 	!byte %01001100		;b4 ldy 2/$xx,X
  1588  0b83 4c                 	!byte %01001100		;b5 lda 2/$xx,X
  1589  0b84 54                 	!byte %01010100		;b6 ldx 2/$xx,Y
  1590  0b85 4d                 	!byte %01001101		;b7 lda 2/[$xx],Y
  1591  0b86 24                 	!byte %00100100		;b8 clv 1
  1592  0b87 6f                 	!byte %01101111		;b9 lda 3/$yyxx,Y
  1593  0b88 24                 	!byte %00100100		;ba tsx 1
  1594  0b89 24                 	!byte %00100100		;bb tyx 1
  1595  0b8a 66                 	!byte %01100110		;bc ldy 3/$yyxx
  1596  0b8b 6e                 	!byte %01101110		;bd lda 3/$yyxx,X
  1597  0b8c 6e                 	!byte %01101110		;be ldx 3/$yyxx,X
  1598  0b8d 90                 	!byte %10010000		;bf lda 4/$zzyyxx,X
  1599  0b8e 45                 	!byte %01000101		;c0 cpy 2/#imm
  1600  0b8f 41                 	!byte %01000001		;c1 cmp 2/($xx,x)
  1601  0b90 45                 	!byte %01000101		;c2 rep 2/#imm
  1602  0b91 42                 	!byte %01000010		;c3 cmp 2/x,s
  1603  0b92 40                 	!byte %01000000		;c4 cpx 2/$xx
  1604  0b93 40                 	!byte %01000000		;c5 cmp 2/$xx
  1605  0b94 40                 	!byte %01000000		;c6 dec 2/$xx
  1606  0b95 43                 	!byte %01000011		;c7 cmp 2/[$xx]
  1607  0b96 24                 	!byte %00100100		;c8 iny 1
  1608  0b97 45                 	!byte %01000101		;c9 cmp 2/#imm
  1609  0b98 24                 	!byte %00100100		;ca dex 1
  1610  0b99 24                 	!byte %00100100		;cb wai 1
  1611  0b9a 66                 	!byte %01100110		;cc cpy 3/$yyxx
  1612  0b9b 66                 	!byte %01100110		;cd cmp 3/$yyxx
  1613  0b9c 66                 	!byte %01100110		;ce dec 3/$yyxx
  1614  0b9d 87                 	!byte %10000111		;cf cmp 4/$zzyyxx
  1615  0b9e 48                 	!byte %01001000		;d0 bne 2/rel8
  1616  0b9f 49                 	!byte %01001001		;d1 cmp 2/($xx),Y
  1617  0ba0 4a                 	!byte %01001010		;d2 cmp 2/($xx)
  1618  0ba1 4b                 	!byte %01001011		;d3 cmp 2/(x,s),Y
  1619  0ba2 4a                 	!byte %01001010		;d4 pei 2/($xx)
  1620  0ba3 4c                 	!byte %01001100		;d5 cmp 2/$xx,X
  1621  0ba4 4c                 	!byte %01001100		;d6 dec 2/$xx,X
  1622  0ba5 4d                 	!byte %01001101		;d7 cmp 2/[$xx],Y
  1623  0ba6 24                 	!byte %00100100		;d8 cld 1
  1624  0ba7 6f                 	!byte %01101111		;d9 cmp 3/$yyxx,Y
  1625  0ba8 24                 	!byte %00100100		;da phx 1
  1626  0ba9 24                 	!byte %00100100		;db stp 1
  1627  0baa 43                 	!byte %01000011		;dc jml 2/[$xx]
  1628  0bab 6e                 	!byte %01101110		;dd cmp 3/$yyxx,X
  1629  0bac 6e                 	!byte %01101110		;de dec 3/$yyxx,X
  1630  0bad 90                 	!byte %10010000		;df cmp 4/$zzyyxx,X
  1631  0bae 45                 	!byte %01000101		;e0 cpx 2/#imm
  1632  0baf 41                 	!byte %01000001		;e1 sbc 2/($xx,x)
  1633  0bb0 45                 	!byte %01000101		;e2 sep 2/#imm
  1634  0bb1 42                 	!byte %01000010		;e3 sbc 2/x,s
  1635  0bb2 40                 	!byte %01000000		;e4 cpx 2/$xx
  1636  0bb3 40                 	!byte %01000000		;e5 sbc 2/$xx
  1637  0bb4 40                 	!byte %01000000		;e6 inc 2/$xx
  1638  0bb5 43                 	!byte %01000011		;e7 sbc 2/[$xx]
  1639  0bb6 24                 	!byte %00100100		;e8 inx 1
  1640  0bb7 45                 	!byte %01000101		;e9 sbc 2/#imm
  1641  0bb8 24                 	!byte %00100100		;ea nop 1
  1642  0bb9 24                 	!byte %00100100		;eb xba 1
  1643  0bba 66                 	!byte %01100110		;ec cpx 3/$yyxx
  1644  0bbb 66                 	!byte %01100110		;ed sbc 3/$yyxx
  1645  0bbc 66                 	!byte %01100110		;ee inc 3/$yyxx
  1646  0bbd 87                 	!byte %10000111		;ef sbc 4/$zzyyxx
  1647  0bbe 48                 	!byte %01001000		;f0 beq 2/rel8
  1648  0bbf 49                 	!byte %01001001		;f1 sbc 2/($xx),Y
  1649  0bc0 4a                 	!byte %01001010		;f2 sbc 2/($xx)
  1650  0bc1 4b                 	!byte %01001011		;f3 sbc 2/(x,s),Y
  1651  0bc2 66                 	!byte %01100110		;f4 pea 3/$yyxx
  1652  0bc3 4c                 	!byte %01001100		;f5 sbc 2/$xx,X
  1653  0bc4 4c                 	!byte %01001100		;f6 inc 2/$xx,X
  1654  0bc5 4d                 	!byte %01001101		;f7 sbc 2/[$xx],Y
  1655  0bc6 24                 	!byte %00100100		;f8 sed 1
  1656  0bc7 6f                 	!byte %01101111		;f9 sbc 3/$yyxx,Y
  1657  0bc8 24                 	!byte %00100100		;fa plx 1
  1658  0bc9 24                 	!byte %00100100		;fb xce 1
  1659  0bca 73                 	!byte %01110011		;fc jsr 3/($yyxx)
  1660  0bcb 6e                 	!byte %01101110		;fd sbc 3/$yyxx,X
  1661  0bcc 6e                 	!byte %01101110		;fe inc 3/$yyxx,X
  1662  0bcd 90                 	!byte %10010000		;ff sbc 4/$zzyyxx,X
  1663                          mnemlist
  1664  0bce 00                 	!byte $00			;00 brk
  1665  0bcf 02                 	!byte $02			;01 ora
  1666  0bd0 01                 	!byte $01			;02 cop
  1667  0bd1 02                 	!byte $02			;03 ora
  1668  0bd2 03                 	!byte $03			;04 tsb
  1669  0bd3 02                 	!byte $02			;05 ora
  1670  0bd4 04                 	!byte $04			;06 asl
  1671  0bd5 02                 	!byte $02			;07 ora
  1672  0bd6 05                 	!byte $05			;08 php
  1673  0bd7 02                 	!byte $02			;09 ora
  1674  0bd8 04                 	!byte $04			;0a asl
  1675  0bd9 06                 	!byte $06			;0b phd
  1676  0bda 03                 	!byte $03			;0c tsb
  1677  0bdb 02                 	!byte $02			;0d ora
  1678  0bdc 04                 	!byte $04			;0e asl
  1679  0bdd 02                 	!byte $02			;0f ora
  1680  0bde 07                 	!byte $07			;10 bpl
  1681  0bdf 02                 	!byte $02			;11 ora
  1682  0be0 02                 	!byte $02			;12 ora
  1683  0be1 02                 	!byte $02			;13 ora
  1684  0be2 08                 	!byte $08			;14 trb
  1685  0be3 02                 	!byte $02			;15 ora
  1686  0be4 04                 	!byte $04			;16 asl
  1687  0be5 02                 	!byte $02			;17 ora
  1688  0be6 09                 	!byte $09			;18 clc
  1689  0be7 02                 	!byte $02			;19 ora
  1690  0be8 0a                 	!byte $0a			;1a inc
  1691  0be9 0b                 	!byte $0b			;1b tcs
  1692  0bea 08                 	!byte $08			;1c trb
  1693  0beb 02                 	!byte $02			;1d ora
  1694  0bec 04                 	!byte $04			;1e asl
  1695  0bed 02                 	!byte $02			;1f ora
  1696  0bee 0d                 	!byte $0d			;20 jsr
  1697  0bef 0c                 	!byte $0c			;21 and
  1698  0bf0 0e                 	!byte $0e			;22 jsl
  1699  0bf1 0c                 	!byte $0c			;23 and
  1700  0bf2 10                 	!byte $10			;24 bit
  1701  0bf3 0c                 	!byte $0c			;25 and
  1702  0bf4 11                 	!byte $11			;26 rol
  1703  0bf5 0c                 	!byte $0c			;27 and
  1704  0bf6 12                 	!byte $12			;28 plp
  1705  0bf7 0c                 	!byte $0c			;29 and
  1706  0bf8 11                 	!byte $11			;2a rol
  1707  0bf9 13                 	!byte $13			;2b pld
  1708  0bfa 10                 	!byte $10			;2c bit
  1709  0bfb 0c                 	!byte $0c			;2d and
  1710  0bfc 11                 	!byte $11			;2e rol
  1711  0bfd 0c                 	!byte $0c			;2f and
  1712  0bfe 14                 	!byte $14			;30 bmi
  1713  0bff 0c                 	!byte $0c			;31 and
  1714  0c00 0c                 	!byte $0c			;32 and
  1715  0c01 0c                 	!byte $0c			;33 and
  1716  0c02 11                 	!byte $11			;34 bit
  1717  0c03 0c                 	!byte $0c			;35 and
  1718  0c04 11                 	!byte $11			;36 rol
  1719  0c05 0c                 	!byte $0c			;37 and
  1720  0c06 15                 	!byte $15			;38 sec
  1721  0c07 0c                 	!byte $0c			;39 and
  1722  0c08 0f                 	!byte $0f			;3a dec
  1723  0c09 16                 	!byte $16			;3b tsc
  1724  0c0a 11                 	!byte $11			;3c bit
  1725  0c0b 0c                 	!byte $0c			;3d and
  1726  0c0c 11                 	!byte $11			;3e rol
  1727  0c0d 0c                 	!byte $0c			;3f and
  1728  0c0e 17                 	!byte $17			;40 ???
  1729  0c0f 18                 	!byte $18			;41 eor
  1730  0c10 19                 	!byte $19			;42 wdm
  1731  0c11 18                 	!byte $18			;43 eor
  1732  0c12 17                 	!byte $17			;44 ???
  1733  0c13 18                 	!byte $18			;45 eor
  1734  0c14 1a                 	!byte $1a			;46 lsr
  1735  0c15 18                 	!byte $18			;47 eor
  1736  0c16 1b                 	!byte $1b			;48 pha
  1737  0c17 18                 	!byte $18			;49 eor
  1738  0c18 1a                 	!byte $1a			;4a lsr
  1739  0c19 1c                 	!byte $1c			;4b phk
  1740  0c1a 1d                 	!byte $1d			;4c jmp
  1741  0c1b 18                 	!byte $18			;4d eor
  1742  0c1c 1a                 	!byte $1a			;4e lsr
  1743  0c1d 18                 	!byte $18			;4f eor
  1744  0c1e 1e                 	!byte $1e			;50 bvc
  1745  0c1f 18                 	!byte $18			;51 eor
  1746  0c20 18                 	!byte $18			;52 eor
  1747  0c21 18                 	!byte $18			;53 eor
  1748  0c22 17                 	!byte $17			;54 ???
  1749  0c23 18                 	!byte $18			;55 eor
  1750  0c24 1a                 	!byte $1a			;56 lsr
  1751  0c25 18                 	!byte $18			;57 eor
  1752  0c26 1f                 	!byte $1f			;58 cli
  1753  0c27 18                 	!byte $18			;59 eor
  1754  0c28 20                 	!byte $20			;5a phy
  1755  0c29 21                 	!byte $21			;5b tcd
  1756  0c2a 22                 	!byte $22			;5c jml
  1757  0c2b 18                 	!byte $18			;5d eor
  1758  0c2c 1a                 	!byte $1a			;5e lsr
  1759  0c2d 18                 	!byte $18			;5f eor
  1760  0c2e 23                 	!byte $23			;60 rts
  1761  0c2f 24                 	!byte $24			;61 adc
  1762  0c30 25                 	!byte $25			;62 per
  1763  0c31 24                 	!byte $24			;63 adc
  1764  0c32 26                 	!byte $26			;64 stz
  1765  0c33 24                 	!byte $24			;65 adc
  1766  0c34 27                 	!byte $27			;66 ror
  1767  0c35 24                 	!byte $24			;67 adc
  1768  0c36 28                 	!byte $28			;68 pla
  1769  0c37 24                 	!byte $24			;69 adc
  1770  0c38 27                 	!byte $27			;6a ror
  1771  0c39 29                 	!byte $29			;6b rtl
  1772  0c3a 1d                 	!byte $1d			;6c jmp
  1773  0c3b 24                 	!byte $24			;6d adc
  1774  0c3c 27                 	!byte $27			;6e ror
  1775  0c3d 24                 	!byte $24			;6f adc
  1776  0c3e 2a                 	!byte $2a			;70 bvs
  1777  0c3f 24                 	!byte $24			;71 adc
  1778  0c40 24                 	!byte $24			;72 adc
  1779  0c41 24                 	!byte $24			;73 adc
  1780  0c42 26                 	!byte $26			;74 stz
  1781  0c43 24                 	!byte $24			;75 adc
  1782  0c44 27                 	!byte $27			;76 ror
  1783  0c45 24                 	!byte $24			;77 adc
  1784  0c46 2b                 	!byte $2b			;78 sei
  1785  0c47 24                 	!byte $24			;79 adc
  1786  0c48 2c                 	!byte $2c			;7a ply
  1787  0c49 2d                 	!byte $2d			;7b tdc
  1788  0c4a 1d                 	!byte $1d			;7c jmp
  1789  0c4b 24                 	!byte $24			;7d adc
  1790  0c4c 27                 	!byte $27			;7e ror
  1791  0c4d 24                 	!byte $24			;7f adc
  1792  0c4e 2e                 	!byte $2e			;80 bra
  1793  0c4f 2f                 	!byte $2f			;81 sta
  1794  0c50 30                 	!byte $30			;82 brl
  1795  0c51 2f                 	!byte $2f			;83 sta
  1796  0c52 31                 	!byte $31			;84 sty
  1797  0c53 2f                 	!byte $2f			;85 sta
  1798  0c54 32                 	!byte $32			;86 stx
  1799  0c55 2f                 	!byte $2f			;87 sta
  1800  0c56 33                 	!byte $33			;88 dey
  1801  0c57 10                 	!byte $10			;89 bit
  1802  0c58 34                 	!byte $34			;8a txa
  1803  0c59 35                 	!byte $35			;8b phb
  1804  0c5a 31                 	!byte $31			;8c sty
  1805  0c5b 2f                 	!byte $2f			;8d sta
  1806  0c5c 32                 	!byte $32			;8e stx
  1807  0c5d 2f                 	!byte $2f			;8f sta
  1808  0c5e 36                 	!byte $36			;90 bcc
  1809  0c5f 2f                 	!byte $2f			;91 sta
  1810  0c60 2f                 	!byte $2f			;92 sta
  1811  0c61 2f                 	!byte $2f			;93 sta
  1812  0c62 31                 	!byte $31			;94 sty
  1813  0c63 2f                 	!byte $2f			;95 sta
  1814  0c64 32                 	!byte $32			;96 stx
  1815  0c65 2f                 	!byte $2f			;97 sta
  1816  0c66 37                 	!byte $37			;98 tya
  1817  0c67 2f                 	!byte $2f			;99 sta
  1818  0c68 38                 	!byte $38			;9a txs
  1819  0c69 39                 	!byte $39			;9b txy
  1820  0c6a 26                 	!byte $26			;9c stz
  1821  0c6b 2f                 	!byte $2f			;9d sta
  1822  0c6c 26                 	!byte $26			;9e stz
  1823  0c6d 2f                 	!byte $2f			;9f sta
  1824  0c6e 3c                 	!byte $3c			;a0 ldy
  1825  0c6f 3a                 	!byte $3a			;a1 lda
  1826  0c70 3b                 	!byte $3b			;a2 ldx
  1827  0c71 3a                 	!byte $3a			;a3 lda
  1828  0c72 3c                 	!byte $3c			;a4 ldy
  1829  0c73 3a                 	!byte $3a			;a5 lda
  1830  0c74 3b                 	!byte $3b			;a6 ldx
  1831  0c75 3a                 	!byte $3a			;a7 lda
  1832  0c76 3d                 	!byte $3d			;a8 tay
  1833  0c77 3a                 	!byte $3a			;a9 lda
  1834  0c78 3e                 	!byte $3e			;aa tax
  1835  0c79 3f                 	!byte $3f			;ab plb
  1836  0c7a 3c                 	!byte $3c			;ac ldy
  1837  0c7b 3a                 	!byte $3a			;ad lda
  1838  0c7c 3b                 	!byte $3b			;ae ldx
  1839  0c7d 3a                 	!byte $3a			;af lda
  1840  0c7e 40                 	!byte $40			;b0 bcs
  1841  0c7f 3a                 	!byte $3a			;b1 lda
  1842  0c80 3a                 	!byte $3a			;b2 lda
  1843  0c81 3a                 	!byte $3a			;b3 lda
  1844  0c82 3c                 	!byte $3c			;b4 ldy
  1845  0c83 3a                 	!byte $3a			;b5 lda
  1846  0c84 3b                 	!byte $3b			;b6 ldx
  1847  0c85 3a                 	!byte $3a			;b7 lda
  1848  0c86 41                 	!byte $41			;b8 clv
  1849  0c87 3a                 	!byte $3a			;b9 lda
  1850  0c88 42                 	!byte $42			;ba tsx
  1851  0c89 43                 	!byte $43			;bb tyx
  1852  0c8a 3c                 	!byte $3c			;bc ldy
  1853  0c8b 3a                 	!byte $3a			;bd lda
  1854  0c8c 3b                 	!byte $3b			;be ldx
  1855  0c8d 3a                 	!byte $3a			;bf lda
  1856  0c8e 46                 	!byte $46			;c0 cpy
  1857  0c8f 44                 	!byte $44			;c1 cmp
  1858  0c90 47                 	!byte $47			;c2 rep
  1859  0c91 44                 	!byte $44			;c3 cmp
  1860  0c92 46                 	!byte $46			;c4 cpy
  1861  0c93 44                 	!byte $44			;c5 cmp
  1862  0c94 48                 	!byte $48			;c6 dec
  1863  0c95 44                 	!byte $44			;c7 cmp
  1864  0c96 49                 	!byte $49			;c8 iny
  1865  0c97 44                 	!byte $44			;c9 cmp
  1866  0c98 4a                 	!byte $4a			;ca dex
  1867  0c99 4b                 	!byte $4b			;cb wai
  1868  0c9a 46                 	!byte $46			;cc cpy
  1869  0c9b 44                 	!byte $44			;cd cmp
  1870  0c9c 48                 	!byte $48			;ce dec
  1871  0c9d 44                 	!byte $44			;cf cmp
  1872  0c9e 4c                 	!byte $4c			;d0 bne
  1873  0c9f 44                 	!byte $44			;d1 cmp
  1874  0ca0 44                 	!byte $44			;d2 cmp
  1875  0ca1 44                 	!byte $44			;d3 cmp
  1876  0ca2 4d                 	!byte $4d			;d4 pei
  1877  0ca3 44                 	!byte $44			;d5 cmp
  1878  0ca4 48                 	!byte $48			;d6 dec
  1879  0ca5 44                 	!byte $44			;d7 cmp
  1880  0ca6 4e                 	!byte $4e			;d8 cld
  1881  0ca7 44                 	!byte $44			;d9 cmp
  1882  0ca8 4f                 	!byte $4f			;da phx
  1883  0ca9 50                 	!byte $50			;db stp
  1884  0caa 22                 	!byte $22			;dc jml
  1885  0cab 44                 	!byte $44			;dd cmp
  1886  0cac 48                 	!byte $48			;de dec
  1887  0cad 44                 	!byte $44			;df cmp
  1888  0cae 51                 	!byte $51			;e0 cpx
  1889  0caf 45                 	!byte $45			;e1 sbc
  1890  0cb0 52                 	!byte $52			;e2 sep
  1891  0cb1 45                 	!byte $45			;e3 sbc
  1892  0cb2 51                 	!byte $51			;e4 cpx
  1893  0cb3 45                 	!byte $45			;e5 sbc
  1894  0cb4 53                 	!byte $53			;e6 inc
  1895  0cb5 45                 	!byte $45			;e7 sbc
  1896  0cb6 54                 	!byte $54			;e8 inx
  1897  0cb7 45                 	!byte $45			;e9 sbc
  1898  0cb8 55                 	!byte $55			;ea nop
  1899  0cb9 56                 	!byte $56			;eb xba
  1900  0cba 51                 	!byte $51			;ec cpx
  1901  0cbb 45                 	!byte $45			;ed sbc
  1902  0cbc 53                 	!byte $53			;ee inc
  1903  0cbd 45                 	!byte $45			;ef sbc
  1904  0cbe 57                 	!byte $57			;f0 beq
  1905  0cbf 45                 	!byte $45			;f1 sbc
  1906  0cc0 45                 	!byte $45			;f2 sbc
  1907  0cc1 45                 	!byte $45			;f3 sbc
  1908  0cc2 58                 	!byte $58			;f4 pea
  1909  0cc3 45                 	!byte $45			;f5 sbc
  1910  0cc4 53                 	!byte $53			;f6 inc
  1911  0cc5 45                 	!byte $45			;f7 sbc
  1912  0cc6 59                 	!byte $59			;f8 sed
  1913  0cc7 45                 	!byte $45			;f9 sbc
  1914  0cc8 5a                 	!byte $5a			;fa plx
  1915  0cc9 5b                 	!byte $5b			;fb xce
  1916  0cca 0d                 	!byte $0d			;fc jsr
  1917  0ccb 45                 	!byte $45			;fd sbc
  1918  0ccc 53                 	!byte $53			;fe inc
  1919  0ccd 45                 	!byte $45			;ff sbc
  1920                          mnems
  1921  0cce 42524b             	!tx "BRK"			;0
  1922  0cd1 434f50             	!tx "COP"			;1
  1923  0cd4 4f5241             	!tx "ORA"			;2
  1924  0cd7 545342             	!tx "TSB"			;3
  1925  0cda 41534c             	!tx "ASL"			;4
  1926  0cdd 504850             	!tx "PHP"			;5
  1927  0ce0 504844             	!tx "PHD"			;6
  1928  0ce3 42504c             	!tx "BPL"			;7
  1929  0ce6 545242             	!tx "TRB"			;8
  1930  0ce9 434c43             	!tx "CLC"			;9
  1931  0cec 494e43             	!tx "INC"			;a
  1932  0cef 544353             	!tx "TCS"			;b
  1933  0cf2 414e44             	!tx "AND"			;c
  1934  0cf5 4a5352             	!tx "JSR"			;d
  1935  0cf8 4a534c             	!tx "JSL"			;e
  1936  0cfb 444543             	!tx "DEC"			;f
  1937  0cfe 424954             	!tx "BIT"			;10
  1938  0d01 524f4c             	!tx "ROL"			;11
  1939  0d04 504c50             	!tx "PLP"			;12
  1940  0d07 504c44             	!tx "PLD"			;13
  1941  0d0a 424d49             	!tx "BMI"			;14
  1942  0d0d 534543             	!tx "SEC"			;15
  1943  0d10 545343             	!tx "TSC"			;16
  1944  0d13 3f3f3f             	!tx "???"			;17
  1945  0d16 454f52             	!tx "EOR"			;18
  1946  0d19 57444d             	!tx "WDM"			;19
  1947  0d1c 4c5352             	!tx "LSR"			;1a
  1948  0d1f 504841             	!tx "PHA"			;1b
  1949  0d22 50484b             	!tx "PHK"			;1c
  1950  0d25 4a4d50             	!tx "JMP"			;1d
  1951  0d28 425643             	!tx "BVC"			;1e
  1952  0d2b 434c49             	!tx "CLI"			;1f
  1953  0d2e 504859             	!tx "PHY"			;20
  1954  0d31 544344             	!tx "TCD"			;21
  1955  0d34 4a4d4c             	!tx "JML"			;22
  1956  0d37 525453             	!tx "RTS"			;23
  1957  0d3a 414443             	!tx "ADC"			;24
  1958  0d3d 504552             	!tx "PER"			;25
  1959  0d40 53545a             	!tx "STZ"			;26
  1960  0d43 524f52             	!tx "ROR"			;27
  1961  0d46 504c41             	!tx "PLA"			;28
  1962  0d49 52544c             	!tx "RTL"			;29
  1963  0d4c 425653             	!tx "BVS"			;2a
  1964  0d4f 534549             	!tx "SEI"			;2b
  1965  0d52 504c59             	!tx "PLY"			;2c
  1966  0d55 544443             	!tx "TDC"			;2d
  1967  0d58 425241             	!tx "BRA"			;2e
  1968  0d5b 535441             	!tx "STA"			;2f
  1969  0d5e 42524c             	!tx "BRL"			;30
  1970  0d61 535459             	!tx "STY"			;31
  1971  0d64 535458             	!tx "STX"			;32
  1972  0d67 444559             	!tx "DEY"			;33
  1973  0d6a 545841             	!tx "TXA"			;34
  1974  0d6d 504842             	!tx "PHB"			;35
  1975  0d70 424343             	!tx "BCC"			;36
  1976  0d73 545941             	!tx "TYA"			;37
  1977  0d76 545853             	!tx "TXS"			;38
  1978  0d79 545859             	!tx "TXY"			;39
  1979  0d7c 4c4441             	!tx "LDA"			;3a
  1980  0d7f 4c4458             	!tx "LDX"			;3b
  1981  0d82 4c4459             	!tx "LDY"			;3c
  1982  0d85 544159             	!tx "TAY"			;3d
  1983  0d88 544158             	!tx "TAX"			;3e
  1984  0d8b 504c42             	!tx "PLB"			;3f
  1985  0d8e 424353             	!tx "BCS"			;40
  1986  0d91 434c56             	!tx "CLV"			;41
  1987  0d94 545358             	!tx "TSX"			;42
  1988  0d97 545958             	!tx "TYX"			;43
  1989  0d9a 434d50             	!tx "CMP"			;44
  1990  0d9d 534243             	!tx "SBC"			;45
  1991  0da0 435059             	!tx "CPY"			;46
  1992  0da3 524550             	!tx "REP"			;47
  1993  0da6 444543             	!tx "DEC"			;48
  1994  0da9 494e59             	!tx "INY"			;49
  1995  0dac 444558             	!tx "DEX"			;4a
  1996  0daf 574149             	!tx "WAI"			;4b
  1997  0db2 424e45             	!tx "BNE"			;4c
  1998  0db5 504549             	!tx "PEI"			;4d
  1999  0db8 434c44             	!tx "CLD"			;4e
  2000  0dbb 504858             	!tx "PHX"			;4f
  2001  0dbe 535450             	!tx "STP"			;50
  2002  0dc1 435058             	!tx "CPX"			;51
  2003  0dc4 534550             	!tx "SEP"			;52
  2004  0dc7 494e43             	!tx "INC"			;53
  2005  0dca 494e58             	!tx "INX"			;54
  2006  0dcd 4e4f50             	!tx "NOP"			;55
  2007  0dd0 584241             	!tx "XBA"			;56
  2008  0dd3 424551             	!tx "BEQ"			;57
  2009  0dd6 504541             	!tx "PEA"			;58
  2010  0dd9 534544             	!tx "SED"			;59
  2011  0ddc 504c58             	!tx "PLX"			;5a
  2012  0ddf 584345             	!tx "XCE"			;5b
  2013                          	
  2014                          	!zone ucline
  2015                          ucline					;convert inbuff at $170400 to upper case
  2016  0de2 08                 	php
  2017  0de3 c210               	rep #$10
  2018  0de5 e220               	sep #$20
  2019                          	!as
  2020                          	!rl
  2021  0de7 a20000             	ldx #$0000
  2022                          .local2
  2023  0dea bf000417           	lda inbuff,x
  2024  0dee f012               	beq .local4			;hit the zero, so bail
  2025  0df0 c961               	cmp #'a'
  2026  0df2 900b               	bcc .local3			;less then lowercase a, so ignore
  2027  0df4 c97b               	cmp #'z' + 1		;less than next character after lowercase z?
  2028  0df6 b007               	bcs .local3			;greater than or equal, so ignore
  2029  0df8 38                 	sec
  2030  0df9 e920               	sbc #('z' - 'Z')	;make upper case
  2031  0dfb 9f000417           	sta inbuff,x
  2032                          .local3
  2033  0dff e8                 	inx
  2034  0e00 80e8               	bra .local2
  2035                          .local4
  2036  0e02 28                 	plp
  2037  0e03 6b                 	rtl
  2038                          	
  2039                          	!zone getline
  2040                          getline
  2041  0e04 08                 	php
  2042  0e05 c210               	rep #$10
  2043  0e07 e220               	sep #$20
  2044                          	!as
  2045                          	!rl
  2046  0e09 a20000             	ldx #$0000
  2047                          .local2
  2048  0e0c af00fc1b           	lda IO_KEYQ_SIZE
  2049  0e10 f0fa               	beq .local2
  2050  0e12 af01fc1b           	lda IO_KEYQ_WAITING
  2051  0e16 8f02fc1b           	sta IO_KEYQ_DEQUEUE
  2052  0e1a c90d               	cmp #$0d			;carriage return yet?
  2053  0e1c f01c               	beq .local3
  2054  0e1e c908               	cmp #$08			;backspace/back arrow?
  2055  0e20 f029               	beq .local4
  2056  0e22 c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
  2057  0e24 90e6               	bcc .local2		 		;yes, so ignore it
  2058  0e26 9f000417           	sta inbuff,x 		;any other character, so register it and store it
  2059  0e2a 8f12fc1b           	sta IO_CON_CHAROUT
  2060  0e2e 8f13fc1b           	sta IO_CON_REGISTER
  2061  0e32 e8                 	inx
  2062  0e33 a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
  2063  0e35 e0fe03             	cpx #$3fe			;overrun end of buffer yet?
  2064  0e38 d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
  2065                          .local3
  2066  0e3a 9f000417           	sta inbuff,x		;store CR
  2067  0e3e 8f17fc1b           	sta IO_CON_CR
  2068  0e42 e8                 	inx
  2069  0e43 a900               	lda #$00			;store zero to end it all
  2070  0e45 9f000417           	sta inbuff,x
  2071  0e49 28                 	plp
  2072  0e4a 6b                 	rtl
  2073                          .local4
  2074  0e4b e00000             	cpx #$0000
  2075  0e4e f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
  2076  0e50 a908               	lda #$08
  2077  0e52 8f12fc1b           	sta IO_CON_CHAROUT
  2078  0e56 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
  2079  0e5a a920               	lda #$20
  2080  0e5c 8f12fc1b           	sta IO_CON_CHAROUT
  2081  0e60 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
  2082  0e64 a908               	lda #$08
  2083  0e66 8f12fc1b           	sta IO_CON_CHAROUT
  2084  0e6a 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
  2085  0e6e ca                 	dex
  2086  0e6f 809b               	bra .local2
  2087                          	
  2088                          prinbuff				;feed location of input buffer into dpla and then print
  2089  0e71 08                 	php
  2090  0e72 c210               	rep #$10
  2091  0e74 e220               	sep #$20
  2092                          	!as
  2093                          	!rl
  2094  0e76 a917               	lda #$17
  2095  0e78 853f               	sta dpla_h
  2096  0e7a a904               	lda #$04
  2097  0e7c 853e               	sta dpla_m
  2098  0e7e 643d               	stz dpla
  2099  0e80 22860e1c           	jsl l_prcdpla
  2100  0e84 28                 	plp
  2101  0e85 6b                 	rtl
  2102                          	
  2103                          	!zone prcdpla
  2104                          prcdpla					; print C string pointed to by dp locations $3d-$3f
  2105  0e86 08                 	php
  2106  0e87 c210               	rep #$10
  2107  0e89 e220               	sep #$20
  2108                          	!as
  2109                          	!rl
  2110  0e8b a00000             	ldy #$0000
  2111                          .local2
  2112  0e8e b73d               	lda [dpla],y
  2113  0e90 f00b               	beq .local3
  2114  0e92 8f12fc1b           	sta IO_CON_CHAROUT
  2115  0e96 8f13fc1b           	sta IO_CON_REGISTER
  2116  0e9a c8                 	iny
  2117  0e9b 80f1               	bra .local2
  2118                          .local3
  2119  0e9d 28                 	plp
  2120  0e9e 6b                 	rtl
  2121                          
  2122                          initstring
  2123  0e9f 494d4c2036353831...	!tx "IML 65816 1C Firmware v00"
  2124  0eb8 0d                 	!byte 0x0d
  2125  0eb9 53797374656d204d...	!tx "System Monitor"
  2126  0ec7 0d                 	!byte 0x0d
  2127  0ec8 0d                 	!byte 0x0d
  2128  0ec9 00                 	!byte 0
  2129                          
  2130                          helpmsg
  2131  0eca 494d4c2036353831...	!tx "IML 65816 Monitor Commands"
  2132  0ee4 0d                 	!byte $0d
  2133  0ee5 41203c616464723e...	!tx "A <addr>  Dump ASCII"
  2134  0ef9 0d                 	!byte $0d
  2135  0efa 42203c62616e6b3e...	!tx "B <bank>  Change bank"
  2136  0f0f 0d                 	!byte $0d
  2137  0f10 43203c636f6c6f72...	!tx "C <color> Change terminal colors"
  2138  0f30 0d                 	!byte $0d
  2139  0f31 44203c616464723e...	!tx "D <addr>  Dump hex"
  2140  0f43 0d                 	!byte $0d
  2141  0f44 45203c616464723e...	!tx "E <addr> <byte> <byte>...  Enter bytes"
  2142  0f6a 0d                 	!byte $0d
  2143  0f6b 463f202020202020...	!tx "F?        Floating Point Support Help"
  2144  0f90 0d                 	!byte $0d
  2145  0f91 4c203c616464723e...	!tx "L <addr>  Disassemble 65816 Inst."
  2146  0fb2 0d                 	!byte $0d
  2147  0fb3 4d203c6d6f64653e...	!tx "M <mode>  Change video mode, 8/9"
  2148  0fd3 0d                 	!byte $0d
  2149  0fd4 5120202020202020...	!tx "Q         Halt the processor"
  2150  0ff0 0d                 	!byte $0d
  2151  0ff1 3f20202020202020...	!tx "?         This menu"
  2152  1004 0d                 	!byte $0d
  2153  1005 3c656e7465723e20...	!tx "<enter>   Repeat last dump command"
  2154  1027 0d                 	!byte $0d
  2155  1028 546f207370656369...	!tx "To specify range, use <addr1.addr2>"
  2156  104b 0d00               	!byte $0d, 00
  2157                          
  2158                          fphelpmsg
  2159  104d 494d4c20466c6f61...	!tx "IML Floating Point Support"
  2160  1067 0d                 	!byte $0d
  2161  1068 466f726d61743a20...	!tx "Format: F<cmd><sz><reg>"
  2162  107f 0d                 	!byte $0d
  2163  1080 53697a65733a2046...	!tx "Sizes: F=float D=double E=extended"
  2164  10a2 0d                 	!byte $0d
  2165  10a3 5265676973746572...	!tx "Registers: A=FACC B=FARG"
  2166  10bb 0d                 	!byte $0d
  2167  10bc 46443c737a3e2020...	!tx "FD<sz>    Display FACC/FARG"
  2168  10d7 0d                 	!byte $0d
  2169  10d8 46433c737a3e3c72...	!tx "FC<sz><reg> <constID> Load Constant"
  2170  10fb 0d                 	!byte $0d
  2171  10fc 46493c737a3e3c72...	!tx "FI<sz><reg> Load Integer from FPINT"
  2172  111f 0d                 	!byte $0d
  2173  1120 463c6f703e3c737a...	!tx "F<op><sz><reg> Bin Op, result in <reg>"
  2174  1146 0d                 	!byte $0d
  2175  1147 42696e617279204f...	!tx "Binary Ops: *, /, +, -"
  2176  115d 0d                 	!tx $0d
  2177  115e 464e3c737a3e3c72...	!tx "FN<sz><reg> Natural Log of <reg>"
  2178  117e 0d                 	!tx $0d
  2179  117f 00                 	!byte $00
  2180                          	
  2181  1180 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
  2182                          

; ******** done
