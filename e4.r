
; ******** Source: e4.a
     1                          	!to "e4.o",plain
     2                          	!cpu 65816
     3                          
     4                          	*= $e400
     5                          
     6                          	!align $ffff,$e400	;leave room for softswitches
     7                          
     8                          IO_CON_CLS = $1bfc10
     9                          IO_CON_COLOR = $1bfc11
    10                          IO_CON_CHAROUT = $1bfc12
    11                          IO_CON_REGISTER = $1bfc13
    12                          IO_CON_CURSORH = $1bfc14;
    13                          IO_CON_CURSORV = $1bfc15;
    14                          IO_CON_CURSOR = $1bfc16;
    15                          IO_VIDMODE = $1bfc20
    16                          
    17                          x1crominit = $1c0000
    18                          
    19                          romstart
    20  e400 18                 	clc
    21  e401 fb                 	xce
    22  e402 c230               	rep #$30
    23                          	!rl
    24                          	!al
    25  e404 a90000             	lda #$0000
    26  e407 48                 	pha
    27  e408 ab                 	plb
    28  e409 ab                 	plb
    29  e40a 5b                 	tcd
    30  e40b a2ffdf             	ldx #$dfff
    31  e40e 9a                 	txs
    32  e40f e220               	sep #$20
    33                          	!as
    34  e411 a908               	lda #$08
    35  e413 8f20fc1b           	sta IO_VIDMODE
    36  e417 a900               	lda #$00
    37  e419 8f14fc1b           	sta IO_CON_CURSORH
    38  e41d 8f15fc1b           	sta IO_CON_CURSORV
    39  e421 0980               	ora #$80
    40  e423 8f16fc1b           	sta IO_CON_CURSOR
    41  e427 a90b               	lda #$0b
    42  e429 8f11fc1b           	sta IO_CON_COLOR
    43  e42d a920               	lda #$20
    44  e42f 8f12fc1b           	sta IO_CON_CHAROUT
    45  e433 8f10fc1b           	sta IO_CON_CLS
    46  e437 a20000             	ldx #$0000
    47                          prloop
    48  e43a bd4ee4             	lda initstring, X
    49  e43d f00b               	beq done
    50  e43f 8f12fc1b           	sta IO_CON_CHAROUT
    51  e443 8f13fc1b           	sta IO_CON_REGISTER
    52  e447 e8                 	inx
    53  e448 80f0               	bra prloop
    54                          done
    55  e44a 5c00001c           	jml x1crominit
    56                          
    57                          initstring
    58  e44e 494d4c2036353831...	!tx "IML 65816 E4 Firmware v00"
    59  e467 0d                 	!byte 0x0d
    60  e468 28432920476f6f64...	!tx "(C) Good Neighbors LLC, 2019, 2024"
    61  e48a 0d                 	!byte 0x0d
    62  e48b 446576656c6f7065...	!tx "Developed by Stephen Sviatko"
    63  e4a7 0d                 	!byte 0x0d
    64  e4a8 00                 	!byte 0
    65                          
    66  e4a9 0000000000000000...	!align $ffff,$fffc,$00
    67                          
    68  fffc 00e4               reset	!word romstart
    69  fffe 00e4               irq	!word romstart
    70                           
