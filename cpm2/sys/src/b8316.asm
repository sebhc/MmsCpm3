********** CP/M LINKABLE BOOT ROUTINE **********
********** 8" MMS CONTROLLER BOOT     **********
	DW	MODLEN,(-1)

BASE	EQU	0000H	;ORG FOR RELOC
	MACLIB Z80

SPT	EQU	16	;16 (512 BYTE) SECTORS ON 8"DD
***** PHYSICAL DRIVES ARE ASSIGNED AS FOLLOWS *****
*****                                         *****
*****  29 = FIRST 8" DRIVE                    *****
*****  30 = SECOND 8" DRIVE                   *****
*****  31 = THIRD 8" DRIVE                    *****
*****  32 = FOURTH 8" DRIVE                   *****
*****                                         *****
***************************************************

***************************************************
**  PORTS AND CONSTANTS
***************************************************
CTRL	EQU	38H
WD1797	EQU	3CH
STAT	EQU	WD1797+0
TRACK	EQU	WD1797+1
SECTOR	EQU	WD1797+2
DATA	EQU	WD1797+3

?PORT	EQU	0F2H

?AUX	EQU	0D0H
?PRINTER	EQU	0E0H
?MODEM	EQU	0D8H

?LINE$CTL	EQU	00000011B	;NO PARITY, 1 STOP BIT, 8 DATA BITS
?MOD$CTL	EQU	00001111B	;SET ALL CONTROL LINES TO 'READY'

?S19200	EQU	6	; 19,200 BAUD
?S9600	EQU	12	;  9,600 BAUD
?S4800	EQU	24	;  4,800 BAUD
?S2400	EQU	48	;  2,400 BAUD
?S1200	EQU	96	;  1,200 BAUD
?S600	EQU	192	;    600 BAUD
?S300	EQU	384	;    300 BAUD
?S150	EQU	768	;    150 BAUD
?S110	EQU	1047	;    110 BAUD
***************************************************

***************************************************
** LINKS TO REST OF SYSTEM
***************************************************
@BIOS	EQU	BASE+1600H
@BDOS	EQU	@BIOS-0E00H
***************************************************

***************************************************
** PAGE ZERO ASSIGNMENTS
***************************************************
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

***************************************************
** START OF RELOCATABLE DISK BOOT MODULE
*************************************************** 
	ORG	2280H
BOOT:
	JMP	AROUND
SECTRS	DB	0	;NUMBER OF SECTORS TO BOOT, FROM MOVCPM.COM
			;PATCHED DURING EXECUTION OF MOVCPM
DRIVE	DB	29	;ALSO PATCHED BY ASSIGN PROGRAM
AROUND:
	POP	H	;ADDRESS OF ERROR ROUTINE
	LXI	SP,?STACK
	PUSH	H

***************************************************
*** START OF UNIQUE ROUTINE FOR BOOTING
***************************************************
	LXI	H,@BDOS-256	;BIAS FOR BOOT SECTORS THAT
	LDA	SECTRS	;WILL BE RE-LOADED TO MAKE EFFICIENT BOOTING
	INR	A	;ADD IN BOOT-SECTORS
	INR	A	;BECAUSE THEY WILL ALSO BE LOADED
	ADI	00000011B	;ROUND UP
	ANI	11111100B	;INTEGER DIVISION
	RRC
	RRC	;  BY 4
	MOV	E,A
	LDA	DRIVE
	SUI	29
	RC
	CPI	4	;ONLY 4 DRIVES IN THIS GROUPE
	RNC
	ORI	00101000B	;BURST OFF,EI
	STA	DRIVE
	OUT	CTRL
	MVI	A,00001011B	;RESTORE COMMAND
LOOP0	CALL	COMMAND
	IN	STAT
	ANI	10011001B
	RNZ
	MVI	A,10	;NUMBER OF RETRYS
	STA	RETRY
	MVI	D,1
	LXI	B,(0)*256+(DATA)
SECL0	PUSH	H	;SAVE DMA ADDRESS IN CASE OF RETRY
	LDA	DRIVE
	ANI	11011111B	;BURST ON
	OUT	CTRL
	MOV	A,D
	OUT	SECTOR
	MVI	A,10001000B	;READ SINGLE SECTOR
	CALL	READ$REC
	ANI	10111111B
	LDA	DRIVE
	OUT	CTRL
	JRZ	OK
	POP	H
	LDA	RETRY
	DCR	A
	STA	RETRY
	JRNZ	SECL0
	RET
OK:	XTHL
	POP	H
	DCR	E
	JRZ	DONE
	INR	D
	MOV	A,D
	CPI	SPT+1
	JRC	SECL0
	IN	TRACK
	INR	A
	OUT	DATA
	MVI	A,00011011B	;SEEK
	JR	LOOP0
DONE:
***************************************************
** START OF SYSTEM INITIALIZATION
*************************************************** 
	DI
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
	LXI	H,?S300	;MODEM (PAPER TAPE) @ 300 BAUD
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
	LXI	H,?CODE	;SEQUENCE TO MOVE MEMORY-MAP
	MVI	B,?CODE$LEN	;NUMBER OF BYTES IN SEQUENCE
	MVI	C,?PORT	;I/O PORT TO SEND SEQUENCE
	OUTIR
	JMP	@BIOS
?CODE	DB	0000$01$00B
	DB	0000$11$00B
	DB	0000$01$00B
	DB	0000$10$00B
	DB	0000$11$00B
	DB	0000$10$00B
	DB	0010$00$10B	;FOR "-FA" MACHINES
?CODE$LEN	EQU	$-?CODE

COMMAND:
	OUT	STAT
	EI
	JR $-1

READ$REC:
	OUT	STAT
	EI
	HLT
RD0	INI
	JNZ	RD0
RD1	INI
	JNZ	RD1
	JR $-1

	REPT	256-($-BOOT)-1
	DB	0
	ENDM

RETRY:		;LOCATION HAS DUAL-FUNCTION
ID	DB	6	;BOOT ROUTINE IDENTIFICATION
MODLEN	EQU	$-BOOT	;MUST BE 256 BYTES
?STACK:	EQU	$+128

 DB 00000000B,00001000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B
 DB 00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B
 DB 00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B
 DB 00000000B,01000000B,00000000B,00000000B,00000000B,00000000B,00000000B,00000000B
	END