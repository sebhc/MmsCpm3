	TITLE	'SBA MAGIC WAND -- TERMINAL HEATH H19'
***********************************************
**	       T E R M I N A L		     **
***********************************************
*		 Zenith z19 VERSION

*	DEVELOPED BY SMALL BUSINESS APPLICATIONS INC
*		     3220 LOUISIANA, SUITE 205
*		     HOUSTON, TEXAS  77006
*		     (713)528-5158
*
*	LAST REVISION 6/5/81 by Magnolia Microsystems
*	for Peachtree Magic Wand as of above date.
*
BASE	EQU	0	;STANDARD CP/M BASE

	ORG	BASE+108H
	JMP	0
	JMP	0
	DB	128

	ORG	BASE+200H  ;TERMINAL MODULE ORIGIN
*
ROWSX	EQU	24	;DISPLAY ROWS
COLSX	EQU	80	;DISPLAY COLUMNS
TERMDIM DB	ROWSX,COLSX	;PHYSICAL TERMINAL LIMITS
SCRDIM	EQU	$		;CURRENT SCREEN LIMITS
ROWS	DB	ROWSX-1
COLS	DB	COLSX
CURSOR	EQU	$	;CURRENT CURSOR LOCATION
ROW	DB	1
COL	DB	1
CONOUT	DB	0,0,0	;CONOUT ADDR TO BE SUPPLIED AT INITIALIZATION
ZPRSEQ	JMP	PRSEQ	;OUTPUT CHAR SEQUENCE AT DE UNTIL NULL
ZCURSE	JMP	CURSE	;POSITION CURSOR AT HL
ZCLRSCR JMP	CLRSCRN ;CLEAR WHOLE SCREEN
ZCLRLN	JMP	CLRLINE ;CLEAR REMAINING LINE
ZSCROLL JMP	SCROLL	;SCROLL 1 LINE UP
ZBKSP	JMP	BKSP	;BACKSPACE 1 FROM CURRENT COLUMN
ZALARM	JMP	ALARM	;SOUND ALARM BELL, IF ANY
ZINIT	JMP	INITSCRN ;INITIALIZE TERMINAL, IF NEEDED
ZNAME	DB	'H19/z19         '
ZID	DB	'HX'	;TERMINAL ID NUMBER FOR SERIAL
*
*********CONTROL TABLES
*
CTAB	DB	8,16,24,32,40,48,56,64,72,COLSX,0,0,0,0,0,0
	DB	255	;TAB TABLE STOP BYTE
*
*	HIGH-ORDER BIT (128+) ON INDICATES ESCAPE SEQUENCE
*
XTAB	EQU	$	;TABLE OF CONTROL CHARACTERS
XRET	DB	RETC	;CARRIAGE RETURN
XCURR	DB	128+'C' ;*****	CURSOR RIGHT
XCURU	DB	128+'A' ;*****	CURSOR UP
XCURD	DB	128+'B' ;*****	CURSOR DOWN   
XDELTL	DB	128+'M' ;*DL*	LINE DELETE
XFSCRL	DB	128+'T' ;'F2'	LINE SCROLL FORWARD
XBSCRL	DB	128+'S' ;'F1'	LINE SCROLL BACKWARD
XPFSCRL DB	128+'V' ;'F4'	PAGE FORWARD
XPBSCRL DB	128+'U' ;'F3'	PAGE BACKWARD
XHOME	DB	128+'H' ;*HOME*	HOME LINE, SCREEN
XSCRTOP DB	20	;Ctl-T	TOP OF TEXT
XSCRBOT DB	2	;Ctl-B	BOTTOM OF TEXT
XTABC	DB	TABKEY	;CTL-I (TAB KEY)
XISRT	DB	128+'@' ;*IC*	CHARACTER INSERT
XISRTP	DB	128+'L' ;*IL*	FULL INSERT (OPEN/CLOSE TEXT)
XISRTX	DB	127	;*DELETE* WORD DELETE
XESC	DB	ESC	;ESCAPE KEY
XDUPE	DB	128+'Q' ;'Red'	REPEAT SEARCH/REPLACE
XFIND	DB	128+'P' ;'Blue' START SEARCH/REPLACE
XSETMK	DB	128+'R' ;'Gray' SET BLOCK MARKER
XFORM	DB	128+'W' ;'f5'	SET FORM FEED
XLNFD	DB	10	;LINE	SET LINE FEED
XBKSP	DB	8	;BACKSPACE
XDELTC	DB	128+'N'	;*DC*  CHARACTER DELETE
XCURL	DB	128+'D' ;*****	CURSOR LEFT
XEND	DB	ESC	;END TABLE /CURRENT CHAR
	PAGE
*	TABLE OF CONTROL CODE/DISPLAY SUBSTITUTIONS
SUBCTLS EQU	$	;TRANSLATES VALUES 0-1F
	DB	0,'_',0,0,0,0,0,BELL,0,0
	DB	'|'	;LINE FEED
	DB	0
	DB	'^'	;FORM FEED
XDCR	DB	'~'	;CARRIAGE RETURN
	DB	0,0,0
	DB	':'	;FIND-KEY
	DB	0,0,0,0,0,0,0,0,0,0,0,0,0
*
BLKMARK EQU	1	;BLOCK MARKER
RETC	EQU	13	;LINE-END CTL CHAR
LNFD	EQU	10	;LINE FEED
FFORM	EQU	12	;FORM FEED
TABKEY	EQU	9	;TAB KEY (CONTROL-I)
BELL	EQU	7	;BELL CODE
ESC	EQU	27	;ESCAPE KEY
DELKEY	EQU	127	;DELETE KEY
DEFIND	EQU	7	;KEY TO DEFINE SEARCH/REPLACE
	PAGE
********	HEATH SCREEN CONTROL ROUTINES
**
LEADIN	EQU	27	;CONTROL SEQUENCE FLAG CODE
CURSXY	EQU	1F1FH	;CONSTANT TO ADJUST CURSOR CODES
SETCCOD EQU	'Y'	;SET CURSOR LOC CODE
XCLEAR	EQU	'E'	;SCREEN CLEAR CODE
LCLEAR	EQU	'K'	;LINE CLEAR CODE
INTSEQ	DB	LEADIN,'x4' ;SET BLOCK-CURSOR
	DB	LEADIN,'t'  ;SET KEYPAD shifted MODE
	DB	LEADIN,'v'	;SELECT WRAP-AROUND MODE FOR INCLUDE
	DB	0	;SEQUENCE TERMINATOR
EXITSEQ DB	LEADIN,'z'  ;return terminal to switches-configuration
	DB	0
CLRSEQ	DB	LEADIN	;SEQUENCE TO CLEAR SCREEN
	DB	XCLEAR
	DB	0
LNSEQ	DB	LEADIN	;SEQUENCE TO CLEAR LINE
	DB	LCLEAR
	DB	0
SETSEQ	DB	LEADIN	;SEQUENCE TO SET CURSOR LOCATION
	DB	SETCCOD
SETC	DW	0	;CURSOR COORDINATES (COL,ROW)
	DB	0
SCROLSQ DB	LEADIN	;SEQUENCE TO SCROLL FWD 1 LINE
	DB	SETCCOD ;FIRST SET CURSOR
	DB	55,32	;TO ROW 24 COL 1
	DB	LNFD	;THEN ISSUE LINE FEED
	DB	LEADIN	;THEN RESET
	DB	SETCCOD ;CURSOR
	DB	54,32	;TO LAST WINDOW ROW
	DB	LEADIN	;AND
	DB	LCLEAR	;CLEAR IT
	DB	0
*
CURSE	EQU	$	;SET CURSOR CORRDINATES IN HL
	LXI	D,CURSXY	;APPLY ADJUSTMENT TO CODES
	DAD	D	;TO MATCH HARDWARE (POS+20H BASED 0)
	SHLD	SETC	;STORE IN SEQUENCE
	LXI	D,SETSEQ ;USE CPM BUFFER PRINT
	CALL	PRSEQ
	RET
*
SCROLL	LXI	D,SCROLSQ	;INITIATE LINE SCROLL SEQUENCE
	JMP	PRSEQ
*
CLRLINE LXI	D,LNSEQ ;CLEAR LINE
	JMP	PRSEQ
*
BKSP	MVI	C,BKSPCODE
	CALL	CONOUT
	RET
BKSPCODE EQU	8
*
CLRSCRN LXI	H,0101H ;CLEAR WHOLE SCREEN
	CALL	CURSE	;FORCE CURSOR HOME
	LXI	D,CLRSEQ ;CLEAR SCREEN
	JMP	PRSEQ
*
ALARM	MVI	C,BELL	  ;SOUND ALARM BELL
	CALL	CONOUT
	RET
*
PRSEQ	LDAX	D	;PRINT SEQ AT DE UNTIL ZERO
	ANA	A
	RZ
	PUSH	D
	MOV	C,A
	CALL	CONOUT
	POP	D
	INX	D
	JMP	PRSEQ

INITSCRN EQU	$	;INIT/DE-INIT ENVIRONMENT
	LXI	D,EXITSEQ
	LXI	H,INITSW
	MOV	A,M
	MVI	M,-1
	ANA	A
	JNZ	EXIT
	LHLD	ORGCONST
	SHLD	CONST
	LXI	H,TCONST
	SHLD	ORGCONST
	LHLD	ORGCONIN
	SHLD	CONIN
	LXI	H,TCONIN
	SHLD	ORGCONIN
	LHLD	6
	LXI	D,-6
	DAD	D
	MOV	A,M
	CPI	175
	JNZ	NOINIT
	INX	H
	MOV	A,M
	CPI	22
	JNZ	NOINIT
	LHLD	1
	LXI	D,5
	DAD	D
	MOV	H,M
	MVI	L,0
	LXI	D,01FEH
	DAD	D
	MOV	E,M
	INX	H
	MOV	D,M
	XRA	A
	STAX	D
	MVI	A,(RET)
	STA	PAT1	;DON'T NEED REST OF ROUTINE
NOINIT:
	LXI	D,INTSEQ
EXIT	CALL	PRSEQ
	RET

INITSW	DB	0	;FIRST-TIME SWITCH

ORGCONST EQU	BASE+109H ;MW CONST ADDR FROM CBIOS
CONST	DW	0	;ADDRESS FOR CBIOS CHAR STATUS

ORGCONIN EQU	BASE+10CH ;MW CONIN ADDR FROM CBIOS
CONIN	DW	0	;ADDR FOR CBIOS CHAR INPUT

HLCALL	PCHL		;ROUTINE PROVIDING INDIRECT CALLS

TCONST	LHLD	CONST
	CALL	HLCALL
	RET

TCONIN	LHLD	CONIN
	CALL	HLCALL
	CPI	ESC
PAT1	RNZ		;DIRECT RETURN ANY NON-ESCAPE SEQUENCE
	MVI	A,250	;WAIT FOR 1.7 MILLISECONDS
DLY	DCR	A
	JNZ	DLY
	CALL	TCONST
	ORA	A
	MVI	A,ESC
	RZ		;RETURN IT UNMODIFIED
	LHLD	CONIN
	CALL	HLCALL
	ORI	10000000B	;ELSE RETURN IT WITH HIGH-BIT SET
	RET

	END