vers equ '1 ' ; July 22, 1983  14:36  mjm  "Z17'3.ASM"
********** CP/M 3 DISK I/O ROUTINES FOR Z17  **********
******* Copyright (c) 1983 Magnolia Microsystems ******
	maclib Z80

false	equ	0
true	equ	not false

	extrn	@dph,@rdrv,@side,@trk,@sect,@dma,@dbnk,@dstat,@intby
	extrn	@dtacb,@dircb,@scrbf,@rcnfg,@cmode,@tick0
	extrn	?bnksl,?timot

***** PHYSICAL DRIVES ARE ASSIGNED AS FOLLOWS *****
*****					      *****
*****  0 = FIRST (BUILT-IN) MINI FLOPPY       *****
*****  1 = SECOND (ADD-ON) MINI FLOPPY	      *****
*****  2 = THIRD (LAST ADD-ON) MINI FLOPPY    *****
*****					      *****
***************************************************
driv0	equ	0
ndriv	equ	3

***************************************************
**  MINI-FLOPPY PORTS AND CONSTANTS
***************************************************
DISK$CTL	EQU	7FH
RCVR		EQU	7EH
STAT		EQU	7DH
DATA		EQU	7CH
PORT		EQU	0F2H

MOTOR$ON	EQU	10010000B	;AND ENABLE FLOPY-RAM
SETTLE		EQU	10	;10*2 = 20mS  STEP-SETTLING TIME
SEL		EQU	25	; WAIT 50mS AFTER SELECTING
MTRDLY		EQU	2	; 1.024 SECONDS

PASS		equ	003eh
***************************************************

***************************************************
** START OF RELOCATABLE DISK I/O MODULE
*************************************************** 
	cseg
	dw	thread
	db	driv0,ndriv
	jmp	init$z17
	JMP	login$Z17
	JMP	READ$Z17
	JMP	WRITE$Z17
	dw	string,dphtbl,modtbl

string: DB	'Z17 ',0,'Hard Sector controller ',0,'v3.10'
	dw	vers
	db	'$'

modtbl: db	00000000b,00000010b,01001101b,00000000b ;modes
	     db 11111111b,11111111b,10010000b,00000000b ;masks
	db	00000000b,00000010b,01001101b,00000000b ;
	     db 11111111b,11111111b,10010000b,00000000b ;
	db	00000000b,00000010b,01001101b,00000000b ;
	     db 11111111b,11111111b,10010000b,00000000b ;

comrd:
	lhld	@dma
	lda	@dbnk
	call	?bnksl
	MVI	C,3
XSYNC	CALL	SYNC0
	DCR	C
	JNZ	XSYNC
	MVI	B,0	;256 BYTES
	CALL	SYNC
	JC	errx1
RD	CALL	INPUT$DISK
	MOV	M,A
	INX	H
	DJNZ	RD
	MOV	L,D
	CALL	INPUT$DISK
	xra	a
	jmp	?bnksl

errx1:	xra	a
	call	?bnksl
	stc
	jmp	errx

comwr:
	lhld	@dma
	lda	@dbnk
	call	?bnksl
	LDA	CTL$BYTE
	ORI	00000001B	;WRITE ENABLE
	OUT	DISK$CTL
	MVI	B,0	;256 BYTES
	MVI	C,10	; WRITE 10 NULLS TO PAD DATA
NLOOP	XRA	A
	CALL	OUTPUT$DISK
	DCR	C
	JNZ	NLOOP
	MVI	A,0FDH	;SYNC CHARACTER
	MOV	D,A	;FORCE CLEARING OF CRC
	CALL	OUTPUT$DISK
WRT	MOV	A,M
	CALL	OUTPUT$DISK
	INX	H
	DJNZ	WRT
	MOV	A,D	;GET CRC
	CALL	OUTPUT$DISK	;WRITE CRC ON DISK
	CALL	OUTPUT$DISK	; NOW 3 NULLS...
	CALL	OUTPUT$DISK
	CALL	OUTPUT$DISK
	LDA	CTL$BYTE
	out	disk$ctl	;RESTORE CTRL LINES
	xra	a
	call	?bnksl
	XRA	A
	EI			;ENABLE INTERUPTS ++++++++++++++++++++++++++
	RET

INPUT$DISK:
	IN	STAT
	RAR
	JNC	INPUT$DISK
	IN	DATA
	MOV	E,A
	XRA	D
	RLC
	MOV	D,A
	MOV	A,E
	RET

OUTPUT$DISK:
	MOV	E,A
	IN	STAT
	RAL
	JNC	OUTPUT$DISK+1
	MOV	A,E
	OUT	DATA
	XRA	D
	RLC
	MOV	D,A
	RET

SYNC0	XRA	A
	JR	SYNCX
SYNC:	MVI	A,0FDH
SYNCX:	MVI	D,80	;TRY 80 TIMES
	OUT	RCVR
	IN	RCVR	;RESET RECEIVER
SLOOP	IN	DISK$CTL
	ANI	00001000B
	JRNZ	FOUND
	DCR	D
	JRNZ	SLOOP
	STC
	RET
FOUND	IN	DATA
	MVI	D,0	;CLEAR CRC
	RET

SEL$OFF:
	LDA	CTL$BYTE
	ANI	11110001B
	OUT	DISK$CTL
	xra	a
	sta	selflg
	pop	h
	xthl
	push	h
	mvi	m,10
	inx	h
	lxi	b,motor$off
	mov	m,c
	inx	h
	mov	m,b
	pop	h
	xthl
	pchl

MOTOR$OFF:
	LDA	CTL$BYTE
	ANI	11100001B
	OUT	DISK$CTL
	xra	a
	sta	motflg
	RET

ctl$byte: db	0
selflg:   db	0
motflg:   db	0

thread	equ	$	;last line in "cseg"

	dseg

dphtbl: DW	0,0,0,0,0,0,0,CSV0,ALV0,@dircb,@dtacb,0 ;hash buffers are
	db	0					;allocated by main
	DW	0,0,0,0,0,0,0,CSV1,ALV1,@dircb,@dtacb,0 ;BIOS during login.
	db	0					;
	DW	0,0,0,0,0,0,0,CSV2,ALV2,@dircb,@dtacb,0
	db	0

csv0:	ds	(64)/4		;Max DIR entries: 64
csv1:	ds	(64)/4
csv2:	ds	(64)/4

alv0:	ds	(188)/4 	;Max blocks: 188
alv1:	ds	(188)/4 	; (double bit)
alv2:	ds	(188)/4

STPTBL: DB	3	;00 =  6 mS (fastest rate)
	DB	6	;01 = 12 mS
	DB	10	;10 = 20 mS
	DB	15	;11 = 30 mS (slowest rate)

init$z17:
	LXI	H,ctl$byte	;DEFINE ENTRY TO THIS INTERNAL ROUTINE
	SHLD	PASS	; PUT ADDRESS WHERE FORMAT PROGRAM CAN FIND IT
	ret

login$Z17:
	call	setup
	xra	a
	sta	selrr
	MOV	A,M
	ANI	1100B	;STEPRATE
	rrc
	rrc
	LXI	h,STPTBL
	ADD	l
	MOV	l,A
	mvi	a,0
	adc	h
	mov	h,a
	mov	a,m
	STA	ASTEPR	;COUNTER VALUE EQUIVELENT TO STEPRATE CODE
	CALL	LOGIN	;CONDITIONAL LOG-IN OF DRIVE (TEST FOR HALF-TRACK)
	xra	a
	jmp	rwerr

LOGIN:	
;
;   TEST DISKETTE/DRIVE FOR "48 IN 96 TPI"
;
	CALL	SELECT
	RC		;NOT READY
	CALL	RECALIBRATE	;[CY]=ERROR
	RC	;IF ERROR HERE, IGNORE IT.
	MVI	C,00100000B	;STEP-IN
	CALL	STEPHEAD	;STEP IN ONCE...
	CALL	STEPHEAD	;STEP IN TWICE.
	LXIX	TEC
	CALL	READ$ADDRESS	;FIND OUT WHERE WE ARE.
	PUSH	PSW
	CALL	RECALIBRATE	;PUT HEAD WHERE SYSTEM CAN FIND IT.
	POP	PSW
	JRC	SELERR	;ERROR HERE MAY INDICATE 96 IN 48 TPI
	MOV	A,D	;TRACK NUMBER
	CPI	2
	RZ	;MEDIA MATCHES DRIVE, NO CHANGES TO MAKE
	CPI	1	;IF 48 TPI DISK IN 96 TPI DRIVE
	JRNZ	SELERR
	LHLD	MODES
	SETB	5,M	;SETUP FOR "HALF-TRACK"
	inx	h
	res	5,m
	mvi	a,0ffh
	sta	@rcnfg
	RET

SELERR: mvi	a,1
	STA	SELRR
	RET

setuprw:
	lda	selrr
	ora	a
setup:
	sixd	saveix
	siyd	saveiy
	lhld	@cmode
	inx	h
	inx	h
	shld	modes
	ret

READ$Z17:
	call	setuprw
	rnz
RD$SEC: CALL	READ		; READ A PHYSICAL SECTOR
rwerr:	push	psw
	lda	motflg
	ora	a
	jrz	rwe
	mvi	c,4
	lxi	d,sel$off
	mvi	b,driv0
	call	?timot
rwe:	pop	psw
	lixd	saveix
	liyd	saveiy
	ret

WRITE$Z17:
	call	setuprw
	rnz
WR$SEC: CALL	WRITE		; WRITE A PHYSICAL SECTOR
	JR	RWERR

***** PHYSICAL READ-SECTOR ROUTINE ******
** RETURNS [NZ] IF ERROR	       **
** USES ALL REGISTERS (IX,IY)	       **
*****************************************
READ:
	CALL	SELECT
	JC	ERROR
	CALL	SEEK
	JC	ERROR
READ01:
	LXIY	SSC
	MVIY	10,+0
READ1:
	CALL	FIND$SECTOR	;DISABLES INTERUPTS ++++++++++++++++++++++
	JC	ERROR	;MUST ENABLE INTERUPTS
	call	comrd
	EI			;ENABLE INTERUPTS +++++++++++++++++++++++++
	mov	a,e
	SUB	L
	RZ	;SUCCESSFULL READ...
ERRX	EI			;ENABLE INTERUPTS +++++++++++++++++++++++++
	DCRY	+0
	JRNZ	READ1
	CALL	ERROR1	;SETS STATUS BIT
	JMP	ERROR

***** PHYSICAL WRITE-SECTOR ROUTINE ******
** RETURNS [NZ] IF ERROR		**
** USES ALL REGISTERS (IX,IY)		**
**					**
******************************************
WRITE:
	CALL	SELECT
	JC	ERROR
	rlc
	JC	ERROR
	CALL	SEEK
	JC	ERROR
	LHLD	MODES	;PREVENT ATTEMPTED WRITE TO 48 TPI DISK IN 96 TPI DRIVE
	bit	5,m
	jrz	wr0
	INX	H
	BIT	5,M
	jz	error	;RETURN ERROR IF ATTEMPTED WRITE TO "HALF TRACK" DISK
wr0:	XRA	A
	OUT	STAT	;SET FILL CHARACTER
	CALL	FIND$SECTOR	;DISABLES INTERUPTS ++++++++++++++++++++++++
	JC	ERROR
	MVI	A,32	;222uS (312 uS total from sector address header.
WLOOP	DCR	A		;
	JNZ	WLOOP		;
	jmp	comwr

***** FINDS SECTOR HEADER ****************
** RETURNS [CY] IF ERROR		**
** USES ALL REGISTERS (IX)		**
**					**
******************************************
FIND$SECTOR:
	LXIX	TEC
	MVIX	5,+0	;TRACK-ERROR RETRY COUNTER
FIND1	MVIX	36,+1	;SECTOR SEARCH RETRY COUNTER
FIND5	CALL	READ$ADDRESS	;DISABLES INTERUPTS +++++++++++++++++++++++
	RC		; >> ACCUMILATED NO-ERROR TIME....
	lda	@side	;
	cmp	e	;SIDE NUMBER
	JNZ	SKERR
	lda	@trk
	cmp	d	;TRACK NUMBER
	JZ	OVER2	; >>	CYCLES
SKERR:	EI
	DCRX	+0
	JZ	SEEK$ERROR
	CALL	RECALIBRATE
	JC	SEEK$ERROR
	CALL	SEEK
	JC	SEEK$ERROR
	JMP	FIND1
OVER2	LDA	@sect	;SECTOR NUMBER
	CMP	C
	RZ		; >>	CYCLES
	DCRX	+1
	JNZ	FIND5
	JMP	ERROR1

;******* READ ADDRESS from diskette ***************
; ENTRY: assumes IX points to "TEC"
; RETURN: (D)=track  (E)=side  (C)=sector
;	or [CY] if error.
;
READ$ADDRESS:		;ALWAYS EXITS WITH INTERUPTS DISABLED....
	MVIX	10,+2	;INIT CHECK-SUM ERROR COUNTER
FIND50:
	MVI	L,12	;MUST FIND SYNC IN 12 INDEX HOLES
FIND$INDEX:
	EI			;ENABLE INTERUPTS +++++++++++++++++++++++
	IN	DISK$CTL
	ANI	00000001B
	MOV	C,A
FLOOP	IN	DISK$CTL
	ANI	00000001B
	CMP	C
	JRZ	FLOOP
	MOV	C,A
	CPI	00000000B
	JRNZ	FLOOP
	PUSH	H
	MVI	A,6	;12 mS WAIT
	call	pause
	DI			;DISABLE INTERUPTS ++++++++++++++++++++++
	POP	H
FL1	IN	DISK$CTL
	RAR
	JRNC	FL1
	CALL	SYNC0
	CALL	SYNC
	JNC	OVER1
	DCR	L
	JNZ	FIND$INDEX
	JMP	ERROR1		;SETS [CY] AND STATUS BIT, RETURNS
OVER1	CALL	INPUT$DISK	;SIDE NUMBER
	MOV	L,A
	CALL	INPUT$DISK	;TRACK NUMBER
	MOV	H,A
	CALL	INPUT$DISK	;SECTOR NUMBER
	MOV	C,A
	CALL	INPUT$DISK	;TEST CHECK-SUM
	XCHG		;PUT TRACK/SIDE IN EXPECTED PLACE (DE)
	RZ		;CHECK-SUM CORRECT
	DCRX	+2
	JZ	ERROR1
	JR	FIND50

ERROR:
	XRA	A
	INR	A	;TO SIGNAL ERROR
	EI
	RET

ERROR1:
	LXI	H,@dstat
	SETB	3,M	;FORMAT ERROR
	STC
	RET

PAUSE5: push	psw		;256 TICS = 512mS
	xra	a
	call	pause
	pop	psw
	dcr	a
	jrnz	pause5
	ret

PAUSE:	LXI	H,@tick0
	ei
PAUS0:	push	psw
	mov	a,m
PLOOP	CMP	M
	jrz	PLOOP
	pop	psw
	dcr	a
	jrnz	paus0
	RET

RECALIBRATE:
	XRA	A
	STA	TRACK
RECAL	MVI	B,255
REC1	IN	DISK$CTL
	ANI	00000010B
	JRNZ	RECDON	;IF ALREADY AT TRK0
	LDA	CTL$BYTE
	ORI	01000000B	;STEP
	CALL	DISK$CTLR
	ANI	10111111B
	CALL	DISK$CTLR
	LDA	ASTEPR	;TIME FOR HEAD TO STEP
	CALL	PAUSE
	DJNZ	REC1
SEEK$ERROR:
	XRA	A
	CMA
	STA	TRACK
	LXI	H,@dstat
	SETB	4,M	;SEEK ERROR
	STC
	RET

RECDON	MVI	A,SETTLE
	JR	PAUSE

DISK$CTLR:
	OUT	DISK$CTL
	PUSH	PSW
	MOV	C,A
	ANI	00010000B	;MOTOR BIT
	JZ	MT$ON
	DI
	LDA	motflg
	ORA	A
	MVI	A,true
	STA	motflg
	JNZ	MT$ON
	MVI	A,MTRDLY
	CALL	PAUSE5
MT$ON	MOV	A,C
	ANI	00001110B	;SELECT BITS
	JZ	NOT$ON
	DI
	LDA	selflg
	ORA	A
	MVI	A,true
	STA	selflg
	JNZ	NOT$ON
	MVI	A,SEL
	CALL	PAUSE
NOT$ON	POP	PSW
	EI
	RET

SELECT:
	mvi	c,0
	mvi	b,driv0
	call	?timot
	LXI	H,DRIVE
	LDA	@rdrv
	CMP	M
	PUSH	PSW
	MOV	E,M
	MOV	M,A
	MVI	D,0
	LXI	H,TRKA
	DAD	D
	LDA	TRACK
	MOV	M,A
	LDED	DRIVE
	MVI	D,0
	LXI	H,TRKA
	DAD	D
	MOV	A,M
	STA	TRACK
	POP	PSW
	JRZ	NO$SEL
	XRA	A
	STA	selflg
NO$SEL	LDA	DRIVE
	INR	A
	MVI	B,3
	MVI	C,00000010B	;DRIVE A:
DRVL	DCR	A
	JZ	GDRIVE
	RLCR	C
	DJNZ	DRVL
	MVI	C,0	;DESELECT ALL DRIVES
GDRIVE	MVI	A,MOTOR$ON
	ORA	C
	STA	CTL$BYTE
	CALL	DISK$CTLR	;TURN MOTOR ON NOW
	LDA	TRACK
	CPI	0FFH	;MEANS DRIVE IS NOT LOGGED-ON
	JRNZ	LOGGED
	CALL	RECALIBRATE	;DETERMINE HEAD POSITION
	RC		;IF ERROR
	LXI	H,@intby
	RES	6,M
	MOV	A,M
	OUT	PORT
LOGGED:
	IN	DISK$CTL
	ANI	00000001B
	MOV	E,A
	LXI	B,0800H ;MUST FIND INDEX BEFORE COUNT GOES TO ZERO
IDX	IN	DISK$CTL
	ANI	00000001B
	CMP	E
	JRNZ	IDX$FOUND
	DCX	B
	MOV	A,B
	ORA	C
	JRNZ	IDX
	MVI	E,0
IDX$FOUND:
	ORA	E
	xri	1	;
	rrc		;
	MOV	E,A
	IN	DISK$CTL
	ANI	00000100B	;WRITE PROTECT
	rlc
	rlc
	rlc
	rlc
	ORA	E		;READY + write-protect
	STA	@dstat
	rlc		;NOT-READY into [CY]
	RET

SEEK:
	LXI	H,TRACK
	LDA	@trk
	MOV	B,M
	MOV	M,A
	lda	@side
	rrc
	rrc
	mov	c,a
	LDA	@intby
	ANI	10111111B
	ORA	C
	STA	@intby
	OUT	PORT
	lda	@trk
	CPI	0	;IF SEEK-TRK-0 THEN RECALIBRATE
	JZ	RECAL
	MVI	C,00100000B	;STEP TOWARDS HUB
	SUB	B
	RZ		;IF RELATIVE TRACKS SAME
	JRNC	SEEK1
	CMA
	INR	A
	MVI	C,00000000B	;ELSE STEP OUTWARD (TOWARDS RIM)
SEEK1	MOV	B,A	;# OF TRACKS TO SKIP
	LHLD	MODES
	mvi	d,0
	bit	5,m	;is drive DT ?
	jrz	step
	INX	H
	bit	5,m	;is media ST ?
	jrnz	step
	setb	5,d	;HALF-TRACK
STEP:
	BIT	5,D
	CNZ	STEPHEAD
	CALL	STEPHEAD
	DJNZ	STEP
	LDA	CTL$BYTE
	CALL	DISK$CTLR	;RESTORE CTL LINES
	JMP	RECDON	;HEAD-SETTLE PAUSE

STEPHEAD:
	BIT	5,C	;TEST DIRECTION OF STEP
	JRNZ	NOTOUT	;IF NOT "OUT" THEN DON'T WORRY...
	IN	DISK$CTL	;ELSE MAKE SURE WE DON'T TRY TO STEP PAST TRK-0
	ANI	0010B	;INTO "NEGATIVE TRACKS"
	RNZ
NOTOUT: LDA	CTL$BYTE
	ORA	C
	CALL	DISK$CTLR
	ORI	01000000B	;STEP BIT
	CALL	DISK$CTLR
	ANI	10111111B	;STEP BIT OFF
	CALL	DISK$CTLR
	LDA	ASTEPR	;TIME FOR HEAD TO STEP
	JMP	PAUSE

modes:	dw	0
ASTEPR: DB	0	;STEP RATE (CONVERTED FROM MODE BYTES)

DRIVE:	DB	4	;CURRENTLY SELECTED DRIVE (IN HARDWARE)
TRACK:	DB	0FFH	;CURRENT HEAD POSITION FOR CURRENT DRIVE
SELRR:	DB	0
TEC:	DB	0
SEC:	DB	0
CEC:	DB	0

SSC:	DB	0

TRKA:	DB	255,255,255,255,0	;CURRENT HEAD POSITION FOR EACH DRIVE

SAVEIX: DW	0
SAVEIY: DW	0

	END


	0

SSC:	DB	0
