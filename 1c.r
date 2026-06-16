
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
    29                          IO_FP_EXP = $1bfc49
    30                          IO_FP_ILOAD = $1bfc47
    31                          IO_FP_ISAVE = $1bfc48
    32                          
    33                          FPCOND = $1bfcbf
    34                          FPASCII = $1bfcc0
    35                          FPASCII_LO16 = $fcc0
    36                          FPINT = $1bfcd8
    37                          FPACCUMULATOR = $1bfce0
    38                          FPARGUMENT = $1bfcf0
    39                          
    40                          promptchar = '*'
    41                          
    42                          l_getline = $1c0000 + getline
    43                          l_prinbuff = $1c0000 + prinbuff
    44                          l_prcdpla = $1c0000 + prcdpla
    45                          l_prcoldpla = $1c0000 + prcoldpla
    46                          l_ucline = $1c0000 + ucline
    47                          
    48                          fpregspec = $28
    49                          fpmask = $29
    50                          scratch2 = $2a
    51                          scratch2_m = $2b
    52                          scratch2_h = $2c
    53                          alarge = $2d
    54                          xlarge = $2e
    55                          scratch1 = $2f
    56                          enterbytes = $30
    57                          enterbytes_m = $31
    58                          enterbytes_h = $32
    59                          rangehigh = $33
    60                          monrange = $35
    61                          monlast = $36
    62                          parseptr = $37
    63                          parseptr_m = $38
    64                          parseptr_h = $39
    65                          mondump = $3a
    66                          mondump_m = $3b
    67                          mondump_h = $3c
    68                          dpla = $3d
    69                          dpla_m = $3e
    70                          dpla_h = $3f
    71                          
    72                          inbuff = $170400
    73                          
    74                          x1crominit
    75  0000 4b                 	phk
    76  0001 ab                 	plb
    77  0002 c210               	rep #$10
    78                          	!rl
    79  0004 e220               	sep #$20
    80                          	!as
    81  0006 a23f0f             	ldx #initbanner
    82  0009 863d               	stx dpla
    83  000b a91c               	lda #$1c
    84  000d 853f               	sta dpla_h
    85  000f 22130f1c           	jsl l_prcoldpla
    86  0013 a2740f             	ldx #initstring
    87  0016 863d               	stx dpla
    88  0018 22d30e1c           	jsl l_prcdpla
    89  001c 4c0904             	jmp+2 monstart
    90                          
    91                          parse_setup
    92  001f a20004             	ldx #$0400
    93  0022 8637               	stx parseptr
    94  0024 a917               	lda #$17
    95  0026 8539               	sta parseptr_h
    96  0028 60                 	rts
    97                          	
    98                          	!zone parse_getchar
    99                          parse_getchar			;get char from inbuff, assumes 8 bit A, 16 bit X
   100  0029 a737               	lda [parseptr]
   101  002b 48                 	pha
   102  002c e637               	inc parseptr
   103  002e d006               	bne .local2
   104  0030 e638               	inc parseptr_m
   105  0032 d002               	bne .local2
   106  0034 e639               	inc parseptr_h
   107                          .local2
   108  0036 68                 	pla
   109  0037 60                 	rts
   110                          	
   111                          	!zone parse_addr
   112                          parse_addr				;see if user specified an address on line.
   113  0038 a900               	lda #$00
   114  003a 48                 	pha
   115  003b 48                 	pha					;make space for working value on the stack
   116  003c 8535               	sta monrange		;clear range flag
   117                          .throwaway
   118  003e 202900             	jsr+2 parse_getchar
   119  0041 c920               	cmp #' '
   120  0043 f0f9               	beq .throwaway		;throw away leading spaces
   121  0045 20a100             	jsr+2 parse_getnib2	;get first nibble. call 2nd entry point since we already have character
   122  0048 9051               	bcc .no				;didn't even get one hex character, so return false
   123  004a 8301               	sta 1,s				;save it on the stack for now
   124  004c 209e00             	jsr+2 parse_getnib	;get second nibble
   125  004f 9047               	bcc .yes			;if not hex then bail
   126  0051 48                 	pha
   127  0052 a302               	lda 2,s
   128  0054 0a                 	asl
   129  0055 0a                 	asl
   130  0056 0a                 	asl
   131  0057 0a                 	asl
   132  0058 0301               	ora 1,s
   133  005a 8302               	sta 2,s
   134  005c 68                 	pla					;add to stack
   135  005d 209e00             	jsr+2 parse_getnib	;get possible third nibble
   136  0060 9036               	bcc .yes
   137  0062 c230               	rep #$30			;we're dealing with a 16 bit value now
   138                          	!al
   139  0064 290f00             	and #$000f
   140  0067 48                 	pha
   141  0068 a303               	lda 3,s
   142  006a 0a                 	asl
   143  006b 0a                 	asl
   144  006c 0a                 	asl
   145  006d 0a                 	asl
   146  006e 0301               	ora 1,s
   147  0070 8303               	sta 3,s
   148  0072 68                 	pla
   149  0073 e220               	sep #$20
   150                          	!as
   151  0075 209e00             	jsr+2 parse_getnib
   152  0078 901e               	bcc .yes
   153  007a c230               	rep #$30
   154                          	!al
   155  007c 290f00             	and #$000f
   156  007f 48                 	pha
   157  0080 a303               	lda 3,s
   158  0082 0a                 	asl
   159  0083 0a                 	asl
   160  0084 0a                 	asl
   161  0085 0a                 	asl
   162  0086 0301               	ora 1,s
   163  0088 8303               	sta 3,s
   164  008a 68                 	pla
   165  008b e220               	sep #$20			;fall thru to yes on 4th nibble
   166                          	!as
   167  008d 202900             	jsr parse_getchar	;check to see if next char is a . so we can specify ranges
   168  0090 c92e               	cmp #'.'
   169  0092 d004               	bne .yes
   170  0094 a980               	lda #$80
   171  0096 8535               	sta monrange
   172                          .yes
   173  0098 7a                 	ply					;get 16 bit work address off of stack
   174  0099 38                 	sec					;got address, return
   175  009a 60                 	rts
   176                          .no
   177  009b 7a                 	ply					;clear stack
   178  009c 18                 	clc					;no address found, return
   179  009d 60                 	rts
   180                          parse_getnib
   181  009e 202900             	jsr parse_getchar
   182                          parse_getnib2			;enter here after we've thrown away leading spaces
   183  00a1 c920               	cmp #' '
   184  00a3 f021               	beq .outrng			;space = end of value
   185  00a5 c92e               	cmp #'.'
   186  00a7 d006               	bne .notrange
   187  00a9 a980               	lda #$80
   188  00ab 8535               	sta monrange		;this is the start of a range specification
   189  00ad 18                 	clc
   190  00ae 60                 	rts
   191                          .notrange
   192  00af c941               	cmp #$41
   193  00b1 900b               	bcc .outrnga
   194  00b3 c947               	cmp #$47
   195  00b5 b007               	bcs .outrnga
   196  00b7 38                 	sec
   197  00b8 e907               	sbc #$07			;in range of A-F
   198                          .success
   199  00ba 290f               	and #$0f
   200  00bc 38                 	sec
   201  00bd 60                 	rts
   202                          .outrnga				;test if 0-9
   203  00be c930               	cmp #$30
   204  00c0 9004               	bcc .outrng
   205  00c2 c93a               	cmp #$3a
   206  00c4 90f4               	bcc .success		;less than 3a, but >= 30, else fall thru to outrng
   207                          .outrng
   208  00c6 18                 	clc
   209  00c7 60                 	rts
   210                          	
   211                          prdumpaddr
   212  00c8 a53c               	lda mondump_h			;print long address
   213  00ca 200a06             	jsr+2 prhex
   214  00cd a92f               	lda #'/'
   215  00cf 8f12fc1b           	sta IO_CON_CHAROUT
   216  00d3 8f13fc1b           	sta IO_CON_REGISTER
   217  00d7 a63a               	ldx mondump
   218  00d9 200006             	jsr+2 prhex16
   219  00dc a92d               	lda #'-'
   220  00de 8f12fc1b           	sta IO_CON_CHAROUT
   221  00e2 8f13fc1b           	sta IO_CON_REGISTER
   222  00e6 a920               	lda #' '
   223  00e8 8f12fc1b           	sta IO_CON_CHAROUT
   224  00ec 8f13fc1b           	sta IO_CON_REGISTER
   225  00f0 60                 	rts
   226                          	
   227                          adjdumpaddr					;add 8 to dump address
   228  00f1 c230               	rep #$30
   229                          	!al
   230  00f3 a53a               	lda mondump
   231  00f5 18                 	clc
   232  00f6 690800             	adc #$0008
   233  00f9 853a               	sta mondump
   234  00fb e220               	sep #$20
   235                          	!as
   236  00fd 08                 	php						;save carry state.. did we carry to the bank?
   237  00fe a53c               	lda mondump_h
   238  0100 6900               	adc #$00
   239  0102 853c               	sta mondump_h
   240  0104 28                 	plp
   241  0105 60                 	rts
   242                          
   243                          	!zone fpcmd
   244                          fphelp
   245  0106 a20d11             	ldx #fphelpmsg
   246  0109 863d               	stx dpla
   247  010b a91c               	lda #$1c
   248  010d 853f               	sta dpla_h
   249  010f 22d30e1c           	jsl l_prcdpla
   250  0113 4c1c04             	jmp moncmd
   251                          fpcmd
   252  0116 202900             	jsr parse_getchar
   253  0119 c93f               	cmp #'?'
   254  011b f0e9               	beq fphelp
   255  011d c944               	cmp #'D'
   256  011f d003               	bne .fpcmd1
   257  0121 4c9902             	jmp fpdisp
   258                          .fpcmd1
   259  0124 c943               	cmp #'C'
   260  0126 d003               	bne .fpcmd2
   261  0128 4c7402             	jmp fploadconst
   262                          .fpcmd2
   263  012b c92a               	cmp #'*'
   264  012d d003               	bne .fpcmd6
   265  012f 4c0802             	jmp fpmultiply
   266                          .fpcmd6
   267  0132 c92f               	cmp #'/'
   268  0134 d003               	bne .fpcmd5
   269  0136 4c2302             	jmp fpdivide
   270                          .fpcmd5
   271  0139 c92b               	cmp #'+'
   272  013b d003               	bne .fpcmd4
   273  013d 4c3e02             	jmp fpadd
   274                          .fpcmd4
   275  0140 c92d               	cmp #'-'
   276  0142 d003               	bne .fpcmd3
   277  0144 4c5902             	jmp fpsubtract
   278                          .fpcmd3
   279  0147 c94e               	cmp #'N'
   280  0149 d003               	bne .fpcmdln
   281  014b 4cd201             	jmp fpln
   282                          .fpcmdln
   283  014e c945               	cmp #'E'
   284  0150 d003               	bne .fpcmdexp
   285  0152 4ced01             	jmp fpexp
   286                          .fpcmdexp
   287  0155 c949               	cmp #'I'
   288  0157 f043               	beq fpiload
   289  0159 c956               	cmp #'V'
   290  015b f05a               	beq fpisave
   291  015d 4cb403             	jmp monerror			;unrecognized FP command so fall thru to syntax error
   292                          
   293                          fpgetmask					;construct mask from size specifier, carry set if unregognized
   294  0160 202900             	jsr parse_getchar
   295  0163 c946               	cmp #'F'
   296  0165 d006               	bne .local1
   297  0167 a900               	lda #$00
   298  0169 8529               	sta fpmask				;set bits 5/7 of fp mask to 0
   299  016b 8016               	bra .local4
   300                          .local1
   301  016d c944               	cmp #'D'
   302  016f d006               	bne .local2
   303  0171 a980               	lda #$80				;bit 7=1, bit 5=0
   304  0173 8529               	sta fpmask
   305  0175 800c               	bra .local4
   306                          .local2
   307  0177 c945               	cmp #'E'
   308  0179 d006               	bne .local3
   309  017b a920               	lda #$20				;bit 7=0, bit 5=1
   310  017d 8529               	sta fpmask
   311  017f 8002               	bra .local4
   312                          .local3
   313  0181 38                 	sec						;unknown size
   314  0182 60                 	rts
   315                          .local4
   316  0183 18                 	clc
   317  0184 60                 	rts
   318                          	
   319                          fpgetregspec
   320  0185 202900             	jsr parse_getchar		;set fpregspec to 00 or 40 depending on register specified
   321  0188 c941               	cmp #'A'
   322  018a d004               	bne .localgrs1
   323  018c 6428               	stz fpregspec
   324  018e 8008               	bra .localgrs3
   325                          .localgrs1
   326  0190 c942               	cmp #'B'
   327  0192 d006               	bne .localgrs4
   328  0194 a940               	lda #$40
   329  0196 8528               	sta fpregspec
   330                          .localgrs3
   331  0198 18                 	clc
   332  0199 60                 	rts
   333                          .localgrs4
   334  019a 38                 	sec
   335  019b 60                 	rts
   336                          
   337                          fpiload
   338  019c 206001             	jsr fpgetmask
   339  019f 9003               	bcc .fpil1
   340  01a1 4cb403             	jmp monerror
   341                          .fpil1
   342  01a4 208501             	jsr fpgetregspec
   343  01a7 9003               	bcc .fpil2
   344  01a9 4cb403             	jmp monerror
   345                          .fpil2
   346  01ac a529               	lda fpmask
   347  01ae 0528               	ora fpregspec
   348  01b0 8f47fc1b           	sta IO_FP_ILOAD
   349  01b4 4c1c04             	jmp moncmd
   350                          
   351                          fpisave
   352  01b7 206001             	jsr fpgetmask
   353  01ba 9003               	bcc .fpis1
   354  01bc 4cb403             	jmp monerror
   355                          .fpis1
   356  01bf 208501             	jsr fpgetregspec
   357  01c2 9003               	bcc .fpis2
   358  01c4 4cb403             	jmp monerror
   359                          .fpis2
   360  01c7 a529               	lda fpmask
   361  01c9 0528               	ora fpregspec
   362  01cb 8f48fc1b           	sta IO_FP_ISAVE
   363  01cf 4c1c04             	jmp moncmd
   364                          
   365                          fpln
   366  01d2 206001             	jsr fpgetmask
   367  01d5 9003               	bcc .fpln1
   368  01d7 4cb403             	jmp monerror
   369                          .fpln1
   370  01da 208501             	jsr fpgetregspec
   371  01dd 9003               	bcc .fpln2
   372  01df 4cb403             	jmp monerror
   373                          .fpln2
   374  01e2 a529               	lda fpmask
   375  01e4 0528               	ora fpregspec
   376  01e6 8f46fc1b           	sta IO_FP_LN
   377  01ea 4c1c04             	jmp moncmd
   378                          
   379                          fpexp
   380  01ed 206001             	jsr fpgetmask
   381  01f0 9003               	bcc .fpexp1
   382  01f2 4cb403             	jmp monerror
   383                          	.fpexp1
   384  01f5 208501             	jsr fpgetregspec
   385  01f8 9003               	bcc .fpexp2
   386  01fa 4cb403             	jmp monerror
   387                          	.fpexp2
   388  01fd a529               	lda fpmask
   389  01ff 0528               	ora fpregspec
   390  0201 8f49fc1b           	sta IO_FP_EXP
   391  0205 4c1c04             	jmp moncmd
   392                          
   393                          fpmultiply
   394  0208 206001             	jsr fpgetmask
   395  020b 9003               	bcc .fpmultiply1
   396  020d 4cb403             	jmp monerror
   397                          .fpmultiply1
   398  0210 208501             	jsr fpgetregspec
   399  0213 9003               	bcc .fpmultiply2
   400  0215 4cb403             	jmp monerror
   401                          .fpmultiply2
   402  0218 a529               	lda fpmask
   403  021a 0528               	ora fpregspec
   404  021c 8f42fc1b           	sta IO_FP_MULTIPLY
   405  0220 4c1c04             	jmp moncmd
   406                          	
   407                          fpdivide
   408  0223 206001             	jsr fpgetmask
   409  0226 9003               	bcc .fpdivide1
   410  0228 4cb403             	jmp monerror
   411                          .fpdivide1
   412  022b 208501             	jsr fpgetregspec
   413  022e 9003               	bcc .fpdivide2
   414  0230 4cb403             	jmp monerror
   415                          .fpdivide2
   416  0233 a529               	lda fpmask
   417  0235 0528               	ora fpregspec
   418  0237 8f43fc1b           	sta IO_FP_DIVIDE
   419  023b 4c1c04             	jmp moncmd
   420                          	
   421                          fpadd
   422  023e 206001             	jsr fpgetmask
   423  0241 9003               	bcc .fpadd1
   424  0243 4cb403             	jmp monerror
   425                          .fpadd1
   426  0246 208501             	jsr fpgetregspec
   427  0249 9003               	bcc .fpadd2
   428  024b 4cb403             	jmp monerror
   429                          .fpadd2
   430  024e a529               	lda fpmask
   431  0250 0528               	ora fpregspec
   432  0252 8f44fc1b           	sta IO_FP_ADD
   433  0256 4c1c04             	jmp moncmd
   434                          	
   435                          fpsubtract
   436  0259 206001             	jsr fpgetmask
   437  025c 9003               	bcc .fpsubtract1
   438  025e 4cb403             	jmp monerror
   439                          .fpsubtract1
   440  0261 208501             	jsr fpgetregspec
   441  0264 9003               	bcc .fpsubtract2
   442  0266 4cb403             	jmp monerror
   443                          .fpsubtract2
   444  0269 a529               	lda fpmask
   445  026b 0528               	ora fpregspec
   446  026d 8f45fc1b           	sta IO_FP_SUBTRACT
   447  0271 4c1c04             	jmp moncmd
   448                          	
   449                          fploadconst
   450  0274 206001             	jsr fpgetmask
   451  0277 9003               	bcc .fploadconst1
   452  0279 4cb403             	jmp monerror
   453                          .fploadconst1
   454  027c 208501             	jsr fpgetregspec
   455  027f 9003               	bcc .fploadconst2
   456  0281 4cb403             	jmp monerror
   457                          .fploadconst2
   458  0284 203800             	jsr parse_addr			;get const specifier
   459  0287 c230               	rep #$30
   460  0289 98                 	tya
   461  028a e220               	sep #$20
   462  028c 291f               	and #$1f				;we're only interested in values 0-31
   463  028e 0529               	ora fpmask
   464  0290 0528               	ora fpregspec
   465  0292 8f40fc1b           	sta IO_FP_INIT_CONSTANT
   466  0296 4c1c04             	jmp moncmd
   467                          
   468                          fpdisp
   469  0299 206001             	jsr fpgetmask
   470  029c 9022               	bcc fpdisp2
   471  029e 4cb403             	jmp monerror
   472                          fpfacctxt
   473  02a1 464143433a20       	!tx "FACC: "
   474  02a7 00                 	!byte $00
   475                          fpfargtxt
   476  02a8 464152473a20       	!tx "FARG: "
   477  02ae 00                 	!byte $00
   478                          fpcondtxt
   479  02af 4650434f4e443a20   	!tx "FPCOND: "
   480  02b7 00                 	!byte $00
   481                          fpinttxt
   482  02b8 4650494e543a20     	!tx "FPINT: "
   483  02bf 00                 	!byte $00
   484                          fpdisp2
   485  02c0 a2a102             	ldx #fpfacctxt			;print FACC: tag
   486  02c3 863d               	stx dpla
   487  02c5 a91c               	lda #$1c
   488  02c7 853f               	sta dpla_h
   489  02c9 22d30e1c           	jsl l_prcdpla
   490  02cd a20900             	ldx #9
   491  02d0 a529               	lda fpmask
   492  02d2 2920               	and #$20
   493  02d4 d00c               	bne .facchex			;bit 5 set, so fall through and print 10 bytes
   494  02d6 a20700             	ldx #7
   495  02d9 a529               	lda fpmask
   496  02db 2980               	and #$80
   497  02dd d003               	bne .facchex			;bit 5 clear, but bit 7 set, print 8 bytes
   498  02df a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   499                          .facchex					;print X number of hex bytes in reverse order
   500  02e2 bfe0fc1b           	lda FPACCUMULATOR,x
   501  02e6 200a06             	jsr+2 prhex
   502  02e9 ca                 	dex
   503  02ea 10f6               	bpl .facchex
   504  02ec a529               	lda fpmask
   505  02ee 8f41fc1b           	sta IO_FP_TO_ASCII
   506  02f2 a92f               	lda #'/'
   507  02f4 8f12fc1b           	sta IO_CON_CHAROUT
   508  02f8 8f13fc1b           	sta IO_CON_REGISTER
   509  02fc a2c0fc             	ldx #FPASCII_LO16
   510  02ff 863d               	stx dpla
   511  0301 a91b               	lda #$1b
   512  0303 853f               	sta dpla_h
   513  0305 22d30e1c           	jsl l_prcdpla
   514  0309 8f17fc1b           	sta IO_CON_CR
   515                          	
   516  030d a2a802             	ldx #fpfargtxt			;print FARG: tag
   517  0310 863d               	stx dpla
   518  0312 a91c               	lda #$1c
   519  0314 853f               	sta dpla_h
   520  0316 22d30e1c           	jsl l_prcdpla
   521  031a a20900             	ldx #9
   522  031d a529               	lda fpmask
   523  031f 2920               	and #$20
   524  0321 d00c               	bne .farghex			;bit 5 set, so fall through and print 10 bytes
   525  0323 a20700             	ldx #7
   526  0326 a529               	lda fpmask
   527  0328 2980               	and #$80
   528  032a d003               	bne .farghex			;bit 5 clear, but bit 7 set, print 8 bytes
   529  032c a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   530                          .farghex					;print X number of hex bytes in reverse order
   531  032f bff0fc1b           	lda FPARGUMENT,x
   532  0333 200a06             	jsr+2 prhex
   533  0336 ca                 	dex
   534  0337 10f6               	bpl .farghex
   535  0339 a529               	lda fpmask
   536  033b 0940               	ora #$40				;select FARG this time
   537  033d 8f41fc1b           	sta IO_FP_TO_ASCII
   538  0341 a92f               	lda #'/'
   539  0343 8f12fc1b           	sta IO_CON_CHAROUT
   540  0347 8f13fc1b           	sta IO_CON_REGISTER
   541  034b a2c0fc             	ldx #FPASCII_LO16
   542  034e 863d               	stx dpla
   543  0350 a91b               	lda #$1b
   544  0352 853f               	sta dpla_h
   545  0354 22d30e1c           	jsl l_prcdpla
   546  0358 8f17fc1b           	sta IO_CON_CR
   547                          	
   548  035c a2af02             	ldx #fpcondtxt			;print FPCOND: tag
   549  035f 863d               	stx dpla
   550  0361 a91c               	lda #$1c
   551  0363 853f               	sta dpla_h
   552  0365 22d30e1c           	jsl l_prcdpla
   553  0369 a920               	lda #' '
   554  036b 8f12fc1b           	sta IO_CON_CHAROUT
   555  036f 8f13fc1b           	sta IO_CON_REGISTER
   556  0373 afbffc1b           	lda FPCOND
   557  0377 200a06             	jsr+2 prhex
   558  037a 8f17fc1b           	sta IO_CON_CR
   559                          	
   560  037e a2b802             	ldx #fpinttxt			;print FPINT tab
   561  0381 863d               	stx dpla
   562  0383 a91c               	lda #$1c
   563  0385 853f               	sta dpla_h
   564  0387 22d30e1c           	jsl l_prcdpla
   565  038b a920               	lda #' '
   566  038d 8f12fc1b           	sta IO_CON_CHAROUT
   567  0391 8f13fc1b           	sta IO_CON_REGISTER
   568  0395 a20700             	ldx #7
   569                          .fpdisp3
   570  0398 bfd8fc1b           	lda FPINT,x
   571  039c 200a06             	jsr+2 prhex
   572  039f ca                 	dex
   573  03a0 10f6               	bpl .fpdisp3
   574  03a2 8f17fc1b           	sta IO_CON_CR
   575                          	
   576  03a6 4c1c04             	jmp moncmd
   577                          	
   578                          bankcmd
   579  03a9 203800             	jsr parse_addr
   580  03ac 9006               	bcc monerror
   581  03ae 98                 	tya
   582  03af 853c               	sta mondump_h
   583  03b1 4c1c04             	jmp moncmd
   584                          monerror
   585  03b4 a2c403             	ldx #monsynerr
   586  03b7 863d               	stx dpla
   587  03b9 a91c               	lda #$1c
   588  03bb 853f               	sta dpla_h
   589  03bd 22d30e1c           	jsl l_prcdpla
   590  03c1 4c1c04             	jmp moncmd
   591                          monsynerr
   592  03c4 53796e7461782065...	!tx "Syntax error!"
   593  03d1 0d00               	!byte $0d, $00
   594                          
   595                          colorcmd
   596  03d3 203800             	jsr parse_addr
   597  03d6 90dc               	bcc monerror
   598  03d8 98                 	tya
   599  03d9 8f11fc1b           	sta IO_CON_COLOR
   600  03dd 4c1c04             	jmp moncmd
   601                          	
   602                          modecmd
   603  03e0 203800             	jsr parse_addr
   604  03e3 90cf               	bcc monerror
   605  03e5 98                 	tya
   606  03e6 c908               	cmp #$08
   607  03e8 90ca               	bcc monerror
   608  03ea c90a               	cmp #$0a
   609  03ec b0c6               	bcs monerror
   610  03ee 8f20fc1b           	sta IO_VIDMODE
   611  03f2 a900               	lda #$00
   612  03f4 8f14fc1b           	sta IO_CON_CURSORH
   613  03f8 8f15fc1b           	sta IO_CON_CURSORV
   614  03fc a920               	lda #$20
   615  03fe 8f12fc1b           	sta IO_CON_CHAROUT
   616  0402 8f10fc1b           	sta IO_CON_CLS
   617  0406 4c1c04             	jmp moncmd
   618                          	
   619                          monstart				;main entry point for system monitor
   620  0409 4b                 	phk
   621  040a ab                 	plb
   622  040b c210               	rep #$10
   623                          	!rl
   624  040d e220               	sep #$20
   625                          	!as
   626  040f a20000             	ldx #$0000
   627  0412 863a               	stx mondump
   628  0414 a91c               	lda #$1c
   629  0416 853c               	sta mondump_h
   630  0418 a944               	lda #'D'
   631  041a 8536               	sta monlast
   632                          	
   633                          	!zone moncmd
   634                          moncmd
   635  041c a92a               	lda #promptchar
   636  041e 8f12fc1b           	sta IO_CON_CHAROUT
   637  0422 8f13fc1b           	sta IO_CON_REGISTER
   638  0426 22510e1c           	jsl l_getline
   639  042a 222f0e1c           	jsl l_ucline
   640  042e 201f00             	jsr parse_setup
   641  0431 202900             	jsr parse_getchar
   642                          .local3
   643  0434 c951               	cmp #'Q'
   644  0436 f05b               	beq haltcmd
   645  0438 c944               	cmp #'D'
   646  043a d003               	bne .local4
   647  043c 4c4f05             	jmp+2 dumpcmd
   648                          .local4
   649  043f c90d               	cmp #$0d
   650  0441 d008               	bne .local2
   651  0443 a536               	lda monlast			;recall previously executed command
   652  0445 c920               	cmp #$20			;make sure it isn't a control character
   653  0447 b0eb               	bcs .local3			;and retry it
   654  0449 80d1               	bra moncmd			;else recycle and try a new command
   655                          .local2
   656  044b c941               	cmp #'A'
   657  044d f06a               	beq asciidumpcmd
   658  044f c942               	cmp #'B'
   659  0451 d003               	bne .local5
   660  0453 4ca903             	jmp+2 bankcmd
   661                          .local5
   662  0456 c943               	cmp #'C'
   663  0458 d003               	bne .local6
   664  045a 4cd303             	jmp+2 colorcmd
   665                          .local6
   666  045d c94d               	cmp #'M'
   667  045f d003               	bne .local7
   668  0461 4ce003             	jmp+2 modecmd
   669                          .local7
   670  0464 c945               	cmp #'E'
   671  0466 d003               	bne .local8
   672  0468 4c2a06             	jmp+2 entercmd
   673                          .local8
   674  046b c94c               	cmp #'L'
   675  046d d003               	bne .local9
   676  046f 4c5806             	jmp+2 listcmd
   677                          .local9
   678  0472 c93f               	cmp #'?'
   679  0474 f00d               	beq helpcmd
   680  0476 c946               	cmp #'F'
   681  0478 f003               	beq .localfp
   682  047a 4c1c04             	jmp moncmd
   683                          .localfp
   684  047d 201601             	jsr fpcmd
   685  0480 4c1c04             	jmp moncmd
   686                          	
   687                          helpcmd
   688  0483 a2870f             	ldx #helpmsg
   689  0486 863d               	stx dpla
   690  0488 a91c               	lda #$1c
   691  048a 853f               	sta dpla_h
   692  048c 22d30e1c           	jsl l_prcdpla
   693  0490 4c1c04             	jmp moncmd
   694                          	
   695                          haltcmd
   696  0493 a2a104             	ldx #haltmsg
   697  0496 863d               	stx dpla
   698  0498 a91c               	lda #$1c
   699  049a 853f               	sta dpla_h
   700  049c 22d30e1c           	jsl l_prcdpla
   701  04a0 db                 	stp
   702                          haltmsg
   703  04a1 48616c74696e6720...	!tx "Halting 65816 engine.."
   704  04b7 0d00               	!byte $0d,$00
   705                          	
   706                          	!zone asciidumpcmd
   707                          asciidumpcmd
   708  04b9 8536               	sta monlast
   709  04bb 203800             	jsr parse_addr
   710  04be 9021               	bcc .local3
   711  04c0 843a               	sty mondump
   712  04c2 8433               	sty rangehigh
   713  04c4 2435               	bit monrange			;user asking for a range?
   714  04c6 1019               	bpl .local3
   715  04c8 203800             	jsr parse_addr			;get the remaining half of the range
   716  04cb 8433               	sty rangehigh
   717  04cd a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   718  04cf 8535               	sta monrange
   719  04d1 a433               	ldy rangehigh
   720  04d3 d003               	bne .local6
   721  04d5 4cb403             	jmp+2 monerror			;top of range can't be zero
   722                          .local6
   723  04d8 a43a               	ldy mondump
   724  04da c433               	cpy rangehigh
   725  04dc 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   726  04de 4cb403             	jmp+2 monerror
   727                          .local3
   728  04e1 20c800             	jsr prdumpaddr
   729  04e4 a00000             	ldy #$0000
   730                          .local2
   731  04e7 b73a               	lda [mondump],y
   732  04e9 c920               	cmp #$20
   733  04eb b002               	bcs .local4
   734  04ed a92e               	lda #'.'				;substitute control character with a period
   735                          .local4
   736  04ef 8f12fc1b           	sta IO_CON_CHAROUT
   737  04f3 8f13fc1b           	sta IO_CON_REGISTER
   738  04f7 c8                 	iny
   739  04f8 af20fc1b           	lda IO_VIDMODE
   740  04fc c909               	cmp #$09
   741  04fe d007               	bne .lores1
   742  0500 c04000             	cpy #$0040
   743  0503 d0e2               	bne .local2
   744  0505 8005               	bra .lores2
   745                          .lores1
   746  0507 c01000             	cpy #$0010
   747  050a d0db               	bne .local2
   748                          .lores2
   749  050c 8f17fc1b           	sta IO_CON_CR
   750  0510 20f100             	jsr adjdumpaddr
   751  0513 b035               	bcs .local5				;carry to bank, exit even if we're processing a range
   752  0515 20f100             	jsr adjdumpaddr
   753  0518 b030               	bcs .local5	
   754  051a af20fc1b           	lda IO_VIDMODE
   755  051e c909               	cmp #$09
   756  0520 d01e               	bne .lores3
   757  0522 20f100             	jsr adjdumpaddr
   758  0525 b023               	bcs .local5	
   759  0527 20f100             	jsr adjdumpaddr
   760  052a b01e               	bcs .local5	
   761  052c 20f100             	jsr adjdumpaddr
   762  052f b019               	bcs .local5	
   763  0531 20f100             	jsr adjdumpaddr
   764  0534 b014               	bcs .local5	
   765  0536 20f100             	jsr adjdumpaddr
   766  0539 b00f               	bcs .local5	
   767  053b 20f100             	jsr adjdumpaddr
   768  053e b00a               	bcs .local5	
   769                          .lores3
   770  0540 2435               	bit monrange			;ranges on?
   771  0542 1006               	bpl .local5
   772  0544 a433               	ldy rangehigh
   773  0546 c43a               	cpy mondump
   774  0548 b097               	bcs .local3
   775                          .local5
   776  054a 6435               	stz monrange
   777  054c 4c1c04             	jmp moncmd
   778                          	
   779                          	!zone dumpcmd
   780                          dumpcmd
   781  054f 8536               	sta monlast
   782  0551 203800             	jsr parse_addr
   783  0554 9021               	bcc .local3
   784  0556 843a               	sty mondump				;if address was specified, store 16 bit y at low 16 bits of mondump address
   785  0558 8433               	sty rangehigh
   786  055a 2435               	bit monrange			;user asking for a range?
   787  055c 1019               	bpl .local3
   788  055e 203800             	jsr parse_addr			;get the remaining half of the range
   789  0561 8433               	sty rangehigh
   790  0563 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   791  0565 8535               	sta monrange
   792  0567 a433               	ldy rangehigh
   793  0569 d003               	bne .local6
   794  056b 4cb403             	jmp+2 monerror			;top of range can't be zero
   795                          .local6
   796  056e a43a               	ldy mondump
   797  0570 c433               	cpy rangehigh
   798  0572 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   799  0574 4cb403             	jmp+2 monerror
   800                          .local3
   801  0577 20c800             	jsr prdumpaddr
   802  057a a00000             	ldy #$0000
   803                          .local2
   804  057d b73a               	lda [mondump],y
   805  057f 200a06             	jsr+2 prhex
   806  0582 a920               	lda #' '
   807  0584 8f12fc1b           	sta IO_CON_CHAROUT
   808  0588 8f13fc1b           	sta IO_CON_REGISTER
   809  058c c8                 	iny
   810  058d af20fc1b           	lda IO_VIDMODE
   811  0591 c909               	cmp #$09
   812  0593 d03e               	bne .lores1
   813  0595 c01000             	cpy #$0010
   814  0598 d0e3               	bne .local2
   815  059a a920               	lda #' '
   816  059c 8f12fc1b           	sta IO_CON_CHAROUT
   817  05a0 8f13fc1b           	sta IO_CON_REGISTER
   818  05a4 a92d               	lda #'-'
   819  05a6 8f12fc1b           	sta IO_CON_CHAROUT
   820  05aa 8f13fc1b           	sta IO_CON_REGISTER
   821  05ae a920               	lda #' '
   822  05b0 8f12fc1b           	sta IO_CON_CHAROUT
   823  05b4 8f13fc1b           	sta IO_CON_REGISTER
   824  05b8 a00000             	ldy #$0000				;print 16 bytes as ASCII... bonus when in mode 9!
   825                          .asc2
   826  05bb b73a               	lda [mondump],y
   827  05bd c920               	cmp #$20
   828  05bf b002               	bcs .asc4
   829  05c1 a92e               	lda #'.'				;substitute control character with a period
   830                          .asc4
   831  05c3 8f12fc1b           	sta IO_CON_CHAROUT
   832  05c7 8f13fc1b           	sta IO_CON_REGISTER
   833  05cb c8                 	iny
   834  05cc c01000             	cpy #$0010
   835  05cf d0ea               	bne .asc2
   836  05d1 8005               	bra .lores2
   837                          .lores1
   838  05d3 c00800             	cpy #$0008
   839  05d6 d0a5               	bne .local2
   840                          .lores2
   841  05d8 8f17fc1b           	sta IO_CON_CR
   842  05dc 20f100             	jsr adjdumpaddr
   843  05df b01a               	bcs .local5				;carry to bank, exit even if we're processing a range
   844  05e1 af20fc1b           	lda IO_VIDMODE
   845  05e5 c909               	cmp #$09
   846  05e7 d005               	bne .lores3
   847  05e9 20f100             	jsr adjdumpaddr
   848  05ec b00d               	bcs .local5
   849                          .lores3
   850  05ee 2435               	bit monrange			;ranges on?
   851  05f0 1009               	bpl .local5
   852  05f2 a433               	ldy rangehigh
   853  05f4 c43a               	cpy mondump
   854  05f6 9003               	bcc .local5
   855  05f8 4c7705             	jmp+2 .local3
   856                          .local5
   857  05fb 6435               	stz monrange
   858  05fd 4c1c04             	jmp moncmd
   859                          	
   860                          prhex16
   861  0600 c230               	rep #$30
   862  0602 8a                 	txa
   863  0603 e220               	sep #$20
   864  0605 eb                 	xba
   865  0606 200a06             	jsr+2 prhex
   866  0609 eb                 	xba
   867                          prhex
   868  060a 48                 	pha
   869  060b 4a                 	lsr
   870  060c 4a                 	lsr
   871  060d 4a                 	lsr
   872  060e 4a                 	lsr
   873  060f 201506             	jsr+2 prhexnib
   874  0612 68                 	pla
   875  0613 290f               	and #$0f
   876                          prhexnib
   877  0615 0930               	ora #$30
   878  0617 c93a               	cmp #$3a
   879  0619 9003               	bcc prhexnofix
   880  061b 18                 	clc
   881  061c 6907               	adc #$07
   882                          prhexnofix
   883  061e 8f12fc1b           	sta IO_CON_CHAROUT
   884  0622 8f13fc1b           	sta IO_CON_REGISTER
   885  0626 60                 	rts
   886                          
   887                          	!zone entercmd
   888                          .local1
   889  0627 4cb403             	jmp monerror
   890                          entercmd
   891  062a 203800             	jsr parse_addr
   892  062d 90f8               	bcc .local1			;address is mandatory
   893  062f 2435               	bit monrange
   894  0631 30f4               	bmi .local1			;ranges not allowed
   895  0633 8430               	sty enterbytes
   896  0635 a53c               	lda mondump_h
   897  0637 8532               	sta enterbytes_h	;retrieve bank from mondump
   898                          .local2
   899  0639 203800             	jsr parse_addr		;start grabbing bytes
   900  063c 9017               	bcc .enterdone
   901  063e 2435               	bit monrange
   902  0640 30e5               	bmi .local1			;stop that happening here too
   903  0642 c230               	rep #$30
   904  0644 98                 	tya
   905  0645 e220               	sep #$20			;get low byte of parsed address into A
   906  0647 8730               	sta [enterbytes]
   907  0649 e630               	inc enterbytes
   908  064b d006               	bne .local3
   909  064d e631               	inc enterbytes_m
   910  064f d002               	bne .local3
   911  0651 e632               	inc enterbytes_h
   912                          .local3
   913  0653 80e4               	bra .local2
   914                          .enterdone
   915  0655 4c1c04             	jmp moncmd
   916                          	
   917                          	!zone listcmd
   918                          listcmd
   919  0658 203800             	jsr parse_addr
   920  065b 9002               	bcc .listmany				;address is optional
   921  065d 843a               	sty mondump
   922                          .listmany
   923  065f af20fc1b           	lda IO_VIDMODE
   924  0663 c909               	cmp #$09
   925  0665 d005               	bne .listmany1
   926  0667 a22000             	ldx #32
   927  066a 8003               	bra .listmany2
   928                          .listmany1
   929  066c a20f00             	ldx #15
   930                          .listmany2
   931  066f da                 	phx
   932  0670 207a06             	jsr+2 .listsingle
   933  0673 fa                 	plx
   934  0674 ca                 	dex
   935  0675 d0f8               	bne .listmany2
   936  0677 4c1c04             	jmp moncmd
   937                          .listsingle
   938  067a a00000             	ldy #$0000
   939  067d 20c800             	jsr prdumpaddr
   940  0680 a900               	lda #$00
   941  0682 eb                 	xba					;clear B
   942  0683 a73a               	lda [mondump]				;get opcode
   943  0685 48                 	pha					;save opcode
   944  0686 aa                 	tax
   945  0687 bd1b0b             	lda mnemlenmode,x
   946  068a 4a                 	lsr
   947  068b 4a                 	lsr
   948  068c 4a                 	lsr
   949  068d 4a                 	lsr
   950  068e 4a                 	lsr					;isolage opcode len
   951  068f 852f               	sta scratch1
   952  0691 a73a               	lda [mondump]
   953  0693 20c00a             	jsr+2 is816
   954  0696 a52f               	lda scratch1
   955  0698 aa                 	tax
   956  0699 a00000             	ldy #$0000
   957                          .nextbyte
   958  069c b73a               	lda [mondump],y
   959  069e 200a06             	jsr prhex			;print hex
   960  06a1 a920               	lda #' '
   961  06a3 8f12fc1b           	sta IO_CON_CHAROUT
   962  06a7 8f13fc1b           	sta IO_CON_REGISTER	;print space
   963  06ab c8                 	iny
   964  06ac ca                 	dex
   965  06ad d0ed               	bne .nextbyte
   966  06af a916               	lda #$16
   967  06b1 8f14fc1b           	sta IO_CON_CURSORH	;tab over
   968  06b5 68                 	pla					;get opcode back
   969  06b6 aa                 	tax
   970  06b7 bd1b0c             	lda mnemlist,x
   971  06ba 8530               	sta enterbytes
   972  06bc 6431               	stz enterbytes_m	;save for 16 bit add
   973  06be da                 	phx					;stash our opcode
   974  06bf c230               	rep #$30
   975                          	!al
   976  06c1 29ff00             	and #$00ff			;switch to 16 bits, clear top
   977  06c4 0a                 	asl
   978  06c5 18                 	clc
   979  06c6 6530               	adc enterbytes		;multiply by 3
   980  06c8 aa                 	tax
   981  06c9 e220               	sep #$20
   982                          	!as
   983  06cb bd1b0d             	lda mnems, x
   984  06ce 8f12fc1b           	sta IO_CON_CHAROUT
   985  06d2 8f13fc1b           	sta IO_CON_REGISTER
   986  06d6 e8                 	inx
   987  06d7 bd1b0d             	lda mnems, x
   988  06da 8f12fc1b           	sta IO_CON_CHAROUT
   989  06de 8f13fc1b           	sta IO_CON_REGISTER
   990  06e2 e8                 	inx
   991  06e3 bd1b0d             	lda mnems, x
   992  06e6 8f12fc1b           	sta IO_CON_CHAROUT
   993  06ea 8f13fc1b           	sta IO_CON_REGISTER
   994  06ee a920               	lda #' '
   995  06f0 8f12fc1b           	sta IO_CON_CHAROUT
   996  06f4 8f13fc1b           	sta IO_CON_REGISTER
   997  06f8 fa                 	plx					;get our opcode back in index
   998  06f9 a900               	lda #$00
   999  06fb eb                 	xba					;clear top byte of A if it's dirty
  1000  06fc bd1b0b             	lda mnemlenmode,x
  1001  06ff 291f               	and #$1f			;isolate the addressing mode
  1002  0701 0a                 	asl					;multiply by two
  1003  0702 aa                 	tax
  1004  0703 fcf10a             	jsr (listamod,x)
  1005  0706 af20fc1b           	lda IO_VIDMODE
  1006  070a c909               	cmp #$09
  1007  070c d01f               	bne .fixup1
  1008  070e a925               	lda #$25
  1009  0710 8f14fc1b           	sta IO_CON_CURSORH		;tab over and print our bytes as ASCII in 80 column mode
  1010  0714 e230               	sep #$30				;8 bit indexes here
  1011                          	!rs
  1012  0716 a000               	ldy #$00				;print disassembly bytes as ASCII... bonus when in mode 9!
  1013                          .asc2
  1014  0718 b73a               	lda [mondump],y
  1015  071a c920               	cmp #$20
  1016  071c b002               	bcs .asc4
  1017  071e a92e               	lda #'.'				;substitute control character with a period
  1018                          .asc4
  1019  0720 8f12fc1b           	sta IO_CON_CHAROUT
  1020  0724 8f13fc1b           	sta IO_CON_REGISTER
  1021  0728 c8                 	iny
  1022  0729 c42f               	cpy scratch1
  1023  072b d0eb               	bne .asc2
  1024                          .fixup1
  1025  072d c210               	rep #$10
  1026                          	!rl
  1027  072f 8f17fc1b           	sta IO_CON_CR
  1028                          .fixup
  1029  0733 a52f               	lda scratch1		;get our fixup
  1030  0735 18                 	clc
  1031  0736 653a               	adc mondump
  1032  0738 853a               	sta mondump
  1033  073a a53b               	lda mondump_m
  1034  073c 6900               	adc #$00
  1035  073e 853b               	sta mondump_m
  1036  0740 a53c               	lda mondump_h
  1037  0742 6900               	adc #$00
  1038  0744 853c               	sta mondump_h
  1039                          .goback
  1040  0746 60                 	rts
  1041                          
  1042                          amod0
  1043  0747 a924               	lda #'$'
  1044  0749 8f12fc1b           	sta IO_CON_CHAROUT
  1045  074d 8f13fc1b           	sta IO_CON_REGISTER
  1046  0751 a00100             	ldy #$0001
  1047  0754 b73a               	lda [mondump],y
  1048  0756 200a06             	jsr prhex
  1049  0759 60                 	rts
  1050                          amod1
  1051  075a a928               	lda #'('
  1052  075c 8f12fc1b           	sta IO_CON_CHAROUT
  1053  0760 8f13fc1b           	sta IO_CON_REGISTER
  1054  0764 a924               	lda #'$'
  1055  0766 8f12fc1b           	sta IO_CON_CHAROUT
  1056  076a 8f13fc1b           	sta IO_CON_REGISTER
  1057  076e a00100             	ldy #$0001
  1058  0771 b73a               	lda [mondump],y
  1059  0773 200a06             	jsr prhex
  1060  0776 a92c               	lda #','
  1061  0778 8f12fc1b           	sta IO_CON_CHAROUT
  1062  077c 8f13fc1b           	sta IO_CON_REGISTER
  1063  0780 a958               	lda #'X'
  1064  0782 8f12fc1b           	sta IO_CON_CHAROUT
  1065  0786 8f13fc1b           	sta IO_CON_REGISTER
  1066  078a a929               	lda #')'
  1067  078c 8f12fc1b           	sta IO_CON_CHAROUT
  1068  0790 8f13fc1b           	sta IO_CON_REGISTER
  1069  0794 60                 	rts
  1070                          amod2
  1071  0795 a00100             	ldy #$0001
  1072  0798 b73a               	lda [mondump],y
  1073  079a 200a06             	jsr prhex
  1074  079d a92c               	lda #','
  1075  079f 8f12fc1b           	sta IO_CON_CHAROUT
  1076  07a3 8f13fc1b           	sta IO_CON_REGISTER
  1077  07a7 a953               	lda #'S'
  1078  07a9 8f12fc1b           	sta IO_CON_CHAROUT
  1079  07ad 8f13fc1b           	sta IO_CON_REGISTER
  1080  07b1 60                 	rts
  1081                          amod3
  1082  07b2 a95b               	lda #'['
  1083  07b4 8f12fc1b           	sta IO_CON_CHAROUT
  1084  07b8 8f13fc1b           	sta IO_CON_REGISTER
  1085  07bc a924               	lda #'$'
  1086  07be 8f12fc1b           	sta IO_CON_CHAROUT
  1087  07c2 8f13fc1b           	sta IO_CON_REGISTER
  1088  07c6 a00100             	ldy #$0001
  1089  07c9 b73a               	lda [mondump],y
  1090  07cb 200a06             	jsr prhex
  1091  07ce a95d               	lda #']'
  1092  07d0 8f12fc1b           	sta IO_CON_CHAROUT
  1093  07d4 8f13fc1b           	sta IO_CON_REGISTER
  1094                          amod4
  1095  07d8 60                 	rts
  1096                          	!zone amod5
  1097                          amod5
  1098  07d9 a923               	lda #'#'
  1099  07db 8f12fc1b           	sta IO_CON_CHAROUT
  1100  07df 8f13fc1b           	sta IO_CON_REGISTER
  1101  07e3 a924               	lda #'$'
  1102  07e5 8f12fc1b           	sta IO_CON_CHAROUT
  1103  07e9 8f13fc1b           	sta IO_CON_REGISTER
  1104  07ed a52f               	lda scratch1
  1105  07ef c902               	cmp #$02
  1106  07f1 f008               	beq .amod508
  1107                          .amod516
  1108  07f3 a00200             	ldy #$0002
  1109  07f6 b73a               	lda [mondump],y
  1110  07f8 200a06             	jsr prhex
  1111                          .amod508
  1112  07fb a00100             	ldy #$0001
  1113  07fe b73a               	lda [mondump],y
  1114  0800 200a06             	jsr prhex
  1115  0803 60                 	rts
  1116                          amod6
  1117  0804 a924               	lda #'$'
  1118  0806 8f12fc1b           	sta IO_CON_CHAROUT
  1119  080a 8f13fc1b           	sta IO_CON_REGISTER
  1120  080e a00200             	ldy #$0002
  1121  0811 b73a               	lda [mondump],y
  1122  0813 200a06             	jsr prhex
  1123  0816 88                 	dey
  1124  0817 b73a               	lda [mondump],y
  1125  0819 4c0a06             	jmp prhex
  1126                          amod7
  1127  081c a924               	lda #'$'
  1128  081e 8f12fc1b           	sta IO_CON_CHAROUT
  1129  0822 8f13fc1b           	sta IO_CON_REGISTER
  1130  0826 a00300             	ldy #$0003
  1131  0829 b73a               	lda [mondump],y
  1132  082b 200a06             	jsr prhex
  1133  082e 88                 	dey
  1134  082f b73a               	lda [mondump],y
  1135  0831 200a06             	jsr prhex
  1136  0834 88                 	dey
  1137  0835 b73a               	lda [mondump],y
  1138  0837 4c0a06             	jmp prhex
  1139                          amod11
  1140  083a a00300             	ldy #$0003
  1141  083d 842a               	sty scratch2			;number of bytes to bump offset
  1142  083f a00200             	ldy #$0002
  1143  0842 b73a               	lda [mondump],y
  1144  0844 eb                 	xba
  1145  0845 88                 	dey
  1146  0846 b73a               	lda [mondump],y
  1147  0848 8014               	bra amod8nosign
  1148                          amod8
  1149  084a a00200             	ldy #$0002
  1150  084d 842a               	sty scratch2
  1151  084f a900               	lda #$00
  1152  0851 eb                 	xba						;clear high byte of A
  1153                          amod8a
  1154  0852 a00100             	ldy #$0001
  1155  0855 b73a               	lda [mondump],y			;get rel byte
  1156  0857 1005               	bpl amod8nosign
  1157  0859 48                 	pha
  1158  085a a9ff               	lda #$ff
  1159  085c eb                 	xba						;sign extend if negative
  1160  085d 68                 	pla
  1161                          amod8nosign
  1162  085e c230               	rep #$30
  1163                          	!al
  1164  0860 18                 	clc
  1165  0861 653a               	adc mondump				;add to our current disassembly address
  1166  0863 18                 	clc
  1167  0864 652a               	adc scratch2			;add offset for instruction size
  1168  0866 aa                 	tax
  1169  0867 e220               	sep #$20
  1170                          	!as
  1171  0869 a924               	lda #'$'
  1172  086b 8f12fc1b           	sta IO_CON_CHAROUT
  1173  086f 8f13fc1b           	sta IO_CON_REGISTER
  1174  0873 200006             	jsr prhex16
  1175  0876 60                 	rts
  1176                          amod9
  1177  0877 a928               	lda #'('
  1178  0879 8f12fc1b           	sta IO_CON_CHAROUT
  1179  087d 8f13fc1b           	sta IO_CON_REGISTER
  1180  0881 a924               	lda #'$'
  1181  0883 8f12fc1b           	sta IO_CON_CHAROUT
  1182  0887 8f13fc1b           	sta IO_CON_REGISTER
  1183  088b a00100             	ldy #$0001
  1184  088e b73a               	lda [mondump],y
  1185  0890 200a06             	jsr prhex
  1186  0893 a929               	lda #')'
  1187  0895 8f12fc1b           	sta IO_CON_CHAROUT
  1188  0899 8f13fc1b           	sta IO_CON_REGISTER
  1189  089d a92c               	lda #','
  1190  089f 8f12fc1b           	sta IO_CON_CHAROUT
  1191  08a3 8f13fc1b           	sta IO_CON_REGISTER
  1192  08a7 a959               	lda #'Y'
  1193  08a9 8f12fc1b           	sta IO_CON_CHAROUT
  1194  08ad 8f13fc1b           	sta IO_CON_REGISTER
  1195  08b1 60                 	rts
  1196                          amoda
  1197  08b2 a928               	lda #'('
  1198  08b4 8f12fc1b           	sta IO_CON_CHAROUT
  1199  08b8 8f13fc1b           	sta IO_CON_REGISTER
  1200  08bc a924               	lda #'$'
  1201  08be 8f12fc1b           	sta IO_CON_CHAROUT
  1202  08c2 8f13fc1b           	sta IO_CON_REGISTER
  1203  08c6 a00100             	ldy #$0001
  1204  08c9 b73a               	lda [mondump],y
  1205  08cb 200a06             	jsr prhex
  1206  08ce a929               	lda #')'
  1207  08d0 8f12fc1b           	sta IO_CON_CHAROUT
  1208  08d4 8f13fc1b           	sta IO_CON_REGISTER
  1209  08d8 60                 	rts
  1210                          amodb
  1211  08d9 a928               	lda #'('
  1212  08db 8f12fc1b           	sta IO_CON_CHAROUT
  1213  08df 8f13fc1b           	sta IO_CON_REGISTER
  1214  08e3 a924               	lda #'$'
  1215  08e5 8f12fc1b           	sta IO_CON_CHAROUT
  1216  08e9 8f13fc1b           	sta IO_CON_REGISTER
  1217  08ed a00100             	ldy #$0001
  1218  08f0 b73a               	lda [mondump],y
  1219  08f2 200a06             	jsr prhex
  1220  08f5 a92c               	lda #','
  1221  08f7 8f12fc1b           	sta IO_CON_CHAROUT
  1222  08fb 8f13fc1b           	sta IO_CON_REGISTER
  1223  08ff a953               	lda #'S'
  1224  0901 8f12fc1b           	sta IO_CON_CHAROUT
  1225  0905 8f13fc1b           	sta IO_CON_REGISTER
  1226  0909 a929               	lda #')'
  1227  090b 8f12fc1b           	sta IO_CON_CHAROUT
  1228  090f 8f13fc1b           	sta IO_CON_REGISTER
  1229  0913 a92c               	lda #','
  1230  0915 8f12fc1b           	sta IO_CON_CHAROUT
  1231  0919 8f13fc1b           	sta IO_CON_REGISTER
  1232  091d a959               	lda #'Y'
  1233  091f 8f12fc1b           	sta IO_CON_CHAROUT
  1234  0923 8f13fc1b           	sta IO_CON_REGISTER
  1235  0927 60                 	rts
  1236                          amodc
  1237  0928 a924               	lda #'$'
  1238  092a 8f12fc1b           	sta IO_CON_CHAROUT
  1239  092e 8f13fc1b           	sta IO_CON_REGISTER
  1240  0932 a00100             	ldy #$0001
  1241  0935 b73a               	lda [mondump],y
  1242  0937 200a06             	jsr prhex
  1243  093a a92c               	lda #','
  1244  093c 8f12fc1b           	sta IO_CON_CHAROUT
  1245  0940 8f13fc1b           	sta IO_CON_REGISTER
  1246  0944 a958               	lda #'X'
  1247  0946 8f12fc1b           	sta IO_CON_CHAROUT
  1248  094a 8f13fc1b           	sta IO_CON_REGISTER
  1249  094e 60                 	rts
  1250                          amodd
  1251  094f a95b               	lda #'['
  1252  0951 8f12fc1b           	sta IO_CON_CHAROUT
  1253  0955 8f13fc1b           	sta IO_CON_REGISTER
  1254  0959 a924               	lda #'$'
  1255  095b 8f12fc1b           	sta IO_CON_CHAROUT
  1256  095f 8f13fc1b           	sta IO_CON_REGISTER
  1257  0963 a00100             	ldy #$0001
  1258  0966 b73a               	lda [mondump],y
  1259  0968 200a06             	jsr prhex
  1260  096b a95d               	lda #']'
  1261  096d 8f12fc1b           	sta IO_CON_CHAROUT
  1262  0971 8f13fc1b           	sta IO_CON_REGISTER
  1263  0975 a92c               	lda #','
  1264  0977 8f12fc1b           	sta IO_CON_CHAROUT
  1265  097b 8f13fc1b           	sta IO_CON_REGISTER
  1266  097f a959               	lda #'Y'
  1267  0981 8f12fc1b           	sta IO_CON_CHAROUT
  1268  0985 8f13fc1b           	sta IO_CON_REGISTER
  1269  0989 60                 	rts
  1270                          amode
  1271  098a a924               	lda #'$'
  1272  098c 8f12fc1b           	sta IO_CON_CHAROUT
  1273  0990 8f13fc1b           	sta IO_CON_REGISTER
  1274  0994 a00200             	ldy #$0002
  1275  0997 b73a               	lda [mondump],y
  1276  0999 200a06             	jsr prhex
  1277  099c 88                 	dey
  1278  099d b73a               	lda [mondump],y
  1279  099f 200a06             	jsr prhex
  1280  09a2 a92c               	lda #','
  1281  09a4 8f12fc1b           	sta IO_CON_CHAROUT
  1282  09a8 8f13fc1b           	sta IO_CON_REGISTER
  1283  09ac a958               	lda #'X'
  1284  09ae 8f12fc1b           	sta IO_CON_CHAROUT
  1285  09b2 8f13fc1b           	sta IO_CON_REGISTER
  1286  09b6 60                 	rts
  1287                          amodf
  1288  09b7 a924               	lda #'$'
  1289  09b9 8f12fc1b           	sta IO_CON_CHAROUT
  1290  09bd 8f13fc1b           	sta IO_CON_REGISTER
  1291  09c1 a00200             	ldy #$0002
  1292  09c4 b73a               	lda [mondump],y
  1293  09c6 200a06             	jsr prhex
  1294  09c9 88                 	dey
  1295  09ca b73a               	lda [mondump],y
  1296  09cc 200a06             	jsr prhex
  1297  09cf a92c               	lda #','
  1298  09d1 8f12fc1b           	sta IO_CON_CHAROUT
  1299  09d5 8f13fc1b           	sta IO_CON_REGISTER
  1300  09d9 a959               	lda #'Y'
  1301  09db 8f12fc1b           	sta IO_CON_CHAROUT
  1302  09df 8f13fc1b           	sta IO_CON_REGISTER
  1303  09e3 60                 	rts
  1304                          amod10
  1305  09e4 a924               	lda #'$'
  1306  09e6 8f12fc1b           	sta IO_CON_CHAROUT
  1307  09ea 8f13fc1b           	sta IO_CON_REGISTER
  1308  09ee a00300             	ldy #$0003
  1309  09f1 b73a               	lda [mondump],y
  1310  09f3 200a06             	jsr prhex
  1311  09f6 88                 	dey
  1312  09f7 b73a               	lda [mondump],y
  1313  09f9 200a06             	jsr prhex
  1314  09fc 88                 	dey
  1315  09fd b73a               	lda [mondump],y
  1316  09ff 200a06             	jsr prhex
  1317  0a02 a92c               	lda #','
  1318  0a04 8f12fc1b           	sta IO_CON_CHAROUT
  1319  0a08 8f13fc1b           	sta IO_CON_REGISTER
  1320  0a0c a958               	lda #'X'
  1321  0a0e 8f12fc1b           	sta IO_CON_CHAROUT
  1322  0a12 8f13fc1b           	sta IO_CON_REGISTER
  1323  0a16 60                 	rts
  1324                          amod12
  1325  0a17 a928               	lda #'('
  1326  0a19 8f12fc1b           	sta IO_CON_CHAROUT
  1327  0a1d 8f13fc1b           	sta IO_CON_REGISTER
  1328  0a21 a924               	lda #'$'
  1329  0a23 8f12fc1b           	sta IO_CON_CHAROUT
  1330  0a27 8f13fc1b           	sta IO_CON_REGISTER
  1331  0a2b a00200             	ldy #$0002
  1332  0a2e b73a               	lda [mondump],y
  1333  0a30 200a06             	jsr prhex
  1334  0a33 88                 	dey
  1335  0a34 b73a               	lda [mondump],y
  1336  0a36 200a06             	jsr prhex
  1337  0a39 a929               	lda #')'
  1338  0a3b 8f12fc1b           	sta IO_CON_CHAROUT
  1339  0a3f 8f13fc1b           	sta IO_CON_REGISTER
  1340  0a43 60                 	rts
  1341                          amod13
  1342  0a44 a928               	lda #'('
  1343  0a46 8f12fc1b           	sta IO_CON_CHAROUT
  1344  0a4a 8f13fc1b           	sta IO_CON_REGISTER
  1345  0a4e a924               	lda #'$'
  1346  0a50 8f12fc1b           	sta IO_CON_CHAROUT
  1347  0a54 8f13fc1b           	sta IO_CON_REGISTER
  1348  0a58 a00200             	ldy #$0002
  1349  0a5b b73a               	lda [mondump],y
  1350  0a5d 200a06             	jsr prhex
  1351  0a60 88                 	dey
  1352  0a61 b73a               	lda [mondump],y
  1353  0a63 200a06             	jsr prhex
  1354  0a66 a92c               	lda #','
  1355  0a68 8f12fc1b           	sta IO_CON_CHAROUT
  1356  0a6c 8f13fc1b           	sta IO_CON_REGISTER
  1357  0a70 a958               	lda #'X'
  1358  0a72 8f12fc1b           	sta IO_CON_CHAROUT
  1359  0a76 8f13fc1b           	sta IO_CON_REGISTER
  1360  0a7a a929               	lda #')'
  1361  0a7c 8f12fc1b           	sta IO_CON_CHAROUT
  1362  0a80 8f13fc1b           	sta IO_CON_REGISTER
  1363  0a84 60                 	rts
  1364                          amod14
  1365  0a85 a924               	lda #'$'
  1366  0a87 8f12fc1b           	sta IO_CON_CHAROUT
  1367  0a8b 8f13fc1b           	sta IO_CON_REGISTER
  1368  0a8f a00100             	ldy #$0001
  1369  0a92 b73a               	lda [mondump],y
  1370  0a94 200a06             	jsr prhex
  1371  0a97 a92c               	lda #','
  1372  0a99 8f12fc1b           	sta IO_CON_CHAROUT
  1373  0a9d 8f13fc1b           	sta IO_CON_REGISTER
  1374  0aa1 a959               	lda #'Y'
  1375  0aa3 8f12fc1b           	sta IO_CON_CHAROUT
  1376  0aa7 8f13fc1b           	sta IO_CON_REGISTER
  1377  0aab 60                 	rts
  1378                          	
  1379                          						;test branches for disassembly purposes..
  1380  0aac 70d7               	bvs amod14
  1381  0aae 7010               	bvs is816
  1382  0ab0 7092               	bvs amod13
  1383  0ab2 703d               	bvs listamod
  1384  0ab4 6260ff             	per amod12
  1385  0ab7 620600             	per is816
  1386  0aba 6227ff             	per amod10
  1387  0abd 623100             	per listamod
  1388                          	
  1389                          	!zone is816
  1390                          is816
  1391  0ac0 48                 	pha
  1392  0ac1 291f               	and #$1f
  1393  0ac3 c909               	cmp #$09				;09, 29, 49, etc?
  1394  0ac5 d006               	bne .testx
  1395  0ac7 242d               	bit alarge				;16 bit?
  1396  0ac9 3020               	bmi .is16
  1397  0acb 1018               	bpl .is8
  1398                          .testx
  1399  0acd 68                 	pla
  1400  0ace 48                 	pha
  1401  0acf c9a0               	cmp #$a0
  1402  0ad1 f00e               	beq .isx
  1403  0ad3 c9a2               	cmp #$a2
  1404  0ad5 f00a               	beq .isx
  1405  0ad7 c9c0               	cmp #$c0
  1406  0ad9 f006               	beq .isx
  1407  0adb c9e0               	cmp #$e0
  1408  0add f002               	beq .isx
  1409  0adf 68                 	pla						;made it here, not an accumulator or index instruction
  1410  0ae0 60                 	rts
  1411                          .isx
  1412  0ae1 242e               	bit xlarge
  1413  0ae3 3006               	bmi .is16				;or else fall thru
  1414                          .is8
  1415  0ae5 a902               	lda #$2
  1416  0ae7 852f               	sta scratch1
  1417  0ae9 68                 	pla
  1418  0aea 60                 	rts
  1419                          .is16
  1420  0aeb a903               	lda #$3
  1421  0aed 852f               	sta scratch1
  1422  0aef 68                 	pla
  1423  0af0 60                 	rts
  1424                          	
  1425                          listamod
  1426  0af1 4707               	!16 amod0			;$xx
  1427  0af3 5a07               	!16 amod1			;($xx,X)
  1428  0af5 9507               	!16 amod2			;x,S
  1429  0af7 b207               	!16 amod3			;[$xx]
  1430  0af9 d807               	!16 amod4			;implied
  1431  0afb d907               	!16 amod5			;#$xx (or #$yyxx)
  1432  0afd 0408               	!16 amod6			;$yyxx
  1433  0aff 1c08               	!16 amod7			;$zzyyxx
  1434  0b01 4a08               	!16 amod8			;rel8
  1435  0b03 7708               	!16 amod9			;($xx),Y
  1436  0b05 b208               	!16 amoda			;($xx)
  1437  0b07 d908               	!16 amodb			;(xx,S),Y
  1438  0b09 2809               	!16 amodc			;$xx,X
  1439  0b0b 4f09               	!16 amodd			;[$xx],Y
  1440  0b0d 8a09               	!16 amode			;$yyxx,X
  1441  0b0f b709               	!16 amodf			;$yyxx,Y
  1442  0b11 e409               	!16 amod10			;$zzyyxx,X
  1443  0b13 3a08               	!16 amod11			;rel16
  1444  0b15 170a               	!16 amod12			;($yyxx)
  1445  0b17 440a               	!16 amod13			;($yyxx,X)
  1446  0b19 850a               	!16 amod14			;$xx,Y
  1447                          	
  1448                          mnemlenmode
  1449  0b1b 40                 	!byte %01000000		;00 brk 2/$xx
  1450  0b1c 41                 	!byte %01000001		;01 ora 2/($xx,x)
  1451  0b1d 40                 	!byte %01000000		;02 cop 2/$xx
  1452  0b1e 42                 	!byte %01000010		;03 ora 2/x,s
  1453  0b1f 40                 	!byte %01000000		;04 tsb 2/$xx
  1454  0b20 40                 	!byte %01000000		;05 ora 2/$xx
  1455  0b21 40                 	!byte %01000000		;06 asl 2/$xx
  1456  0b22 43                 	!byte %01000011		;07 ora 2/[$xx]
  1457  0b23 24                 	!byte %00100100		;08 php 1
  1458  0b24 45                 	!byte %01000101		;09 ora 2/#imm
  1459  0b25 24                 	!byte %00100100		;0a asl 1
  1460  0b26 24                 	!byte %00100100		;0b phd 1
  1461  0b27 66                 	!byte %01100110		;0c tsb 3/$yyxx
  1462  0b28 66                 	!byte %01100110		;0d ora 3/$yyxx
  1463  0b29 66                 	!byte %01100110		;0e asl 3/$yyxx
  1464  0b2a 87                 	!byte %10000111		;0f ora 4/$zzyyxx
  1465  0b2b 48                 	!byte %01001000		;10 bpl 2/rel8
  1466  0b2c 49                 	!byte %01001001		;11 ora 2/($xx),Y
  1467  0b2d 4a                 	!byte %01001010		;12 ora 2/($xx)
  1468  0b2e 4b                 	!byte %01001011		;13 ora 2/(x,s),Y
  1469  0b2f 40                 	!byte %01000000		;14 trb 2/$xx
  1470  0b30 4c                 	!byte %01001100		;15 ora 2/$xx,X
  1471  0b31 4c                 	!byte %01001100		;16 asl 2/$xx,X
  1472  0b32 4d                 	!byte %01001101		;17 ora 2/[$xx],Y
  1473  0b33 24                 	!byte %00100100		;18 clc 1
  1474  0b34 6f                 	!byte %01101111		;19 ora 3/$yyxx,Y
  1475  0b35 24                 	!byte %00100100		;1a inc 1
  1476  0b36 24                 	!byte %00100100		;1b tcs 1
  1477  0b37 66                 	!byte %01100110		;1c trb 3/$yyxx
  1478  0b38 6e                 	!byte %01101110		;1d ora 3/$yyxx,X
  1479  0b39 6e                 	!byte %01101110		;1e asl 3/$yyxx,X
  1480  0b3a 90                 	!byte %10010000		;1f ora 4/$zzyyxx,X
  1481  0b3b 66                 	!byte %01100110		;20 jsr 3/$yyxx
  1482  0b3c 41                 	!byte %01000001		;21 and 2/($xx,x)
  1483  0b3d 87                 	!byte %10000111		;22 jsl 4/$zzyyxx
  1484  0b3e 42                 	!byte %01000010		;23 and 2/x,s
  1485  0b3f 40                 	!byte %01000000		;24 bit 2/$xx
  1486  0b40 40                 	!byte %01000000		;25 and 2/$xx
  1487  0b41 40                 	!byte %01000000		;26 rol 2/$xx
  1488  0b42 43                 	!byte %01000011		;27 and 2/[$xx]
  1489  0b43 24                 	!byte %00100100		;28 plp 1
  1490  0b44 45                 	!byte %01000101		;29 and 2/#imm
  1491  0b45 24                 	!byte %00100100		;2a rol 1
  1492  0b46 24                 	!byte %00100100		;2b pld 1
  1493  0b47 66                 	!byte %01100110		;2c bit 3/$yyxx
  1494  0b48 66                 	!byte %01100110		;2d and 3/$yyxx
  1495  0b49 66                 	!byte %01100110		;2e rol 3/$yyxx
  1496  0b4a 87                 	!byte %10000111		;2f and 4/$zzyyxx
  1497  0b4b 48                 	!byte %01001000		;30 bmi 2/rel8
  1498  0b4c 49                 	!byte %01001001		;31 and 2/($xx),Y
  1499  0b4d 4a                 	!byte %01001010		;32 and 2/($xx)
  1500  0b4e 4b                 	!byte %01001011		;33 and 2/(x,s),Y
  1501  0b4f 4c                 	!byte %01001100		;34 bit 2/$xx,X
  1502  0b50 4c                 	!byte %01001100		;35 and 2/$xx,X
  1503  0b51 4c                 	!byte %01001100		;36 rol 2/$xx,X
  1504  0b52 4d                 	!byte %01001101		;37 and 2/[$xx],Y
  1505  0b53 24                 	!byte %00100100		;38 sec 1
  1506  0b54 6f                 	!byte %01101111		;39 and 3/$yyxx,Y
  1507  0b55 24                 	!byte %00100100		;3a dec 1
  1508  0b56 24                 	!byte %00100100		;3b tsc 1
  1509  0b57 6e                 	!byte %01101110		;3c bit 3/$yyxx,X
  1510  0b58 6e                 	!byte %01101110		;3d and 3/$yyxx,X
  1511  0b59 6e                 	!byte %01101110		;3e rol 3/$yyxx,X
  1512  0b5a 90                 	!byte %10010000		;3f and 4/$zzyyxx,X
  1513  0b5b 24                 	!byte %00100100		;40 ???
  1514  0b5c 41                 	!byte %01000001		;41 eor 2/($xx,x)
  1515  0b5d 40                 	!byte %01000000		;42 wdm 2/$00
  1516  0b5e 42                 	!byte %01000010		;43 eor 2/x,s
  1517  0b5f 24                 	!byte %00100100		;44 ???
  1518  0b60 40                 	!byte %01000000		;45 eor 2/$xx
  1519  0b61 40                 	!byte %01000000		;46 lsr 2/$xx
  1520  0b62 43                 	!byte %01000011		;47 eor 2/[$xx]
  1521  0b63 24                 	!byte %00100100		;48 pha 1
  1522  0b64 45                 	!byte %01000101		;49 eor 2/#imm
  1523  0b65 24                 	!byte %00100100		;4a lsr 1
  1524  0b66 24                 	!byte %00100100		;4b phk 1
  1525  0b67 66                 	!byte %01100110		;4c jmp 3/$yyxx
  1526  0b68 66                 	!byte %01100110		;4d eor 3/$yyxx
  1527  0b69 66                 	!byte %01100110		;4e lsr 3/$yyxx
  1528  0b6a 87                 	!byte %10000111		;4f eor 4/$zzyyxx
  1529  0b6b 48                 	!byte %01001000		;50 bvc 2/rel8
  1530  0b6c 49                 	!byte %01001001		;51 eor 2/($xx),Y
  1531  0b6d 4a                 	!byte %01001010		;52 eor 2/($xx)
  1532  0b6e 4b                 	!byte %01001011		;53 eor 2/(x,s),Y
  1533  0b6f 24                 	!byte %00100100		;54 ???
  1534  0b70 4c                 	!byte %01001100		;55 eor 2/$xx,X
  1535  0b71 4c                 	!byte %01001100		;56 lsr 2/$xx,X
  1536  0b72 4d                 	!byte %01001101		;57 eor 2/[$xx],Y
  1537  0b73 24                 	!byte %00100100		;58 cli 1
  1538  0b74 6f                 	!byte %01101111		;59 eor 3/$yyxx,Y
  1539  0b75 24                 	!byte %00100100		;5a phy 1
  1540  0b76 24                 	!byte %00100100		;5b tcd 1
  1541  0b77 87                 	!byte %10000111		;5c jml 4/$zzyyxx
  1542  0b78 6e                 	!byte %01101110		;5d eor 3/$yyxx,X
  1543  0b79 6e                 	!byte %01101110		;5e lsr 3/$yyxx,X
  1544  0b7a 90                 	!byte %10010000		;5f eor 4/$zzyyxx,X
  1545  0b7b 24                 	!byte %00100100		;60 rts
  1546  0b7c 41                 	!byte %01000001		;61 adc 2/($xx,x)
  1547  0b7d 71                 	!byte %01110001		;62 per 3/rel16
  1548  0b7e 42                 	!byte %01000010		;63 adc 2/x,s
  1549  0b7f 40                 	!byte %01000000		;64 stz 2/$xx
  1550  0b80 40                 	!byte %01000000		;65 adc 2/$xx
  1551  0b81 40                 	!byte %01000000		;66 ror 2/$xx
  1552  0b82 43                 	!byte %01000011		;67 adc 2/[$xx]
  1553  0b83 24                 	!byte %00100100		;68 pla 1
  1554  0b84 45                 	!byte %01000101		;69 adc 2/#imm
  1555  0b85 24                 	!byte %00100100		;6a ror 1
  1556  0b86 24                 	!byte %00100100		;6b rtl 1
  1557  0b87 72                 	!byte %01110010		;6c jmp 3/($yyxx)
  1558  0b88 66                 	!byte %01100110		;6d adc 3/$yyxx
  1559  0b89 66                 	!byte %01100110		;6e ror 3/$yyxx
  1560  0b8a 87                 	!byte %10000111		;6f adc 4/$zzyyxx
  1561  0b8b 48                 	!byte %01001000		;70 bvs 2/rel8
  1562  0b8c 49                 	!byte %01001001		;71 adc 2/($xx),Y
  1563  0b8d 4a                 	!byte %01001010		;72 adc 2/($xx)
  1564  0b8e 4b                 	!byte %01001011		;73 adc 2/(x,s),Y
  1565  0b8f 4c                 	!byte %01001100		;74 stz 2/$xx,X
  1566  0b90 4c                 	!byte %01001100		;75 adc 2/$xx,X
  1567  0b91 4c                 	!byte %01001100		;76 ror 2/$xx,X
  1568  0b92 4d                 	!byte %01001101		;77 adc 2/[$xx],Y
  1569  0b93 24                 	!byte %00100100		;78 sei 1
  1570  0b94 6f                 	!byte %01101111		;79 adc 3/$yyxx,Y
  1571  0b95 24                 	!byte %00100100		;7a ply 1
  1572  0b96 24                 	!byte %00100100		;7b tdc 1
  1573  0b97 73                 	!byte %01110011		;7c jmp 3/($yyxx,X)
  1574  0b98 6e                 	!byte %01101110		;7d adc 3/$yyxx,X
  1575  0b99 6e                 	!byte %01101110		;7e lsr 3/$yyxx,X
  1576  0b9a 90                 	!byte %10010000		;7f adc 4/$zzyyxx,X
  1577  0b9b 48                 	!byte %01001000		;80 bra 2/rel8
  1578  0b9c 41                 	!byte %01000001		;81 sta 2/($xx,x)
  1579  0b9d 71                 	!byte %01110001		;82 brl 3/rel16
  1580  0b9e 42                 	!byte %01000010		;83 sta 2/x,s
  1581  0b9f 40                 	!byte %01000000		;84 sty 2/$xx
  1582  0ba0 40                 	!byte %01000000		;85 sta 2/$xx
  1583  0ba1 40                 	!byte %01000000		;86 stx 2/$xx
  1584  0ba2 43                 	!byte %01000011		;87 sta 2/[$xx]
  1585  0ba3 24                 	!byte %00100100		;88 dey 1
  1586  0ba4 45                 	!byte %01000101		;89 bit 2/#imm
  1587  0ba5 24                 	!byte %00100100		;8a txa 1
  1588  0ba6 24                 	!byte %00100100		;8b phb 1
  1589  0ba7 66                 	!byte %01100110		;8c sty 3/$yyxx
  1590  0ba8 66                 	!byte %01100110		;8d sta 3/$yyxx
  1591  0ba9 66                 	!byte %01100110		;8e stx 3/$yyxx
  1592  0baa 87                 	!byte %10000111		;8f sta 4/$zzyyxx
  1593  0bab 48                 	!byte %01001000		;90 bcc 2/rel8
  1594  0bac 49                 	!byte %01001001		;91 sta 2/($xx),Y
  1595  0bad 4a                 	!byte %01001010		;92 sta 2/($xx)
  1596  0bae 4b                 	!byte %01001011		;93 sta 2/(x,s),Y
  1597  0baf 4c                 	!byte %01001100		;94 sty 2/$xx,X
  1598  0bb0 4c                 	!byte %01001100		;95 sta 2/$xx,X
  1599  0bb1 54                 	!byte %01010100		;96 stx 2/$xx,Y
  1600  0bb2 4d                 	!byte %01001101		;97 sta 2/[$xx],Y
  1601  0bb3 24                 	!byte %00100100		;98 txa 1
  1602  0bb4 6f                 	!byte %01101111		;99 sta 3/$yyxx,Y
  1603  0bb5 24                 	!byte %00100100		;9a txs 1
  1604  0bb6 24                 	!byte %00100100		;9b txy 1
  1605  0bb7 66                 	!byte %01100110		;9c stz 3/$yyxx
  1606  0bb8 6e                 	!byte %01101110		;9d sta 3/$yyxx,X
  1607  0bb9 6e                 	!byte %01101110		;9e stz 3/$yyxx,X
  1608  0bba 90                 	!byte %10010000		;9f sta 4/$zzyyxx,X
  1609  0bbb 45                 	!byte %01000101		;a0 ldy 2/#imm
  1610  0bbc 41                 	!byte %01000001		;a1 lda 2/($xx,x)
  1611  0bbd 45                 	!byte %01000101		;a2 ldx 2/#imm
  1612  0bbe 42                 	!byte %01000010		;a3 lda 2/x,s
  1613  0bbf 40                 	!byte %01000000		;a4 ldy 2/$xx
  1614  0bc0 40                 	!byte %01000000		;a5 sta 2/$xx
  1615  0bc1 40                 	!byte %01000000		;a6 ldx 2/$xx
  1616  0bc2 43                 	!byte %01000011		;a7 lda 2/[$xx]
  1617  0bc3 24                 	!byte %00100100		;a8 tay 1
  1618  0bc4 45                 	!byte %01000101		;a9 lda 2/#imm
  1619  0bc5 24                 	!byte %00100100		;aa tax 1
  1620  0bc6 24                 	!byte %00100100		;ab plb 1
  1621  0bc7 66                 	!byte %01100110		;ac ldy 3/$yyxx
  1622  0bc8 66                 	!byte %01100110		;ad lda 3/$yyxx
  1623  0bc9 66                 	!byte %01100110		;ae ldx 3/$yyxx
  1624  0bca 87                 	!byte %10000111		;af lda 4/$zzyyxx
  1625  0bcb 48                 	!byte %01001000		;b0 bcs 2/rel8
  1626  0bcc 49                 	!byte %01001001		;b1 lda 2/($xx),Y
  1627  0bcd 4a                 	!byte %01001010		;b2 lda 2/($xx)
  1628  0bce 4b                 	!byte %01001011		;b3 lda 2/(x,s),Y
  1629  0bcf 4c                 	!byte %01001100		;b4 ldy 2/$xx,X
  1630  0bd0 4c                 	!byte %01001100		;b5 lda 2/$xx,X
  1631  0bd1 54                 	!byte %01010100		;b6 ldx 2/$xx,Y
  1632  0bd2 4d                 	!byte %01001101		;b7 lda 2/[$xx],Y
  1633  0bd3 24                 	!byte %00100100		;b8 clv 1
  1634  0bd4 6f                 	!byte %01101111		;b9 lda 3/$yyxx,Y
  1635  0bd5 24                 	!byte %00100100		;ba tsx 1
  1636  0bd6 24                 	!byte %00100100		;bb tyx 1
  1637  0bd7 66                 	!byte %01100110		;bc ldy 3/$yyxx
  1638  0bd8 6e                 	!byte %01101110		;bd lda 3/$yyxx,X
  1639  0bd9 6e                 	!byte %01101110		;be ldx 3/$yyxx,X
  1640  0bda 90                 	!byte %10010000		;bf lda 4/$zzyyxx,X
  1641  0bdb 45                 	!byte %01000101		;c0 cpy 2/#imm
  1642  0bdc 41                 	!byte %01000001		;c1 cmp 2/($xx,x)
  1643  0bdd 45                 	!byte %01000101		;c2 rep 2/#imm
  1644  0bde 42                 	!byte %01000010		;c3 cmp 2/x,s
  1645  0bdf 40                 	!byte %01000000		;c4 cpx 2/$xx
  1646  0be0 40                 	!byte %01000000		;c5 cmp 2/$xx
  1647  0be1 40                 	!byte %01000000		;c6 dec 2/$xx
  1648  0be2 43                 	!byte %01000011		;c7 cmp 2/[$xx]
  1649  0be3 24                 	!byte %00100100		;c8 iny 1
  1650  0be4 45                 	!byte %01000101		;c9 cmp 2/#imm
  1651  0be5 24                 	!byte %00100100		;ca dex 1
  1652  0be6 24                 	!byte %00100100		;cb wai 1
  1653  0be7 66                 	!byte %01100110		;cc cpy 3/$yyxx
  1654  0be8 66                 	!byte %01100110		;cd cmp 3/$yyxx
  1655  0be9 66                 	!byte %01100110		;ce dec 3/$yyxx
  1656  0bea 87                 	!byte %10000111		;cf cmp 4/$zzyyxx
  1657  0beb 48                 	!byte %01001000		;d0 bne 2/rel8
  1658  0bec 49                 	!byte %01001001		;d1 cmp 2/($xx),Y
  1659  0bed 4a                 	!byte %01001010		;d2 cmp 2/($xx)
  1660  0bee 4b                 	!byte %01001011		;d3 cmp 2/(x,s),Y
  1661  0bef 4a                 	!byte %01001010		;d4 pei 2/($xx)
  1662  0bf0 4c                 	!byte %01001100		;d5 cmp 2/$xx,X
  1663  0bf1 4c                 	!byte %01001100		;d6 dec 2/$xx,X
  1664  0bf2 4d                 	!byte %01001101		;d7 cmp 2/[$xx],Y
  1665  0bf3 24                 	!byte %00100100		;d8 cld 1
  1666  0bf4 6f                 	!byte %01101111		;d9 cmp 3/$yyxx,Y
  1667  0bf5 24                 	!byte %00100100		;da phx 1
  1668  0bf6 24                 	!byte %00100100		;db stp 1
  1669  0bf7 43                 	!byte %01000011		;dc jml 2/[$xx]
  1670  0bf8 6e                 	!byte %01101110		;dd cmp 3/$yyxx,X
  1671  0bf9 6e                 	!byte %01101110		;de dec 3/$yyxx,X
  1672  0bfa 90                 	!byte %10010000		;df cmp 4/$zzyyxx,X
  1673  0bfb 45                 	!byte %01000101		;e0 cpx 2/#imm
  1674  0bfc 41                 	!byte %01000001		;e1 sbc 2/($xx,x)
  1675  0bfd 45                 	!byte %01000101		;e2 sep 2/#imm
  1676  0bfe 42                 	!byte %01000010		;e3 sbc 2/x,s
  1677  0bff 40                 	!byte %01000000		;e4 cpx 2/$xx
  1678  0c00 40                 	!byte %01000000		;e5 sbc 2/$xx
  1679  0c01 40                 	!byte %01000000		;e6 inc 2/$xx
  1680  0c02 43                 	!byte %01000011		;e7 sbc 2/[$xx]
  1681  0c03 24                 	!byte %00100100		;e8 inx 1
  1682  0c04 45                 	!byte %01000101		;e9 sbc 2/#imm
  1683  0c05 24                 	!byte %00100100		;ea nop 1
  1684  0c06 24                 	!byte %00100100		;eb xba 1
  1685  0c07 66                 	!byte %01100110		;ec cpx 3/$yyxx
  1686  0c08 66                 	!byte %01100110		;ed sbc 3/$yyxx
  1687  0c09 66                 	!byte %01100110		;ee inc 3/$yyxx
  1688  0c0a 87                 	!byte %10000111		;ef sbc 4/$zzyyxx
  1689  0c0b 48                 	!byte %01001000		;f0 beq 2/rel8
  1690  0c0c 49                 	!byte %01001001		;f1 sbc 2/($xx),Y
  1691  0c0d 4a                 	!byte %01001010		;f2 sbc 2/($xx)
  1692  0c0e 4b                 	!byte %01001011		;f3 sbc 2/(x,s),Y
  1693  0c0f 66                 	!byte %01100110		;f4 pea 3/$yyxx
  1694  0c10 4c                 	!byte %01001100		;f5 sbc 2/$xx,X
  1695  0c11 4c                 	!byte %01001100		;f6 inc 2/$xx,X
  1696  0c12 4d                 	!byte %01001101		;f7 sbc 2/[$xx],Y
  1697  0c13 24                 	!byte %00100100		;f8 sed 1
  1698  0c14 6f                 	!byte %01101111		;f9 sbc 3/$yyxx,Y
  1699  0c15 24                 	!byte %00100100		;fa plx 1
  1700  0c16 24                 	!byte %00100100		;fb xce 1
  1701  0c17 73                 	!byte %01110011		;fc jsr 3/($yyxx)
  1702  0c18 6e                 	!byte %01101110		;fd sbc 3/$yyxx,X
  1703  0c19 6e                 	!byte %01101110		;fe inc 3/$yyxx,X
  1704  0c1a 90                 	!byte %10010000		;ff sbc 4/$zzyyxx,X
  1705                          mnemlist
  1706  0c1b 00                 	!byte $00			;00 brk
  1707  0c1c 02                 	!byte $02			;01 ora
  1708  0c1d 01                 	!byte $01			;02 cop
  1709  0c1e 02                 	!byte $02			;03 ora
  1710  0c1f 03                 	!byte $03			;04 tsb
  1711  0c20 02                 	!byte $02			;05 ora
  1712  0c21 04                 	!byte $04			;06 asl
  1713  0c22 02                 	!byte $02			;07 ora
  1714  0c23 05                 	!byte $05			;08 php
  1715  0c24 02                 	!byte $02			;09 ora
  1716  0c25 04                 	!byte $04			;0a asl
  1717  0c26 06                 	!byte $06			;0b phd
  1718  0c27 03                 	!byte $03			;0c tsb
  1719  0c28 02                 	!byte $02			;0d ora
  1720  0c29 04                 	!byte $04			;0e asl
  1721  0c2a 02                 	!byte $02			;0f ora
  1722  0c2b 07                 	!byte $07			;10 bpl
  1723  0c2c 02                 	!byte $02			;11 ora
  1724  0c2d 02                 	!byte $02			;12 ora
  1725  0c2e 02                 	!byte $02			;13 ora
  1726  0c2f 08                 	!byte $08			;14 trb
  1727  0c30 02                 	!byte $02			;15 ora
  1728  0c31 04                 	!byte $04			;16 asl
  1729  0c32 02                 	!byte $02			;17 ora
  1730  0c33 09                 	!byte $09			;18 clc
  1731  0c34 02                 	!byte $02			;19 ora
  1732  0c35 0a                 	!byte $0a			;1a inc
  1733  0c36 0b                 	!byte $0b			;1b tcs
  1734  0c37 08                 	!byte $08			;1c trb
  1735  0c38 02                 	!byte $02			;1d ora
  1736  0c39 04                 	!byte $04			;1e asl
  1737  0c3a 02                 	!byte $02			;1f ora
  1738  0c3b 0d                 	!byte $0d			;20 jsr
  1739  0c3c 0c                 	!byte $0c			;21 and
  1740  0c3d 0e                 	!byte $0e			;22 jsl
  1741  0c3e 0c                 	!byte $0c			;23 and
  1742  0c3f 10                 	!byte $10			;24 bit
  1743  0c40 0c                 	!byte $0c			;25 and
  1744  0c41 11                 	!byte $11			;26 rol
  1745  0c42 0c                 	!byte $0c			;27 and
  1746  0c43 12                 	!byte $12			;28 plp
  1747  0c44 0c                 	!byte $0c			;29 and
  1748  0c45 11                 	!byte $11			;2a rol
  1749  0c46 13                 	!byte $13			;2b pld
  1750  0c47 10                 	!byte $10			;2c bit
  1751  0c48 0c                 	!byte $0c			;2d and
  1752  0c49 11                 	!byte $11			;2e rol
  1753  0c4a 0c                 	!byte $0c			;2f and
  1754  0c4b 14                 	!byte $14			;30 bmi
  1755  0c4c 0c                 	!byte $0c			;31 and
  1756  0c4d 0c                 	!byte $0c			;32 and
  1757  0c4e 0c                 	!byte $0c			;33 and
  1758  0c4f 11                 	!byte $11			;34 bit
  1759  0c50 0c                 	!byte $0c			;35 and
  1760  0c51 11                 	!byte $11			;36 rol
  1761  0c52 0c                 	!byte $0c			;37 and
  1762  0c53 15                 	!byte $15			;38 sec
  1763  0c54 0c                 	!byte $0c			;39 and
  1764  0c55 0f                 	!byte $0f			;3a dec
  1765  0c56 16                 	!byte $16			;3b tsc
  1766  0c57 11                 	!byte $11			;3c bit
  1767  0c58 0c                 	!byte $0c			;3d and
  1768  0c59 11                 	!byte $11			;3e rol
  1769  0c5a 0c                 	!byte $0c			;3f and
  1770  0c5b 17                 	!byte $17			;40 ???
  1771  0c5c 18                 	!byte $18			;41 eor
  1772  0c5d 19                 	!byte $19			;42 wdm
  1773  0c5e 18                 	!byte $18			;43 eor
  1774  0c5f 17                 	!byte $17			;44 ???
  1775  0c60 18                 	!byte $18			;45 eor
  1776  0c61 1a                 	!byte $1a			;46 lsr
  1777  0c62 18                 	!byte $18			;47 eor
  1778  0c63 1b                 	!byte $1b			;48 pha
  1779  0c64 18                 	!byte $18			;49 eor
  1780  0c65 1a                 	!byte $1a			;4a lsr
  1781  0c66 1c                 	!byte $1c			;4b phk
  1782  0c67 1d                 	!byte $1d			;4c jmp
  1783  0c68 18                 	!byte $18			;4d eor
  1784  0c69 1a                 	!byte $1a			;4e lsr
  1785  0c6a 18                 	!byte $18			;4f eor
  1786  0c6b 1e                 	!byte $1e			;50 bvc
  1787  0c6c 18                 	!byte $18			;51 eor
  1788  0c6d 18                 	!byte $18			;52 eor
  1789  0c6e 18                 	!byte $18			;53 eor
  1790  0c6f 17                 	!byte $17			;54 ???
  1791  0c70 18                 	!byte $18			;55 eor
  1792  0c71 1a                 	!byte $1a			;56 lsr
  1793  0c72 18                 	!byte $18			;57 eor
  1794  0c73 1f                 	!byte $1f			;58 cli
  1795  0c74 18                 	!byte $18			;59 eor
  1796  0c75 20                 	!byte $20			;5a phy
  1797  0c76 21                 	!byte $21			;5b tcd
  1798  0c77 22                 	!byte $22			;5c jml
  1799  0c78 18                 	!byte $18			;5d eor
  1800  0c79 1a                 	!byte $1a			;5e lsr
  1801  0c7a 18                 	!byte $18			;5f eor
  1802  0c7b 23                 	!byte $23			;60 rts
  1803  0c7c 24                 	!byte $24			;61 adc
  1804  0c7d 25                 	!byte $25			;62 per
  1805  0c7e 24                 	!byte $24			;63 adc
  1806  0c7f 26                 	!byte $26			;64 stz
  1807  0c80 24                 	!byte $24			;65 adc
  1808  0c81 27                 	!byte $27			;66 ror
  1809  0c82 24                 	!byte $24			;67 adc
  1810  0c83 28                 	!byte $28			;68 pla
  1811  0c84 24                 	!byte $24			;69 adc
  1812  0c85 27                 	!byte $27			;6a ror
  1813  0c86 29                 	!byte $29			;6b rtl
  1814  0c87 1d                 	!byte $1d			;6c jmp
  1815  0c88 24                 	!byte $24			;6d adc
  1816  0c89 27                 	!byte $27			;6e ror
  1817  0c8a 24                 	!byte $24			;6f adc
  1818  0c8b 2a                 	!byte $2a			;70 bvs
  1819  0c8c 24                 	!byte $24			;71 adc
  1820  0c8d 24                 	!byte $24			;72 adc
  1821  0c8e 24                 	!byte $24			;73 adc
  1822  0c8f 26                 	!byte $26			;74 stz
  1823  0c90 24                 	!byte $24			;75 adc
  1824  0c91 27                 	!byte $27			;76 ror
  1825  0c92 24                 	!byte $24			;77 adc
  1826  0c93 2b                 	!byte $2b			;78 sei
  1827  0c94 24                 	!byte $24			;79 adc
  1828  0c95 2c                 	!byte $2c			;7a ply
  1829  0c96 2d                 	!byte $2d			;7b tdc
  1830  0c97 1d                 	!byte $1d			;7c jmp
  1831  0c98 24                 	!byte $24			;7d adc
  1832  0c99 27                 	!byte $27			;7e ror
  1833  0c9a 24                 	!byte $24			;7f adc
  1834  0c9b 2e                 	!byte $2e			;80 bra
  1835  0c9c 2f                 	!byte $2f			;81 sta
  1836  0c9d 30                 	!byte $30			;82 brl
  1837  0c9e 2f                 	!byte $2f			;83 sta
  1838  0c9f 31                 	!byte $31			;84 sty
  1839  0ca0 2f                 	!byte $2f			;85 sta
  1840  0ca1 32                 	!byte $32			;86 stx
  1841  0ca2 2f                 	!byte $2f			;87 sta
  1842  0ca3 33                 	!byte $33			;88 dey
  1843  0ca4 10                 	!byte $10			;89 bit
  1844  0ca5 34                 	!byte $34			;8a txa
  1845  0ca6 35                 	!byte $35			;8b phb
  1846  0ca7 31                 	!byte $31			;8c sty
  1847  0ca8 2f                 	!byte $2f			;8d sta
  1848  0ca9 32                 	!byte $32			;8e stx
  1849  0caa 2f                 	!byte $2f			;8f sta
  1850  0cab 36                 	!byte $36			;90 bcc
  1851  0cac 2f                 	!byte $2f			;91 sta
  1852  0cad 2f                 	!byte $2f			;92 sta
  1853  0cae 2f                 	!byte $2f			;93 sta
  1854  0caf 31                 	!byte $31			;94 sty
  1855  0cb0 2f                 	!byte $2f			;95 sta
  1856  0cb1 32                 	!byte $32			;96 stx
  1857  0cb2 2f                 	!byte $2f			;97 sta
  1858  0cb3 37                 	!byte $37			;98 tya
  1859  0cb4 2f                 	!byte $2f			;99 sta
  1860  0cb5 38                 	!byte $38			;9a txs
  1861  0cb6 39                 	!byte $39			;9b txy
  1862  0cb7 26                 	!byte $26			;9c stz
  1863  0cb8 2f                 	!byte $2f			;9d sta
  1864  0cb9 26                 	!byte $26			;9e stz
  1865  0cba 2f                 	!byte $2f			;9f sta
  1866  0cbb 3c                 	!byte $3c			;a0 ldy
  1867  0cbc 3a                 	!byte $3a			;a1 lda
  1868  0cbd 3b                 	!byte $3b			;a2 ldx
  1869  0cbe 3a                 	!byte $3a			;a3 lda
  1870  0cbf 3c                 	!byte $3c			;a4 ldy
  1871  0cc0 3a                 	!byte $3a			;a5 lda
  1872  0cc1 3b                 	!byte $3b			;a6 ldx
  1873  0cc2 3a                 	!byte $3a			;a7 lda
  1874  0cc3 3d                 	!byte $3d			;a8 tay
  1875  0cc4 3a                 	!byte $3a			;a9 lda
  1876  0cc5 3e                 	!byte $3e			;aa tax
  1877  0cc6 3f                 	!byte $3f			;ab plb
  1878  0cc7 3c                 	!byte $3c			;ac ldy
  1879  0cc8 3a                 	!byte $3a			;ad lda
  1880  0cc9 3b                 	!byte $3b			;ae ldx
  1881  0cca 3a                 	!byte $3a			;af lda
  1882  0ccb 40                 	!byte $40			;b0 bcs
  1883  0ccc 3a                 	!byte $3a			;b1 lda
  1884  0ccd 3a                 	!byte $3a			;b2 lda
  1885  0cce 3a                 	!byte $3a			;b3 lda
  1886  0ccf 3c                 	!byte $3c			;b4 ldy
  1887  0cd0 3a                 	!byte $3a			;b5 lda
  1888  0cd1 3b                 	!byte $3b			;b6 ldx
  1889  0cd2 3a                 	!byte $3a			;b7 lda
  1890  0cd3 41                 	!byte $41			;b8 clv
  1891  0cd4 3a                 	!byte $3a			;b9 lda
  1892  0cd5 42                 	!byte $42			;ba tsx
  1893  0cd6 43                 	!byte $43			;bb tyx
  1894  0cd7 3c                 	!byte $3c			;bc ldy
  1895  0cd8 3a                 	!byte $3a			;bd lda
  1896  0cd9 3b                 	!byte $3b			;be ldx
  1897  0cda 3a                 	!byte $3a			;bf lda
  1898  0cdb 46                 	!byte $46			;c0 cpy
  1899  0cdc 44                 	!byte $44			;c1 cmp
  1900  0cdd 47                 	!byte $47			;c2 rep
  1901  0cde 44                 	!byte $44			;c3 cmp
  1902  0cdf 46                 	!byte $46			;c4 cpy
  1903  0ce0 44                 	!byte $44			;c5 cmp
  1904  0ce1 48                 	!byte $48			;c6 dec
  1905  0ce2 44                 	!byte $44			;c7 cmp
  1906  0ce3 49                 	!byte $49			;c8 iny
  1907  0ce4 44                 	!byte $44			;c9 cmp
  1908  0ce5 4a                 	!byte $4a			;ca dex
  1909  0ce6 4b                 	!byte $4b			;cb wai
  1910  0ce7 46                 	!byte $46			;cc cpy
  1911  0ce8 44                 	!byte $44			;cd cmp
  1912  0ce9 48                 	!byte $48			;ce dec
  1913  0cea 44                 	!byte $44			;cf cmp
  1914  0ceb 4c                 	!byte $4c			;d0 bne
  1915  0cec 44                 	!byte $44			;d1 cmp
  1916  0ced 44                 	!byte $44			;d2 cmp
  1917  0cee 44                 	!byte $44			;d3 cmp
  1918  0cef 4d                 	!byte $4d			;d4 pei
  1919  0cf0 44                 	!byte $44			;d5 cmp
  1920  0cf1 48                 	!byte $48			;d6 dec
  1921  0cf2 44                 	!byte $44			;d7 cmp
  1922  0cf3 4e                 	!byte $4e			;d8 cld
  1923  0cf4 44                 	!byte $44			;d9 cmp
  1924  0cf5 4f                 	!byte $4f			;da phx
  1925  0cf6 50                 	!byte $50			;db stp
  1926  0cf7 22                 	!byte $22			;dc jml
  1927  0cf8 44                 	!byte $44			;dd cmp
  1928  0cf9 48                 	!byte $48			;de dec
  1929  0cfa 44                 	!byte $44			;df cmp
  1930  0cfb 51                 	!byte $51			;e0 cpx
  1931  0cfc 45                 	!byte $45			;e1 sbc
  1932  0cfd 52                 	!byte $52			;e2 sep
  1933  0cfe 45                 	!byte $45			;e3 sbc
  1934  0cff 51                 	!byte $51			;e4 cpx
  1935  0d00 45                 	!byte $45			;e5 sbc
  1936  0d01 53                 	!byte $53			;e6 inc
  1937  0d02 45                 	!byte $45			;e7 sbc
  1938  0d03 54                 	!byte $54			;e8 inx
  1939  0d04 45                 	!byte $45			;e9 sbc
  1940  0d05 55                 	!byte $55			;ea nop
  1941  0d06 56                 	!byte $56			;eb xba
  1942  0d07 51                 	!byte $51			;ec cpx
  1943  0d08 45                 	!byte $45			;ed sbc
  1944  0d09 53                 	!byte $53			;ee inc
  1945  0d0a 45                 	!byte $45			;ef sbc
  1946  0d0b 57                 	!byte $57			;f0 beq
  1947  0d0c 45                 	!byte $45			;f1 sbc
  1948  0d0d 45                 	!byte $45			;f2 sbc
  1949  0d0e 45                 	!byte $45			;f3 sbc
  1950  0d0f 58                 	!byte $58			;f4 pea
  1951  0d10 45                 	!byte $45			;f5 sbc
  1952  0d11 53                 	!byte $53			;f6 inc
  1953  0d12 45                 	!byte $45			;f7 sbc
  1954  0d13 59                 	!byte $59			;f8 sed
  1955  0d14 45                 	!byte $45			;f9 sbc
  1956  0d15 5a                 	!byte $5a			;fa plx
  1957  0d16 5b                 	!byte $5b			;fb xce
  1958  0d17 0d                 	!byte $0d			;fc jsr
  1959  0d18 45                 	!byte $45			;fd sbc
  1960  0d19 53                 	!byte $53			;fe inc
  1961  0d1a 45                 	!byte $45			;ff sbc
  1962                          mnems
  1963  0d1b 42524b             	!tx "BRK"			;0
  1964  0d1e 434f50             	!tx "COP"			;1
  1965  0d21 4f5241             	!tx "ORA"			;2
  1966  0d24 545342             	!tx "TSB"			;3
  1967  0d27 41534c             	!tx "ASL"			;4
  1968  0d2a 504850             	!tx "PHP"			;5
  1969  0d2d 504844             	!tx "PHD"			;6
  1970  0d30 42504c             	!tx "BPL"			;7
  1971  0d33 545242             	!tx "TRB"			;8
  1972  0d36 434c43             	!tx "CLC"			;9
  1973  0d39 494e43             	!tx "INC"			;a
  1974  0d3c 544353             	!tx "TCS"			;b
  1975  0d3f 414e44             	!tx "AND"			;c
  1976  0d42 4a5352             	!tx "JSR"			;d
  1977  0d45 4a534c             	!tx "JSL"			;e
  1978  0d48 444543             	!tx "DEC"			;f
  1979  0d4b 424954             	!tx "BIT"			;10
  1980  0d4e 524f4c             	!tx "ROL"			;11
  1981  0d51 504c50             	!tx "PLP"			;12
  1982  0d54 504c44             	!tx "PLD"			;13
  1983  0d57 424d49             	!tx "BMI"			;14
  1984  0d5a 534543             	!tx "SEC"			;15
  1985  0d5d 545343             	!tx "TSC"			;16
  1986  0d60 3f3f3f             	!tx "???"			;17
  1987  0d63 454f52             	!tx "EOR"			;18
  1988  0d66 57444d             	!tx "WDM"			;19
  1989  0d69 4c5352             	!tx "LSR"			;1a
  1990  0d6c 504841             	!tx "PHA"			;1b
  1991  0d6f 50484b             	!tx "PHK"			;1c
  1992  0d72 4a4d50             	!tx "JMP"			;1d
  1993  0d75 425643             	!tx "BVC"			;1e
  1994  0d78 434c49             	!tx "CLI"			;1f
  1995  0d7b 504859             	!tx "PHY"			;20
  1996  0d7e 544344             	!tx "TCD"			;21
  1997  0d81 4a4d4c             	!tx "JML"			;22
  1998  0d84 525453             	!tx "RTS"			;23
  1999  0d87 414443             	!tx "ADC"			;24
  2000  0d8a 504552             	!tx "PER"			;25
  2001  0d8d 53545a             	!tx "STZ"			;26
  2002  0d90 524f52             	!tx "ROR"			;27
  2003  0d93 504c41             	!tx "PLA"			;28
  2004  0d96 52544c             	!tx "RTL"			;29
  2005  0d99 425653             	!tx "BVS"			;2a
  2006  0d9c 534549             	!tx "SEI"			;2b
  2007  0d9f 504c59             	!tx "PLY"			;2c
  2008  0da2 544443             	!tx "TDC"			;2d
  2009  0da5 425241             	!tx "BRA"			;2e
  2010  0da8 535441             	!tx "STA"			;2f
  2011  0dab 42524c             	!tx "BRL"			;30
  2012  0dae 535459             	!tx "STY"			;31
  2013  0db1 535458             	!tx "STX"			;32
  2014  0db4 444559             	!tx "DEY"			;33
  2015  0db7 545841             	!tx "TXA"			;34
  2016  0dba 504842             	!tx "PHB"			;35
  2017  0dbd 424343             	!tx "BCC"			;36
  2018  0dc0 545941             	!tx "TYA"			;37
  2019  0dc3 545853             	!tx "TXS"			;38
  2020  0dc6 545859             	!tx "TXY"			;39
  2021  0dc9 4c4441             	!tx "LDA"			;3a
  2022  0dcc 4c4458             	!tx "LDX"			;3b
  2023  0dcf 4c4459             	!tx "LDY"			;3c
  2024  0dd2 544159             	!tx "TAY"			;3d
  2025  0dd5 544158             	!tx "TAX"			;3e
  2026  0dd8 504c42             	!tx "PLB"			;3f
  2027  0ddb 424353             	!tx "BCS"			;40
  2028  0dde 434c56             	!tx "CLV"			;41
  2029  0de1 545358             	!tx "TSX"			;42
  2030  0de4 545958             	!tx "TYX"			;43
  2031  0de7 434d50             	!tx "CMP"			;44
  2032  0dea 534243             	!tx "SBC"			;45
  2033  0ded 435059             	!tx "CPY"			;46
  2034  0df0 524550             	!tx "REP"			;47
  2035  0df3 444543             	!tx "DEC"			;48
  2036  0df6 494e59             	!tx "INY"			;49
  2037  0df9 444558             	!tx "DEX"			;4a
  2038  0dfc 574149             	!tx "WAI"			;4b
  2039  0dff 424e45             	!tx "BNE"			;4c
  2040  0e02 504549             	!tx "PEI"			;4d
  2041  0e05 434c44             	!tx "CLD"			;4e
  2042  0e08 504858             	!tx "PHX"			;4f
  2043  0e0b 535450             	!tx "STP"			;50
  2044  0e0e 435058             	!tx "CPX"			;51
  2045  0e11 534550             	!tx "SEP"			;52
  2046  0e14 494e43             	!tx "INC"			;53
  2047  0e17 494e58             	!tx "INX"			;54
  2048  0e1a 4e4f50             	!tx "NOP"			;55
  2049  0e1d 584241             	!tx "XBA"			;56
  2050  0e20 424551             	!tx "BEQ"			;57
  2051  0e23 504541             	!tx "PEA"			;58
  2052  0e26 534544             	!tx "SED"			;59
  2053  0e29 504c58             	!tx "PLX"			;5a
  2054  0e2c 584345             	!tx "XCE"			;5b
  2055                          	
  2056                          	!zone ucline
  2057                          ucline					;convert inbuff at $170400 to upper case
  2058  0e2f 08                 	php
  2059  0e30 c210               	rep #$10
  2060  0e32 e220               	sep #$20
  2061                          	!as
  2062                          	!rl
  2063  0e34 a20000             	ldx #$0000
  2064                          .local2
  2065  0e37 bf000417           	lda inbuff,x
  2066  0e3b f012               	beq .local4			;hit the zero, so bail
  2067  0e3d c961               	cmp #'a'
  2068  0e3f 900b               	bcc .local3			;less then lowercase a, so ignore
  2069  0e41 c97b               	cmp #'z' + 1		;less than next character after lowercase z?
  2070  0e43 b007               	bcs .local3			;greater than or equal, so ignore
  2071  0e45 38                 	sec
  2072  0e46 e920               	sbc #('z' - 'Z')	;make upper case
  2073  0e48 9f000417           	sta inbuff,x
  2074                          .local3
  2075  0e4c e8                 	inx
  2076  0e4d 80e8               	bra .local2
  2077                          .local4
  2078  0e4f 28                 	plp
  2079  0e50 6b                 	rtl
  2080                          	
  2081                          	!zone getline
  2082                          getline
  2083  0e51 08                 	php
  2084  0e52 c210               	rep #$10
  2085  0e54 e220               	sep #$20
  2086                          	!as
  2087                          	!rl
  2088  0e56 a20000             	ldx #$0000
  2089                          .local2
  2090  0e59 af00fc1b           	lda IO_KEYQ_SIZE
  2091  0e5d f0fa               	beq .local2
  2092  0e5f af01fc1b           	lda IO_KEYQ_WAITING
  2093  0e63 8f02fc1b           	sta IO_KEYQ_DEQUEUE
  2094  0e67 c90d               	cmp #$0d			;carriage return yet?
  2095  0e69 f01c               	beq .local3
  2096  0e6b c908               	cmp #$08			;backspace/back arrow?
  2097  0e6d f029               	beq .local4
  2098  0e6f c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
  2099  0e71 90e6               	bcc .local2		 		;yes, so ignore it
  2100  0e73 9f000417           	sta inbuff,x 		;any other character, so register it and store it
  2101  0e77 8f12fc1b           	sta IO_CON_CHAROUT
  2102  0e7b 8f13fc1b           	sta IO_CON_REGISTER
  2103  0e7f e8                 	inx
  2104  0e80 a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
  2105  0e82 e0fe03             	cpx #$3fe			;overrun end of buffer yet?
  2106  0e85 d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
  2107                          .local3
  2108  0e87 9f000417           	sta inbuff,x		;store CR
  2109  0e8b 8f17fc1b           	sta IO_CON_CR
  2110  0e8f e8                 	inx
  2111  0e90 a900               	lda #$00			;store zero to end it all
  2112  0e92 9f000417           	sta inbuff,x
  2113  0e96 28                 	plp
  2114  0e97 6b                 	rtl
  2115                          .local4
  2116  0e98 e00000             	cpx #$0000
  2117  0e9b f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
  2118  0e9d a908               	lda #$08
  2119  0e9f 8f12fc1b           	sta IO_CON_CHAROUT
  2120  0ea3 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
  2121  0ea7 a920               	lda #$20
  2122  0ea9 8f12fc1b           	sta IO_CON_CHAROUT
  2123  0ead 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
  2124  0eb1 a908               	lda #$08
  2125  0eb3 8f12fc1b           	sta IO_CON_CHAROUT
  2126  0eb7 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
  2127  0ebb ca                 	dex
  2128  0ebc 809b               	bra .local2
  2129                          	
  2130                          prinbuff				;feed location of input buffer into dpla and then print
  2131  0ebe 08                 	php
  2132  0ebf c210               	rep #$10
  2133  0ec1 e220               	sep #$20
  2134                          	!as
  2135                          	!rl
  2136  0ec3 a917               	lda #$17
  2137  0ec5 853f               	sta dpla_h
  2138  0ec7 a904               	lda #$04
  2139  0ec9 853e               	sta dpla_m
  2140  0ecb 643d               	stz dpla
  2141  0ecd 22d30e1c           	jsl l_prcdpla
  2142  0ed1 28                 	plp
  2143  0ed2 6b                 	rtl
  2144                          	
  2145                          	!zone prcdpla
  2146                          prcdpla					; print C string pointed to by dp locations $3d-$3f
  2147  0ed3 08                 	php					; modified for color coding (0x01/color byte to change colors)
  2148  0ed4 c210               	rep #$10			;  0x02 = return to default color
  2149  0ed6 e220               	sep #$20
  2150                          	!as
  2151                          	!rl
  2152  0ed8 af11fc1b           	lda IO_CON_COLOR
  2153  0edc 852f               	sta scratch1
  2154  0ede a00000             	ldy #$0000
  2155                          .local2
  2156  0ee1 b73d               	lda [dpla],y
  2157  0ee3 f013               	beq .local3
  2158  0ee5 c901               	cmp #$01
  2159  0ee7 f017               	beq .local4
  2160  0ee9 c902               	cmp #$02
  2161  0eeb f01d               	beq .local5
  2162  0eed 8f12fc1b           	sta IO_CON_CHAROUT
  2163  0ef1 8f13fc1b           	sta IO_CON_REGISTER
  2164  0ef5 c8                 	iny
  2165  0ef6 80e9               	bra .local2
  2166                          .local3
  2167  0ef8 a52f               	lda scratch1
  2168  0efa 8f11fc1b           	sta IO_CON_COLOR
  2169  0efe 28                 	plp
  2170  0eff 6b                 	rtl
  2171                          .local4
  2172  0f00 c8                 	iny
  2173  0f01 b73d               	lda [dpla],y
  2174  0f03 8f11fc1b           	sta IO_CON_COLOR
  2175  0f07 c8                 	iny
  2176  0f08 80d7               	bra .local2
  2177                          .local5
  2178  0f0a a52f               	lda scratch1
  2179  0f0c 8f11fc1b           	sta IO_CON_COLOR
  2180  0f10 c8                 	iny
  2181  0f11 80ce               	bra .local2
  2182                          	
  2183                          	!zone prcoldpla
  2184                          prcoldpla				;print colored C string (color byte/character byte pairs) pointed to by dpla
  2185  0f13 08                 	php
  2186  0f14 c210               	rep #$10
  2187  0f16 e220               	sep #$20
  2188                          	!as
  2189                          	!rl
  2190  0f18 af11fc1b           	lda IO_CON_COLOR
  2191  0f1c 852f               	sta scratch1
  2192  0f1e a00000             	ldy #$0000
  2193                          .local2
  2194  0f21 b73d               	lda [dpla],y
  2195  0f23 f012               	beq .local3
  2196  0f25 8f11fc1b           	sta IO_CON_COLOR
  2197  0f29 c8                 	iny
  2198  0f2a b73d               	lda [dpla],y
  2199  0f2c 8f12fc1b           	sta IO_CON_CHAROUT
  2200  0f30 8f13fc1b           	sta IO_CON_REGISTER
  2201  0f34 c8                 	iny
  2202  0f35 80ea               	bra .local2
  2203                          .local3
  2204  0f37 a52f               	lda scratch1
  2205  0f39 8f11fc1b           	sta IO_CON_COLOR
  2206  0f3d 28                 	plp
  2207  0f3e 6b                 	rtl
  2208                          
  2209                          initbanner
  2210  0f3f 0b49014d094c0120   	!byte 0x0b, 'I', 0x01, 'M', 0x09, 'L', 0x01, ' '
  2211  0f47 0336033503380331...	!byte 0x03, '6', 0x03, '5', 0x03, '8', 0x03, '1', 0x03, '6', 0x03, ' '
  2212  0f53 0c310c430c20       	!byte 0x0c, '1', 0x0c, 'C', 0x0c, ' '
  2213  0f59 064606690672066d...	!byte 0x06, 'F', 0x06, 'i', 0x06, 'r', 0x06, 'm', 0x06, 'w', 0x06, 'a', 0x06, 'r', 0x06, 'e', 0x06, ' '
  2214  0f6b 0d760d300d30       	!byte 0x0d, 'v', 0x0d, '0', 0x0d, '0'
  2215  0f71 010d               	!byte 0x01, 0x0d
  2216  0f73 00                 	!byte 0x00
  2217                          
  2218                          initstring
  2219  0f74 0101               	!byte 0x01, 0x01
  2220  0f76 53797374656d204d...	!tx "System Monitor"
  2221  0f84 0d                 	!byte 0x0d
  2222  0f85 0d                 	!byte 0x0d
  2223  0f86 00                 	!byte 0
  2224                          
  2225                          helpmsg
  2226  0f87 010e               	!byte 0x01, 0x0e
  2227  0f89 494d4c2036353831...	!tx "IML 65816 Monitor Commands"
  2228  0fa3 02                 	!byte 0x02
  2229  0fa4 0d                 	!byte $0d
  2230  0fa5 41203c616464723e...	!tx "A <addr>  Dump ASCII"
  2231  0fb9 0d                 	!byte $0d
  2232  0fba 42203c62616e6b3e...	!tx "B <bank>  Change bank"
  2233  0fcf 0d                 	!byte $0d
  2234  0fd0 43203c636f6c6f72...	!tx "C <color> Change terminal colors"
  2235  0ff0 0d                 	!byte $0d
  2236  0ff1 44203c616464723e...	!tx "D <addr>  Dump hex"
  2237  1003 0d                 	!byte $0d
  2238  1004 45203c616464723e...	!tx "E <addr> <byte> <byte>...  Enter bytes"
  2239  102a 0d                 	!byte $0d
  2240  102b 463f202020202020...	!tx "F?        Floating Point Support Help"
  2241  1050 0d                 	!byte $0d
  2242  1051 4c203c616464723e...	!tx "L <addr>  Disassemble 65816 Inst."
  2243  1072 0d                 	!byte $0d
  2244  1073 4d203c6d6f64653e...	!tx "M <mode>  Change video mode, 8/9"
  2245  1093 0d                 	!byte $0d
  2246  1094 5120202020202020...	!tx "Q         Halt the processor"
  2247  10b0 0d                 	!byte $0d
  2248  10b1 3f20202020202020...	!tx "?         This menu"
  2249  10c4 0d                 	!byte $0d
  2250  10c5 3c656e7465723e20...	!tx "<enter>   Repeat last dump command"
  2251  10e7 0d                 	!byte $0d
  2252  10e8 546f207370656369...	!tx "To specify range, use <addr1.addr2>"
  2253  110b 0d00               	!byte $0d, 00
  2254                          
  2255                          fphelpmsg
  2256  110d 010e               	!byte 0x01, 0x0e
  2257  110f 494d4c20466c6f61...	!tx "IML Floating Point Support"
  2258  1129 02                 	!byte 0x02
  2259  112a 0d                 	!byte $0d
  2260  112b 466f726d61743a20...	!tx "Format: F<cmd><sz><reg>"
  2261  1142 0d                 	!byte $0d
  2262  1143 53697a65733a2046...	!tx "Sizes: F=float D=double E=extended"
  2263  1165 0d                 	!byte $0d
  2264  1166 5265676973746572...	!tx "Registers: A=FACC B=FARG"
  2265  117e 0d                 	!byte $0d
  2266  117f 46443c737a3e2020...	!tx "FD<sz>    Display FACC/FARG"
  2267  119a 0d                 	!byte $0d
  2268  119b 46433c737a3e3c72...	!tx "FC<sz><reg> <constID> Load Constant"
  2269  11be 0d                 	!byte $0d
  2270  11bf 46493c737a3e3c72...	!tx "FI<sz><reg> Load Integer from FPINT"
  2271  11e2 0d                 	!byte $0d
  2272  11e3 46563c737a3e3c72...	!tx "FV<sz><reg> Save int(reg) to FPINT"
  2273  1205 0d                 	!byte $0d
  2274  1206 463c6f703e3c737a...	!tx "F<op><sz><reg> Bin Op, result in <reg>"
  2275  122c 0d                 	!byte $0d
  2276  122d 42696e617279204f...	!tx "Binary Ops: *, /, +, -"
  2277  1243 0d                 	!tx $0d
  2278  1244 464e3c737a3e3c72...	!tx "FN<sz><reg> Natural Log of <reg>"
  2279  1264 0d                 	!tx $0d
  2280  1265 46453c737a3e3c72...	!tx "FE<sz><reg> Exponential of <reg>"
  2281  1285 0d                 	!tx $0d
  2282  1286 00                 	!byte $00
  2283                          	
  2284  1287 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
  2285                          

; ******** done
