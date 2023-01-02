; CLIBRARY.ASM 3.0 (4/3/84) - (c) 1982, 1983, 1984 Walter Bilofsky
; Multiply and divide routines (c)1981 UltiMeth Corp. Permission is gran-
; ted to reproduce them without charge, provided this notice is included.
	ORG	21200Q
C_lib:	DS	0
CP_M	EQU	0
$AS	EQU	21200Q-200
$AT	EQU	$AS-2
$AG	EQU	$AS-4
$INIT:	LXI	H,exic
	MVI	A,3
	DB	255,33
	LXI	H,1
	SHLD	$AG
	DCX	H
	SHLD	20033Q
	DAD	SP
	SHLD	$AT
	LHLD	20320Q
	LXI	H,-1
	DB	255,42
	XCHG
	LHLD	20324Q
	LXI	B,10
	DAD	B
	CALL	s.1
	PUSH	H
	DB	255,42
	POP	H
	DCR	H
	SHLD	IObuf+6
	DCR	H
	SHLD	IObuf+4
	DCR	H
	SHLD	IObuf+2
	DCX	H
	SPHL
	LXI	H,21200Q-120
	SHLD	$AS
	LXI	D,$AS+2
	PUSH	D
	MVI	A,-1
	DB	255,44
	LHLD	$AT
$A2:	DS	0
	LXI	D,21200Q
	MOV	A,E
	CMP	L
	JNZ	$A7
	MOV	A,D
	CMP	H
	JZ	$A6
$A7:	MOV	A,M
	INX	H
	ORA	A
	JZ	$A6
	CPI	' '
	JZ	$A7
	MOV	C,A
	CPI	'"'
	JZ	$A3
	CPI	047Q
	JZ	$A3
	MVI	C,' '
	DCX	H
$A3:	POP	D
	MOV	A,L
	STAX	D
	INX	D
	MOV	A,H
	STAX	D
	INX	D
	PUSH	D
	PUSH	H
	DCX	H
$A9:	INX	H
	MOV	A,M
	ORA	A
	JZ	$A5
	CMP	C
	JNZ	$A9
	MVI	M,0
	INX	H
$A5:	XTHL
	MOV	A,M
	INX	H
	CPI	'<'
	JZ	$B1
	CPI	'>'
	JZ	$B2
	LXI	H,$AG
	INR	M
	POP	H
	JMP	$A2
$A6:	POP	H
	MVI	M,-1
	INX	H
	MVI	M,-1
	LHLD	$AG
	PUSH	H
	LXI	H,$AS
	PUSH	H
	CALL	main
exit:	LHLD	fout
	MOV	A,H
	ORA	L
	JZ	$B4
	PUSH	H
	CALL	fclose
$B4:	MVI	A,0
	DB	255,0
exic:	DB	255,7
	JMP	exit
$B1:	PUSH	H
	LXI	H,$BR
	PUSH	H
	CALL	fopen
	SHLD	fin
	JMP	$B3
$BR:	DB	'r',0
fin:	DW	0
$B2:	PUSH	H
	LXI	H,$BW
	PUSH	H
	CALL	fopen
	SHLD	fout
$B3:	POP	B
	POP	B
	JC	$B0
	POP	H
	POP	D
	DCX	D
	DCX	D
	PUSH	D
	JMP	$A2
$B0:	DB	255,47,255,7,255,0
$BW:	DB	'w',0
fout:	DW	0
	RET
sbrk:	DS	0
	POP	D
	POP	B
	PUSH	B
	PUSH	D
	LHLD	$LM
	PUSH	H
	PUSH	H
	POP	D
	DAD	B
	PUSH	H
	PUSH	H
	CALL	c.ugt
	POP	D
	JNZ	al.1
	LXI	H,-500
	DAD	SP
	CALL	c.uge
al.1:	POP	D
	POP	B
	LXI	H,-1
	RNZ
	XCHG
	SHLD	$LM
	PUSH	B
	POP	H
	RET
$LM:	DW	$END
	RET
getchar:	DS	0
	LHLD	fin
	PUSH	H
	CALL	getc
	POP	B
	RET
$B8:	DB	255,1
	JC	$B8
	CPI	4
	JZ	$B9
	MOV	L,A
	MVI	H,0
	RET
$B9:	DB	255,7
$RM:	LXI	H,-1
	RET
putchar:	DS	0
	POP	B
	POP	D
	PUSH	D
	PUSH	B
	LHLD	fout
	PUSH	D
	PUSH	H
	CALL	putc
	POP	B
	POP	B
	RET
$B7:	PUSH	D
	MOV	A,E
	DB	255,2
	POP	H
	RET
	RET
IObuf:	DW	0,0,0,0,0,0,0
IOsect:	DW	0,0,0,0,0,0,0
IOrw:	DB	0,0,0,0,0,0,0
IOtmp:	DW	0
IOch:	DB	-1,-1,-1,-1,-1,-1,-1
IOind:	DW	0,0,0,0,0,0,0
IOmode:	DB	0,0,0,0,0,0,0
IObin:	DB	0,0,0,0,0,0,0
IOseek:	DB	0,0,0,0,0,0,0
fopen:	DS	0
	MVI	B,6
	LXI	H,IOch+1
O1$:	MOV	A,M
	CPI	-1
	JZ	O2$
	INX	H
	DCR	B
	JNZ	O1$
	JMP	RN$
O2$:	POP	B
	POP	D
	PUSH	D
	PUSH	B
	XCHG
	MOV	A,M
	INX	H
	MOV	B,M
	XCHG
	LXI	D,IOrw-IOch
	DAD	D
	MVI	M,0
	LXI	D,IOseek-IOrw
	DAD	D
	MVI	M,0
	LXI	D,IObin-IOseek
	DAD	D
	MOV	M,B
	LXI	D,IOmode-IObin
	DAD	D
	MOV	M,A
	MVI	C,34+2
	CPI	'u'
	JZ	O4$
	DCR	C
	CPI	'w'
	JZ	O4$
	DCR	C
O4$:	MOV	A,C
	STA	O6$+1
	LXI	D,IOmode
	XCHG
	CALL	s.1
	PUSH	H
	LXI	H,6
	DAD	SP
	CALL	h.
	POP	B
	PUSH	B
	MOV	A,C
	DCR	A
	LXI	D,O7$
O6$:	DB	255,0
	POP	D
	JC	RN$
	LXI	H,IOch
	DAD	D
	MOV	M,E
	LXI	B,IOind-IOch
	DAD	B
	DAD	D
	XRA	A
	MOV	M,A
	INX	H
	MVI	M,1
	LXI	B,IOsect-IOind
	DAD	B
	MOV	M,A
	DCX	H
	MOV	M,A
	LXI	B,IObuf-IOsect
	DAD	B
	MOV	A,M
	INX	H
	ORA	M
	JNZ	O8$
	PUSH	D
	PUSH	H
	LXI	B,256
	PUSH	B
	CALL	sbrk
	POP	B
	XCHG
	POP	H
	MOV	M,D
	DCX	H
	MOV	M,E
	INX	D
	MOV	A,E
	ORA	D
	POP	D
	JZ	RN$
O8$:	XCHG
	XRA	A
	RET
O7$:	DB	'SY0'
	DB	0,0,0
fclose:	DS	0
	POP	B
	POP	D
	PUSH	D
	PUSH	B
F$1:	LXI	H,IOch
	DAD	D
	MOV	A,M
	INR	A
	JZ	RN$
	MVI	M,-1
	CALL	TM$
	LXI	H,IOmode
	DAD	D
	MOV	A,M
	CPI	'r'
	JZ	F2$
	LXI	H,IObin
	DAD	D
	MOV	C,M
	LXI	H,IOind
	DAD	D
	DAD	D
	PUSH	D
	CALL	h.
	MOV	A,L
	ORA	A
	JZ	F3$
	XCHG
	LHLD	IOtmp
	MOV	A,C
	CPI	'b'
	JZ	F5$
	DAD	D
	XRA	A
F4$:	MOV	M,A
	INX	H
	INR	E
	JNZ	F4$
	DCR	H
F5$:	PUSH	H
	LXI	H,256
F5A$:	PUSH	H
__CL2	EQU	$+1
	CALL	write
	POP	B
	POP	B
F3$:	POP	D
F2$:	MOV	A,E
	DCR	A
	PUSH	D
	DB	255,38
	POP	H
	RNC
RN$:	LXI	H,0
	STC
	RET
TM$:	LXI	H,IObuf
	DAD	D
	DAD	D
	MOV	C,M
	INX	H
	MOV	B,M
	PUSH	B
	POP	H
	SHLD	IOtmp
	RET
getc:	DS	0
.G3:	CALL	.GPC
	ORA	A
	JZ	$B8
	XRA	A
	CMP	C
	DCX	H
	JNZ	.G1
	PUSH	H
	PUSH	D
	LHLD	IOtmp
	PUSH	H
	LXI	H,256
	PUSH	H
	CALL	read
	POP	B
	POP	B
	POP	D
	MOV	A,L
	ORA	H
	POP	H
	JZ	$RM
.G1:	PUSH	D
	PUSH	H
	CALL	h.
	INX	H
	CALL	q.
	DCX	H
	XCHG
	LHLD	IOtmp
	DAD	D
	MOV	B,M
	LXI	H,IObin
	POP	D
	DAD	D
	MVI	A,'b'
	CMP	M
	JZ	.G2
	MOV	A,B
	ORA	A
	JZ	.G3
.G2:	MOV	L,B
	MVI	H,0
	RET
.GPC:	POP	H
	POP	B
	POP	D
	PUSH	D
	PUSH	B
	PUSH	H
	MOV	A,E
	ORA	A
	RZ
	CALL	TM$
	XRA	A
	LXI	H,IOind
	DAD	D
	DAD	D
	MOV	C,M
	INX	H
	MOV	B,M
	CMP	C
	MOV	A,E
	RNZ
	MVI	B,0
	MOV	M,B
	RET
putc:	DS	0
	CALL	.GPC
	ORA	A
	JNZ	PC.8
	POP	B
	POP	H
	POP	D
	PUSH	D
	PUSH	H
	PUSH	B
	JMP	$B7
PC.8:	DS	0
PC.9:	DCX	H
	PUSH	H
	LXI	H,6
	DAD	SP
	MOV	A,M
PC.1:	LHLD	IOtmp
	DAD	B
	MOV	M,A
	XTHL
	PUSH	H
	PUSH	H
	MOV	H,B
	MOV	L,C
	INX	H
	CALL	q.
	POP	H
	XRA	A
	CMP	M
	POP	H
	JNZ	.PC1
	POP	B
	POP	D
	PUSH	D
	PUSH	B
	PUSH	D
	DCR	H
	INR	L
	PUSH	H
	LXI	H,256
	PUSH	H
__PC2	EQU	$+1
	CALL	write
	POP	B
	POP	B
	POP	B
	MOV	A,H
	ORA	L
	LXI	H,-1
	RZ
	RM
.PC1:	LXI	H,4
	DAD	SP
	MOV	L,M
	MVI	H,0
	RET
write:	DS	0
	XRA	A
	STA	RD.RW
	CALL	$RW.
	PUSH	B
	DB	255,5
	POP	H
	JC	$RW.3
$RW.2:	PUSH	H
	LXI	H,8
	DAD	SP
	CALL	h.
	XCHG
	POP	H
	PUSH	H
	LDA	RD.RW
	ANA	H
	PUSH	PSW
	MOV	A,H
	LXI	H,IOsect
	DAD	D
	DAD	D
	ADD	M
	MOV	M,A
	JNC	.PC5
	INX	H
	INR	M
.PC5:	LXI	H,IOrw
	DAD	D
	POP	PSW
	MOV	M,A
	POP	H
	RET
read:	DS	0
	MVI	A,-1
	STA	RD.RW
	CALL	$RW.
	PUSH	B
	DB	255,4
	POP	H
	JNC	$RW.2
	DCR	A
	JNZ	$RW.1
	MOV	A,H
	SUB	B
	MOV	H,A
	RET
$RW.1:	INR	A
$RW.3:	DB	255,47
	JMP	$RM
RD.RW:	DS	1
$RW.:	LXI	H,8
	DAD	SP
	MOV	A,M
	DCR	A
	DCX	H
	MOV	D,M
	DCX	H
	MOV	E,M
	DCX	H
	MOV	B,M
	DCX	H
	MOV	C,M
	RET
	RET
o.:	POP	B
	POP	D
	PUSH	B
	MOV	A,L
	ORA	E
	MOV	L,A
	MOV	A,H
	ORA	D
	MOV	H,A
	RET
x.:	POP	B
	POP	D
	PUSH	B
	MOV	A,L
	XRA	E
	MOV	L,A
	MOV	A,H
	XRA	D
	MOV	H,A
	RET
a.:	POP	B
	POP	D
	PUSH	B
	MOV	A,L
	ANA	E
	MOV	L,A
	MOV	A,H
	ANA	D
	MOV	H,A
	RET
e.0:	MOV	A,H
	ORA	L
	RZ
e.t:	LXI	H,0
e.2:	INR	L
	RET
e.:	POP	B
	POP	D
	PUSH	B
e.1:	MOV	A,H
	CMP	D
	MOV	A,L
	LXI	H,0
	JNZ	e.f
	CMP	E
	JNZ	e.f
	INR	L
	RET
e.f:	XRA	A
	RET
c.not:	MOV	A,H
	ORA	L
	JZ	e.2
	LXI	H,0
	XRA	A
	RET
n.:	POP	B
	POP	D
	PUSH	B
n.1:	MOV	A,H
	CMP	D
	MOV	A,L
	LXI	H,1
	RNZ
	CMP	E
	RNZ
	DCR	L
	RET
c.ge:	XCHG
c.le:	MOV	A,D
	CMP	H
	JNZ	c.lt1
	MOV	A,E
	CMP	L
	JNZ	c.lt3
true:	LXI	H,0
	INR	L
	RET
c.gt:	XCHG
c.lt:	MOV	A,D
c.lt1:	XRA	H
	JM	negHL
	MOV	A,D
	CMP	H
	JNZ	c.lt3
	MOV	A,E
	CMP	L
c.lt3:	LXI	H,1
	RC
c.lt4:	DCR	L
	RET
negHL:	MOV	A,H
	ANA	A
	LXI	H,1
	JM	c.lt4
	ORA	L
	RET
c.tst:	MOV	A,H
	XRI	128
	MOV	H,A
	DAD	D
	RET
c.uge:	XCHG
c.ule:	MOV A,H
	CMP D
	JNZ c.ule1
	MOV A,L
	CMP E
c.ule1: LXI H,1
	JNC c.true
c.fals: DCR L
	RET
c.true: ORA L
	RET
c.ugt:	XCHG
c.ult:	MOV A,D
	CMP H
	JNZ c.rt
	MOV A,E
	CMP L
c.rt:	LXI H,1
	RC
	DCR L
	RET
c.asr:	XCHG
	MOV	A,H
	RAL
c.shf:	DCR	E
	RM
	MOV	A,H
	RAR
	MOV	H,A
	MOV	A,L
	RAR
	MOV	L,A
	JMP	c.asr+1
c.usr:	XCHG
	XRA	A
	JMP	c.shf
c.asl:	XCHG
	DCR	E
	RM
	DAD	H
	JMP	c.asl+1
s.:	POP	B
	POP	D
	PUSH	B
s.1:	MOV	A,E
	SUB	L
	MOV	L,A
	MOV	A,D
	SBB	H
	MOV	H,A
	RET
c.neg:	DCX	H
c.com:	MOV	A,H
	CMA
	MOV	H,A
	MOV	A,L
	CMA
	MOV	L,A
	RET
g.:	MOV	A,M
c.sxt:	MOV	L,A
	RLC
	SBB	A
	MOV	H,A
	RET
h@:	DS	0
h.:	MOV	A,M
	INX	H
	MOV	H,M
	MOV	L,A
	RET
q.:	XCHG
	POP	H
	XTHL
	MOV	M,E
	INX	H
	MOV	M,D
	XCHG
	RET
.switch:
	XCHG
	POP	H
S.9:	MOV	C,M
	INX	H
	MOV	B,M
	INX	H
	MOV	A,B
	ORA	C
	JZ	S.8
	MOV	A,M
	INX	H
	CMP	E
	MOV	A,M
	INX	H
	JNZ	S.9
	CMP	D
	JNZ	S.9
	MOV	H,B
	MOV	L,C
S.8:	PCHL
c.mult: MOV	B,H
	MOV	C,L
	LXI	H,0
	MOV	A,D
	ORA	A
	MVI	A,16
	JNZ	.MLP
	MOV	D,E
	MOV	E,H
	RRC
.MLP:	DAD	H
	XCHG
	DAD	H
	XCHG
	JNC	.MSK
	DAD	B
.MSK:	DCR	A
	JNZ	.MLP
	RET
c.udv:	XRA	A
	PUSH	PSW
	JMP	c.d1
c.div:	MOV	A,D
	XRA	H
	PUSH	PSW
	XRA	H
	XCHG
	CM	c.neg
	XCHG
	MOV	A,H
	ORA	A
c.d1:	CP	c.neg
	MOV	C,L
	MOV	B,H
	LXI	H,0
	MOV	A,B
	INR	A
	JNZ	.DV3
	MOV	A,D
	ADD	C
	MVI	A,16
	JC	.DV1
.DV3:	MOV	L,D
	MOV	D,E
	MOV	E,H
	MVI	A,8
.DV1:	DAD	H
	XCHG
	DAD	H
	XCHG
	JNC	.DV4
	INX	H
.DV4:	PUSH	H
	DAD	B
	POP	H
	JNC	.DV5
	DAD	B
	INX	D
.DV5:	DCR	A
	JNZ	.DV1
	XCHG
	POP	PSW
	RP
	XCHG
	CALL	c.neg
	XCHG
	JMP	c.neg
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              