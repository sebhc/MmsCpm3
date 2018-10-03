

 

********** CP/M LINKABLE BOOT ROUTINE **********
********** 8 USER CONSTELLATION BOOT  **********

************************************************
****  MACRO ASSEMBLER DIRECTIVES  **************
	TITLE	'BOOT20'
	PAGE	58
	MACLIB	Z80	; USE Z80 LIBRARY
	$-MACRO 	; SUPRESS MACRO EXPANSIONS
************************************************
	DW	MODLEN,(-1)

BASE	EQU	0000H	;ORG FOR RELOC

***** PHYSICAL DRIVES ARE ASSIGNED AS FOLLOWS *****
*****					      *****
*****  0 = FIRST (BUILT-IN) MINI FLOPPY       *****
*****  1 = SECOND (ADD-ON) MINI FLOPPY	      *****
*****  2 = THIRD (LAST ADD-ON) MINI FLOPPY    *****
*****  15-23 = CORVUS HARD DISK SEGMENTS      *****
*****  5 = FIRST 8" FLOPPY (REMEX)            *****
*****  6 = SECOND 8" FLOPPY                   *****
*****  7 = THIRD 8" FLOPPY                    *****
*****  8 = FOURTH 8" FLOPPY                   *****
*****					      *****
***************************************************

**  PORTS AND CONSTANTS

?STAT	EQU	058H
?DATA	EQU	059H

?PORT	EQU	0F2H

?AUX	EQU	0D0H
?PRINTER	EQU	0E0H
?MODEM	EQU	0D8H

?LINE$CTL	EQU	00000011B	;NO PARITY, 1 STOP BIT, 8 DATA BITS
?MOD$CTL	EQU	00001111B	;SET ALL CONTROL LINES TO 'READY'

?STACK	EQU	2480H		; INITIAL STACK POINTER
?TMEM	EQU	2580H		; TEMPORARY STORAGE FOR DISK TABLE

?S19200 EQU	6	; 19,200 BAUD
?S9600	EQU	12	;  9,600 BAUD
?S4800	EQU	24	;  4,800 BAUD
?S2400	EQU	48	;  2,400 BAUD
?S1200	EQU	96	;  1,200 BAUD
?S600	EQU	192	;    600 BAUD
?S300	EQU	384	;    300 BAUD
?S150	EQU	768	;    150 BAUD
?S110	EQU	1047	;    110 BAUD
***************************************************
PAGE




** LINKS TO REST OF SYSTEM

@BIOS	EQU	BASE+1600H
@BDOS	EQU	@BIOS-0E00H
***************************************************

** PAGE ZERO ASSIGNMENTS

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




** START OF RELOCATABLE DISK BOOT MODULE

	ORG	2280H
BOOT:
	JMP	AROUND
SECTRS	DB	0	;NUMBER OF SECTORS TO BOOT, FROM MOVCPM.COM
			;PATCHED DURING EXECUTION OF MOVCPM
DRIVE	DB	15	;PATCHED ALSO BY ASSIGN PROGRAM

*** START OF UNIQUE ROUTINE FOR BOOTING

AROUND: LXI	SP,?STACK	; INITIALIZE STACK POINTER
	LXIX	?TMEM		; TEMPORARY STORAGE
	MVI	L,1		; READ ONE SECTOR ONLY
	LXI	D,0		; CLEAR D&E
	MVI	C,0		; AND 'C' TO SECTOR 0
	CALL	RDSEC		; READ THE SECTOR
	LXI	H,?TMEM 	; DISK TABLE ADDRESS
	LDA	DRIVE		; GET DISK DRIVE
	SUI	15		; BASE ADDRESS
	JC	0		; TRY AGAIN IF LESS THAN 15
	CPI	9		; CHECK FOR RANGE
	JNC	0		; TRY AGAIN IF OVER 23
	MOV	C,A		; SETUP DRIVE # OFFSET
	MVI	B,0		; IN B,C REGISTER PAIR
	DAD	B		; ADD AS OFFSET INTO TABLE
	DAD	B		; EACH TABLE ENTRY IS
	DAD	B		; THREE BYTES LONG
	MOV	A,M		; GET MSByte
	RAL			; CHECK MSB
	JC	0		; NOT BOOTABLE IF ONE 
	RAR			; RESTORE THE ACCUMULATOR
	ANI	15		; MASK OFF 4 MSB's
	INX	H		; POINT TO NEXT BYTE
	MOV	D,M		; PUT IT IN REGISTER
	INX	H		; PAIR D,E
	MOV	E,M		; FOR TEMPORARY STORAGE
	MOV	C,A		; ALSO SAVE MSByte
	CALL	INCRE		; INCREMENT POINTER BY 2
	CALL	INCRE		; FOR BOOT MODULE OFFSET
	LXIX	@BDOS
	LDA	SECTRS
	MOV	L,A		; NUMBER OF SECTORS TO READ
	CALL	RDSEC		; LOAD DATA
	JR	START		; AND START INITIALIZATION
PAGE



;
;	READ DISK SECTORS ROUTINE. ENTERED WITH THE X-INDEX
;	REGISTED POINTING TO RAM AND THE NUMBER OF SECTORS
;	TO READ IN L. C-D-E CONTAINS A 20 BIT DISK ADDRESS.
;
RDSEC:	MVI	A,12H		; READ COMMAND
	CALL	ISSUE		; SEND TO CONTROLLER
	MOV	A,C		; GET 4 MSB's
	RLC			; ROTATE DATA INTO THE
	RLC			; 4 MSB's OF ACCUMULATOR
	RLC			; SO WE CAN PUT THE
	RLC			; DRIVE NUMBER INTO
	INR	A		; THE 4 LSB's (1)
	CALL	ISSUE
	MOV	A,E
	CALL	ISSUE
	MOV	A,D
	CALL	ISSUE
WAIT1:	IN	?STAT
	ANI	2
	JRZ	WAIT1
	MVI	A,8
DLY:	DCR	A
	JRNZ	DLY
	CALL	GET	;STATUS
	RLC
	JC	0	;RETURN TO MONITOR IF ERROR
	MVI	B,128
LOAD:	CALL	GET
	STX	A,0
	INXIX	  
	DJNZ	LOAD
	CALL	INCRE		; INCREMENT SECTOR POINTER
	DCR	L
	JRNZ	RDSEC
	RET
;
;	THIS SUBROUTINE INCREMENTS THE 20 BIT SECTOR POINTER
;
INCRE:	INR	E		; INCREMENT LSByte
	JRNZ	NOINC		; CARRY OUT ?
	INR	D		; YES, INCREMENT NEXT BYTE
	JRNZ	NOINC		; CARRY OUT AGAIN ?
	INR	C		; YES, INCREMENT LAST BYTE
NOINC:	RET

***************************************************
PAGE




** START OF SYSTEM INITIALIZATION

START:	DI
* INITIALIZE I/O, ETC
	XRA	A
	OUT	?AUX+4
	OUT	?PRINTER+4
	OUT	?MODEM+4
	MVI	A,?LINE$CTL
	ORI	10000000B	;ENABLE DIVISOR LATCH
	OUT	?AUX+3
	OUT	?PRINTER+3
	OUT	?MODEM+3
* BAUD RATE SETUP:
	LXI	H,?S9600	;AUX SERIAL @ 9600 BAUD
	MOV	A,L
	OUT	?AUX
	MOV	A,H
	OUT	?AUX+1
	LXI	H,?S9600	;PRINTER @ 9600 BAUD
	MOV	A,L
	OUT	?PRINTER
	MOV	A,H
	OUT	?PRINTER+1
	LXI	H,?S300 ;MODEM (PAPER TAPE) @ 300 BAUD
	MOV	A,L
	OUT	?MODEM
	MOV	A,H
	OUT	?MODEM+1
* NOW GET PORTS READY FOR I/O
	MVI	A,?LINE$CTL	;NOW DE-SELECT DIVISOR LATCH
	OUT	?AUX+3
	OUT	?PRINTER+3
	OUT	?MODEM+3
	MVI	A,?MOD$CTL	;SIGNAL 'READY'
	OUT	?AUX+4
	OUT	?PRINTER+4
	OUT	?MODEM+4
	IN	?AUX+5	;RESET ANY STRAY ACTIVITY
	IN	?PRINTER+5
	IN	?MODEM+5
	IN	?AUX
	IN	?PRINTER
	IN	?MODEM
* END OF I/O INITIALIZATION
PAGE



	LXI	H,?CODE ;SEQUENCE TO MOVE MEMORY-MAP
	MVI	B,?CODE$LEN	;NUMBER OF BYTES IN SEQUENCE
	MVI	C,?PORT ;I/O PORT TO SEND SEQUENCE
	DW 0B3EDH ; OUTIR
	JMP	@BIOS
?CODE	DB	0000$01$00B
	DB	0000$11$00B
	DB	0000$01$00B
	DB	0000$10$00B
	DB	0000$11$00B
	DB	0000$10$00B
	DB	0010$00$10B	;WORKS IN Z89-FA
?CODE$LEN	EQU	$-?CODE

***** SPECIAL ROUTINES FOR HARD DISK *****
ISSUE:	PUSH	PSW
ISS	IN	?STAT
	ANI	1
	JRNZ	ISS
	POP	PSW
	OUT	?DATA
	RET

GET:	IN	?STAT
	ANI	1
	JRNZ	GET
	IN	?DATA
	RET

	REPT	256-($-BOOT)-1
	DB	0
	ENDM

	DB	2	;BOOT IDENTIFICATION
PAGE



MODLEN	EQU	$-BOOT	;MUST BE 256 BYTES

 DB 00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B
 DB 00100000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B
 DB 00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B
 DB 00000000B,00000000B,00000000B,00000000B,00010000B,00000000B,00000000B,00000000B
	END