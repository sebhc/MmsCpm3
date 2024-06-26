; September 2,1982 LWF
**************** CP/M DISK I/O ROUTINES  **********
**************** 4 USER CORVUS MODULE	 **********

********** MACRO ASSEMBLER DIRECTIVES *************
	TITLE	'CVS405'
	MACLIB	Z80	; USE Z80 LIBRARY
	$-MACRO 	; DISABLE MACRO EXPANSIONS
***************************************************
	DW	MODLEN,BUFLEN

BASE	EQU	0000H	;ORG FOR RELOC

***** PHYSICAL DRIVES ARE ASSIGNED AS FOLLOWS *****
*****					      *****
***** 15-16 = 2 - 2.0 Mbyte partitions	      *****
***** 17-18 = 2 - 0.6 Mbyte partitions	      *****
*****					      *****
***************************************************

**  PORTS AND CONSTANTS

RO	EQU	040H		; makes R/O to other partitions
NB	EQU	080H		; prevents partition from booting
D0	EQU	   0		; drive 0 select for daisy chaining
D1	EQU	090H		; drive 1 select (not-bootable)

?HSTAT	EQU	058H		; HARD DISK STATUS REGISTER
?HDATA	EQU	059H		; HARD DISK DATA REGISTER

** LINKS TO REST OF SYSTEM ************************

PATCH	EQU	BASE+1600H
MBASE	EQU	BASE		; MODULE BASE
COMBUF	EQU	BASE+0C000H	; COMMON BUFFER
BUFFER	EQU	BASE+0F000H	; MODULE BUFFER

** PAGE ZERO ASSIGNMENTS **************************

	ORG	0
?CPM		DS	3
?DEV$STAT	DS	1
?LOGIN$DSK	DS	1
?BDOS		DS	3
?RST1		DS	3
?CLOCK		DS	2
?INT$BYTE	DS	1
?CTL$BYTE	DS	1
		DS	77
?FCB		DS	36
?DMA		DS	128
?TPA		DS	0
***************************************************
PAGE


** OVERLAY MODULE INFORMATION ON BIOS *************

	ORG	PATCH-2
INIT$RO DS	2
	DS	51		; JUMP TABLE
DSK$STAT	DS	1
STEPR	DS	1		; MINI-FLOPPY STEP RATE
SIDED	DS	3		; SIDE CONTROL FOR EACH DRIVE
				; (0-SINGLE,1=DOUBLE)
	DS	4		; FOR EIGHT-INCH DRIVES
MIXER	DB	15,16,17,18
	DS	12
DRIVE$BASE:
	DB	15,19		; DRIVES 15-18
	DW	MBASE
	DS	28

TIME$OUT:	DS	3

NEWBAS	DS	2
NEWDSK	DS	1
NEWTRK	DS	1
NEWSEC	DS	1
HRDTRK	DS	2
DMAA	DS	2
***************************************************
PAGE


** START OF RELOCATABLE DISK I/O MODULE

	ORG	MBASE		; START OF MODULE

	JMP	SEL$HARD
	JMP	READ$HARD
	JMP	WRITE$HARD
;
;	Not strictly 2.24 as mode bytes cannot be included yet without
;	modifying the CONFIG utility as CONFIG requires the partition
;	table follow the text string, and the mode function requires
;	the DPH's be in this location
;
	DB	'77314 Corvus Interface ( 5MB, 4 partitions) v1.201 $'
;
;	The total number of sectors available is as follows:
;
;		5 Mbyte drive		42624
;	       10 Mbyte drive (Rev. A)	75488
;	       10 Mbyte drive (Rev. B)	82624
;	       20 Mbyte drive	       151584
;
;			all sizes are adjusted to account for space
;			       used by CORVUS for PIPES etc.
;			   This also includes space used by MMS.
;
;	Unless a custom module is being built, always assume a Rev. B
;	drive if you are building a 10 Mbyte module.
;	Every partition should have two tracks of system space allocated
;	which uses 144 sectors.
;
;	For a 5 Mbyte drive with three partitions this would be:
;			144+144+144 = 432
;	The total space available for directory storage and file space would
;	therefore be 42624-432 or 42192 sectors.
;
;	DISK SEGMENT BOUNDRY TABLE
;		THIS TABLE IS INSTALLED AT BOOT TIME
;		AND IS READ FROM SECTOR '0' OF THE CORVUS
;		DISK. THIS TABLE CONTAINS 3 8-BIT BYTES.
;		THE LEASE SIGNIFICANT 20 BITS FORM A 128
;		BYTE SECTOR ADDRESS FOR THE CORVUS. THE
;		REMAINING BITS (BITS 7,6,5,4) OF THE FIRST
;		BYTE ARE ASSIGNED AS FOLLOWS:
;			BIT 7 = BOOT BIT (0 = A BOOTABLE PARTITION)
;			BIT 6 = R/O BIT ( 1 = R/O TO OTHER SYSTEMS)
;			BITS 5,4 = DISK SELECT FOR DAISY CHAINING
;
DSKBD:
	DB	  0,   8, 208	;   2256   Use 2256 for an offset
	DB	  0,  72, 128	;  18560   except for a 10 Mbyte
	DB	  0, 136,  48	;  34864   Rev. A drive. Then use
	DB	  0, 155, 192	;  39832   256 for an offset. This
	DB     NB+0,   8, 208	;	   is because pipes are not
	DB     NB+0,   8, 208	;	   available on a Rev. A
	DB     NB+0,   8, 208	;	   drive.
	DB     NB+0,   8, 208	;
	DB     NB+0,   8, 208	;
;
;	DISK HEADER BLOCKS
;
HRD$BASE:
	DW	0,0,0,0,DIRBUF,DPB1,CSVCM,ALV15
	DW	0,0,0,0,DIRBUF,DPB2,CSVCM,ALV16
	DW	0,0,0,0,DIRBUF,DPB3,CSVCM,ALV17
	DW	0,0,0,0,DIRBUF,DPB4,CSVCM,ALV18
	DW	0,0,0,0,DIRBUF,DPB5,CSVCM,ALV19
	DW	0,0,0,0,DIRBUF,DPB6,CSVCM,ALV20
	DW	0,0,0,0,DIRBUF,DPB7,CSVCM,ALV21
	DW	0,0,0,0,DIRBUF,DPB8,CSVCM,ALV22
	DW	0,0,0,0,DIRBUF,DPB9,CSVCM,ALV23
PAGE


;	DISK PARAMETER BLOCKS
;
;	2020K BOOTABLE DISK
;
DPB1:	DW	72		; SPT
	DB	5,32-1,1	; BSH,BLM,EXM
	DW	505-1,512-1	; DSM,DRM
	DB	11110000B,0	; AL0,AL1
	DW	0,2		; CKS,OFF
;
;	2020K BOOTABLE DISK
;
DPB2:	DW	72		; SPT
	DB	5,32-1,1	; BSH,BLM,EXM
	DW	505-1,512-1	; DSM,DRM
	DB	11110000B,0	; AL0,AL1
	DW	0,2		; CKS,OFF
;
;	604K BOOTABLE DISK
;
DPB3:	DW	72		; SPT
	DB	5,32-1,3	; BSH,BLM,EXM
	DW	152-1,128-1	; DSM,DRM
	DB	10000000B,0	; AL0,AL1
	DW	0,2		; CKS,OFF
;
;	608K BOOTABLE DISK
;
DPB4:	DW	72		; SPT
	DB	5,32-1,3	; BSH,BLM,EXM
	DW	152-1,128-1	; DSM,DRM
	DB	10000000B,0	; AL0,AL1
	DW	0,2		; CKS,OFF
;
;	UNUSED
;
DPB5:	DB	72,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DPB6:	DB	72,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DPB7:	DB	72,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DPB8:	DB	72,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DPB9:	DB	72,0,0,0,0,0,0,0,0,0,0,0,0,0,0

PAGE


;	SELECT DISK FUNCTION
;
SEL$HARD:
;
;	THIS ROUTINE READS THE DISK DEFINITION TABLE FROM
;	SECTOR '0' OF THE DISK AND INSTALLS IT IN THE
;	DRIVE DEFINITION MODULE IF NEEDED.
;
	LDA	DFLAG		; GET DISK TABLE FLAG
	ORA	A		; TO TEST THE ACCUMULATOR
	JRNZ	SELIT		; SKIP IF NOT FIRST PASS
	PUSH	B		; SAVE REGISTERS
	MVI	A,12H		; READ COMMAND
	CALL	ISSUE		; SEND TO DISK
	MVI	A,1		; DRIVE #1
	CALL	ISSUE		; SEND TO DISK
	STA	DFLAG		; SET TABLE UPDATE FLAG
	XRA	A		; SECTOR NUMBER 0
	CALL	ISSUE		; SEND TO DISK AS
	CALL	ISSUE		; 16 BIT SECTOR #
	CALL	RESULT		; GET DISK READ STATUS
	JC	ERROR		; DISK ERROR IF SET
	MVI	B,128		; ALL'S WELL, READ A SECTOR
	LXI	H,DIRBUF	; INTO TEMPORARY STORAGE
LOAD:	CALL	WAIT$BYTE	; READ ONE BYTE
	RRC			; RESTORE DATA
	MOV	M,A		; SAVE IN TEMP STORAGE
	INX	H		; INCREMENT STORAGE POINTER
	DJNZ	LOAD		; DONE YET ?
	LXI	H,DIRBUF	; YES, TEMP. STORAGE POINTER
	LXI	D,DSKBD 	; FINAL TABLE LOCATION
	LXI	B,27		; MOVE 27 BYTES
	LDIR			; MOVE THE TABLE
	POP	B		; RESTORE REGISTERS
PAGE


;
;	NOW LETS PERFORM THE REAL SELECT FUNCTION
;
SELIT:	LXI	H,DSKBD 	; ADDRESS OF BOUNDRY TABLE
	MOV	A,C		; SUBTRACT DISK DRIVE
	SUI	15		; OFFSET OF 15
	MOV	C,A		; RESTORE AS DRIVE NUMBER
	MVI	B,0		; IN B,C REGISTER PAIR
	DAD	B		; ADD AS OFFSET INTO TABLE
	DAD	B		; EACH TABLE ENTRY IS
	DAD	B		; THREE BYTES LONG
	MOV	A,M		; GET MSByte
	STA	DSKMSB		; SAVE IT AWAY
	INX	H		; POINT TO NEXT BYTE
	MOV	D,M		; PUT IT IN REGISTER
	INX	H		; PAIR D&E
	MOV	E,M		; SO IT CAN BE SAVED
	SDED	DSKOFF		; WITH THE MSByte
	LXI	D,HRD$BASE
	RET
DSKMSB: DB	0		; MSByte OF OFFSET
DSKOFF: DW	0		; 2 LSBytes OF OFFSET
DFLAG:	DB	0		; PASS FLAG
;
;	READ DISK FUNCTION
;
READ$HARD:
	IN	?HSTAT
	ANI	10000000B
	JRNZ	ERROR		; HARD DISK NOT CONNECTED
	MVI	A,12H		; READ COMMAND
	CALL	SETADR		; SETUP CONTROLLER
	CALL	RESULT		; STATUS OF READ
	JRC	ERROR
HRD1:	IN	?HSTAT
	RAR
	JRC	HRD1
	INI
	JRNZ	HRD1
	XRA	A
	RET
PAGE


SETADR:
	CALL	ISSUE		; SEND COMMAND TO HARD DISK
	LHLD	HRDTRK
	MOV	E,L
	MOV	D,H
	DAD	H	; *2
	DAD	H	; *4
	DAD	H	; *8
	DAD	D	; *9
	DAD	H	; *18
	DAD	H	; *36
	DAD	H	; *72
	LDA	NEWSEC
	MOV	E,A
	MVI	D,0
	DAD	D		; (TRK*72)+SEC
	LDED	DSKOFF		; GET 2 LSBytes OF OFFSET
	DAD	D		; ADD TO H & L
	LDA	DSKMSB		; GET MSByte
	ACI	0		; ADD OFFSET AND CARRY
	ANI	15		; MASK TO 4 BITS
	RLC			; ROTATE OFFSET INTO
	RLC			; 4 MSB's OF ACCUMULATOR
	RLC			; SO WE CAN PUT THE
	RLC			; DRIVE NUMBER INTO
	INR	A		; THE 4 LSB's (1)
	CALL	ISSUE		; SEND EXTENDED ADR + DRIVE
	MOV	A,L
	CALL	ISSUE
	MOV	A,H
	CALL	ISSUE
	LHLD	DMAA		; HERE STRICTLY FOR SAVING SPACE
	LXI	B,(128)*256+(?HDATA)
	RET
PAGE


RESULT:
	IN	?HSTAT
	ANI	2
	JRZ	RESULT
	MVI	A,8		; OVERCOMES BUG IN THE '7711'
HDLY:	DCR	A		; REVISION 'A' CORVUS CONTROLLER
	JRNZ	HDLY

WAIT$BYTE:
	IN	?HSTAT
	ANI	1
	JRNZ	WAIT$BYTE
	IN	?HDATA
	STA	DSK$STAT
	RLC			; BIT 7 TO CARRY, 1=FATAL ERROR
	RET

;SSUE:				; ORIGINAL CODE
;	DI
;	MOV	C,A
;SS1	IN	?HSTAT
;	ANI	1
;	JRNZ	ISS1 
;	MOV	A,C
;	OUT	?HDATA
;	EI
;	RET

ISSUE:	MOV	C,A		; MODIFIED TO IMPROVE RESPONSE TO
ISS1:	DI			;  INTERRUPT DRIVEN KEYBOARD
	IN	?HSTAT
	ANI	1
	JRZ	ISS2
	EI
	NOP
	NOP
	JR	ISS1


ERROR	XRA	A
	INR	A
	RET
PAGE


WRITE$HARD:
	IN	?HSTAT
	ANI	10000000B
	JRNZ	ERROR		; HARD DISK NOT CONNECTED
;
;	THIS CODE CHECKS FOR R/O
;
	LXI	H,MIXER 	; TEST IF DRIVE IS R/O
	LDA	NEWDSK		; REQUESTED DRIVE
	MOV	B,A		; TEMPORARY STORAGE
	LDA	DSKMSB		; GET TABLE MS BYTE
	BIT	6,A		; SEE IF R/O BIT IS SET
	JRZ	NORO		; JUMP IF NOT GLOBAL R/O
	MOV	A,B		; GET REQUESTED DRIVE
	CMP	M		; IS IT DRIVE A
	JRNZ	ERROR		; JUMP IF IT IS'NT
NORO:	MOV	A,B		; GET REQUESTED DRIVE
	LXI	B,16
	LDA	NEWDSK
	CCIR
	JRNZ	ERROR
	LHLD	INIT$RO
	INR	C
SHFT:	DAD	H		; SHIFT R/O BIT INTO CARRY
	DCR	C
	JRNZ	SHFT
	JRC	ERROR
;
;	END OF R/O CODE
;
	MVI	A,13H		; WRITE COMMAND
	CALL	SETADR		; SETUP CONTROLLER
HWR1:	IN	?HSTAT
	RAR
	JRC	HWR1
	OUTI
	JRNZ	HWR1
	CALL	RESULT
	JRC	ERROR
	XRA	A
	RET

ISS2:	MOV	A,C
	OUT	?HDATA
	EI
	RET


	REPT   (($+0FFH) AND 0FF00H)-$
	  DB	  0
	ENDM
PAGE


MODLEN	EQU	$-MBASE

 DB 00100100B,10000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B
 DB 00000000B,00000000B,00000000B,00000000B,01010101B,00000000B,01010101B,00000000B
 DB 01010101B,00000000B,01010101B,00000000B,01010101B,00000000B,01010101B,00000000B
 DB 01010101B,00000000B,01010101B,00000000B,01010101B,00000000B,00000000B,00000000B
 DB 00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B
 DB 00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,01000000B,00100001B
 DB 00100010B,01001001B,00001001B,00000001B,00100000B,00010000B,00000000B,10000000B
 DB 10010000B,00000000B,00010010B,00000000B,00000010B,01000000B,00000100B,00000100B
 DB 01000000B,00000100B,01000100B,10000000B,00000000B,00000000B,00100000B,00000000B
 DB 00000000B,00000100B,10001000B,00000000B,00010000B,00100000B,00000010B,00000000B
 DB 00100000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B
 DB 00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B

********************************************************
** COMMON BUFFERS
********************************************************
	ORG	COMBUF
	DS	20
	DS	64
	DS	2
DIRBUF	DS	128
********************************************************
**  BUFFERS
********************************************************
	ORG	BUFFER
CSVCM	DS	0
ALV15	DS	64
ALV16	DS	64
ALV17	DS	19
ALV18	DS	19
ALV19	DS	0
ALV20	DS	0
ALV21	DS	0
ALV22	DS	0
ALV23	DS	0
*********************************************************
BUFLEN	EQU	$-BUFFER
	END
