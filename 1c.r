
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
    30                          IO_FP_ISAVE = $1bfc48
    31                          
    32                          FPCOND = $1bfcbf
    33                          FPASCII = $1bfcc0
    34                          FPASCII_LO16 = $fcc0
    35                          FPINT = $1bfcd8
    36                          FPACCUMULATOR = $1bfce0
    37                          FPARGUMENT = $1bfcf0
    38                          
    39                          promptchar = '*'
    40                          
    41                          l_getline = $1c0000 + getline
    42                          l_prinbuff = $1c0000 + prinbuff
    43                          l_prcdpla = $1c0000 + prcdpla
    44                          l_ucline = $1c0000 + ucline
    45                          
    46                          fpregspec = $28
    47                          fpmask = $29
    48                          scratch2 = $2a
    49                          scratch2_m = $2b
    50                          scratch2_h = $2c
    51                          alarge = $2d
    52                          xlarge = $2e
    53                          scratch1 = $2f
    54                          enterbytes = $30
    55                          enterbytes_m = $31
    56                          enterbytes_h = $32
    57                          rangehigh = $33
    58                          monrange = $35
    59                          monlast = $36
    60                          parseptr = $37
    61                          parseptr_m = $38
    62                          parseptr_h = $39
    63                          mondump = $3a
    64                          mondump_m = $3b
    65                          mondump_h = $3c
    66                          dpla = $3d
    67                          dpla_m = $3e
    68                          dpla_h = $3f
    69                          
    70                          inbuff = $170400
    71                          
    72                          x1crominit
    73  0000 4b                 	phk
    74  0001 ab                 	plb
    75  0002 c210               	rep #$10
    76                          	!rl
    77  0004 e220               	sep #$20
    78                          	!as
    79  0006 a2be0e             	ldx #initstring
    80  0009 863d               	stx dpla
    81  000b a91c               	lda #$1c
    82  000d 853f               	sta dpla_h
    83  000f 22a50e1c           	jsl l_prcdpla
    84  0013 4cdb03             	jmp+2 monstart
    85                          
    86                          parse_setup
    87  0016 a20004             	ldx #$0400
    88  0019 8637               	stx parseptr
    89  001b a917               	lda #$17
    90  001d 8539               	sta parseptr_h
    91  001f 60                 	rts
    92                          	
    93                          	!zone parse_getchar
    94                          parse_getchar			;get char from inbuff, assumes 8 bit A, 16 bit X
    95  0020 a737               	lda [parseptr]
    96  0022 48                 	pha
    97  0023 e637               	inc parseptr
    98  0025 d006               	bne .local2
    99  0027 e638               	inc parseptr_m
   100  0029 d002               	bne .local2
   101  002b e639               	inc parseptr_h
   102                          .local2
   103  002d 68                 	pla
   104  002e 60                 	rts
   105                          	
   106                          	!zone parse_addr
   107                          parse_addr				;see if user specified an address on line.
   108  002f a900               	lda #$00
   109  0031 48                 	pha
   110  0032 48                 	pha					;make space for working value on the stack
   111  0033 8535               	sta monrange		;clear range flag
   112                          .throwaway
   113  0035 202000             	jsr+2 parse_getchar
   114  0038 c920               	cmp #' '
   115  003a f0f9               	beq .throwaway		;throw away leading spaces
   116  003c 209800             	jsr+2 parse_getnib2	;get first nibble. call 2nd entry point since we already have character
   117  003f 9051               	bcc .no				;didn't even get one hex character, so return false
   118  0041 8301               	sta 1,s				;save it on the stack for now
   119  0043 209500             	jsr+2 parse_getnib	;get second nibble
   120  0046 9047               	bcc .yes			;if not hex then bail
   121  0048 48                 	pha
   122  0049 a302               	lda 2,s
   123  004b 0a                 	asl
   124  004c 0a                 	asl
   125  004d 0a                 	asl
   126  004e 0a                 	asl
   127  004f 0301               	ora 1,s
   128  0051 8302               	sta 2,s
   129  0053 68                 	pla					;add to stack
   130  0054 209500             	jsr+2 parse_getnib	;get possible third nibble
   131  0057 9036               	bcc .yes
   132  0059 c230               	rep #$30			;we're dealing with a 16 bit value now
   133                          	!al
   134  005b 290f00             	and #$000f
   135  005e 48                 	pha
   136  005f a303               	lda 3,s
   137  0061 0a                 	asl
   138  0062 0a                 	asl
   139  0063 0a                 	asl
   140  0064 0a                 	asl
   141  0065 0301               	ora 1,s
   142  0067 8303               	sta 3,s
   143  0069 68                 	pla
   144  006a e220               	sep #$20
   145                          	!as
   146  006c 209500             	jsr+2 parse_getnib
   147  006f 901e               	bcc .yes
   148  0071 c230               	rep #$30
   149                          	!al
   150  0073 290f00             	and #$000f
   151  0076 48                 	pha
   152  0077 a303               	lda 3,s
   153  0079 0a                 	asl
   154  007a 0a                 	asl
   155  007b 0a                 	asl
   156  007c 0a                 	asl
   157  007d 0301               	ora 1,s
   158  007f 8303               	sta 3,s
   159  0081 68                 	pla
   160  0082 e220               	sep #$20			;fall thru to yes on 4th nibble
   161                          	!as
   162  0084 202000             	jsr parse_getchar	;check to see if next char is a . so we can specify ranges
   163  0087 c92e               	cmp #'.'
   164  0089 d004               	bne .yes
   165  008b a980               	lda #$80
   166  008d 8535               	sta monrange
   167                          .yes
   168  008f 7a                 	ply					;get 16 bit work address off of stack
   169  0090 38                 	sec					;got address, return
   170  0091 60                 	rts
   171                          .no
   172  0092 7a                 	ply					;clear stack
   173  0093 18                 	clc					;no address found, return
   174  0094 60                 	rts
   175                          parse_getnib
   176  0095 202000             	jsr parse_getchar
   177                          parse_getnib2			;enter here after we've thrown away leading spaces
   178  0098 c920               	cmp #' '
   179  009a f021               	beq .outrng			;space = end of value
   180  009c c92e               	cmp #'.'
   181  009e d006               	bne .notrange
   182  00a0 a980               	lda #$80
   183  00a2 8535               	sta monrange		;this is the start of a range specification
   184  00a4 18                 	clc
   185  00a5 60                 	rts
   186                          .notrange
   187  00a6 c941               	cmp #$41
   188  00a8 900b               	bcc .outrnga
   189  00aa c947               	cmp #$47
   190  00ac b007               	bcs .outrnga
   191  00ae 38                 	sec
   192  00af e907               	sbc #$07			;in range of A-F
   193                          .success
   194  00b1 290f               	and #$0f
   195  00b3 38                 	sec
   196  00b4 60                 	rts
   197                          .outrnga				;test if 0-9
   198  00b5 c930               	cmp #$30
   199  00b7 9004               	bcc .outrng
   200  00b9 c93a               	cmp #$3a
   201  00bb 90f4               	bcc .success		;less than 3a, but >= 30, else fall thru to outrng
   202                          .outrng
   203  00bd 18                 	clc
   204  00be 60                 	rts
   205                          	
   206                          prdumpaddr
   207  00bf a53c               	lda mondump_h			;print long address
   208  00c1 20dc05             	jsr+2 prhex
   209  00c4 a92f               	lda #'/'
   210  00c6 8f12fc1b           	sta IO_CON_CHAROUT
   211  00ca 8f13fc1b           	sta IO_CON_REGISTER
   212  00ce a63a               	ldx mondump
   213  00d0 20d205             	jsr+2 prhex16
   214  00d3 a92d               	lda #'-'
   215  00d5 8f12fc1b           	sta IO_CON_CHAROUT
   216  00d9 8f13fc1b           	sta IO_CON_REGISTER
   217  00dd a920               	lda #' '
   218  00df 8f12fc1b           	sta IO_CON_CHAROUT
   219  00e3 8f13fc1b           	sta IO_CON_REGISTER
   220  00e7 60                 	rts
   221                          	
   222                          adjdumpaddr					;add 8 to dump address
   223  00e8 c230               	rep #$30
   224                          	!al
   225  00ea a53a               	lda mondump
   226  00ec 18                 	clc
   227  00ed 690800             	adc #$0008
   228  00f0 853a               	sta mondump
   229  00f2 e220               	sep #$20
   230                          	!as
   231  00f4 08                 	php						;save carry state.. did we carry to the bank?
   232  00f5 a53c               	lda mondump_h
   233  00f7 6900               	adc #$00
   234  00f9 853c               	sta mondump_h
   235  00fb 28                 	plp
   236  00fc 60                 	rts
   237                          
   238                          	!zone fpcmd
   239                          fphelp
   240  00fd a26c10             	ldx #fphelpmsg
   241  0100 863d               	stx dpla
   242  0102 a91c               	lda #$1c
   243  0104 853f               	sta dpla_h
   244  0106 22a50e1c           	jsl l_prcdpla
   245  010a 4cee03             	jmp moncmd
   246                          fpcmd
   247  010d 202000             	jsr parse_getchar
   248  0110 c93f               	cmp #'?'
   249  0112 f0e9               	beq fphelp
   250  0114 c944               	cmp #'D'
   251  0116 d003               	bne .fpcmd1
   252  0118 4c6b02             	jmp fpdisp
   253                          .fpcmd1
   254  011b c943               	cmp #'C'
   255  011d d003               	bne .fpcmd2
   256  011f 4c4602             	jmp fploadconst
   257                          .fpcmd2
   258  0122 c92a               	cmp #'*'
   259  0124 d003               	bne .fpcmd6
   260  0126 4cda01             	jmp fpmultiply
   261                          .fpcmd6
   262  0129 c92f               	cmp #'/'
   263  012b d003               	bne .fpcmd5
   264  012d 4cf501             	jmp fpdivide
   265                          .fpcmd5
   266  0130 c92b               	cmp #'+'
   267  0132 d003               	bne .fpcmd4
   268  0134 4c1002             	jmp fpadd
   269                          .fpcmd4
   270  0137 c92d               	cmp #'-'
   271  0139 d003               	bne .fpcmd3
   272  013b 4c2b02             	jmp fpsubtract
   273                          .fpcmd3
   274  013e c94e               	cmp #'N'
   275  0140 f07d               	beq fpln
   276  0142 c949               	cmp #'I'
   277  0144 f043               	beq fpiload
   278  0146 c956               	cmp #'V'
   279  0148 f05a               	beq fpisave
   280  014a 4c8603             	jmp monerror			;unrecognized FP command so fall thru to syntax error
   281                          
   282                          fpgetmask					;construct mask from size specifier, carry set if unregognized
   283  014d 202000             	jsr parse_getchar
   284  0150 c946               	cmp #'F'
   285  0152 d006               	bne .local1
   286  0154 a900               	lda #$00
   287  0156 8529               	sta fpmask				;set bits 5/7 of fp mask to 0
   288  0158 8016               	bra .local4
   289                          .local1
   290  015a c944               	cmp #'D'
   291  015c d006               	bne .local2
   292  015e a980               	lda #$80				;bit 7=1, bit 5=0
   293  0160 8529               	sta fpmask
   294  0162 800c               	bra .local4
   295                          .local2
   296  0164 c945               	cmp #'E'
   297  0166 d006               	bne .local3
   298  0168 a920               	lda #$20				;bit 7=0, bit 5=1
   299  016a 8529               	sta fpmask
   300  016c 8002               	bra .local4
   301                          .local3
   302  016e 38                 	sec						;unknown size
   303  016f 60                 	rts
   304                          .local4
   305  0170 18                 	clc
   306  0171 60                 	rts
   307                          	
   308                          fpgetregspec
   309  0172 202000             	jsr parse_getchar		;set fpregspec to 00 or 40 depending on register specified
   310  0175 c941               	cmp #'A'
   311  0177 d004               	bne .localgrs1
   312  0179 6428               	stz fpregspec
   313  017b 8008               	bra .localgrs3
   314                          .localgrs1
   315  017d c942               	cmp #'B'
   316  017f d006               	bne .localgrs4
   317  0181 a940               	lda #$40
   318  0183 8528               	sta fpregspec
   319                          .localgrs3
   320  0185 18                 	clc
   321  0186 60                 	rts
   322                          .localgrs4
   323  0187 38                 	sec
   324  0188 60                 	rts
   325                          
   326                          fpiload
   327  0189 204d01             	jsr fpgetmask
   328  018c 9003               	bcc .fpil1
   329  018e 4c8603             	jmp monerror
   330                          .fpil1
   331  0191 207201             	jsr fpgetregspec
   332  0194 9003               	bcc .fpil2
   333  0196 4c8603             	jmp monerror
   334                          .fpil2
   335  0199 a529               	lda fpmask
   336  019b 0528               	ora fpregspec
   337  019d 8f47fc1b           	sta IO_FP_ILOAD
   338  01a1 4cee03             	jmp moncmd
   339                          
   340                          fpisave
   341  01a4 204d01             	jsr fpgetmask
   342  01a7 9003               	bcc .fpis1
   343  01a9 4c8603             	jmp monerror
   344                          .fpis1
   345  01ac 207201             	jsr fpgetregspec
   346  01af 9003               	bcc .fpis2
   347  01b1 4c8603             	jmp monerror
   348                          .fpis2
   349  01b4 a529               	lda fpmask
   350  01b6 0528               	ora fpregspec
   351  01b8 8f48fc1b           	sta IO_FP_ISAVE
   352  01bc 4cee03             	jmp moncmd
   353                          
   354                          fpln
   355  01bf 204d01             	jsr fpgetmask
   356  01c2 9003               	bcc .fpln1
   357  01c4 4c8603             	jmp monerror
   358                          .fpln1
   359  01c7 207201             	jsr fpgetregspec
   360  01ca 9003               	bcc .fpln2
   361  01cc 4c8603             	jmp monerror
   362                          .fpln2
   363  01cf a529               	lda fpmask
   364  01d1 0528               	ora fpregspec
   365  01d3 8f46fc1b           	sta IO_FP_LN
   366  01d7 4cee03             	jmp moncmd
   367                          	
   368                          fpmultiply
   369  01da 204d01             	jsr fpgetmask
   370  01dd 9003               	bcc .fpmultiply1
   371  01df 4c8603             	jmp monerror
   372                          .fpmultiply1
   373  01e2 207201             	jsr fpgetregspec
   374  01e5 9003               	bcc .fpmultiply2
   375  01e7 4c8603             	jmp monerror
   376                          .fpmultiply2
   377  01ea a529               	lda fpmask
   378  01ec 0528               	ora fpregspec
   379  01ee 8f42fc1b           	sta IO_FP_MULTIPLY
   380  01f2 4cee03             	jmp moncmd
   381                          	
   382                          fpdivide
   383  01f5 204d01             	jsr fpgetmask
   384  01f8 9003               	bcc .fpdivide1
   385  01fa 4c8603             	jmp monerror
   386                          .fpdivide1
   387  01fd 207201             	jsr fpgetregspec
   388  0200 9003               	bcc .fpdivide2
   389  0202 4c8603             	jmp monerror
   390                          .fpdivide2
   391  0205 a529               	lda fpmask
   392  0207 0528               	ora fpregspec
   393  0209 8f43fc1b           	sta IO_FP_DIVIDE
   394  020d 4cee03             	jmp moncmd
   395                          	
   396                          fpadd
   397  0210 204d01             	jsr fpgetmask
   398  0213 9003               	bcc .fpadd1
   399  0215 4c8603             	jmp monerror
   400                          .fpadd1
   401  0218 207201             	jsr fpgetregspec
   402  021b 9003               	bcc .fpadd2
   403  021d 4c8603             	jmp monerror
   404                          .fpadd2
   405  0220 a529               	lda fpmask
   406  0222 0528               	ora fpregspec
   407  0224 8f44fc1b           	sta IO_FP_ADD
   408  0228 4cee03             	jmp moncmd
   409                          	
   410                          fpsubtract
   411  022b 204d01             	jsr fpgetmask
   412  022e 9003               	bcc .fpsubtract1
   413  0230 4c8603             	jmp monerror
   414                          .fpsubtract1
   415  0233 207201             	jsr fpgetregspec
   416  0236 9003               	bcc .fpsubtract2
   417  0238 4c8603             	jmp monerror
   418                          .fpsubtract2
   419  023b a529               	lda fpmask
   420  023d 0528               	ora fpregspec
   421  023f 8f45fc1b           	sta IO_FP_SUBTRACT
   422  0243 4cee03             	jmp moncmd
   423                          	
   424                          fploadconst
   425  0246 204d01             	jsr fpgetmask
   426  0249 9003               	bcc .fploadconst1
   427  024b 4c8603             	jmp monerror
   428                          .fploadconst1
   429  024e 207201             	jsr fpgetregspec
   430  0251 9003               	bcc .fploadconst2
   431  0253 4c8603             	jmp monerror
   432                          .fploadconst2
   433  0256 202f00             	jsr parse_addr			;get const specifier
   434  0259 c230               	rep #$30
   435  025b 98                 	tya
   436  025c e220               	sep #$20
   437  025e 291f               	and #$1f				;we're only interested in values 0-31
   438  0260 0529               	ora fpmask
   439  0262 0528               	ora fpregspec
   440  0264 8f40fc1b           	sta IO_FP_INIT_CONSTANT
   441  0268 4cee03             	jmp moncmd
   442                          
   443                          fpdisp
   444  026b 204d01             	jsr fpgetmask
   445  026e 9022               	bcc fpdisp2
   446  0270 4c8603             	jmp monerror
   447                          fpfacctxt
   448  0273 464143433a20       	!tx "FACC: "
   449  0279 00                 	!byte $00
   450                          fpfargtxt
   451  027a 464152473a20       	!tx "FARG: "
   452  0280 00                 	!byte $00
   453                          fpcondtxt
   454  0281 4650434f4e443a20   	!tx "FPCOND: "
   455  0289 00                 	!byte $00
   456                          fpinttxt
   457  028a 4650494e543a20     	!tx "FPINT: "
   458  0291 00                 	!byte $00
   459                          fpdisp2
   460  0292 a27302             	ldx #fpfacctxt			;print FACC: tag
   461  0295 863d               	stx dpla
   462  0297 a91c               	lda #$1c
   463  0299 853f               	sta dpla_h
   464  029b 22a50e1c           	jsl l_prcdpla
   465  029f a20900             	ldx #9
   466  02a2 a529               	lda fpmask
   467  02a4 2920               	and #$20
   468  02a6 d00c               	bne .facchex			;bit 5 set, so fall through and print 10 bytes
   469  02a8 a20700             	ldx #7
   470  02ab a529               	lda fpmask
   471  02ad 2980               	and #$80
   472  02af d003               	bne .facchex			;bit 5 clear, but bit 7 set, print 8 bytes
   473  02b1 a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   474                          .facchex					;print X number of hex bytes in reverse order
   475  02b4 bfe0fc1b           	lda FPACCUMULATOR,x
   476  02b8 20dc05             	jsr+2 prhex
   477  02bb ca                 	dex
   478  02bc 10f6               	bpl .facchex
   479  02be a529               	lda fpmask
   480  02c0 8f41fc1b           	sta IO_FP_TO_ASCII
   481  02c4 a92f               	lda #'/'
   482  02c6 8f12fc1b           	sta IO_CON_CHAROUT
   483  02ca 8f13fc1b           	sta IO_CON_REGISTER
   484  02ce a2c0fc             	ldx #FPASCII_LO16
   485  02d1 863d               	stx dpla
   486  02d3 a91b               	lda #$1b
   487  02d5 853f               	sta dpla_h
   488  02d7 22a50e1c           	jsl l_prcdpla
   489  02db 8f17fc1b           	sta IO_CON_CR
   490                          	
   491  02df a27a02             	ldx #fpfargtxt			;print FARG: tag
   492  02e2 863d               	stx dpla
   493  02e4 a91c               	lda #$1c
   494  02e6 853f               	sta dpla_h
   495  02e8 22a50e1c           	jsl l_prcdpla
   496  02ec a20900             	ldx #9
   497  02ef a529               	lda fpmask
   498  02f1 2920               	and #$20
   499  02f3 d00c               	bne .farghex			;bit 5 set, so fall through and print 10 bytes
   500  02f5 a20700             	ldx #7
   501  02f8 a529               	lda fpmask
   502  02fa 2980               	and #$80
   503  02fc d003               	bne .farghex			;bit 5 clear, but bit 7 set, print 8 bytes
   504  02fe a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   505                          .farghex					;print X number of hex bytes in reverse order
   506  0301 bff0fc1b           	lda FPARGUMENT,x
   507  0305 20dc05             	jsr+2 prhex
   508  0308 ca                 	dex
   509  0309 10f6               	bpl .farghex
   510  030b a529               	lda fpmask
   511  030d 0940               	ora #$40				;select FARG this time
   512  030f 8f41fc1b           	sta IO_FP_TO_ASCII
   513  0313 a92f               	lda #'/'
   514  0315 8f12fc1b           	sta IO_CON_CHAROUT
   515  0319 8f13fc1b           	sta IO_CON_REGISTER
   516  031d a2c0fc             	ldx #FPASCII_LO16
   517  0320 863d               	stx dpla
   518  0322 a91b               	lda #$1b
   519  0324 853f               	sta dpla_h
   520  0326 22a50e1c           	jsl l_prcdpla
   521  032a 8f17fc1b           	sta IO_CON_CR
   522                          	
   523  032e a28102             	ldx #fpcondtxt			;print FPCOND: tag
   524  0331 863d               	stx dpla
   525  0333 a91c               	lda #$1c
   526  0335 853f               	sta dpla_h
   527  0337 22a50e1c           	jsl l_prcdpla
   528  033b a920               	lda #' '
   529  033d 8f12fc1b           	sta IO_CON_CHAROUT
   530  0341 8f13fc1b           	sta IO_CON_REGISTER
   531  0345 afbffc1b           	lda FPCOND
   532  0349 20dc05             	jsr+2 prhex
   533  034c 8f17fc1b           	sta IO_CON_CR
   534                          	
   535  0350 a28a02             	ldx #fpinttxt			;print FPINT tab
   536  0353 863d               	stx dpla
   537  0355 a91c               	lda #$1c
   538  0357 853f               	sta dpla_h
   539  0359 22a50e1c           	jsl l_prcdpla
   540  035d a920               	lda #' '
   541  035f 8f12fc1b           	sta IO_CON_CHAROUT
   542  0363 8f13fc1b           	sta IO_CON_REGISTER
   543  0367 a20700             	ldx #7
   544                          .fpdisp3
   545  036a bfd8fc1b           	lda FPINT,x
   546  036e 20dc05             	jsr+2 prhex
   547  0371 ca                 	dex
   548  0372 10f6               	bpl .fpdisp3
   549  0374 8f17fc1b           	sta IO_CON_CR
   550                          	
   551  0378 4cee03             	jmp moncmd
   552                          	
   553                          bankcmd
   554  037b 202f00             	jsr parse_addr
   555  037e 9006               	bcc monerror
   556  0380 98                 	tya
   557  0381 853c               	sta mondump_h
   558  0383 4cee03             	jmp moncmd
   559                          monerror
   560  0386 a29603             	ldx #monsynerr
   561  0389 863d               	stx dpla
   562  038b a91c               	lda #$1c
   563  038d 853f               	sta dpla_h
   564  038f 22a50e1c           	jsl l_prcdpla
   565  0393 4cee03             	jmp moncmd
   566                          monsynerr
   567  0396 53796e7461782065...	!tx "Syntax error!"
   568  03a3 0d00               	!byte $0d, $00
   569                          
   570                          colorcmd
   571  03a5 202f00             	jsr parse_addr
   572  03a8 90dc               	bcc monerror
   573  03aa 98                 	tya
   574  03ab 8f11fc1b           	sta IO_CON_COLOR
   575  03af 4cee03             	jmp moncmd
   576                          	
   577                          modecmd
   578  03b2 202f00             	jsr parse_addr
   579  03b5 90cf               	bcc monerror
   580  03b7 98                 	tya
   581  03b8 c908               	cmp #$08
   582  03ba 90ca               	bcc monerror
   583  03bc c90a               	cmp #$0a
   584  03be b0c6               	bcs monerror
   585  03c0 8f20fc1b           	sta IO_VIDMODE
   586  03c4 a900               	lda #$00
   587  03c6 8f14fc1b           	sta IO_CON_CURSORH
   588  03ca 8f15fc1b           	sta IO_CON_CURSORV
   589  03ce a920               	lda #$20
   590  03d0 8f12fc1b           	sta IO_CON_CHAROUT
   591  03d4 8f10fc1b           	sta IO_CON_CLS
   592  03d8 4cee03             	jmp moncmd
   593                          	
   594                          monstart				;main entry point for system monitor
   595  03db 4b                 	phk
   596  03dc ab                 	plb
   597  03dd c210               	rep #$10
   598                          	!rl
   599  03df e220               	sep #$20
   600                          	!as
   601  03e1 a20000             	ldx #$0000
   602  03e4 863a               	stx mondump
   603  03e6 a91c               	lda #$1c
   604  03e8 853c               	sta mondump_h
   605  03ea a944               	lda #'D'
   606  03ec 8536               	sta monlast
   607                          	
   608                          	!zone moncmd
   609                          moncmd
   610  03ee a92a               	lda #promptchar
   611  03f0 8f12fc1b           	sta IO_CON_CHAROUT
   612  03f4 8f13fc1b           	sta IO_CON_REGISTER
   613  03f8 22230e1c           	jsl l_getline
   614  03fc 22010e1c           	jsl l_ucline
   615  0400 201600             	jsr parse_setup
   616  0403 202000             	jsr parse_getchar
   617                          .local3
   618  0406 c951               	cmp #'Q'
   619  0408 f05b               	beq haltcmd
   620  040a c944               	cmp #'D'
   621  040c d003               	bne .local4
   622  040e 4c2105             	jmp+2 dumpcmd
   623                          .local4
   624  0411 c90d               	cmp #$0d
   625  0413 d008               	bne .local2
   626  0415 a536               	lda monlast			;recall previously executed command
   627  0417 c920               	cmp #$20			;make sure it isn't a control character
   628  0419 b0eb               	bcs .local3			;and retry it
   629  041b 80d1               	bra moncmd			;else recycle and try a new command
   630                          .local2
   631  041d c941               	cmp #'A'
   632  041f f06a               	beq asciidumpcmd
   633  0421 c942               	cmp #'B'
   634  0423 d003               	bne .local5
   635  0425 4c7b03             	jmp+2 bankcmd
   636                          .local5
   637  0428 c943               	cmp #'C'
   638  042a d003               	bne .local6
   639  042c 4ca503             	jmp+2 colorcmd
   640                          .local6
   641  042f c94d               	cmp #'M'
   642  0431 d003               	bne .local7
   643  0433 4cb203             	jmp+2 modecmd
   644                          .local7
   645  0436 c945               	cmp #'E'
   646  0438 d003               	bne .local8
   647  043a 4cfc05             	jmp+2 entercmd
   648                          .local8
   649  043d c94c               	cmp #'L'
   650  043f d003               	bne .local9
   651  0441 4c2a06             	jmp+2 listcmd
   652                          .local9
   653  0444 c93f               	cmp #'?'
   654  0446 f00d               	beq helpcmd
   655  0448 c946               	cmp #'F'
   656  044a f003               	beq .localfp
   657  044c 4cee03             	jmp moncmd
   658                          .localfp
   659  044f 200d01             	jsr fpcmd
   660  0452 4cee03             	jmp moncmd
   661                          	
   662                          helpcmd
   663  0455 a2e90e             	ldx #helpmsg
   664  0458 863d               	stx dpla
   665  045a a91c               	lda #$1c
   666  045c 853f               	sta dpla_h
   667  045e 22a50e1c           	jsl l_prcdpla
   668  0462 4cee03             	jmp moncmd
   669                          	
   670                          haltcmd
   671  0465 a27304             	ldx #haltmsg
   672  0468 863d               	stx dpla
   673  046a a91c               	lda #$1c
   674  046c 853f               	sta dpla_h
   675  046e 22a50e1c           	jsl l_prcdpla
   676  0472 db                 	stp
   677                          haltmsg
   678  0473 48616c74696e6720...	!tx "Halting 65816 engine.."
   679  0489 0d00               	!byte $0d,$00
   680                          	
   681                          	!zone asciidumpcmd
   682                          asciidumpcmd
   683  048b 8536               	sta monlast
   684  048d 202f00             	jsr parse_addr
   685  0490 9021               	bcc .local3
   686  0492 843a               	sty mondump
   687  0494 8433               	sty rangehigh
   688  0496 2435               	bit monrange			;user asking for a range?
   689  0498 1019               	bpl .local3
   690  049a 202f00             	jsr parse_addr			;get the remaining half of the range
   691  049d 8433               	sty rangehigh
   692  049f a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   693  04a1 8535               	sta monrange
   694  04a3 a433               	ldy rangehigh
   695  04a5 d003               	bne .local6
   696  04a7 4c8603             	jmp+2 monerror			;top of range can't be zero
   697                          .local6
   698  04aa a43a               	ldy mondump
   699  04ac c433               	cpy rangehigh
   700  04ae 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   701  04b0 4c8603             	jmp+2 monerror
   702                          .local3
   703  04b3 20bf00             	jsr prdumpaddr
   704  04b6 a00000             	ldy #$0000
   705                          .local2
   706  04b9 b73a               	lda [mondump],y
   707  04bb c920               	cmp #$20
   708  04bd b002               	bcs .local4
   709  04bf a92e               	lda #'.'				;substitute control character with a period
   710                          .local4
   711  04c1 8f12fc1b           	sta IO_CON_CHAROUT
   712  04c5 8f13fc1b           	sta IO_CON_REGISTER
   713  04c9 c8                 	iny
   714  04ca af20fc1b           	lda IO_VIDMODE
   715  04ce c909               	cmp #$09
   716  04d0 d007               	bne .lores1
   717  04d2 c04000             	cpy #$0040
   718  04d5 d0e2               	bne .local2
   719  04d7 8005               	bra .lores2
   720                          .lores1
   721  04d9 c01000             	cpy #$0010
   722  04dc d0db               	bne .local2
   723                          .lores2
   724  04de 8f17fc1b           	sta IO_CON_CR
   725  04e2 20e800             	jsr adjdumpaddr
   726  04e5 b035               	bcs .local5				;carry to bank, exit even if we're processing a range
   727  04e7 20e800             	jsr adjdumpaddr
   728  04ea b030               	bcs .local5	
   729  04ec af20fc1b           	lda IO_VIDMODE
   730  04f0 c909               	cmp #$09
   731  04f2 d01e               	bne .lores3
   732  04f4 20e800             	jsr adjdumpaddr
   733  04f7 b023               	bcs .local5	
   734  04f9 20e800             	jsr adjdumpaddr
   735  04fc b01e               	bcs .local5	
   736  04fe 20e800             	jsr adjdumpaddr
   737  0501 b019               	bcs .local5	
   738  0503 20e800             	jsr adjdumpaddr
   739  0506 b014               	bcs .local5	
   740  0508 20e800             	jsr adjdumpaddr
   741  050b b00f               	bcs .local5	
   742  050d 20e800             	jsr adjdumpaddr
   743  0510 b00a               	bcs .local5	
   744                          .lores3
   745  0512 2435               	bit monrange			;ranges on?
   746  0514 1006               	bpl .local5
   747  0516 a433               	ldy rangehigh
   748  0518 c43a               	cpy mondump
   749  051a b097               	bcs .local3
   750                          .local5
   751  051c 6435               	stz monrange
   752  051e 4cee03             	jmp moncmd
   753                          	
   754                          	!zone dumpcmd
   755                          dumpcmd
   756  0521 8536               	sta monlast
   757  0523 202f00             	jsr parse_addr
   758  0526 9021               	bcc .local3
   759  0528 843a               	sty mondump				;if address was specified, store 16 bit y at low 16 bits of mondump address
   760  052a 8433               	sty rangehigh
   761  052c 2435               	bit monrange			;user asking for a range?
   762  052e 1019               	bpl .local3
   763  0530 202f00             	jsr parse_addr			;get the remaining half of the range
   764  0533 8433               	sty rangehigh
   765  0535 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   766  0537 8535               	sta monrange
   767  0539 a433               	ldy rangehigh
   768  053b d003               	bne .local6
   769  053d 4c8603             	jmp+2 monerror			;top of range can't be zero
   770                          .local6
   771  0540 a43a               	ldy mondump
   772  0542 c433               	cpy rangehigh
   773  0544 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   774  0546 4c8603             	jmp+2 monerror
   775                          .local3
   776  0549 20bf00             	jsr prdumpaddr
   777  054c a00000             	ldy #$0000
   778                          .local2
   779  054f b73a               	lda [mondump],y
   780  0551 20dc05             	jsr+2 prhex
   781  0554 a920               	lda #' '
   782  0556 8f12fc1b           	sta IO_CON_CHAROUT
   783  055a 8f13fc1b           	sta IO_CON_REGISTER
   784  055e c8                 	iny
   785  055f af20fc1b           	lda IO_VIDMODE
   786  0563 c909               	cmp #$09
   787  0565 d03e               	bne .lores1
   788  0567 c01000             	cpy #$0010
   789  056a d0e3               	bne .local2
   790  056c a920               	lda #' '
   791  056e 8f12fc1b           	sta IO_CON_CHAROUT
   792  0572 8f13fc1b           	sta IO_CON_REGISTER
   793  0576 a92d               	lda #'-'
   794  0578 8f12fc1b           	sta IO_CON_CHAROUT
   795  057c 8f13fc1b           	sta IO_CON_REGISTER
   796  0580 a920               	lda #' '
   797  0582 8f12fc1b           	sta IO_CON_CHAROUT
   798  0586 8f13fc1b           	sta IO_CON_REGISTER
   799  058a a00000             	ldy #$0000				;print 16 bytes as ASCII... bonus when in mode 9!
   800                          .asc2
   801  058d b73a               	lda [mondump],y
   802  058f c920               	cmp #$20
   803  0591 b002               	bcs .asc4
   804  0593 a92e               	lda #'.'				;substitute control character with a period
   805                          .asc4
   806  0595 8f12fc1b           	sta IO_CON_CHAROUT
   807  0599 8f13fc1b           	sta IO_CON_REGISTER
   808  059d c8                 	iny
   809  059e c01000             	cpy #$0010
   810  05a1 d0ea               	bne .asc2
   811  05a3 8005               	bra .lores2
   812                          .lores1
   813  05a5 c00800             	cpy #$0008
   814  05a8 d0a5               	bne .local2
   815                          .lores2
   816  05aa 8f17fc1b           	sta IO_CON_CR
   817  05ae 20e800             	jsr adjdumpaddr
   818  05b1 b01a               	bcs .local5				;carry to bank, exit even if we're processing a range
   819  05b3 af20fc1b           	lda IO_VIDMODE
   820  05b7 c909               	cmp #$09
   821  05b9 d005               	bne .lores3
   822  05bb 20e800             	jsr adjdumpaddr
   823  05be b00d               	bcs .local5
   824                          .lores3
   825  05c0 2435               	bit monrange			;ranges on?
   826  05c2 1009               	bpl .local5
   827  05c4 a433               	ldy rangehigh
   828  05c6 c43a               	cpy mondump
   829  05c8 9003               	bcc .local5
   830  05ca 4c4905             	jmp+2 .local3
   831                          .local5
   832  05cd 6435               	stz monrange
   833  05cf 4cee03             	jmp moncmd
   834                          	
   835                          prhex16
   836  05d2 c230               	rep #$30
   837  05d4 8a                 	txa
   838  05d5 e220               	sep #$20
   839  05d7 eb                 	xba
   840  05d8 20dc05             	jsr+2 prhex
   841  05db eb                 	xba
   842                          prhex
   843  05dc 48                 	pha
   844  05dd 4a                 	lsr
   845  05de 4a                 	lsr
   846  05df 4a                 	lsr
   847  05e0 4a                 	lsr
   848  05e1 20e705             	jsr+2 prhexnib
   849  05e4 68                 	pla
   850  05e5 290f               	and #$0f
   851                          prhexnib
   852  05e7 0930               	ora #$30
   853  05e9 c93a               	cmp #$3a
   854  05eb 9003               	bcc prhexnofix
   855  05ed 18                 	clc
   856  05ee 6907               	adc #$07
   857                          prhexnofix
   858  05f0 8f12fc1b           	sta IO_CON_CHAROUT
   859  05f4 8f13fc1b           	sta IO_CON_REGISTER
   860  05f8 60                 	rts
   861                          
   862                          	!zone entercmd
   863                          .local1
   864  05f9 4c8603             	jmp monerror
   865                          entercmd
   866  05fc 202f00             	jsr parse_addr
   867  05ff 90f8               	bcc .local1			;address is mandatory
   868  0601 2435               	bit monrange
   869  0603 30f4               	bmi .local1			;ranges not allowed
   870  0605 8430               	sty enterbytes
   871  0607 a53c               	lda mondump_h
   872  0609 8532               	sta enterbytes_h	;retrieve bank from mondump
   873                          .local2
   874  060b 202f00             	jsr parse_addr		;start grabbing bytes
   875  060e 9017               	bcc .enterdone
   876  0610 2435               	bit monrange
   877  0612 30e5               	bmi .local1			;stop that happening here too
   878  0614 c230               	rep #$30
   879  0616 98                 	tya
   880  0617 e220               	sep #$20			;get low byte of parsed address into A
   881  0619 8730               	sta [enterbytes]
   882  061b e630               	inc enterbytes
   883  061d d006               	bne .local3
   884  061f e631               	inc enterbytes_m
   885  0621 d002               	bne .local3
   886  0623 e632               	inc enterbytes_h
   887                          .local3
   888  0625 80e4               	bra .local2
   889                          .enterdone
   890  0627 4cee03             	jmp moncmd
   891                          	
   892                          	!zone listcmd
   893                          listcmd
   894  062a 202f00             	jsr parse_addr
   895  062d 9002               	bcc .listmany				;address is optional
   896  062f 843a               	sty mondump
   897                          .listmany
   898  0631 af20fc1b           	lda IO_VIDMODE
   899  0635 c909               	cmp #$09
   900  0637 d005               	bne .listmany1
   901  0639 a22000             	ldx #32
   902  063c 8003               	bra .listmany2
   903                          .listmany1
   904  063e a20f00             	ldx #15
   905                          .listmany2
   906  0641 da                 	phx
   907  0642 204c06             	jsr+2 .listsingle
   908  0645 fa                 	plx
   909  0646 ca                 	dex
   910  0647 d0f8               	bne .listmany2
   911  0649 4cee03             	jmp moncmd
   912                          .listsingle
   913  064c a00000             	ldy #$0000
   914  064f 20bf00             	jsr prdumpaddr
   915  0652 a900               	lda #$00
   916  0654 eb                 	xba					;clear B
   917  0655 a73a               	lda [mondump]				;get opcode
   918  0657 48                 	pha					;save opcode
   919  0658 aa                 	tax
   920  0659 bded0a             	lda mnemlenmode,x
   921  065c 4a                 	lsr
   922  065d 4a                 	lsr
   923  065e 4a                 	lsr
   924  065f 4a                 	lsr
   925  0660 4a                 	lsr					;isolage opcode len
   926  0661 852f               	sta scratch1
   927  0663 a73a               	lda [mondump]
   928  0665 20920a             	jsr+2 is816
   929  0668 a52f               	lda scratch1
   930  066a aa                 	tax
   931  066b a00000             	ldy #$0000
   932                          .nextbyte
   933  066e b73a               	lda [mondump],y
   934  0670 20dc05             	jsr prhex			;print hex
   935  0673 a920               	lda #' '
   936  0675 8f12fc1b           	sta IO_CON_CHAROUT
   937  0679 8f13fc1b           	sta IO_CON_REGISTER	;print space
   938  067d c8                 	iny
   939  067e ca                 	dex
   940  067f d0ed               	bne .nextbyte
   941  0681 a916               	lda #$16
   942  0683 8f14fc1b           	sta IO_CON_CURSORH	;tab over
   943  0687 68                 	pla					;get opcode back
   944  0688 aa                 	tax
   945  0689 bded0b             	lda mnemlist,x
   946  068c 8530               	sta enterbytes
   947  068e 6431               	stz enterbytes_m	;save for 16 bit add
   948  0690 da                 	phx					;stash our opcode
   949  0691 c230               	rep #$30
   950                          	!al
   951  0693 29ff00             	and #$00ff			;switch to 16 bits, clear top
   952  0696 0a                 	asl
   953  0697 18                 	clc
   954  0698 6530               	adc enterbytes		;multiply by 3
   955  069a aa                 	tax
   956  069b e220               	sep #$20
   957                          	!as
   958  069d bded0c             	lda mnems, x
   959  06a0 8f12fc1b           	sta IO_CON_CHAROUT
   960  06a4 8f13fc1b           	sta IO_CON_REGISTER
   961  06a8 e8                 	inx
   962  06a9 bded0c             	lda mnems, x
   963  06ac 8f12fc1b           	sta IO_CON_CHAROUT
   964  06b0 8f13fc1b           	sta IO_CON_REGISTER
   965  06b4 e8                 	inx
   966  06b5 bded0c             	lda mnems, x
   967  06b8 8f12fc1b           	sta IO_CON_CHAROUT
   968  06bc 8f13fc1b           	sta IO_CON_REGISTER
   969  06c0 a920               	lda #' '
   970  06c2 8f12fc1b           	sta IO_CON_CHAROUT
   971  06c6 8f13fc1b           	sta IO_CON_REGISTER
   972  06ca fa                 	plx					;get our opcode back in index
   973  06cb a900               	lda #$00
   974  06cd eb                 	xba					;clear top byte of A if it's dirty
   975  06ce bded0a             	lda mnemlenmode,x
   976  06d1 291f               	and #$1f			;isolate the addressing mode
   977  06d3 0a                 	asl					;multiply by two
   978  06d4 aa                 	tax
   979  06d5 fcc30a             	jsr (listamod,x)
   980  06d8 af20fc1b           	lda IO_VIDMODE
   981  06dc c909               	cmp #$09
   982  06de d01f               	bne .fixup1
   983  06e0 a925               	lda #$25
   984  06e2 8f14fc1b           	sta IO_CON_CURSORH		;tab over and print our bytes as ASCII in 80 column mode
   985  06e6 e230               	sep #$30				;8 bit indexes here
   986                          	!rs
   987  06e8 a000               	ldy #$00				;print disassembly bytes as ASCII... bonus when in mode 9!
   988                          .asc2
   989  06ea b73a               	lda [mondump],y
   990  06ec c920               	cmp #$20
   991  06ee b002               	bcs .asc4
   992  06f0 a92e               	lda #'.'				;substitute control character with a period
   993                          .asc4
   994  06f2 8f12fc1b           	sta IO_CON_CHAROUT
   995  06f6 8f13fc1b           	sta IO_CON_REGISTER
   996  06fa c8                 	iny
   997  06fb c42f               	cpy scratch1
   998  06fd d0eb               	bne .asc2
   999                          .fixup1
  1000  06ff c210               	rep #$10
  1001                          	!rl
  1002  0701 8f17fc1b           	sta IO_CON_CR
  1003                          .fixup
  1004  0705 a52f               	lda scratch1		;get our fixup
  1005  0707 18                 	clc
  1006  0708 653a               	adc mondump
  1007  070a 853a               	sta mondump
  1008  070c a53b               	lda mondump_m
  1009  070e 6900               	adc #$00
  1010  0710 853b               	sta mondump_m
  1011  0712 a53c               	lda mondump_h
  1012  0714 6900               	adc #$00
  1013  0716 853c               	sta mondump_h
  1014                          .goback
  1015  0718 60                 	rts
  1016                          
  1017                          amod0
  1018  0719 a924               	lda #'$'
  1019  071b 8f12fc1b           	sta IO_CON_CHAROUT
  1020  071f 8f13fc1b           	sta IO_CON_REGISTER
  1021  0723 a00100             	ldy #$0001
  1022  0726 b73a               	lda [mondump],y
  1023  0728 20dc05             	jsr prhex
  1024  072b 60                 	rts
  1025                          amod1
  1026  072c a928               	lda #'('
  1027  072e 8f12fc1b           	sta IO_CON_CHAROUT
  1028  0732 8f13fc1b           	sta IO_CON_REGISTER
  1029  0736 a924               	lda #'$'
  1030  0738 8f12fc1b           	sta IO_CON_CHAROUT
  1031  073c 8f13fc1b           	sta IO_CON_REGISTER
  1032  0740 a00100             	ldy #$0001
  1033  0743 b73a               	lda [mondump],y
  1034  0745 20dc05             	jsr prhex
  1035  0748 a92c               	lda #','
  1036  074a 8f12fc1b           	sta IO_CON_CHAROUT
  1037  074e 8f13fc1b           	sta IO_CON_REGISTER
  1038  0752 a958               	lda #'X'
  1039  0754 8f12fc1b           	sta IO_CON_CHAROUT
  1040  0758 8f13fc1b           	sta IO_CON_REGISTER
  1041  075c a929               	lda #')'
  1042  075e 8f12fc1b           	sta IO_CON_CHAROUT
  1043  0762 8f13fc1b           	sta IO_CON_REGISTER
  1044  0766 60                 	rts
  1045                          amod2
  1046  0767 a00100             	ldy #$0001
  1047  076a b73a               	lda [mondump],y
  1048  076c 20dc05             	jsr prhex
  1049  076f a92c               	lda #','
  1050  0771 8f12fc1b           	sta IO_CON_CHAROUT
  1051  0775 8f13fc1b           	sta IO_CON_REGISTER
  1052  0779 a953               	lda #'S'
  1053  077b 8f12fc1b           	sta IO_CON_CHAROUT
  1054  077f 8f13fc1b           	sta IO_CON_REGISTER
  1055  0783 60                 	rts
  1056                          amod3
  1057  0784 a95b               	lda #'['
  1058  0786 8f12fc1b           	sta IO_CON_CHAROUT
  1059  078a 8f13fc1b           	sta IO_CON_REGISTER
  1060  078e a924               	lda #'$'
  1061  0790 8f12fc1b           	sta IO_CON_CHAROUT
  1062  0794 8f13fc1b           	sta IO_CON_REGISTER
  1063  0798 a00100             	ldy #$0001
  1064  079b b73a               	lda [mondump],y
  1065  079d 20dc05             	jsr prhex
  1066  07a0 a95d               	lda #']'
  1067  07a2 8f12fc1b           	sta IO_CON_CHAROUT
  1068  07a6 8f13fc1b           	sta IO_CON_REGISTER
  1069                          amod4
  1070  07aa 60                 	rts
  1071                          	!zone amod5
  1072                          amod5
  1073  07ab a923               	lda #'#'
  1074  07ad 8f12fc1b           	sta IO_CON_CHAROUT
  1075  07b1 8f13fc1b           	sta IO_CON_REGISTER
  1076  07b5 a924               	lda #'$'
  1077  07b7 8f12fc1b           	sta IO_CON_CHAROUT
  1078  07bb 8f13fc1b           	sta IO_CON_REGISTER
  1079  07bf a52f               	lda scratch1
  1080  07c1 c902               	cmp #$02
  1081  07c3 f008               	beq .amod508
  1082                          .amod516
  1083  07c5 a00200             	ldy #$0002
  1084  07c8 b73a               	lda [mondump],y
  1085  07ca 20dc05             	jsr prhex
  1086                          .amod508
  1087  07cd a00100             	ldy #$0001
  1088  07d0 b73a               	lda [mondump],y
  1089  07d2 20dc05             	jsr prhex
  1090  07d5 60                 	rts
  1091                          amod6
  1092  07d6 a924               	lda #'$'
  1093  07d8 8f12fc1b           	sta IO_CON_CHAROUT
  1094  07dc 8f13fc1b           	sta IO_CON_REGISTER
  1095  07e0 a00200             	ldy #$0002
  1096  07e3 b73a               	lda [mondump],y
  1097  07e5 20dc05             	jsr prhex
  1098  07e8 88                 	dey
  1099  07e9 b73a               	lda [mondump],y
  1100  07eb 4cdc05             	jmp prhex
  1101                          amod7
  1102  07ee a924               	lda #'$'
  1103  07f0 8f12fc1b           	sta IO_CON_CHAROUT
  1104  07f4 8f13fc1b           	sta IO_CON_REGISTER
  1105  07f8 a00300             	ldy #$0003
  1106  07fb b73a               	lda [mondump],y
  1107  07fd 20dc05             	jsr prhex
  1108  0800 88                 	dey
  1109  0801 b73a               	lda [mondump],y
  1110  0803 20dc05             	jsr prhex
  1111  0806 88                 	dey
  1112  0807 b73a               	lda [mondump],y
  1113  0809 4cdc05             	jmp prhex
  1114                          amod11
  1115  080c a00300             	ldy #$0003
  1116  080f 842a               	sty scratch2			;number of bytes to bump offset
  1117  0811 a00200             	ldy #$0002
  1118  0814 b73a               	lda [mondump],y
  1119  0816 eb                 	xba
  1120  0817 88                 	dey
  1121  0818 b73a               	lda [mondump],y
  1122  081a 8014               	bra amod8nosign
  1123                          amod8
  1124  081c a00200             	ldy #$0002
  1125  081f 842a               	sty scratch2
  1126  0821 a900               	lda #$00
  1127  0823 eb                 	xba						;clear high byte of A
  1128                          amod8a
  1129  0824 a00100             	ldy #$0001
  1130  0827 b73a               	lda [mondump],y			;get rel byte
  1131  0829 1005               	bpl amod8nosign
  1132  082b 48                 	pha
  1133  082c a9ff               	lda #$ff
  1134  082e eb                 	xba						;sign extend if negative
  1135  082f 68                 	pla
  1136                          amod8nosign
  1137  0830 c230               	rep #$30
  1138                          	!al
  1139  0832 18                 	clc
  1140  0833 653a               	adc mondump				;add to our current disassembly address
  1141  0835 18                 	clc
  1142  0836 652a               	adc scratch2			;add offset for instruction size
  1143  0838 aa                 	tax
  1144  0839 e220               	sep #$20
  1145                          	!as
  1146  083b a924               	lda #'$'
  1147  083d 8f12fc1b           	sta IO_CON_CHAROUT
  1148  0841 8f13fc1b           	sta IO_CON_REGISTER
  1149  0845 20d205             	jsr prhex16
  1150  0848 60                 	rts
  1151                          amod9
  1152  0849 a928               	lda #'('
  1153  084b 8f12fc1b           	sta IO_CON_CHAROUT
  1154  084f 8f13fc1b           	sta IO_CON_REGISTER
  1155  0853 a924               	lda #'$'
  1156  0855 8f12fc1b           	sta IO_CON_CHAROUT
  1157  0859 8f13fc1b           	sta IO_CON_REGISTER
  1158  085d a00100             	ldy #$0001
  1159  0860 b73a               	lda [mondump],y
  1160  0862 20dc05             	jsr prhex
  1161  0865 a929               	lda #')'
  1162  0867 8f12fc1b           	sta IO_CON_CHAROUT
  1163  086b 8f13fc1b           	sta IO_CON_REGISTER
  1164  086f a92c               	lda #','
  1165  0871 8f12fc1b           	sta IO_CON_CHAROUT
  1166  0875 8f13fc1b           	sta IO_CON_REGISTER
  1167  0879 a959               	lda #'Y'
  1168  087b 8f12fc1b           	sta IO_CON_CHAROUT
  1169  087f 8f13fc1b           	sta IO_CON_REGISTER
  1170  0883 60                 	rts
  1171                          amoda
  1172  0884 a928               	lda #'('
  1173  0886 8f12fc1b           	sta IO_CON_CHAROUT
  1174  088a 8f13fc1b           	sta IO_CON_REGISTER
  1175  088e a924               	lda #'$'
  1176  0890 8f12fc1b           	sta IO_CON_CHAROUT
  1177  0894 8f13fc1b           	sta IO_CON_REGISTER
  1178  0898 a00100             	ldy #$0001
  1179  089b b73a               	lda [mondump],y
  1180  089d 20dc05             	jsr prhex
  1181  08a0 a929               	lda #')'
  1182  08a2 8f12fc1b           	sta IO_CON_CHAROUT
  1183  08a6 8f13fc1b           	sta IO_CON_REGISTER
  1184  08aa 60                 	rts
  1185                          amodb
  1186  08ab a928               	lda #'('
  1187  08ad 8f12fc1b           	sta IO_CON_CHAROUT
  1188  08b1 8f13fc1b           	sta IO_CON_REGISTER
  1189  08b5 a924               	lda #'$'
  1190  08b7 8f12fc1b           	sta IO_CON_CHAROUT
  1191  08bb 8f13fc1b           	sta IO_CON_REGISTER
  1192  08bf a00100             	ldy #$0001
  1193  08c2 b73a               	lda [mondump],y
  1194  08c4 20dc05             	jsr prhex
  1195  08c7 a92c               	lda #','
  1196  08c9 8f12fc1b           	sta IO_CON_CHAROUT
  1197  08cd 8f13fc1b           	sta IO_CON_REGISTER
  1198  08d1 a953               	lda #'S'
  1199  08d3 8f12fc1b           	sta IO_CON_CHAROUT
  1200  08d7 8f13fc1b           	sta IO_CON_REGISTER
  1201  08db a929               	lda #')'
  1202  08dd 8f12fc1b           	sta IO_CON_CHAROUT
  1203  08e1 8f13fc1b           	sta IO_CON_REGISTER
  1204  08e5 a92c               	lda #','
  1205  08e7 8f12fc1b           	sta IO_CON_CHAROUT
  1206  08eb 8f13fc1b           	sta IO_CON_REGISTER
  1207  08ef a959               	lda #'Y'
  1208  08f1 8f12fc1b           	sta IO_CON_CHAROUT
  1209  08f5 8f13fc1b           	sta IO_CON_REGISTER
  1210  08f9 60                 	rts
  1211                          amodc
  1212  08fa a924               	lda #'$'
  1213  08fc 8f12fc1b           	sta IO_CON_CHAROUT
  1214  0900 8f13fc1b           	sta IO_CON_REGISTER
  1215  0904 a00100             	ldy #$0001
  1216  0907 b73a               	lda [mondump],y
  1217  0909 20dc05             	jsr prhex
  1218  090c a92c               	lda #','
  1219  090e 8f12fc1b           	sta IO_CON_CHAROUT
  1220  0912 8f13fc1b           	sta IO_CON_REGISTER
  1221  0916 a958               	lda #'X'
  1222  0918 8f12fc1b           	sta IO_CON_CHAROUT
  1223  091c 8f13fc1b           	sta IO_CON_REGISTER
  1224  0920 60                 	rts
  1225                          amodd
  1226  0921 a95b               	lda #'['
  1227  0923 8f12fc1b           	sta IO_CON_CHAROUT
  1228  0927 8f13fc1b           	sta IO_CON_REGISTER
  1229  092b a924               	lda #'$'
  1230  092d 8f12fc1b           	sta IO_CON_CHAROUT
  1231  0931 8f13fc1b           	sta IO_CON_REGISTER
  1232  0935 a00100             	ldy #$0001
  1233  0938 b73a               	lda [mondump],y
  1234  093a 20dc05             	jsr prhex
  1235  093d a95d               	lda #']'
  1236  093f 8f12fc1b           	sta IO_CON_CHAROUT
  1237  0943 8f13fc1b           	sta IO_CON_REGISTER
  1238  0947 a92c               	lda #','
  1239  0949 8f12fc1b           	sta IO_CON_CHAROUT
  1240  094d 8f13fc1b           	sta IO_CON_REGISTER
  1241  0951 a959               	lda #'Y'
  1242  0953 8f12fc1b           	sta IO_CON_CHAROUT
  1243  0957 8f13fc1b           	sta IO_CON_REGISTER
  1244  095b 60                 	rts
  1245                          amode
  1246  095c a924               	lda #'$'
  1247  095e 8f12fc1b           	sta IO_CON_CHAROUT
  1248  0962 8f13fc1b           	sta IO_CON_REGISTER
  1249  0966 a00200             	ldy #$0002
  1250  0969 b73a               	lda [mondump],y
  1251  096b 20dc05             	jsr prhex
  1252  096e 88                 	dey
  1253  096f b73a               	lda [mondump],y
  1254  0971 20dc05             	jsr prhex
  1255  0974 a92c               	lda #','
  1256  0976 8f12fc1b           	sta IO_CON_CHAROUT
  1257  097a 8f13fc1b           	sta IO_CON_REGISTER
  1258  097e a958               	lda #'X'
  1259  0980 8f12fc1b           	sta IO_CON_CHAROUT
  1260  0984 8f13fc1b           	sta IO_CON_REGISTER
  1261  0988 60                 	rts
  1262                          amodf
  1263  0989 a924               	lda #'$'
  1264  098b 8f12fc1b           	sta IO_CON_CHAROUT
  1265  098f 8f13fc1b           	sta IO_CON_REGISTER
  1266  0993 a00200             	ldy #$0002
  1267  0996 b73a               	lda [mondump],y
  1268  0998 20dc05             	jsr prhex
  1269  099b 88                 	dey
  1270  099c b73a               	lda [mondump],y
  1271  099e 20dc05             	jsr prhex
  1272  09a1 a92c               	lda #','
  1273  09a3 8f12fc1b           	sta IO_CON_CHAROUT
  1274  09a7 8f13fc1b           	sta IO_CON_REGISTER
  1275  09ab a959               	lda #'Y'
  1276  09ad 8f12fc1b           	sta IO_CON_CHAROUT
  1277  09b1 8f13fc1b           	sta IO_CON_REGISTER
  1278  09b5 60                 	rts
  1279                          amod10
  1280  09b6 a924               	lda #'$'
  1281  09b8 8f12fc1b           	sta IO_CON_CHAROUT
  1282  09bc 8f13fc1b           	sta IO_CON_REGISTER
  1283  09c0 a00300             	ldy #$0003
  1284  09c3 b73a               	lda [mondump],y
  1285  09c5 20dc05             	jsr prhex
  1286  09c8 88                 	dey
  1287  09c9 b73a               	lda [mondump],y
  1288  09cb 20dc05             	jsr prhex
  1289  09ce 88                 	dey
  1290  09cf b73a               	lda [mondump],y
  1291  09d1 20dc05             	jsr prhex
  1292  09d4 a92c               	lda #','
  1293  09d6 8f12fc1b           	sta IO_CON_CHAROUT
  1294  09da 8f13fc1b           	sta IO_CON_REGISTER
  1295  09de a958               	lda #'X'
  1296  09e0 8f12fc1b           	sta IO_CON_CHAROUT
  1297  09e4 8f13fc1b           	sta IO_CON_REGISTER
  1298  09e8 60                 	rts
  1299                          amod12
  1300  09e9 a928               	lda #'('
  1301  09eb 8f12fc1b           	sta IO_CON_CHAROUT
  1302  09ef 8f13fc1b           	sta IO_CON_REGISTER
  1303  09f3 a924               	lda #'$'
  1304  09f5 8f12fc1b           	sta IO_CON_CHAROUT
  1305  09f9 8f13fc1b           	sta IO_CON_REGISTER
  1306  09fd a00200             	ldy #$0002
  1307  0a00 b73a               	lda [mondump],y
  1308  0a02 20dc05             	jsr prhex
  1309  0a05 88                 	dey
  1310  0a06 b73a               	lda [mondump],y
  1311  0a08 20dc05             	jsr prhex
  1312  0a0b a929               	lda #')'
  1313  0a0d 8f12fc1b           	sta IO_CON_CHAROUT
  1314  0a11 8f13fc1b           	sta IO_CON_REGISTER
  1315  0a15 60                 	rts
  1316                          amod13
  1317  0a16 a928               	lda #'('
  1318  0a18 8f12fc1b           	sta IO_CON_CHAROUT
  1319  0a1c 8f13fc1b           	sta IO_CON_REGISTER
  1320  0a20 a924               	lda #'$'
  1321  0a22 8f12fc1b           	sta IO_CON_CHAROUT
  1322  0a26 8f13fc1b           	sta IO_CON_REGISTER
  1323  0a2a a00200             	ldy #$0002
  1324  0a2d b73a               	lda [mondump],y
  1325  0a2f 20dc05             	jsr prhex
  1326  0a32 88                 	dey
  1327  0a33 b73a               	lda [mondump],y
  1328  0a35 20dc05             	jsr prhex
  1329  0a38 a92c               	lda #','
  1330  0a3a 8f12fc1b           	sta IO_CON_CHAROUT
  1331  0a3e 8f13fc1b           	sta IO_CON_REGISTER
  1332  0a42 a958               	lda #'X'
  1333  0a44 8f12fc1b           	sta IO_CON_CHAROUT
  1334  0a48 8f13fc1b           	sta IO_CON_REGISTER
  1335  0a4c a929               	lda #')'
  1336  0a4e 8f12fc1b           	sta IO_CON_CHAROUT
  1337  0a52 8f13fc1b           	sta IO_CON_REGISTER
  1338  0a56 60                 	rts
  1339                          amod14
  1340  0a57 a924               	lda #'$'
  1341  0a59 8f12fc1b           	sta IO_CON_CHAROUT
  1342  0a5d 8f13fc1b           	sta IO_CON_REGISTER
  1343  0a61 a00100             	ldy #$0001
  1344  0a64 b73a               	lda [mondump],y
  1345  0a66 20dc05             	jsr prhex
  1346  0a69 a92c               	lda #','
  1347  0a6b 8f12fc1b           	sta IO_CON_CHAROUT
  1348  0a6f 8f13fc1b           	sta IO_CON_REGISTER
  1349  0a73 a959               	lda #'Y'
  1350  0a75 8f12fc1b           	sta IO_CON_CHAROUT
  1351  0a79 8f13fc1b           	sta IO_CON_REGISTER
  1352  0a7d 60                 	rts
  1353                          	
  1354                          						;test branches for disassembly purposes..
  1355  0a7e 70d7               	bvs amod14
  1356  0a80 7010               	bvs is816
  1357  0a82 7092               	bvs amod13
  1358  0a84 703d               	bvs listamod
  1359  0a86 6260ff             	per amod12
  1360  0a89 620600             	per is816
  1361  0a8c 6227ff             	per amod10
  1362  0a8f 623100             	per listamod
  1363                          	
  1364                          	!zone is816
  1365                          is816
  1366  0a92 48                 	pha
  1367  0a93 291f               	and #$1f
  1368  0a95 c909               	cmp #$09				;09, 29, 49, etc?
  1369  0a97 d006               	bne .testx
  1370  0a99 242d               	bit alarge				;16 bit?
  1371  0a9b 3020               	bmi .is16
  1372  0a9d 1018               	bpl .is8
  1373                          .testx
  1374  0a9f 68                 	pla
  1375  0aa0 48                 	pha
  1376  0aa1 c9a0               	cmp #$a0
  1377  0aa3 f00e               	beq .isx
  1378  0aa5 c9a2               	cmp #$a2
  1379  0aa7 f00a               	beq .isx
  1380  0aa9 c9c0               	cmp #$c0
  1381  0aab f006               	beq .isx
  1382  0aad c9e0               	cmp #$e0
  1383  0aaf f002               	beq .isx
  1384  0ab1 68                 	pla						;made it here, not an accumulator or index instruction
  1385  0ab2 60                 	rts
  1386                          .isx
  1387  0ab3 242e               	bit xlarge
  1388  0ab5 3006               	bmi .is16				;or else fall thru
  1389                          .is8
  1390  0ab7 a902               	lda #$2
  1391  0ab9 852f               	sta scratch1
  1392  0abb 68                 	pla
  1393  0abc 60                 	rts
  1394                          .is16
  1395  0abd a903               	lda #$3
  1396  0abf 852f               	sta scratch1
  1397  0ac1 68                 	pla
  1398  0ac2 60                 	rts
  1399                          	
  1400                          listamod
  1401  0ac3 1907               	!16 amod0			;$xx
  1402  0ac5 2c07               	!16 amod1			;($xx,X)
  1403  0ac7 6707               	!16 amod2			;x,S
  1404  0ac9 8407               	!16 amod3			;[$xx]
  1405  0acb aa07               	!16 amod4			;implied
  1406  0acd ab07               	!16 amod5			;#$xx (or #$yyxx)
  1407  0acf d607               	!16 amod6			;$yyxx
  1408  0ad1 ee07               	!16 amod7			;$zzyyxx
  1409  0ad3 1c08               	!16 amod8			;rel8
  1410  0ad5 4908               	!16 amod9			;($xx),Y
  1411  0ad7 8408               	!16 amoda			;($xx)
  1412  0ad9 ab08               	!16 amodb			;(xx,S),Y
  1413  0adb fa08               	!16 amodc			;$xx,X
  1414  0add 2109               	!16 amodd			;[$xx],Y
  1415  0adf 5c09               	!16 amode			;$yyxx,X
  1416  0ae1 8909               	!16 amodf			;$yyxx,Y
  1417  0ae3 b609               	!16 amod10			;$zzyyxx,X
  1418  0ae5 0c08               	!16 amod11			;rel16
  1419  0ae7 e909               	!16 amod12			;($yyxx)
  1420  0ae9 160a               	!16 amod13			;($yyxx,X)
  1421  0aeb 570a               	!16 amod14			;$xx,Y
  1422                          	
  1423                          mnemlenmode
  1424  0aed 40                 	!byte %01000000		;00 brk 2/$xx
  1425  0aee 41                 	!byte %01000001		;01 ora 2/($xx,x)
  1426  0aef 40                 	!byte %01000000		;02 cop 2/$xx
  1427  0af0 42                 	!byte %01000010		;03 ora 2/x,s
  1428  0af1 40                 	!byte %01000000		;04 tsb 2/$xx
  1429  0af2 40                 	!byte %01000000		;05 ora 2/$xx
  1430  0af3 40                 	!byte %01000000		;06 asl 2/$xx
  1431  0af4 43                 	!byte %01000011		;07 ora 2/[$xx]
  1432  0af5 24                 	!byte %00100100		;08 php 1
  1433  0af6 45                 	!byte %01000101		;09 ora 2/#imm
  1434  0af7 24                 	!byte %00100100		;0a asl 1
  1435  0af8 24                 	!byte %00100100		;0b phd 1
  1436  0af9 66                 	!byte %01100110		;0c tsb 3/$yyxx
  1437  0afa 66                 	!byte %01100110		;0d ora 3/$yyxx
  1438  0afb 66                 	!byte %01100110		;0e asl 3/$yyxx
  1439  0afc 87                 	!byte %10000111		;0f ora 4/$zzyyxx
  1440  0afd 48                 	!byte %01001000		;10 bpl 2/rel8
  1441  0afe 49                 	!byte %01001001		;11 ora 2/($xx),Y
  1442  0aff 4a                 	!byte %01001010		;12 ora 2/($xx)
  1443  0b00 4b                 	!byte %01001011		;13 ora 2/(x,s),Y
  1444  0b01 40                 	!byte %01000000		;14 trb 2/$xx
  1445  0b02 4c                 	!byte %01001100		;15 ora 2/$xx,X
  1446  0b03 4c                 	!byte %01001100		;16 asl 2/$xx,X
  1447  0b04 4d                 	!byte %01001101		;17 ora 2/[$xx],Y
  1448  0b05 24                 	!byte %00100100		;18 clc 1
  1449  0b06 6f                 	!byte %01101111		;19 ora 3/$yyxx,Y
  1450  0b07 24                 	!byte %00100100		;1a inc 1
  1451  0b08 24                 	!byte %00100100		;1b tcs 1
  1452  0b09 66                 	!byte %01100110		;1c trb 3/$yyxx
  1453  0b0a 6e                 	!byte %01101110		;1d ora 3/$yyxx,X
  1454  0b0b 6e                 	!byte %01101110		;1e asl 3/$yyxx,X
  1455  0b0c 90                 	!byte %10010000		;1f ora 4/$zzyyxx,X
  1456  0b0d 66                 	!byte %01100110		;20 jsr 3/$yyxx
  1457  0b0e 41                 	!byte %01000001		;21 and 2/($xx,x)
  1458  0b0f 87                 	!byte %10000111		;22 jsl 4/$zzyyxx
  1459  0b10 42                 	!byte %01000010		;23 and 2/x,s
  1460  0b11 40                 	!byte %01000000		;24 bit 2/$xx
  1461  0b12 40                 	!byte %01000000		;25 and 2/$xx
  1462  0b13 40                 	!byte %01000000		;26 rol 2/$xx
  1463  0b14 43                 	!byte %01000011		;27 and 2/[$xx]
  1464  0b15 24                 	!byte %00100100		;28 plp 1
  1465  0b16 45                 	!byte %01000101		;29 and 2/#imm
  1466  0b17 24                 	!byte %00100100		;2a rol 1
  1467  0b18 24                 	!byte %00100100		;2b pld 1
  1468  0b19 66                 	!byte %01100110		;2c bit 3/$yyxx
  1469  0b1a 66                 	!byte %01100110		;2d and 3/$yyxx
  1470  0b1b 66                 	!byte %01100110		;2e rol 3/$yyxx
  1471  0b1c 87                 	!byte %10000111		;2f and 4/$zzyyxx
  1472  0b1d 48                 	!byte %01001000		;30 bmi 2/rel8
  1473  0b1e 49                 	!byte %01001001		;31 and 2/($xx),Y
  1474  0b1f 4a                 	!byte %01001010		;32 and 2/($xx)
  1475  0b20 4b                 	!byte %01001011		;33 and 2/(x,s),Y
  1476  0b21 4c                 	!byte %01001100		;34 bit 2/$xx,X
  1477  0b22 4c                 	!byte %01001100		;35 and 2/$xx,X
  1478  0b23 4c                 	!byte %01001100		;36 rol 2/$xx,X
  1479  0b24 4d                 	!byte %01001101		;37 and 2/[$xx],Y
  1480  0b25 24                 	!byte %00100100		;38 sec 1
  1481  0b26 6f                 	!byte %01101111		;39 and 3/$yyxx,Y
  1482  0b27 24                 	!byte %00100100		;3a dec 1
  1483  0b28 24                 	!byte %00100100		;3b tsc 1
  1484  0b29 6e                 	!byte %01101110		;3c bit 3/$yyxx,X
  1485  0b2a 6e                 	!byte %01101110		;3d and 3/$yyxx,X
  1486  0b2b 6e                 	!byte %01101110		;3e rol 3/$yyxx,X
  1487  0b2c 90                 	!byte %10010000		;3f and 4/$zzyyxx,X
  1488  0b2d 24                 	!byte %00100100		;40 ???
  1489  0b2e 41                 	!byte %01000001		;41 eor 2/($xx,x)
  1490  0b2f 40                 	!byte %01000000		;42 wdm 2/$00
  1491  0b30 42                 	!byte %01000010		;43 eor 2/x,s
  1492  0b31 24                 	!byte %00100100		;44 ???
  1493  0b32 40                 	!byte %01000000		;45 eor 2/$xx
  1494  0b33 40                 	!byte %01000000		;46 lsr 2/$xx
  1495  0b34 43                 	!byte %01000011		;47 eor 2/[$xx]
  1496  0b35 24                 	!byte %00100100		;48 pha 1
  1497  0b36 45                 	!byte %01000101		;49 eor 2/#imm
  1498  0b37 24                 	!byte %00100100		;4a lsr 1
  1499  0b38 24                 	!byte %00100100		;4b phk 1
  1500  0b39 66                 	!byte %01100110		;4c jmp 3/$yyxx
  1501  0b3a 66                 	!byte %01100110		;4d eor 3/$yyxx
  1502  0b3b 66                 	!byte %01100110		;4e lsr 3/$yyxx
  1503  0b3c 87                 	!byte %10000111		;4f eor 4/$zzyyxx
  1504  0b3d 48                 	!byte %01001000		;50 bvc 2/rel8
  1505  0b3e 49                 	!byte %01001001		;51 eor 2/($xx),Y
  1506  0b3f 4a                 	!byte %01001010		;52 eor 2/($xx)
  1507  0b40 4b                 	!byte %01001011		;53 eor 2/(x,s),Y
  1508  0b41 24                 	!byte %00100100		;54 ???
  1509  0b42 4c                 	!byte %01001100		;55 eor 2/$xx,X
  1510  0b43 4c                 	!byte %01001100		;56 lsr 2/$xx,X
  1511  0b44 4d                 	!byte %01001101		;57 eor 2/[$xx],Y
  1512  0b45 24                 	!byte %00100100		;58 cli 1
  1513  0b46 6f                 	!byte %01101111		;59 eor 3/$yyxx,Y
  1514  0b47 24                 	!byte %00100100		;5a phy 1
  1515  0b48 24                 	!byte %00100100		;5b tcd 1
  1516  0b49 87                 	!byte %10000111		;5c jml 4/$zzyyxx
  1517  0b4a 6e                 	!byte %01101110		;5d eor 3/$yyxx,X
  1518  0b4b 6e                 	!byte %01101110		;5e lsr 3/$yyxx,X
  1519  0b4c 90                 	!byte %10010000		;5f eor 4/$zzyyxx,X
  1520  0b4d 24                 	!byte %00100100		;60 rts
  1521  0b4e 41                 	!byte %01000001		;61 adc 2/($xx,x)
  1522  0b4f 71                 	!byte %01110001		;62 per 3/rel16
  1523  0b50 42                 	!byte %01000010		;63 adc 2/x,s
  1524  0b51 40                 	!byte %01000000		;64 stz 2/$xx
  1525  0b52 40                 	!byte %01000000		;65 adc 2/$xx
  1526  0b53 40                 	!byte %01000000		;66 ror 2/$xx
  1527  0b54 43                 	!byte %01000011		;67 adc 2/[$xx]
  1528  0b55 24                 	!byte %00100100		;68 pla 1
  1529  0b56 45                 	!byte %01000101		;69 adc 2/#imm
  1530  0b57 24                 	!byte %00100100		;6a ror 1
  1531  0b58 24                 	!byte %00100100		;6b rtl 1
  1532  0b59 72                 	!byte %01110010		;6c jmp 3/($yyxx)
  1533  0b5a 66                 	!byte %01100110		;6d adc 3/$yyxx
  1534  0b5b 66                 	!byte %01100110		;6e ror 3/$yyxx
  1535  0b5c 87                 	!byte %10000111		;6f adc 4/$zzyyxx
  1536  0b5d 48                 	!byte %01001000		;70 bvs 2/rel8
  1537  0b5e 49                 	!byte %01001001		;71 adc 2/($xx),Y
  1538  0b5f 4a                 	!byte %01001010		;72 adc 2/($xx)
  1539  0b60 4b                 	!byte %01001011		;73 adc 2/(x,s),Y
  1540  0b61 4c                 	!byte %01001100		;74 stz 2/$xx,X
  1541  0b62 4c                 	!byte %01001100		;75 adc 2/$xx,X
  1542  0b63 4c                 	!byte %01001100		;76 ror 2/$xx,X
  1543  0b64 4d                 	!byte %01001101		;77 adc 2/[$xx],Y
  1544  0b65 24                 	!byte %00100100		;78 sei 1
  1545  0b66 6f                 	!byte %01101111		;79 adc 3/$yyxx,Y
  1546  0b67 24                 	!byte %00100100		;7a ply 1
  1547  0b68 24                 	!byte %00100100		;7b tdc 1
  1548  0b69 73                 	!byte %01110011		;7c jmp 3/($yyxx,X)
  1549  0b6a 6e                 	!byte %01101110		;7d adc 3/$yyxx,X
  1550  0b6b 6e                 	!byte %01101110		;7e lsr 3/$yyxx,X
  1551  0b6c 90                 	!byte %10010000		;7f adc 4/$zzyyxx,X
  1552  0b6d 48                 	!byte %01001000		;80 bra 2/rel8
  1553  0b6e 41                 	!byte %01000001		;81 sta 2/($xx,x)
  1554  0b6f 71                 	!byte %01110001		;82 brl 3/rel16
  1555  0b70 42                 	!byte %01000010		;83 sta 2/x,s
  1556  0b71 40                 	!byte %01000000		;84 sty 2/$xx
  1557  0b72 40                 	!byte %01000000		;85 sta 2/$xx
  1558  0b73 40                 	!byte %01000000		;86 stx 2/$xx
  1559  0b74 43                 	!byte %01000011		;87 sta 2/[$xx]
  1560  0b75 24                 	!byte %00100100		;88 dey 1
  1561  0b76 45                 	!byte %01000101		;89 bit 2/#imm
  1562  0b77 24                 	!byte %00100100		;8a txa 1
  1563  0b78 24                 	!byte %00100100		;8b phb 1
  1564  0b79 66                 	!byte %01100110		;8c sty 3/$yyxx
  1565  0b7a 66                 	!byte %01100110		;8d sta 3/$yyxx
  1566  0b7b 66                 	!byte %01100110		;8e stx 3/$yyxx
  1567  0b7c 87                 	!byte %10000111		;8f sta 4/$zzyyxx
  1568  0b7d 48                 	!byte %01001000		;90 bcc 2/rel8
  1569  0b7e 49                 	!byte %01001001		;91 sta 2/($xx),Y
  1570  0b7f 4a                 	!byte %01001010		;92 sta 2/($xx)
  1571  0b80 4b                 	!byte %01001011		;93 sta 2/(x,s),Y
  1572  0b81 4c                 	!byte %01001100		;94 sty 2/$xx,X
  1573  0b82 4c                 	!byte %01001100		;95 sta 2/$xx,X
  1574  0b83 54                 	!byte %01010100		;96 stx 2/$xx,Y
  1575  0b84 4d                 	!byte %01001101		;97 sta 2/[$xx],Y
  1576  0b85 24                 	!byte %00100100		;98 txa 1
  1577  0b86 6f                 	!byte %01101111		;99 sta 3/$yyxx,Y
  1578  0b87 24                 	!byte %00100100		;9a txs 1
  1579  0b88 24                 	!byte %00100100		;9b txy 1
  1580  0b89 66                 	!byte %01100110		;9c stz 3/$yyxx
  1581  0b8a 6e                 	!byte %01101110		;9d sta 3/$yyxx,X
  1582  0b8b 6e                 	!byte %01101110		;9e stz 3/$yyxx,X
  1583  0b8c 90                 	!byte %10010000		;9f sta 4/$zzyyxx,X
  1584  0b8d 45                 	!byte %01000101		;a0 ldy 2/#imm
  1585  0b8e 41                 	!byte %01000001		;a1 lda 2/($xx,x)
  1586  0b8f 45                 	!byte %01000101		;a2 ldx 2/#imm
  1587  0b90 42                 	!byte %01000010		;a3 lda 2/x,s
  1588  0b91 40                 	!byte %01000000		;a4 ldy 2/$xx
  1589  0b92 40                 	!byte %01000000		;a5 sta 2/$xx
  1590  0b93 40                 	!byte %01000000		;a6 ldx 2/$xx
  1591  0b94 43                 	!byte %01000011		;a7 lda 2/[$xx]
  1592  0b95 24                 	!byte %00100100		;a8 tay 1
  1593  0b96 45                 	!byte %01000101		;a9 lda 2/#imm
  1594  0b97 24                 	!byte %00100100		;aa tax 1
  1595  0b98 24                 	!byte %00100100		;ab plb 1
  1596  0b99 66                 	!byte %01100110		;ac ldy 3/$yyxx
  1597  0b9a 66                 	!byte %01100110		;ad lda 3/$yyxx
  1598  0b9b 66                 	!byte %01100110		;ae ldx 3/$yyxx
  1599  0b9c 87                 	!byte %10000111		;af lda 4/$zzyyxx
  1600  0b9d 48                 	!byte %01001000		;b0 bcs 2/rel8
  1601  0b9e 49                 	!byte %01001001		;b1 lda 2/($xx),Y
  1602  0b9f 4a                 	!byte %01001010		;b2 lda 2/($xx)
  1603  0ba0 4b                 	!byte %01001011		;b3 lda 2/(x,s),Y
  1604  0ba1 4c                 	!byte %01001100		;b4 ldy 2/$xx,X
  1605  0ba2 4c                 	!byte %01001100		;b5 lda 2/$xx,X
  1606  0ba3 54                 	!byte %01010100		;b6 ldx 2/$xx,Y
  1607  0ba4 4d                 	!byte %01001101		;b7 lda 2/[$xx],Y
  1608  0ba5 24                 	!byte %00100100		;b8 clv 1
  1609  0ba6 6f                 	!byte %01101111		;b9 lda 3/$yyxx,Y
  1610  0ba7 24                 	!byte %00100100		;ba tsx 1
  1611  0ba8 24                 	!byte %00100100		;bb tyx 1
  1612  0ba9 66                 	!byte %01100110		;bc ldy 3/$yyxx
  1613  0baa 6e                 	!byte %01101110		;bd lda 3/$yyxx,X
  1614  0bab 6e                 	!byte %01101110		;be ldx 3/$yyxx,X
  1615  0bac 90                 	!byte %10010000		;bf lda 4/$zzyyxx,X
  1616  0bad 45                 	!byte %01000101		;c0 cpy 2/#imm
  1617  0bae 41                 	!byte %01000001		;c1 cmp 2/($xx,x)
  1618  0baf 45                 	!byte %01000101		;c2 rep 2/#imm
  1619  0bb0 42                 	!byte %01000010		;c3 cmp 2/x,s
  1620  0bb1 40                 	!byte %01000000		;c4 cpx 2/$xx
  1621  0bb2 40                 	!byte %01000000		;c5 cmp 2/$xx
  1622  0bb3 40                 	!byte %01000000		;c6 dec 2/$xx
  1623  0bb4 43                 	!byte %01000011		;c7 cmp 2/[$xx]
  1624  0bb5 24                 	!byte %00100100		;c8 iny 1
  1625  0bb6 45                 	!byte %01000101		;c9 cmp 2/#imm
  1626  0bb7 24                 	!byte %00100100		;ca dex 1
  1627  0bb8 24                 	!byte %00100100		;cb wai 1
  1628  0bb9 66                 	!byte %01100110		;cc cpy 3/$yyxx
  1629  0bba 66                 	!byte %01100110		;cd cmp 3/$yyxx
  1630  0bbb 66                 	!byte %01100110		;ce dec 3/$yyxx
  1631  0bbc 87                 	!byte %10000111		;cf cmp 4/$zzyyxx
  1632  0bbd 48                 	!byte %01001000		;d0 bne 2/rel8
  1633  0bbe 49                 	!byte %01001001		;d1 cmp 2/($xx),Y
  1634  0bbf 4a                 	!byte %01001010		;d2 cmp 2/($xx)
  1635  0bc0 4b                 	!byte %01001011		;d3 cmp 2/(x,s),Y
  1636  0bc1 4a                 	!byte %01001010		;d4 pei 2/($xx)
  1637  0bc2 4c                 	!byte %01001100		;d5 cmp 2/$xx,X
  1638  0bc3 4c                 	!byte %01001100		;d6 dec 2/$xx,X
  1639  0bc4 4d                 	!byte %01001101		;d7 cmp 2/[$xx],Y
  1640  0bc5 24                 	!byte %00100100		;d8 cld 1
  1641  0bc6 6f                 	!byte %01101111		;d9 cmp 3/$yyxx,Y
  1642  0bc7 24                 	!byte %00100100		;da phx 1
  1643  0bc8 24                 	!byte %00100100		;db stp 1
  1644  0bc9 43                 	!byte %01000011		;dc jml 2/[$xx]
  1645  0bca 6e                 	!byte %01101110		;dd cmp 3/$yyxx,X
  1646  0bcb 6e                 	!byte %01101110		;de dec 3/$yyxx,X
  1647  0bcc 90                 	!byte %10010000		;df cmp 4/$zzyyxx,X
  1648  0bcd 45                 	!byte %01000101		;e0 cpx 2/#imm
  1649  0bce 41                 	!byte %01000001		;e1 sbc 2/($xx,x)
  1650  0bcf 45                 	!byte %01000101		;e2 sep 2/#imm
  1651  0bd0 42                 	!byte %01000010		;e3 sbc 2/x,s
  1652  0bd1 40                 	!byte %01000000		;e4 cpx 2/$xx
  1653  0bd2 40                 	!byte %01000000		;e5 sbc 2/$xx
  1654  0bd3 40                 	!byte %01000000		;e6 inc 2/$xx
  1655  0bd4 43                 	!byte %01000011		;e7 sbc 2/[$xx]
  1656  0bd5 24                 	!byte %00100100		;e8 inx 1
  1657  0bd6 45                 	!byte %01000101		;e9 sbc 2/#imm
  1658  0bd7 24                 	!byte %00100100		;ea nop 1
  1659  0bd8 24                 	!byte %00100100		;eb xba 1
  1660  0bd9 66                 	!byte %01100110		;ec cpx 3/$yyxx
  1661  0bda 66                 	!byte %01100110		;ed sbc 3/$yyxx
  1662  0bdb 66                 	!byte %01100110		;ee inc 3/$yyxx
  1663  0bdc 87                 	!byte %10000111		;ef sbc 4/$zzyyxx
  1664  0bdd 48                 	!byte %01001000		;f0 beq 2/rel8
  1665  0bde 49                 	!byte %01001001		;f1 sbc 2/($xx),Y
  1666  0bdf 4a                 	!byte %01001010		;f2 sbc 2/($xx)
  1667  0be0 4b                 	!byte %01001011		;f3 sbc 2/(x,s),Y
  1668  0be1 66                 	!byte %01100110		;f4 pea 3/$yyxx
  1669  0be2 4c                 	!byte %01001100		;f5 sbc 2/$xx,X
  1670  0be3 4c                 	!byte %01001100		;f6 inc 2/$xx,X
  1671  0be4 4d                 	!byte %01001101		;f7 sbc 2/[$xx],Y
  1672  0be5 24                 	!byte %00100100		;f8 sed 1
  1673  0be6 6f                 	!byte %01101111		;f9 sbc 3/$yyxx,Y
  1674  0be7 24                 	!byte %00100100		;fa plx 1
  1675  0be8 24                 	!byte %00100100		;fb xce 1
  1676  0be9 73                 	!byte %01110011		;fc jsr 3/($yyxx)
  1677  0bea 6e                 	!byte %01101110		;fd sbc 3/$yyxx,X
  1678  0beb 6e                 	!byte %01101110		;fe inc 3/$yyxx,X
  1679  0bec 90                 	!byte %10010000		;ff sbc 4/$zzyyxx,X
  1680                          mnemlist
  1681  0bed 00                 	!byte $00			;00 brk
  1682  0bee 02                 	!byte $02			;01 ora
  1683  0bef 01                 	!byte $01			;02 cop
  1684  0bf0 02                 	!byte $02			;03 ora
  1685  0bf1 03                 	!byte $03			;04 tsb
  1686  0bf2 02                 	!byte $02			;05 ora
  1687  0bf3 04                 	!byte $04			;06 asl
  1688  0bf4 02                 	!byte $02			;07 ora
  1689  0bf5 05                 	!byte $05			;08 php
  1690  0bf6 02                 	!byte $02			;09 ora
  1691  0bf7 04                 	!byte $04			;0a asl
  1692  0bf8 06                 	!byte $06			;0b phd
  1693  0bf9 03                 	!byte $03			;0c tsb
  1694  0bfa 02                 	!byte $02			;0d ora
  1695  0bfb 04                 	!byte $04			;0e asl
  1696  0bfc 02                 	!byte $02			;0f ora
  1697  0bfd 07                 	!byte $07			;10 bpl
  1698  0bfe 02                 	!byte $02			;11 ora
  1699  0bff 02                 	!byte $02			;12 ora
  1700  0c00 02                 	!byte $02			;13 ora
  1701  0c01 08                 	!byte $08			;14 trb
  1702  0c02 02                 	!byte $02			;15 ora
  1703  0c03 04                 	!byte $04			;16 asl
  1704  0c04 02                 	!byte $02			;17 ora
  1705  0c05 09                 	!byte $09			;18 clc
  1706  0c06 02                 	!byte $02			;19 ora
  1707  0c07 0a                 	!byte $0a			;1a inc
  1708  0c08 0b                 	!byte $0b			;1b tcs
  1709  0c09 08                 	!byte $08			;1c trb
  1710  0c0a 02                 	!byte $02			;1d ora
  1711  0c0b 04                 	!byte $04			;1e asl
  1712  0c0c 02                 	!byte $02			;1f ora
  1713  0c0d 0d                 	!byte $0d			;20 jsr
  1714  0c0e 0c                 	!byte $0c			;21 and
  1715  0c0f 0e                 	!byte $0e			;22 jsl
  1716  0c10 0c                 	!byte $0c			;23 and
  1717  0c11 10                 	!byte $10			;24 bit
  1718  0c12 0c                 	!byte $0c			;25 and
  1719  0c13 11                 	!byte $11			;26 rol
  1720  0c14 0c                 	!byte $0c			;27 and
  1721  0c15 12                 	!byte $12			;28 plp
  1722  0c16 0c                 	!byte $0c			;29 and
  1723  0c17 11                 	!byte $11			;2a rol
  1724  0c18 13                 	!byte $13			;2b pld
  1725  0c19 10                 	!byte $10			;2c bit
  1726  0c1a 0c                 	!byte $0c			;2d and
  1727  0c1b 11                 	!byte $11			;2e rol
  1728  0c1c 0c                 	!byte $0c			;2f and
  1729  0c1d 14                 	!byte $14			;30 bmi
  1730  0c1e 0c                 	!byte $0c			;31 and
  1731  0c1f 0c                 	!byte $0c			;32 and
  1732  0c20 0c                 	!byte $0c			;33 and
  1733  0c21 11                 	!byte $11			;34 bit
  1734  0c22 0c                 	!byte $0c			;35 and
  1735  0c23 11                 	!byte $11			;36 rol
  1736  0c24 0c                 	!byte $0c			;37 and
  1737  0c25 15                 	!byte $15			;38 sec
  1738  0c26 0c                 	!byte $0c			;39 and
  1739  0c27 0f                 	!byte $0f			;3a dec
  1740  0c28 16                 	!byte $16			;3b tsc
  1741  0c29 11                 	!byte $11			;3c bit
  1742  0c2a 0c                 	!byte $0c			;3d and
  1743  0c2b 11                 	!byte $11			;3e rol
  1744  0c2c 0c                 	!byte $0c			;3f and
  1745  0c2d 17                 	!byte $17			;40 ???
  1746  0c2e 18                 	!byte $18			;41 eor
  1747  0c2f 19                 	!byte $19			;42 wdm
  1748  0c30 18                 	!byte $18			;43 eor
  1749  0c31 17                 	!byte $17			;44 ???
  1750  0c32 18                 	!byte $18			;45 eor
  1751  0c33 1a                 	!byte $1a			;46 lsr
  1752  0c34 18                 	!byte $18			;47 eor
  1753  0c35 1b                 	!byte $1b			;48 pha
  1754  0c36 18                 	!byte $18			;49 eor
  1755  0c37 1a                 	!byte $1a			;4a lsr
  1756  0c38 1c                 	!byte $1c			;4b phk
  1757  0c39 1d                 	!byte $1d			;4c jmp
  1758  0c3a 18                 	!byte $18			;4d eor
  1759  0c3b 1a                 	!byte $1a			;4e lsr
  1760  0c3c 18                 	!byte $18			;4f eor
  1761  0c3d 1e                 	!byte $1e			;50 bvc
  1762  0c3e 18                 	!byte $18			;51 eor
  1763  0c3f 18                 	!byte $18			;52 eor
  1764  0c40 18                 	!byte $18			;53 eor
  1765  0c41 17                 	!byte $17			;54 ???
  1766  0c42 18                 	!byte $18			;55 eor
  1767  0c43 1a                 	!byte $1a			;56 lsr
  1768  0c44 18                 	!byte $18			;57 eor
  1769  0c45 1f                 	!byte $1f			;58 cli
  1770  0c46 18                 	!byte $18			;59 eor
  1771  0c47 20                 	!byte $20			;5a phy
  1772  0c48 21                 	!byte $21			;5b tcd
  1773  0c49 22                 	!byte $22			;5c jml
  1774  0c4a 18                 	!byte $18			;5d eor
  1775  0c4b 1a                 	!byte $1a			;5e lsr
  1776  0c4c 18                 	!byte $18			;5f eor
  1777  0c4d 23                 	!byte $23			;60 rts
  1778  0c4e 24                 	!byte $24			;61 adc
  1779  0c4f 25                 	!byte $25			;62 per
  1780  0c50 24                 	!byte $24			;63 adc
  1781  0c51 26                 	!byte $26			;64 stz
  1782  0c52 24                 	!byte $24			;65 adc
  1783  0c53 27                 	!byte $27			;66 ror
  1784  0c54 24                 	!byte $24			;67 adc
  1785  0c55 28                 	!byte $28			;68 pla
  1786  0c56 24                 	!byte $24			;69 adc
  1787  0c57 27                 	!byte $27			;6a ror
  1788  0c58 29                 	!byte $29			;6b rtl
  1789  0c59 1d                 	!byte $1d			;6c jmp
  1790  0c5a 24                 	!byte $24			;6d adc
  1791  0c5b 27                 	!byte $27			;6e ror
  1792  0c5c 24                 	!byte $24			;6f adc
  1793  0c5d 2a                 	!byte $2a			;70 bvs
  1794  0c5e 24                 	!byte $24			;71 adc
  1795  0c5f 24                 	!byte $24			;72 adc
  1796  0c60 24                 	!byte $24			;73 adc
  1797  0c61 26                 	!byte $26			;74 stz
  1798  0c62 24                 	!byte $24			;75 adc
  1799  0c63 27                 	!byte $27			;76 ror
  1800  0c64 24                 	!byte $24			;77 adc
  1801  0c65 2b                 	!byte $2b			;78 sei
  1802  0c66 24                 	!byte $24			;79 adc
  1803  0c67 2c                 	!byte $2c			;7a ply
  1804  0c68 2d                 	!byte $2d			;7b tdc
  1805  0c69 1d                 	!byte $1d			;7c jmp
  1806  0c6a 24                 	!byte $24			;7d adc
  1807  0c6b 27                 	!byte $27			;7e ror
  1808  0c6c 24                 	!byte $24			;7f adc
  1809  0c6d 2e                 	!byte $2e			;80 bra
  1810  0c6e 2f                 	!byte $2f			;81 sta
  1811  0c6f 30                 	!byte $30			;82 brl
  1812  0c70 2f                 	!byte $2f			;83 sta
  1813  0c71 31                 	!byte $31			;84 sty
  1814  0c72 2f                 	!byte $2f			;85 sta
  1815  0c73 32                 	!byte $32			;86 stx
  1816  0c74 2f                 	!byte $2f			;87 sta
  1817  0c75 33                 	!byte $33			;88 dey
  1818  0c76 10                 	!byte $10			;89 bit
  1819  0c77 34                 	!byte $34			;8a txa
  1820  0c78 35                 	!byte $35			;8b phb
  1821  0c79 31                 	!byte $31			;8c sty
  1822  0c7a 2f                 	!byte $2f			;8d sta
  1823  0c7b 32                 	!byte $32			;8e stx
  1824  0c7c 2f                 	!byte $2f			;8f sta
  1825  0c7d 36                 	!byte $36			;90 bcc
  1826  0c7e 2f                 	!byte $2f			;91 sta
  1827  0c7f 2f                 	!byte $2f			;92 sta
  1828  0c80 2f                 	!byte $2f			;93 sta
  1829  0c81 31                 	!byte $31			;94 sty
  1830  0c82 2f                 	!byte $2f			;95 sta
  1831  0c83 32                 	!byte $32			;96 stx
  1832  0c84 2f                 	!byte $2f			;97 sta
  1833  0c85 37                 	!byte $37			;98 tya
  1834  0c86 2f                 	!byte $2f			;99 sta
  1835  0c87 38                 	!byte $38			;9a txs
  1836  0c88 39                 	!byte $39			;9b txy
  1837  0c89 26                 	!byte $26			;9c stz
  1838  0c8a 2f                 	!byte $2f			;9d sta
  1839  0c8b 26                 	!byte $26			;9e stz
  1840  0c8c 2f                 	!byte $2f			;9f sta
  1841  0c8d 3c                 	!byte $3c			;a0 ldy
  1842  0c8e 3a                 	!byte $3a			;a1 lda
  1843  0c8f 3b                 	!byte $3b			;a2 ldx
  1844  0c90 3a                 	!byte $3a			;a3 lda
  1845  0c91 3c                 	!byte $3c			;a4 ldy
  1846  0c92 3a                 	!byte $3a			;a5 lda
  1847  0c93 3b                 	!byte $3b			;a6 ldx
  1848  0c94 3a                 	!byte $3a			;a7 lda
  1849  0c95 3d                 	!byte $3d			;a8 tay
  1850  0c96 3a                 	!byte $3a			;a9 lda
  1851  0c97 3e                 	!byte $3e			;aa tax
  1852  0c98 3f                 	!byte $3f			;ab plb
  1853  0c99 3c                 	!byte $3c			;ac ldy
  1854  0c9a 3a                 	!byte $3a			;ad lda
  1855  0c9b 3b                 	!byte $3b			;ae ldx
  1856  0c9c 3a                 	!byte $3a			;af lda
  1857  0c9d 40                 	!byte $40			;b0 bcs
  1858  0c9e 3a                 	!byte $3a			;b1 lda
  1859  0c9f 3a                 	!byte $3a			;b2 lda
  1860  0ca0 3a                 	!byte $3a			;b3 lda
  1861  0ca1 3c                 	!byte $3c			;b4 ldy
  1862  0ca2 3a                 	!byte $3a			;b5 lda
  1863  0ca3 3b                 	!byte $3b			;b6 ldx
  1864  0ca4 3a                 	!byte $3a			;b7 lda
  1865  0ca5 41                 	!byte $41			;b8 clv
  1866  0ca6 3a                 	!byte $3a			;b9 lda
  1867  0ca7 42                 	!byte $42			;ba tsx
  1868  0ca8 43                 	!byte $43			;bb tyx
  1869  0ca9 3c                 	!byte $3c			;bc ldy
  1870  0caa 3a                 	!byte $3a			;bd lda
  1871  0cab 3b                 	!byte $3b			;be ldx
  1872  0cac 3a                 	!byte $3a			;bf lda
  1873  0cad 46                 	!byte $46			;c0 cpy
  1874  0cae 44                 	!byte $44			;c1 cmp
  1875  0caf 47                 	!byte $47			;c2 rep
  1876  0cb0 44                 	!byte $44			;c3 cmp
  1877  0cb1 46                 	!byte $46			;c4 cpy
  1878  0cb2 44                 	!byte $44			;c5 cmp
  1879  0cb3 48                 	!byte $48			;c6 dec
  1880  0cb4 44                 	!byte $44			;c7 cmp
  1881  0cb5 49                 	!byte $49			;c8 iny
  1882  0cb6 44                 	!byte $44			;c9 cmp
  1883  0cb7 4a                 	!byte $4a			;ca dex
  1884  0cb8 4b                 	!byte $4b			;cb wai
  1885  0cb9 46                 	!byte $46			;cc cpy
  1886  0cba 44                 	!byte $44			;cd cmp
  1887  0cbb 48                 	!byte $48			;ce dec
  1888  0cbc 44                 	!byte $44			;cf cmp
  1889  0cbd 4c                 	!byte $4c			;d0 bne
  1890  0cbe 44                 	!byte $44			;d1 cmp
  1891  0cbf 44                 	!byte $44			;d2 cmp
  1892  0cc0 44                 	!byte $44			;d3 cmp
  1893  0cc1 4d                 	!byte $4d			;d4 pei
  1894  0cc2 44                 	!byte $44			;d5 cmp
  1895  0cc3 48                 	!byte $48			;d6 dec
  1896  0cc4 44                 	!byte $44			;d7 cmp
  1897  0cc5 4e                 	!byte $4e			;d8 cld
  1898  0cc6 44                 	!byte $44			;d9 cmp
  1899  0cc7 4f                 	!byte $4f			;da phx
  1900  0cc8 50                 	!byte $50			;db stp
  1901  0cc9 22                 	!byte $22			;dc jml
  1902  0cca 44                 	!byte $44			;dd cmp
  1903  0ccb 48                 	!byte $48			;de dec
  1904  0ccc 44                 	!byte $44			;df cmp
  1905  0ccd 51                 	!byte $51			;e0 cpx
  1906  0cce 45                 	!byte $45			;e1 sbc
  1907  0ccf 52                 	!byte $52			;e2 sep
  1908  0cd0 45                 	!byte $45			;e3 sbc
  1909  0cd1 51                 	!byte $51			;e4 cpx
  1910  0cd2 45                 	!byte $45			;e5 sbc
  1911  0cd3 53                 	!byte $53			;e6 inc
  1912  0cd4 45                 	!byte $45			;e7 sbc
  1913  0cd5 54                 	!byte $54			;e8 inx
  1914  0cd6 45                 	!byte $45			;e9 sbc
  1915  0cd7 55                 	!byte $55			;ea nop
  1916  0cd8 56                 	!byte $56			;eb xba
  1917  0cd9 51                 	!byte $51			;ec cpx
  1918  0cda 45                 	!byte $45			;ed sbc
  1919  0cdb 53                 	!byte $53			;ee inc
  1920  0cdc 45                 	!byte $45			;ef sbc
  1921  0cdd 57                 	!byte $57			;f0 beq
  1922  0cde 45                 	!byte $45			;f1 sbc
  1923  0cdf 45                 	!byte $45			;f2 sbc
  1924  0ce0 45                 	!byte $45			;f3 sbc
  1925  0ce1 58                 	!byte $58			;f4 pea
  1926  0ce2 45                 	!byte $45			;f5 sbc
  1927  0ce3 53                 	!byte $53			;f6 inc
  1928  0ce4 45                 	!byte $45			;f7 sbc
  1929  0ce5 59                 	!byte $59			;f8 sed
  1930  0ce6 45                 	!byte $45			;f9 sbc
  1931  0ce7 5a                 	!byte $5a			;fa plx
  1932  0ce8 5b                 	!byte $5b			;fb xce
  1933  0ce9 0d                 	!byte $0d			;fc jsr
  1934  0cea 45                 	!byte $45			;fd sbc
  1935  0ceb 53                 	!byte $53			;fe inc
  1936  0cec 45                 	!byte $45			;ff sbc
  1937                          mnems
  1938  0ced 42524b             	!tx "BRK"			;0
  1939  0cf0 434f50             	!tx "COP"			;1
  1940  0cf3 4f5241             	!tx "ORA"			;2
  1941  0cf6 545342             	!tx "TSB"			;3
  1942  0cf9 41534c             	!tx "ASL"			;4
  1943  0cfc 504850             	!tx "PHP"			;5
  1944  0cff 504844             	!tx "PHD"			;6
  1945  0d02 42504c             	!tx "BPL"			;7
  1946  0d05 545242             	!tx "TRB"			;8
  1947  0d08 434c43             	!tx "CLC"			;9
  1948  0d0b 494e43             	!tx "INC"			;a
  1949  0d0e 544353             	!tx "TCS"			;b
  1950  0d11 414e44             	!tx "AND"			;c
  1951  0d14 4a5352             	!tx "JSR"			;d
  1952  0d17 4a534c             	!tx "JSL"			;e
  1953  0d1a 444543             	!tx "DEC"			;f
  1954  0d1d 424954             	!tx "BIT"			;10
  1955  0d20 524f4c             	!tx "ROL"			;11
  1956  0d23 504c50             	!tx "PLP"			;12
  1957  0d26 504c44             	!tx "PLD"			;13
  1958  0d29 424d49             	!tx "BMI"			;14
  1959  0d2c 534543             	!tx "SEC"			;15
  1960  0d2f 545343             	!tx "TSC"			;16
  1961  0d32 3f3f3f             	!tx "???"			;17
  1962  0d35 454f52             	!tx "EOR"			;18
  1963  0d38 57444d             	!tx "WDM"			;19
  1964  0d3b 4c5352             	!tx "LSR"			;1a
  1965  0d3e 504841             	!tx "PHA"			;1b
  1966  0d41 50484b             	!tx "PHK"			;1c
  1967  0d44 4a4d50             	!tx "JMP"			;1d
  1968  0d47 425643             	!tx "BVC"			;1e
  1969  0d4a 434c49             	!tx "CLI"			;1f
  1970  0d4d 504859             	!tx "PHY"			;20
  1971  0d50 544344             	!tx "TCD"			;21
  1972  0d53 4a4d4c             	!tx "JML"			;22
  1973  0d56 525453             	!tx "RTS"			;23
  1974  0d59 414443             	!tx "ADC"			;24
  1975  0d5c 504552             	!tx "PER"			;25
  1976  0d5f 53545a             	!tx "STZ"			;26
  1977  0d62 524f52             	!tx "ROR"			;27
  1978  0d65 504c41             	!tx "PLA"			;28
  1979  0d68 52544c             	!tx "RTL"			;29
  1980  0d6b 425653             	!tx "BVS"			;2a
  1981  0d6e 534549             	!tx "SEI"			;2b
  1982  0d71 504c59             	!tx "PLY"			;2c
  1983  0d74 544443             	!tx "TDC"			;2d
  1984  0d77 425241             	!tx "BRA"			;2e
  1985  0d7a 535441             	!tx "STA"			;2f
  1986  0d7d 42524c             	!tx "BRL"			;30
  1987  0d80 535459             	!tx "STY"			;31
  1988  0d83 535458             	!tx "STX"			;32
  1989  0d86 444559             	!tx "DEY"			;33
  1990  0d89 545841             	!tx "TXA"			;34
  1991  0d8c 504842             	!tx "PHB"			;35
  1992  0d8f 424343             	!tx "BCC"			;36
  1993  0d92 545941             	!tx "TYA"			;37
  1994  0d95 545853             	!tx "TXS"			;38
  1995  0d98 545859             	!tx "TXY"			;39
  1996  0d9b 4c4441             	!tx "LDA"			;3a
  1997  0d9e 4c4458             	!tx "LDX"			;3b
  1998  0da1 4c4459             	!tx "LDY"			;3c
  1999  0da4 544159             	!tx "TAY"			;3d
  2000  0da7 544158             	!tx "TAX"			;3e
  2001  0daa 504c42             	!tx "PLB"			;3f
  2002  0dad 424353             	!tx "BCS"			;40
  2003  0db0 434c56             	!tx "CLV"			;41
  2004  0db3 545358             	!tx "TSX"			;42
  2005  0db6 545958             	!tx "TYX"			;43
  2006  0db9 434d50             	!tx "CMP"			;44
  2007  0dbc 534243             	!tx "SBC"			;45
  2008  0dbf 435059             	!tx "CPY"			;46
  2009  0dc2 524550             	!tx "REP"			;47
  2010  0dc5 444543             	!tx "DEC"			;48
  2011  0dc8 494e59             	!tx "INY"			;49
  2012  0dcb 444558             	!tx "DEX"			;4a
  2013  0dce 574149             	!tx "WAI"			;4b
  2014  0dd1 424e45             	!tx "BNE"			;4c
  2015  0dd4 504549             	!tx "PEI"			;4d
  2016  0dd7 434c44             	!tx "CLD"			;4e
  2017  0dda 504858             	!tx "PHX"			;4f
  2018  0ddd 535450             	!tx "STP"			;50
  2019  0de0 435058             	!tx "CPX"			;51
  2020  0de3 534550             	!tx "SEP"			;52
  2021  0de6 494e43             	!tx "INC"			;53
  2022  0de9 494e58             	!tx "INX"			;54
  2023  0dec 4e4f50             	!tx "NOP"			;55
  2024  0def 584241             	!tx "XBA"			;56
  2025  0df2 424551             	!tx "BEQ"			;57
  2026  0df5 504541             	!tx "PEA"			;58
  2027  0df8 534544             	!tx "SED"			;59
  2028  0dfb 504c58             	!tx "PLX"			;5a
  2029  0dfe 584345             	!tx "XCE"			;5b
  2030                          	
  2031                          	!zone ucline
  2032                          ucline					;convert inbuff at $170400 to upper case
  2033  0e01 08                 	php
  2034  0e02 c210               	rep #$10
  2035  0e04 e220               	sep #$20
  2036                          	!as
  2037                          	!rl
  2038  0e06 a20000             	ldx #$0000
  2039                          .local2
  2040  0e09 bf000417           	lda inbuff,x
  2041  0e0d f012               	beq .local4			;hit the zero, so bail
  2042  0e0f c961               	cmp #'a'
  2043  0e11 900b               	bcc .local3			;less then lowercase a, so ignore
  2044  0e13 c97b               	cmp #'z' + 1		;less than next character after lowercase z?
  2045  0e15 b007               	bcs .local3			;greater than or equal, so ignore
  2046  0e17 38                 	sec
  2047  0e18 e920               	sbc #('z' - 'Z')	;make upper case
  2048  0e1a 9f000417           	sta inbuff,x
  2049                          .local3
  2050  0e1e e8                 	inx
  2051  0e1f 80e8               	bra .local2
  2052                          .local4
  2053  0e21 28                 	plp
  2054  0e22 6b                 	rtl
  2055                          	
  2056                          	!zone getline
  2057                          getline
  2058  0e23 08                 	php
  2059  0e24 c210               	rep #$10
  2060  0e26 e220               	sep #$20
  2061                          	!as
  2062                          	!rl
  2063  0e28 a20000             	ldx #$0000
  2064                          .local2
  2065  0e2b af00fc1b           	lda IO_KEYQ_SIZE
  2066  0e2f f0fa               	beq .local2
  2067  0e31 af01fc1b           	lda IO_KEYQ_WAITING
  2068  0e35 8f02fc1b           	sta IO_KEYQ_DEQUEUE
  2069  0e39 c90d               	cmp #$0d			;carriage return yet?
  2070  0e3b f01c               	beq .local3
  2071  0e3d c908               	cmp #$08			;backspace/back arrow?
  2072  0e3f f029               	beq .local4
  2073  0e41 c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
  2074  0e43 90e6               	bcc .local2		 		;yes, so ignore it
  2075  0e45 9f000417           	sta inbuff,x 		;any other character, so register it and store it
  2076  0e49 8f12fc1b           	sta IO_CON_CHAROUT
  2077  0e4d 8f13fc1b           	sta IO_CON_REGISTER
  2078  0e51 e8                 	inx
  2079  0e52 a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
  2080  0e54 e0fe03             	cpx #$3fe			;overrun end of buffer yet?
  2081  0e57 d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
  2082                          .local3
  2083  0e59 9f000417           	sta inbuff,x		;store CR
  2084  0e5d 8f17fc1b           	sta IO_CON_CR
  2085  0e61 e8                 	inx
  2086  0e62 a900               	lda #$00			;store zero to end it all
  2087  0e64 9f000417           	sta inbuff,x
  2088  0e68 28                 	plp
  2089  0e69 6b                 	rtl
  2090                          .local4
  2091  0e6a e00000             	cpx #$0000
  2092  0e6d f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
  2093  0e6f a908               	lda #$08
  2094  0e71 8f12fc1b           	sta IO_CON_CHAROUT
  2095  0e75 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
  2096  0e79 a920               	lda #$20
  2097  0e7b 8f12fc1b           	sta IO_CON_CHAROUT
  2098  0e7f 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
  2099  0e83 a908               	lda #$08
  2100  0e85 8f12fc1b           	sta IO_CON_CHAROUT
  2101  0e89 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
  2102  0e8d ca                 	dex
  2103  0e8e 809b               	bra .local2
  2104                          	
  2105                          prinbuff				;feed location of input buffer into dpla and then print
  2106  0e90 08                 	php
  2107  0e91 c210               	rep #$10
  2108  0e93 e220               	sep #$20
  2109                          	!as
  2110                          	!rl
  2111  0e95 a917               	lda #$17
  2112  0e97 853f               	sta dpla_h
  2113  0e99 a904               	lda #$04
  2114  0e9b 853e               	sta dpla_m
  2115  0e9d 643d               	stz dpla
  2116  0e9f 22a50e1c           	jsl l_prcdpla
  2117  0ea3 28                 	plp
  2118  0ea4 6b                 	rtl
  2119                          	
  2120                          	!zone prcdpla
  2121                          prcdpla					; print C string pointed to by dp locations $3d-$3f
  2122  0ea5 08                 	php
  2123  0ea6 c210               	rep #$10
  2124  0ea8 e220               	sep #$20
  2125                          	!as
  2126                          	!rl
  2127  0eaa a00000             	ldy #$0000
  2128                          .local2
  2129  0ead b73d               	lda [dpla],y
  2130  0eaf f00b               	beq .local3
  2131  0eb1 8f12fc1b           	sta IO_CON_CHAROUT
  2132  0eb5 8f13fc1b           	sta IO_CON_REGISTER
  2133  0eb9 c8                 	iny
  2134  0eba 80f1               	bra .local2
  2135                          .local3
  2136  0ebc 28                 	plp
  2137  0ebd 6b                 	rtl
  2138                          
  2139                          initstring
  2140  0ebe 494d4c2036353831...	!tx "IML 65816 1C Firmware v00"
  2141  0ed7 0d                 	!byte 0x0d
  2142  0ed8 53797374656d204d...	!tx "System Monitor"
  2143  0ee6 0d                 	!byte 0x0d
  2144  0ee7 0d                 	!byte 0x0d
  2145  0ee8 00                 	!byte 0
  2146                          
  2147                          helpmsg
  2148  0ee9 494d4c2036353831...	!tx "IML 65816 Monitor Commands"
  2149  0f03 0d                 	!byte $0d
  2150  0f04 41203c616464723e...	!tx "A <addr>  Dump ASCII"
  2151  0f18 0d                 	!byte $0d
  2152  0f19 42203c62616e6b3e...	!tx "B <bank>  Change bank"
  2153  0f2e 0d                 	!byte $0d
  2154  0f2f 43203c636f6c6f72...	!tx "C <color> Change terminal colors"
  2155  0f4f 0d                 	!byte $0d
  2156  0f50 44203c616464723e...	!tx "D <addr>  Dump hex"
  2157  0f62 0d                 	!byte $0d
  2158  0f63 45203c616464723e...	!tx "E <addr> <byte> <byte>...  Enter bytes"
  2159  0f89 0d                 	!byte $0d
  2160  0f8a 463f202020202020...	!tx "F?        Floating Point Support Help"
  2161  0faf 0d                 	!byte $0d
  2162  0fb0 4c203c616464723e...	!tx "L <addr>  Disassemble 65816 Inst."
  2163  0fd1 0d                 	!byte $0d
  2164  0fd2 4d203c6d6f64653e...	!tx "M <mode>  Change video mode, 8/9"
  2165  0ff2 0d                 	!byte $0d
  2166  0ff3 5120202020202020...	!tx "Q         Halt the processor"
  2167  100f 0d                 	!byte $0d
  2168  1010 3f20202020202020...	!tx "?         This menu"
  2169  1023 0d                 	!byte $0d
  2170  1024 3c656e7465723e20...	!tx "<enter>   Repeat last dump command"
  2171  1046 0d                 	!byte $0d
  2172  1047 546f207370656369...	!tx "To specify range, use <addr1.addr2>"
  2173  106a 0d00               	!byte $0d, 00
  2174                          
  2175                          fphelpmsg
  2176  106c 494d4c20466c6f61...	!tx "IML Floating Point Support"
  2177  1086 0d                 	!byte $0d
  2178  1087 466f726d61743a20...	!tx "Format: F<cmd><sz><reg>"
  2179  109e 0d                 	!byte $0d
  2180  109f 53697a65733a2046...	!tx "Sizes: F=float D=double E=extended"
  2181  10c1 0d                 	!byte $0d
  2182  10c2 5265676973746572...	!tx "Registers: A=FACC B=FARG"
  2183  10da 0d                 	!byte $0d
  2184  10db 46443c737a3e2020...	!tx "FD<sz>    Display FACC/FARG"
  2185  10f6 0d                 	!byte $0d
  2186  10f7 46433c737a3e3c72...	!tx "FC<sz><reg> <constID> Load Constant"
  2187  111a 0d                 	!byte $0d
  2188  111b 46493c737a3e3c72...	!tx "FI<sz><reg> Load Integer from FPINT"
  2189  113e 0d                 	!byte $0d
  2190  113f 46563c737a3e3c72...	!tx "FV<sz><reg> Save int(reg) to FPINT"
  2191  1161 0d                 	!byte $0d
  2192  1162 463c6f703e3c737a...	!tx "F<op><sz><reg> Bin Op, result in <reg>"
  2193  1188 0d                 	!byte $0d
  2194  1189 42696e617279204f...	!tx "Binary Ops: *, /, +, -"
  2195  119f 0d                 	!tx $0d
  2196  11a0 464e3c737a3e3c72...	!tx "FN<sz><reg> Natural Log of <reg>"
  2197  11c0 0d                 	!tx $0d
  2198  11c1 00                 	!byte $00
  2199                          	
  2200  11c2 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
  2201                          

; ******** done
