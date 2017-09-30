vers equ '1 ' ; July 19, 1983  10:16  mjm  "LDRZ17.ASM"
********** LOADER DISK I/O ROUTINE FOR Z17  ********
	maclib Z80
	$-MACRO

	public	btend
	extrn	BDOS,CBOOT,DSKSTA,TIMEOT,MIXER,DIRBUF,DLOG
	extrn	NEWDSK,NEWTRK,NEWSEC,DMAA

driv0	equ	0

***** PHYSICAL DRIVES ARE ASSIGNED AS FOLLOWS *****
*****					      *****
*****  0 = FIRST (BUILT-IN) MINI FLOPPY       *****
*****  1 = SECOND (ADD-ON) MINI FLOPPY	      *****
*****  2 = THIRD (LAST ADD-ON) MINI FLOPPY    *****
*****					      *****
***************************************************

***************************************************
**  MINI-FLOPPY PORTS AND CONSTANTS
***************************************************
?DISK$CTL	EQU	7FH
?RCVR		EQU	7EH
?STAT		EQU	7DH
?DATA		EQU	7CH
?PORT		EQU	0F2H

?MOTOR$ON	EQU	10010000B	;AND ENABLE FLOPY-RAM
?SETTLE EQU	10	;10*2 = 20mS  STEP-SETTLING TIME
?SEL		EQU	25	; WAIT 50mS AFTER SELECTING
?MTRDLY EQU	2	; 1.024 SECONDS
?SEL$TIME	EQU	4	; = 2.048 SECONDS
?MOTOR$TIME	EQU	40	; = 20.48 SECONDS
***************************************************

?CLOCK		equ	11
?INT$BYTE	equ	13
?CTL$BYTE	equ	14
***************************************************

** START OF RELOCATABLE DISK I/O MODULE
	cseg		;START OF MODULE
	jmp	init
	JMP	SEL$Z17
	JMP	READ$Z17

	DB	'Z17 ',0,'Hard Sector loader ',0,'3.10'
	dw	vers
	db	'$'

modebt: equ	2288h
drvbt:	equ	2287h

dph:	DW	sectbl,0,0,0,DIRBUF,dpbssst,CSV,ALV
	DW	sectbl,0,0,0,DIRBUF,dpbdsst,CSV,ALV
	DW	sectbl,0,0,0,DIRBUF,dpbssdt,CSV,ALV
	DW	sectbl,0,0,0,DIRBUF,dpbdsdt,CSV,ALV

dpbssst:
	DW	20 ;SECTORS PER TRACK
	DB	3,7,0 ;SECTORS PER BLOCK
	DW	92-1 ;LAST BLOCK ON DISK
	DW	64-1 ; DIRECTORY ENTRIES
	DB 11000000B,0 ;DIRECTORY ALLOCATION MASK
	DW	16 ;CHECK SIZE
	DW	3  ;FIRST TRACK OF DIRECTORY
	DB	00000001B,00000011B,00001001B	;modes

dpbdsst:
	DW	20 ;SECTORS PER TRACK
	DB	3,7,0 ;SECTORS PER BLOCK
	DW	182-1 ;LAST BLOCK ON DISK
	DW	64-1 ; DIRECTORY ENTRIES
	DB 11000000B,0 ;DIRECTORY ALLOCATION MASK
	DW	16 ;CHECK SIZE
	DW	3  ;FIRST TRACK OF DIRECTORY
	DB	00100001B,00000011B,00001001B	;modes

dpbssdt:
	DW	20 ;SECTORS PER TRACK
	DB	4,15,1 ;SECTORS PER BLOCK
	DW	96-1 ;LAST BLOCK ON DISK
	DW	64-1 ; DIRECTORY ENTRIES
	DB 10000000B,0 ;DIRECTORY ALLOCATION MASK
	DW	16 ;CHECK SIZE
	DW	3  ;FIRST TRACK OF DIRECTORY
	DB	00000001B,00001011B,00001001B	;modes

dpbdsdt:
	DW	20 ;SECTORS PER TRACK
	DB	4,15,1 ;SECTORS PER BLOCK
	DW	186-1 ;LAST BLOCK ON DISK
	DW	64-1 ; DIRECTORY ENTRIES
	DB 10000000B,0 ;DIRECTORY ALLOCATION MASK
	DW	16 ;CHECK SIZE
	DW	3  ;FIRST TRACK OF DIRECTORY
	DB	00100001B,00001011B,00001001B	;modes

SEC$TBL:
	DB	1,2,9,10,17,18,5,6,13,14   ;LOGICAL/PHYSICAL SECTOR TABLE
	DB	3,4,11,12,19,20,7,8,15,16

STPTBL: DB	3	;00 =  6 mS (fastest rate)
	DB	6	;01 = 12 mS
	DB	10	;10 = 20 mS
	DB	15	;11 = 30 mS (slowest rate)

TPS:	DB	0	;NUMBER OF PHYSICAL HEAD POSITIONS (TRACKS PER SIDE)
TPS2:	DB	0	;NUMBER OF TRACKS USED ON SECOND SIDE

init:	lda	drvbt
	sta	mixer
	mvi	a,(JMP)
	sta	timeot
	lxi	h,TIME$OUT
	shld	timeot+1
	ret

SEL$Z17:
	SIXD	SAVE$IX
	SIYD	SAVE$IY
	XRA	A
	STA	SELRR
	LDA	modebt
	ADD	A	;*2
	ADD	A	;*4
	ADD	A	;*8
	ADD	A	;*16
	MOV	C,A
	MVI	B,0
	LXI	H,dph
	DAD	B
	SHLD	DPHA
	PUSH	H
	POPIX
	LDX	L,+10	;DPB ADDRESS
	LDX	H,+11
	SHLD	DPBA
	PUSH	H
	POPIY
	LDY	A,+3	;BSM
	STA	BLKMSK
	LDY	A,+13	;TRACK OFFSET
	STA	OFFSET
	LXI	D,+15	;MODE BYTES
	DAD	D	;
	SHLD	MODES
	MOV	A,M
	ANI	11B	;PHYSICAL SECTOR SIZE
	STA	BLCODE
	INX	H
	LXI	B,(36)*256+(40) ;40 TRACKS, 36 USED ON SECOND SIDE
	BIT	3,M	;TRACK DENSITY BIT
	JRZ	NOTDT
	LXI	B,(72)*256+(80) ;80 TRACKS, 72 USED ON SECOND SIDE
NOTDT:	SBCD	TPS
	MOV	A,M
	ANI	11B	;STEPRATE
	LXI	D,STPTBL
	ADD	E
	MOV	E,A
	mvi	a,0
	adc	d
	mov	d,a
	LDAX	D
	STA	ASTEPR	;COUNTER VALUE EQUIVELENT TO STEPRATE CODE
	CALL	LOGIN	;CONDITIONAL LOG-IN OF DRIVE (TEST FOR HALF-TRACK)
	LHLD	DPHA
	LDA	NEWDSK
	MOV	C,A
	LIXD	SAVE$IX
	LIYD	SAVE$IY
	RET

LOGIN:	lhld	dlog
	mov	a,l
	rar
	RC
;
;   TEST DISKETTE/DRIVE FOR "48 IN 96 TPI"
;
	LDA	NEWDSK
	STA	HSTDSK	;MAKE SURE "SELECT" KNOWS WHAT DRIVE TO SELECT
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
	INX	H
	BIT	3,M	;TEST IF DPB IS SET CORRECTLY
	JRNZ	SELERR	;IF NOT, CANNOT PROCESS THE DISKETTE
	SETB	4,M	;ELSE SETUP FOR "HALF-TRACK"
	RET

SELERR: XRA	A
	INR	A
	STA	SELRR
	RET

READ$Z17:
	SIXD	SAVE$IX
	SIYD	SAVE$IY
	LDA	SELRR
	ORA	A
	RNZ
	LXI	B,3
	LXI	H,NEWDSK
	LXI	D,REQDSK
	LDIR
DBLOCK: XRA	A		; CLEAR CARRY
	MOV	C,A		; CALCULATE PHYSICAL SECTOR
	LDA	BLCODE
	MOV	B,A
	LDA	NEWSEC
DBLOK1: DCR	B
	JM	DBLOK2
	RAR
	RARR	C
	JR	DBLOK1
DBLOK2: STA	REQSEC		; SAVE IT
	LDA	BLCODE		; CALCULATE BLKSEC
DBLOK3: DCR	A
	JM	DBLOK4
	RLCR	C
	JR	DBLOK3
DBLOK4: MOV	A,C
	STA	BLKSEC		; STORE IT
ALLOC:	XRA	A		; NO LONGER WRITING AN UNALLOCATED BLOCK
	STA	UNALLOC
CHKRD:				; IS SECTOR ALREADY IN BUFFER ?
CHKSEC: LXI	H,NEWTRK
	LDA	OFFSET
	CMP	M		; IS IT THE DIRECTORY TRACK ?
	JRNZ	CHKBUF
	INX	H
	MOV	A,M
	ORA	A		; FIRST SECTOR OF DIRECTORY ?
	JRZ	READIT 
CHKBUF: LXI	H,REQDSK
	LXI	D,HSTDSK
	MVI	B,3
CHKNXT: LDAX	D
	CMP	M
	JRNZ	READIT
	INX	H
	INX	D
	DJNZ	CHKNXT
	JR	NOREAD		; THEN NO NEED TO PRE-READ
READIT:
	LXI	D,HSTDSK	; SET UP NEW BUFFER PARAMETERS
	LXI	H,REQDSK
	LXI	B,3
	LDIR
	call	RD$SEC		; READ THE SECTOR
NOREAD: LXI	H,HSTBUF	; POINT TO START OF SECTOR BUFFER
	LXI	B,128
	LDA	BLKSEC		; POINT TO LOCATION OF CORRECT LOGICAL SECTOR
MOVIT1: DCR	A
	JM	MOVIT2
	DAD	B
	JR	MOVIT1
MOVIT2: LDED	DMAA		; POINT TO DMA
	LDIR			; MOVE IT
	XRA	A		; FLAG NO ERROR
	RET			; RETURN TO BDOS (OR RESEL ROUTINE)

RD$SEC: CALL	READ		; READ A PHYSICAL SECTOR
	RZ			; RETURN IF SUCCESSFUL
	MVI	A,0FFH		; FLAG BUFFER AS UNKNOWN
	STA	HSTDSK
RWERR:	POP	D		; THROW AWAY TOP OF STACK
	MVI	A,1		; SIGNAL ERROR TO BDOS
	RET			; RETURN TO BDOS (OR RESEL ROUTINE)


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
	MVI	C,3
XSYNC	CALL	SYNC0
	DCR	C
	JNZ	XSYNC
	LXI	H,HSTBUF
	MVI	B,0	;256 BYTES
	CALL	SYNC
	JC	ERRX
RD	CALL	INPUT$DISK
	MOV	M,A
	INX	H
	DJNZ	RD
	MOV	L,D
	CALL	INPUT$DISK
	EI			;ENABLE INTERUPTS +++++++++++++++++++++++++
	SUB	L
	RZ	;SUCCESSFULL READ...
ERRX	EI			;ENABLE INTERUPTS +++++++++++++++++++++++++
	DCRY	+0
	JRNZ	READ1
	CALL	ERROR1	;SETS STATUS BIT
	JMP	ERROR

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
	LXI	H,SIDE	;
	MOV	A,E	;SIDE NUMBER
	CMP	M	; >>	CYCLES
	JNZ	SKERR
	INX	H
	MOV	A,D	;TRACK NUMBER
	CMP	M
	JZ	OVER2	; >>	CYCLES
SKERR:	EI
	DCRX	+0
	JZ	SEEK$ERROR
	CALL	RECALIBRATE
	JC	SEEK$ERROR
	CALL	SEEK
	JC	SEEK$ERROR
	JMP	FIND1
OVER2	LDA	HSTSEC	;SECTOR NUMBER
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
	IN	?DISK$CTL
	ANI	00000001B
	MOV	C,A
FLOOP	IN	?DISK$CTL
	ANI	00000001B
	CMP	C
	JRZ	FLOOP
	MOV	C,A
	CPI	00000000B
	JRNZ	FLOOP
	PUSH	H
	LXI	H,?CLOCK
	MVI	A,6	;12 mS WAIT
	ADD	M
FXL	CMP	M
	JNZ	FXL
	DI			;DISABLE INTERUPTS ++++++++++++++++++++++
	POP	H
FL1	IN	?DISK$CTL
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
	LXI	H,DSKSTA
	SETB	3,M	;FORMAT ERROR
	STC
	RET

PAUSE5	LXI	H,?CLOCK+1	;HI BYTE TICS EVERY 512mS
	JR	PAUSX
PAUSE:	LXI	H,?CLOCK
PAUSX	ADD	M
	EI
PLOOP	CMP	M
	JRNZ	PLOOP
	RET

RECALIBRATE:
	XRA	A
	STA	TRACK
RECAL	MVI	B,255
REC1	IN	?DISK$CTL
	ANI	00000010B
	JRNZ	RECDON	;IF ALREADY AT TRK0
	LDA	?CTL$BYTE
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
	LXI	H,DSKSTA
	SETB	2,M	;SEEK ERROR
	STC
	RET

RECDON	MVI	A,?SETTLE
	JR	PAUSE

INPUT$DISK:
	IN	?STAT
	RAR
	JNC	INPUT$DISK
	IN	?DATA
	MOV	E,A
	XRA	D
	RLC
	MOV	D,A
	MOV	A,E
	RET

SYNC0	XRA	A
	JR	SYNCX

SYNC:
	MVI	A,0FDH
SYNCX:
	MVI	D,80	;TRY 80 TIMES
	OUT	?RCVR
	IN	?RCVR	;RESET RECEIVER
SLOOP	IN	?DISK$CTL
	ANI	00001000B
	JRNZ	FOUND
	DCR	D
	JRNZ	SLOOP
	STC
	RET
FOUND	IN	?DATA
	MVI	D,0	;CLEAR CRC
	RET


SELECT:
	LXI	H,DRIVE
	LDA	HSTDSK
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
	STA	SEL$TIMER
NO$SEL	LDA	DRIVE
	INR	A
	MVI	B,3
	MVI	C,00000010B	;DRIVE A:
DRVL	DCR	A
	JZ	GDRIVE
	RLCR	C
	DJNZ	DRVL
	MVI	C,0	;DESELECT ALL DRIVES
GDRIVE	MVI	A,?MOTOR$ON
	ORA	C
	STA	?CTL$BYTE
	CALL	DISK$CTLR	;TURN MOTOR ON NOW
	LDA	TRACK
	CPI	0FFH	;MEANS DRIVE IS NOT LOGGED-ON
	JRNZ	LOGGED
	CALL	RECALIBRATE	;DETERMINE HEAD POSITION
	RC		;IF ERROR
	LXI	H,0
	SHLD	SIDE
	LXI	H,?INT$BYTE
	RES	6,M
	MOV	A,M
	OUT	?PORT
LOGGED:
	IN	?DISK$CTL
	ANI	00000001B
	MOV	E,A
	LXI	B,0800H ;MUST FIND INDEX BEFORE COUNT GOES TO ZERO
IDX	IN	?DISK$CTL
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
	MOV	E,A
	IN	?DISK$CTL
	ANI	00000100B	;WRITE PROTECT
	RRC
	ORA	E		;READY
	STA	DSKSTA
	CMA		;NOT-READY
	RAR		; INTO CY BIT
	BIT	0,A	; WRITE ENABLE NOTCH INTO ZR BIT
	RET

SEEK:
	LXI	H,TRACK
	LDA	HSTTRK
	MOV	B,M
	MOV	M,A
	CALL	CONVERT
	STA	SIDE+1
	PUSH	PSW
	LDA	?INT$BYTE
	ANI	10111111B
	ORA	C
	STA	?INT$BYTE
	OUT	?PORT
	MOV	A,C
	RLC
	RLC
	STA	SIDE
	MOV	A,B
	CALL	CONVERT
	MOV	B,A
	POP	PSW
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
	INX	H
	MOV	D,M	;HALF-TRACK BIT IS #4
STEP:
	BIT	4,D
	CNZ	STEPHEAD
	CALL	STEPHEAD
	DJNZ	STEP
	LDA	?CTL$BYTE
	CALL	DISK$CTLR	;RESTORE CTL LINES
	JMP	RECDON	;HEAD-SETTLE PAUSE

STEPHEAD:
	BIT	5,C	;TEST DIRECTION OF STEP
	JRNZ	NOTOUT	;IF NOT "OUT" THEN DON'T WORRY...
	IN	?DISK$CTL	;ELSE MAKE SURE WE DON'T TRY TO STEP PAST TRK-0
	ANI	0010B	;INTO "NEGATIVE TRACKS"
	RNZ
NOTOUT: LDA	?CTL$BYTE
	ORA	C
	CALL	DISK$CTLR
	ORI	01000000B	;STEP BIT
	CALL	DISK$CTLR
	ANI	10111111B	;STEP BIT OFF
	CALL	DISK$CTLR
	LDA	ASTEPR	;TIME FOR HEAD TO STEP
	JMP	PAUSE

CONVERT:
	MVI	C,00000000B	;SIDE 0
	LHLD	TPS	;TPS AND TPS2
	CMP	L	;ACCESS TO SECOND SIDE??
	RC	;IF NOT, QUIT HERE
	SUB	L	;PUT TRACK NUMBER IN PROPER RANGE
	CMA
	INR	A	;NEGATE TRACK NUMBER FOR COMPUTATION
	ADD	H	;EFFECT: SUBTRACT TRACK FROM "TPS2"
	DCR	A	; -1 BECAUSE TRACKS ARE NUMBERED 0-N
	MVI	C,01000000B	;BIT TO SELECT SECOND SIDE
	RET

DISK$CTLR:
	OUT	?DISK$CTL
	PUSH	PSW
	MOV	C,A
	ANI	00010000B	;MOTOR BIT
	JZ	MT$ON
	DI
	LDA	MOTOR$TIMER
	ORA	A
	MVI	A,?MOTOR$TIME
	STA	MOTOR$TIMER
	STA	SEL$TIMER
	JNZ	MT$ON
	MVI	A,?MTRDLY
	CALL	PAUSE5
MT$ON	MOV	A,C
	ANI	00001110B	;SELECT BITS
	JZ	NOT$ON
	DI
	LDA	SEL$TIMER
	ORA	A
	MVI	A,?SEL$TIME
	STA	SEL$TIMER
	JNZ	NOT$ON
	MVI	A,?SEL
	CALL	PAUSE
NOT$ON	POP	PSW
	EI
	RET

TIME$OUT:
	LXI	H,MOTOR$TIMER
	DCR	M
	JM	MOTOR$OFF
	DCX	H
	DCR	M
	RP
SEL$OFF:
	LDA	?CTL$BYTE
	ANI	11110001B
	OUT	?DISK$CTL
	MVI	M,0
	RET

MOTOR$OFF:
	MVI	M,0
	LDA	?CTL$BYTE
	ANI	11100001B
	OUT	?DISK$CTL
	RET

ASTEPR: DB	0	;STEP RATE (CONVERTED FROM MODE BYTES)
BLKSEC	DB	0
OFFSET	DB	0
UNALLOC DB	0
BLKMSK	DB	0
URECORD DW	0
BLCODE	DB	0
MODES	DW	0
DPBA	DW	0
DPHA	DW	0

DRIVE	DB	4	;CURRENTLY SELECTED DRIVE (IN HARDWARE)
TRACK	DB	0FFH	;CURRENT HEAD POSITION FOR CURRENT DRIVE
SEL$TIMER	DB	1
MOTOR$TIMER	DB	1
SELRR	DB	0
TEC	DB	0
SEC	DB	0
CEC	DB	0

SSC	DB	0

SIDE	DB	0,0	;SIDE/TRACK NUMBERS FOR COMPARE TO SECTOR-HEADER

TRKA:	DB	255,255,255,255,0	;CURRENT HEAD POSITION FOR EACH DRIVE

SAVE$IX DW	0
SAVE$IY DW	0

REQDSK: DB	0
REQTRK: DB	0
REQSEC: DB	0

HSTDSK: DB	0FFH
HSTTRK: DB	0FFH
HSTSEC: DB	0FFH

btend	equ	$

HSTBUF: DS	256

CSV	DS	0
ALV	DS	0

	end
SEC: DB	0

HSTDSK: DB	0FFH
HSTTRK: DB	0FFH
HSTSEC: DB	0FFH

btend	equ	$

HSTBUF: DS	25