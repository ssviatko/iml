
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
    29                          
    30                          FPCOND = 0x1bfcbf
    31                          FPASCII = 0x1bfcc0
    32                          FPASCII_LO16 = 0xfcc0
    33                          FPACCUMULATOR = 0x1bfce0
    34                          FPARGUMENT = 0x1bfcf0
    35                          
    36                          promptchar = '*'
    37                          
    38                          l_getline = $1c0000 + getline
    39                          l_prinbuff = $1c0000 + prinbuff
    40                          l_prcdpla = $1c0000 + prcdpla
    41                          l_ucline = $1c0000 + ucline
    42                          
    43                          fpregspec = $28
    44                          fpmask = $29
    45                          scratch2 = $2a
    46                          scratch2_m = $2b
    47                          scratch2_h = $2c
    48                          alarge = $2d
    49                          xlarge = $2e
    50                          scratch1 = $2f
    51                          enterbytes = $30
    52                          enterbytes_m = $31
    53                          enterbytes_h = $32
    54                          rangehigh = $33
    55                          monrange = $35
    56                          monlast = $36
    57                          parseptr = $37
    58                          parseptr_m = $38
    59                          parseptr_h = $39
    60                          mondump = $3a
    61                          mondump_m = $3b
    62                          mondump_h = $3c
    63                          dpla = $3d
    64                          dpla_m = $3e
    65                          dpla_h = $3f
    66                          
    67                          inbuff = $170400
    68                          
    69                          x1crominit
    70  0000 4b                 	phk
    71  0001 ab                 	plb
    72  0002 c210               	rep #$10
    73                          	!rl
    74  0004 e220               	sep #$20
    75                          	!as
    76  0006 a24d0e             	ldx #initstring
    77  0009 863d               	stx dpla
    78  000b a91c               	lda #$1c
    79  000d 853f               	sta dpla_h
    80  000f 22340e1c           	jsl l_prcdpla
    81  0013 4c6a03             	jmp+2 monstart
    82                          
    83                          parse_setup
    84  0016 a20004             	ldx #$0400
    85  0019 8637               	stx parseptr
    86  001b a917               	lda #$17
    87  001d 8539               	sta parseptr_h
    88  001f 60                 	rts
    89                          	
    90                          	!zone parse_getchar
    91                          parse_getchar			;get char from inbuff, assumes 8 bit A, 16 bit X
    92  0020 a737               	lda [parseptr]
    93  0022 48                 	pha
    94  0023 e637               	inc parseptr
    95  0025 d006               	bne .local2
    96  0027 e638               	inc parseptr_m
    97  0029 d002               	bne .local2
    98  002b e639               	inc parseptr_h
    99                          .local2
   100  002d 68                 	pla
   101  002e 60                 	rts
   102                          	
   103                          	!zone parse_addr
   104                          parse_addr				;see if user specified an address on line.
   105  002f a900               	lda #$00
   106  0031 48                 	pha
   107  0032 48                 	pha					;make space for working value on the stack
   108  0033 8535               	sta monrange		;clear range flag
   109                          .throwaway
   110  0035 202000             	jsr+2 parse_getchar
   111  0038 c920               	cmp #' '
   112  003a f0f9               	beq .throwaway		;throw away leading spaces
   113  003c 209800             	jsr+2 parse_getnib2	;get first nibble. call 2nd entry point since we already have character
   114  003f 9051               	bcc .no				;didn't even get one hex character, so return false
   115  0041 8301               	sta 1,s				;save it on the stack for now
   116  0043 209500             	jsr+2 parse_getnib	;get second nibble
   117  0046 9047               	bcc .yes			;if not hex then bail
   118  0048 48                 	pha
   119  0049 a302               	lda 2,s
   120  004b 0a                 	asl
   121  004c 0a                 	asl
   122  004d 0a                 	asl
   123  004e 0a                 	asl
   124  004f 0301               	ora 1,s
   125  0051 8302               	sta 2,s
   126  0053 68                 	pla					;add to stack
   127  0054 209500             	jsr+2 parse_getnib	;get possible third nibble
   128  0057 9036               	bcc .yes
   129  0059 c230               	rep #$30			;we're dealing with a 16 bit value now
   130                          	!al
   131  005b 290f00             	and #$000f
   132  005e 48                 	pha
   133  005f a303               	lda 3,s
   134  0061 0a                 	asl
   135  0062 0a                 	asl
   136  0063 0a                 	asl
   137  0064 0a                 	asl
   138  0065 0301               	ora 1,s
   139  0067 8303               	sta 3,s
   140  0069 68                 	pla
   141  006a e220               	sep #$20
   142                          	!as
   143  006c 209500             	jsr+2 parse_getnib
   144  006f 901e               	bcc .yes
   145  0071 c230               	rep #$30
   146                          	!al
   147  0073 290f00             	and #$000f
   148  0076 48                 	pha
   149  0077 a303               	lda 3,s
   150  0079 0a                 	asl
   151  007a 0a                 	asl
   152  007b 0a                 	asl
   153  007c 0a                 	asl
   154  007d 0301               	ora 1,s
   155  007f 8303               	sta 3,s
   156  0081 68                 	pla
   157  0082 e220               	sep #$20			;fall thru to yes on 4th nibble
   158                          	!as
   159  0084 202000             	jsr parse_getchar	;check to see if next char is a . so we can specify ranges
   160  0087 c92e               	cmp #'.'
   161  0089 d004               	bne .yes
   162  008b a980               	lda #$80
   163  008d 8535               	sta monrange
   164                          .yes
   165  008f 7a                 	ply					;get 16 bit work address off of stack
   166  0090 38                 	sec					;got address, return
   167  0091 60                 	rts
   168                          .no
   169  0092 7a                 	ply					;clear stack
   170  0093 18                 	clc					;no address found, return
   171  0094 60                 	rts
   172                          parse_getnib
   173  0095 202000             	jsr parse_getchar
   174                          parse_getnib2			;enter here after we've thrown away leading spaces
   175  0098 c920               	cmp #' '
   176  009a f021               	beq .outrng			;space = end of value
   177  009c c92e               	cmp #'.'
   178  009e d006               	bne .notrange
   179  00a0 a980               	lda #$80
   180  00a2 8535               	sta monrange		;this is the start of a range specification
   181  00a4 18                 	clc
   182  00a5 60                 	rts
   183                          .notrange
   184  00a6 c941               	cmp #$41
   185  00a8 900b               	bcc .outrnga
   186  00aa c947               	cmp #$47
   187  00ac b007               	bcs .outrnga
   188  00ae 38                 	sec
   189  00af e907               	sbc #$07			;in range of A-F
   190                          .success
   191  00b1 290f               	and #$0f
   192  00b3 38                 	sec
   193  00b4 60                 	rts
   194                          .outrnga				;test if 0-9
   195  00b5 c930               	cmp #$30
   196  00b7 9004               	bcc .outrng
   197  00b9 c93a               	cmp #$3a
   198  00bb 90f4               	bcc .success		;less than 3a, but >= 30, else fall thru to outrng
   199                          .outrng
   200  00bd 18                 	clc
   201  00be 60                 	rts
   202                          	
   203                          prdumpaddr
   204  00bf a53c               	lda mondump_h			;print long address
   205  00c1 206b05             	jsr+2 prhex
   206  00c4 a92f               	lda #'/'
   207  00c6 8f12fc1b           	sta IO_CON_CHAROUT
   208  00ca 8f13fc1b           	sta IO_CON_REGISTER
   209  00ce a63a               	ldx mondump
   210  00d0 206105             	jsr+2 prhex16
   211  00d3 a92d               	lda #'-'
   212  00d5 8f12fc1b           	sta IO_CON_CHAROUT
   213  00d9 8f13fc1b           	sta IO_CON_REGISTER
   214  00dd a920               	lda #' '
   215  00df 8f12fc1b           	sta IO_CON_CHAROUT
   216  00e3 8f13fc1b           	sta IO_CON_REGISTER
   217  00e7 60                 	rts
   218                          	
   219                          adjdumpaddr					;add 8 to dump address
   220  00e8 c230               	rep #$30
   221                          	!al
   222  00ea a53a               	lda mondump
   223  00ec 18                 	clc
   224  00ed 690800             	adc #$0008
   225  00f0 853a               	sta mondump
   226  00f2 e220               	sep #$20
   227                          	!as
   228  00f4 08                 	php						;save carry state.. did we carry to the bank?
   229  00f5 a53c               	lda mondump_h
   230  00f7 6900               	adc #$00
   231  00f9 853c               	sta mondump_h
   232  00fb 28                 	plp
   233  00fc 60                 	rts
   234                          
   235                          	!zone fpcmd
   236                          fphelp
   237  00fd a2fb0f             	ldx #fphelpmsg
   238  0100 863d               	stx dpla
   239  0102 a91c               	lda #$1c
   240  0104 853f               	sta dpla_h
   241  0106 22340e1c           	jsl l_prcdpla
   242  010a 4c7d03             	jmp moncmd
   243                          fpcmd
   244  010d 202000             	jsr parse_getchar
   245  0110 c93f               	cmp #'?'
   246  0112 f0e9               	beq fphelp
   247  0114 c944               	cmp #'D'
   248  0116 d003               	bne .fpcmd1
   249  0118 4c2a02             	jmp fpdisp
   250                          .fpcmd1
   251  011b c943               	cmp #'C'
   252  011d d003               	bne .fpcmd2
   253  011f 4c0502             	jmp fploadconst
   254                          .fpcmd2
   255  0122 c92a               	cmp #'*'
   256  0124 f073               	beq fpmultiply
   257  0126 c92f               	cmp #'/'
   258  0128 d003               	bne .fpcmd5
   259  012a 4cb401             	jmp fpdivide
   260                          .fpcmd5
   261  012d c92b               	cmp #'+'
   262  012f d003               	bne .fpcmd4
   263  0131 4ccf01             	jmp fpadd
   264                          .fpcmd4
   265  0134 c92d               	cmp #'-'
   266  0136 d003               	bne .fpcmd3
   267  0138 4cea01             	jmp fpsubtract
   268                          .fpcmd3
   269  013b c94e               	cmp #'N'
   270  013d f03f               	beq fpln
   271  013f 4c1503             	jmp monerror			;unrecognized FP command so fall thru to syntax error
   272                          
   273                          fpgetmask					;construct mask from size specifier, carry set if unregognized
   274  0142 202000             	jsr parse_getchar
   275  0145 c946               	cmp #'F'
   276  0147 d006               	bne .local1
   277  0149 a900               	lda #$00
   278  014b 8529               	sta fpmask				;set bits 5/7 of fp mask to 0
   279  014d 8016               	bra .local4
   280                          .local1
   281  014f c944               	cmp #'D'
   282  0151 d006               	bne .local2
   283  0153 a980               	lda #$80				;bit 7=1, bit 5=0
   284  0155 8529               	sta fpmask
   285  0157 800c               	bra .local4
   286                          .local2
   287  0159 c945               	cmp #'E'
   288  015b d006               	bne .local3
   289  015d a920               	lda #$20				;bit 7=0, bit 5=1
   290  015f 8529               	sta fpmask
   291  0161 8002               	bra .local4
   292                          .local3
   293  0163 38                 	sec						;unknown size
   294  0164 60                 	rts
   295                          .local4
   296  0165 18                 	clc
   297  0166 60                 	rts
   298                          	
   299                          fpgetregspec
   300  0167 202000             	jsr parse_getchar		;set fpregspec to 00 or 40 depending on register specified
   301  016a c941               	cmp #'A'
   302  016c d004               	bne .localgrs1
   303  016e 6428               	stz fpregspec
   304  0170 8008               	bra .localgrs3
   305                          .localgrs1
   306  0172 c942               	cmp #'B'
   307  0174 d006               	bne .localgrs4
   308  0176 a940               	lda #$40
   309  0178 8528               	sta fpregspec
   310                          .localgrs3
   311  017a 18                 	clc
   312  017b 60                 	rts
   313                          .localgrs4
   314  017c 38                 	sec
   315  017d 60                 	rts
   316                          
   317                          fpln
   318  017e 204201             	jsr fpgetmask
   319  0181 9003               	bcc .fpln1
   320  0183 4c1503             	jmp monerror
   321                          .fpln1
   322  0186 206701             	jsr fpgetregspec
   323  0189 9003               	bcc .fpln2
   324  018b 4c1503             	jmp monerror
   325                          .fpln2
   326  018e a529               	lda fpmask
   327  0190 0528               	ora fpregspec
   328  0192 8f46fc1b           	sta IO_FP_LN
   329  0196 4c7d03             	jmp moncmd
   330                          	
   331                          fpmultiply
   332  0199 204201             	jsr fpgetmask
   333  019c 9003               	bcc .fpmultiply1
   334  019e 4c1503             	jmp monerror
   335                          .fpmultiply1
   336  01a1 206701             	jsr fpgetregspec
   337  01a4 9003               	bcc .fpmultiply2
   338  01a6 4c1503             	jmp monerror
   339                          .fpmultiply2
   340  01a9 a529               	lda fpmask
   341  01ab 0528               	ora fpregspec
   342  01ad 8f42fc1b           	sta IO_FP_MULTIPLY
   343  01b1 4c7d03             	jmp moncmd
   344                          	
   345                          fpdivide
   346  01b4 204201             	jsr fpgetmask
   347  01b7 9003               	bcc .fpdivide1
   348  01b9 4c1503             	jmp monerror
   349                          .fpdivide1
   350  01bc 206701             	jsr fpgetregspec
   351  01bf 9003               	bcc .fpdivide2
   352  01c1 4c1503             	jmp monerror
   353                          .fpdivide2
   354  01c4 a529               	lda fpmask
   355  01c6 0528               	ora fpregspec
   356  01c8 8f43fc1b           	sta IO_FP_DIVIDE
   357  01cc 4c7d03             	jmp moncmd
   358                          	
   359                          fpadd
   360  01cf 204201             	jsr fpgetmask
   361  01d2 9003               	bcc .fpadd1
   362  01d4 4c1503             	jmp monerror
   363                          .fpadd1
   364  01d7 206701             	jsr fpgetregspec
   365  01da 9003               	bcc .fpadd2
   366  01dc 4c1503             	jmp monerror
   367                          .fpadd2
   368  01df a529               	lda fpmask
   369  01e1 0528               	ora fpregspec
   370  01e3 8f44fc1b           	sta IO_FP_ADD
   371  01e7 4c7d03             	jmp moncmd
   372                          	
   373                          fpsubtract
   374  01ea 204201             	jsr fpgetmask
   375  01ed 9003               	bcc .fpsubtract1
   376  01ef 4c1503             	jmp monerror
   377                          .fpsubtract1
   378  01f2 206701             	jsr fpgetregspec
   379  01f5 9003               	bcc .fpsubtract2
   380  01f7 4c1503             	jmp monerror
   381                          .fpsubtract2
   382  01fa a529               	lda fpmask
   383  01fc 0528               	ora fpregspec
   384  01fe 8f45fc1b           	sta IO_FP_SUBTRACT
   385  0202 4c7d03             	jmp moncmd
   386                          	
   387                          fploadconst
   388  0205 204201             	jsr fpgetmask
   389  0208 9003               	bcc .fploadconst1
   390  020a 4c1503             	jmp monerror
   391                          .fploadconst1
   392  020d 206701             	jsr fpgetregspec
   393  0210 9003               	bcc .fploadconst2
   394  0212 4c1503             	jmp monerror
   395                          .fploadconst2
   396  0215 202f00             	jsr parse_addr			;get const specifier
   397  0218 c230               	rep #$30
   398  021a 98                 	tya
   399  021b e220               	sep #$20
   400  021d 291f               	and #$1f				;we're only interested in values 0-31
   401  021f 0529               	ora fpmask
   402  0221 0528               	ora fpregspec
   403  0223 8f40fc1b           	sta IO_FP_INIT_CONSTANT
   404  0227 4c7d03             	jmp moncmd
   405                          
   406                          fpdisp
   407  022a 204201             	jsr fpgetmask
   408  022d 901a               	bcc fpdisp2
   409  022f 4c1503             	jmp monerror
   410                          fpfacctxt
   411  0232 464143433a20       	!tx "FACC: "
   412  0238 00                 	!byte $00
   413                          fpfargtxt
   414  0239 464152473a20       	!tx "FARG: "
   415  023f 00                 	!byte $00
   416                          fpcondtxt
   417  0240 4650434f4e443a20   	!tx "FPCOND: "
   418  0248 00                 	!byte $00
   419                          fpdisp2
   420  0249 a23202             	ldx #fpfacctxt			;print FACC: tag
   421  024c 863d               	stx dpla
   422  024e a91c               	lda #$1c
   423  0250 853f               	sta dpla_h
   424  0252 22340e1c           	jsl l_prcdpla
   425  0256 a20900             	ldx #9
   426  0259 a529               	lda fpmask
   427  025b 2920               	and #$20
   428  025d d00c               	bne .facchex			;bit 5 set, so fall through and print 10 bytes
   429  025f a20700             	ldx #7
   430  0262 a529               	lda fpmask
   431  0264 2980               	and #$80
   432  0266 d003               	bne .facchex			;bit 5 clear, but bit 7 set, print 8 bytes
   433  0268 a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   434                          .facchex					;print X number of hex bytes in reverse order
   435  026b bfe0fc1b           	lda FPACCUMULATOR,x
   436  026f 206b05             	jsr+2 prhex
   437  0272 ca                 	dex
   438  0273 10f6               	bpl .facchex
   439  0275 a529               	lda fpmask
   440  0277 8f41fc1b           	sta IO_FP_TO_ASCII
   441  027b a92f               	lda #'/'
   442  027d 8f12fc1b           	sta IO_CON_CHAROUT
   443  0281 8f13fc1b           	sta IO_CON_REGISTER
   444  0285 a2c0fc             	ldx #FPASCII_LO16
   445  0288 863d               	stx dpla
   446  028a a91b               	lda #$1b
   447  028c 853f               	sta dpla_h
   448  028e 22340e1c           	jsl l_prcdpla
   449  0292 8f17fc1b           	sta IO_CON_CR
   450                          	
   451  0296 a23902             	ldx #fpfargtxt			;print FARG: tag
   452  0299 863d               	stx dpla
   453  029b a91c               	lda #$1c
   454  029d 853f               	sta dpla_h
   455  029f 22340e1c           	jsl l_prcdpla
   456  02a3 a20900             	ldx #9
   457  02a6 a529               	lda fpmask
   458  02a8 2920               	and #$20
   459  02aa d00c               	bne .farghex			;bit 5 set, so fall through and print 10 bytes
   460  02ac a20700             	ldx #7
   461  02af a529               	lda fpmask
   462  02b1 2980               	and #$80
   463  02b3 d003               	bne .farghex			;bit 5 clear, but bit 7 set, print 8 bytes
   464  02b5 a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   465                          .farghex					;print X number of hex bytes in reverse order
   466  02b8 bff0fc1b           	lda FPARGUMENT,x
   467  02bc 206b05             	jsr+2 prhex
   468  02bf ca                 	dex
   469  02c0 10f6               	bpl .farghex
   470  02c2 a529               	lda fpmask
   471  02c4 0940               	ora #$40				;select FARG this time
   472  02c6 8f41fc1b           	sta IO_FP_TO_ASCII
   473  02ca a92f               	lda #'/'
   474  02cc 8f12fc1b           	sta IO_CON_CHAROUT
   475  02d0 8f13fc1b           	sta IO_CON_REGISTER
   476  02d4 a2c0fc             	ldx #FPASCII_LO16
   477  02d7 863d               	stx dpla
   478  02d9 a91b               	lda #$1b
   479  02db 853f               	sta dpla_h
   480  02dd 22340e1c           	jsl l_prcdpla
   481  02e1 8f17fc1b           	sta IO_CON_CR
   482                          	
   483  02e5 a24002             	ldx #fpcondtxt			;print FPCOND: tag
   484  02e8 863d               	stx dpla
   485  02ea a91c               	lda #$1c
   486  02ec 853f               	sta dpla_h
   487  02ee 22340e1c           	jsl l_prcdpla
   488  02f2 a920               	lda #' '
   489  02f4 8f12fc1b           	sta IO_CON_CHAROUT
   490  02f8 8f13fc1b           	sta IO_CON_REGISTER
   491  02fc afbffc1b           	lda FPCOND
   492  0300 206b05             	jsr+2 prhex
   493  0303 8f17fc1b           	sta IO_CON_CR
   494                          	
   495  0307 4c7d03             	jmp moncmd
   496                          	
   497                          bankcmd
   498  030a 202f00             	jsr parse_addr
   499  030d 9006               	bcc monerror
   500  030f 98                 	tya
   501  0310 853c               	sta mondump_h
   502  0312 4c7d03             	jmp moncmd
   503                          monerror
   504  0315 a22503             	ldx #monsynerr
   505  0318 863d               	stx dpla
   506  031a a91c               	lda #$1c
   507  031c 853f               	sta dpla_h
   508  031e 22340e1c           	jsl l_prcdpla
   509  0322 4c7d03             	jmp moncmd
   510                          monsynerr
   511  0325 53796e7461782065...	!tx "Syntax error!"
   512  0332 0d00               	!byte $0d, $00
   513                          
   514                          colorcmd
   515  0334 202f00             	jsr parse_addr
   516  0337 90dc               	bcc monerror
   517  0339 98                 	tya
   518  033a 8f11fc1b           	sta IO_CON_COLOR
   519  033e 4c7d03             	jmp moncmd
   520                          	
   521                          modecmd
   522  0341 202f00             	jsr parse_addr
   523  0344 90cf               	bcc monerror
   524  0346 98                 	tya
   525  0347 c908               	cmp #$08
   526  0349 90ca               	bcc monerror
   527  034b c90a               	cmp #$0a
   528  034d b0c6               	bcs monerror
   529  034f 8f20fc1b           	sta IO_VIDMODE
   530  0353 a900               	lda #$00
   531  0355 8f14fc1b           	sta IO_CON_CURSORH
   532  0359 8f15fc1b           	sta IO_CON_CURSORV
   533  035d a920               	lda #$20
   534  035f 8f12fc1b           	sta IO_CON_CHAROUT
   535  0363 8f10fc1b           	sta IO_CON_CLS
   536  0367 4c7d03             	jmp moncmd
   537                          	
   538                          monstart				;main entry point for system monitor
   539  036a 4b                 	phk
   540  036b ab                 	plb
   541  036c c210               	rep #$10
   542                          	!rl
   543  036e e220               	sep #$20
   544                          	!as
   545  0370 a20000             	ldx #$0000
   546  0373 863a               	stx mondump
   547  0375 a91c               	lda #$1c
   548  0377 853c               	sta mondump_h
   549  0379 a944               	lda #'D'
   550  037b 8536               	sta monlast
   551                          	
   552                          	!zone moncmd
   553                          moncmd
   554  037d a92a               	lda #promptchar
   555  037f 8f12fc1b           	sta IO_CON_CHAROUT
   556  0383 8f13fc1b           	sta IO_CON_REGISTER
   557  0387 22b20d1c           	jsl l_getline
   558  038b 22900d1c           	jsl l_ucline
   559  038f 201600             	jsr parse_setup
   560  0392 202000             	jsr parse_getchar
   561                          .local3
   562  0395 c951               	cmp #'Q'
   563  0397 f05b               	beq haltcmd
   564  0399 c944               	cmp #'D'
   565  039b d003               	bne .local4
   566  039d 4cb004             	jmp+2 dumpcmd
   567                          .local4
   568  03a0 c90d               	cmp #$0d
   569  03a2 d008               	bne .local2
   570  03a4 a536               	lda monlast			;recall previously executed command
   571  03a6 c920               	cmp #$20			;make sure it isn't a control character
   572  03a8 b0eb               	bcs .local3			;and retry it
   573  03aa 80d1               	bra moncmd			;else recycle and try a new command
   574                          .local2
   575  03ac c941               	cmp #'A'
   576  03ae f06a               	beq asciidumpcmd
   577  03b0 c942               	cmp #'B'
   578  03b2 d003               	bne .local5
   579  03b4 4c0a03             	jmp+2 bankcmd
   580                          .local5
   581  03b7 c943               	cmp #'C'
   582  03b9 d003               	bne .local6
   583  03bb 4c3403             	jmp+2 colorcmd
   584                          .local6
   585  03be c94d               	cmp #'M'
   586  03c0 d003               	bne .local7
   587  03c2 4c4103             	jmp+2 modecmd
   588                          .local7
   589  03c5 c945               	cmp #'E'
   590  03c7 d003               	bne .local8
   591  03c9 4c8b05             	jmp+2 entercmd
   592                          .local8
   593  03cc c94c               	cmp #'L'
   594  03ce d003               	bne .local9
   595  03d0 4cb905             	jmp+2 listcmd
   596                          .local9
   597  03d3 c93f               	cmp #'?'
   598  03d5 f00d               	beq helpcmd
   599  03d7 c946               	cmp #'F'
   600  03d9 f003               	beq .localfp
   601  03db 4c7d03             	jmp moncmd
   602                          .localfp
   603  03de 200d01             	jsr fpcmd
   604  03e1 4c7d03             	jmp moncmd
   605                          	
   606                          helpcmd
   607  03e4 a2780e             	ldx #helpmsg
   608  03e7 863d               	stx dpla
   609  03e9 a91c               	lda #$1c
   610  03eb 853f               	sta dpla_h
   611  03ed 22340e1c           	jsl l_prcdpla
   612  03f1 4c7d03             	jmp moncmd
   613                          	
   614                          haltcmd
   615  03f4 a20204             	ldx #haltmsg
   616  03f7 863d               	stx dpla
   617  03f9 a91c               	lda #$1c
   618  03fb 853f               	sta dpla_h
   619  03fd 22340e1c           	jsl l_prcdpla
   620  0401 db                 	stp
   621                          haltmsg
   622  0402 48616c74696e6720...	!tx "Halting 65816 engine.."
   623  0418 0d00               	!byte $0d,$00
   624                          	
   625                          	!zone asciidumpcmd
   626                          asciidumpcmd
   627  041a 8536               	sta monlast
   628  041c 202f00             	jsr parse_addr
   629  041f 9021               	bcc .local3
   630  0421 843a               	sty mondump
   631  0423 8433               	sty rangehigh
   632  0425 2435               	bit monrange			;user asking for a range?
   633  0427 1019               	bpl .local3
   634  0429 202f00             	jsr parse_addr			;get the remaining half of the range
   635  042c 8433               	sty rangehigh
   636  042e a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   637  0430 8535               	sta monrange
   638  0432 a433               	ldy rangehigh
   639  0434 d003               	bne .local6
   640  0436 4c1503             	jmp+2 monerror			;top of range can't be zero
   641                          .local6
   642  0439 a43a               	ldy mondump
   643  043b c433               	cpy rangehigh
   644  043d 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   645  043f 4c1503             	jmp+2 monerror
   646                          .local3
   647  0442 20bf00             	jsr prdumpaddr
   648  0445 a00000             	ldy #$0000
   649                          .local2
   650  0448 b73a               	lda [mondump],y
   651  044a c920               	cmp #$20
   652  044c b002               	bcs .local4
   653  044e a92e               	lda #'.'				;substitute control character with a period
   654                          .local4
   655  0450 8f12fc1b           	sta IO_CON_CHAROUT
   656  0454 8f13fc1b           	sta IO_CON_REGISTER
   657  0458 c8                 	iny
   658  0459 af20fc1b           	lda IO_VIDMODE
   659  045d c909               	cmp #$09
   660  045f d007               	bne .lores1
   661  0461 c04000             	cpy #$0040
   662  0464 d0e2               	bne .local2
   663  0466 8005               	bra .lores2
   664                          .lores1
   665  0468 c01000             	cpy #$0010
   666  046b d0db               	bne .local2
   667                          .lores2
   668  046d 8f17fc1b           	sta IO_CON_CR
   669  0471 20e800             	jsr adjdumpaddr
   670  0474 b035               	bcs .local5				;carry to bank, exit even if we're processing a range
   671  0476 20e800             	jsr adjdumpaddr
   672  0479 b030               	bcs .local5	
   673  047b af20fc1b           	lda IO_VIDMODE
   674  047f c909               	cmp #$09
   675  0481 d01e               	bne .lores3
   676  0483 20e800             	jsr adjdumpaddr
   677  0486 b023               	bcs .local5	
   678  0488 20e800             	jsr adjdumpaddr
   679  048b b01e               	bcs .local5	
   680  048d 20e800             	jsr adjdumpaddr
   681  0490 b019               	bcs .local5	
   682  0492 20e800             	jsr adjdumpaddr
   683  0495 b014               	bcs .local5	
   684  0497 20e800             	jsr adjdumpaddr
   685  049a b00f               	bcs .local5	
   686  049c 20e800             	jsr adjdumpaddr
   687  049f b00a               	bcs .local5	
   688                          .lores3
   689  04a1 2435               	bit monrange			;ranges on?
   690  04a3 1006               	bpl .local5
   691  04a5 a433               	ldy rangehigh
   692  04a7 c43a               	cpy mondump
   693  04a9 b097               	bcs .local3
   694                          .local5
   695  04ab 6435               	stz monrange
   696  04ad 4c7d03             	jmp moncmd
   697                          	
   698                          	!zone dumpcmd
   699                          dumpcmd
   700  04b0 8536               	sta monlast
   701  04b2 202f00             	jsr parse_addr
   702  04b5 9021               	bcc .local3
   703  04b7 843a               	sty mondump				;if address was specified, store 16 bit y at low 16 bits of mondump address
   704  04b9 8433               	sty rangehigh
   705  04bb 2435               	bit monrange			;user asking for a range?
   706  04bd 1019               	bpl .local3
   707  04bf 202f00             	jsr parse_addr			;get the remaining half of the range
   708  04c2 8433               	sty rangehigh
   709  04c4 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   710  04c6 8535               	sta monrange
   711  04c8 a433               	ldy rangehigh
   712  04ca d003               	bne .local6
   713  04cc 4c1503             	jmp+2 monerror			;top of range can't be zero
   714                          .local6
   715  04cf a43a               	ldy mondump
   716  04d1 c433               	cpy rangehigh
   717  04d3 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   718  04d5 4c1503             	jmp+2 monerror
   719                          .local3
   720  04d8 20bf00             	jsr prdumpaddr
   721  04db a00000             	ldy #$0000
   722                          .local2
   723  04de b73a               	lda [mondump],y
   724  04e0 206b05             	jsr+2 prhex
   725  04e3 a920               	lda #' '
   726  04e5 8f12fc1b           	sta IO_CON_CHAROUT
   727  04e9 8f13fc1b           	sta IO_CON_REGISTER
   728  04ed c8                 	iny
   729  04ee af20fc1b           	lda IO_VIDMODE
   730  04f2 c909               	cmp #$09
   731  04f4 d03e               	bne .lores1
   732  04f6 c01000             	cpy #$0010
   733  04f9 d0e3               	bne .local2
   734  04fb a920               	lda #' '
   735  04fd 8f12fc1b           	sta IO_CON_CHAROUT
   736  0501 8f13fc1b           	sta IO_CON_REGISTER
   737  0505 a92d               	lda #'-'
   738  0507 8f12fc1b           	sta IO_CON_CHAROUT
   739  050b 8f13fc1b           	sta IO_CON_REGISTER
   740  050f a920               	lda #' '
   741  0511 8f12fc1b           	sta IO_CON_CHAROUT
   742  0515 8f13fc1b           	sta IO_CON_REGISTER
   743  0519 a00000             	ldy #$0000				;print 16 bytes as ASCII... bonus when in mode 9!
   744                          .asc2
   745  051c b73a               	lda [mondump],y
   746  051e c920               	cmp #$20
   747  0520 b002               	bcs .asc4
   748  0522 a92e               	lda #'.'				;substitute control character with a period
   749                          .asc4
   750  0524 8f12fc1b           	sta IO_CON_CHAROUT
   751  0528 8f13fc1b           	sta IO_CON_REGISTER
   752  052c c8                 	iny
   753  052d c01000             	cpy #$0010
   754  0530 d0ea               	bne .asc2
   755  0532 8005               	bra .lores2
   756                          .lores1
   757  0534 c00800             	cpy #$0008
   758  0537 d0a5               	bne .local2
   759                          .lores2
   760  0539 8f17fc1b           	sta IO_CON_CR
   761  053d 20e800             	jsr adjdumpaddr
   762  0540 b01a               	bcs .local5				;carry to bank, exit even if we're processing a range
   763  0542 af20fc1b           	lda IO_VIDMODE
   764  0546 c909               	cmp #$09
   765  0548 d005               	bne .lores3
   766  054a 20e800             	jsr adjdumpaddr
   767  054d b00d               	bcs .local5
   768                          .lores3
   769  054f 2435               	bit monrange			;ranges on?
   770  0551 1009               	bpl .local5
   771  0553 a433               	ldy rangehigh
   772  0555 c43a               	cpy mondump
   773  0557 9003               	bcc .local5
   774  0559 4cd804             	jmp+2 .local3
   775                          .local5
   776  055c 6435               	stz monrange
   777  055e 4c7d03             	jmp moncmd
   778                          	
   779                          prhex16
   780  0561 c230               	rep #$30
   781  0563 8a                 	txa
   782  0564 e220               	sep #$20
   783  0566 eb                 	xba
   784  0567 206b05             	jsr+2 prhex
   785  056a eb                 	xba
   786                          prhex
   787  056b 48                 	pha
   788  056c 4a                 	lsr
   789  056d 4a                 	lsr
   790  056e 4a                 	lsr
   791  056f 4a                 	lsr
   792  0570 207605             	jsr+2 prhexnib
   793  0573 68                 	pla
   794  0574 290f               	and #$0f
   795                          prhexnib
   796  0576 0930               	ora #$30
   797  0578 c93a               	cmp #$3a
   798  057a 9003               	bcc prhexnofix
   799  057c 18                 	clc
   800  057d 6907               	adc #$07
   801                          prhexnofix
   802  057f 8f12fc1b           	sta IO_CON_CHAROUT
   803  0583 8f13fc1b           	sta IO_CON_REGISTER
   804  0587 60                 	rts
   805                          
   806                          	!zone entercmd
   807                          .local1
   808  0588 4c1503             	jmp monerror
   809                          entercmd
   810  058b 202f00             	jsr parse_addr
   811  058e 90f8               	bcc .local1			;address is mandatory
   812  0590 2435               	bit monrange
   813  0592 30f4               	bmi .local1			;ranges not allowed
   814  0594 8430               	sty enterbytes
   815  0596 a53c               	lda mondump_h
   816  0598 8532               	sta enterbytes_h	;retrieve bank from mondump
   817                          .local2
   818  059a 202f00             	jsr parse_addr		;start grabbing bytes
   819  059d 9017               	bcc .enterdone
   820  059f 2435               	bit monrange
   821  05a1 30e5               	bmi .local1			;stop that happening here too
   822  05a3 c230               	rep #$30
   823  05a5 98                 	tya
   824  05a6 e220               	sep #$20			;get low byte of parsed address into A
   825  05a8 8730               	sta [enterbytes]
   826  05aa e630               	inc enterbytes
   827  05ac d006               	bne .local3
   828  05ae e631               	inc enterbytes_m
   829  05b0 d002               	bne .local3
   830  05b2 e632               	inc enterbytes_h
   831                          .local3
   832  05b4 80e4               	bra .local2
   833                          .enterdone
   834  05b6 4c7d03             	jmp moncmd
   835                          	
   836                          	!zone listcmd
   837                          listcmd
   838  05b9 202f00             	jsr parse_addr
   839  05bc 9002               	bcc .listmany				;address is optional
   840  05be 843a               	sty mondump
   841                          .listmany
   842  05c0 af20fc1b           	lda IO_VIDMODE
   843  05c4 c909               	cmp #$09
   844  05c6 d005               	bne .listmany1
   845  05c8 a22000             	ldx #32
   846  05cb 8003               	bra .listmany2
   847                          .listmany1
   848  05cd a20f00             	ldx #15
   849                          .listmany2
   850  05d0 da                 	phx
   851  05d1 20db05             	jsr+2 .listsingle
   852  05d4 fa                 	plx
   853  05d5 ca                 	dex
   854  05d6 d0f8               	bne .listmany2
   855  05d8 4c7d03             	jmp moncmd
   856                          .listsingle
   857  05db a00000             	ldy #$0000
   858  05de 20bf00             	jsr prdumpaddr
   859  05e1 a900               	lda #$00
   860  05e3 eb                 	xba					;clear B
   861  05e4 a73a               	lda [mondump]				;get opcode
   862  05e6 48                 	pha					;save opcode
   863  05e7 aa                 	tax
   864  05e8 bd7c0a             	lda mnemlenmode,x
   865  05eb 4a                 	lsr
   866  05ec 4a                 	lsr
   867  05ed 4a                 	lsr
   868  05ee 4a                 	lsr
   869  05ef 4a                 	lsr					;isolage opcode len
   870  05f0 852f               	sta scratch1
   871  05f2 a73a               	lda [mondump]
   872  05f4 20210a             	jsr+2 is816
   873  05f7 a52f               	lda scratch1
   874  05f9 aa                 	tax
   875  05fa a00000             	ldy #$0000
   876                          .nextbyte
   877  05fd b73a               	lda [mondump],y
   878  05ff 206b05             	jsr prhex			;print hex
   879  0602 a920               	lda #' '
   880  0604 8f12fc1b           	sta IO_CON_CHAROUT
   881  0608 8f13fc1b           	sta IO_CON_REGISTER	;print space
   882  060c c8                 	iny
   883  060d ca                 	dex
   884  060e d0ed               	bne .nextbyte
   885  0610 a916               	lda #$16
   886  0612 8f14fc1b           	sta IO_CON_CURSORH	;tab over
   887  0616 68                 	pla					;get opcode back
   888  0617 aa                 	tax
   889  0618 bd7c0b             	lda mnemlist,x
   890  061b 8530               	sta enterbytes
   891  061d 6431               	stz enterbytes_m	;save for 16 bit add
   892  061f da                 	phx					;stash our opcode
   893  0620 c230               	rep #$30
   894                          	!al
   895  0622 29ff00             	and #$00ff			;switch to 16 bits, clear top
   896  0625 0a                 	asl
   897  0626 18                 	clc
   898  0627 6530               	adc enterbytes		;multiply by 3
   899  0629 aa                 	tax
   900  062a e220               	sep #$20
   901                          	!as
   902  062c bd7c0c             	lda mnems, x
   903  062f 8f12fc1b           	sta IO_CON_CHAROUT
   904  0633 8f13fc1b           	sta IO_CON_REGISTER
   905  0637 e8                 	inx
   906  0638 bd7c0c             	lda mnems, x
   907  063b 8f12fc1b           	sta IO_CON_CHAROUT
   908  063f 8f13fc1b           	sta IO_CON_REGISTER
   909  0643 e8                 	inx
   910  0644 bd7c0c             	lda mnems, x
   911  0647 8f12fc1b           	sta IO_CON_CHAROUT
   912  064b 8f13fc1b           	sta IO_CON_REGISTER
   913  064f a920               	lda #' '
   914  0651 8f12fc1b           	sta IO_CON_CHAROUT
   915  0655 8f13fc1b           	sta IO_CON_REGISTER
   916  0659 fa                 	plx					;get our opcode back in index
   917  065a a900               	lda #$00
   918  065c eb                 	xba					;clear top byte of A if it's dirty
   919  065d bd7c0a             	lda mnemlenmode,x
   920  0660 291f               	and #$1f			;isolate the addressing mode
   921  0662 0a                 	asl					;multiply by two
   922  0663 aa                 	tax
   923  0664 fc520a             	jsr (listamod,x)
   924  0667 af20fc1b           	lda IO_VIDMODE
   925  066b c909               	cmp #$09
   926  066d d01f               	bne .fixup1
   927  066f a925               	lda #$25
   928  0671 8f14fc1b           	sta IO_CON_CURSORH		;tab over and print our bytes as ASCII in 80 column mode
   929  0675 e230               	sep #$30				;8 bit indexes here
   930                          	!rs
   931  0677 a000               	ldy #$00				;print disassembly bytes as ASCII... bonus when in mode 9!
   932                          .asc2
   933  0679 b73a               	lda [mondump],y
   934  067b c920               	cmp #$20
   935  067d b002               	bcs .asc4
   936  067f a92e               	lda #'.'				;substitute control character with a period
   937                          .asc4
   938  0681 8f12fc1b           	sta IO_CON_CHAROUT
   939  0685 8f13fc1b           	sta IO_CON_REGISTER
   940  0689 c8                 	iny
   941  068a c42f               	cpy scratch1
   942  068c d0eb               	bne .asc2
   943                          .fixup1
   944  068e c210               	rep #$10
   945                          	!rl
   946  0690 8f17fc1b           	sta IO_CON_CR
   947                          .fixup
   948  0694 a52f               	lda scratch1		;get our fixup
   949  0696 18                 	clc
   950  0697 653a               	adc mondump
   951  0699 853a               	sta mondump
   952  069b a53b               	lda mondump_m
   953  069d 6900               	adc #$00
   954  069f 853b               	sta mondump_m
   955  06a1 a53c               	lda mondump_h
   956  06a3 6900               	adc #$00
   957  06a5 853c               	sta mondump_h
   958                          .goback
   959  06a7 60                 	rts
   960                          
   961                          amod0
   962  06a8 a924               	lda #'$'
   963  06aa 8f12fc1b           	sta IO_CON_CHAROUT
   964  06ae 8f13fc1b           	sta IO_CON_REGISTER
   965  06b2 a00100             	ldy #$0001
   966  06b5 b73a               	lda [mondump],y
   967  06b7 206b05             	jsr prhex
   968  06ba 60                 	rts
   969                          amod1
   970  06bb a928               	lda #'('
   971  06bd 8f12fc1b           	sta IO_CON_CHAROUT
   972  06c1 8f13fc1b           	sta IO_CON_REGISTER
   973  06c5 a924               	lda #'$'
   974  06c7 8f12fc1b           	sta IO_CON_CHAROUT
   975  06cb 8f13fc1b           	sta IO_CON_REGISTER
   976  06cf a00100             	ldy #$0001
   977  06d2 b73a               	lda [mondump],y
   978  06d4 206b05             	jsr prhex
   979  06d7 a92c               	lda #','
   980  06d9 8f12fc1b           	sta IO_CON_CHAROUT
   981  06dd 8f13fc1b           	sta IO_CON_REGISTER
   982  06e1 a958               	lda #'X'
   983  06e3 8f12fc1b           	sta IO_CON_CHAROUT
   984  06e7 8f13fc1b           	sta IO_CON_REGISTER
   985  06eb a929               	lda #')'
   986  06ed 8f12fc1b           	sta IO_CON_CHAROUT
   987  06f1 8f13fc1b           	sta IO_CON_REGISTER
   988  06f5 60                 	rts
   989                          amod2
   990  06f6 a00100             	ldy #$0001
   991  06f9 b73a               	lda [mondump],y
   992  06fb 206b05             	jsr prhex
   993  06fe a92c               	lda #','
   994  0700 8f12fc1b           	sta IO_CON_CHAROUT
   995  0704 8f13fc1b           	sta IO_CON_REGISTER
   996  0708 a953               	lda #'S'
   997  070a 8f12fc1b           	sta IO_CON_CHAROUT
   998  070e 8f13fc1b           	sta IO_CON_REGISTER
   999  0712 60                 	rts
  1000                          amod3
  1001  0713 a95b               	lda #'['
  1002  0715 8f12fc1b           	sta IO_CON_CHAROUT
  1003  0719 8f13fc1b           	sta IO_CON_REGISTER
  1004  071d a924               	lda #'$'
  1005  071f 8f12fc1b           	sta IO_CON_CHAROUT
  1006  0723 8f13fc1b           	sta IO_CON_REGISTER
  1007  0727 a00100             	ldy #$0001
  1008  072a b73a               	lda [mondump],y
  1009  072c 206b05             	jsr prhex
  1010  072f a95d               	lda #']'
  1011  0731 8f12fc1b           	sta IO_CON_CHAROUT
  1012  0735 8f13fc1b           	sta IO_CON_REGISTER
  1013                          amod4
  1014  0739 60                 	rts
  1015                          	!zone amod5
  1016                          amod5
  1017  073a a923               	lda #'#'
  1018  073c 8f12fc1b           	sta IO_CON_CHAROUT
  1019  0740 8f13fc1b           	sta IO_CON_REGISTER
  1020  0744 a924               	lda #'$'
  1021  0746 8f12fc1b           	sta IO_CON_CHAROUT
  1022  074a 8f13fc1b           	sta IO_CON_REGISTER
  1023  074e a52f               	lda scratch1
  1024  0750 c902               	cmp #$02
  1025  0752 f008               	beq .amod508
  1026                          .amod516
  1027  0754 a00200             	ldy #$0002
  1028  0757 b73a               	lda [mondump],y
  1029  0759 206b05             	jsr prhex
  1030                          .amod508
  1031  075c a00100             	ldy #$0001
  1032  075f b73a               	lda [mondump],y
  1033  0761 206b05             	jsr prhex
  1034  0764 60                 	rts
  1035                          amod6
  1036  0765 a924               	lda #'$'
  1037  0767 8f12fc1b           	sta IO_CON_CHAROUT
  1038  076b 8f13fc1b           	sta IO_CON_REGISTER
  1039  076f a00200             	ldy #$0002
  1040  0772 b73a               	lda [mondump],y
  1041  0774 206b05             	jsr prhex
  1042  0777 88                 	dey
  1043  0778 b73a               	lda [mondump],y
  1044  077a 4c6b05             	jmp prhex
  1045                          amod7
  1046  077d a924               	lda #'$'
  1047  077f 8f12fc1b           	sta IO_CON_CHAROUT
  1048  0783 8f13fc1b           	sta IO_CON_REGISTER
  1049  0787 a00300             	ldy #$0003
  1050  078a b73a               	lda [mondump],y
  1051  078c 206b05             	jsr prhex
  1052  078f 88                 	dey
  1053  0790 b73a               	lda [mondump],y
  1054  0792 206b05             	jsr prhex
  1055  0795 88                 	dey
  1056  0796 b73a               	lda [mondump],y
  1057  0798 4c6b05             	jmp prhex
  1058                          amod11
  1059  079b a00300             	ldy #$0003
  1060  079e 842a               	sty scratch2			;number of bytes to bump offset
  1061  07a0 a00200             	ldy #$0002
  1062  07a3 b73a               	lda [mondump],y
  1063  07a5 eb                 	xba
  1064  07a6 88                 	dey
  1065  07a7 b73a               	lda [mondump],y
  1066  07a9 8014               	bra amod8nosign
  1067                          amod8
  1068  07ab a00200             	ldy #$0002
  1069  07ae 842a               	sty scratch2
  1070  07b0 a900               	lda #$00
  1071  07b2 eb                 	xba						;clear high byte of A
  1072                          amod8a
  1073  07b3 a00100             	ldy #$0001
  1074  07b6 b73a               	lda [mondump],y			;get rel byte
  1075  07b8 1005               	bpl amod8nosign
  1076  07ba 48                 	pha
  1077  07bb a9ff               	lda #$ff
  1078  07bd eb                 	xba						;sign extend if negative
  1079  07be 68                 	pla
  1080                          amod8nosign
  1081  07bf c230               	rep #$30
  1082                          	!al
  1083  07c1 18                 	clc
  1084  07c2 653a               	adc mondump				;add to our current disassembly address
  1085  07c4 18                 	clc
  1086  07c5 652a               	adc scratch2			;add offset for instruction size
  1087  07c7 aa                 	tax
  1088  07c8 e220               	sep #$20
  1089                          	!as
  1090  07ca a924               	lda #'$'
  1091  07cc 8f12fc1b           	sta IO_CON_CHAROUT
  1092  07d0 8f13fc1b           	sta IO_CON_REGISTER
  1093  07d4 206105             	jsr prhex16
  1094  07d7 60                 	rts
  1095                          amod9
  1096  07d8 a928               	lda #'('
  1097  07da 8f12fc1b           	sta IO_CON_CHAROUT
  1098  07de 8f13fc1b           	sta IO_CON_REGISTER
  1099  07e2 a924               	lda #'$'
  1100  07e4 8f12fc1b           	sta IO_CON_CHAROUT
  1101  07e8 8f13fc1b           	sta IO_CON_REGISTER
  1102  07ec a00100             	ldy #$0001
  1103  07ef b73a               	lda [mondump],y
  1104  07f1 206b05             	jsr prhex
  1105  07f4 a929               	lda #')'
  1106  07f6 8f12fc1b           	sta IO_CON_CHAROUT
  1107  07fa 8f13fc1b           	sta IO_CON_REGISTER
  1108  07fe a92c               	lda #','
  1109  0800 8f12fc1b           	sta IO_CON_CHAROUT
  1110  0804 8f13fc1b           	sta IO_CON_REGISTER
  1111  0808 a959               	lda #'Y'
  1112  080a 8f12fc1b           	sta IO_CON_CHAROUT
  1113  080e 8f13fc1b           	sta IO_CON_REGISTER
  1114  0812 60                 	rts
  1115                          amoda
  1116  0813 a928               	lda #'('
  1117  0815 8f12fc1b           	sta IO_CON_CHAROUT
  1118  0819 8f13fc1b           	sta IO_CON_REGISTER
  1119  081d a924               	lda #'$'
  1120  081f 8f12fc1b           	sta IO_CON_CHAROUT
  1121  0823 8f13fc1b           	sta IO_CON_REGISTER
  1122  0827 a00100             	ldy #$0001
  1123  082a b73a               	lda [mondump],y
  1124  082c 206b05             	jsr prhex
  1125  082f a929               	lda #')'
  1126  0831 8f12fc1b           	sta IO_CON_CHAROUT
  1127  0835 8f13fc1b           	sta IO_CON_REGISTER
  1128  0839 60                 	rts
  1129                          amodb
  1130  083a a928               	lda #'('
  1131  083c 8f12fc1b           	sta IO_CON_CHAROUT
  1132  0840 8f13fc1b           	sta IO_CON_REGISTER
  1133  0844 a924               	lda #'$'
  1134  0846 8f12fc1b           	sta IO_CON_CHAROUT
  1135  084a 8f13fc1b           	sta IO_CON_REGISTER
  1136  084e a00100             	ldy #$0001
  1137  0851 b73a               	lda [mondump],y
  1138  0853 206b05             	jsr prhex
  1139  0856 a92c               	lda #','
  1140  0858 8f12fc1b           	sta IO_CON_CHAROUT
  1141  085c 8f13fc1b           	sta IO_CON_REGISTER
  1142  0860 a953               	lda #'S'
  1143  0862 8f12fc1b           	sta IO_CON_CHAROUT
  1144  0866 8f13fc1b           	sta IO_CON_REGISTER
  1145  086a a929               	lda #')'
  1146  086c 8f12fc1b           	sta IO_CON_CHAROUT
  1147  0870 8f13fc1b           	sta IO_CON_REGISTER
  1148  0874 a92c               	lda #','
  1149  0876 8f12fc1b           	sta IO_CON_CHAROUT
  1150  087a 8f13fc1b           	sta IO_CON_REGISTER
  1151  087e a959               	lda #'Y'
  1152  0880 8f12fc1b           	sta IO_CON_CHAROUT
  1153  0884 8f13fc1b           	sta IO_CON_REGISTER
  1154  0888 60                 	rts
  1155                          amodc
  1156  0889 a924               	lda #'$'
  1157  088b 8f12fc1b           	sta IO_CON_CHAROUT
  1158  088f 8f13fc1b           	sta IO_CON_REGISTER
  1159  0893 a00100             	ldy #$0001
  1160  0896 b73a               	lda [mondump],y
  1161  0898 206b05             	jsr prhex
  1162  089b a92c               	lda #','
  1163  089d 8f12fc1b           	sta IO_CON_CHAROUT
  1164  08a1 8f13fc1b           	sta IO_CON_REGISTER
  1165  08a5 a958               	lda #'X'
  1166  08a7 8f12fc1b           	sta IO_CON_CHAROUT
  1167  08ab 8f13fc1b           	sta IO_CON_REGISTER
  1168  08af 60                 	rts
  1169                          amodd
  1170  08b0 a95b               	lda #'['
  1171  08b2 8f12fc1b           	sta IO_CON_CHAROUT
  1172  08b6 8f13fc1b           	sta IO_CON_REGISTER
  1173  08ba a924               	lda #'$'
  1174  08bc 8f12fc1b           	sta IO_CON_CHAROUT
  1175  08c0 8f13fc1b           	sta IO_CON_REGISTER
  1176  08c4 a00100             	ldy #$0001
  1177  08c7 b73a               	lda [mondump],y
  1178  08c9 206b05             	jsr prhex
  1179  08cc a95d               	lda #']'
  1180  08ce 8f12fc1b           	sta IO_CON_CHAROUT
  1181  08d2 8f13fc1b           	sta IO_CON_REGISTER
  1182  08d6 a92c               	lda #','
  1183  08d8 8f12fc1b           	sta IO_CON_CHAROUT
  1184  08dc 8f13fc1b           	sta IO_CON_REGISTER
  1185  08e0 a959               	lda #'Y'
  1186  08e2 8f12fc1b           	sta IO_CON_CHAROUT
  1187  08e6 8f13fc1b           	sta IO_CON_REGISTER
  1188  08ea 60                 	rts
  1189                          amode
  1190  08eb a924               	lda #'$'
  1191  08ed 8f12fc1b           	sta IO_CON_CHAROUT
  1192  08f1 8f13fc1b           	sta IO_CON_REGISTER
  1193  08f5 a00200             	ldy #$0002
  1194  08f8 b73a               	lda [mondump],y
  1195  08fa 206b05             	jsr prhex
  1196  08fd 88                 	dey
  1197  08fe b73a               	lda [mondump],y
  1198  0900 206b05             	jsr prhex
  1199  0903 a92c               	lda #','
  1200  0905 8f12fc1b           	sta IO_CON_CHAROUT
  1201  0909 8f13fc1b           	sta IO_CON_REGISTER
  1202  090d a958               	lda #'X'
  1203  090f 8f12fc1b           	sta IO_CON_CHAROUT
  1204  0913 8f13fc1b           	sta IO_CON_REGISTER
  1205  0917 60                 	rts
  1206                          amodf
  1207  0918 a924               	lda #'$'
  1208  091a 8f12fc1b           	sta IO_CON_CHAROUT
  1209  091e 8f13fc1b           	sta IO_CON_REGISTER
  1210  0922 a00200             	ldy #$0002
  1211  0925 b73a               	lda [mondump],y
  1212  0927 206b05             	jsr prhex
  1213  092a 88                 	dey
  1214  092b b73a               	lda [mondump],y
  1215  092d 206b05             	jsr prhex
  1216  0930 a92c               	lda #','
  1217  0932 8f12fc1b           	sta IO_CON_CHAROUT
  1218  0936 8f13fc1b           	sta IO_CON_REGISTER
  1219  093a a959               	lda #'Y'
  1220  093c 8f12fc1b           	sta IO_CON_CHAROUT
  1221  0940 8f13fc1b           	sta IO_CON_REGISTER
  1222  0944 60                 	rts
  1223                          amod10
  1224  0945 a924               	lda #'$'
  1225  0947 8f12fc1b           	sta IO_CON_CHAROUT
  1226  094b 8f13fc1b           	sta IO_CON_REGISTER
  1227  094f a00300             	ldy #$0003
  1228  0952 b73a               	lda [mondump],y
  1229  0954 206b05             	jsr prhex
  1230  0957 88                 	dey
  1231  0958 b73a               	lda [mondump],y
  1232  095a 206b05             	jsr prhex
  1233  095d 88                 	dey
  1234  095e b73a               	lda [mondump],y
  1235  0960 206b05             	jsr prhex
  1236  0963 a92c               	lda #','
  1237  0965 8f12fc1b           	sta IO_CON_CHAROUT
  1238  0969 8f13fc1b           	sta IO_CON_REGISTER
  1239  096d a958               	lda #'X'
  1240  096f 8f12fc1b           	sta IO_CON_CHAROUT
  1241  0973 8f13fc1b           	sta IO_CON_REGISTER
  1242  0977 60                 	rts
  1243                          amod12
  1244  0978 a928               	lda #'('
  1245  097a 8f12fc1b           	sta IO_CON_CHAROUT
  1246  097e 8f13fc1b           	sta IO_CON_REGISTER
  1247  0982 a924               	lda #'$'
  1248  0984 8f12fc1b           	sta IO_CON_CHAROUT
  1249  0988 8f13fc1b           	sta IO_CON_REGISTER
  1250  098c a00200             	ldy #$0002
  1251  098f b73a               	lda [mondump],y
  1252  0991 206b05             	jsr prhex
  1253  0994 88                 	dey
  1254  0995 b73a               	lda [mondump],y
  1255  0997 206b05             	jsr prhex
  1256  099a a929               	lda #')'
  1257  099c 8f12fc1b           	sta IO_CON_CHAROUT
  1258  09a0 8f13fc1b           	sta IO_CON_REGISTER
  1259  09a4 60                 	rts
  1260                          amod13
  1261  09a5 a928               	lda #'('
  1262  09a7 8f12fc1b           	sta IO_CON_CHAROUT
  1263  09ab 8f13fc1b           	sta IO_CON_REGISTER
  1264  09af a924               	lda #'$'
  1265  09b1 8f12fc1b           	sta IO_CON_CHAROUT
  1266  09b5 8f13fc1b           	sta IO_CON_REGISTER
  1267  09b9 a00200             	ldy #$0002
  1268  09bc b73a               	lda [mondump],y
  1269  09be 206b05             	jsr prhex
  1270  09c1 88                 	dey
  1271  09c2 b73a               	lda [mondump],y
  1272  09c4 206b05             	jsr prhex
  1273  09c7 a92c               	lda #','
  1274  09c9 8f12fc1b           	sta IO_CON_CHAROUT
  1275  09cd 8f13fc1b           	sta IO_CON_REGISTER
  1276  09d1 a958               	lda #'X'
  1277  09d3 8f12fc1b           	sta IO_CON_CHAROUT
  1278  09d7 8f13fc1b           	sta IO_CON_REGISTER
  1279  09db a929               	lda #')'
  1280  09dd 8f12fc1b           	sta IO_CON_CHAROUT
  1281  09e1 8f13fc1b           	sta IO_CON_REGISTER
  1282  09e5 60                 	rts
  1283                          amod14
  1284  09e6 a924               	lda #'$'
  1285  09e8 8f12fc1b           	sta IO_CON_CHAROUT
  1286  09ec 8f13fc1b           	sta IO_CON_REGISTER
  1287  09f0 a00100             	ldy #$0001
  1288  09f3 b73a               	lda [mondump],y
  1289  09f5 206b05             	jsr prhex
  1290  09f8 a92c               	lda #','
  1291  09fa 8f12fc1b           	sta IO_CON_CHAROUT
  1292  09fe 8f13fc1b           	sta IO_CON_REGISTER
  1293  0a02 a959               	lda #'Y'
  1294  0a04 8f12fc1b           	sta IO_CON_CHAROUT
  1295  0a08 8f13fc1b           	sta IO_CON_REGISTER
  1296  0a0c 60                 	rts
  1297                          	
  1298                          						;test branches for disassembly purposes..
  1299  0a0d 70d7               	bvs amod14
  1300  0a0f 7010               	bvs is816
  1301  0a11 7092               	bvs amod13
  1302  0a13 703d               	bvs listamod
  1303  0a15 6260ff             	per amod12
  1304  0a18 620600             	per is816
  1305  0a1b 6227ff             	per amod10
  1306  0a1e 623100             	per listamod
  1307                          	
  1308                          	!zone is816
  1309                          is816
  1310  0a21 48                 	pha
  1311  0a22 291f               	and #$1f
  1312  0a24 c909               	cmp #$09				;09, 29, 49, etc?
  1313  0a26 d006               	bne .testx
  1314  0a28 242d               	bit alarge				;16 bit?
  1315  0a2a 3020               	bmi .is16
  1316  0a2c 1018               	bpl .is8
  1317                          .testx
  1318  0a2e 68                 	pla
  1319  0a2f 48                 	pha
  1320  0a30 c9a0               	cmp #$a0
  1321  0a32 f00e               	beq .isx
  1322  0a34 c9a2               	cmp #$a2
  1323  0a36 f00a               	beq .isx
  1324  0a38 c9c0               	cmp #$c0
  1325  0a3a f006               	beq .isx
  1326  0a3c c9e0               	cmp #$e0
  1327  0a3e f002               	beq .isx
  1328  0a40 68                 	pla						;made it here, not an accumulator or index instruction
  1329  0a41 60                 	rts
  1330                          .isx
  1331  0a42 242e               	bit xlarge
  1332  0a44 3006               	bmi .is16				;or else fall thru
  1333                          .is8
  1334  0a46 a902               	lda #$2
  1335  0a48 852f               	sta scratch1
  1336  0a4a 68                 	pla
  1337  0a4b 60                 	rts
  1338                          .is16
  1339  0a4c a903               	lda #$3
  1340  0a4e 852f               	sta scratch1
  1341  0a50 68                 	pla
  1342  0a51 60                 	rts
  1343                          	
  1344                          listamod
  1345  0a52 a806               	!16 amod0			;$xx
  1346  0a54 bb06               	!16 amod1			;($xx,X)
  1347  0a56 f606               	!16 amod2			;x,S
  1348  0a58 1307               	!16 amod3			;[$xx]
  1349  0a5a 3907               	!16 amod4			;implied
  1350  0a5c 3a07               	!16 amod5			;#$xx (or #$yyxx)
  1351  0a5e 6507               	!16 amod6			;$yyxx
  1352  0a60 7d07               	!16 amod7			;$zzyyxx
  1353  0a62 ab07               	!16 amod8			;rel8
  1354  0a64 d807               	!16 amod9			;($xx),Y
  1355  0a66 1308               	!16 amoda			;($xx)
  1356  0a68 3a08               	!16 amodb			;(xx,S),Y
  1357  0a6a 8908               	!16 amodc			;$xx,X
  1358  0a6c b008               	!16 amodd			;[$xx],Y
  1359  0a6e eb08               	!16 amode			;$yyxx,X
  1360  0a70 1809               	!16 amodf			;$yyxx,Y
  1361  0a72 4509               	!16 amod10			;$zzyyxx,X
  1362  0a74 9b07               	!16 amod11			;rel16
  1363  0a76 7809               	!16 amod12			;($yyxx)
  1364  0a78 a509               	!16 amod13			;($yyxx,X)
  1365  0a7a e609               	!16 amod14			;$xx,Y
  1366                          	
  1367                          mnemlenmode
  1368  0a7c 40                 	!byte %01000000		;00 brk 2/$xx
  1369  0a7d 41                 	!byte %01000001		;01 ora 2/($xx,x)
  1370  0a7e 40                 	!byte %01000000		;02 cop 2/$xx
  1371  0a7f 42                 	!byte %01000010		;03 ora 2/x,s
  1372  0a80 40                 	!byte %01000000		;04 tsb 2/$xx
  1373  0a81 40                 	!byte %01000000		;05 ora 2/$xx
  1374  0a82 40                 	!byte %01000000		;06 asl 2/$xx
  1375  0a83 43                 	!byte %01000011		;07 ora 2/[$xx]
  1376  0a84 24                 	!byte %00100100		;08 php 1
  1377  0a85 45                 	!byte %01000101		;09 ora 2/#imm
  1378  0a86 24                 	!byte %00100100		;0a asl 1
  1379  0a87 24                 	!byte %00100100		;0b phd 1
  1380  0a88 66                 	!byte %01100110		;0c tsb 3/$yyxx
  1381  0a89 66                 	!byte %01100110		;0d ora 3/$yyxx
  1382  0a8a 66                 	!byte %01100110		;0e asl 3/$yyxx
  1383  0a8b 87                 	!byte %10000111		;0f ora 4/$zzyyxx
  1384  0a8c 48                 	!byte %01001000		;10 bpl 2/rel8
  1385  0a8d 49                 	!byte %01001001		;11 ora 2/($xx),Y
  1386  0a8e 4a                 	!byte %01001010		;12 ora 2/($xx)
  1387  0a8f 4b                 	!byte %01001011		;13 ora 2/(x,s),Y
  1388  0a90 40                 	!byte %01000000		;14 trb 2/$xx
  1389  0a91 4c                 	!byte %01001100		;15 ora 2/$xx,X
  1390  0a92 4c                 	!byte %01001100		;16 asl 2/$xx,X
  1391  0a93 4d                 	!byte %01001101		;17 ora 2/[$xx],Y
  1392  0a94 24                 	!byte %00100100		;18 clc 1
  1393  0a95 6f                 	!byte %01101111		;19 ora 3/$yyxx,Y
  1394  0a96 24                 	!byte %00100100		;1a inc 1
  1395  0a97 24                 	!byte %00100100		;1b tcs 1
  1396  0a98 66                 	!byte %01100110		;1c trb 3/$yyxx
  1397  0a99 6e                 	!byte %01101110		;1d ora 3/$yyxx,X
  1398  0a9a 6e                 	!byte %01101110		;1e asl 3/$yyxx,X
  1399  0a9b 90                 	!byte %10010000		;1f ora 4/$zzyyxx,X
  1400  0a9c 66                 	!byte %01100110		;20 jsr 3/$yyxx
  1401  0a9d 41                 	!byte %01000001		;21 and 2/($xx,x)
  1402  0a9e 87                 	!byte %10000111		;22 jsl 4/$zzyyxx
  1403  0a9f 42                 	!byte %01000010		;23 and 2/x,s
  1404  0aa0 40                 	!byte %01000000		;24 bit 2/$xx
  1405  0aa1 40                 	!byte %01000000		;25 and 2/$xx
  1406  0aa2 40                 	!byte %01000000		;26 rol 2/$xx
  1407  0aa3 43                 	!byte %01000011		;27 and 2/[$xx]
  1408  0aa4 24                 	!byte %00100100		;28 plp 1
  1409  0aa5 45                 	!byte %01000101		;29 and 2/#imm
  1410  0aa6 24                 	!byte %00100100		;2a rol 1
  1411  0aa7 24                 	!byte %00100100		;2b pld 1
  1412  0aa8 66                 	!byte %01100110		;2c bit 3/$yyxx
  1413  0aa9 66                 	!byte %01100110		;2d and 3/$yyxx
  1414  0aaa 66                 	!byte %01100110		;2e rol 3/$yyxx
  1415  0aab 87                 	!byte %10000111		;2f and 4/$zzyyxx
  1416  0aac 48                 	!byte %01001000		;30 bmi 2/rel8
  1417  0aad 49                 	!byte %01001001		;31 and 2/($xx),Y
  1418  0aae 4a                 	!byte %01001010		;32 and 2/($xx)
  1419  0aaf 4b                 	!byte %01001011		;33 and 2/(x,s),Y
  1420  0ab0 4c                 	!byte %01001100		;34 bit 2/$xx,X
  1421  0ab1 4c                 	!byte %01001100		;35 and 2/$xx,X
  1422  0ab2 4c                 	!byte %01001100		;36 rol 2/$xx,X
  1423  0ab3 4d                 	!byte %01001101		;37 and 2/[$xx],Y
  1424  0ab4 24                 	!byte %00100100		;38 sec 1
  1425  0ab5 6f                 	!byte %01101111		;39 and 3/$yyxx,Y
  1426  0ab6 24                 	!byte %00100100		;3a dec 1
  1427  0ab7 24                 	!byte %00100100		;3b tsc 1
  1428  0ab8 6e                 	!byte %01101110		;3c bit 3/$yyxx,X
  1429  0ab9 6e                 	!byte %01101110		;3d and 3/$yyxx,X
  1430  0aba 6e                 	!byte %01101110		;3e rol 3/$yyxx,X
  1431  0abb 90                 	!byte %10010000		;3f and 4/$zzyyxx,X
  1432  0abc 24                 	!byte %00100100		;40 ???
  1433  0abd 41                 	!byte %01000001		;41 eor 2/($xx,x)
  1434  0abe 40                 	!byte %01000000		;42 wdm 2/$00
  1435  0abf 42                 	!byte %01000010		;43 eor 2/x,s
  1436  0ac0 24                 	!byte %00100100		;44 ???
  1437  0ac1 40                 	!byte %01000000		;45 eor 2/$xx
  1438  0ac2 40                 	!byte %01000000		;46 lsr 2/$xx
  1439  0ac3 43                 	!byte %01000011		;47 eor 2/[$xx]
  1440  0ac4 24                 	!byte %00100100		;48 pha 1
  1441  0ac5 45                 	!byte %01000101		;49 eor 2/#imm
  1442  0ac6 24                 	!byte %00100100		;4a lsr 1
  1443  0ac7 24                 	!byte %00100100		;4b phk 1
  1444  0ac8 66                 	!byte %01100110		;4c jmp 3/$yyxx
  1445  0ac9 66                 	!byte %01100110		;4d eor 3/$yyxx
  1446  0aca 66                 	!byte %01100110		;4e lsr 3/$yyxx
  1447  0acb 87                 	!byte %10000111		;4f eor 4/$zzyyxx
  1448  0acc 48                 	!byte %01001000		;50 bvc 2/rel8
  1449  0acd 49                 	!byte %01001001		;51 eor 2/($xx),Y
  1450  0ace 4a                 	!byte %01001010		;52 eor 2/($xx)
  1451  0acf 4b                 	!byte %01001011		;53 eor 2/(x,s),Y
  1452  0ad0 24                 	!byte %00100100		;54 ???
  1453  0ad1 4c                 	!byte %01001100		;55 eor 2/$xx,X
  1454  0ad2 4c                 	!byte %01001100		;56 lsr 2/$xx,X
  1455  0ad3 4d                 	!byte %01001101		;57 eor 2/[$xx],Y
  1456  0ad4 24                 	!byte %00100100		;58 cli 1
  1457  0ad5 6f                 	!byte %01101111		;59 eor 3/$yyxx,Y
  1458  0ad6 24                 	!byte %00100100		;5a phy 1
  1459  0ad7 24                 	!byte %00100100		;5b tcd 1
  1460  0ad8 87                 	!byte %10000111		;5c jml 4/$zzyyxx
  1461  0ad9 6e                 	!byte %01101110		;5d eor 3/$yyxx,X
  1462  0ada 6e                 	!byte %01101110		;5e lsr 3/$yyxx,X
  1463  0adb 90                 	!byte %10010000		;5f eor 4/$zzyyxx,X
  1464  0adc 24                 	!byte %00100100		;60 rts
  1465  0add 41                 	!byte %01000001		;61 adc 2/($xx,x)
  1466  0ade 71                 	!byte %01110001		;62 per 3/rel16
  1467  0adf 42                 	!byte %01000010		;63 adc 2/x,s
  1468  0ae0 40                 	!byte %01000000		;64 stz 2/$xx
  1469  0ae1 40                 	!byte %01000000		;65 adc 2/$xx
  1470  0ae2 40                 	!byte %01000000		;66 ror 2/$xx
  1471  0ae3 43                 	!byte %01000011		;67 adc 2/[$xx]
  1472  0ae4 24                 	!byte %00100100		;68 pla 1
  1473  0ae5 45                 	!byte %01000101		;69 adc 2/#imm
  1474  0ae6 24                 	!byte %00100100		;6a ror 1
  1475  0ae7 24                 	!byte %00100100		;6b rtl 1
  1476  0ae8 72                 	!byte %01110010		;6c jmp 3/($yyxx)
  1477  0ae9 66                 	!byte %01100110		;6d adc 3/$yyxx
  1478  0aea 66                 	!byte %01100110		;6e ror 3/$yyxx
  1479  0aeb 87                 	!byte %10000111		;6f adc 4/$zzyyxx
  1480  0aec 48                 	!byte %01001000		;70 bvs 2/rel8
  1481  0aed 49                 	!byte %01001001		;71 adc 2/($xx),Y
  1482  0aee 4a                 	!byte %01001010		;72 adc 2/($xx)
  1483  0aef 4b                 	!byte %01001011		;73 adc 2/(x,s),Y
  1484  0af0 4c                 	!byte %01001100		;74 stz 2/$xx,X
  1485  0af1 4c                 	!byte %01001100		;75 adc 2/$xx,X
  1486  0af2 4c                 	!byte %01001100		;76 ror 2/$xx,X
  1487  0af3 4d                 	!byte %01001101		;77 adc 2/[$xx],Y
  1488  0af4 24                 	!byte %00100100		;78 sei 1
  1489  0af5 6f                 	!byte %01101111		;79 adc 3/$yyxx,Y
  1490  0af6 24                 	!byte %00100100		;7a ply 1
  1491  0af7 24                 	!byte %00100100		;7b tdc 1
  1492  0af8 73                 	!byte %01110011		;7c jmp 3/($yyxx,X)
  1493  0af9 6e                 	!byte %01101110		;7d adc 3/$yyxx,X
  1494  0afa 6e                 	!byte %01101110		;7e lsr 3/$yyxx,X
  1495  0afb 90                 	!byte %10010000		;7f adc 4/$zzyyxx,X
  1496  0afc 48                 	!byte %01001000		;80 bra 2/rel8
  1497  0afd 41                 	!byte %01000001		;81 sta 2/($xx,x)
  1498  0afe 71                 	!byte %01110001		;82 brl 3/rel16
  1499  0aff 42                 	!byte %01000010		;83 sta 2/x,s
  1500  0b00 40                 	!byte %01000000		;84 sty 2/$xx
  1501  0b01 40                 	!byte %01000000		;85 sta 2/$xx
  1502  0b02 40                 	!byte %01000000		;86 stx 2/$xx
  1503  0b03 43                 	!byte %01000011		;87 sta 2/[$xx]
  1504  0b04 24                 	!byte %00100100		;88 dey 1
  1505  0b05 45                 	!byte %01000101		;89 bit 2/#imm
  1506  0b06 24                 	!byte %00100100		;8a txa 1
  1507  0b07 24                 	!byte %00100100		;8b phb 1
  1508  0b08 66                 	!byte %01100110		;8c sty 3/$yyxx
  1509  0b09 66                 	!byte %01100110		;8d sta 3/$yyxx
  1510  0b0a 66                 	!byte %01100110		;8e stx 3/$yyxx
  1511  0b0b 87                 	!byte %10000111		;8f sta 4/$zzyyxx
  1512  0b0c 48                 	!byte %01001000		;90 bcc 2/rel8
  1513  0b0d 49                 	!byte %01001001		;91 sta 2/($xx),Y
  1514  0b0e 4a                 	!byte %01001010		;92 sta 2/($xx)
  1515  0b0f 4b                 	!byte %01001011		;93 sta 2/(x,s),Y
  1516  0b10 4c                 	!byte %01001100		;94 sty 2/$xx,X
  1517  0b11 4c                 	!byte %01001100		;95 sta 2/$xx,X
  1518  0b12 54                 	!byte %01010100		;96 stx 2/$xx,Y
  1519  0b13 4d                 	!byte %01001101		;97 sta 2/[$xx],Y
  1520  0b14 24                 	!byte %00100100		;98 txa 1
  1521  0b15 6f                 	!byte %01101111		;99 sta 3/$yyxx,Y
  1522  0b16 24                 	!byte %00100100		;9a txs 1
  1523  0b17 24                 	!byte %00100100		;9b txy 1
  1524  0b18 66                 	!byte %01100110		;9c stz 3/$yyxx
  1525  0b19 6e                 	!byte %01101110		;9d sta 3/$yyxx,X
  1526  0b1a 6e                 	!byte %01101110		;9e stz 3/$yyxx,X
  1527  0b1b 90                 	!byte %10010000		;9f sta 4/$zzyyxx,X
  1528  0b1c 45                 	!byte %01000101		;a0 ldy 2/#imm
  1529  0b1d 41                 	!byte %01000001		;a1 lda 2/($xx,x)
  1530  0b1e 45                 	!byte %01000101		;a2 ldx 2/#imm
  1531  0b1f 42                 	!byte %01000010		;a3 lda 2/x,s
  1532  0b20 40                 	!byte %01000000		;a4 ldy 2/$xx
  1533  0b21 40                 	!byte %01000000		;a5 sta 2/$xx
  1534  0b22 40                 	!byte %01000000		;a6 ldx 2/$xx
  1535  0b23 43                 	!byte %01000011		;a7 lda 2/[$xx]
  1536  0b24 24                 	!byte %00100100		;a8 tay 1
  1537  0b25 45                 	!byte %01000101		;a9 lda 2/#imm
  1538  0b26 24                 	!byte %00100100		;aa tax 1
  1539  0b27 24                 	!byte %00100100		;ab plb 1
  1540  0b28 66                 	!byte %01100110		;ac ldy 3/$yyxx
  1541  0b29 66                 	!byte %01100110		;ad lda 3/$yyxx
  1542  0b2a 66                 	!byte %01100110		;ae ldx 3/$yyxx
  1543  0b2b 87                 	!byte %10000111		;af lda 4/$zzyyxx
  1544  0b2c 48                 	!byte %01001000		;b0 bcs 2/rel8
  1545  0b2d 49                 	!byte %01001001		;b1 lda 2/($xx),Y
  1546  0b2e 4a                 	!byte %01001010		;b2 lda 2/($xx)
  1547  0b2f 4b                 	!byte %01001011		;b3 lda 2/(x,s),Y
  1548  0b30 4c                 	!byte %01001100		;b4 ldy 2/$xx,X
  1549  0b31 4c                 	!byte %01001100		;b5 lda 2/$xx,X
  1550  0b32 54                 	!byte %01010100		;b6 ldx 2/$xx,Y
  1551  0b33 4d                 	!byte %01001101		;b7 lda 2/[$xx],Y
  1552  0b34 24                 	!byte %00100100		;b8 clv 1
  1553  0b35 6f                 	!byte %01101111		;b9 lda 3/$yyxx,Y
  1554  0b36 24                 	!byte %00100100		;ba tsx 1
  1555  0b37 24                 	!byte %00100100		;bb tyx 1
  1556  0b38 66                 	!byte %01100110		;bc ldy 3/$yyxx
  1557  0b39 6e                 	!byte %01101110		;bd lda 3/$yyxx,X
  1558  0b3a 6e                 	!byte %01101110		;be ldx 3/$yyxx,X
  1559  0b3b 90                 	!byte %10010000		;bf lda 4/$zzyyxx,X
  1560  0b3c 45                 	!byte %01000101		;c0 cpy 2/#imm
  1561  0b3d 41                 	!byte %01000001		;c1 cmp 2/($xx,x)
  1562  0b3e 45                 	!byte %01000101		;c2 rep 2/#imm
  1563  0b3f 42                 	!byte %01000010		;c3 cmp 2/x,s
  1564  0b40 40                 	!byte %01000000		;c4 cpx 2/$xx
  1565  0b41 40                 	!byte %01000000		;c5 cmp 2/$xx
  1566  0b42 40                 	!byte %01000000		;c6 dec 2/$xx
  1567  0b43 43                 	!byte %01000011		;c7 cmp 2/[$xx]
  1568  0b44 24                 	!byte %00100100		;c8 iny 1
  1569  0b45 45                 	!byte %01000101		;c9 cmp 2/#imm
  1570  0b46 24                 	!byte %00100100		;ca dex 1
  1571  0b47 24                 	!byte %00100100		;cb wai 1
  1572  0b48 66                 	!byte %01100110		;cc cpy 3/$yyxx
  1573  0b49 66                 	!byte %01100110		;cd cmp 3/$yyxx
  1574  0b4a 66                 	!byte %01100110		;ce dec 3/$yyxx
  1575  0b4b 87                 	!byte %10000111		;cf cmp 4/$zzyyxx
  1576  0b4c 48                 	!byte %01001000		;d0 bne 2/rel8
  1577  0b4d 49                 	!byte %01001001		;d1 cmp 2/($xx),Y
  1578  0b4e 4a                 	!byte %01001010		;d2 cmp 2/($xx)
  1579  0b4f 4b                 	!byte %01001011		;d3 cmp 2/(x,s),Y
  1580  0b50 4a                 	!byte %01001010		;d4 pei 2/($xx)
  1581  0b51 4c                 	!byte %01001100		;d5 cmp 2/$xx,X
  1582  0b52 4c                 	!byte %01001100		;d6 dec 2/$xx,X
  1583  0b53 4d                 	!byte %01001101		;d7 cmp 2/[$xx],Y
  1584  0b54 24                 	!byte %00100100		;d8 cld 1
  1585  0b55 6f                 	!byte %01101111		;d9 cmp 3/$yyxx,Y
  1586  0b56 24                 	!byte %00100100		;da phx 1
  1587  0b57 24                 	!byte %00100100		;db stp 1
  1588  0b58 43                 	!byte %01000011		;dc jml 2/[$xx]
  1589  0b59 6e                 	!byte %01101110		;dd cmp 3/$yyxx,X
  1590  0b5a 6e                 	!byte %01101110		;de dec 3/$yyxx,X
  1591  0b5b 90                 	!byte %10010000		;df cmp 4/$zzyyxx,X
  1592  0b5c 45                 	!byte %01000101		;e0 cpx 2/#imm
  1593  0b5d 41                 	!byte %01000001		;e1 sbc 2/($xx,x)
  1594  0b5e 45                 	!byte %01000101		;e2 sep 2/#imm
  1595  0b5f 42                 	!byte %01000010		;e3 sbc 2/x,s
  1596  0b60 40                 	!byte %01000000		;e4 cpx 2/$xx
  1597  0b61 40                 	!byte %01000000		;e5 sbc 2/$xx
  1598  0b62 40                 	!byte %01000000		;e6 inc 2/$xx
  1599  0b63 43                 	!byte %01000011		;e7 sbc 2/[$xx]
  1600  0b64 24                 	!byte %00100100		;e8 inx 1
  1601  0b65 45                 	!byte %01000101		;e9 sbc 2/#imm
  1602  0b66 24                 	!byte %00100100		;ea nop 1
  1603  0b67 24                 	!byte %00100100		;eb xba 1
  1604  0b68 66                 	!byte %01100110		;ec cpx 3/$yyxx
  1605  0b69 66                 	!byte %01100110		;ed sbc 3/$yyxx
  1606  0b6a 66                 	!byte %01100110		;ee inc 3/$yyxx
  1607  0b6b 87                 	!byte %10000111		;ef sbc 4/$zzyyxx
  1608  0b6c 48                 	!byte %01001000		;f0 beq 2/rel8
  1609  0b6d 49                 	!byte %01001001		;f1 sbc 2/($xx),Y
  1610  0b6e 4a                 	!byte %01001010		;f2 sbc 2/($xx)
  1611  0b6f 4b                 	!byte %01001011		;f3 sbc 2/(x,s),Y
  1612  0b70 66                 	!byte %01100110		;f4 pea 3/$yyxx
  1613  0b71 4c                 	!byte %01001100		;f5 sbc 2/$xx,X
  1614  0b72 4c                 	!byte %01001100		;f6 inc 2/$xx,X
  1615  0b73 4d                 	!byte %01001101		;f7 sbc 2/[$xx],Y
  1616  0b74 24                 	!byte %00100100		;f8 sed 1
  1617  0b75 6f                 	!byte %01101111		;f9 sbc 3/$yyxx,Y
  1618  0b76 24                 	!byte %00100100		;fa plx 1
  1619  0b77 24                 	!byte %00100100		;fb xce 1
  1620  0b78 73                 	!byte %01110011		;fc jsr 3/($yyxx)
  1621  0b79 6e                 	!byte %01101110		;fd sbc 3/$yyxx,X
  1622  0b7a 6e                 	!byte %01101110		;fe inc 3/$yyxx,X
  1623  0b7b 90                 	!byte %10010000		;ff sbc 4/$zzyyxx,X
  1624                          mnemlist
  1625  0b7c 00                 	!byte $00			;00 brk
  1626  0b7d 02                 	!byte $02			;01 ora
  1627  0b7e 01                 	!byte $01			;02 cop
  1628  0b7f 02                 	!byte $02			;03 ora
  1629  0b80 03                 	!byte $03			;04 tsb
  1630  0b81 02                 	!byte $02			;05 ora
  1631  0b82 04                 	!byte $04			;06 asl
  1632  0b83 02                 	!byte $02			;07 ora
  1633  0b84 05                 	!byte $05			;08 php
  1634  0b85 02                 	!byte $02			;09 ora
  1635  0b86 04                 	!byte $04			;0a asl
  1636  0b87 06                 	!byte $06			;0b phd
  1637  0b88 03                 	!byte $03			;0c tsb
  1638  0b89 02                 	!byte $02			;0d ora
  1639  0b8a 04                 	!byte $04			;0e asl
  1640  0b8b 02                 	!byte $02			;0f ora
  1641  0b8c 07                 	!byte $07			;10 bpl
  1642  0b8d 02                 	!byte $02			;11 ora
  1643  0b8e 02                 	!byte $02			;12 ora
  1644  0b8f 02                 	!byte $02			;13 ora
  1645  0b90 08                 	!byte $08			;14 trb
  1646  0b91 02                 	!byte $02			;15 ora
  1647  0b92 04                 	!byte $04			;16 asl
  1648  0b93 02                 	!byte $02			;17 ora
  1649  0b94 09                 	!byte $09			;18 clc
  1650  0b95 02                 	!byte $02			;19 ora
  1651  0b96 0a                 	!byte $0a			;1a inc
  1652  0b97 0b                 	!byte $0b			;1b tcs
  1653  0b98 08                 	!byte $08			;1c trb
  1654  0b99 02                 	!byte $02			;1d ora
  1655  0b9a 04                 	!byte $04			;1e asl
  1656  0b9b 02                 	!byte $02			;1f ora
  1657  0b9c 0d                 	!byte $0d			;20 jsr
  1658  0b9d 0c                 	!byte $0c			;21 and
  1659  0b9e 0e                 	!byte $0e			;22 jsl
  1660  0b9f 0c                 	!byte $0c			;23 and
  1661  0ba0 10                 	!byte $10			;24 bit
  1662  0ba1 0c                 	!byte $0c			;25 and
  1663  0ba2 11                 	!byte $11			;26 rol
  1664  0ba3 0c                 	!byte $0c			;27 and
  1665  0ba4 12                 	!byte $12			;28 plp
  1666  0ba5 0c                 	!byte $0c			;29 and
  1667  0ba6 11                 	!byte $11			;2a rol
  1668  0ba7 13                 	!byte $13			;2b pld
  1669  0ba8 10                 	!byte $10			;2c bit
  1670  0ba9 0c                 	!byte $0c			;2d and
  1671  0baa 11                 	!byte $11			;2e rol
  1672  0bab 0c                 	!byte $0c			;2f and
  1673  0bac 14                 	!byte $14			;30 bmi
  1674  0bad 0c                 	!byte $0c			;31 and
  1675  0bae 0c                 	!byte $0c			;32 and
  1676  0baf 0c                 	!byte $0c			;33 and
  1677  0bb0 11                 	!byte $11			;34 bit
  1678  0bb1 0c                 	!byte $0c			;35 and
  1679  0bb2 11                 	!byte $11			;36 rol
  1680  0bb3 0c                 	!byte $0c			;37 and
  1681  0bb4 15                 	!byte $15			;38 sec
  1682  0bb5 0c                 	!byte $0c			;39 and
  1683  0bb6 0f                 	!byte $0f			;3a dec
  1684  0bb7 16                 	!byte $16			;3b tsc
  1685  0bb8 11                 	!byte $11			;3c bit
  1686  0bb9 0c                 	!byte $0c			;3d and
  1687  0bba 11                 	!byte $11			;3e rol
  1688  0bbb 0c                 	!byte $0c			;3f and
  1689  0bbc 17                 	!byte $17			;40 ???
  1690  0bbd 18                 	!byte $18			;41 eor
  1691  0bbe 19                 	!byte $19			;42 wdm
  1692  0bbf 18                 	!byte $18			;43 eor
  1693  0bc0 17                 	!byte $17			;44 ???
  1694  0bc1 18                 	!byte $18			;45 eor
  1695  0bc2 1a                 	!byte $1a			;46 lsr
  1696  0bc3 18                 	!byte $18			;47 eor
  1697  0bc4 1b                 	!byte $1b			;48 pha
  1698  0bc5 18                 	!byte $18			;49 eor
  1699  0bc6 1a                 	!byte $1a			;4a lsr
  1700  0bc7 1c                 	!byte $1c			;4b phk
  1701  0bc8 1d                 	!byte $1d			;4c jmp
  1702  0bc9 18                 	!byte $18			;4d eor
  1703  0bca 1a                 	!byte $1a			;4e lsr
  1704  0bcb 18                 	!byte $18			;4f eor
  1705  0bcc 1e                 	!byte $1e			;50 bvc
  1706  0bcd 18                 	!byte $18			;51 eor
  1707  0bce 18                 	!byte $18			;52 eor
  1708  0bcf 18                 	!byte $18			;53 eor
  1709  0bd0 17                 	!byte $17			;54 ???
  1710  0bd1 18                 	!byte $18			;55 eor
  1711  0bd2 1a                 	!byte $1a			;56 lsr
  1712  0bd3 18                 	!byte $18			;57 eor
  1713  0bd4 1f                 	!byte $1f			;58 cli
  1714  0bd5 18                 	!byte $18			;59 eor
  1715  0bd6 20                 	!byte $20			;5a phy
  1716  0bd7 21                 	!byte $21			;5b tcd
  1717  0bd8 22                 	!byte $22			;5c jml
  1718  0bd9 18                 	!byte $18			;5d eor
  1719  0bda 1a                 	!byte $1a			;5e lsr
  1720  0bdb 18                 	!byte $18			;5f eor
  1721  0bdc 23                 	!byte $23			;60 rts
  1722  0bdd 24                 	!byte $24			;61 adc
  1723  0bde 25                 	!byte $25			;62 per
  1724  0bdf 24                 	!byte $24			;63 adc
  1725  0be0 26                 	!byte $26			;64 stz
  1726  0be1 24                 	!byte $24			;65 adc
  1727  0be2 27                 	!byte $27			;66 ror
  1728  0be3 24                 	!byte $24			;67 adc
  1729  0be4 28                 	!byte $28			;68 pla
  1730  0be5 24                 	!byte $24			;69 adc
  1731  0be6 27                 	!byte $27			;6a ror
  1732  0be7 29                 	!byte $29			;6b rtl
  1733  0be8 1d                 	!byte $1d			;6c jmp
  1734  0be9 24                 	!byte $24			;6d adc
  1735  0bea 27                 	!byte $27			;6e ror
  1736  0beb 24                 	!byte $24			;6f adc
  1737  0bec 2a                 	!byte $2a			;70 bvs
  1738  0bed 24                 	!byte $24			;71 adc
  1739  0bee 24                 	!byte $24			;72 adc
  1740  0bef 24                 	!byte $24			;73 adc
  1741  0bf0 26                 	!byte $26			;74 stz
  1742  0bf1 24                 	!byte $24			;75 adc
  1743  0bf2 27                 	!byte $27			;76 ror
  1744  0bf3 24                 	!byte $24			;77 adc
  1745  0bf4 2b                 	!byte $2b			;78 sei
  1746  0bf5 24                 	!byte $24			;79 adc
  1747  0bf6 2c                 	!byte $2c			;7a ply
  1748  0bf7 2d                 	!byte $2d			;7b tdc
  1749  0bf8 1d                 	!byte $1d			;7c jmp
  1750  0bf9 24                 	!byte $24			;7d adc
  1751  0bfa 27                 	!byte $27			;7e ror
  1752  0bfb 24                 	!byte $24			;7f adc
  1753  0bfc 2e                 	!byte $2e			;80 bra
  1754  0bfd 2f                 	!byte $2f			;81 sta
  1755  0bfe 30                 	!byte $30			;82 brl
  1756  0bff 2f                 	!byte $2f			;83 sta
  1757  0c00 31                 	!byte $31			;84 sty
  1758  0c01 2f                 	!byte $2f			;85 sta
  1759  0c02 32                 	!byte $32			;86 stx
  1760  0c03 2f                 	!byte $2f			;87 sta
  1761  0c04 33                 	!byte $33			;88 dey
  1762  0c05 10                 	!byte $10			;89 bit
  1763  0c06 34                 	!byte $34			;8a txa
  1764  0c07 35                 	!byte $35			;8b phb
  1765  0c08 31                 	!byte $31			;8c sty
  1766  0c09 2f                 	!byte $2f			;8d sta
  1767  0c0a 32                 	!byte $32			;8e stx
  1768  0c0b 2f                 	!byte $2f			;8f sta
  1769  0c0c 36                 	!byte $36			;90 bcc
  1770  0c0d 2f                 	!byte $2f			;91 sta
  1771  0c0e 2f                 	!byte $2f			;92 sta
  1772  0c0f 2f                 	!byte $2f			;93 sta
  1773  0c10 31                 	!byte $31			;94 sty
  1774  0c11 2f                 	!byte $2f			;95 sta
  1775  0c12 32                 	!byte $32			;96 stx
  1776  0c13 2f                 	!byte $2f			;97 sta
  1777  0c14 37                 	!byte $37			;98 tya
  1778  0c15 2f                 	!byte $2f			;99 sta
  1779  0c16 38                 	!byte $38			;9a txs
  1780  0c17 39                 	!byte $39			;9b txy
  1781  0c18 26                 	!byte $26			;9c stz
  1782  0c19 2f                 	!byte $2f			;9d sta
  1783  0c1a 26                 	!byte $26			;9e stz
  1784  0c1b 2f                 	!byte $2f			;9f sta
  1785  0c1c 3c                 	!byte $3c			;a0 ldy
  1786  0c1d 3a                 	!byte $3a			;a1 lda
  1787  0c1e 3b                 	!byte $3b			;a2 ldx
  1788  0c1f 3a                 	!byte $3a			;a3 lda
  1789  0c20 3c                 	!byte $3c			;a4 ldy
  1790  0c21 3a                 	!byte $3a			;a5 lda
  1791  0c22 3b                 	!byte $3b			;a6 ldx
  1792  0c23 3a                 	!byte $3a			;a7 lda
  1793  0c24 3d                 	!byte $3d			;a8 tay
  1794  0c25 3a                 	!byte $3a			;a9 lda
  1795  0c26 3e                 	!byte $3e			;aa tax
  1796  0c27 3f                 	!byte $3f			;ab plb
  1797  0c28 3c                 	!byte $3c			;ac ldy
  1798  0c29 3a                 	!byte $3a			;ad lda
  1799  0c2a 3b                 	!byte $3b			;ae ldx
  1800  0c2b 3a                 	!byte $3a			;af lda
  1801  0c2c 40                 	!byte $40			;b0 bcs
  1802  0c2d 3a                 	!byte $3a			;b1 lda
  1803  0c2e 3a                 	!byte $3a			;b2 lda
  1804  0c2f 3a                 	!byte $3a			;b3 lda
  1805  0c30 3c                 	!byte $3c			;b4 ldy
  1806  0c31 3a                 	!byte $3a			;b5 lda
  1807  0c32 3b                 	!byte $3b			;b6 ldx
  1808  0c33 3a                 	!byte $3a			;b7 lda
  1809  0c34 41                 	!byte $41			;b8 clv
  1810  0c35 3a                 	!byte $3a			;b9 lda
  1811  0c36 42                 	!byte $42			;ba tsx
  1812  0c37 43                 	!byte $43			;bb tyx
  1813  0c38 3c                 	!byte $3c			;bc ldy
  1814  0c39 3a                 	!byte $3a			;bd lda
  1815  0c3a 3b                 	!byte $3b			;be ldx
  1816  0c3b 3a                 	!byte $3a			;bf lda
  1817  0c3c 46                 	!byte $46			;c0 cpy
  1818  0c3d 44                 	!byte $44			;c1 cmp
  1819  0c3e 47                 	!byte $47			;c2 rep
  1820  0c3f 44                 	!byte $44			;c3 cmp
  1821  0c40 46                 	!byte $46			;c4 cpy
  1822  0c41 44                 	!byte $44			;c5 cmp
  1823  0c42 48                 	!byte $48			;c6 dec
  1824  0c43 44                 	!byte $44			;c7 cmp
  1825  0c44 49                 	!byte $49			;c8 iny
  1826  0c45 44                 	!byte $44			;c9 cmp
  1827  0c46 4a                 	!byte $4a			;ca dex
  1828  0c47 4b                 	!byte $4b			;cb wai
  1829  0c48 46                 	!byte $46			;cc cpy
  1830  0c49 44                 	!byte $44			;cd cmp
  1831  0c4a 48                 	!byte $48			;ce dec
  1832  0c4b 44                 	!byte $44			;cf cmp
  1833  0c4c 4c                 	!byte $4c			;d0 bne
  1834  0c4d 44                 	!byte $44			;d1 cmp
  1835  0c4e 44                 	!byte $44			;d2 cmp
  1836  0c4f 44                 	!byte $44			;d3 cmp
  1837  0c50 4d                 	!byte $4d			;d4 pei
  1838  0c51 44                 	!byte $44			;d5 cmp
  1839  0c52 48                 	!byte $48			;d6 dec
  1840  0c53 44                 	!byte $44			;d7 cmp
  1841  0c54 4e                 	!byte $4e			;d8 cld
  1842  0c55 44                 	!byte $44			;d9 cmp
  1843  0c56 4f                 	!byte $4f			;da phx
  1844  0c57 50                 	!byte $50			;db stp
  1845  0c58 22                 	!byte $22			;dc jml
  1846  0c59 44                 	!byte $44			;dd cmp
  1847  0c5a 48                 	!byte $48			;de dec
  1848  0c5b 44                 	!byte $44			;df cmp
  1849  0c5c 51                 	!byte $51			;e0 cpx
  1850  0c5d 45                 	!byte $45			;e1 sbc
  1851  0c5e 52                 	!byte $52			;e2 sep
  1852  0c5f 45                 	!byte $45			;e3 sbc
  1853  0c60 51                 	!byte $51			;e4 cpx
  1854  0c61 45                 	!byte $45			;e5 sbc
  1855  0c62 53                 	!byte $53			;e6 inc
  1856  0c63 45                 	!byte $45			;e7 sbc
  1857  0c64 54                 	!byte $54			;e8 inx
  1858  0c65 45                 	!byte $45			;e9 sbc
  1859  0c66 55                 	!byte $55			;ea nop
  1860  0c67 56                 	!byte $56			;eb xba
  1861  0c68 51                 	!byte $51			;ec cpx
  1862  0c69 45                 	!byte $45			;ed sbc
  1863  0c6a 53                 	!byte $53			;ee inc
  1864  0c6b 45                 	!byte $45			;ef sbc
  1865  0c6c 57                 	!byte $57			;f0 beq
  1866  0c6d 45                 	!byte $45			;f1 sbc
  1867  0c6e 45                 	!byte $45			;f2 sbc
  1868  0c6f 45                 	!byte $45			;f3 sbc
  1869  0c70 58                 	!byte $58			;f4 pea
  1870  0c71 45                 	!byte $45			;f5 sbc
  1871  0c72 53                 	!byte $53			;f6 inc
  1872  0c73 45                 	!byte $45			;f7 sbc
  1873  0c74 59                 	!byte $59			;f8 sed
  1874  0c75 45                 	!byte $45			;f9 sbc
  1875  0c76 5a                 	!byte $5a			;fa plx
  1876  0c77 5b                 	!byte $5b			;fb xce
  1877  0c78 0d                 	!byte $0d			;fc jsr
  1878  0c79 45                 	!byte $45			;fd sbc
  1879  0c7a 53                 	!byte $53			;fe inc
  1880  0c7b 45                 	!byte $45			;ff sbc
  1881                          mnems
  1882  0c7c 42524b             	!tx "BRK"			;0
  1883  0c7f 434f50             	!tx "COP"			;1
  1884  0c82 4f5241             	!tx "ORA"			;2
  1885  0c85 545342             	!tx "TSB"			;3
  1886  0c88 41534c             	!tx "ASL"			;4
  1887  0c8b 504850             	!tx "PHP"			;5
  1888  0c8e 504844             	!tx "PHD"			;6
  1889  0c91 42504c             	!tx "BPL"			;7
  1890  0c94 545242             	!tx "TRB"			;8
  1891  0c97 434c43             	!tx "CLC"			;9
  1892  0c9a 494e43             	!tx "INC"			;a
  1893  0c9d 544353             	!tx "TCS"			;b
  1894  0ca0 414e44             	!tx "AND"			;c
  1895  0ca3 4a5352             	!tx "JSR"			;d
  1896  0ca6 4a534c             	!tx "JSL"			;e
  1897  0ca9 444543             	!tx "DEC"			;f
  1898  0cac 424954             	!tx "BIT"			;10
  1899  0caf 524f4c             	!tx "ROL"			;11
  1900  0cb2 504c50             	!tx "PLP"			;12
  1901  0cb5 504c44             	!tx "PLD"			;13
  1902  0cb8 424d49             	!tx "BMI"			;14
  1903  0cbb 534543             	!tx "SEC"			;15
  1904  0cbe 545343             	!tx "TSC"			;16
  1905  0cc1 3f3f3f             	!tx "???"			;17
  1906  0cc4 454f52             	!tx "EOR"			;18
  1907  0cc7 57444d             	!tx "WDM"			;19
  1908  0cca 4c5352             	!tx "LSR"			;1a
  1909  0ccd 504841             	!tx "PHA"			;1b
  1910  0cd0 50484b             	!tx "PHK"			;1c
  1911  0cd3 4a4d50             	!tx "JMP"			;1d
  1912  0cd6 425643             	!tx "BVC"			;1e
  1913  0cd9 434c49             	!tx "CLI"			;1f
  1914  0cdc 504859             	!tx "PHY"			;20
  1915  0cdf 544344             	!tx "TCD"			;21
  1916  0ce2 4a4d4c             	!tx "JML"			;22
  1917  0ce5 525453             	!tx "RTS"			;23
  1918  0ce8 414443             	!tx "ADC"			;24
  1919  0ceb 504552             	!tx "PER"			;25
  1920  0cee 53545a             	!tx "STZ"			;26
  1921  0cf1 524f52             	!tx "ROR"			;27
  1922  0cf4 504c41             	!tx "PLA"			;28
  1923  0cf7 52544c             	!tx "RTL"			;29
  1924  0cfa 425653             	!tx "BVS"			;2a
  1925  0cfd 534549             	!tx "SEI"			;2b
  1926  0d00 504c59             	!tx "PLY"			;2c
  1927  0d03 544443             	!tx "TDC"			;2d
  1928  0d06 425241             	!tx "BRA"			;2e
  1929  0d09 535441             	!tx "STA"			;2f
  1930  0d0c 42524c             	!tx "BRL"			;30
  1931  0d0f 535459             	!tx "STY"			;31
  1932  0d12 535458             	!tx "STX"			;32
  1933  0d15 444559             	!tx "DEY"			;33
  1934  0d18 545841             	!tx "TXA"			;34
  1935  0d1b 504842             	!tx "PHB"			;35
  1936  0d1e 424343             	!tx "BCC"			;36
  1937  0d21 545941             	!tx "TYA"			;37
  1938  0d24 545853             	!tx "TXS"			;38
  1939  0d27 545859             	!tx "TXY"			;39
  1940  0d2a 4c4441             	!tx "LDA"			;3a
  1941  0d2d 4c4458             	!tx "LDX"			;3b
  1942  0d30 4c4459             	!tx "LDY"			;3c
  1943  0d33 544159             	!tx "TAY"			;3d
  1944  0d36 544158             	!tx "TAX"			;3e
  1945  0d39 504c42             	!tx "PLB"			;3f
  1946  0d3c 424353             	!tx "BCS"			;40
  1947  0d3f 434c56             	!tx "CLV"			;41
  1948  0d42 545358             	!tx "TSX"			;42
  1949  0d45 545958             	!tx "TYX"			;43
  1950  0d48 434d50             	!tx "CMP"			;44
  1951  0d4b 534243             	!tx "SBC"			;45
  1952  0d4e 435059             	!tx "CPY"			;46
  1953  0d51 524550             	!tx "REP"			;47
  1954  0d54 444543             	!tx "DEC"			;48
  1955  0d57 494e59             	!tx "INY"			;49
  1956  0d5a 444558             	!tx "DEX"			;4a
  1957  0d5d 574149             	!tx "WAI"			;4b
  1958  0d60 424e45             	!tx "BNE"			;4c
  1959  0d63 504549             	!tx "PEI"			;4d
  1960  0d66 434c44             	!tx "CLD"			;4e
  1961  0d69 504858             	!tx "PHX"			;4f
  1962  0d6c 535450             	!tx "STP"			;50
  1963  0d6f 435058             	!tx "CPX"			;51
  1964  0d72 534550             	!tx "SEP"			;52
  1965  0d75 494e43             	!tx "INC"			;53
  1966  0d78 494e58             	!tx "INX"			;54
  1967  0d7b 4e4f50             	!tx "NOP"			;55
  1968  0d7e 584241             	!tx "XBA"			;56
  1969  0d81 424551             	!tx "BEQ"			;57
  1970  0d84 504541             	!tx "PEA"			;58
  1971  0d87 534544             	!tx "SED"			;59
  1972  0d8a 504c58             	!tx "PLX"			;5a
  1973  0d8d 584345             	!tx "XCE"			;5b
  1974                          	
  1975                          	!zone ucline
  1976                          ucline					;convert inbuff at $170400 to upper case
  1977  0d90 08                 	php
  1978  0d91 c210               	rep #$10
  1979  0d93 e220               	sep #$20
  1980                          	!as
  1981                          	!rl
  1982  0d95 a20000             	ldx #$0000
  1983                          .local2
  1984  0d98 bf000417           	lda inbuff,x
  1985  0d9c f012               	beq .local4			;hit the zero, so bail
  1986  0d9e c961               	cmp #'a'
  1987  0da0 900b               	bcc .local3			;less then lowercase a, so ignore
  1988  0da2 c97b               	cmp #'z' + 1		;less than next character after lowercase z?
  1989  0da4 b007               	bcs .local3			;greater than or equal, so ignore
  1990  0da6 38                 	sec
  1991  0da7 e920               	sbc #('z' - 'Z')	;make upper case
  1992  0da9 9f000417           	sta inbuff,x
  1993                          .local3
  1994  0dad e8                 	inx
  1995  0dae 80e8               	bra .local2
  1996                          .local4
  1997  0db0 28                 	plp
  1998  0db1 6b                 	rtl
  1999                          	
  2000                          	!zone getline
  2001                          getline
  2002  0db2 08                 	php
  2003  0db3 c210               	rep #$10
  2004  0db5 e220               	sep #$20
  2005                          	!as
  2006                          	!rl
  2007  0db7 a20000             	ldx #$0000
  2008                          .local2
  2009  0dba af00fc1b           	lda IO_KEYQ_SIZE
  2010  0dbe f0fa               	beq .local2
  2011  0dc0 af01fc1b           	lda IO_KEYQ_WAITING
  2012  0dc4 8f02fc1b           	sta IO_KEYQ_DEQUEUE
  2013  0dc8 c90d               	cmp #$0d			;carriage return yet?
  2014  0dca f01c               	beq .local3
  2015  0dcc c908               	cmp #$08			;backspace/back arrow?
  2016  0dce f029               	beq .local4
  2017  0dd0 c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
  2018  0dd2 90e6               	bcc .local2		 		;yes, so ignore it
  2019  0dd4 9f000417           	sta inbuff,x 		;any other character, so register it and store it
  2020  0dd8 8f12fc1b           	sta IO_CON_CHAROUT
  2021  0ddc 8f13fc1b           	sta IO_CON_REGISTER
  2022  0de0 e8                 	inx
  2023  0de1 a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
  2024  0de3 e0fe03             	cpx #$3fe			;overrun end of buffer yet?
  2025  0de6 d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
  2026                          .local3
  2027  0de8 9f000417           	sta inbuff,x		;store CR
  2028  0dec 8f17fc1b           	sta IO_CON_CR
  2029  0df0 e8                 	inx
  2030  0df1 a900               	lda #$00			;store zero to end it all
  2031  0df3 9f000417           	sta inbuff,x
  2032  0df7 28                 	plp
  2033  0df8 6b                 	rtl
  2034                          .local4
  2035  0df9 e00000             	cpx #$0000
  2036  0dfc f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
  2037  0dfe a908               	lda #$08
  2038  0e00 8f12fc1b           	sta IO_CON_CHAROUT
  2039  0e04 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
  2040  0e08 a920               	lda #$20
  2041  0e0a 8f12fc1b           	sta IO_CON_CHAROUT
  2042  0e0e 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
  2043  0e12 a908               	lda #$08
  2044  0e14 8f12fc1b           	sta IO_CON_CHAROUT
  2045  0e18 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
  2046  0e1c ca                 	dex
  2047  0e1d 809b               	bra .local2
  2048                          	
  2049                          prinbuff				;feed location of input buffer into dpla and then print
  2050  0e1f 08                 	php
  2051  0e20 c210               	rep #$10
  2052  0e22 e220               	sep #$20
  2053                          	!as
  2054                          	!rl
  2055  0e24 a917               	lda #$17
  2056  0e26 853f               	sta dpla_h
  2057  0e28 a904               	lda #$04
  2058  0e2a 853e               	sta dpla_m
  2059  0e2c 643d               	stz dpla
  2060  0e2e 22340e1c           	jsl l_prcdpla
  2061  0e32 28                 	plp
  2062  0e33 6b                 	rtl
  2063                          	
  2064                          	!zone prcdpla
  2065                          prcdpla					; print C string pointed to by dp locations $3d-$3f
  2066  0e34 08                 	php
  2067  0e35 c210               	rep #$10
  2068  0e37 e220               	sep #$20
  2069                          	!as
  2070                          	!rl
  2071  0e39 a00000             	ldy #$0000
  2072                          .local2
  2073  0e3c b73d               	lda [dpla],y
  2074  0e3e f00b               	beq .local3
  2075  0e40 8f12fc1b           	sta IO_CON_CHAROUT
  2076  0e44 8f13fc1b           	sta IO_CON_REGISTER
  2077  0e48 c8                 	iny
  2078  0e49 80f1               	bra .local2
  2079                          .local3
  2080  0e4b 28                 	plp
  2081  0e4c 6b                 	rtl
  2082                          
  2083                          initstring
  2084  0e4d 494d4c2036353831...	!tx "IML 65816 1C Firmware v00"
  2085  0e66 0d                 	!byte 0x0d
  2086  0e67 53797374656d204d...	!tx "System Monitor"
  2087  0e75 0d                 	!byte 0x0d
  2088  0e76 0d                 	!byte 0x0d
  2089  0e77 00                 	!byte 0
  2090                          
  2091                          helpmsg
  2092  0e78 494d4c2036353831...	!tx "IML 65816 Monitor Commands"
  2093  0e92 0d                 	!byte $0d
  2094  0e93 41203c616464723e...	!tx "A <addr>  Dump ASCII"
  2095  0ea7 0d                 	!byte $0d
  2096  0ea8 42203c62616e6b3e...	!tx "B <bank>  Change bank"
  2097  0ebd 0d                 	!byte $0d
  2098  0ebe 43203c636f6c6f72...	!tx "C <color> Change terminal colors"
  2099  0ede 0d                 	!byte $0d
  2100  0edf 44203c616464723e...	!tx "D <addr>  Dump hex"
  2101  0ef1 0d                 	!byte $0d
  2102  0ef2 45203c616464723e...	!tx "E <addr> <byte> <byte>...  Enter bytes"
  2103  0f18 0d                 	!byte $0d
  2104  0f19 463f202020202020...	!tx "F?        Floating Point Support Help"
  2105  0f3e 0d                 	!byte $0d
  2106  0f3f 4c203c616464723e...	!tx "L <addr>  Disassemble 65816 Inst."
  2107  0f60 0d                 	!byte $0d
  2108  0f61 4d203c6d6f64653e...	!tx "M <mode>  Change video mode, 8/9"
  2109  0f81 0d                 	!byte $0d
  2110  0f82 5120202020202020...	!tx "Q         Halt the processor"
  2111  0f9e 0d                 	!byte $0d
  2112  0f9f 3f20202020202020...	!tx "?         This menu"
  2113  0fb2 0d                 	!byte $0d
  2114  0fb3 3c656e7465723e20...	!tx "<enter>   Repeat last dump command"
  2115  0fd5 0d                 	!byte $0d
  2116  0fd6 546f207370656369...	!tx "To specify range, use <addr1.addr2>"
  2117  0ff9 0d00               	!byte $0d, 00
  2118                          
  2119                          fphelpmsg
  2120  0ffb 494d4c20466c6f61...	!tx "IML Floating Point Support"
  2121  1015 0d                 	!byte $0d
  2122  1016 466f726d61743a20...	!tx "Format: F<cmd><sz><reg>"
  2123  102d 0d                 	!byte $0d
  2124  102e 53697a65733a2046...	!tx "Sizes: F=float D=double E=extended"
  2125  1050 0d                 	!byte $0d
  2126  1051 5265676973746572...	!tx "Registers: A=FACC B=FARG"
  2127  1069 0d                 	!byte $0d
  2128  106a 46443c737a3e2020...	!tx "FD<sz>    Display FACC/FARG"
  2129  1085 0d                 	!byte $0d
  2130  1086 46433c737a3e3c72...	!tx "FC<sz><reg> <constID> Load Constant"
  2131  10a9 0d                 	!byte $0d
  2132  10aa 463c6f703e3c737a...	!tx "F<op><sz><reg> Bin Op, result in <reg>"
  2133  10d0 0d                 	!byte $0d
  2134  10d1 42696e617279204f...	!tx "Binary Ops: *, /, +, -"
  2135  10e7 0d                 	!tx $0d
  2136  10e8 464e3c737a3e3c72...	!tx "FN<sz><reg> Natural Log of <reg>"
  2137  1108 0d                 	!tx $0d
  2138  1109 00                 	!byte $00
  2139                          	
  2140  110a 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
  2141                          

; ******** done
