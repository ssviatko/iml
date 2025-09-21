
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
    44                          l_prcoldpla = $1c0000 + prcoldpla
    45                          l_ucline = $1c0000 + ucline
    46                          
    47                          fpregspec = $28
    48                          fpmask = $29
    49                          scratch2 = $2a
    50                          scratch2_m = $2b
    51                          scratch2_h = $2c
    52                          alarge = $2d
    53                          xlarge = $2e
    54                          scratch1 = $2f
    55                          enterbytes = $30
    56                          enterbytes_m = $31
    57                          enterbytes_h = $32
    58                          rangehigh = $33
    59                          monrange = $35
    60                          monlast = $36
    61                          parseptr = $37
    62                          parseptr_m = $38
    63                          parseptr_h = $39
    64                          mondump = $3a
    65                          mondump_m = $3b
    66                          mondump_h = $3c
    67                          dpla = $3d
    68                          dpla_m = $3e
    69                          dpla_h = $3f
    70                          
    71                          inbuff = $170400
    72                          
    73                          x1crominit
    74  0000 4b                 	phk
    75  0001 ab                 	plb
    76  0002 c210               	rep #$10
    77                          	!rl
    78  0004 e220               	sep #$20
    79                          	!as
    80  0006 a21a0f             	ldx #initbanner
    81  0009 863d               	stx dpla
    82  000b a91c               	lda #$1c
    83  000d 853f               	sta dpla_h
    84  000f 22ee0e1c           	jsl l_prcoldpla
    85  0013 a24f0f             	ldx #initstring
    86  0016 863d               	stx dpla
    87  0018 22ae0e1c           	jsl l_prcdpla
    88  001c 4ce403             	jmp+2 monstart
    89                          
    90                          parse_setup
    91  001f a20004             	ldx #$0400
    92  0022 8637               	stx parseptr
    93  0024 a917               	lda #$17
    94  0026 8539               	sta parseptr_h
    95  0028 60                 	rts
    96                          	
    97                          	!zone parse_getchar
    98                          parse_getchar			;get char from inbuff, assumes 8 bit A, 16 bit X
    99  0029 a737               	lda [parseptr]
   100  002b 48                 	pha
   101  002c e637               	inc parseptr
   102  002e d006               	bne .local2
   103  0030 e638               	inc parseptr_m
   104  0032 d002               	bne .local2
   105  0034 e639               	inc parseptr_h
   106                          .local2
   107  0036 68                 	pla
   108  0037 60                 	rts
   109                          	
   110                          	!zone parse_addr
   111                          parse_addr				;see if user specified an address on line.
   112  0038 a900               	lda #$00
   113  003a 48                 	pha
   114  003b 48                 	pha					;make space for working value on the stack
   115  003c 8535               	sta monrange		;clear range flag
   116                          .throwaway
   117  003e 202900             	jsr+2 parse_getchar
   118  0041 c920               	cmp #' '
   119  0043 f0f9               	beq .throwaway		;throw away leading spaces
   120  0045 20a100             	jsr+2 parse_getnib2	;get first nibble. call 2nd entry point since we already have character
   121  0048 9051               	bcc .no				;didn't even get one hex character, so return false
   122  004a 8301               	sta 1,s				;save it on the stack for now
   123  004c 209e00             	jsr+2 parse_getnib	;get second nibble
   124  004f 9047               	bcc .yes			;if not hex then bail
   125  0051 48                 	pha
   126  0052 a302               	lda 2,s
   127  0054 0a                 	asl
   128  0055 0a                 	asl
   129  0056 0a                 	asl
   130  0057 0a                 	asl
   131  0058 0301               	ora 1,s
   132  005a 8302               	sta 2,s
   133  005c 68                 	pla					;add to stack
   134  005d 209e00             	jsr+2 parse_getnib	;get possible third nibble
   135  0060 9036               	bcc .yes
   136  0062 c230               	rep #$30			;we're dealing with a 16 bit value now
   137                          	!al
   138  0064 290f00             	and #$000f
   139  0067 48                 	pha
   140  0068 a303               	lda 3,s
   141  006a 0a                 	asl
   142  006b 0a                 	asl
   143  006c 0a                 	asl
   144  006d 0a                 	asl
   145  006e 0301               	ora 1,s
   146  0070 8303               	sta 3,s
   147  0072 68                 	pla
   148  0073 e220               	sep #$20
   149                          	!as
   150  0075 209e00             	jsr+2 parse_getnib
   151  0078 901e               	bcc .yes
   152  007a c230               	rep #$30
   153                          	!al
   154  007c 290f00             	and #$000f
   155  007f 48                 	pha
   156  0080 a303               	lda 3,s
   157  0082 0a                 	asl
   158  0083 0a                 	asl
   159  0084 0a                 	asl
   160  0085 0a                 	asl
   161  0086 0301               	ora 1,s
   162  0088 8303               	sta 3,s
   163  008a 68                 	pla
   164  008b e220               	sep #$20			;fall thru to yes on 4th nibble
   165                          	!as
   166  008d 202900             	jsr parse_getchar	;check to see if next char is a . so we can specify ranges
   167  0090 c92e               	cmp #'.'
   168  0092 d004               	bne .yes
   169  0094 a980               	lda #$80
   170  0096 8535               	sta monrange
   171                          .yes
   172  0098 7a                 	ply					;get 16 bit work address off of stack
   173  0099 38                 	sec					;got address, return
   174  009a 60                 	rts
   175                          .no
   176  009b 7a                 	ply					;clear stack
   177  009c 18                 	clc					;no address found, return
   178  009d 60                 	rts
   179                          parse_getnib
   180  009e 202900             	jsr parse_getchar
   181                          parse_getnib2			;enter here after we've thrown away leading spaces
   182  00a1 c920               	cmp #' '
   183  00a3 f021               	beq .outrng			;space = end of value
   184  00a5 c92e               	cmp #'.'
   185  00a7 d006               	bne .notrange
   186  00a9 a980               	lda #$80
   187  00ab 8535               	sta monrange		;this is the start of a range specification
   188  00ad 18                 	clc
   189  00ae 60                 	rts
   190                          .notrange
   191  00af c941               	cmp #$41
   192  00b1 900b               	bcc .outrnga
   193  00b3 c947               	cmp #$47
   194  00b5 b007               	bcs .outrnga
   195  00b7 38                 	sec
   196  00b8 e907               	sbc #$07			;in range of A-F
   197                          .success
   198  00ba 290f               	and #$0f
   199  00bc 38                 	sec
   200  00bd 60                 	rts
   201                          .outrnga				;test if 0-9
   202  00be c930               	cmp #$30
   203  00c0 9004               	bcc .outrng
   204  00c2 c93a               	cmp #$3a
   205  00c4 90f4               	bcc .success		;less than 3a, but >= 30, else fall thru to outrng
   206                          .outrng
   207  00c6 18                 	clc
   208  00c7 60                 	rts
   209                          	
   210                          prdumpaddr
   211  00c8 a53c               	lda mondump_h			;print long address
   212  00ca 20e505             	jsr+2 prhex
   213  00cd a92f               	lda #'/'
   214  00cf 8f12fc1b           	sta IO_CON_CHAROUT
   215  00d3 8f13fc1b           	sta IO_CON_REGISTER
   216  00d7 a63a               	ldx mondump
   217  00d9 20db05             	jsr+2 prhex16
   218  00dc a92d               	lda #'-'
   219  00de 8f12fc1b           	sta IO_CON_CHAROUT
   220  00e2 8f13fc1b           	sta IO_CON_REGISTER
   221  00e6 a920               	lda #' '
   222  00e8 8f12fc1b           	sta IO_CON_CHAROUT
   223  00ec 8f13fc1b           	sta IO_CON_REGISTER
   224  00f0 60                 	rts
   225                          	
   226                          adjdumpaddr					;add 8 to dump address
   227  00f1 c230               	rep #$30
   228                          	!al
   229  00f3 a53a               	lda mondump
   230  00f5 18                 	clc
   231  00f6 690800             	adc #$0008
   232  00f9 853a               	sta mondump
   233  00fb e220               	sep #$20
   234                          	!as
   235  00fd 08                 	php						;save carry state.. did we carry to the bank?
   236  00fe a53c               	lda mondump_h
   237  0100 6900               	adc #$00
   238  0102 853c               	sta mondump_h
   239  0104 28                 	plp
   240  0105 60                 	rts
   241                          
   242                          	!zone fpcmd
   243                          fphelp
   244  0106 a2e810             	ldx #fphelpmsg
   245  0109 863d               	stx dpla
   246  010b a91c               	lda #$1c
   247  010d 853f               	sta dpla_h
   248  010f 22ae0e1c           	jsl l_prcdpla
   249  0113 4cf703             	jmp moncmd
   250                          fpcmd
   251  0116 202900             	jsr parse_getchar
   252  0119 c93f               	cmp #'?'
   253  011b f0e9               	beq fphelp
   254  011d c944               	cmp #'D'
   255  011f d003               	bne .fpcmd1
   256  0121 4c7402             	jmp fpdisp
   257                          .fpcmd1
   258  0124 c943               	cmp #'C'
   259  0126 d003               	bne .fpcmd2
   260  0128 4c4f02             	jmp fploadconst
   261                          .fpcmd2
   262  012b c92a               	cmp #'*'
   263  012d d003               	bne .fpcmd6
   264  012f 4ce301             	jmp fpmultiply
   265                          .fpcmd6
   266  0132 c92f               	cmp #'/'
   267  0134 d003               	bne .fpcmd5
   268  0136 4cfe01             	jmp fpdivide
   269                          .fpcmd5
   270  0139 c92b               	cmp #'+'
   271  013b d003               	bne .fpcmd4
   272  013d 4c1902             	jmp fpadd
   273                          .fpcmd4
   274  0140 c92d               	cmp #'-'
   275  0142 d003               	bne .fpcmd3
   276  0144 4c3402             	jmp fpsubtract
   277                          .fpcmd3
   278  0147 c94e               	cmp #'N'
   279  0149 f07d               	beq fpln
   280  014b c949               	cmp #'I'
   281  014d f043               	beq fpiload
   282  014f c956               	cmp #'V'
   283  0151 f05a               	beq fpisave
   284  0153 4c8f03             	jmp monerror			;unrecognized FP command so fall thru to syntax error
   285                          
   286                          fpgetmask					;construct mask from size specifier, carry set if unregognized
   287  0156 202900             	jsr parse_getchar
   288  0159 c946               	cmp #'F'
   289  015b d006               	bne .local1
   290  015d a900               	lda #$00
   291  015f 8529               	sta fpmask				;set bits 5/7 of fp mask to 0
   292  0161 8016               	bra .local4
   293                          .local1
   294  0163 c944               	cmp #'D'
   295  0165 d006               	bne .local2
   296  0167 a980               	lda #$80				;bit 7=1, bit 5=0
   297  0169 8529               	sta fpmask
   298  016b 800c               	bra .local4
   299                          .local2
   300  016d c945               	cmp #'E'
   301  016f d006               	bne .local3
   302  0171 a920               	lda #$20				;bit 7=0, bit 5=1
   303  0173 8529               	sta fpmask
   304  0175 8002               	bra .local4
   305                          .local3
   306  0177 38                 	sec						;unknown size
   307  0178 60                 	rts
   308                          .local4
   309  0179 18                 	clc
   310  017a 60                 	rts
   311                          	
   312                          fpgetregspec
   313  017b 202900             	jsr parse_getchar		;set fpregspec to 00 or 40 depending on register specified
   314  017e c941               	cmp #'A'
   315  0180 d004               	bne .localgrs1
   316  0182 6428               	stz fpregspec
   317  0184 8008               	bra .localgrs3
   318                          .localgrs1
   319  0186 c942               	cmp #'B'
   320  0188 d006               	bne .localgrs4
   321  018a a940               	lda #$40
   322  018c 8528               	sta fpregspec
   323                          .localgrs3
   324  018e 18                 	clc
   325  018f 60                 	rts
   326                          .localgrs4
   327  0190 38                 	sec
   328  0191 60                 	rts
   329                          
   330                          fpiload
   331  0192 205601             	jsr fpgetmask
   332  0195 9003               	bcc .fpil1
   333  0197 4c8f03             	jmp monerror
   334                          .fpil1
   335  019a 207b01             	jsr fpgetregspec
   336  019d 9003               	bcc .fpil2
   337  019f 4c8f03             	jmp monerror
   338                          .fpil2
   339  01a2 a529               	lda fpmask
   340  01a4 0528               	ora fpregspec
   341  01a6 8f47fc1b           	sta IO_FP_ILOAD
   342  01aa 4cf703             	jmp moncmd
   343                          
   344                          fpisave
   345  01ad 205601             	jsr fpgetmask
   346  01b0 9003               	bcc .fpis1
   347  01b2 4c8f03             	jmp monerror
   348                          .fpis1
   349  01b5 207b01             	jsr fpgetregspec
   350  01b8 9003               	bcc .fpis2
   351  01ba 4c8f03             	jmp monerror
   352                          .fpis2
   353  01bd a529               	lda fpmask
   354  01bf 0528               	ora fpregspec
   355  01c1 8f48fc1b           	sta IO_FP_ISAVE
   356  01c5 4cf703             	jmp moncmd
   357                          
   358                          fpln
   359  01c8 205601             	jsr fpgetmask
   360  01cb 9003               	bcc .fpln1
   361  01cd 4c8f03             	jmp monerror
   362                          .fpln1
   363  01d0 207b01             	jsr fpgetregspec
   364  01d3 9003               	bcc .fpln2
   365  01d5 4c8f03             	jmp monerror
   366                          .fpln2
   367  01d8 a529               	lda fpmask
   368  01da 0528               	ora fpregspec
   369  01dc 8f46fc1b           	sta IO_FP_LN
   370  01e0 4cf703             	jmp moncmd
   371                          	
   372                          fpmultiply
   373  01e3 205601             	jsr fpgetmask
   374  01e6 9003               	bcc .fpmultiply1
   375  01e8 4c8f03             	jmp monerror
   376                          .fpmultiply1
   377  01eb 207b01             	jsr fpgetregspec
   378  01ee 9003               	bcc .fpmultiply2
   379  01f0 4c8f03             	jmp monerror
   380                          .fpmultiply2
   381  01f3 a529               	lda fpmask
   382  01f5 0528               	ora fpregspec
   383  01f7 8f42fc1b           	sta IO_FP_MULTIPLY
   384  01fb 4cf703             	jmp moncmd
   385                          	
   386                          fpdivide
   387  01fe 205601             	jsr fpgetmask
   388  0201 9003               	bcc .fpdivide1
   389  0203 4c8f03             	jmp monerror
   390                          .fpdivide1
   391  0206 207b01             	jsr fpgetregspec
   392  0209 9003               	bcc .fpdivide2
   393  020b 4c8f03             	jmp monerror
   394                          .fpdivide2
   395  020e a529               	lda fpmask
   396  0210 0528               	ora fpregspec
   397  0212 8f43fc1b           	sta IO_FP_DIVIDE
   398  0216 4cf703             	jmp moncmd
   399                          	
   400                          fpadd
   401  0219 205601             	jsr fpgetmask
   402  021c 9003               	bcc .fpadd1
   403  021e 4c8f03             	jmp monerror
   404                          .fpadd1
   405  0221 207b01             	jsr fpgetregspec
   406  0224 9003               	bcc .fpadd2
   407  0226 4c8f03             	jmp monerror
   408                          .fpadd2
   409  0229 a529               	lda fpmask
   410  022b 0528               	ora fpregspec
   411  022d 8f44fc1b           	sta IO_FP_ADD
   412  0231 4cf703             	jmp moncmd
   413                          	
   414                          fpsubtract
   415  0234 205601             	jsr fpgetmask
   416  0237 9003               	bcc .fpsubtract1
   417  0239 4c8f03             	jmp monerror
   418                          .fpsubtract1
   419  023c 207b01             	jsr fpgetregspec
   420  023f 9003               	bcc .fpsubtract2
   421  0241 4c8f03             	jmp monerror
   422                          .fpsubtract2
   423  0244 a529               	lda fpmask
   424  0246 0528               	ora fpregspec
   425  0248 8f45fc1b           	sta IO_FP_SUBTRACT
   426  024c 4cf703             	jmp moncmd
   427                          	
   428                          fploadconst
   429  024f 205601             	jsr fpgetmask
   430  0252 9003               	bcc .fploadconst1
   431  0254 4c8f03             	jmp monerror
   432                          .fploadconst1
   433  0257 207b01             	jsr fpgetregspec
   434  025a 9003               	bcc .fploadconst2
   435  025c 4c8f03             	jmp monerror
   436                          .fploadconst2
   437  025f 203800             	jsr parse_addr			;get const specifier
   438  0262 c230               	rep #$30
   439  0264 98                 	tya
   440  0265 e220               	sep #$20
   441  0267 291f               	and #$1f				;we're only interested in values 0-31
   442  0269 0529               	ora fpmask
   443  026b 0528               	ora fpregspec
   444  026d 8f40fc1b           	sta IO_FP_INIT_CONSTANT
   445  0271 4cf703             	jmp moncmd
   446                          
   447                          fpdisp
   448  0274 205601             	jsr fpgetmask
   449  0277 9022               	bcc fpdisp2
   450  0279 4c8f03             	jmp monerror
   451                          fpfacctxt
   452  027c 464143433a20       	!tx "FACC: "
   453  0282 00                 	!byte $00
   454                          fpfargtxt
   455  0283 464152473a20       	!tx "FARG: "
   456  0289 00                 	!byte $00
   457                          fpcondtxt
   458  028a 4650434f4e443a20   	!tx "FPCOND: "
   459  0292 00                 	!byte $00
   460                          fpinttxt
   461  0293 4650494e543a20     	!tx "FPINT: "
   462  029a 00                 	!byte $00
   463                          fpdisp2
   464  029b a27c02             	ldx #fpfacctxt			;print FACC: tag
   465  029e 863d               	stx dpla
   466  02a0 a91c               	lda #$1c
   467  02a2 853f               	sta dpla_h
   468  02a4 22ae0e1c           	jsl l_prcdpla
   469  02a8 a20900             	ldx #9
   470  02ab a529               	lda fpmask
   471  02ad 2920               	and #$20
   472  02af d00c               	bne .facchex			;bit 5 set, so fall through and print 10 bytes
   473  02b1 a20700             	ldx #7
   474  02b4 a529               	lda fpmask
   475  02b6 2980               	and #$80
   476  02b8 d003               	bne .facchex			;bit 5 clear, but bit 7 set, print 8 bytes
   477  02ba a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   478                          .facchex					;print X number of hex bytes in reverse order
   479  02bd bfe0fc1b           	lda FPACCUMULATOR,x
   480  02c1 20e505             	jsr+2 prhex
   481  02c4 ca                 	dex
   482  02c5 10f6               	bpl .facchex
   483  02c7 a529               	lda fpmask
   484  02c9 8f41fc1b           	sta IO_FP_TO_ASCII
   485  02cd a92f               	lda #'/'
   486  02cf 8f12fc1b           	sta IO_CON_CHAROUT
   487  02d3 8f13fc1b           	sta IO_CON_REGISTER
   488  02d7 a2c0fc             	ldx #FPASCII_LO16
   489  02da 863d               	stx dpla
   490  02dc a91b               	lda #$1b
   491  02de 853f               	sta dpla_h
   492  02e0 22ae0e1c           	jsl l_prcdpla
   493  02e4 8f17fc1b           	sta IO_CON_CR
   494                          	
   495  02e8 a28302             	ldx #fpfargtxt			;print FARG: tag
   496  02eb 863d               	stx dpla
   497  02ed a91c               	lda #$1c
   498  02ef 853f               	sta dpla_h
   499  02f1 22ae0e1c           	jsl l_prcdpla
   500  02f5 a20900             	ldx #9
   501  02f8 a529               	lda fpmask
   502  02fa 2920               	and #$20
   503  02fc d00c               	bne .farghex			;bit 5 set, so fall through and print 10 bytes
   504  02fe a20700             	ldx #7
   505  0301 a529               	lda fpmask
   506  0303 2980               	and #$80
   507  0305 d003               	bne .farghex			;bit 5 clear, but bit 7 set, print 8 bytes
   508  0307 a20300             	ldx #3					;bit 5/7 both clear, float, print 4 bytes, fall thru
   509                          .farghex					;print X number of hex bytes in reverse order
   510  030a bff0fc1b           	lda FPARGUMENT,x
   511  030e 20e505             	jsr+2 prhex
   512  0311 ca                 	dex
   513  0312 10f6               	bpl .farghex
   514  0314 a529               	lda fpmask
   515  0316 0940               	ora #$40				;select FARG this time
   516  0318 8f41fc1b           	sta IO_FP_TO_ASCII
   517  031c a92f               	lda #'/'
   518  031e 8f12fc1b           	sta IO_CON_CHAROUT
   519  0322 8f13fc1b           	sta IO_CON_REGISTER
   520  0326 a2c0fc             	ldx #FPASCII_LO16
   521  0329 863d               	stx dpla
   522  032b a91b               	lda #$1b
   523  032d 853f               	sta dpla_h
   524  032f 22ae0e1c           	jsl l_prcdpla
   525  0333 8f17fc1b           	sta IO_CON_CR
   526                          	
   527  0337 a28a02             	ldx #fpcondtxt			;print FPCOND: tag
   528  033a 863d               	stx dpla
   529  033c a91c               	lda #$1c
   530  033e 853f               	sta dpla_h
   531  0340 22ae0e1c           	jsl l_prcdpla
   532  0344 a920               	lda #' '
   533  0346 8f12fc1b           	sta IO_CON_CHAROUT
   534  034a 8f13fc1b           	sta IO_CON_REGISTER
   535  034e afbffc1b           	lda FPCOND
   536  0352 20e505             	jsr+2 prhex
   537  0355 8f17fc1b           	sta IO_CON_CR
   538                          	
   539  0359 a29302             	ldx #fpinttxt			;print FPINT tab
   540  035c 863d               	stx dpla
   541  035e a91c               	lda #$1c
   542  0360 853f               	sta dpla_h
   543  0362 22ae0e1c           	jsl l_prcdpla
   544  0366 a920               	lda #' '
   545  0368 8f12fc1b           	sta IO_CON_CHAROUT
   546  036c 8f13fc1b           	sta IO_CON_REGISTER
   547  0370 a20700             	ldx #7
   548                          .fpdisp3
   549  0373 bfd8fc1b           	lda FPINT,x
   550  0377 20e505             	jsr+2 prhex
   551  037a ca                 	dex
   552  037b 10f6               	bpl .fpdisp3
   553  037d 8f17fc1b           	sta IO_CON_CR
   554                          	
   555  0381 4cf703             	jmp moncmd
   556                          	
   557                          bankcmd
   558  0384 203800             	jsr parse_addr
   559  0387 9006               	bcc monerror
   560  0389 98                 	tya
   561  038a 853c               	sta mondump_h
   562  038c 4cf703             	jmp moncmd
   563                          monerror
   564  038f a29f03             	ldx #monsynerr
   565  0392 863d               	stx dpla
   566  0394 a91c               	lda #$1c
   567  0396 853f               	sta dpla_h
   568  0398 22ae0e1c           	jsl l_prcdpla
   569  039c 4cf703             	jmp moncmd
   570                          monsynerr
   571  039f 53796e7461782065...	!tx "Syntax error!"
   572  03ac 0d00               	!byte $0d, $00
   573                          
   574                          colorcmd
   575  03ae 203800             	jsr parse_addr
   576  03b1 90dc               	bcc monerror
   577  03b3 98                 	tya
   578  03b4 8f11fc1b           	sta IO_CON_COLOR
   579  03b8 4cf703             	jmp moncmd
   580                          	
   581                          modecmd
   582  03bb 203800             	jsr parse_addr
   583  03be 90cf               	bcc monerror
   584  03c0 98                 	tya
   585  03c1 c908               	cmp #$08
   586  03c3 90ca               	bcc monerror
   587  03c5 c90a               	cmp #$0a
   588  03c7 b0c6               	bcs monerror
   589  03c9 8f20fc1b           	sta IO_VIDMODE
   590  03cd a900               	lda #$00
   591  03cf 8f14fc1b           	sta IO_CON_CURSORH
   592  03d3 8f15fc1b           	sta IO_CON_CURSORV
   593  03d7 a920               	lda #$20
   594  03d9 8f12fc1b           	sta IO_CON_CHAROUT
   595  03dd 8f10fc1b           	sta IO_CON_CLS
   596  03e1 4cf703             	jmp moncmd
   597                          	
   598                          monstart				;main entry point for system monitor
   599  03e4 4b                 	phk
   600  03e5 ab                 	plb
   601  03e6 c210               	rep #$10
   602                          	!rl
   603  03e8 e220               	sep #$20
   604                          	!as
   605  03ea a20000             	ldx #$0000
   606  03ed 863a               	stx mondump
   607  03ef a91c               	lda #$1c
   608  03f1 853c               	sta mondump_h
   609  03f3 a944               	lda #'D'
   610  03f5 8536               	sta monlast
   611                          	
   612                          	!zone moncmd
   613                          moncmd
   614  03f7 a92a               	lda #promptchar
   615  03f9 8f12fc1b           	sta IO_CON_CHAROUT
   616  03fd 8f13fc1b           	sta IO_CON_REGISTER
   617  0401 222c0e1c           	jsl l_getline
   618  0405 220a0e1c           	jsl l_ucline
   619  0409 201f00             	jsr parse_setup
   620  040c 202900             	jsr parse_getchar
   621                          .local3
   622  040f c951               	cmp #'Q'
   623  0411 f05b               	beq haltcmd
   624  0413 c944               	cmp #'D'
   625  0415 d003               	bne .local4
   626  0417 4c2a05             	jmp+2 dumpcmd
   627                          .local4
   628  041a c90d               	cmp #$0d
   629  041c d008               	bne .local2
   630  041e a536               	lda monlast			;recall previously executed command
   631  0420 c920               	cmp #$20			;make sure it isn't a control character
   632  0422 b0eb               	bcs .local3			;and retry it
   633  0424 80d1               	bra moncmd			;else recycle and try a new command
   634                          .local2
   635  0426 c941               	cmp #'A'
   636  0428 f06a               	beq asciidumpcmd
   637  042a c942               	cmp #'B'
   638  042c d003               	bne .local5
   639  042e 4c8403             	jmp+2 bankcmd
   640                          .local5
   641  0431 c943               	cmp #'C'
   642  0433 d003               	bne .local6
   643  0435 4cae03             	jmp+2 colorcmd
   644                          .local6
   645  0438 c94d               	cmp #'M'
   646  043a d003               	bne .local7
   647  043c 4cbb03             	jmp+2 modecmd
   648                          .local7
   649  043f c945               	cmp #'E'
   650  0441 d003               	bne .local8
   651  0443 4c0506             	jmp+2 entercmd
   652                          .local8
   653  0446 c94c               	cmp #'L'
   654  0448 d003               	bne .local9
   655  044a 4c3306             	jmp+2 listcmd
   656                          .local9
   657  044d c93f               	cmp #'?'
   658  044f f00d               	beq helpcmd
   659  0451 c946               	cmp #'F'
   660  0453 f003               	beq .localfp
   661  0455 4cf703             	jmp moncmd
   662                          .localfp
   663  0458 201601             	jsr fpcmd
   664  045b 4cf703             	jmp moncmd
   665                          	
   666                          helpcmd
   667  045e a2620f             	ldx #helpmsg
   668  0461 863d               	stx dpla
   669  0463 a91c               	lda #$1c
   670  0465 853f               	sta dpla_h
   671  0467 22ae0e1c           	jsl l_prcdpla
   672  046b 4cf703             	jmp moncmd
   673                          	
   674                          haltcmd
   675  046e a27c04             	ldx #haltmsg
   676  0471 863d               	stx dpla
   677  0473 a91c               	lda #$1c
   678  0475 853f               	sta dpla_h
   679  0477 22ae0e1c           	jsl l_prcdpla
   680  047b db                 	stp
   681                          haltmsg
   682  047c 48616c74696e6720...	!tx "Halting 65816 engine.."
   683  0492 0d00               	!byte $0d,$00
   684                          	
   685                          	!zone asciidumpcmd
   686                          asciidumpcmd
   687  0494 8536               	sta monlast
   688  0496 203800             	jsr parse_addr
   689  0499 9021               	bcc .local3
   690  049b 843a               	sty mondump
   691  049d 8433               	sty rangehigh
   692  049f 2435               	bit monrange			;user asking for a range?
   693  04a1 1019               	bpl .local3
   694  04a3 203800             	jsr parse_addr			;get the remaining half of the range
   695  04a6 8433               	sty rangehigh
   696  04a8 a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   697  04aa 8535               	sta monrange
   698  04ac a433               	ldy rangehigh
   699  04ae d003               	bne .local6
   700  04b0 4c8f03             	jmp+2 monerror			;top of range can't be zero
   701                          .local6
   702  04b3 a43a               	ldy mondump
   703  04b5 c433               	cpy rangehigh
   704  04b7 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   705  04b9 4c8f03             	jmp+2 monerror
   706                          .local3
   707  04bc 20c800             	jsr prdumpaddr
   708  04bf a00000             	ldy #$0000
   709                          .local2
   710  04c2 b73a               	lda [mondump],y
   711  04c4 c920               	cmp #$20
   712  04c6 b002               	bcs .local4
   713  04c8 a92e               	lda #'.'				;substitute control character with a period
   714                          .local4
   715  04ca 8f12fc1b           	sta IO_CON_CHAROUT
   716  04ce 8f13fc1b           	sta IO_CON_REGISTER
   717  04d2 c8                 	iny
   718  04d3 af20fc1b           	lda IO_VIDMODE
   719  04d7 c909               	cmp #$09
   720  04d9 d007               	bne .lores1
   721  04db c04000             	cpy #$0040
   722  04de d0e2               	bne .local2
   723  04e0 8005               	bra .lores2
   724                          .lores1
   725  04e2 c01000             	cpy #$0010
   726  04e5 d0db               	bne .local2
   727                          .lores2
   728  04e7 8f17fc1b           	sta IO_CON_CR
   729  04eb 20f100             	jsr adjdumpaddr
   730  04ee b035               	bcs .local5				;carry to bank, exit even if we're processing a range
   731  04f0 20f100             	jsr adjdumpaddr
   732  04f3 b030               	bcs .local5	
   733  04f5 af20fc1b           	lda IO_VIDMODE
   734  04f9 c909               	cmp #$09
   735  04fb d01e               	bne .lores3
   736  04fd 20f100             	jsr adjdumpaddr
   737  0500 b023               	bcs .local5	
   738  0502 20f100             	jsr adjdumpaddr
   739  0505 b01e               	bcs .local5	
   740  0507 20f100             	jsr adjdumpaddr
   741  050a b019               	bcs .local5	
   742  050c 20f100             	jsr adjdumpaddr
   743  050f b014               	bcs .local5	
   744  0511 20f100             	jsr adjdumpaddr
   745  0514 b00f               	bcs .local5	
   746  0516 20f100             	jsr adjdumpaddr
   747  0519 b00a               	bcs .local5	
   748                          .lores3
   749  051b 2435               	bit monrange			;ranges on?
   750  051d 1006               	bpl .local5
   751  051f a433               	ldy rangehigh
   752  0521 c43a               	cpy mondump
   753  0523 b097               	bcs .local3
   754                          .local5
   755  0525 6435               	stz monrange
   756  0527 4cf703             	jmp moncmd
   757                          	
   758                          	!zone dumpcmd
   759                          dumpcmd
   760  052a 8536               	sta monlast
   761  052c 203800             	jsr parse_addr
   762  052f 9021               	bcc .local3
   763  0531 843a               	sty mondump				;if address was specified, store 16 bit y at low 16 bits of mondump address
   764  0533 8433               	sty rangehigh
   765  0535 2435               	bit monrange			;user asking for a range?
   766  0537 1019               	bpl .local3
   767  0539 203800             	jsr parse_addr			;get the remaining half of the range
   768  053c 8433               	sty rangehigh
   769  053e a980               	lda #$80				;replace value in monrange since parse_addr will overwrite it
   770  0540 8535               	sta monrange
   771  0542 a433               	ldy rangehigh
   772  0544 d003               	bne .local6
   773  0546 4c8f03             	jmp+2 monerror			;top of range can't be zero
   774                          .local6
   775  0549 a43a               	ldy mondump
   776  054b c433               	cpy rangehigh
   777  054d 9003               	bcc .local3				;mondump must be less than rangehigh or it's a syntax error
   778  054f 4c8f03             	jmp+2 monerror
   779                          .local3
   780  0552 20c800             	jsr prdumpaddr
   781  0555 a00000             	ldy #$0000
   782                          .local2
   783  0558 b73a               	lda [mondump],y
   784  055a 20e505             	jsr+2 prhex
   785  055d a920               	lda #' '
   786  055f 8f12fc1b           	sta IO_CON_CHAROUT
   787  0563 8f13fc1b           	sta IO_CON_REGISTER
   788  0567 c8                 	iny
   789  0568 af20fc1b           	lda IO_VIDMODE
   790  056c c909               	cmp #$09
   791  056e d03e               	bne .lores1
   792  0570 c01000             	cpy #$0010
   793  0573 d0e3               	bne .local2
   794  0575 a920               	lda #' '
   795  0577 8f12fc1b           	sta IO_CON_CHAROUT
   796  057b 8f13fc1b           	sta IO_CON_REGISTER
   797  057f a92d               	lda #'-'
   798  0581 8f12fc1b           	sta IO_CON_CHAROUT
   799  0585 8f13fc1b           	sta IO_CON_REGISTER
   800  0589 a920               	lda #' '
   801  058b 8f12fc1b           	sta IO_CON_CHAROUT
   802  058f 8f13fc1b           	sta IO_CON_REGISTER
   803  0593 a00000             	ldy #$0000				;print 16 bytes as ASCII... bonus when in mode 9!
   804                          .asc2
   805  0596 b73a               	lda [mondump],y
   806  0598 c920               	cmp #$20
   807  059a b002               	bcs .asc4
   808  059c a92e               	lda #'.'				;substitute control character with a period
   809                          .asc4
   810  059e 8f12fc1b           	sta IO_CON_CHAROUT
   811  05a2 8f13fc1b           	sta IO_CON_REGISTER
   812  05a6 c8                 	iny
   813  05a7 c01000             	cpy #$0010
   814  05aa d0ea               	bne .asc2
   815  05ac 8005               	bra .lores2
   816                          .lores1
   817  05ae c00800             	cpy #$0008
   818  05b1 d0a5               	bne .local2
   819                          .lores2
   820  05b3 8f17fc1b           	sta IO_CON_CR
   821  05b7 20f100             	jsr adjdumpaddr
   822  05ba b01a               	bcs .local5				;carry to bank, exit even if we're processing a range
   823  05bc af20fc1b           	lda IO_VIDMODE
   824  05c0 c909               	cmp #$09
   825  05c2 d005               	bne .lores3
   826  05c4 20f100             	jsr adjdumpaddr
   827  05c7 b00d               	bcs .local5
   828                          .lores3
   829  05c9 2435               	bit monrange			;ranges on?
   830  05cb 1009               	bpl .local5
   831  05cd a433               	ldy rangehigh
   832  05cf c43a               	cpy mondump
   833  05d1 9003               	bcc .local5
   834  05d3 4c5205             	jmp+2 .local3
   835                          .local5
   836  05d6 6435               	stz monrange
   837  05d8 4cf703             	jmp moncmd
   838                          	
   839                          prhex16
   840  05db c230               	rep #$30
   841  05dd 8a                 	txa
   842  05de e220               	sep #$20
   843  05e0 eb                 	xba
   844  05e1 20e505             	jsr+2 prhex
   845  05e4 eb                 	xba
   846                          prhex
   847  05e5 48                 	pha
   848  05e6 4a                 	lsr
   849  05e7 4a                 	lsr
   850  05e8 4a                 	lsr
   851  05e9 4a                 	lsr
   852  05ea 20f005             	jsr+2 prhexnib
   853  05ed 68                 	pla
   854  05ee 290f               	and #$0f
   855                          prhexnib
   856  05f0 0930               	ora #$30
   857  05f2 c93a               	cmp #$3a
   858  05f4 9003               	bcc prhexnofix
   859  05f6 18                 	clc
   860  05f7 6907               	adc #$07
   861                          prhexnofix
   862  05f9 8f12fc1b           	sta IO_CON_CHAROUT
   863  05fd 8f13fc1b           	sta IO_CON_REGISTER
   864  0601 60                 	rts
   865                          
   866                          	!zone entercmd
   867                          .local1
   868  0602 4c8f03             	jmp monerror
   869                          entercmd
   870  0605 203800             	jsr parse_addr
   871  0608 90f8               	bcc .local1			;address is mandatory
   872  060a 2435               	bit monrange
   873  060c 30f4               	bmi .local1			;ranges not allowed
   874  060e 8430               	sty enterbytes
   875  0610 a53c               	lda mondump_h
   876  0612 8532               	sta enterbytes_h	;retrieve bank from mondump
   877                          .local2
   878  0614 203800             	jsr parse_addr		;start grabbing bytes
   879  0617 9017               	bcc .enterdone
   880  0619 2435               	bit monrange
   881  061b 30e5               	bmi .local1			;stop that happening here too
   882  061d c230               	rep #$30
   883  061f 98                 	tya
   884  0620 e220               	sep #$20			;get low byte of parsed address into A
   885  0622 8730               	sta [enterbytes]
   886  0624 e630               	inc enterbytes
   887  0626 d006               	bne .local3
   888  0628 e631               	inc enterbytes_m
   889  062a d002               	bne .local3
   890  062c e632               	inc enterbytes_h
   891                          .local3
   892  062e 80e4               	bra .local2
   893                          .enterdone
   894  0630 4cf703             	jmp moncmd
   895                          	
   896                          	!zone listcmd
   897                          listcmd
   898  0633 203800             	jsr parse_addr
   899  0636 9002               	bcc .listmany				;address is optional
   900  0638 843a               	sty mondump
   901                          .listmany
   902  063a af20fc1b           	lda IO_VIDMODE
   903  063e c909               	cmp #$09
   904  0640 d005               	bne .listmany1
   905  0642 a22000             	ldx #32
   906  0645 8003               	bra .listmany2
   907                          .listmany1
   908  0647 a20f00             	ldx #15
   909                          .listmany2
   910  064a da                 	phx
   911  064b 205506             	jsr+2 .listsingle
   912  064e fa                 	plx
   913  064f ca                 	dex
   914  0650 d0f8               	bne .listmany2
   915  0652 4cf703             	jmp moncmd
   916                          .listsingle
   917  0655 a00000             	ldy #$0000
   918  0658 20c800             	jsr prdumpaddr
   919  065b a900               	lda #$00
   920  065d eb                 	xba					;clear B
   921  065e a73a               	lda [mondump]				;get opcode
   922  0660 48                 	pha					;save opcode
   923  0661 aa                 	tax
   924  0662 bdf60a             	lda mnemlenmode,x
   925  0665 4a                 	lsr
   926  0666 4a                 	lsr
   927  0667 4a                 	lsr
   928  0668 4a                 	lsr
   929  0669 4a                 	lsr					;isolage opcode len
   930  066a 852f               	sta scratch1
   931  066c a73a               	lda [mondump]
   932  066e 209b0a             	jsr+2 is816
   933  0671 a52f               	lda scratch1
   934  0673 aa                 	tax
   935  0674 a00000             	ldy #$0000
   936                          .nextbyte
   937  0677 b73a               	lda [mondump],y
   938  0679 20e505             	jsr prhex			;print hex
   939  067c a920               	lda #' '
   940  067e 8f12fc1b           	sta IO_CON_CHAROUT
   941  0682 8f13fc1b           	sta IO_CON_REGISTER	;print space
   942  0686 c8                 	iny
   943  0687 ca                 	dex
   944  0688 d0ed               	bne .nextbyte
   945  068a a916               	lda #$16
   946  068c 8f14fc1b           	sta IO_CON_CURSORH	;tab over
   947  0690 68                 	pla					;get opcode back
   948  0691 aa                 	tax
   949  0692 bdf60b             	lda mnemlist,x
   950  0695 8530               	sta enterbytes
   951  0697 6431               	stz enterbytes_m	;save for 16 bit add
   952  0699 da                 	phx					;stash our opcode
   953  069a c230               	rep #$30
   954                          	!al
   955  069c 29ff00             	and #$00ff			;switch to 16 bits, clear top
   956  069f 0a                 	asl
   957  06a0 18                 	clc
   958  06a1 6530               	adc enterbytes		;multiply by 3
   959  06a3 aa                 	tax
   960  06a4 e220               	sep #$20
   961                          	!as
   962  06a6 bdf60c             	lda mnems, x
   963  06a9 8f12fc1b           	sta IO_CON_CHAROUT
   964  06ad 8f13fc1b           	sta IO_CON_REGISTER
   965  06b1 e8                 	inx
   966  06b2 bdf60c             	lda mnems, x
   967  06b5 8f12fc1b           	sta IO_CON_CHAROUT
   968  06b9 8f13fc1b           	sta IO_CON_REGISTER
   969  06bd e8                 	inx
   970  06be bdf60c             	lda mnems, x
   971  06c1 8f12fc1b           	sta IO_CON_CHAROUT
   972  06c5 8f13fc1b           	sta IO_CON_REGISTER
   973  06c9 a920               	lda #' '
   974  06cb 8f12fc1b           	sta IO_CON_CHAROUT
   975  06cf 8f13fc1b           	sta IO_CON_REGISTER
   976  06d3 fa                 	plx					;get our opcode back in index
   977  06d4 a900               	lda #$00
   978  06d6 eb                 	xba					;clear top byte of A if it's dirty
   979  06d7 bdf60a             	lda mnemlenmode,x
   980  06da 291f               	and #$1f			;isolate the addressing mode
   981  06dc 0a                 	asl					;multiply by two
   982  06dd aa                 	tax
   983  06de fccc0a             	jsr (listamod,x)
   984  06e1 af20fc1b           	lda IO_VIDMODE
   985  06e5 c909               	cmp #$09
   986  06e7 d01f               	bne .fixup1
   987  06e9 a925               	lda #$25
   988  06eb 8f14fc1b           	sta IO_CON_CURSORH		;tab over and print our bytes as ASCII in 80 column mode
   989  06ef e230               	sep #$30				;8 bit indexes here
   990                          	!rs
   991  06f1 a000               	ldy #$00				;print disassembly bytes as ASCII... bonus when in mode 9!
   992                          .asc2
   993  06f3 b73a               	lda [mondump],y
   994  06f5 c920               	cmp #$20
   995  06f7 b002               	bcs .asc4
   996  06f9 a92e               	lda #'.'				;substitute control character with a period
   997                          .asc4
   998  06fb 8f12fc1b           	sta IO_CON_CHAROUT
   999  06ff 8f13fc1b           	sta IO_CON_REGISTER
  1000  0703 c8                 	iny
  1001  0704 c42f               	cpy scratch1
  1002  0706 d0eb               	bne .asc2
  1003                          .fixup1
  1004  0708 c210               	rep #$10
  1005                          	!rl
  1006  070a 8f17fc1b           	sta IO_CON_CR
  1007                          .fixup
  1008  070e a52f               	lda scratch1		;get our fixup
  1009  0710 18                 	clc
  1010  0711 653a               	adc mondump
  1011  0713 853a               	sta mondump
  1012  0715 a53b               	lda mondump_m
  1013  0717 6900               	adc #$00
  1014  0719 853b               	sta mondump_m
  1015  071b a53c               	lda mondump_h
  1016  071d 6900               	adc #$00
  1017  071f 853c               	sta mondump_h
  1018                          .goback
  1019  0721 60                 	rts
  1020                          
  1021                          amod0
  1022  0722 a924               	lda #'$'
  1023  0724 8f12fc1b           	sta IO_CON_CHAROUT
  1024  0728 8f13fc1b           	sta IO_CON_REGISTER
  1025  072c a00100             	ldy #$0001
  1026  072f b73a               	lda [mondump],y
  1027  0731 20e505             	jsr prhex
  1028  0734 60                 	rts
  1029                          amod1
  1030  0735 a928               	lda #'('
  1031  0737 8f12fc1b           	sta IO_CON_CHAROUT
  1032  073b 8f13fc1b           	sta IO_CON_REGISTER
  1033  073f a924               	lda #'$'
  1034  0741 8f12fc1b           	sta IO_CON_CHAROUT
  1035  0745 8f13fc1b           	sta IO_CON_REGISTER
  1036  0749 a00100             	ldy #$0001
  1037  074c b73a               	lda [mondump],y
  1038  074e 20e505             	jsr prhex
  1039  0751 a92c               	lda #','
  1040  0753 8f12fc1b           	sta IO_CON_CHAROUT
  1041  0757 8f13fc1b           	sta IO_CON_REGISTER
  1042  075b a958               	lda #'X'
  1043  075d 8f12fc1b           	sta IO_CON_CHAROUT
  1044  0761 8f13fc1b           	sta IO_CON_REGISTER
  1045  0765 a929               	lda #')'
  1046  0767 8f12fc1b           	sta IO_CON_CHAROUT
  1047  076b 8f13fc1b           	sta IO_CON_REGISTER
  1048  076f 60                 	rts
  1049                          amod2
  1050  0770 a00100             	ldy #$0001
  1051  0773 b73a               	lda [mondump],y
  1052  0775 20e505             	jsr prhex
  1053  0778 a92c               	lda #','
  1054  077a 8f12fc1b           	sta IO_CON_CHAROUT
  1055  077e 8f13fc1b           	sta IO_CON_REGISTER
  1056  0782 a953               	lda #'S'
  1057  0784 8f12fc1b           	sta IO_CON_CHAROUT
  1058  0788 8f13fc1b           	sta IO_CON_REGISTER
  1059  078c 60                 	rts
  1060                          amod3
  1061  078d a95b               	lda #'['
  1062  078f 8f12fc1b           	sta IO_CON_CHAROUT
  1063  0793 8f13fc1b           	sta IO_CON_REGISTER
  1064  0797 a924               	lda #'$'
  1065  0799 8f12fc1b           	sta IO_CON_CHAROUT
  1066  079d 8f13fc1b           	sta IO_CON_REGISTER
  1067  07a1 a00100             	ldy #$0001
  1068  07a4 b73a               	lda [mondump],y
  1069  07a6 20e505             	jsr prhex
  1070  07a9 a95d               	lda #']'
  1071  07ab 8f12fc1b           	sta IO_CON_CHAROUT
  1072  07af 8f13fc1b           	sta IO_CON_REGISTER
  1073                          amod4
  1074  07b3 60                 	rts
  1075                          	!zone amod5
  1076                          amod5
  1077  07b4 a923               	lda #'#'
  1078  07b6 8f12fc1b           	sta IO_CON_CHAROUT
  1079  07ba 8f13fc1b           	sta IO_CON_REGISTER
  1080  07be a924               	lda #'$'
  1081  07c0 8f12fc1b           	sta IO_CON_CHAROUT
  1082  07c4 8f13fc1b           	sta IO_CON_REGISTER
  1083  07c8 a52f               	lda scratch1
  1084  07ca c902               	cmp #$02
  1085  07cc f008               	beq .amod508
  1086                          .amod516
  1087  07ce a00200             	ldy #$0002
  1088  07d1 b73a               	lda [mondump],y
  1089  07d3 20e505             	jsr prhex
  1090                          .amod508
  1091  07d6 a00100             	ldy #$0001
  1092  07d9 b73a               	lda [mondump],y
  1093  07db 20e505             	jsr prhex
  1094  07de 60                 	rts
  1095                          amod6
  1096  07df a924               	lda #'$'
  1097  07e1 8f12fc1b           	sta IO_CON_CHAROUT
  1098  07e5 8f13fc1b           	sta IO_CON_REGISTER
  1099  07e9 a00200             	ldy #$0002
  1100  07ec b73a               	lda [mondump],y
  1101  07ee 20e505             	jsr prhex
  1102  07f1 88                 	dey
  1103  07f2 b73a               	lda [mondump],y
  1104  07f4 4ce505             	jmp prhex
  1105                          amod7
  1106  07f7 a924               	lda #'$'
  1107  07f9 8f12fc1b           	sta IO_CON_CHAROUT
  1108  07fd 8f13fc1b           	sta IO_CON_REGISTER
  1109  0801 a00300             	ldy #$0003
  1110  0804 b73a               	lda [mondump],y
  1111  0806 20e505             	jsr prhex
  1112  0809 88                 	dey
  1113  080a b73a               	lda [mondump],y
  1114  080c 20e505             	jsr prhex
  1115  080f 88                 	dey
  1116  0810 b73a               	lda [mondump],y
  1117  0812 4ce505             	jmp prhex
  1118                          amod11
  1119  0815 a00300             	ldy #$0003
  1120  0818 842a               	sty scratch2			;number of bytes to bump offset
  1121  081a a00200             	ldy #$0002
  1122  081d b73a               	lda [mondump],y
  1123  081f eb                 	xba
  1124  0820 88                 	dey
  1125  0821 b73a               	lda [mondump],y
  1126  0823 8014               	bra amod8nosign
  1127                          amod8
  1128  0825 a00200             	ldy #$0002
  1129  0828 842a               	sty scratch2
  1130  082a a900               	lda #$00
  1131  082c eb                 	xba						;clear high byte of A
  1132                          amod8a
  1133  082d a00100             	ldy #$0001
  1134  0830 b73a               	lda [mondump],y			;get rel byte
  1135  0832 1005               	bpl amod8nosign
  1136  0834 48                 	pha
  1137  0835 a9ff               	lda #$ff
  1138  0837 eb                 	xba						;sign extend if negative
  1139  0838 68                 	pla
  1140                          amod8nosign
  1141  0839 c230               	rep #$30
  1142                          	!al
  1143  083b 18                 	clc
  1144  083c 653a               	adc mondump				;add to our current disassembly address
  1145  083e 18                 	clc
  1146  083f 652a               	adc scratch2			;add offset for instruction size
  1147  0841 aa                 	tax
  1148  0842 e220               	sep #$20
  1149                          	!as
  1150  0844 a924               	lda #'$'
  1151  0846 8f12fc1b           	sta IO_CON_CHAROUT
  1152  084a 8f13fc1b           	sta IO_CON_REGISTER
  1153  084e 20db05             	jsr prhex16
  1154  0851 60                 	rts
  1155                          amod9
  1156  0852 a928               	lda #'('
  1157  0854 8f12fc1b           	sta IO_CON_CHAROUT
  1158  0858 8f13fc1b           	sta IO_CON_REGISTER
  1159  085c a924               	lda #'$'
  1160  085e 8f12fc1b           	sta IO_CON_CHAROUT
  1161  0862 8f13fc1b           	sta IO_CON_REGISTER
  1162  0866 a00100             	ldy #$0001
  1163  0869 b73a               	lda [mondump],y
  1164  086b 20e505             	jsr prhex
  1165  086e a929               	lda #')'
  1166  0870 8f12fc1b           	sta IO_CON_CHAROUT
  1167  0874 8f13fc1b           	sta IO_CON_REGISTER
  1168  0878 a92c               	lda #','
  1169  087a 8f12fc1b           	sta IO_CON_CHAROUT
  1170  087e 8f13fc1b           	sta IO_CON_REGISTER
  1171  0882 a959               	lda #'Y'
  1172  0884 8f12fc1b           	sta IO_CON_CHAROUT
  1173  0888 8f13fc1b           	sta IO_CON_REGISTER
  1174  088c 60                 	rts
  1175                          amoda
  1176  088d a928               	lda #'('
  1177  088f 8f12fc1b           	sta IO_CON_CHAROUT
  1178  0893 8f13fc1b           	sta IO_CON_REGISTER
  1179  0897 a924               	lda #'$'
  1180  0899 8f12fc1b           	sta IO_CON_CHAROUT
  1181  089d 8f13fc1b           	sta IO_CON_REGISTER
  1182  08a1 a00100             	ldy #$0001
  1183  08a4 b73a               	lda [mondump],y
  1184  08a6 20e505             	jsr prhex
  1185  08a9 a929               	lda #')'
  1186  08ab 8f12fc1b           	sta IO_CON_CHAROUT
  1187  08af 8f13fc1b           	sta IO_CON_REGISTER
  1188  08b3 60                 	rts
  1189                          amodb
  1190  08b4 a928               	lda #'('
  1191  08b6 8f12fc1b           	sta IO_CON_CHAROUT
  1192  08ba 8f13fc1b           	sta IO_CON_REGISTER
  1193  08be a924               	lda #'$'
  1194  08c0 8f12fc1b           	sta IO_CON_CHAROUT
  1195  08c4 8f13fc1b           	sta IO_CON_REGISTER
  1196  08c8 a00100             	ldy #$0001
  1197  08cb b73a               	lda [mondump],y
  1198  08cd 20e505             	jsr prhex
  1199  08d0 a92c               	lda #','
  1200  08d2 8f12fc1b           	sta IO_CON_CHAROUT
  1201  08d6 8f13fc1b           	sta IO_CON_REGISTER
  1202  08da a953               	lda #'S'
  1203  08dc 8f12fc1b           	sta IO_CON_CHAROUT
  1204  08e0 8f13fc1b           	sta IO_CON_REGISTER
  1205  08e4 a929               	lda #')'
  1206  08e6 8f12fc1b           	sta IO_CON_CHAROUT
  1207  08ea 8f13fc1b           	sta IO_CON_REGISTER
  1208  08ee a92c               	lda #','
  1209  08f0 8f12fc1b           	sta IO_CON_CHAROUT
  1210  08f4 8f13fc1b           	sta IO_CON_REGISTER
  1211  08f8 a959               	lda #'Y'
  1212  08fa 8f12fc1b           	sta IO_CON_CHAROUT
  1213  08fe 8f13fc1b           	sta IO_CON_REGISTER
  1214  0902 60                 	rts
  1215                          amodc
  1216  0903 a924               	lda #'$'
  1217  0905 8f12fc1b           	sta IO_CON_CHAROUT
  1218  0909 8f13fc1b           	sta IO_CON_REGISTER
  1219  090d a00100             	ldy #$0001
  1220  0910 b73a               	lda [mondump],y
  1221  0912 20e505             	jsr prhex
  1222  0915 a92c               	lda #','
  1223  0917 8f12fc1b           	sta IO_CON_CHAROUT
  1224  091b 8f13fc1b           	sta IO_CON_REGISTER
  1225  091f a958               	lda #'X'
  1226  0921 8f12fc1b           	sta IO_CON_CHAROUT
  1227  0925 8f13fc1b           	sta IO_CON_REGISTER
  1228  0929 60                 	rts
  1229                          amodd
  1230  092a a95b               	lda #'['
  1231  092c 8f12fc1b           	sta IO_CON_CHAROUT
  1232  0930 8f13fc1b           	sta IO_CON_REGISTER
  1233  0934 a924               	lda #'$'
  1234  0936 8f12fc1b           	sta IO_CON_CHAROUT
  1235  093a 8f13fc1b           	sta IO_CON_REGISTER
  1236  093e a00100             	ldy #$0001
  1237  0941 b73a               	lda [mondump],y
  1238  0943 20e505             	jsr prhex
  1239  0946 a95d               	lda #']'
  1240  0948 8f12fc1b           	sta IO_CON_CHAROUT
  1241  094c 8f13fc1b           	sta IO_CON_REGISTER
  1242  0950 a92c               	lda #','
  1243  0952 8f12fc1b           	sta IO_CON_CHAROUT
  1244  0956 8f13fc1b           	sta IO_CON_REGISTER
  1245  095a a959               	lda #'Y'
  1246  095c 8f12fc1b           	sta IO_CON_CHAROUT
  1247  0960 8f13fc1b           	sta IO_CON_REGISTER
  1248  0964 60                 	rts
  1249                          amode
  1250  0965 a924               	lda #'$'
  1251  0967 8f12fc1b           	sta IO_CON_CHAROUT
  1252  096b 8f13fc1b           	sta IO_CON_REGISTER
  1253  096f a00200             	ldy #$0002
  1254  0972 b73a               	lda [mondump],y
  1255  0974 20e505             	jsr prhex
  1256  0977 88                 	dey
  1257  0978 b73a               	lda [mondump],y
  1258  097a 20e505             	jsr prhex
  1259  097d a92c               	lda #','
  1260  097f 8f12fc1b           	sta IO_CON_CHAROUT
  1261  0983 8f13fc1b           	sta IO_CON_REGISTER
  1262  0987 a958               	lda #'X'
  1263  0989 8f12fc1b           	sta IO_CON_CHAROUT
  1264  098d 8f13fc1b           	sta IO_CON_REGISTER
  1265  0991 60                 	rts
  1266                          amodf
  1267  0992 a924               	lda #'$'
  1268  0994 8f12fc1b           	sta IO_CON_CHAROUT
  1269  0998 8f13fc1b           	sta IO_CON_REGISTER
  1270  099c a00200             	ldy #$0002
  1271  099f b73a               	lda [mondump],y
  1272  09a1 20e505             	jsr prhex
  1273  09a4 88                 	dey
  1274  09a5 b73a               	lda [mondump],y
  1275  09a7 20e505             	jsr prhex
  1276  09aa a92c               	lda #','
  1277  09ac 8f12fc1b           	sta IO_CON_CHAROUT
  1278  09b0 8f13fc1b           	sta IO_CON_REGISTER
  1279  09b4 a959               	lda #'Y'
  1280  09b6 8f12fc1b           	sta IO_CON_CHAROUT
  1281  09ba 8f13fc1b           	sta IO_CON_REGISTER
  1282  09be 60                 	rts
  1283                          amod10
  1284  09bf a924               	lda #'$'
  1285  09c1 8f12fc1b           	sta IO_CON_CHAROUT
  1286  09c5 8f13fc1b           	sta IO_CON_REGISTER
  1287  09c9 a00300             	ldy #$0003
  1288  09cc b73a               	lda [mondump],y
  1289  09ce 20e505             	jsr prhex
  1290  09d1 88                 	dey
  1291  09d2 b73a               	lda [mondump],y
  1292  09d4 20e505             	jsr prhex
  1293  09d7 88                 	dey
  1294  09d8 b73a               	lda [mondump],y
  1295  09da 20e505             	jsr prhex
  1296  09dd a92c               	lda #','
  1297  09df 8f12fc1b           	sta IO_CON_CHAROUT
  1298  09e3 8f13fc1b           	sta IO_CON_REGISTER
  1299  09e7 a958               	lda #'X'
  1300  09e9 8f12fc1b           	sta IO_CON_CHAROUT
  1301  09ed 8f13fc1b           	sta IO_CON_REGISTER
  1302  09f1 60                 	rts
  1303                          amod12
  1304  09f2 a928               	lda #'('
  1305  09f4 8f12fc1b           	sta IO_CON_CHAROUT
  1306  09f8 8f13fc1b           	sta IO_CON_REGISTER
  1307  09fc a924               	lda #'$'
  1308  09fe 8f12fc1b           	sta IO_CON_CHAROUT
  1309  0a02 8f13fc1b           	sta IO_CON_REGISTER
  1310  0a06 a00200             	ldy #$0002
  1311  0a09 b73a               	lda [mondump],y
  1312  0a0b 20e505             	jsr prhex
  1313  0a0e 88                 	dey
  1314  0a0f b73a               	lda [mondump],y
  1315  0a11 20e505             	jsr prhex
  1316  0a14 a929               	lda #')'
  1317  0a16 8f12fc1b           	sta IO_CON_CHAROUT
  1318  0a1a 8f13fc1b           	sta IO_CON_REGISTER
  1319  0a1e 60                 	rts
  1320                          amod13
  1321  0a1f a928               	lda #'('
  1322  0a21 8f12fc1b           	sta IO_CON_CHAROUT
  1323  0a25 8f13fc1b           	sta IO_CON_REGISTER
  1324  0a29 a924               	lda #'$'
  1325  0a2b 8f12fc1b           	sta IO_CON_CHAROUT
  1326  0a2f 8f13fc1b           	sta IO_CON_REGISTER
  1327  0a33 a00200             	ldy #$0002
  1328  0a36 b73a               	lda [mondump],y
  1329  0a38 20e505             	jsr prhex
  1330  0a3b 88                 	dey
  1331  0a3c b73a               	lda [mondump],y
  1332  0a3e 20e505             	jsr prhex
  1333  0a41 a92c               	lda #','
  1334  0a43 8f12fc1b           	sta IO_CON_CHAROUT
  1335  0a47 8f13fc1b           	sta IO_CON_REGISTER
  1336  0a4b a958               	lda #'X'
  1337  0a4d 8f12fc1b           	sta IO_CON_CHAROUT
  1338  0a51 8f13fc1b           	sta IO_CON_REGISTER
  1339  0a55 a929               	lda #')'
  1340  0a57 8f12fc1b           	sta IO_CON_CHAROUT
  1341  0a5b 8f13fc1b           	sta IO_CON_REGISTER
  1342  0a5f 60                 	rts
  1343                          amod14
  1344  0a60 a924               	lda #'$'
  1345  0a62 8f12fc1b           	sta IO_CON_CHAROUT
  1346  0a66 8f13fc1b           	sta IO_CON_REGISTER
  1347  0a6a a00100             	ldy #$0001
  1348  0a6d b73a               	lda [mondump],y
  1349  0a6f 20e505             	jsr prhex
  1350  0a72 a92c               	lda #','
  1351  0a74 8f12fc1b           	sta IO_CON_CHAROUT
  1352  0a78 8f13fc1b           	sta IO_CON_REGISTER
  1353  0a7c a959               	lda #'Y'
  1354  0a7e 8f12fc1b           	sta IO_CON_CHAROUT
  1355  0a82 8f13fc1b           	sta IO_CON_REGISTER
  1356  0a86 60                 	rts
  1357                          	
  1358                          						;test branches for disassembly purposes..
  1359  0a87 70d7               	bvs amod14
  1360  0a89 7010               	bvs is816
  1361  0a8b 7092               	bvs amod13
  1362  0a8d 703d               	bvs listamod
  1363  0a8f 6260ff             	per amod12
  1364  0a92 620600             	per is816
  1365  0a95 6227ff             	per amod10
  1366  0a98 623100             	per listamod
  1367                          	
  1368                          	!zone is816
  1369                          is816
  1370  0a9b 48                 	pha
  1371  0a9c 291f               	and #$1f
  1372  0a9e c909               	cmp #$09				;09, 29, 49, etc?
  1373  0aa0 d006               	bne .testx
  1374  0aa2 242d               	bit alarge				;16 bit?
  1375  0aa4 3020               	bmi .is16
  1376  0aa6 1018               	bpl .is8
  1377                          .testx
  1378  0aa8 68                 	pla
  1379  0aa9 48                 	pha
  1380  0aaa c9a0               	cmp #$a0
  1381  0aac f00e               	beq .isx
  1382  0aae c9a2               	cmp #$a2
  1383  0ab0 f00a               	beq .isx
  1384  0ab2 c9c0               	cmp #$c0
  1385  0ab4 f006               	beq .isx
  1386  0ab6 c9e0               	cmp #$e0
  1387  0ab8 f002               	beq .isx
  1388  0aba 68                 	pla						;made it here, not an accumulator or index instruction
  1389  0abb 60                 	rts
  1390                          .isx
  1391  0abc 242e               	bit xlarge
  1392  0abe 3006               	bmi .is16				;or else fall thru
  1393                          .is8
  1394  0ac0 a902               	lda #$2
  1395  0ac2 852f               	sta scratch1
  1396  0ac4 68                 	pla
  1397  0ac5 60                 	rts
  1398                          .is16
  1399  0ac6 a903               	lda #$3
  1400  0ac8 852f               	sta scratch1
  1401  0aca 68                 	pla
  1402  0acb 60                 	rts
  1403                          	
  1404                          listamod
  1405  0acc 2207               	!16 amod0			;$xx
  1406  0ace 3507               	!16 amod1			;($xx,X)
  1407  0ad0 7007               	!16 amod2			;x,S
  1408  0ad2 8d07               	!16 amod3			;[$xx]
  1409  0ad4 b307               	!16 amod4			;implied
  1410  0ad6 b407               	!16 amod5			;#$xx (or #$yyxx)
  1411  0ad8 df07               	!16 amod6			;$yyxx
  1412  0ada f707               	!16 amod7			;$zzyyxx
  1413  0adc 2508               	!16 amod8			;rel8
  1414  0ade 5208               	!16 amod9			;($xx),Y
  1415  0ae0 8d08               	!16 amoda			;($xx)
  1416  0ae2 b408               	!16 amodb			;(xx,S),Y
  1417  0ae4 0309               	!16 amodc			;$xx,X
  1418  0ae6 2a09               	!16 amodd			;[$xx],Y
  1419  0ae8 6509               	!16 amode			;$yyxx,X
  1420  0aea 9209               	!16 amodf			;$yyxx,Y
  1421  0aec bf09               	!16 amod10			;$zzyyxx,X
  1422  0aee 1508               	!16 amod11			;rel16
  1423  0af0 f209               	!16 amod12			;($yyxx)
  1424  0af2 1f0a               	!16 amod13			;($yyxx,X)
  1425  0af4 600a               	!16 amod14			;$xx,Y
  1426                          	
  1427                          mnemlenmode
  1428  0af6 40                 	!byte %01000000		;00 brk 2/$xx
  1429  0af7 41                 	!byte %01000001		;01 ora 2/($xx,x)
  1430  0af8 40                 	!byte %01000000		;02 cop 2/$xx
  1431  0af9 42                 	!byte %01000010		;03 ora 2/x,s
  1432  0afa 40                 	!byte %01000000		;04 tsb 2/$xx
  1433  0afb 40                 	!byte %01000000		;05 ora 2/$xx
  1434  0afc 40                 	!byte %01000000		;06 asl 2/$xx
  1435  0afd 43                 	!byte %01000011		;07 ora 2/[$xx]
  1436  0afe 24                 	!byte %00100100		;08 php 1
  1437  0aff 45                 	!byte %01000101		;09 ora 2/#imm
  1438  0b00 24                 	!byte %00100100		;0a asl 1
  1439  0b01 24                 	!byte %00100100		;0b phd 1
  1440  0b02 66                 	!byte %01100110		;0c tsb 3/$yyxx
  1441  0b03 66                 	!byte %01100110		;0d ora 3/$yyxx
  1442  0b04 66                 	!byte %01100110		;0e asl 3/$yyxx
  1443  0b05 87                 	!byte %10000111		;0f ora 4/$zzyyxx
  1444  0b06 48                 	!byte %01001000		;10 bpl 2/rel8
  1445  0b07 49                 	!byte %01001001		;11 ora 2/($xx),Y
  1446  0b08 4a                 	!byte %01001010		;12 ora 2/($xx)
  1447  0b09 4b                 	!byte %01001011		;13 ora 2/(x,s),Y
  1448  0b0a 40                 	!byte %01000000		;14 trb 2/$xx
  1449  0b0b 4c                 	!byte %01001100		;15 ora 2/$xx,X
  1450  0b0c 4c                 	!byte %01001100		;16 asl 2/$xx,X
  1451  0b0d 4d                 	!byte %01001101		;17 ora 2/[$xx],Y
  1452  0b0e 24                 	!byte %00100100		;18 clc 1
  1453  0b0f 6f                 	!byte %01101111		;19 ora 3/$yyxx,Y
  1454  0b10 24                 	!byte %00100100		;1a inc 1
  1455  0b11 24                 	!byte %00100100		;1b tcs 1
  1456  0b12 66                 	!byte %01100110		;1c trb 3/$yyxx
  1457  0b13 6e                 	!byte %01101110		;1d ora 3/$yyxx,X
  1458  0b14 6e                 	!byte %01101110		;1e asl 3/$yyxx,X
  1459  0b15 90                 	!byte %10010000		;1f ora 4/$zzyyxx,X
  1460  0b16 66                 	!byte %01100110		;20 jsr 3/$yyxx
  1461  0b17 41                 	!byte %01000001		;21 and 2/($xx,x)
  1462  0b18 87                 	!byte %10000111		;22 jsl 4/$zzyyxx
  1463  0b19 42                 	!byte %01000010		;23 and 2/x,s
  1464  0b1a 40                 	!byte %01000000		;24 bit 2/$xx
  1465  0b1b 40                 	!byte %01000000		;25 and 2/$xx
  1466  0b1c 40                 	!byte %01000000		;26 rol 2/$xx
  1467  0b1d 43                 	!byte %01000011		;27 and 2/[$xx]
  1468  0b1e 24                 	!byte %00100100		;28 plp 1
  1469  0b1f 45                 	!byte %01000101		;29 and 2/#imm
  1470  0b20 24                 	!byte %00100100		;2a rol 1
  1471  0b21 24                 	!byte %00100100		;2b pld 1
  1472  0b22 66                 	!byte %01100110		;2c bit 3/$yyxx
  1473  0b23 66                 	!byte %01100110		;2d and 3/$yyxx
  1474  0b24 66                 	!byte %01100110		;2e rol 3/$yyxx
  1475  0b25 87                 	!byte %10000111		;2f and 4/$zzyyxx
  1476  0b26 48                 	!byte %01001000		;30 bmi 2/rel8
  1477  0b27 49                 	!byte %01001001		;31 and 2/($xx),Y
  1478  0b28 4a                 	!byte %01001010		;32 and 2/($xx)
  1479  0b29 4b                 	!byte %01001011		;33 and 2/(x,s),Y
  1480  0b2a 4c                 	!byte %01001100		;34 bit 2/$xx,X
  1481  0b2b 4c                 	!byte %01001100		;35 and 2/$xx,X
  1482  0b2c 4c                 	!byte %01001100		;36 rol 2/$xx,X
  1483  0b2d 4d                 	!byte %01001101		;37 and 2/[$xx],Y
  1484  0b2e 24                 	!byte %00100100		;38 sec 1
  1485  0b2f 6f                 	!byte %01101111		;39 and 3/$yyxx,Y
  1486  0b30 24                 	!byte %00100100		;3a dec 1
  1487  0b31 24                 	!byte %00100100		;3b tsc 1
  1488  0b32 6e                 	!byte %01101110		;3c bit 3/$yyxx,X
  1489  0b33 6e                 	!byte %01101110		;3d and 3/$yyxx,X
  1490  0b34 6e                 	!byte %01101110		;3e rol 3/$yyxx,X
  1491  0b35 90                 	!byte %10010000		;3f and 4/$zzyyxx,X
  1492  0b36 24                 	!byte %00100100		;40 ???
  1493  0b37 41                 	!byte %01000001		;41 eor 2/($xx,x)
  1494  0b38 40                 	!byte %01000000		;42 wdm 2/$00
  1495  0b39 42                 	!byte %01000010		;43 eor 2/x,s
  1496  0b3a 24                 	!byte %00100100		;44 ???
  1497  0b3b 40                 	!byte %01000000		;45 eor 2/$xx
  1498  0b3c 40                 	!byte %01000000		;46 lsr 2/$xx
  1499  0b3d 43                 	!byte %01000011		;47 eor 2/[$xx]
  1500  0b3e 24                 	!byte %00100100		;48 pha 1
  1501  0b3f 45                 	!byte %01000101		;49 eor 2/#imm
  1502  0b40 24                 	!byte %00100100		;4a lsr 1
  1503  0b41 24                 	!byte %00100100		;4b phk 1
  1504  0b42 66                 	!byte %01100110		;4c jmp 3/$yyxx
  1505  0b43 66                 	!byte %01100110		;4d eor 3/$yyxx
  1506  0b44 66                 	!byte %01100110		;4e lsr 3/$yyxx
  1507  0b45 87                 	!byte %10000111		;4f eor 4/$zzyyxx
  1508  0b46 48                 	!byte %01001000		;50 bvc 2/rel8
  1509  0b47 49                 	!byte %01001001		;51 eor 2/($xx),Y
  1510  0b48 4a                 	!byte %01001010		;52 eor 2/($xx)
  1511  0b49 4b                 	!byte %01001011		;53 eor 2/(x,s),Y
  1512  0b4a 24                 	!byte %00100100		;54 ???
  1513  0b4b 4c                 	!byte %01001100		;55 eor 2/$xx,X
  1514  0b4c 4c                 	!byte %01001100		;56 lsr 2/$xx,X
  1515  0b4d 4d                 	!byte %01001101		;57 eor 2/[$xx],Y
  1516  0b4e 24                 	!byte %00100100		;58 cli 1
  1517  0b4f 6f                 	!byte %01101111		;59 eor 3/$yyxx,Y
  1518  0b50 24                 	!byte %00100100		;5a phy 1
  1519  0b51 24                 	!byte %00100100		;5b tcd 1
  1520  0b52 87                 	!byte %10000111		;5c jml 4/$zzyyxx
  1521  0b53 6e                 	!byte %01101110		;5d eor 3/$yyxx,X
  1522  0b54 6e                 	!byte %01101110		;5e lsr 3/$yyxx,X
  1523  0b55 90                 	!byte %10010000		;5f eor 4/$zzyyxx,X
  1524  0b56 24                 	!byte %00100100		;60 rts
  1525  0b57 41                 	!byte %01000001		;61 adc 2/($xx,x)
  1526  0b58 71                 	!byte %01110001		;62 per 3/rel16
  1527  0b59 42                 	!byte %01000010		;63 adc 2/x,s
  1528  0b5a 40                 	!byte %01000000		;64 stz 2/$xx
  1529  0b5b 40                 	!byte %01000000		;65 adc 2/$xx
  1530  0b5c 40                 	!byte %01000000		;66 ror 2/$xx
  1531  0b5d 43                 	!byte %01000011		;67 adc 2/[$xx]
  1532  0b5e 24                 	!byte %00100100		;68 pla 1
  1533  0b5f 45                 	!byte %01000101		;69 adc 2/#imm
  1534  0b60 24                 	!byte %00100100		;6a ror 1
  1535  0b61 24                 	!byte %00100100		;6b rtl 1
  1536  0b62 72                 	!byte %01110010		;6c jmp 3/($yyxx)
  1537  0b63 66                 	!byte %01100110		;6d adc 3/$yyxx
  1538  0b64 66                 	!byte %01100110		;6e ror 3/$yyxx
  1539  0b65 87                 	!byte %10000111		;6f adc 4/$zzyyxx
  1540  0b66 48                 	!byte %01001000		;70 bvs 2/rel8
  1541  0b67 49                 	!byte %01001001		;71 adc 2/($xx),Y
  1542  0b68 4a                 	!byte %01001010		;72 adc 2/($xx)
  1543  0b69 4b                 	!byte %01001011		;73 adc 2/(x,s),Y
  1544  0b6a 4c                 	!byte %01001100		;74 stz 2/$xx,X
  1545  0b6b 4c                 	!byte %01001100		;75 adc 2/$xx,X
  1546  0b6c 4c                 	!byte %01001100		;76 ror 2/$xx,X
  1547  0b6d 4d                 	!byte %01001101		;77 adc 2/[$xx],Y
  1548  0b6e 24                 	!byte %00100100		;78 sei 1
  1549  0b6f 6f                 	!byte %01101111		;79 adc 3/$yyxx,Y
  1550  0b70 24                 	!byte %00100100		;7a ply 1
  1551  0b71 24                 	!byte %00100100		;7b tdc 1
  1552  0b72 73                 	!byte %01110011		;7c jmp 3/($yyxx,X)
  1553  0b73 6e                 	!byte %01101110		;7d adc 3/$yyxx,X
  1554  0b74 6e                 	!byte %01101110		;7e lsr 3/$yyxx,X
  1555  0b75 90                 	!byte %10010000		;7f adc 4/$zzyyxx,X
  1556  0b76 48                 	!byte %01001000		;80 bra 2/rel8
  1557  0b77 41                 	!byte %01000001		;81 sta 2/($xx,x)
  1558  0b78 71                 	!byte %01110001		;82 brl 3/rel16
  1559  0b79 42                 	!byte %01000010		;83 sta 2/x,s
  1560  0b7a 40                 	!byte %01000000		;84 sty 2/$xx
  1561  0b7b 40                 	!byte %01000000		;85 sta 2/$xx
  1562  0b7c 40                 	!byte %01000000		;86 stx 2/$xx
  1563  0b7d 43                 	!byte %01000011		;87 sta 2/[$xx]
  1564  0b7e 24                 	!byte %00100100		;88 dey 1
  1565  0b7f 45                 	!byte %01000101		;89 bit 2/#imm
  1566  0b80 24                 	!byte %00100100		;8a txa 1
  1567  0b81 24                 	!byte %00100100		;8b phb 1
  1568  0b82 66                 	!byte %01100110		;8c sty 3/$yyxx
  1569  0b83 66                 	!byte %01100110		;8d sta 3/$yyxx
  1570  0b84 66                 	!byte %01100110		;8e stx 3/$yyxx
  1571  0b85 87                 	!byte %10000111		;8f sta 4/$zzyyxx
  1572  0b86 48                 	!byte %01001000		;90 bcc 2/rel8
  1573  0b87 49                 	!byte %01001001		;91 sta 2/($xx),Y
  1574  0b88 4a                 	!byte %01001010		;92 sta 2/($xx)
  1575  0b89 4b                 	!byte %01001011		;93 sta 2/(x,s),Y
  1576  0b8a 4c                 	!byte %01001100		;94 sty 2/$xx,X
  1577  0b8b 4c                 	!byte %01001100		;95 sta 2/$xx,X
  1578  0b8c 54                 	!byte %01010100		;96 stx 2/$xx,Y
  1579  0b8d 4d                 	!byte %01001101		;97 sta 2/[$xx],Y
  1580  0b8e 24                 	!byte %00100100		;98 txa 1
  1581  0b8f 6f                 	!byte %01101111		;99 sta 3/$yyxx,Y
  1582  0b90 24                 	!byte %00100100		;9a txs 1
  1583  0b91 24                 	!byte %00100100		;9b txy 1
  1584  0b92 66                 	!byte %01100110		;9c stz 3/$yyxx
  1585  0b93 6e                 	!byte %01101110		;9d sta 3/$yyxx,X
  1586  0b94 6e                 	!byte %01101110		;9e stz 3/$yyxx,X
  1587  0b95 90                 	!byte %10010000		;9f sta 4/$zzyyxx,X
  1588  0b96 45                 	!byte %01000101		;a0 ldy 2/#imm
  1589  0b97 41                 	!byte %01000001		;a1 lda 2/($xx,x)
  1590  0b98 45                 	!byte %01000101		;a2 ldx 2/#imm
  1591  0b99 42                 	!byte %01000010		;a3 lda 2/x,s
  1592  0b9a 40                 	!byte %01000000		;a4 ldy 2/$xx
  1593  0b9b 40                 	!byte %01000000		;a5 sta 2/$xx
  1594  0b9c 40                 	!byte %01000000		;a6 ldx 2/$xx
  1595  0b9d 43                 	!byte %01000011		;a7 lda 2/[$xx]
  1596  0b9e 24                 	!byte %00100100		;a8 tay 1
  1597  0b9f 45                 	!byte %01000101		;a9 lda 2/#imm
  1598  0ba0 24                 	!byte %00100100		;aa tax 1
  1599  0ba1 24                 	!byte %00100100		;ab plb 1
  1600  0ba2 66                 	!byte %01100110		;ac ldy 3/$yyxx
  1601  0ba3 66                 	!byte %01100110		;ad lda 3/$yyxx
  1602  0ba4 66                 	!byte %01100110		;ae ldx 3/$yyxx
  1603  0ba5 87                 	!byte %10000111		;af lda 4/$zzyyxx
  1604  0ba6 48                 	!byte %01001000		;b0 bcs 2/rel8
  1605  0ba7 49                 	!byte %01001001		;b1 lda 2/($xx),Y
  1606  0ba8 4a                 	!byte %01001010		;b2 lda 2/($xx)
  1607  0ba9 4b                 	!byte %01001011		;b3 lda 2/(x,s),Y
  1608  0baa 4c                 	!byte %01001100		;b4 ldy 2/$xx,X
  1609  0bab 4c                 	!byte %01001100		;b5 lda 2/$xx,X
  1610  0bac 54                 	!byte %01010100		;b6 ldx 2/$xx,Y
  1611  0bad 4d                 	!byte %01001101		;b7 lda 2/[$xx],Y
  1612  0bae 24                 	!byte %00100100		;b8 clv 1
  1613  0baf 6f                 	!byte %01101111		;b9 lda 3/$yyxx,Y
  1614  0bb0 24                 	!byte %00100100		;ba tsx 1
  1615  0bb1 24                 	!byte %00100100		;bb tyx 1
  1616  0bb2 66                 	!byte %01100110		;bc ldy 3/$yyxx
  1617  0bb3 6e                 	!byte %01101110		;bd lda 3/$yyxx,X
  1618  0bb4 6e                 	!byte %01101110		;be ldx 3/$yyxx,X
  1619  0bb5 90                 	!byte %10010000		;bf lda 4/$zzyyxx,X
  1620  0bb6 45                 	!byte %01000101		;c0 cpy 2/#imm
  1621  0bb7 41                 	!byte %01000001		;c1 cmp 2/($xx,x)
  1622  0bb8 45                 	!byte %01000101		;c2 rep 2/#imm
  1623  0bb9 42                 	!byte %01000010		;c3 cmp 2/x,s
  1624  0bba 40                 	!byte %01000000		;c4 cpx 2/$xx
  1625  0bbb 40                 	!byte %01000000		;c5 cmp 2/$xx
  1626  0bbc 40                 	!byte %01000000		;c6 dec 2/$xx
  1627  0bbd 43                 	!byte %01000011		;c7 cmp 2/[$xx]
  1628  0bbe 24                 	!byte %00100100		;c8 iny 1
  1629  0bbf 45                 	!byte %01000101		;c9 cmp 2/#imm
  1630  0bc0 24                 	!byte %00100100		;ca dex 1
  1631  0bc1 24                 	!byte %00100100		;cb wai 1
  1632  0bc2 66                 	!byte %01100110		;cc cpy 3/$yyxx
  1633  0bc3 66                 	!byte %01100110		;cd cmp 3/$yyxx
  1634  0bc4 66                 	!byte %01100110		;ce dec 3/$yyxx
  1635  0bc5 87                 	!byte %10000111		;cf cmp 4/$zzyyxx
  1636  0bc6 48                 	!byte %01001000		;d0 bne 2/rel8
  1637  0bc7 49                 	!byte %01001001		;d1 cmp 2/($xx),Y
  1638  0bc8 4a                 	!byte %01001010		;d2 cmp 2/($xx)
  1639  0bc9 4b                 	!byte %01001011		;d3 cmp 2/(x,s),Y
  1640  0bca 4a                 	!byte %01001010		;d4 pei 2/($xx)
  1641  0bcb 4c                 	!byte %01001100		;d5 cmp 2/$xx,X
  1642  0bcc 4c                 	!byte %01001100		;d6 dec 2/$xx,X
  1643  0bcd 4d                 	!byte %01001101		;d7 cmp 2/[$xx],Y
  1644  0bce 24                 	!byte %00100100		;d8 cld 1
  1645  0bcf 6f                 	!byte %01101111		;d9 cmp 3/$yyxx,Y
  1646  0bd0 24                 	!byte %00100100		;da phx 1
  1647  0bd1 24                 	!byte %00100100		;db stp 1
  1648  0bd2 43                 	!byte %01000011		;dc jml 2/[$xx]
  1649  0bd3 6e                 	!byte %01101110		;dd cmp 3/$yyxx,X
  1650  0bd4 6e                 	!byte %01101110		;de dec 3/$yyxx,X
  1651  0bd5 90                 	!byte %10010000		;df cmp 4/$zzyyxx,X
  1652  0bd6 45                 	!byte %01000101		;e0 cpx 2/#imm
  1653  0bd7 41                 	!byte %01000001		;e1 sbc 2/($xx,x)
  1654  0bd8 45                 	!byte %01000101		;e2 sep 2/#imm
  1655  0bd9 42                 	!byte %01000010		;e3 sbc 2/x,s
  1656  0bda 40                 	!byte %01000000		;e4 cpx 2/$xx
  1657  0bdb 40                 	!byte %01000000		;e5 sbc 2/$xx
  1658  0bdc 40                 	!byte %01000000		;e6 inc 2/$xx
  1659  0bdd 43                 	!byte %01000011		;e7 sbc 2/[$xx]
  1660  0bde 24                 	!byte %00100100		;e8 inx 1
  1661  0bdf 45                 	!byte %01000101		;e9 sbc 2/#imm
  1662  0be0 24                 	!byte %00100100		;ea nop 1
  1663  0be1 24                 	!byte %00100100		;eb xba 1
  1664  0be2 66                 	!byte %01100110		;ec cpx 3/$yyxx
  1665  0be3 66                 	!byte %01100110		;ed sbc 3/$yyxx
  1666  0be4 66                 	!byte %01100110		;ee inc 3/$yyxx
  1667  0be5 87                 	!byte %10000111		;ef sbc 4/$zzyyxx
  1668  0be6 48                 	!byte %01001000		;f0 beq 2/rel8
  1669  0be7 49                 	!byte %01001001		;f1 sbc 2/($xx),Y
  1670  0be8 4a                 	!byte %01001010		;f2 sbc 2/($xx)
  1671  0be9 4b                 	!byte %01001011		;f3 sbc 2/(x,s),Y
  1672  0bea 66                 	!byte %01100110		;f4 pea 3/$yyxx
  1673  0beb 4c                 	!byte %01001100		;f5 sbc 2/$xx,X
  1674  0bec 4c                 	!byte %01001100		;f6 inc 2/$xx,X
  1675  0bed 4d                 	!byte %01001101		;f7 sbc 2/[$xx],Y
  1676  0bee 24                 	!byte %00100100		;f8 sed 1
  1677  0bef 6f                 	!byte %01101111		;f9 sbc 3/$yyxx,Y
  1678  0bf0 24                 	!byte %00100100		;fa plx 1
  1679  0bf1 24                 	!byte %00100100		;fb xce 1
  1680  0bf2 73                 	!byte %01110011		;fc jsr 3/($yyxx)
  1681  0bf3 6e                 	!byte %01101110		;fd sbc 3/$yyxx,X
  1682  0bf4 6e                 	!byte %01101110		;fe inc 3/$yyxx,X
  1683  0bf5 90                 	!byte %10010000		;ff sbc 4/$zzyyxx,X
  1684                          mnemlist
  1685  0bf6 00                 	!byte $00			;00 brk
  1686  0bf7 02                 	!byte $02			;01 ora
  1687  0bf8 01                 	!byte $01			;02 cop
  1688  0bf9 02                 	!byte $02			;03 ora
  1689  0bfa 03                 	!byte $03			;04 tsb
  1690  0bfb 02                 	!byte $02			;05 ora
  1691  0bfc 04                 	!byte $04			;06 asl
  1692  0bfd 02                 	!byte $02			;07 ora
  1693  0bfe 05                 	!byte $05			;08 php
  1694  0bff 02                 	!byte $02			;09 ora
  1695  0c00 04                 	!byte $04			;0a asl
  1696  0c01 06                 	!byte $06			;0b phd
  1697  0c02 03                 	!byte $03			;0c tsb
  1698  0c03 02                 	!byte $02			;0d ora
  1699  0c04 04                 	!byte $04			;0e asl
  1700  0c05 02                 	!byte $02			;0f ora
  1701  0c06 07                 	!byte $07			;10 bpl
  1702  0c07 02                 	!byte $02			;11 ora
  1703  0c08 02                 	!byte $02			;12 ora
  1704  0c09 02                 	!byte $02			;13 ora
  1705  0c0a 08                 	!byte $08			;14 trb
  1706  0c0b 02                 	!byte $02			;15 ora
  1707  0c0c 04                 	!byte $04			;16 asl
  1708  0c0d 02                 	!byte $02			;17 ora
  1709  0c0e 09                 	!byte $09			;18 clc
  1710  0c0f 02                 	!byte $02			;19 ora
  1711  0c10 0a                 	!byte $0a			;1a inc
  1712  0c11 0b                 	!byte $0b			;1b tcs
  1713  0c12 08                 	!byte $08			;1c trb
  1714  0c13 02                 	!byte $02			;1d ora
  1715  0c14 04                 	!byte $04			;1e asl
  1716  0c15 02                 	!byte $02			;1f ora
  1717  0c16 0d                 	!byte $0d			;20 jsr
  1718  0c17 0c                 	!byte $0c			;21 and
  1719  0c18 0e                 	!byte $0e			;22 jsl
  1720  0c19 0c                 	!byte $0c			;23 and
  1721  0c1a 10                 	!byte $10			;24 bit
  1722  0c1b 0c                 	!byte $0c			;25 and
  1723  0c1c 11                 	!byte $11			;26 rol
  1724  0c1d 0c                 	!byte $0c			;27 and
  1725  0c1e 12                 	!byte $12			;28 plp
  1726  0c1f 0c                 	!byte $0c			;29 and
  1727  0c20 11                 	!byte $11			;2a rol
  1728  0c21 13                 	!byte $13			;2b pld
  1729  0c22 10                 	!byte $10			;2c bit
  1730  0c23 0c                 	!byte $0c			;2d and
  1731  0c24 11                 	!byte $11			;2e rol
  1732  0c25 0c                 	!byte $0c			;2f and
  1733  0c26 14                 	!byte $14			;30 bmi
  1734  0c27 0c                 	!byte $0c			;31 and
  1735  0c28 0c                 	!byte $0c			;32 and
  1736  0c29 0c                 	!byte $0c			;33 and
  1737  0c2a 11                 	!byte $11			;34 bit
  1738  0c2b 0c                 	!byte $0c			;35 and
  1739  0c2c 11                 	!byte $11			;36 rol
  1740  0c2d 0c                 	!byte $0c			;37 and
  1741  0c2e 15                 	!byte $15			;38 sec
  1742  0c2f 0c                 	!byte $0c			;39 and
  1743  0c30 0f                 	!byte $0f			;3a dec
  1744  0c31 16                 	!byte $16			;3b tsc
  1745  0c32 11                 	!byte $11			;3c bit
  1746  0c33 0c                 	!byte $0c			;3d and
  1747  0c34 11                 	!byte $11			;3e rol
  1748  0c35 0c                 	!byte $0c			;3f and
  1749  0c36 17                 	!byte $17			;40 ???
  1750  0c37 18                 	!byte $18			;41 eor
  1751  0c38 19                 	!byte $19			;42 wdm
  1752  0c39 18                 	!byte $18			;43 eor
  1753  0c3a 17                 	!byte $17			;44 ???
  1754  0c3b 18                 	!byte $18			;45 eor
  1755  0c3c 1a                 	!byte $1a			;46 lsr
  1756  0c3d 18                 	!byte $18			;47 eor
  1757  0c3e 1b                 	!byte $1b			;48 pha
  1758  0c3f 18                 	!byte $18			;49 eor
  1759  0c40 1a                 	!byte $1a			;4a lsr
  1760  0c41 1c                 	!byte $1c			;4b phk
  1761  0c42 1d                 	!byte $1d			;4c jmp
  1762  0c43 18                 	!byte $18			;4d eor
  1763  0c44 1a                 	!byte $1a			;4e lsr
  1764  0c45 18                 	!byte $18			;4f eor
  1765  0c46 1e                 	!byte $1e			;50 bvc
  1766  0c47 18                 	!byte $18			;51 eor
  1767  0c48 18                 	!byte $18			;52 eor
  1768  0c49 18                 	!byte $18			;53 eor
  1769  0c4a 17                 	!byte $17			;54 ???
  1770  0c4b 18                 	!byte $18			;55 eor
  1771  0c4c 1a                 	!byte $1a			;56 lsr
  1772  0c4d 18                 	!byte $18			;57 eor
  1773  0c4e 1f                 	!byte $1f			;58 cli
  1774  0c4f 18                 	!byte $18			;59 eor
  1775  0c50 20                 	!byte $20			;5a phy
  1776  0c51 21                 	!byte $21			;5b tcd
  1777  0c52 22                 	!byte $22			;5c jml
  1778  0c53 18                 	!byte $18			;5d eor
  1779  0c54 1a                 	!byte $1a			;5e lsr
  1780  0c55 18                 	!byte $18			;5f eor
  1781  0c56 23                 	!byte $23			;60 rts
  1782  0c57 24                 	!byte $24			;61 adc
  1783  0c58 25                 	!byte $25			;62 per
  1784  0c59 24                 	!byte $24			;63 adc
  1785  0c5a 26                 	!byte $26			;64 stz
  1786  0c5b 24                 	!byte $24			;65 adc
  1787  0c5c 27                 	!byte $27			;66 ror
  1788  0c5d 24                 	!byte $24			;67 adc
  1789  0c5e 28                 	!byte $28			;68 pla
  1790  0c5f 24                 	!byte $24			;69 adc
  1791  0c60 27                 	!byte $27			;6a ror
  1792  0c61 29                 	!byte $29			;6b rtl
  1793  0c62 1d                 	!byte $1d			;6c jmp
  1794  0c63 24                 	!byte $24			;6d adc
  1795  0c64 27                 	!byte $27			;6e ror
  1796  0c65 24                 	!byte $24			;6f adc
  1797  0c66 2a                 	!byte $2a			;70 bvs
  1798  0c67 24                 	!byte $24			;71 adc
  1799  0c68 24                 	!byte $24			;72 adc
  1800  0c69 24                 	!byte $24			;73 adc
  1801  0c6a 26                 	!byte $26			;74 stz
  1802  0c6b 24                 	!byte $24			;75 adc
  1803  0c6c 27                 	!byte $27			;76 ror
  1804  0c6d 24                 	!byte $24			;77 adc
  1805  0c6e 2b                 	!byte $2b			;78 sei
  1806  0c6f 24                 	!byte $24			;79 adc
  1807  0c70 2c                 	!byte $2c			;7a ply
  1808  0c71 2d                 	!byte $2d			;7b tdc
  1809  0c72 1d                 	!byte $1d			;7c jmp
  1810  0c73 24                 	!byte $24			;7d adc
  1811  0c74 27                 	!byte $27			;7e ror
  1812  0c75 24                 	!byte $24			;7f adc
  1813  0c76 2e                 	!byte $2e			;80 bra
  1814  0c77 2f                 	!byte $2f			;81 sta
  1815  0c78 30                 	!byte $30			;82 brl
  1816  0c79 2f                 	!byte $2f			;83 sta
  1817  0c7a 31                 	!byte $31			;84 sty
  1818  0c7b 2f                 	!byte $2f			;85 sta
  1819  0c7c 32                 	!byte $32			;86 stx
  1820  0c7d 2f                 	!byte $2f			;87 sta
  1821  0c7e 33                 	!byte $33			;88 dey
  1822  0c7f 10                 	!byte $10			;89 bit
  1823  0c80 34                 	!byte $34			;8a txa
  1824  0c81 35                 	!byte $35			;8b phb
  1825  0c82 31                 	!byte $31			;8c sty
  1826  0c83 2f                 	!byte $2f			;8d sta
  1827  0c84 32                 	!byte $32			;8e stx
  1828  0c85 2f                 	!byte $2f			;8f sta
  1829  0c86 36                 	!byte $36			;90 bcc
  1830  0c87 2f                 	!byte $2f			;91 sta
  1831  0c88 2f                 	!byte $2f			;92 sta
  1832  0c89 2f                 	!byte $2f			;93 sta
  1833  0c8a 31                 	!byte $31			;94 sty
  1834  0c8b 2f                 	!byte $2f			;95 sta
  1835  0c8c 32                 	!byte $32			;96 stx
  1836  0c8d 2f                 	!byte $2f			;97 sta
  1837  0c8e 37                 	!byte $37			;98 tya
  1838  0c8f 2f                 	!byte $2f			;99 sta
  1839  0c90 38                 	!byte $38			;9a txs
  1840  0c91 39                 	!byte $39			;9b txy
  1841  0c92 26                 	!byte $26			;9c stz
  1842  0c93 2f                 	!byte $2f			;9d sta
  1843  0c94 26                 	!byte $26			;9e stz
  1844  0c95 2f                 	!byte $2f			;9f sta
  1845  0c96 3c                 	!byte $3c			;a0 ldy
  1846  0c97 3a                 	!byte $3a			;a1 lda
  1847  0c98 3b                 	!byte $3b			;a2 ldx
  1848  0c99 3a                 	!byte $3a			;a3 lda
  1849  0c9a 3c                 	!byte $3c			;a4 ldy
  1850  0c9b 3a                 	!byte $3a			;a5 lda
  1851  0c9c 3b                 	!byte $3b			;a6 ldx
  1852  0c9d 3a                 	!byte $3a			;a7 lda
  1853  0c9e 3d                 	!byte $3d			;a8 tay
  1854  0c9f 3a                 	!byte $3a			;a9 lda
  1855  0ca0 3e                 	!byte $3e			;aa tax
  1856  0ca1 3f                 	!byte $3f			;ab plb
  1857  0ca2 3c                 	!byte $3c			;ac ldy
  1858  0ca3 3a                 	!byte $3a			;ad lda
  1859  0ca4 3b                 	!byte $3b			;ae ldx
  1860  0ca5 3a                 	!byte $3a			;af lda
  1861  0ca6 40                 	!byte $40			;b0 bcs
  1862  0ca7 3a                 	!byte $3a			;b1 lda
  1863  0ca8 3a                 	!byte $3a			;b2 lda
  1864  0ca9 3a                 	!byte $3a			;b3 lda
  1865  0caa 3c                 	!byte $3c			;b4 ldy
  1866  0cab 3a                 	!byte $3a			;b5 lda
  1867  0cac 3b                 	!byte $3b			;b6 ldx
  1868  0cad 3a                 	!byte $3a			;b7 lda
  1869  0cae 41                 	!byte $41			;b8 clv
  1870  0caf 3a                 	!byte $3a			;b9 lda
  1871  0cb0 42                 	!byte $42			;ba tsx
  1872  0cb1 43                 	!byte $43			;bb tyx
  1873  0cb2 3c                 	!byte $3c			;bc ldy
  1874  0cb3 3a                 	!byte $3a			;bd lda
  1875  0cb4 3b                 	!byte $3b			;be ldx
  1876  0cb5 3a                 	!byte $3a			;bf lda
  1877  0cb6 46                 	!byte $46			;c0 cpy
  1878  0cb7 44                 	!byte $44			;c1 cmp
  1879  0cb8 47                 	!byte $47			;c2 rep
  1880  0cb9 44                 	!byte $44			;c3 cmp
  1881  0cba 46                 	!byte $46			;c4 cpy
  1882  0cbb 44                 	!byte $44			;c5 cmp
  1883  0cbc 48                 	!byte $48			;c6 dec
  1884  0cbd 44                 	!byte $44			;c7 cmp
  1885  0cbe 49                 	!byte $49			;c8 iny
  1886  0cbf 44                 	!byte $44			;c9 cmp
  1887  0cc0 4a                 	!byte $4a			;ca dex
  1888  0cc1 4b                 	!byte $4b			;cb wai
  1889  0cc2 46                 	!byte $46			;cc cpy
  1890  0cc3 44                 	!byte $44			;cd cmp
  1891  0cc4 48                 	!byte $48			;ce dec
  1892  0cc5 44                 	!byte $44			;cf cmp
  1893  0cc6 4c                 	!byte $4c			;d0 bne
  1894  0cc7 44                 	!byte $44			;d1 cmp
  1895  0cc8 44                 	!byte $44			;d2 cmp
  1896  0cc9 44                 	!byte $44			;d3 cmp
  1897  0cca 4d                 	!byte $4d			;d4 pei
  1898  0ccb 44                 	!byte $44			;d5 cmp
  1899  0ccc 48                 	!byte $48			;d6 dec
  1900  0ccd 44                 	!byte $44			;d7 cmp
  1901  0cce 4e                 	!byte $4e			;d8 cld
  1902  0ccf 44                 	!byte $44			;d9 cmp
  1903  0cd0 4f                 	!byte $4f			;da phx
  1904  0cd1 50                 	!byte $50			;db stp
  1905  0cd2 22                 	!byte $22			;dc jml
  1906  0cd3 44                 	!byte $44			;dd cmp
  1907  0cd4 48                 	!byte $48			;de dec
  1908  0cd5 44                 	!byte $44			;df cmp
  1909  0cd6 51                 	!byte $51			;e0 cpx
  1910  0cd7 45                 	!byte $45			;e1 sbc
  1911  0cd8 52                 	!byte $52			;e2 sep
  1912  0cd9 45                 	!byte $45			;e3 sbc
  1913  0cda 51                 	!byte $51			;e4 cpx
  1914  0cdb 45                 	!byte $45			;e5 sbc
  1915  0cdc 53                 	!byte $53			;e6 inc
  1916  0cdd 45                 	!byte $45			;e7 sbc
  1917  0cde 54                 	!byte $54			;e8 inx
  1918  0cdf 45                 	!byte $45			;e9 sbc
  1919  0ce0 55                 	!byte $55			;ea nop
  1920  0ce1 56                 	!byte $56			;eb xba
  1921  0ce2 51                 	!byte $51			;ec cpx
  1922  0ce3 45                 	!byte $45			;ed sbc
  1923  0ce4 53                 	!byte $53			;ee inc
  1924  0ce5 45                 	!byte $45			;ef sbc
  1925  0ce6 57                 	!byte $57			;f0 beq
  1926  0ce7 45                 	!byte $45			;f1 sbc
  1927  0ce8 45                 	!byte $45			;f2 sbc
  1928  0ce9 45                 	!byte $45			;f3 sbc
  1929  0cea 58                 	!byte $58			;f4 pea
  1930  0ceb 45                 	!byte $45			;f5 sbc
  1931  0cec 53                 	!byte $53			;f6 inc
  1932  0ced 45                 	!byte $45			;f7 sbc
  1933  0cee 59                 	!byte $59			;f8 sed
  1934  0cef 45                 	!byte $45			;f9 sbc
  1935  0cf0 5a                 	!byte $5a			;fa plx
  1936  0cf1 5b                 	!byte $5b			;fb xce
  1937  0cf2 0d                 	!byte $0d			;fc jsr
  1938  0cf3 45                 	!byte $45			;fd sbc
  1939  0cf4 53                 	!byte $53			;fe inc
  1940  0cf5 45                 	!byte $45			;ff sbc
  1941                          mnems
  1942  0cf6 42524b             	!tx "BRK"			;0
  1943  0cf9 434f50             	!tx "COP"			;1
  1944  0cfc 4f5241             	!tx "ORA"			;2
  1945  0cff 545342             	!tx "TSB"			;3
  1946  0d02 41534c             	!tx "ASL"			;4
  1947  0d05 504850             	!tx "PHP"			;5
  1948  0d08 504844             	!tx "PHD"			;6
  1949  0d0b 42504c             	!tx "BPL"			;7
  1950  0d0e 545242             	!tx "TRB"			;8
  1951  0d11 434c43             	!tx "CLC"			;9
  1952  0d14 494e43             	!tx "INC"			;a
  1953  0d17 544353             	!tx "TCS"			;b
  1954  0d1a 414e44             	!tx "AND"			;c
  1955  0d1d 4a5352             	!tx "JSR"			;d
  1956  0d20 4a534c             	!tx "JSL"			;e
  1957  0d23 444543             	!tx "DEC"			;f
  1958  0d26 424954             	!tx "BIT"			;10
  1959  0d29 524f4c             	!tx "ROL"			;11
  1960  0d2c 504c50             	!tx "PLP"			;12
  1961  0d2f 504c44             	!tx "PLD"			;13
  1962  0d32 424d49             	!tx "BMI"			;14
  1963  0d35 534543             	!tx "SEC"			;15
  1964  0d38 545343             	!tx "TSC"			;16
  1965  0d3b 3f3f3f             	!tx "???"			;17
  1966  0d3e 454f52             	!tx "EOR"			;18
  1967  0d41 57444d             	!tx "WDM"			;19
  1968  0d44 4c5352             	!tx "LSR"			;1a
  1969  0d47 504841             	!tx "PHA"			;1b
  1970  0d4a 50484b             	!tx "PHK"			;1c
  1971  0d4d 4a4d50             	!tx "JMP"			;1d
  1972  0d50 425643             	!tx "BVC"			;1e
  1973  0d53 434c49             	!tx "CLI"			;1f
  1974  0d56 504859             	!tx "PHY"			;20
  1975  0d59 544344             	!tx "TCD"			;21
  1976  0d5c 4a4d4c             	!tx "JML"			;22
  1977  0d5f 525453             	!tx "RTS"			;23
  1978  0d62 414443             	!tx "ADC"			;24
  1979  0d65 504552             	!tx "PER"			;25
  1980  0d68 53545a             	!tx "STZ"			;26
  1981  0d6b 524f52             	!tx "ROR"			;27
  1982  0d6e 504c41             	!tx "PLA"			;28
  1983  0d71 52544c             	!tx "RTL"			;29
  1984  0d74 425653             	!tx "BVS"			;2a
  1985  0d77 534549             	!tx "SEI"			;2b
  1986  0d7a 504c59             	!tx "PLY"			;2c
  1987  0d7d 544443             	!tx "TDC"			;2d
  1988  0d80 425241             	!tx "BRA"			;2e
  1989  0d83 535441             	!tx "STA"			;2f
  1990  0d86 42524c             	!tx "BRL"			;30
  1991  0d89 535459             	!tx "STY"			;31
  1992  0d8c 535458             	!tx "STX"			;32
  1993  0d8f 444559             	!tx "DEY"			;33
  1994  0d92 545841             	!tx "TXA"			;34
  1995  0d95 504842             	!tx "PHB"			;35
  1996  0d98 424343             	!tx "BCC"			;36
  1997  0d9b 545941             	!tx "TYA"			;37
  1998  0d9e 545853             	!tx "TXS"			;38
  1999  0da1 545859             	!tx "TXY"			;39
  2000  0da4 4c4441             	!tx "LDA"			;3a
  2001  0da7 4c4458             	!tx "LDX"			;3b
  2002  0daa 4c4459             	!tx "LDY"			;3c
  2003  0dad 544159             	!tx "TAY"			;3d
  2004  0db0 544158             	!tx "TAX"			;3e
  2005  0db3 504c42             	!tx "PLB"			;3f
  2006  0db6 424353             	!tx "BCS"			;40
  2007  0db9 434c56             	!tx "CLV"			;41
  2008  0dbc 545358             	!tx "TSX"			;42
  2009  0dbf 545958             	!tx "TYX"			;43
  2010  0dc2 434d50             	!tx "CMP"			;44
  2011  0dc5 534243             	!tx "SBC"			;45
  2012  0dc8 435059             	!tx "CPY"			;46
  2013  0dcb 524550             	!tx "REP"			;47
  2014  0dce 444543             	!tx "DEC"			;48
  2015  0dd1 494e59             	!tx "INY"			;49
  2016  0dd4 444558             	!tx "DEX"			;4a
  2017  0dd7 574149             	!tx "WAI"			;4b
  2018  0dda 424e45             	!tx "BNE"			;4c
  2019  0ddd 504549             	!tx "PEI"			;4d
  2020  0de0 434c44             	!tx "CLD"			;4e
  2021  0de3 504858             	!tx "PHX"			;4f
  2022  0de6 535450             	!tx "STP"			;50
  2023  0de9 435058             	!tx "CPX"			;51
  2024  0dec 534550             	!tx "SEP"			;52
  2025  0def 494e43             	!tx "INC"			;53
  2026  0df2 494e58             	!tx "INX"			;54
  2027  0df5 4e4f50             	!tx "NOP"			;55
  2028  0df8 584241             	!tx "XBA"			;56
  2029  0dfb 424551             	!tx "BEQ"			;57
  2030  0dfe 504541             	!tx "PEA"			;58
  2031  0e01 534544             	!tx "SED"			;59
  2032  0e04 504c58             	!tx "PLX"			;5a
  2033  0e07 584345             	!tx "XCE"			;5b
  2034                          	
  2035                          	!zone ucline
  2036                          ucline					;convert inbuff at $170400 to upper case
  2037  0e0a 08                 	php
  2038  0e0b c210               	rep #$10
  2039  0e0d e220               	sep #$20
  2040                          	!as
  2041                          	!rl
  2042  0e0f a20000             	ldx #$0000
  2043                          .local2
  2044  0e12 bf000417           	lda inbuff,x
  2045  0e16 f012               	beq .local4			;hit the zero, so bail
  2046  0e18 c961               	cmp #'a'
  2047  0e1a 900b               	bcc .local3			;less then lowercase a, so ignore
  2048  0e1c c97b               	cmp #'z' + 1		;less than next character after lowercase z?
  2049  0e1e b007               	bcs .local3			;greater than or equal, so ignore
  2050  0e20 38                 	sec
  2051  0e21 e920               	sbc #('z' - 'Z')	;make upper case
  2052  0e23 9f000417           	sta inbuff,x
  2053                          .local3
  2054  0e27 e8                 	inx
  2055  0e28 80e8               	bra .local2
  2056                          .local4
  2057  0e2a 28                 	plp
  2058  0e2b 6b                 	rtl
  2059                          	
  2060                          	!zone getline
  2061                          getline
  2062  0e2c 08                 	php
  2063  0e2d c210               	rep #$10
  2064  0e2f e220               	sep #$20
  2065                          	!as
  2066                          	!rl
  2067  0e31 a20000             	ldx #$0000
  2068                          .local2
  2069  0e34 af00fc1b           	lda IO_KEYQ_SIZE
  2070  0e38 f0fa               	beq .local2
  2071  0e3a af01fc1b           	lda IO_KEYQ_WAITING
  2072  0e3e 8f02fc1b           	sta IO_KEYQ_DEQUEUE
  2073  0e42 c90d               	cmp #$0d			;carriage return yet?
  2074  0e44 f01c               	beq .local3
  2075  0e46 c908               	cmp #$08			;backspace/back arrow?
  2076  0e48 f029               	beq .local4
  2077  0e4a c920               	cmp #$20 			;generally any control character besides what we're specifically looking for?
  2078  0e4c 90e6               	bcc .local2		 		;yes, so ignore it
  2079  0e4e 9f000417           	sta inbuff,x 		;any other character, so register it and store it
  2080  0e52 8f12fc1b           	sta IO_CON_CHAROUT
  2081  0e56 8f13fc1b           	sta IO_CON_REGISTER
  2082  0e5a e8                 	inx
  2083  0e5b a90d               	lda #$0d			;tee up a CR just in case we have to fall thru below
  2084  0e5d e0fe03             	cpx #$3fe			;overrun end of buffer yet?
  2085  0e60 d0d2               	bne .local2			;no, so get another char.. otherwise fall thru
  2086                          .local3
  2087  0e62 9f000417           	sta inbuff,x		;store CR
  2088  0e66 8f17fc1b           	sta IO_CON_CR
  2089  0e6a e8                 	inx
  2090  0e6b a900               	lda #$00			;store zero to end it all
  2091  0e6d 9f000417           	sta inbuff,x
  2092  0e71 28                 	plp
  2093  0e72 6b                 	rtl
  2094                          .local4
  2095  0e73 e00000             	cpx #$0000
  2096  0e76 f0bc               	beq .local2			;no data in buffer yet, so nothing to backspace over
  2097  0e78 a908               	lda #$08
  2098  0e7a 8f12fc1b           	sta IO_CON_CHAROUT
  2099  0e7e 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char, which backs up the cursor
  2100  0e82 a920               	lda #$20
  2101  0e84 8f12fc1b           	sta IO_CON_CHAROUT
  2102  0e88 8f13fc1b           	sta IO_CON_REGISTER	;blot out the character with a space
  2103  0e8c a908               	lda #$08
  2104  0e8e 8f12fc1b           	sta IO_CON_CHAROUT
  2105  0e92 8f13fc1b           	sta IO_CON_REGISTER	;print backspace char again since we advanced the cursor
  2106  0e96 ca                 	dex
  2107  0e97 809b               	bra .local2
  2108                          	
  2109                          prinbuff				;feed location of input buffer into dpla and then print
  2110  0e99 08                 	php
  2111  0e9a c210               	rep #$10
  2112  0e9c e220               	sep #$20
  2113                          	!as
  2114                          	!rl
  2115  0e9e a917               	lda #$17
  2116  0ea0 853f               	sta dpla_h
  2117  0ea2 a904               	lda #$04
  2118  0ea4 853e               	sta dpla_m
  2119  0ea6 643d               	stz dpla
  2120  0ea8 22ae0e1c           	jsl l_prcdpla
  2121  0eac 28                 	plp
  2122  0ead 6b                 	rtl
  2123                          	
  2124                          	!zone prcdpla
  2125                          prcdpla					; print C string pointed to by dp locations $3d-$3f
  2126  0eae 08                 	php					; modified for color coding (0x01/color byte to change colors)
  2127  0eaf c210               	rep #$10			;  0x02 = return to default color
  2128  0eb1 e220               	sep #$20
  2129                          	!as
  2130                          	!rl
  2131  0eb3 af11fc1b           	lda IO_CON_COLOR
  2132  0eb7 852f               	sta scratch1
  2133  0eb9 a00000             	ldy #$0000
  2134                          .local2
  2135  0ebc b73d               	lda [dpla],y
  2136  0ebe f013               	beq .local3
  2137  0ec0 c901               	cmp #$01
  2138  0ec2 f017               	beq .local4
  2139  0ec4 c902               	cmp #$02
  2140  0ec6 f01d               	beq .local5
  2141  0ec8 8f12fc1b           	sta IO_CON_CHAROUT
  2142  0ecc 8f13fc1b           	sta IO_CON_REGISTER
  2143  0ed0 c8                 	iny
  2144  0ed1 80e9               	bra .local2
  2145                          .local3
  2146  0ed3 a52f               	lda scratch1
  2147  0ed5 8f11fc1b           	sta IO_CON_COLOR
  2148  0ed9 28                 	plp
  2149  0eda 6b                 	rtl
  2150                          .local4
  2151  0edb c8                 	iny
  2152  0edc b73d               	lda [dpla],y
  2153  0ede 8f11fc1b           	sta IO_CON_COLOR
  2154  0ee2 c8                 	iny
  2155  0ee3 80d7               	bra .local2
  2156                          .local5
  2157  0ee5 a52f               	lda scratch1
  2158  0ee7 8f11fc1b           	sta IO_CON_COLOR
  2159  0eeb c8                 	iny
  2160  0eec 80ce               	bra .local2
  2161                          	
  2162                          	!zone prcoldpla
  2163                          prcoldpla				;print colored C string (color byte/character byte pairs) pointed to by dpla
  2164  0eee 08                 	php
  2165  0eef c210               	rep #$10
  2166  0ef1 e220               	sep #$20
  2167                          	!as
  2168                          	!rl
  2169  0ef3 af11fc1b           	lda IO_CON_COLOR
  2170  0ef7 852f               	sta scratch1
  2171  0ef9 a00000             	ldy #$0000
  2172                          .local2
  2173  0efc b73d               	lda [dpla],y
  2174  0efe f012               	beq .local3
  2175  0f00 8f11fc1b           	sta IO_CON_COLOR
  2176  0f04 c8                 	iny
  2177  0f05 b73d               	lda [dpla],y
  2178  0f07 8f12fc1b           	sta IO_CON_CHAROUT
  2179  0f0b 8f13fc1b           	sta IO_CON_REGISTER
  2180  0f0f c8                 	iny
  2181  0f10 80ea               	bra .local2
  2182                          .local3
  2183  0f12 a52f               	lda scratch1
  2184  0f14 8f11fc1b           	sta IO_CON_COLOR
  2185  0f18 28                 	plp
  2186  0f19 6b                 	rtl
  2187                          
  2188                          initbanner
  2189  0f1a 0b49014d094c0120   	!byte 0x0b, 'I', 0x01, 'M', 0x09, 'L', 0x01, ' '
  2190  0f22 0336033503380331...	!byte 0x03, '6', 0x03, '5', 0x03, '8', 0x03, '1', 0x03, '6', 0x03, ' '
  2191  0f2e 0c310c430c20       	!byte 0x0c, '1', 0x0c, 'C', 0x0c, ' '
  2192  0f34 064606690672066d...	!byte 0x06, 'F', 0x06, 'i', 0x06, 'r', 0x06, 'm', 0x06, 'w', 0x06, 'a', 0x06, 'r', 0x06, 'e', 0x06, ' '
  2193  0f46 0d760d300d30       	!byte 0x0d, 'v', 0x0d, '0', 0x0d, '0'
  2194  0f4c 010d               	!byte 0x01, 0x0d
  2195  0f4e 00                 	!byte 0x00
  2196                          
  2197                          initstring
  2198  0f4f 0101               	!byte 0x01, 0x01
  2199  0f51 53797374656d204d...	!tx "System Monitor"
  2200  0f5f 0d                 	!byte 0x0d
  2201  0f60 0d                 	!byte 0x0d
  2202  0f61 00                 	!byte 0
  2203                          
  2204                          helpmsg
  2205  0f62 010e               	!byte 0x01, 0x0e
  2206  0f64 494d4c2036353831...	!tx "IML 65816 Monitor Commands"
  2207  0f7e 02                 	!byte 0x02
  2208  0f7f 0d                 	!byte $0d
  2209  0f80 41203c616464723e...	!tx "A <addr>  Dump ASCII"
  2210  0f94 0d                 	!byte $0d
  2211  0f95 42203c62616e6b3e...	!tx "B <bank>  Change bank"
  2212  0faa 0d                 	!byte $0d
  2213  0fab 43203c636f6c6f72...	!tx "C <color> Change terminal colors"
  2214  0fcb 0d                 	!byte $0d
  2215  0fcc 44203c616464723e...	!tx "D <addr>  Dump hex"
  2216  0fde 0d                 	!byte $0d
  2217  0fdf 45203c616464723e...	!tx "E <addr> <byte> <byte>...  Enter bytes"
  2218  1005 0d                 	!byte $0d
  2219  1006 463f202020202020...	!tx "F?        Floating Point Support Help"
  2220  102b 0d                 	!byte $0d
  2221  102c 4c203c616464723e...	!tx "L <addr>  Disassemble 65816 Inst."
  2222  104d 0d                 	!byte $0d
  2223  104e 4d203c6d6f64653e...	!tx "M <mode>  Change video mode, 8/9"
  2224  106e 0d                 	!byte $0d
  2225  106f 5120202020202020...	!tx "Q         Halt the processor"
  2226  108b 0d                 	!byte $0d
  2227  108c 3f20202020202020...	!tx "?         This menu"
  2228  109f 0d                 	!byte $0d
  2229  10a0 3c656e7465723e20...	!tx "<enter>   Repeat last dump command"
  2230  10c2 0d                 	!byte $0d
  2231  10c3 546f207370656369...	!tx "To specify range, use <addr1.addr2>"
  2232  10e6 0d00               	!byte $0d, 00
  2233                          
  2234                          fphelpmsg
  2235  10e8 010e               	!byte 0x01, 0x0e
  2236  10ea 494d4c20466c6f61...	!tx "IML Floating Point Support"
  2237  1104 02                 	!byte 0x02
  2238  1105 0d                 	!byte $0d
  2239  1106 466f726d61743a20...	!tx "Format: F<cmd><sz><reg>"
  2240  111d 0d                 	!byte $0d
  2241  111e 53697a65733a2046...	!tx "Sizes: F=float D=double E=extended"
  2242  1140 0d                 	!byte $0d
  2243  1141 5265676973746572...	!tx "Registers: A=FACC B=FARG"
  2244  1159 0d                 	!byte $0d
  2245  115a 46443c737a3e2020...	!tx "FD<sz>    Display FACC/FARG"
  2246  1175 0d                 	!byte $0d
  2247  1176 46433c737a3e3c72...	!tx "FC<sz><reg> <constID> Load Constant"
  2248  1199 0d                 	!byte $0d
  2249  119a 46493c737a3e3c72...	!tx "FI<sz><reg> Load Integer from FPINT"
  2250  11bd 0d                 	!byte $0d
  2251  11be 46563c737a3e3c72...	!tx "FV<sz><reg> Save int(reg) to FPINT"
  2252  11e0 0d                 	!byte $0d
  2253  11e1 463c6f703e3c737a...	!tx "F<op><sz><reg> Bin Op, result in <reg>"
  2254  1207 0d                 	!byte $0d
  2255  1208 42696e617279204f...	!tx "Binary Ops: *, /, +, -"
  2256  121e 0d                 	!tx $0d
  2257  121f 464e3c737a3e3c72...	!tx "FN<sz><reg> Natural Log of <reg>"
  2258  123f 0d                 	!tx $0d
  2259  1240 00                 	!byte $00
  2260                          	
  2261  1241 0000000000000000...!align $ffff, $ffff,$00	;fill up to top of memory
  2262                          

; ******** done
