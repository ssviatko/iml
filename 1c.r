
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
    28                          
    29                          FPCOND = 0x1bfcbf
    30                          FPASCII = 0x1bfcc0
    31                          FPASCII_LO16 = 0xfcc0
    32                          FPACCUMULATOR = 0x1bfce0
    33                          FPARGUMENT = 0x1bfcf0
    34                          
    35                          promptchar = '*'
    36                          
    37                          l_getline = $1c0000 + getline
    38                          l_prinbuff = $1c0000 + prinbuff
    39                          l_prcdpla = $1c0000 + prcdpla
    40                          l_ucline = $1c0000 + ucline
    41                          
    42                          fpregspec = $28
    43                          fpmask = $29
    44                          scratch2 = $2a
    45                          scratch2_m = $2b
    46                          scratch2_h = $2c
    47                          alarge = $2d
    48                          xlarge = $2e
    49                          scratch1 = $2f
    50                          enterbytes = $30
    51                          enterbytes_m = $31
    52                          enterbytes_h = $32
    53                          rangehigh = $33
    54                          monrange = $35
    55                          monlast = $36
    56                          parseptr = $37
    57                          parseptr_m = $38
    58                          parseptr_h = $39
    59                          mondump = $3a
    60                          mondump_m = $3b
    61                          mondump_h = $3c
    62                          dpla = $3d
    63                          dpla_m = $3e
    64                          dpla_h = $3f
    65                          
    66                          inbuff = $170400
    67                          
    68                          x1crominit
    69  0000 4b                 	phk
    70  0001 ab                 	plb
    71  0002 c210               	rep #$10
    72                          	!rl
    73  0004 e220               	sep #$20
    74                          	!as
    75  0006 a2280e             	ldx #initstring
    76  0009 863d               	stx dpla
    77  000b a91c               	lda #$1c
    78  000d 853f               	sta dpla_h
    79  000f 220f0e1c           	jsl l_prcdpla
    80  0013 4c4503             	jmp+2 monstart
    81                          
    82                          parse_setup
    83  0016 a20004             	ldx #$0400
    84  0019 8637               	stx parseptr
    85  001b a917               	lda #$17
    86  001d 8539               	sta parseptr_h
    87  001f 60                 	rts
    88                          	
    89                          	!zone parse_getchar
    90                          parse_getchar			;get char from inbuff, assumes 8 bit A, 16 bit X
    91  0020 a737               	lda [parseptr]
    92  0022 48                 	pha
    93  0023 e637               	inc parseptr
    94  0025 d006               	bne .local2
    95  0027 e638               	inc parseptr_m
    96  0029 d002               	bne .local2
    97  002b e639               	inc parseptr_h
    98                          .local2
    99  002d 68                 	pla
   100  002e 60                 	rts
   101                          	
   102                          	!zone parse_addr
   103                          parse_addr				;see if user specified an address on line.
   104  002f a900               	lda #$00
   105  0031 48                 	pha
   106  0032 48                 	pha					;make space for working value on the stack
   107  0033 8535               	sta monrange		;clear range flag
   108                          .throwaway
   109  0035 202000             	jsr+2 parse_getchar
   110  0038 c920               	cmp #' '
   111  003a f0f9               	beq .throwaway		;throw away leading spaces
   112  003c 209800             	jsr+2 parse_getnib2	;get first nibble. call 2nd entry point since we already have character
   113  003f 9051               	bcc .no				;didn't even get one hex character, so return false
   114  0041 8301               	sta 1,s				;save it on the stack for now
   115  0043 209500             	jsr+2 parse_getnib	;get second nibble
   116  0046 9047               	bcc .yes			;if not hex then bail
   117  0048 48                 	pha
   118  0049 a302               	lda 2,s
   119  004b 0a                 	asl
   120  004c 0a                 	asl
   121  004d 0a                 	asl
   122  004e 0a                 	asl
   123  004f 0301               	ora 1,s
   124  0051 8302               	sta 2,s
   125  0053 68                 	pla					;add to stack
   126  0054 209500             	jsr+2 parse_getnib	;get possible third nibble
   127  0057 9036               	bcc .yes
   128  0059 c230               	rep #$30			;we're dealing with a 16 bit value now
   129                          	!al
   130  005b 290f00             	and #$000f
   131  005e 48                 	pha
   132  005f a303               	lda 3,s
   133  0061 0a                 	asl
   134  0062 0a                 	asl
   135  0063 0a                 	asl
   136  0064 0a                 	asl
   137  0065 0301               	ora 1,s
   138  0067 8303               	sta 3,s
   139  0069 68                 	pla
   140  006a e220               	sep #$20
   141                          	!as
   142  006c 209500             	jsr+2 parse_getnib
   143  006f 901e               	bcc .yes
   144  0071 c230               	rep #$30
   145                          	!al
   146  0073 290f00             	and #$000f
   147  0076 48                 	pha
   148  0077 a303               	lda 3,s
   149  0079 0a                 	asl
   150  007a 0a                 	asl
   151  007b 0a                 	asl
   152  007c 0a                 	asl
   153  007d 0301               	ora 1,s
   154  007f 8303               	sta 3,s
   155  0081 68                 	pla
   156  0082 e220               	sep #$20			;fall thru to yes on 4th nibble
   157                          	!as
   158  0084 202000             	jsr parse_getchar	;check to see if next char is a . so we can specify ranges
   159  0087 c92e               	cmp #'.'
   160  0089 d004               	bne .yes
   161  008b a980               	lda #$80
   162  008d 8535               	sta monrange
   163                          .yes
   164  008f 7a                 	ply					;get 16 bit work address off of stack
   165  0090 38                 	sec					;got address, return
   166  0091 60                 	rts
   167                          .no
   168  0092 7a                 	ply					;clear stack
   169  0093 18                 	clc					;no address found, return
   170  0094 60                 	rts
   171                          parse_getnib
   172  0095 202000             	jsr parse_getchar
   173                          parse_getnib2			;enter here after we've thrown away leading spaces
   174  0098 c920               	cmp #' '
   175  009a f021               	beq .outrng			;space = end of value
   176  009c c92e               	cmp #'.'
   177  009e d006               	bne .notrange
   178  00a0 a980               	lda #$80
   179  00a2 8535               	sta monrange		;this is the start of a range specification
   180  00a4 18                 	clc
   181  00a5 60                 	rts
   182                          .notrange
   183  00a6 c941               	cmp #$41
   184  00a8 900b               	bcc .outrnga
   185  00aa c947               	cmp #$47
   186  00ac b007               	bcs .outrnga
   187  00ae 38                 	sec
   188  00af e907               	sbc #$07			;in range of A-F
   189                          .success
   190  00b1 290f               	and #$0f
   191  00b3 38                 	sec
   192  00b4 60                 	rts
   193                          .outrnga				;test if 0-9
   194  00b5 c930               	cmp #$30
   195  00b7 9004               	bcc .outrng
   196  00b9 c93a               	cmp #$3a
   197  00bb 90f4               	bcc .success		;less than 3a, but >= 30, else fall thru to outrng
   198                          .outrng
   199  00bd 18                 	clc
   200  00be 60                 	rts
   201                          	
   202                          prdumpaddr
   203  00bf a53c               	lda mondump_h			;print long address
   204  00c1 204605             	jsr+2 prhex
   205  00c4 a92f               	lda #'/'
   206  00c6 8f12fc1b           	sta IO_CON_CHAROUT
   207  00ca 8f13fc1b           	sta IO_CON_REGISTER
   208  00ce a63a               	ldx mondump
   209  00d0 203c05             	jsr+2 prhex16
   210  00d3 a92d               	lda #'-'
   211  00d5 8f12fc1b           	sta IO_CON_CHAROUT
   212  00d9 8f13fc1b           	sta IO_CON_REGISTER
   213  00dd a920               	lda #' '
   214  00df 8f12fc1b           	sta IO_CON_CHAROUT
   215  00e3 8f13fc1b           	sta IO_CON_REGISTER
   216  00e7 60                 	rts
   217                          	
   218                          adjdumpaddr					;add 8 to dump address
   219  00e8 c230               	rep #$30
   220                          	!al
   221  00ea a53a               	lda mondump
   222  00ec 18                 	clc
   223  00ed 690800             	adc #$0008
   224  00f0 853a               	sta mondump
   225  00f2 e220               	sep #$20
   226                          	!as
   227  00f4 08                 	php						;save carry state.. did we carry to the bank?
   228  00f5 a53c               	lda mondump_h
   229  00f7 6900               	adc #$00
   230  00f9 853c               	sta mondump_h
   231  00fb 28                 	plp
   232  00fc 60                 	rts
   233                          
   234                          	!zone fpcmd
   235                          fphelp
   236  00fd a2d60f             	ldx #fphelpmsg
   237  0100 863d               	stx dpla
   238  0102 a91c               	lda #$1c
   239  0104 853f               	sta dpla_h
   240  0106 220f0e1c           	jsl l_prcdpla
   241  010a 4c5803             	jmp moncmd
   242                          fpcmd
   243  010d 202000             	jsr parse_getchar
   244  0110 c93f               	cmp #'?'
   245  0112 f0e9               	beq fphelp
   246  0114 c944               	cmp #'D'
   247  0116 d003               	bne .fpcmd1
   248  0118 4c0502             	jmp fpdisp
   249                          .fpcmd1
   250  011b c943               	cmp #'C'
   251  011d d003               	bne .fpcmd2
   252  011f 4ce001             	jmp fploadconst
   253                          .fpcmd2
   254  0122 c92a               	cmp #'*'
   255  0124 f04e               	beq fpmultiply
   256  0126 c92f               	cmp #'/'
   257  0128 f065               	beq fpdivide
   258  012a c92b               	cmp #'+'
   259  012c f07c               	beq fpadd
   260  012e c92d               	cmp #'-'
   261  0130 d003               	bne .fpcmd3
   262  0132 4cc501             	jmp fpsubtract
   263                          .fpcmd3
   264  0135 4cf002             	jmp monerror			;unrecognized FP command so fall thru to syntax error
   265                          
   266                          fpgetmask					;construct mask from size specifier, carry set if unregognized
   267  0138 202000             	jsr parse_getchar
   268  013b c946               	cmp #'F'
   269  013d d006               	bne .local1
   270  013f a900               	lda #$00
   271  0141 8529               	sta fpmask				;set bits 5/7 of fp mask to 0
   272  0143 8016               	bra .local4
   273                          .local1
   274  0145 c944               	cmp #'D'
   275  0147 d006               	bne .local2
   276  0149 a980               	lda #$80				;bit 7=1, bit 5=0
   277  014b 8529               	sta fpmask
   278  014d 800c               	bra .local4
   279                          .local2
   280  014f c945               	cmp #'E'
   281  0151 d006               	bne .local3
   282  0153 a920               	lda #$20				;bit 7=0, bit 5=1
   283  0155 8529               	sta fpmask
   284  0157 8002               	bra .local4
   285                          .local3
   286  0159 38                 	sec						;unknown size
   287  015a 60                 	rts
   288                          .local4
   289  015b 18                 	clc
   290  015c 60                 	rts
   291                          	
   292                          fpgetregspec
   293  015d 202000             	jsr parse_getchar		;set fpregspec to 00 or 40 depending on register specified
   294  0160 c941               	cmp #'A'
   295  0162 d004               	bne .localgrs1
   296  0164 6428               	stz fpregspec
   297  0166 8008               	bra .localgrs3
   298                          .localgrs1
   299  0168 c942               	cmp #'B'
   300  016a d006               	bne .localgrs4
   301  016c a940               	lda #$40
   302  016e 8528               	sta fpregspec
   303                          .localgrs3
   304  0170 18                 	clc
   305  0171 60                 	rts
   306                          .localgrs4
   307  0172 38                 	sec
   308  0173 60                 	rts
   309                          
   310                          fpmultiply
   311  0174 203801             	jsr fpgetmask
   312  0177 9003               	bcc .fpmultiply1
   313  0179 4cf002             	jmp monerror
   314                          .fpmultiply1
   315  017c 205d01             	jsr fpgetregspec
   316  017f 9003               	bcc .fpmultiply2
   317  0181 4cf002             	jmp monerror
   318                          .fpmultiply2
   319  0184 a529               	lda fpmask
   320  0186 0528               	ora fpregspec
   321  0188 8f42fc1b           	sta IO_FP_MULTIPLY
   322  018c 4c5803             	jmp moncmd
   323                          	
   324                          fpdivide
   325  018f 203801             	jsr fpgetmask
   326  0192 9003               	bcc .fpdivide1
   327  0194 4cf002             	jmp monerror
   328                          .fpdivide1
   329  0197 205d01             	jsr fpgetregspec
   330  019a 9003               	bcc .fpdivide2
   331  019c 4cf002             	jmp monerror
   332                          .fpdivide2
   333  019f a529               	lda fpmask
   334  01a1 0528               	ora fpregspec
   335  01a3 8f43fc1b           	sta IO_FP_DIVIDE
   336  01a7 4c5803             	jmp moncmd
   337                          	
   338                          fpadd
   339  01aa 203801             	jsr fpgetmask
   340  01ad 9003               	bcc .fpadd1
   341  01af 4cf002             	jmp monerror
   342                          .fpadd1
   343  01b2 205d01             	jsr fpgetregspec
   344  01b5 9003               	bcc .fpadd2
   345  01b7 4cf002             	jmp monerror
   346                          .fpadd2
   347  01ba a529               	lda fpmask
   348  01bc 0528               	ora fpregspec
   349  01be 8f44fc1b           	sta IO_FP_ADD
   350  01c2 4c5803             	jmp moncmd
   351                          	
   352                          fpsubtract
   353  01c5 203801             	jsr fpgetmask
   354  01c8 9003               	bcc .fpsubtract1
   355  01ca 4cf002             	jmp monerror
   356                          .fpsubtract1
   357  01cd 205d01             	jsr fpgetregspec
   358  01d0 9003               	bcc .fpsubtract2
   359  01d2 4cf002             	jmp monerror
   360                          .fpsubtract2
   361  01d5 a529               	lda fpmask
   362  01d7 0528               	ora fpregspec
   363  01d9 8f45fc1b           	sta IO_FP_SUBTRACT
   364  01dd 4c5803             	jmp moncmd
   365                          	
   366                          fploadconst
   367  01e0 203801             	jsr fpgetmask
   368  01e3 9003               	bcc .fploadconst1
   369  01e5 4cf002             	jmp monerror
   370                          .fploadconst1
   371  01e8 205d01             	jsr fpgetregspec
   372  01eb 9003               	bcc .fploadconst2
   373  01ed 4cf002             	jmp monerror
   374                          .fploadconst2
   375  01f0 202f00             	jsr parse_addr			;get const specifier
   376  01f3 c230               	rep #$30
   377  01f5 98                 	tya
   378  01f6 e220               	sep #$20
   379  01f8 291f               	and #$1f				;we're only interested in values 0-31
   380  01fa 0529               	ora fpmask
   381  01fc 0528               	ora fpregspec
   382  01fe 8f40fc1b           	sta IO_FP_INIT_CONSTANT
   383  0202 4c5803             	jmp moncmd
   384                          
   385                          fpdisp
   386  0205 203801             	jsr fpgetmask
   387  0208 901a               	bcc fpdisp2
   388  020a 4cf002             	jmp monerror
   389                          fpfacctxt
   390  020d 464143433a20       	!tx "FACC: "
   391  0213 00                 	!byte $00
   392                          fpfargtxt
   393  0214 464152473a20       	!tx "FARG: "
   394  021a 00                 	!byte $00
   395                          fpcondtxt
   396  021b 4650434f4e443a20   	!tx "FPCOND: "
   397  0223 00                 	!byte $00
   398                          fpdisp2
   399  0224 a20d02             	ldx #fpfacctxt			;print FACC: tag
   400  0227 863d               	stx dpla
   401  0229 a91c               	lda #$1c
   402  022b 853f               	sta dpla_h
   403  022d 220f0e1c           	jsl l_prcdpla
   404  0231 a20900             	ldx #9
   405  0234 a529               	lda fpmask
   406  0236 2920               	and #$20
   407  0238 d00c               	bne .facchex			;bit 5 set, so fall through and print 10 bytes
   408  023a a20700             	ldx #7
   409  023d a529               	lda fpmask
   410  023f 2980               	and #$80
   411  0241 d003               	bne .facchex			;bit 5 clear, but bit 7 set, print 8 bytes
   412  0243 a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   413                          .facchex					;print X number of hex bytes in reverse order
   414  0246 bfe0fc1b           	lda FPACCUMULATOR,x
   415  024a 204605             	jsr+2 prhex
   416  024d ca                 	dex
   417  024e 10f6               	bpl .facchex
   418  0250 a529               	lda fpmask
   419  0252 8f41fc1b           	sta IO_FP_TO_ASCII
   420  0256 a92f               	lda #'/'
   421  0258 8f12fc1b           	sta IO_CON_CHAROUT
   422  025c 8f13fc1b           	sta IO_CON_REGISTER
   423  0260 a2c0fc             	ldx #FPASCII_LO16
   424  0263 863d               	stx dpla
   425  0265 a91b               	lda #$1b
   426  0267 853f               	sta dpla_h
   427  0269 220f0e1c           	jsl l_prcdpla
   428  026d 8f17fc1b           	sta IO_CON_CR
   429                          	
   430  0271 a21402             	ldx #fpfargtxt			;print FARG: tag
   431  0274 863d               	stx dpla
   432  0276 a91c               	lda #$1c
   433  0278 853f               	sta dpla_h
   434  027a 220f0e1c           	jsl l_prcdpla
   435  027e a20900             	ldx #9
   436  0281 a529               	lda fpmask
   437  0283 2920               	and #$20
   438  0285 d00c               	bne .farghex			;bit 5 set, so fall through and print 10 bytes
   439  0287 a20700             	ldx #7
   440  028a a529               	lda fpmask
   441  028c 2980               	and #$80
   442  028e d003               	bne .farghex			;bit 5 clear, but bit 7 set, print 8 bytes
   443  0290 a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   444                          .farghex					;print X number of hex bytes in reverse order
   445  0293 bff0fc1b           	lda FPARGUMENT,x
   446  0297 204605             	jsr+2 prhex
   447  029a ca                 	dex
   448  029b 10f6               	bpl .farghex
   449  029d a529               	lda fpmask
   450  029f 0940               	ora #$40				;select FARG this time
   451  02a1 8f41fc1b           	sta IO_FP_TO_ASCII
   452  02a5 a92f               	lda #'/'
   453  02a7 8f12fc1b           	sta IO_CON_CHAROUT
   454  02ab 8f13fc1b           	sta IO_CON_REGISTER
   455  02af a2c0fc             	ldx #FPASCII_LO16
   456  02b2 863d               	stx dpla
   457  02b4 a91b               	lda #$1b
   458  02b6 853f               	sta dpla_h
   459  02b8 220f0e1c           	jsl l_prcdpla
   460  02bc 8f17fc1b           	sta IO_CON_CR
   461                          	
   462  02c0 a21b02             	ldx #fpcondtxt			;print FPCOND: tag
   463  02c3 863d               	stx dpla
   464  02c5 a91c               	lda #$1c
   465  02c7 853f               	sta dpla_h
   466  02c9 220f0e1c           	jsl l_prcdpla
   467  02cd a920               	lda #' '
   468  02cf 8f12fc1b           	sta IO_CON_CHAROUT
   469  02d3 8f13fc1b           	sta IO_CON_REGISTER
   470  02d7 afbffc1b           	lda FPCOND
   471  02db 204605             	jsr+2 prhex
   472  02de 8f17fc1b           	sta IO_CON_CR
   473                          	
   474  02e2 4c5803             	jmp moncmd
   475                          	
   476                          bankcmd
   477  02e5 202f00             	jsr parse_addr
   478  02e8 9006               	bcc monerror
   479  02ea 98                 	tya
   480  02eb 853c               	sta mondump_h
   481  02ed 4c5803             	jmp moncmd
   482                          monerror
   483  02f0 a20003             	ldx #monsynerr
   484  02f3 863d               	stx dpla
   485  02f5 a91c               	lda #$1c
   486  02f7 853f               	sta dpla_h
   487  02f9 220f0e1c           	jsl l_prcdpla
   488  02fd 4c5803             	jmp moncmd
   489                          monsynerr
   490  0300 53796e7461782065...	!tx "Syntax error!"
   491  030d 0d00               	!byte $0d, $00
   492                          
   493                          colorcmd
   494  030f 202f00             	jsr parse_addr
   495  0312 90dc               	bcc monerror
   496  0314 98                 	tya
   497  0315 8f11fc1b           	sta IO_CON_COLOR
   498  0319 4c5803             	jmp moncmd
   499                          	
   500                          modecmd
   501  031c 202f00             	jsr parse_addr
   502  031f 90cf               	bcc monerror
   503  0321 98                 	tya
   504  0322 c908               	cmp #$08
   505  0324 90ca               	bcc monerror
   506  0326 c90a               	cmp #$0a
   507  0328 b0c6               	bcs monerror
   508  032a 8f20fc1b           	sta IO_VIDMODE
   509  032e a900               	lda #$00
   510  0330 8f14fc1b           	sta IO_CON_CURSORH
   511  0334 8f15fc1b           	sta IO_CON_CURSORV
   512  0338 a920               	lda #$20
   513  033a 8f12fc1b           	sta IO_CON_CHAROUT
   514  033e 8f10fc1b           	sta IO_CON_CLS
   515  0342 4c5803             	jmp moncmd
   516                          	
   517                          monstart				;main entry point for system monitor
   518  0345 4b                 	phk
   519  0346 ab                 	plb
   520  0347 c210               	rep #$10
   521                          	!rl
   522  0349 e220               	sep #$20
   523                          	!as
   524  034b a20000             	ldx #$0000
   525  034e 863a               	stx mondump
   526  0350 a91c               	lda #$1c
   527  0352 853c               	sta mondump_h
   528  0354 a944               	lda #'D'
   529  0356 8536               	sta monlast
   530                          	
   531                          	!zone moncmd
   532                          moncmd
   533  0358 a92a               	lda #promptchar
   534  035a 8f12fc1b           	sta IO_CON_CHAROUT
   535  035e 8f13fc1b           	sta IO_CON_REGISTER
   536  0362 228d0d1c           	jsl l_getline
   537  0366 226b0d1c           	jsl l_ucline
   538  036a 201600             	jsr parse_setup
   539  036d 202000             	jsr parse_getchar
   540                          .local3
   541  0370 c951               	cmp #'Q'
   542  0372 f05b               	beq haltcmd
   543  0374 c944               	cmp #'D'
   544  0376 d003               	bne .local4
   545  0378 4c8b04             	jmp+2 dumpcmd
   546                          .local4
   547  037b c90d               	cmp #$0d
   548  037d d008               	bne .local2
   549  037f a536               	lda monlast			;recall previously executed command
   550  0381 c920               	cmp #$20			;make sure it isn't a control character
   551  0383 b0eb               	bcs .local3			;and retry it
   552  0385 80d1               	bra moncmd			;else recycle and try a new command
   553                          .local2
   554  0387 c941               	cmp #'A'
   555  0389 f06a               	beq asciidumpcmd
   556  038b c942               	cmp #'B'
   557  038d d003               	bne .local5
   558  038f 4ce502             	jmp+2 bankcmd
   559                          .local5
   560  0392 c943               	cmp #'C'
   561  0394 d003               	bne .local6
   562  0396 4c0f03             	jmp+2 colorcmd
   563                          .local6
   564  0399 c94d               	cmp #'M'
   565  039b d003               	bne .local7
   566  039d 4c1c03             	jmp+2 modecmd
   567                          .local7
   568  03a0 c945               	cmp #'E'
   569  03a2 d003               	bne .local8
   570  03a4 4c6605             	jmp+2 entercmd
   571                          .local8
   572  03a7 c94c               	cmp #'L'
   573  03a9 d003               	bne .local9
   574  03ab 4c9405             	jmp+2 listcmd
   575                          .local9
   576  03ae c93f               	cmp #'?'
   577  03b0 f00d               	beq helpcmd
   578  03b2 c946               	cmp #'F'
   579  03b4 f003               	beq .localfp
   580  03b6 4c5803             	jmp moncmd
   581                          .localfp
   582  03b9 200d01             	jsr fpcmd
   583  03bc 4c5803             	jmp moncmd
   584                          	
   585                          helpcmd
   586  03bf a2530e             	ldx #helpmsg
   587  03c2 863d               	stx dpla
   588  03c4 a91c               	lda #$1c
   589  03c6 853f               	sta dpla_h
   590  03c8 220f0e1c           	jsl l_prcdpla
   591  03cc 4c5803             	jmp moncmd
   592                          	
   593                          haltcmd
   594  03cf a2dd03             	ldx #haltmsg
   595  03d2 863d               	stx dpla
   596  03d4 a91c               	lda #$1c
   597  03d6 853f               	sta dpla_h
   598  03d8 220f0e1c           	jsl l_prcdpla
   599  03dc db                 	stp
   600                          haltmsg
   601  03dd 48616c74696e6720...	!tx "Halting 65816 engine.."
   602  03f3 0d00               	!byte $0d,$00
   603                          	
   604                          	!zone asciidumpcmd
   605                          asciidumpcmd
   606  03f5 8536               	sta monlast
   607  03f7 202f00             	jsr parse_addr
   608  03fa 9021               	bcc .local3
   609  03fc 843a               	sty mondump
   610  03fe 8433               	sty rangehigh
   611  0400 2435               	bit monrange			;user asking for a range?
   612  0402 1019               	bpl .local3
   613  0404 202f00             	jsr parse_addr			;get the remaining half of the range
   614  0407 8433               	sty rangehigh
   615  0409 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   616  040b 8535               	sta monrange
   617  040d a433               	ldy rangehigh
   618  040f d003               	bne .local6
   619  0411 4cf002             	jmp+2 monerror			;top of range can't be zero
   620                          .local6
   621  0414 a43a               	ldy mondump
   622  0416 c433               	cpy rangehigh
   623  0418 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   624  041a 4cf002             	jmp+2 monerror
   625                          .local3
   626  041d 20bf00             	jsr prdumpaddr
   627  0420 a00000             	ldy #$0000
   628                          .local2
   629  0423 b73a               	lda [mondump],y
   630  0425 c920               	cmp #$20
   631  0427 b002               	bcs .local4
   632  0429 a92e               	lda #'.'				;substitute control character with a period
   633                          .local4
   634  042b 8f12fc1b           	sta IO_CON_CHAROUT
   635  042f 8f13fc1b           	sta IO_CON_REGISTER
   636  0433 c8                 	iny
   637  0434 af20fc1b           	lda IO_VIDMODE
   638  0438 c909               	cmp #$09
   639  043a d007               	bne .lores1
   640  043c c04000             	cpy #$0040
   641  043f d0e2               	bne .local2
   642  0441 8005               	bra .lores2
   643                          .lores1
   644  0443 c01000             	cpy #$0010
   645  0446 d0db               	bne .local2
   646                          .lores2
   647  0448 8f17fc1b           	sta IO_CON_CR
   648  044c 20e800             	jsr adjdumpaddr
   649  044f b035               	bcs .local5				;carry to bank, exit even if we're processing a range
   650  0451 20e800             	jsr adjdumpaddr
   651  0454 b030               	bcs .local5	
   652  0456 af20fc1b           	lda IO_VIDMODE
   653  045a c909               	cmp #$09
   654  045c d01e               	bne .lores3
   655  045e 20e800             	jsr adjdumpaddr
   656  0461 b023               	bcs .local5	
   657  0463 20e800             	jsr adjdumpaddr
   658  0466 b01e               	bcs .local5	
   659  0468 20e800             	jsr adjdumpaddr
   660  046b b019               	bcs .local5	
   661  046d 20e800             	jsr adjdumpaddr
   662  0470 b014               	bcs .local5	
   663  0472 20e800             	jsr adjdumpaddr
   664  0475 b00f               	bcs .local5	
   665  0477 20e800             	jsr adjdumpaddr
   666  047a b00a               	bcs .local5	
   667                          .lores3
   668  047c 2435               	bit monrange			;ranges on?
   669  047e 1006               	bpl .local5
   670  0480 a433               	ldy rangehigh
   671  0482 c43a               	cpy mondump
   672  0484 b097               	bcs .local3
   673                          .local5
   674  0486 6435               	stz monrange
   675  0488 4c5803             	jmp moncmd
   676                          	
   677                          	!zone dumpcmd
   678                          dumpcmd
   679  048b 8536               	sta monlast
   680  048d 202f00             	jsr parse_addr
   681  0490 9021               	bcc .local3
   682  0492 843a               	sty mondump				;if address was specified, store 16 bit y at low 16 bits of mondump address
   683  0494 8433               	sty rangehigh
   684  0496 2435               	bit monrange			;user asking for a range?
   685  0498 1019               	bpl .local3
   686  049a 202f00             	jsr parse_addr			;get the remaining half of the range
   687  049d 8433               	sty rangehigh
   688  049f a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   689  04a1 8535               	sta monrange
   690  04a3 a433               	ldy rangehigh
   691  04a5 d003               	bne .local6
   692  04a7 4cf002             	jmp+2 monerror			;top of range can't be zero
   693                          .local6
   694  04aa a43a               	ldy mondump
   695  04ac c433               	cpy rangehigh
   696  04ae 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   697  04b0 4cf002             	jmp+2 monerror
   698                          .local3
   699  04b3 20bf00             	jsr prdumpaddr
   700  04b6 a00000             	ldy #$0000
   701                          .local2
   702  04b9 b73a               	lda [mondump],y
   703  04bb 204605             	jsr+2 prhex
   704  04be a920               	lda #' '
   705  04c0 8f12fc1b           	sta IO_CON_CHAROUT
   706  04c4 8f13fc1b           	sta IO_CON_REGISTER
   707  04c8 c8                 	iny
   708  04c9 af20fc1b           	lda IO_VIDMODE
   709  04cd c909               	cmp #$09
   710  04cf d03e               	bne .lores1
   711  04d1 c01000             	cpy #$0010
   712  04d4 d0e3               	bne .local2
   713  04d6 a920               	lda #' '
   714  04d8 8f12fc1b           	sta IO_CON_CHAROUT
   715  04dc 8f13fc1b           	sta IO_CON_REGISTER
   716  04e0 a92d               	lda #'-'
   717  04e2 8f12fc1b           	sta IO_CON_CHAROUT
   718  04e6 8f13fc1b           	sta IO_CON_REGISTER
   719  04ea a920               	lda #' '
   720  04ec 8f12fc1b           	sta IO_CON_CHAROUT
   721  04f0 8f13fc1b           	sta IO_CON_REGISTER
   722  04f4 a00000             	ldy #$0000				;print 16 bytes as ASCII... bonus when in mode 9!
   723                          .asc2
   724  04f7 b73a               	lda [mondump],y
   725  04f9 c920               	cmp #$20
   726  04fb b002               	bcs .asc4
   727  04fd a92e               	lda #'.'				;substitute control character with a period
   728                          .asc4
   729  04ff 8f12fc1b           	sta IO_CON_CHAROUT
   730  0503 8f13fc1b           	sta IO_CON_REGISTER
   731  0507 c8                 	iny
   732  0508 c01000             	cpy #$0010
   733  050b d0ea               	bne .asc2
   734  050d 8005               	bra .lores2
   735                          .lores1
   736  050f c00800             	cpy #$0008
   737  0512 d0a5               	bne .local2
   738                          .lores2
   739  0514 8f17fc1b           	sta IO_CON_CR
   740  0518 20e800             	jsr adjdumpaddr
   741  051b b01a               	bcs .local5				;carry to bank, exit even if we're processing a range
   742  051d af20fc1b           	lda IO_VIDMODE
   743  0521 c909               	cmp #$09
   744  0523 d005               	bne .lores3
   745  0525 20e800             	jsr adjdumpaddr
   746  0528 b00d               	bcs .local5
   747                          .lores3
   748  052a 2435               	bit monrange			;ranges on?
   749  052c 1009               	bpl .local5
   750  052e a433               	ldy rangehigh
   751  0530 c43a               	cpy mondump
   752  0532 9003               	bcc .local5
   753  0534 4cb304             	jmp+2 .local3
   754                          .local5
   755  0537 6435               	stz monrange
   756  0539 4c5803             	jmp moncmd
   757                          	
   758                          prhex16
   759  053c c230               	rep #$30
   760  053e 8a                 	txa
   761  053f e220               	sep #$20
   762  0541 eb                 	xba
   763  0542 204605             	jsr+2 prhex
   764  0545 eb                 	xba
   765                          prhex
   766  0546 48                 	pha
   767  0547 4a                 	lsr
   768  0548 4a                 	lsr
   769  0549 4a                 	lsr
   770  054a 4a                 	lsr
   771  054b 205105             	jsr+2 prhexnib
   772  054e 68                 	pla
   773  054f 290f               	and #$0f
   774                          prhexnib
   775  0551 0930               	ora #$30
   776  0553 c93a               	cmp #$3a
   777  0555 9003               	bcc prhexnofix
   778  0557 18                 	clc
   779  0558 6907               	adc #$07
   780                          prhexnofix
   781  055a 8f12fc1b           	sta IO_CON_CHAROUT
   782  055e 8f13fc1b           	sta IO_CON_REGISTER
   783  0562 60                 	rts
   784                          
   785                          	!zone entercmd
   786                          .local1
   787  0563 4cf002             	jmp monerror
   788                          entercmd
   789  0566 202f00             	jsr parse_addr
   790  0569 90f8               	bcc .local1			;address is mandatory
   791  056b 2435               	bit monrange
   792  056d 30f4               	bmi .local1			;ranges not allowed
   793  056f 8430               	sty enterbytes
   794  0571 a53c               	lda mondump_h
   795  0573 8532               	sta enterbytes_h	;retrieve bank from mondump
   796                          .local2
   797  0575 202f00             	jsr parse_addr		;start grabbing bytes
   798  0578 9017               	bcc .enterdone
   799  057a 2435               	bit monrange
   800  057c 30e5               	bmi .local1			;stop that happening here too
   801  057e c230               	rep #$30
   802  0580 98                 	tya
   803  0581 e220               	sep #$20			;get low byte of parsed address into A
   804  0583 8730               	sta [enterbytes]
   805  0585 e630               	inc enterbytes
   806  0587 d006               	bne .local3
   807  0589 e631               	inc enterbytes_m
   808  058b d002               	bne .local3
   809  058d e632               	inc enterbytes_h
   810                          .local3
   811  058f 80e4               	bra .local2
   812                          .enterdone
   813  0591 4c5803             	jmp moncmd
   814                          	
   815                          	!zone listcmd
   816                          listcmd
   817  0594 202f00             	jsr parse_addr
   818  0597 9002               	bcc .listmany				;address is optional
   819  0599 843a               	sty mondump
   820                          .listmany
   821  059b af20fc1b           	lda IO_VIDMODE
   822  059f c909               	cmp #$09
   823  05a1 d005               	bne .listmany1
   824  05a3 a22000             	ldx #32
   825  05a6 8003               	bra .listmany2
   826                          .listmany1
   827  05a8 a20f00             	ldx #15
   828                          .listmany2
   829  05ab da                 	phx
   830  05ac 20b605             	jsr+2 .listsingle
   831  05af fa                 	plx
   832  05b0 ca                 	dex
   833  05b1 d0f8               	bne .listmany2
   834  05b3 4c5803             	jmp moncmd
   835                          .listsingle
   836  05b6 a00000             	ldy #$0000
   837  05b9 20bf00             	jsr prdumpaddr
   838  05bc a900               	lda #$00
   839  05be eb                 	xba					;clear B
   840  05bf a73a               	lda [mondump]				;get opcode
   841  05c1 48                 	pha					;save opcode
   842  05c2 aa                 	tax
   843  05c3 bd570a             	lda mnemlenmode,x
   844  05c6 4a                 	lsr
   845  05c7 4a                 	lsr
   846  05c8 4a                 	lsr
   847  05c9 4a                 	lsr
   848  05ca 4a                 	lsr					;isolage opcode len
   849  05cb 852f               	sta scratch1
   850  05cd a73a               	lda [mondump]
   851  05cf 20fc09             	jsr+2 is816
   852  05d2 a52f               	lda scratch1
   853  05d4 aa                 	tax
   854  05d5 a00000             	ldy #$0000
   855                          .nextbyte
   856  05d8 b73a               	lda [mondump],y
   857  05da 204605             	jsr prhex			;print hex
   858  05dd a920               	lda #' '
   859  05df 8f12fc1b           	sta IO_CON_CHAROUT
   860  05e3 8f13fc1b           	sta IO_CON_REGISTER	;print space
   861  05e7 c8                 	iny
   862  05e8 ca                 	dex
   863  05e9 d0ed               	bne .nextbyte
   864  05eb a916               	lda #$16
   865  05ed 8f14fc1b           	sta IO_CON_CURSORH	;tab over
   866  05f1 68                 	pla					;get opcode back
   867  05f2 aa                 	tax
   868  05f3 bd570b             	lda mnemlist,x
   869  05f6 8530               	sta enterbytes
   870  05f8 6431               	stz enterbytes_m	;save for 16 bit add
   871  05fa da                 	phx					;stash our opcode
   872  05fb c230               	rep #$30
   873                          	!al
   874  05fd 29ff00             	and #$00ff			;switch to 16 bits, clear top
   875  0600 0a                 	asl
   876  0601 18                 	clc
   877  0602 6530               	adc enterbytes		;multiply by 3
   878  0604 aa                 	tax
   879  0605 e220               	sep #$20
   880                          	!as
   881  0607 bd570c             	lda mnems, x
   882  060a 8f12fc1b           	sta IO_CON_CHAROUT
   883  060e 8f13fc1b           	sta IO_CON_REGISTER
   884  0612 e8                 	inx
   885  0613 bd570c             	lda mnems, x
   886  0616 8f12fc1b           	sta IO_CON_CHAROUT
   887  061a 8f13fc1b           	sta IO_CON_REGISTER
   888  061e e8                 	inx
   889  061f bd570c             	lda mnems, x
   890  0622 8f12fc1b           	sta IO_CON_CHAROUT
   891  0626 8f13fc1b           	sta IO_CON_REGISTER
   892  062a a920               	lda #' '
   893  062c 8f12fc1b           	sta IO_CON_CHAROUT
   894  0630 8f13fc1b           	sta IO_CON_REGISTER
   895  0634 fa                 	plx					;get our opcode back in index
   896  0635 a900               	lda #$00
   897  0637 eb                 	xba					;clear top byte of A if it's dirty
   898  0638 bd570a             	lda mnemlenmode,x
   899  063b 291f               	and #$1f			;isolate the addressing mode
   900  063d 0a                 	asl					;multiply by two
   901  063e aa                 	tax
   902  063f fc2d0a             	jsr (listamod,x)
   903  0642 af20fc1b           	lda IO_VIDMODE
   904  0646 c909               	cmp #$09
   905  0648 d01f               	bne .fixup1
   906  064a a925               	lda #$25
   907  064c 8f14fc1b           	sta IO_CON_CURSORH		;tab over and print our bytes as ASCII in 80 column mode
   908  0650 e230               	sep #$30				;8 bit indexes here
   909                          	!rs
   910  0652 a000               	ldy #$00				;print disassembly bytes as ASCII... bonus when in mode 9!
   911                          .asc2
   912  0654 b73a               	lda [mondump],y
   913  0656 c920               	cmp #$20
   914  0658 b002               	bcs .asc4
   915  065a a92e               	lda #'.'				;substitute control character with a period
   916                          .asc4
   917  065c 8f12fc1b           	sta IO_CON_CHAROUT
   918  0660 8f13fc1b           	sta IO_CON_REGISTER
   919  0664 c8                 	iny
   920  0665 c42f               	cpy scratch1
   921  0667 d0eb               	bne .asc2
   922                          .fixup1
   923  0669 c210               	rep #$10
   924                          	!rl
   925  066b 8f17fc1b           	sta IO_CON_CR
   926                          .fixup
   927  066f a52f               	lda scratch1		;get our fixup
   928  0671 18                 	clc
   929  0672 653a               	adc mondump
   930  0674 853a               	sta mondump
   931  0676 a53b               	lda mondump_m
   932  0678 6900               	adc #$00
   933  067a 853b               	sta mondump_m
   934  067c a53c               	lda mondump_h
   935  067e 6900               	adc #$00
   936  0680 853c               	sta mondump_h
   937                          .goback
   938  0682 60                 	rts
   939                          
   940                          amod0
   941  0683 a924               	lda #'$'
   942  0685 8f12fc1b           	sta IO_CON_CHAROUT
   943  0689 8f13fc1b           	sta IO_CON_REGISTER
   944  068d a00100             	ldy #$0001
   945  0690 b73a               	lda [mondump],y
   946  0692 204605             	jsr prhex
   947  0695 60                 	rts
   948                          amod1
   949  0696 a928               	lda #'('
   950  0698 8f12fc1b           	sta IO_CON_CHAROUT
   951  069c 8f13fc1b           	sta IO_CON_REGISTER
   952  06a0 a924               	lda #'$'
   953  06a2 8f12fc1b           	sta IO_CON_CHAROUT
   954  06a6 8f13fc1b           	sta IO_CON_REGISTER
   955  06aa a00100             	ldy #$0001
   956  06ad b73a               	lda [mondump],y
   957  06af 204605             	jsr prhex
   958  06b2 a92c               	lda #','
   959  06b4 8f12fc1b           	sta IO_CON_CHAROUT
   960  06b8 8f13fc1b           	sta IO_CON_REGISTER
   961  06bc a958               	lda #'X'
   962  06be 8f12fc1b           	sta IO_CON_CHAROUT
   963  06c2 8f13fc1b           	sta IO_CON_REGISTER
   964  06c6 a929               	lda #')'
   965  06c8 8f12fc1b           	sta IO_CON_CHAROUT
   966  06cc 8f13fc1b           	sta IO_CON_REGISTER
   967  06d0 60                 	rts
   968                          amod2
   969  06d1 a00100             	ldy #$0001
   970  06d4 b73a               	lda [mondump],y
   971  06d6 204605             	jsr prhex
   972  06d9 a92c               	lda #','
   973  06db 8f12fc1b           	sta IO_CON_CHAROUT
   974  06df 8f13fc1b           	sta IO_CON_REGISTER
   975  06e3 a953               	lda #'S'
   976  06e5 8f12fc1b           	sta IO_CON_CHAROUT
   977  06e9 8f13fc1b           	sta IO_CON_REGISTER
   978  06ed 60                 	rts
   979                          amod3
   980  06ee a95b               	lda #'['
   981  06f0 8f12fc1b           	sta IO_CON_CHAROUT
   982  06f4 8f13fc1b           	sta IO_CON_REGISTER
   983  06f8 a924               	lda #'$'
   984  06fa 8f12fc1b           	sta IO_CON_CHAROUT
   985  06fe 8f13fc1b           	sta IO_CON_REGISTER
   986  0702 a00100             	ldy #$0001
   987  0705 b73a               	lda [mondump],y
   988  0707 204605             	jsr prhex
   989  070a a95d               	lda #']'
   990  070c 8f12fc1b           	sta IO_CON_CHAROUT
   991  0710 8f13fc1b           	sta IO_CON_REGISTER
   992                          amod4
   993  0714 60                 	rts
   994                          	!zone amod5
   995                          amod5
   996  0715 a923               	lda #'#'
   997  0717 8f12fc1b           	sta IO_CON_CHAROUT
   998  071b 8f13fc1b           	sta IO_CON_REGISTER
   999  071f a924               	lda #'$'
  1000  0721 8f12fc1b           	sta IO_CON_CHAROUT
  1001  0725 8f13fc1b           	sta IO_CON_REGISTER
  1002  0729 a52f               	lda scratch1
  1003  072b c902               	cmp #$02
  1004  072d f008               	beq .amod508
  1005                          .amod516
  1006  072f a00200             	ldy #$0002
  1007  0732 b73a               	lda [mondump],y
  1008  0734 204605             	jsr prhex
  1009                          .amod508
  1010  0737 a00100             	ldy #$0001
  1011  073a b73a               	lda [mondump],y
  1012  073c 204605             	jsr prhex
  1013  073f 60                 	rts
  1014                          amod6
  1015  0740 a924               	lda #'$'
  1016  0742 8f12fc1b           	sta IO_CON_CHAROUT
  1017  0746 8f13fc1b           	sta IO_CON_REGISTER
  1018  074a a00200             	ldy #$0002
  1019  074d b73a               	lda [mondump],y
  1020  074f 204605             	jsr prhex
  1021  0752 88                 	dey
  1022  0753 b73a               	lda [mondump],y
  1023  0755 4c4605             	jmp prhex
  1024                          amod7
  1025  0758 a924               	lda #'$'
  1026  075a 8f12fc1b           	sta IO_CON_CHAROUT
  1027  075e 8f13fc1b           	sta IO_CON_REGISTER
  1028  0762 a00300             	ldy #$0003
  1029  0765 b73a               	lda [mondump],y
  1030  0767 204605             	jsr prhex
  1031  076a 88                 	dey
  1032  076b b73a               	lda [mondump],y
  1033  076d 204605             	jsr prhex
  1034  0770 88                 	dey
  1035  0771 b73a               	lda [mondump],y
  1036  0773 4c4605             	jmp prhex
  1037                          amod11
  1038  0776 a00300             	ldy #$0003
  1039  0779 842a               	sty scratch2			;number of bytes to bump offset
  1040  077b a00200             	ldy #$0002
  1041  077e b73a               	lda [mondump],y
  1042  0780 eb                 	xba
  1043  0781 88                 	dey
  1044  0782 b73a               	lda [mondump],y
  1045  0784 8014               	bra amod8nosign
  1046                          amod8
  1047  0786 a00200             	ldy #$0002
  1048  0789 842a               	sty scratch2
  1049  078b a900               	lda #$00
  1050  078d eb                 	xba						;clear high byte of A
  1051                          amod8a
  1052  078e a00100             	ldy #$0001
  1053  0791 b73a               	lda [mondump],y			;get rel byte
  1054  0793 1005               	bpl amod8nosign
  1055  0795 48                 	pha
  1056  0796 a9ff               	lda #$ff
  1057  0798 eb                 	xba						;sign extend if negative
  1058  0799 68                 	pla
  1059                          amod8nosign
  1060  079a c230               	rep #$30
  1061                          	!al
  1062  079c 18                 	clc
  1063  079d 653a               	adc mondump				;add to our current disassembly address
  1064  079f 18                 	clc
  1065  07a0 652a               	adc scratch2			;add offset for instruction size
  1066  07a2 aa                 	tax
  1067  07a3 e220               	sep #$20
  1068                          	!as
  1069  07a5 a924               	lda #'$'
  1070  07a7 8f12fc1b           	sta IO_CON_CHAROUT
  1071  07ab 8f13fc1b           	sta IO_CON_REGISTER
  1072  07af 203c05             	jsr prhex16
  1073  07b2 60                 	rts
  1074                          amod9
  1075  07b3 a928               	lda #'('
  1076  07b5 8f12fc1b           	sta IO_CON_CHAROUT
  1077  07b9 8f13fc1b           	sta IO_CON_REGISTER
  1078  07bd a924               	lda #'$'
  1079  07bf 8f12fc1b           	sta IO_CON_CHAROUT
  1080  07c3 8f13fc1b           	sta IO_CON_REGISTER
  1081  07c7 a00100             	ldy #$0001
  1082  07ca b73a               	lda [mondump],y
  1083  07cc 204605             	jsr prhex
  1084  07cf a929               	lda #')'
  1085  07d1 8f12fc1b           	sta IO_CON_CHAROUT
  1086  07d5 8f13fc1b           	sta IO_CON_REGISTER
  1087  07d9 a92c               	lda #','
  1088  07db 8f12fc1b           	sta IO_CON_CHAROUT
  1089  07df 8f13fc1b           	sta IO_CON_REGISTER
  1090  07e3 a959               	lda #'Y'
  1091  07e5 8f12fc1b           	sta IO_CON_CHAROUT
  1092  07e9 8f13fc1b           	sta IO_CON_REGISTER
  1093  07ed 60                 	rts
  1094                          amoda
  1095  07ee a928               	lda #'('
  1096  07f0 8f12fc1b           	sta IO_CON_CHAROUT
  1097  07f4 8f13fc1b           	sta IO_CON_REGISTER
  1098  07f8 a924               	lda #'$'
  1099  07fa 8f12fc1b           	sta IO_CON_CHAROUT
  1100  07fe 8f13fc1b           	sta IO_CON_REGISTER
  1101  0802 a00100             	ldy #$0001
  1102  0805 b73a               	lda [mondump],y
  1103  0807 204605             	jsr prhex
  1104  080a a929               	lda #')'
  1105  080c 8f12fc1b           	sta IO_CON_CHAROUT
  1106  0810 8f13fc1b           	sta IO_CON_REGISTER
  1107  0814 60                 	rts
  1108                          amodb
  1109  0815 a928               	lda #'('
  1110  0817 8f12fc1b           	sta IO_CON_CHAROUT
  1111  081b 8f13fc1b           	sta IO_CON_REGISTER
  1112  081f a924               	lda #'$'
  1113  0821 8f12fc1b           	sta IO_CON_CHAROUT
  1114  0825 8f13fc1b           	sta IO_CON_REGISTER
  1115  0829 a00100             	ldy #$0001
  1116  082c b73a               	lda [mondump],y
  1117  082e 204605             	jsr prhex
  1118  0831 a92c               	lda #','
  1119  0833 8f12fc1b           	sta IO_CON_CHAROUT
  1120  0837 8f13fc1b           	sta IO_CON_REGISTER
  1121  083b a953               	lda #'S'
  1122  083d 8f12fc1b           	sta IO_CON_CHAROUT
  1123  0841 8f13fc1b           	sta IO_CON_REGISTER
  1124  0845 a929               	lda #')'
  1125  0847 8f12fc1b           	sta IO_CON_CHAROUT
  1126  084b 8f13fc1b           	sta IO_CON_REGISTER
  1127  084f a92c               	lda #','
  1128  0851 8f12fc1b           	sta IO_CON_CHAROUT
  1129  0855 8f13fc1b           	sta IO_CON_REGISTER
  1130  0859 a959               	lda #'Y'
  1131  085b 8f12fc1b           	sta IO_CON_CHAROUT
  1132  085f 8f13fc1b           	sta IO_CON_REGISTER
  1133  0863 60                 	rts
  1134                          amodc
  1135  0864 a924               	lda #'$'
  1136  0866 8f12fc1b           	sta IO_CON_CHAROUT
  1137  086a 8f13fc1b           	sta IO_CON_REGISTER
  1138  086e a00100             	ldy #$0001
  1139  0871 b73a               	lda [mondump],y
  1140  0873 204605             	jsr prhex
  1141  0876 a92c               	lda #','
  1142  0878 8f12fc1b           	sta IO_CON_CHAROUT
  1143  087c 8f13fc1b           	sta IO_CON_REGISTER
  1144  0880 a958               	lda #'X'
  1145  0882 8f12fc1b           	sta IO_CON_CHAROUT
  1146  0886 8f13fc1b           	sta IO_CON_REGISTER
  1147  088a 60                 	rts
  1148                          amodd
  1149  088b a95b               	lda #'['
  1150  088d 8f12fc1b           	sta IO_CON_CHAROUT
  1151  0891 8f13fc1b           	sta IO_CON_REGISTER
  1152  0895 a924               	lda #'$'
  1153  0897 8f12fc1b           	sta IO_CON_CHAROUT
  1154  089b 8f13fc1b           	sta IO_CON_REGISTER
  1155  089f a00100             	ldy #$0001
  1156  08a2 b73a               	lda [mondump],y
  1157  08a4 204605             	jsr prhex
  1158  08a7 a95d               	lda #']'
  1159  08a9 8f12fc1b           	sta IO_CON_CHAROUT
  1160  08ad 8f13fc1b           	sta IO_CON_REGISTER
  1161  08b1 a92c               	lda #','
  1162  08b3 8f12fc1b           	sta IO_CON_CHAROUT
  1163  08b7 8f13fc1b           	sta IO_CON_REGISTER
  1164  08bb a959               	lda #'Y'
  1165  08bd 8f12fc1b           	sta IO_CON_CHAROUT
  1166  08c1 8f13fc1b           	sta IO_CON_REGISTER
  1167  08c5 60                 	rts
  1168                          amode
  1169  08c6 a924               	lda #'$'
  1170  08c8 8f12fc1b           	sta IO_CON_CHAROUT
  1171  08cc 8f13fc1b           	sta IO_CON_REGISTER
  1172  08d0 a00200             	ldy #$0002
  1173  08d3 b73a               	lda [mondump],y
  1174  08d5 204605             	jsr prhex
  1175  08d8 88                 	dey
  1176  08d9 b73a               	lda [mondump],y
  1177  08db 204605             	jsr prhex
  1178  08de a92c               	lda #','
  1179  08e0 8f12fc1b           	sta IO_CON_CHAROUT
  1180  08e4 8f13fc1b           	sta IO_CON_REGISTER
  1181  08e8 a958               	lda #'X'
  1182  08ea 8f12fc1b           	sta IO_CON_CHAROUT
  1183  08ee 8f13fc1b           	sta IO_CON_REGISTER
  1184  08f2 60                 	rts
  1185                          amodf
  1186  08f3 a924               	lda #'$'
  1187  08f5 8f12fc1b           	sta IO_CON_CHAROUT
  1188  08f9 8f13fc1b           	sta IO_CON_REGISTER
  1189  08fd a00200             	ldy #$0002
  1190  0900 b73a               	lda [mondump],y
  1191  0902 204605             	jsr prhex
  1192  0905 88                 	dey
  1193  0906 b73a               	lda [mondump],y
  1194  0908 204605             	jsr prhex
  1195  090b a92c               	lda #','
  1196  090d 8f12fc1b           	sta IO_CON_CHAROUT
  1197  0911 8f13fc1b           	sta IO_CON_REGISTER
  1198  0915 a959               	lda #'Y'
  1199  0917 8f12fc1b           	sta IO_CON_CHAROUT
  1200  091b 8f13fc1b           	sta IO_CON_REGISTER
  1201  091f 60                 	rts
  1202                          amod10
  1203  0920 a924               	lda #'$'
  1204  0922 8f12fc1b           	sta IO_CON_CHAROUT
  1205  0926 8f13fc1b           	sta IO_CON_REGISTER
  1206  092a a00300             	ldy #$0003
  1207  092d b73a               	lda [mondump],y
  1208  092f 204605             	jsr prhex
  1209  0932 88                 	dey
  1210  0933 b73a               	lda [mondump],y
  1211  0935 204605             	jsr prhex
  1212  0938 88                 	dey
  1213  0939 b73a               	lda [mondump],y
  1214  093b 204605             	jsr prhex
  1215  093e a92c               	lda #','
  1216  0940 8f12fc1b           	sta IO_CON_CHAROUT
  1217  0944 8f13fc1b           	sta IO_CON_REGISTER
  1218  0948 a958               	lda #'X'
  1219  094a 8f12fc1b           	sta IO_CON_CHAROUT
  1220  094e 8f13fc1b           	sta IO_CON_REGISTER
  1221  0952 60                 	rts
  1222                          amod12
  1223  0953 a928               	lda #'('
  1224  0955 8f12fc1b           	sta IO_CON_CHAROUT
  1225  0959 8f13fc1b           	sta IO_CON_REGISTER
  1226  095d a924               	lda #'$'
  1227  095f 8f12fc1b           	sta IO_CON_CHAROUT
  1228  0963 8f13fc1b           	sta IO_CON_REGISTER
  1229  0967 a00200             	ldy #$0002
  1230  096a b73a               	lda [mondump],y
  1231  096c 204605             	jsr prhex
  1232  096f 88                 	dey
  1233  0970 b73a               	lda [mondump],y
  1234  0972 204605             	jsr prhex
  1235  0975 a929               	lda #')'
  1236  0977 8f12fc1b           	sta IO_CON_CHAROUT
  1237  097b 8f13fc1b           	sta IO_CON_REGISTER
  1238  097f 60                 	rts
  1239                          amod13
  1240  0980 a928               	lda #'('
  1241  0982 8f12fc1b           	sta IO_CON_CHAROUT
  1242  0986 8f13fc1b           	sta IO_CON_REGISTER
  1243  098a a924               	lda #'$'
  1244  098c 8f12fc1b           	sta IO_CON_CHAROUT
  1245  0990 8f13fc1b           	sta IO_CON_REGISTER
  1246  0994 a00200             	ldy #$0002
  1247  0997 b73a               	lda [mondump],y
  1248  0999 204605             	jsr prhex
  1249  099c 88                 	dey
  1250  099d b73a               	lda [mondump],y
  1251  099f 204605             	jsr prhex
  1252  09a2 a92c               	lda #','
  1253  09a4 8f12fc1b           	sta IO_CON_CHAROUT
  1254  09a8 8f13fc1b           	sta IO_CON_REGISTER
  1255  09ac a958               	lda #'X'
  1256  09ae 8f12fc1b           	sta IO_CON_CHAROUT
  1257  09b2 8f13fc1b           	sta IO_CON_REGISTER
  1258  09b6 a929               	lda #')'
  1259  09b8 8f12fc1b           	sta IO_CON_CHAROUT
  1260  09bc 8f13fc1b           	sta IO_CON_REGISTER
  1261  09c0 60                 	rts
  1262                          amod14
  1263  09c1 a924               	lda #'$'
  1264  09c3 8f12fc1b           	sta IO_CON_CHAROUT
  1265  09c7 8f13fc1b           	sta IO_CON_REGISTER
  1266  09cb a00100             	ldy #$0001
  1267  09ce b73a               	lda [mondump],y
  1268  09d0 204605             	jsr prhex
  1269  09d3 a92c               	lda #','
  1270  09d5 8f12fc1b           	sta IO_CON_CHAROUT
  1271  09d9 8f13fc1b           	sta IO_CON_REGISTER
  1272  09dd a959               	lda #'Y'
  1273  09df 8f12fc1b           	sta IO_CON_CHAROUT
  1274  09e3 8f13fc1b           	sta IO_CON_REGISTER
  1275  09e7 60                 	rts
  1276                          	
  1277                          						;test branches for disassembly purposes..
  1278  09e8 70d7               	bvs amod14
  1279  09ea 7010               	bvs is816
  1280  09ec 7092               	bvs amod13
  1281  09ee 703d               	bvs listamod
  1282  09f0 6260ff             	per amod12
  1283  09f3 620600             	per is816
  1284  09f6 6227ff             	per amod10
  1285  09f9 623100             	per listamod
  1286                          	
  1287                          	!zone is816
  1288                          is816
  1289  09fc 48                 	pha
  1290  09fd 291f               	and #$1f
  1291  09ff c909               	cmp #$09				;09, 29, 49, etc?
  1292  0a01 d006               	bne .testx
  1293  0a03 242d               	bit alarge				;16 bit?
  1294  0a05 3020               	bmi .is16
  1295  0a07 1018               	bpl .is8
  1296                          .testx
  1297  0a09 68                 	pla
  1298  0a0a 48                 	pha
  1299  0a0b c9a0               	cmp #$a0
  1300  0a0d f00e               	beq .isx
  1301  0a0f c9a2               	cmp #$a2
  1302  0a11 f00a               	beq .isx
  1303  0a13 c9c0               	cmp #$c0
  1304  0a15 f006               	beq .isx
  1305  0a17 c9e0               	cmp #$e0
  1306  0a19 f002               	beq .isx
  1307  0a1b 68                 	pla						;made it here, not an accumulator or index instruction
  1308  0a1c 60                 	rts
  1309                          .isx
  1310  0a1d 242e               	bit xlarge
  1311  0a1f 3006               	bmi .is16				;or else fall thru
  1312                          .is8
  1313  0a21 a902               	lda #$2
  1314  0a23 852f               	sta scratch1
  1315  0a25 68                 	pla
  1316  0a26 60                 	rts
  1317                          .is16
  1318  0a27 a903               	lda #$3
  1319  0a29 852f               	sta scratch1
  1320  0a2b 68                 	pla
  1321  0a2c 60                 	rts
  1322                          	
  1323                          listamod
  1324  0a2d 8306               	!16 amod0			;$xx
  1325  0a2f 9606               	!16 amod1			;($xx,X)
  1326  0a31 d106               	!16 amod2			;x,S
  1327  0a33 ee06               	!16 amod3			;[$xx]
  1328  0a35 1407               	!16 amod4			;implied
  1329  0a37 1507               	!16 amod5			;#$xx (or #$yyxx)
  1330  0a39 4007               	!16 amod6			;$yyxx
  1331  0a3b 5807               	!16 amod7			;$zzyyxx
  1332  0a3d 8607               	!16 amod8			;rel8
  1333  0a3f b307               	!16 amod9			;($xx),Y
  1334  0a41 ee07               	!16 amoda			;($xx)
  1335  0a43 1508               	!16 amodb			;(xx,S),Y
  1336  0a45 6408               	!16 amodc			;$xx,X
  1337  0a47 8b08               	!16 amodd			;[$xx],Y
  1338  0a49 c608               	!16 amode			;$yyxx,X
  1339  0a4b f308               	!16 amodf			;$yyxx,Y
  1340  0a4d 2009               	!16 amod10			;$zzyyxx,X
  1341  0a4f 7607               	!16 amod11			;rel16
  1342  0a51 5309               	!16 amod12			;($yyxx)
  1343  0a53 8009               	!16 amod13			;($yyxx,X)
  1344  0a55 c109               	!16 amod14			;$xx,Y
  1345                          	
  1346                          mnemlenmode
  1347  0a57 40                 	!byte %01000000		;00 brk 2/$xx
  1348  0a58 41                 	!byte %01000001		;01 ora 2/($xx,x)
  1349  0a59 40                 	!byte %01000000		;02 cop 2/$xx
  1350  0a5a 42                 	!byte %01000010		;03 ora 2/x,s
  1351  0a5b 40                 	!byte %01000000		;04 tsb 2/$xx
  1352  0a5c 40                 	!byte %01000000		;05 ora 2/$xx
  1353  0a5d 40                 	!byte %01000000		;06 asl 2/$xx
  1354  0a5e 43                 	!byte %01000011		;07 ora 2/[$xx]
  1355  0a5f 24                 	!byte %00100100		;08 php 1
  1356  0a60 45                 	!byte %01000101		;09 ora 2/#imm
  1357  0a61 24                 	!byte %00100100		;0a asl 1
  1358  0a62 24                 	!byte %00100100		;0b phd 1
  1359  0a63 66                 	!byte %01100110		;0c tsb 3/$yyxx
  1360  0a64 66                 	!byte %01100110		;0d ora 3/$yyxx
  1361  0a65 66                 	!byte %01100110		;0e asl 3/$yyxx
  1362  0a66 87                 	!byte %10000111		;0f ora 4/$zzyyxx
  1363  0a67 48                 	!byte %01001000		;10 bpl 2/rel8
  1364  0a68 49                 	!byte %01001001		;11 ora 2/($xx),Y
  1365  0a69 4a                 	!byte %01001010		;12 ora 2/($xx)
  1366  0a6a 4b                 	!byte %01001011		;13 ora 2/(x,s),Y
  1367  0a6b 40                 	!byte %01000000		;14 trb 2/$xx
  1368  0a6c 4c                 	!byte %01001100		;15 ora 2/$xx,X
  1369  0a6d 4c                 	!byte %01001100		;16 asl 2/$xx,X
  1370  0a6e 4d                 	!byte %01001101		;17 ora 2/[$xx],Y
  1371  0a6f 24                 	!byte %00100100		;18 clc 1
  1372  0a70 6f                 	!byte %01101111		;19 ora 3/$yyxx,Y
  1373  0a71 24                 	!byte %00100100		;1a inc 1
  1374  0a72 24                 	!byte %00100100		;1b tcs 1
  1375  0a73 66                 	!byte %01100110		;1c trb 3/$yyxx
  1376  0a74 6e                 	!byte %01101110		;1d ora 3/$yyxx,X
  1377  0a75 6e                 	!byte %01101110		;1e asl 3/$yyxx,X
  1378  0a76 90                 	!byte %10010000		;1f ora 4/$zzyyxx,X
  1379  0a77 66                 	!byte %01100110		;20 jsr 3/$yyxx
  1380  0a78 41                 	!byte %01000001		;21 and 2/($xx,x)
  1381  0a79 87                 	!byte %10000111		;22 jsl 4/$zzyyxx
  1382  0a7a 42                 	!byte %01000010		;23 and 2/x,s
  1383  0a7b 40                 	!byte %01000000		;24 bit 2/$xx
  1384  0a7c 40                 	!byte %01000000		;25 and 2/$xx
  1385  0a7d 40                 	!byte %01000000		;26 rol 2/$xx
  1386  0a7e 43                 	!byte %01000011		;27 and 2/[$xx]
  1387  0a7f 24                 	!byte %00100100		;28 plp 1
  1388  0a80 45                 	!byte %01000101		;29 and 2/#imm
  1389  0a81 24                 	!byte %00100100		;2a rol 1
  1390  0a82 24                 	!byte %00100100		;2b pld 1
  1391  0a83 66                 	!byte %01100110		;2c bit 3/$yyxx
  1392  0a84 66                 	!byte %01100110		;2d and 3/$yyxx
  1393  0a85 66                 	!byte %01100110		;2e rol 3/$yyxx
  1394  0a86 87                 	!byte %10000111		;2f and 4/$zzyyxx
  1395  0a87 48                 	!byte %01001000		;30 bmi 2/rel8
  1396  0a88 49                 	!byte %01001001		;31 and 2/($xx),Y
  1397  0a89 4a                 	!byte %01001010		;32 and 2/($xx)
  1398  0a8a 4b                 	!byte %01001011		;33 and 2/(x,s),Y
  1399  0a8b 4c                 	!byte %01001100		;34 bit 2/$xx,X
  1400  0a8c 4c                 	!byte %01001100		;35 and 2/$xx,X
  1401  0a8d 4c                 	!byte %01001100		;36 rol 2/$xx,X
  1402  0a8e 4d                 	!byte %01001101		;37 and 2/[$xx],Y
  1403  0a8f 24                 	!byte %00100100		;38 sec 1
  1404  0a90 6f                 	!byte %01101111		;39 and 3/$yyxx,Y
  1405  0a91 24                 	!byte %00100100		;3a dec 1
  1406  0a92 24                 	!byte %00100100		;3b tsc 1
  1407  0a93 6e                 	!byte %01101110		;3c bit 3/$yyxx,X
  1408  0a94 6e                 	!byte %01101110		;3d and 3/$yyxx,X
  1409  0a95 6e                 	!byte %01101110		;3e rol 3/$yyxx,X
  1410  0a96 90                 	!byte %10010000		;3f and 4/$zzyyxx,X
  1411  0a97 24                 	!byte %00100100		;40 ???
  1412  0a98 41                 	!byte %01000001		;41 eor 2/($xx,x)
  1413  0a99 40                 	!byte %01000000		;42 wdm 2/$00
  1414  0a9a 42                 	!byte %01000010		;43 eor 2/x,s
  1415  0a9b 24                 	!byte %00100100		;44 ???
  1416  0a9c 40                 	!byte %01000000		;45 eor 2/$xx
  1417  0a9d 40                 	!byte %01000000		;46 lsr 2/$xx
  1418  0a9e 43                 	!byte %01000011		;47 eor 2/[$xx]
  1419  0a9f 24                 	!byte %00100100		;48 pha 1
  1420  0aa0 45                 	!byte %01000101		;49 eor 2/#imm
  1421  0aa1 24                 	!byte %00100100		;4a lsr 1
  1422  0aa2 24                 	!byte %00100100		;4b phk 1
  1423  0aa3 66                 	!byte %01100110		;4c jmp 3/$yyxx
  1424  0aa4 66                 	!byte %01100110		;4d eor 3/$yyxx
  1425  0aa5 66                 	!byte %01100110		;4e lsr 3/$yyxx
  1426  0aa6 87                 	!byte %10000111		;4f eor 4/$zzyyxx
  1427  0aa7 48                 	!byte %01001000		;50 bvc 2/rel8
  1428  0aa8 49                 	!byte %01001001		;51 eor 2/($xx),Y
  1429  0aa9 4a                 	!byte %01001010		;52 eor 2/($xx)
  1430  0aaa 4b                 	!byte %01001011		;53 eor 2/(x,s),Y
  1431  0aab 24                 	!byte %00100100		;54 ???
  1432  0aac 4c                 	!byte %01001100		;55 eor 2/$xx,X
  1433  0aad 4c                 	!byte %01001100		;56 lsr 2/$xx,X
  1434  0aae 4d                 	!byte %01001101		;57 eor 2/[$xx],Y
  1435  0aaf 24                 	!byte %00100100		;58 cli 1
  1436  0ab0 6f                 	!byte %01101111		;59 eor 3/$yyxx,Y
  1437  0ab1 24                 	!byte %00100100		;5a phy 1
  1438  0ab2 24                 	!byte %00100100		;5b tcd 1
  1439  0ab3 87                 	!byte %10000111		;5c jml 4/$zzyyxx
  1440  0ab4 6e                 	!byte %01101110		;5d eor 3/$yyxx,X
  1441  0ab5 6e                 	!byte %01101110		;5e lsr 3/$yyxx,X
  1442  0ab6 90                 	!byte %10010000		;5f eor 4/$zzyyxx,X
  1443  0ab7 24                 	!byte %00100100		;60 rts
  1444  0ab8 41                 	!byte %01000001		;61 adc 2/($xx,x)
  1445  0ab9 71                 	!byte %01110001		;62 per 3/rel16
  1446  0aba 42                 	!byte %01000010		;63 adc 2/x,s
  1447  0abb 40                 	!byte %01000000		;64 stz 2/$xx
  1448  0abc 40                 	!byte %01000000		;65 adc 2/$xx
  1449  0abd 40                 	!byte %01000000		;66 ror 2/$xx
  1450  0abe 43                 	!byte %01000011		;67 adc 2/[$xx]
  1451  0abf 24                 	!byte %00100100		;68 pla 1
  1452  0ac0 45                 	!byte %01000101		;69 adc 2/#imm
  1453  0ac1 24                 	!byte %00100100		;6a ror 1
  1454  0ac2 24                 	!byte %00100100		;6b rtl 1
  1455  0ac3 72                 	!byte %01110010		;6c jmp 3/($yyxx)
  1456  0ac4 66                 	!byte %01100110		;6d adc 3/$yyxx
  1457  0ac5 66                 	!byte %01100110		;6e ror 3/$yyxx
  1458  0ac6 87                 	!byte %10000111		;6f adc 4/$zzyyxx
  1459  0ac7 48                 	!byte %01001000		;70 bvs 2/rel8
  1460  0ac8 49                 	!byte %01001001		;71 adc 2/($xx),Y
  1461  0ac9 4a                 	!byte %01001010		;72 adc 2/($xx)
  1462  0aca 4b                 	!byte %01001011		;73 adc 2/(x,s),Y
  1463  0acb 4c                 	!byte %01001100		;74 stz 2/$xx,X
  1464  0acc 4c                 	!byte %01001100		;75 adc 2/$xx,X
  1465  0acd 4c                 	!byte %01001100		;76 ror 2/$xx,X
  1466  0ace 4d                 	!byte %01001101		;77 adc 2/[$xx],Y
  1467  0acf 24                 	!byte %00100100		;78 sei 1
  1468  0ad0 6f                 	!byte %01101111		;79 adc 3/$yyxx,Y
  1469  0ad1 24                 	!byte %00100100		;7a ply 1
  1470  0ad2 24                 	!byte %00100100		;7b tdc 1
  1471  0ad3 73                 	!byte %01110011		;7c jmp 3/($yyxx,X)
  1472  0ad4 6e                 	!byte %01101110		;7d adc 3/$yyxx,X
  1473  0ad5 6e                 	!byte %01101110		;7e lsr 3/$yyxx,X
  1474  0ad6 90                 	!byte %10010000		;7f adc 4/$zzyyxx,X
  1475  0ad7 48                 	!byte %01001000		;80 bra 2/rel8
  1476  0ad8 41                 	!byte %01000001		;81 sta 2/($xx,x)
  1477  0ad9 71                 	!byte %01110001		;82 brl 3/rel16
  1478  0ada 42                 	!byte %01000010		;83 sta 2/x,s
  1479  0adb 40                 	!byte %01000000		;84 sty 2/$xx
  1480  0adc 40                 	!byte %01000000		;85 sta 2/$xx
  1481  0add 40                 	!byte %01000000		;86 stx 2/$xx
  1482  0ade 43                 	!byte %01000011		;87 sta 2/[$xx]
  1483  0adf 24                 	!byte %00100100		;88 dey 1
  1484  0ae0 45                 	!byte %01000101		;89 bit 2/#imm
  1485  0ae1 24                 	!byte %00100100		;8a txa 1
  1486  0ae2 24                 	!byte %00100100		;8b phb 1
  1487  0ae3 66                 	!byte %01100110		;8c sty 3/$yyxx
  1488  0ae4 66                 	!byte %01100110		;8d sta 3/$yyxx
  1489  0ae5 66                 	!byte %01100110		;8e stx 3/$yyxx
  1490  0ae6 87                 	!byte %10000111		;8f sta 4/$zzyyxx
  1491  0ae7 48                 	!byte %01001000		;90 bcc 2/rel8
  1492  0ae8 49                 	!byte %01001001		;91 sta 2/($xx),Y
  1493  0ae9 4a                 	!byte %01001010		;92 sta 2/($xx)
  1494  0aea 4b                 	!byte %01001011		;93 sta 2/(x,s),Y
  1495  0aeb 4c                 	!byte %01001100		;94 sty 2/$xx,X
  1496  0aec 4c                 	!byte %01001100		;95 sta 2/$xx,X
  1497  0aed 54                 	!byte %01010100		;96 stx 2/$xx,Y
  1498  0aee 4d                 	!byte %01001101		;97 sta 2/[$xx],Y
  1499  0aef 24                 	!byte %00100100		;98 txa 1
  1500  0af0 6f                 	!byte %01101111		;99 sta 3/$yyxx,Y
  1501  0af1 24                 	!byte %00100100		;9a txs 1
  1502  0af2 24                 	!byte %00100100		;9b txy 1
  1503  0af3 66                 	!byte %01100110		;9c stz 3/$yyxx
  1504  0af4 6e                 	!byte %01101110		;9d sta 3/$yyxx,X
  1505  0af5 6e                 	!byte %01101110		;9e stz 3/$yyxx,X
  1506  0af6 90                 	!byte %10010000		;9f sta 4/$zzyyxx,X
  1507  0af7 45                 	!byte %01000101		;a0 ldy 2/#imm
  1508  0af8 41                 	!byte %01000001		;a1 lda 2/($xx,x)
  1509  0af9 45                 	!byte %01000101		;a2 ldx 2/#imm
  1510  0afa 42                 	!byte %01000010		;a3 lda 2/x,s
  1511  0afb 40                 	!byte %01000000		;a4 ldy 2/$xx
  1512  0afc 40                 	!byte %01000000		;a5 sta 2/$xx
  1513  0afd 40                 	!byte %01000000		;a6 ldx 2/$xx
  1514  0afe 43                 	!byte %01000011		;a7 lda 2/[$xx]
  1515  0aff 24                 	!byte %00100100		;a8 tay 1
  1516  0b00 45                 	!byte %01000101		;a9 lda 2/#imm
  1517  0b01 24                 	!byte %00100100		;aa tax 1
  1518  0b02 24                 	!byte %00100100		;ab plb 1
  1519  0b03 66                 	!byte %01100110		;ac ldy 3/$yyxx
  1520  0b04 66                 	!byte %01100110		;ad lda 3/$yyxx
  1521  0b05 66                 	!byte %01100110		;ae ldx 3/$yyxx
  1522  0b06 87                 	!byte %10000111		;af lda 4/$zzyyxx
  1523  0b07 48                 	!byte %01001000		;b0 bcs 2/rel8
  1524  0b08 49                 	!byte %01001001		;b1 lda 2/($xx),Y
  1525  0b09 4a                 	!byte %01001010		;b2 lda 2/($xx)
  1526  0b0a 4b                 	!byte %01001011		;b3 lda 2/(x,s),Y
  1527  0b0b 4c                 	!byte %01001100		;b4 ldy 2/$xx,X
  1528  0b0c 4c                 	!byte %01001100		;b5 lda 2/$xx,X
  1529  0b0d 54                 	!byte %01010100		;b6 ldx 2/$xx,Y
  1530  0b0e 4d                 	!byte %01001101		;b7 lda 2/[$xx],Y
  1531  0b0f 24                 	!byte %00100100		;b8 clv 1
  1532  0b10 6f                 	!byte %01101111		;b9 lda 3/$yyxx,Y
  1533  0b11 24                 	!byte %00100100		;ba tsx 1
  1534  0b12 24                 	!byte %00100100		;bb tyx 1
  1535  0b13 66                 	!byte %01100110		;bc ldy 3/$yyxx
  1536  0b14 6e                 	!byte %01101110		;bd lda 3/$yyxx,X
  1537  0b15 6e                 	!byte %01101110		;be ldx 3/$yyxx,X
  1538  0b16 90                 	!byte %10010000		;bf lda 4/$zzyyxx,X
  1539  0b17 45                 	!byte %01000101		;c0 cpy 2/#imm
  1540  0b18 41                 	!byte %01000001		;c1 cmp 2/($xx,x)
  1541  0b19 45                 	!byte %01000101		;c2 rep 2/#imm
  1542  0b1a 42                 	!byte %01000010		;c3 cmp 2/x,s
  1543  0b1b 40                 	!byte %01000000		;c4 cpx 2/$xx
  1544  0b1c 40                 	!byte %01000000		;c5 cmp 2/$xx
  1545  0b1d 40                 	!byte %01000000		;c6 dec 2/$xx
  1546  0b1e 43                 	!byte %01000011		;c7 cmp 2/[$xx]
  1547  0b1f 24                 	!byte %00100100		;c8 iny 1
  1548  0b20 45                 	!byte %01000101		;c9 cmp 2/#imm
  1549  0b21 24                 	!byte %00100100		;ca dex 1
  1550  0b22 24                 	!byte %00100100		;cb wai 1
  1551  0b23 66                 	!byte %01100110		;cc cpy 3/$yyxx
  1552  0b24 66                 	!byte %01100110		;cd cmp 3/$yyxx
  1553  0b25 66                 	!byte %01100110		;ce dec 3/$yyxx
  1554  0b26 87                 	!byte %10000111		;cf cmp 4/$zzyyxx
  1555  0b27 48                 	!byte %01001000		;d0 bne 2/rel8
  1556  0b28 49                 	!byte %01001001		;d1 cmp 2/($xx),Y
  1557  0b29 4a                 	!byte %01001010		;d2 cmp 2/($xx)
  1558  0b2a 4b                 	!byte %01001011		;d3 cmp 2/(x,s),Y
  1559  0b2b 4a                 	!byte %01001010		;d4 pei 2/($xx)
  1560  0b2c 4c                 	!byte %01001100		;d5 cmp 2/$xx,X
  1561  0b2d 4c                 	!byte %01001100		;d6 dec 2/$xx,X
  1562  0b2e 4d                 	!byte %01001101		;d7 cmp 2/[$xx],Y
  1563  0b2f 24                 	!byte %00100100		;d8 cld 1
  1564  0b30 6f                 	!byte %01101111		;d9 cmp 3/$yyxx,Y
  1565  0b31 24                 	!byte %00100100		;da phx 1
  1566  0b32 24                 	!byte %00100100		;db stp 1
  1567  0b33 43                 	!byte %01000011		;dc jml 2/[$xx]
  1568  0b34 6e                 	!byte %01101110		;dd cmp 3/$yyxx,X
  1569  0b35 6e                 	!byte %01101110		;de dec 3/$yyxx,X
  1570  0b36 90                 	!byte %10010000		;df cmp 4/$zzyyxx,X
  1571  0b37 45                 	!byte %01000101		;e0 cpx 2/#imm
  1572  0b38 41                 	!byte %01000001		;e1 sbc 2/($xx,x)
  1573  0b39 45                 	!byte %01000101		;e2 sep 2/#imm
  1574  0b3a 42                 	!byte %01000010		;e3 sbc 2/x,s
  1575  0b3b 40                 	!byte %01000000		;e4 cpx 2/$xx
  1576  0b3c 40                 	!byte %01000000		;e5 sbc 2/$xx
  1577  0b3d 40                 	!byte %01000000		;e6 inc 2/$xx
  1578  0b3e 43                 	!byte %01000011		;e7 sbc 2/[$xx]
  1579  0b3f 24                 	!byte %00100100		;e8 inx 1
  1580  0b40 45                 	!byte %01000101		;e9 sbc 2/#imm
  1581  0b41 24                 	!byte %00100100		;ea nop 1
  1582  0b42 24                 	!byte %00100100		;eb xba 1
  1583  0b43 66                 	!byte %01100110		;ec cpx 3/$yyxx
  1584  0b44 66                 	!byte %01100110		;ed sbc 3/$yyxx
  1585  0b45 66                 	!byte %01100110		;ee inc 3/$yyxx
  1586  0b46 87                 	!byte %10000111		;ef sbc 4/$zzyyxx
  1587  0b47 48                 	!byte %01001000		;f0 beq 2/rel8
  1588  0b48 49                 	!byte %01001001		;f1 sbc 2/($xx),Y
  1589  0b49 4a                 	!byte %01001010		;f2 sbc 2/($xx)
  1590  0b4a 4b                 	!byte %01001011		;f3 sbc 2/(x,s),Y
  1591  0b4b 66                 	!byte %01100110		;f4 pea 3/$yyxx
  1592  0b4c 4c                 	!byte %01001100		;f5 sbc 2/$xx,X
  1593  0b4d 4c                 	!byte %01001100		;f6 inc 2/$xx,X
  1594  0b4e 4d                 	!byte %01001101		;f7 sbc 2/[$xx],Y
  1595  0b4f 24                 	!byte %00100100		;f8 sed 1
  1596  0b50 6f                 	!byte %01101111		;f9 sbc 3/$yyxx,Y
  1597  0b51 24                 	!byte %00100100		;fa plx 1
  1598  0b52 24                 	!byte %00100100		;fb xce 1
  1599  0b53 73                 	!byte %01110011		;fc jsr 3/($yyxx)
  1600  0b54 6e                 	!byte %01101110		;fd sbc 3/$yyxx,X
  1601  0b55 6e                 	!byte %01101110		;fe inc 3/$yyxx,X
  1602  0b56 90                 	!byte %10010000		;ff sbc 4/$zzyyxx,X
  1603                          mnemlist
  1604  0b57 00                 	!byte $00			;00 brk
  1605  0b58 02                 	!byte $02			;01 ora
  1606  0b59 01                 	!byte $01			;02 cop
  1607  0b5a 02                 	!byte $02			;03 ora
  1608  0b5b 03                 	!byte $03			;04 tsb
  1609  0b5c 02                 	!byte $02			;05 ora
  1610  0b5d 04                 	!byte $04			;06 asl
  1611  0b5e 02                 	!byte $02			;07 ora
  1612  0b5f 05                 	!byte $05			;08 php
  1613  0b60 02                 	!byte $02			;09 ora
  1614  0b61 04                 	!byte $04			;0a asl
  1615  0b62 06                 	!byte $06			;0b phd
  1616  0b63 03                 	!byte $03			;0c tsb
  1617  0b64 02                 	!byte $02			;0d ora
  1618  0b65 04                 	!byte $04			;0e asl
  1619  0b66 02                 	!byte $02			;0f ora
  1620  0b67 07                 	!byte $07			;10 bpl
  1621  0b68 02                 	!byte $02			;11 ora
  1622  0b69 02                 	!byte $02			;12 ora
  1623  0b6a 02                 	!byte $02			;13 ora
  1624  0b6b 08                 	!byte $08			;14 trb
  1625  0b6c 02                 	!byte $02			;15 ora
  1626  0b6d 04                 	!byte $04			;16 asl
  1627  0b6e 02                 	!byte $02			;17 ora
  1628  0b6f 09                 	!byte $09			;18 clc
  1629  0b70 02                 	!byte $02			;19 ora
  1630  0b71 0a                 	!byte $0a			;1a inc
  1631  0b72 0b                 	!byte $0b			;1b tcs
  1632  0b73 08                 	!byte $08			;1c trb
  1633  0b74 02                 	!byte $02			;1d ora
  1634  0b75 04                 	!byte $04			;1e asl
  1635  0b76 02                 	!byte $02			;1f ora
  1636  0b77 0d                 	!byte $0d			;20 jsr
  1637  0b78 0c                 	!byte $0c			;21 and
  1638  0b79 0e                 	!byte $0e			;22 jsl
  1639  0b7a 0c                 	!byte $0c			;23 and
  1640  0b7b 10                 	!byte $10			;24 bit
  1641  0b7c 0c                 	!byte $0c			;25 and
  1642  0b7d 11                 	!byte $11			;26 rol
  1643  0b7e 0c                 	!byte $0c			;27 and
  1644  0b7f 12                 	!byte $12			;28 plp
  1645  0b80 0c                 	!byte $0c			;29 and
  1646  0b81 11                 	!byte $11			;2a rol
  1647  0b82 13                 	!byte $13			;2b pld
  1648  0b83 10                 	!byte $10			;2c bit
  1649  0b84 0c                 	!byte $0c			;2d and
  1650  0b85 11                 	!byte $11			;2e rol
  1651  0b86 0c                 	!byte $0c			;2f and
  1652  0b87 14                 	!byte $14			;30 bmi
  1653  0b88 0c                 	!byte $0c			;31 and
  1654  0b89 0c                 	!byte $0c			;32 and
  1655  0b8a 0c                 	!byte $0c			;33 and
  1656  0b8b 11                 	!byte $11			;34 bit
  1657  0b8c 0c                 	!byte $0c			;35 and
  1658  0b8d 11                 	!byte $11			;36 rol
  1659  0b8e 0c                 	!byte $0c			;37 and
  1660  0b8f 15                 	!byte $15			;38 sec
  1661  0b90 0c                 	!byte $0c			;39 and
  1662  0b91 0f                 	!byte $0f			;3a dec
  1663  0b92 16                 	!byte $16			;3b tsc
  1664  0b93 11                 	!byte $11			;3c bit
  1665  0b94 0c                 	!byte $0c			;3d and
  1666  0b95 11                 	!byte $11			;3e rol
  1667  0b96 0c                 	!byte $0c			;3f and
  1668  0b97 17                 	!byte $17			;40 ???
  1669  0b98 18                 	!byte $18			;41 eor
  1670  0b99 19                 	!byte $19			;42 wdm
  1671  0b9a 18                 	!byte $18			;43 eor
  1672  0b9b 17                 	!byte $17			;44 ???
  1673  0b9c 18                 	!byte $18			;45 eor
  1674  0b9d 1a                 	!byte $1a			;46 lsr
  1675  0b9e 18                 	!byte $18			;47 eor
  1676  0b9f 1b                 	!byte $1b			;48 pha
  1677  0ba0 18                 	!byte $18			;49 eor
  1678  0ba1 1a                 	!byte $1a			;4a lsr
  1679  0ba2 1c                 	!byte $1c			;4b phk
  1680  0ba3 1d                 	!byte $1d			;4c jmp
  1681  0ba4 18                 	!byte $18			;4d eor
  1682  0ba5 1a                 	!byte $1a			;4e lsr
  1683  0ba6 18                 	!byte $18			;4f eor
  1684  0ba7 1e                 	!byte $1e			;50 bvc
  1685  0ba8 18                 	!byte $18			;51 eor
  1686  0ba9 18                 	!byte $18			;52 eor
  1687  0baa 18                 	!byte $18			;53 eor
  1688  0bab 17                 	!byte $17			;54 ???
  1689  0bac 18                 	!byte $18			;55 eor
  1690  0bad 1a                 	!byte $1a			;56 lsr
  1691  0bae 18                 	!byte $18			;57 eor
  1692  0baf 1f                 	!byte $1f			;58 cli
  1693  0bb0 18                 	!byte $18			;59 eor
  1694  0bb1 20                 	!byte $20			;5a phy
  1695  0bb2 21                 	!byte $21			;5b tcd
  1696  0bb3 22                 	!byte $22			;5c jml
  1697  0bb4 18                 	!byte $18			;5d eor
  1698  0bb5 1a                 	!byte $1a			;5e lsr
  1699  0bb6 18                 	!byte $18			;5f eor
  1700  0bb7 23                 	!byte $23			;60 rts
  1701  0bb8 24                 	!byte $24			;61 adc
  1702  0bb9 25                 	!byte $25			;62 per
  1703  0bba 24                 	!byte $24			;63 adc
  1704  0bbb 26                 	!byte $26			;64 stz
  1705  0bbc 24                 	!byte $24			;65 adc
  1706  0bbd 27                 	!byte $27			;66 ror
  1707  0bbe 24                 	!byte $24			;67 adc
  1708  0bbf 28                 	!byte $28			;68 pla
  1709  0bc0 24                 	!byte $24			;69 adc
  1710  0bc1 27                 	!byte $27			;6a ror
  1711  0bc2 29                 	!byte $29			;6b rtl
  1712  0bc3 1d                 	!byte $1d			;6c jmp
  1713  0bc4 24                 	!byte $24			;6d adc
  1714  0bc5 27                 	!byte $27			;6e ror
  1715  0bc6 24                 	!byte $24			;6f adc
  1716  0bc7 2a                 	!byte $2a			;70 bvs
  1717  0bc8 24                 	!byte $24			;71 adc
  1718  0bc9 24                 	!byte $24			;72 adc
  1719  0bca 24                 	!byte $24			;73 adc
  1720  0bcb 26                 	!byte $26			;74 stz
  1721  0bcc 24                 	!byte $24			;75 adc
  1722  0bcd 27                 	!byte $27			;76 ror
  1723  0bce 24                 	!byte $24			;77 adc
  1724  0bcf 2b                 	!byte $2b			;78 sei
  1725  0bd0 24                 	!byte $24			;79 adc
  1726  0bd1 2c                 	!byte $2c			;7a ply
  1727  0bd2 2d                 	!byte $2d			;7b tdc
  1728  0bd3 1d                 	!byte $1d			;7c jmp
  1729  0bd4 24                 	!byte $24			;7d adc
  1730  0bd5 27                 	!byte $27			;7e ror
  1731  0bd6 24                 	!byte $24			;7f adc
  1732  0bd7 2e                 	!byte $2e			;80 bra
  1733  0bd8 2f                 	!byte $2f			;81 sta
  1734  0bd9 30                 	!byte $30			;82 brl
  1735  0bda 2f                 	!byte $2f			;83 sta
  1736  0bdb 31                 	!byte $31			;84 sty
  1737  0bdc 2f                 	!byte $2f			;85 sta
  1738  0bdd 32                 	!byte $32			;86 stx
  1739  0bde 2f                 	!byte $2f			;87 sta
  1740  0bdf 33                 	!byte $33			;88 dey
  1741  0be0 10                 	!byte $10			;89 bit
  1742  0be1 34                 	!byte $34			;8a txa
  1743  0be2 35                 	!byte $35			;8b phb
  1744  0be3 31                 	!byte $31			;8c sty
  1745  0be4 2f                 	!byte $2f			;8d sta
  1746  0be5 32                 	!byte $32			;8e stx
  1747  0be6 2f                 	!byte $2f			;8f sta
  1748  0be7 36                 	!byte $36			;90 bcc
  1749  0be8 2f                 	!byte $2f			;91 sta
  1750  0be9 2f                 	!byte $2f			;92 sta
  1751  0bea 2f                 	!byte $2f			;93 sta
  1752  0beb 31                 	!byte $31			;94 sty
  1753  0bec 2f                 	!byte $2f			;95 sta
  1754  0bed 32                 	!byte $32			;96 stx
  1755  0bee 2f                 	!byte $2f			;97 sta
  1756  0bef 37                 	!byte $37			;98 tya
  1757  0bf0 2f                 	!byte $2f			;99 sta
  1758  0bf1 38                 	!byte $38			;9a txs
  1759  0bf2 39                 	!byte $39			;9b txy
  1760  0bf3 26                 	!byte $26			;9c stz
  1761  0bf4 2f                 	!byte $2f			;9d sta
  1762  0bf5 26                 	!byte $26			;9e stz
  1763  0bf6 2f                 	!byte $2f			;9f sta
  1764  0bf7 3c                 	!byte $3c			;a0 ldy
  1765  0bf8 3a                 	!byte $3a			;a1 lda
  1766  0bf9 3b                 	!byte $3b			;a2 ldx
  1767  0bfa 3a                 	!byte $3a			;a3 lda
  1768  0bfb 3c                 	!byte $3c			;a4 ldy
  1769  0bfc 3a                 	!byte $3a			;a5 lda
  1770  0bfd 3b                 	!byte $3b			;a6 ldx
  1771  0bfe 3a                 	!byte $3a			;a7 lda
  1772  0bff 3d                 	!byte $3d			;a8 tay
  1773  0c00 3a                 	!byte $3a			;a9 lda
  1774  0c01 3e                 	!byte $3e			;aa tax
  1775  0c02 3f                 	!byte $3f			;ab plb
  1776  0c03 3c                 	!byte $3c			;ac ldy
  1777  0c04 3a                 	!byte $3a			;ad lda
  1778  0c05 3b                 	!byte $3b			;ae ldx
  1779  0c06 3a                 	!byte $3a			;af lda
  1780  0c07 40                 	!byte $40			;b0 bcs
  1781  0c08 3a                 	!byte $3a			;b1 lda
  1782  0c09 3a                 	!byte $3a			;b2 lda
  1783  0c0a 3a                 	!byte $3a			;b3 lda
  1784  0c0b 3c                 	!byte $3c			;b4 ldy
  1785  0c0c 3a                 	!byte $3a			;b5 lda
  1786  0c0d 3b                 	!byte $3b			;b6 ldx
  1787  0c0e 3a                 	!byte $3a			;b7 lda
  1788  0c0f 41                 	!byte $41			;b8 clv
  1789  0c10 3a                 	!byte $3a			;b9 lda
  1790  0c11 42                 	!byte $42			;ba tsx
  1791  0c12 43                 	!byte $43			;bb tyx
  1792  0c13 3c                 	!byte $3c			;bc ldy
  1793  0c14 3a                 	!byte $3a			;bd lda
  1794  0c15 3b                 	!byte $3b			;be ldx
  1795  0c16 3a                 	!byte $3a			;bf lda
  1796  0c17 46                 	!byte $46			;c0 cpy
  1797  0c18 44                 	!byte $44			;c1 cmp
  1798  0c19 47                 	!byte $47			;c2 rep
  1799  0c1a 44                 	!byte $44			;c3 cmp
  1800  0c1b 46                 	!byte $46			;c4 cpy
  1801  0c1c 44                 	!byte $44			;c5 cmp
  1802  0c1d 48                 	!byte $48			;c6 dec
  1803  0c1e 44                 	!byte $44			;c7 cmp
  1804  0c1f 49                 	!byte $49			;c8 iny
  1805  0c20 44                 	!byte $44			;c9 cmp
  1806  0c21 4a                 	!byte $4a			;ca dex
  1807  0c22 4b                 	!byte $4b			;cb wai
  1808  0c23 46                 	!byte $46			;cc cpy
  1809  0c24 44                 	!byte $44			;cd cmp
  1810  0c25 48                 	!byte $48			;ce dec
  1811  0c26 44                 	!byte $44			;cf cmp
  1812  0c27 4c                 	!byte $4c			;d0 bne
  1813  0c28 44                 	!byte $44			;d1 cmp
  1814  0c29 44                 	!byte $44			;d2 cmp
  1815  0c2a 44                 	!byte $44			;d3 cmp
  1816  0c2b 4d                 	!byte $4d			;d4 pei
  1817  0c2c 44                 	!byte $44			;d5 cmp
  1818  0c2d 48                 	!byte $48			;d6 dec
  1819  0c2e 44                 	!byte $44			;d7 cmp
  1820  0c2f 4e                 	!byte $4e			;d8 cld
  1821  0c30 44                 	!byte $44			;d9 cmp
  1822  0c31 4f                 	!byte $4f			;da phx
  1823  0c32 50                 	!byte $50			;db stp
  1824  0c33 22                 	!byte $22			;dc jml
  1825  0c34 44                 	!byte $44			;dd cmp
  1826  0c35 48                 	!byte $48			;de dec
  1827  0c36 44                 	!byte $44			;df cmp
  1828  0c37 51                 	!byte $51			;e0 cpx
  1829  0c38 45                 	!byte $45			;e1 sbc
  1830  0c39 52                 	!byte $52			;e2 sep
  1831  0c3a 45                 	!byte $45			;e3 sbc
  1832  0c3b 51                 	!byte $51			;e4 cpx
  1833  0c3c 45                 	!byte $45			;e5 sbc
  1834  0c3d 53                 	!byte $53			;e6 inc
  1835  0c3e 45                 	!byte $45			;e7 sbc
  1836  0c3f 54                 	!byte $54			;e8 inx
  1837  0c40 45                 	!byte $45			;e9 sbc
  1838  0c41 55                 	!byte $55			;ea nop
  1839  0c42 56                 	!byte $56			;eb xba
  1840  0c43 51                 	!byte $51			;ec cpx
  1841  0c44 45                 	!byte $45			;ed sbc
  1842  0c45 53                 	!byte $53			;ee inc
  1843  0c46 45                 	!byte $45			;ef sbc
  1844  0c47 57                 	!byte $57			;f0 beq
  1845  0c48 45                 	!byte $45			;f1 sbc
  1846  0c49 45                 	!byte $45			;f2 sbc
  1847  0c4a 45                 	!byte $45			;f3 sbc
  1848  0c4b 58                 	!byte $58			;f4 pea
  1849  0c4c 45                 	!byte $45			;f5 sbc
  1850  0c4d 53                 	!byte $53			;f6 inc
  1851  0c4e 45                 	!byte $45			;f7 sbc
  1852  0c4f 59                 	!byte $59			;f8 sed
  1853  0c50 45                 	!byte $45			;f9 sbc
  1854  0c51 5a                 	!byte $5a			;fa plx
  1855  0c52 5b                 	!byte $5b			;fb xce
  1856  0c53 0d                 	!byte $0d			;fc jsr
  1857  0c54 45                 	!byte $45			;fd sbc
  1858  0c55 53                 	!byte $53			;fe inc
  1859  0c56 45                 	!byte $45			;ff sbc
  1860                          mnems
  1861  0c57 42524b             	!tx "BRK"			;0
  1862  0c5a 434f50             	!tx "COP"			;1
  1863  0c5d 4f5241             	!tx "ORA"			;2
  1864  0c60 545342             	!tx "TSB"			;3
  1865  0c63 41534c             	!tx "ASL"			;4
  1866  0c66 504850             	!tx "PHP"			;5
  1867  0c69 504844             	!tx "PHD"			;6
  1868  0c6c 42504c             	!tx "BPL"			;7
  1869  0c6f 545242             	!tx "TRB"			;8
  1870  0c72 434c43             	!tx "CLC"			;9
  1871  0c75 494e43             	!tx "INC"			;a
  1872  0c78 544353             	!tx "TCS"			;b
  1873  0c7b 414e44             	!tx "AND"			;c
  1874  0c7e 4a5352             	!tx "JSR"			;d
  1875  0c81 4a534c             	!tx "JSL"			;e
  1876  0c84 444543             	!tx "DEC"			;f
  1877  0c87 424954             	!tx "BIT"			;10
  1878  0c8a 524f4c             	!tx "ROL"			;11
  1879  0c8d 504c50             	!tx "PLP"			;12
  1880  0c90 504c44             	!tx "PLD"			;13
  1881  0c93 424d49             	!tx "BMI"			;14
  1882  0c96 534543             	!tx "SEC"			;15
  1883  0c99 545343             	!tx "TSC"			;16
  1884  0c9c 3f3f3f             	!tx "???"			;17
  1885  0c9f 454f52             	!tx "EOR"			;18
  1886  0ca2 57444d             	!tx "WDM"			;19
  1887  0ca5 4c5352             	!tx "LSR"			;1a
  1888  0ca8 504841             	!tx "PHA"			;1b
  1889  0cab 50484b             	!tx "PHK"			;1c
  1890  0cae 4a4d50             	!tx "JMP"			;1d
  1891  0cb1 425643             	!tx "BVC"			;1e
  1892  0cb4 434c49             	!tx "CLI"			;1f
  1893  0cb7 504859             	!tx "PHY"			;20
  1894  0cba 544344             	!tx "TCD"			;21
  1895  0cbd 4a4d4c             	!tx "JML"			;22
  1896  0cc0 525453             	!tx "RTS"			;23
  1897  0cc3 414443             	!tx "ADC"			;24
  1898  0cc6 504552             	!tx "PER"			;25
  1899  0cc9 53545a             	!tx "STZ"			;26
  1900  0ccc 524f52             	!tx "ROR"			;27
  1901  0ccf 504c41             	!tx "PLA"			;28
  1902  0cd2 52544c             	!tx "RTL"			;29
  1903  0cd5 425653             	!tx "BVS"			;2a
  1904  0cd8 534549             	!tx "SEI"			;2b
  1905  0cdb 504c59             	!tx "PLY"			;2c
  1906  0cde 544443             	!tx "TDC"			;2d
  1907  0ce1 425241             	!tx "BRA"			;2e
  1908  0ce4 535441             	!tx "STA"			;2f
  1909  0ce7 42524c             	!tx "BRL"			;30
  1910  0cea 535459             	!tx "STY"			;31
  1911  0ced 535458             	!tx "STX"			;32
  1912  0cf0 444559             	!tx "DEY"			;33
  1913  0cf3 545841             	!tx "TXA"			;34
  1914  0cf6 504842             	!tx "PHB"			;35
  1915  0cf9 424343             	!tx "BCC"			;36
  1916  0cfc 545941             	!tx "TYA"			;37
  1917  0cff 545853             	!tx "TXS"			;38
  1918  0d02 545859             	!tx "TXY"			;39
  1919  0d05 4c4441             	!tx "LDA"			;3a
  1920  0d08 4c4458             	!tx "LDX"			;3b
  1921  0d0b 4c4459             	!tx "LDY"			;3c
  1922  0d0e 544159             	!tx "TAY"			;3d
  1923  0d11 544158             	!tx "TAX"			;3e
  1924  0d14 504c42             	!tx "PLB"			;3f
  1925  0d17 424353             	!tx "BCS"			;40
  1926  0d1a 434c56             	!tx "CLV"			;41
  1927  0d1d 545358             	!tx "TSX"			;42
  1928  0d20 545958             	!tx "TYX"			;43
  1929  0d23 434d50             	!tx "CMP"			;44
  1930  0d26 534243             	!tx "SBC"			;45
  1931  0d29 435059             	!tx "CPY"			;46
  1932  0d2c 524550             	!tx "REP"			;47
  1933  0d2f 444543             	!tx "DEC"			;48
  1934  0d32 494e59             	!tx "INY"			;49
  1935  0d35 444558             	!tx "DEX"			;4a
  1936  0d38 574149             	!tx "WAI"			;4b
  1937  0d3b 424e45             	!tx "BNE"			;4c
  1938  0d3e 504549             	!tx "PEI"			;4d
  1939  0d41 434c44             	!tx "CLD"			;4e
  1940  0d44 504858             	!tx "PHX"			;4f
  1941  0d47 535450             	!tx "STP"			;50
  1942  0d4a 435058             	!tx "CPX"			;51
  1943  0d4d 534550             	!tx "SEP"			;52
  1944  0d50 494e43             	!tx "INC"			;53
  1945  0d53 494e58             	!tx "INX"			;54
  1946  0d56 4e4f50             	!tx "NOP"			;55
  1947  0d59 584241             	!tx "XBA"			;56
  1948  0d5c 424551             	!tx "BEQ"			;57
  1949  0d5f 504541             	!tx "PEA"			;58
  1950  0d62 534544             	!tx "SED"			;59
  1951  0d65 504c58             	!tx "PLX"			;5a
  1952  0d68 584345             	!tx "XCE"			;5b
  1953                          	
  1954                          	!zone ucline
  1955                          ucline					;convert inbuff at $170400 to upper case
  1956  0d6b 08                 	php
  1957  0d6c c210               	rep #$10
  1958  0d6e e220               	sep #$20
  1959                          	!as
  1960                          	!rl
  1961  0d70 a20000             	ldx #$0000
  1962                          .local2
  1963  0d73 bf000417           	lda inbuff,x
  1964  0d77 f012               	beq .local4			;hit the zero, so bail
  1965  0d79 c961               	cmp #'a'
  1966  0d7b 900b               	bcc .local3			;less then lowercase a, so ignore
  1967  0d7d c97b               	cmp #'z' + 1		;less than next character after lowercase z?
  1968  0d7f b007               	bcs .local3			;greater than or equal, so ignore
  1969  0d81 38                 	sec
  1970  0d82 e920               	sbc #('z' - 'Z')	;make upper case
  1971  0d84 9f000417           	sta inbuff,x
  1972                          .local3
  1973  0d88 e8                 	inx
  1974  0d89 80e8               	bra .local2
  1975                          .local4
  1976  0d8b 28                 	plp
  1977  0d8c 6b                 	rtl
  1978                          	
  1979                          	!zone getline
  1980                          getline
  1981  0d8d 08                 	php
  1982  0d8e c210               	rep #$10
  1983  0d90 e220               	sep #$20
  1984                          	!as
  1985                          	!rl
  1986  0d92 a20000             	ldx #$0000
  1987                          .local2
  1988  0d95 af00fc1b           	lda IO_KEYQ_SIZE
  1989  0d99 f0fa               	beq .local2
  1990  0d9b af01fc1b           	lda IO_KEYQ_WAITING
  1991  0d9f 8f02fc1b           	sta IO_KEYQ_DEQUEUE
  1992  0da3 c90d               	cmp #$0d			;carriage return yet?
  1993  0da5 f01c               	beq .local3
  1994  0da7 c908               	cmp #$08			;backspace/back arrow?
  1995  0da9 f029               	beq .local4
  1996  0dab c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
  1997  0dad 90e6               	bcc .local2		 		;yes, so ignore it
  1998  0daf 9f000417           	sta inbuff,x 		;any other character, so register it and store it
  1999  0db3 8f12fc1b           	sta IO_CON_CHAROUT
  2000  0db7 8f13fc1b           	sta IO_CON_REGISTER
  2001  0dbb e8                 	inx
  2002  0dbc a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
  2003  0dbe e0fe03             	cpx #$3fe			;overrun end of buffer yet?
  2004  0dc1 d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
  2005                          .local3
  2006  0dc3 9f000417           	sta inbuff,x		;store CR
  2007  0dc7 8f17fc1b           	sta IO_CON_CR
  2008  0dcb e8                 	inx
  2009  0dcc a900               	lda #$00			;store zero to end it all
  2010  0dce 9f000417           	sta inbuff,x
  2011  0dd2 28                 	plp
  2012  0dd3 6b                 	rtl
  2013                          .local4
  2014  0dd4 e00000             	cpx #$0000
  2015  0dd7 f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
  2016  0dd9 a908               	lda #$08
  2017  0ddb 8f12fc1b           	sta IO_CON_CHAROUT
  2018  0ddf 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
  2019  0de3 a920               	lda #$20
  2020  0de5 8f12fc1b           	sta IO_CON_CHAROUT
  2021  0de9 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
  2022  0ded a908               	lda #$08
  2023  0def 8f12fc1b           	sta IO_CON_CHAROUT
  2024  0df3 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
  2025  0df7 ca                 	dex
  2026  0df8 809b               	bra .local2
  2027                          	
  2028                          prinbuff				;feed location of input buffer into dpla and then print
  2029  0dfa 08                 	php
  2030  0dfb c210               	rep #$10
  2031  0dfd e220               	sep #$20
  2032                          	!as
  2033                          	!rl
  2034  0dff a917               	lda #$17
  2035  0e01 853f               	sta dpla_h
  2036  0e03 a904               	lda #$04
  2037  0e05 853e               	sta dpla_m
  2038  0e07 643d               	stz dpla
  2039  0e09 220f0e1c           	jsl l_prcdpla
  2040  0e0d 28                 	plp
  2041  0e0e 6b                 	rtl
  2042                          	
  2043                          	!zone prcdpla
  2044                          prcdpla					; print C string pointed to by dp locations $3d-$3f
  2045  0e0f 08                 	php
  2046  0e10 c210               	rep #$10
  2047  0e12 e220               	sep #$20
  2048                          	!as
  2049                          	!rl
  2050  0e14 a00000             	ldy #$0000
  2051                          .local2
  2052  0e17 b73d               	lda [dpla],y
  2053  0e19 f00b               	beq .local3
  2054  0e1b 8f12fc1b           	sta IO_CON_CHAROUT
  2055  0e1f 8f13fc1b           	sta IO_CON_REGISTER
  2056  0e23 c8                 	iny
  2057  0e24 80f1               	bra .local2
  2058                          .local3
  2059  0e26 28                 	plp
  2060  0e27 6b                 	rtl
  2061                          
  2062                          initstring
  2063  0e28 494d4c2036353831...	!tx "IML 65816 1C Firmware v00"
  2064  0e41 0d                 	!byte 0x0d
  2065  0e42 53797374656d204d...	!tx "System Monitor"
  2066  0e50 0d                 	!byte 0x0d
  2067  0e51 0d                 	!byte 0x0d
  2068  0e52 00                 	!byte 0
  2069                          
  2070                          helpmsg
  2071  0e53 494d4c2036353831...	!tx "IML 65816 Monitor Commands"
  2072  0e6d 0d                 	!byte $0d
  2073  0e6e 41203c616464723e...	!tx "A <addr>  Dump ASCII"
  2074  0e82 0d                 	!byte $0d
  2075  0e83 42203c62616e6b3e...	!tx "B <bank>  Change bank"
  2076  0e98 0d                 	!byte $0d
  2077  0e99 43203c636f6c6f72...	!tx "C <color> Change terminal colors"
  2078  0eb9 0d                 	!byte $0d
  2079  0eba 44203c616464723e...	!tx "D <addr>  Dump hex"
  2080  0ecc 0d                 	!byte $0d
  2081  0ecd 45203c616464723e...	!tx "E <addr> <byte> <byte>...  Enter bytes"
  2082  0ef3 0d                 	!byte $0d
  2083  0ef4 463f202020202020...	!tx "F?        Floating Point Support Help"
  2084  0f19 0d                 	!byte $0d
  2085  0f1a 4c203c616464723e...	!tx "L <addr>  Disassemble 65816 Inst."
  2086  0f3b 0d                 	!byte $0d
  2087  0f3c 4d203c6d6f64653e...	!tx "M <mode>  Change video mode, 8/9"
  2088  0f5c 0d                 	!byte $0d
  2089  0f5d 5120202020202020...	!tx "Q         Halt the processor"
  2090  0f79 0d                 	!byte $0d
  2091  0f7a 3f20202020202020...	!tx "?         This menu"
  2092  0f8d 0d                 	!byte $0d
  2093  0f8e 3c656e7465723e20...	!tx "<enter>   Repeat last dump command"
  2094  0fb0 0d                 	!byte $0d
  2095  0fb1 546f207370656369...	!tx "To specify range, use <addr1.addr2>"
  2096  0fd4 0d00               	!byte $0d, 00
  2097                          
  2098                          fphelpmsg
  2099  0fd6 494d4c20466c6f61...	!tx "IML Floating Point Support"
  2100  0ff0 0d                 	!byte $0d
  2101  0ff1 466f726d61743a20...	!tx "Format: F<cmd><sz><reg>"
  2102  1008 0d                 	!byte $0d
  2103  1009 53697a65733a2046...	!tx "Sizes: F=float D=double E=extended"
  2104  102b 0d                 	!byte $0d
  2105  102c 5265676973746572...	!tx "Registers: A=FACC B=FARG"
  2106  1044 0d                 	!byte $0d
  2107  1045 46443c737a3e2020...	!tx "FD<sz>    Display FACC/FARG"
  2108  1060 0d                 	!byte $0d
  2109  1061 46433c737a3e3c72...	!tx "FC<sz><reg> <constID> Load Constant"
  2110  1084 0d                 	!byte $0d
  2111  1085 463c6f703e3c737a...	!tx "F<op><sz><reg> Bin Op, result in <reg>"
  2112  10ab 0d                 	!byte $0d
  2113  10ac 42696e617279204f...	!tx "Binary Ops: *, /, +, -"
  2114  10c2 0d                 	!tx $0d
  2115  10c3 00                 	!byte $00
  2116                          	
  2117  10c4 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
  2118                          

; ******** done
