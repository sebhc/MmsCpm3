	TITLE	'ASM SYMBOL TABLE MODULE'
;	SYMBOL TABLE MANIPULATION MODULE
;
	org	0
base	equ	$

	ORG	1340H
IOMOD	EQU	base+200H	;IO MODULE ENTRY POINT
PCON	EQU	IOMOD+12H
EOR	EQU	IOMOD+1EH
;
;
;	ENTRY POINTS TO SYMBOL TABLE MODULE
	JMP	ENDMOD
	JMP	INISY
	JMP	LOOKUP
	JMP	FOUND
	JMP	ENTER
	JMP	SETTY
	JMP	GETTY
	JMP	SETVAL
	JMP	GETVAL
;
;	COMMON EQUATES
PBMAX	EQU	90	;MAX PRINT SIZE
PBUFF	EQU	base+10CH	;PRINT BUFFER
PBP	EQU	PBUFF+PBMAX	;PRINT BUFFER POINTER
;
TOKEN	EQU	PBP+1	;CURRENT TOKEN UDER SCAN
VALUE	EQU	TOKEN+1	;VALUE OF NUMBER IN BINARY
ACCLEN	EQU	VALUE+2	;ACCUMULATOR LENGTH
ACMAX	EQU	64	;MAX ACCUMULATOR LENGTH
ACCUM	EQU	ACCLEN+1
;
EVALUE	EQU	ACCUM+ACMAX	;VALUE FROM EXPRESSION ANALYSIS
;
SYTOP	EQU	EVALUE+2	;CURRENT SYMBOL TOP
SYMAX	EQU	SYTOP+2		;MAX ADDRESS+1
;
PASS	EQU	SYMAX+2	;CURRENT PASS NUMBER
FPC	EQU	PASS+1	;FILL ADDRESS FOR NEXT HEX BYTE
ASPC	EQU	FPC+2	;ASSEMBLER'S PSEUDO PC
SYBAS	EQU	ASPC+2	;BASE OF SYMBOL TABLE
SYADR	EQU	SYBAS+2	;CURRENT SYMBOL BEING ACCESSED
;
;	GLOBAL EQUATES
IDEN	EQU	1	;IDENTIFIER
NUMB	EQU	2	;NUMBER
STRNG	EQU	3	;STRING
SPECL	EQU	4	;SPECIAL CHARACTER
;
PLABT	EQU	0001B	;PROGRAM LABEL
DLABT	EQU	0010B	;DATA LABEL
EQUT	EQU	0100B	;EQUATE
SETT	EQU	0101B	;SET
MACT	EQU	0110B	;MACRO
;
EXTT	EQU	1000B	;EXTERNAL
REFT	EQU	1011B	;REFER
GLBT	EQU	1100B	;GLOBAL
;
;
CR	EQU	0DH
;
;	DATA AREAS
;	SYMBOL TABLE BEGINS AT THE END OF THIS MODULE
FIXD	EQU	5	;5 BYTES OVERHEAD WITH EACH SYMBOL ENTRY
;			2BY COLLISION, 1BY TYPE/LEN, 2BY VALUE
HSIZE	EQU	128	;HASH TABLE SIZE
HMASK	EQU	HSIZE-1	;HASH MASK FOR CODING
HASHT:	DS	HSIZE*2	;HASH TABLE
HASHC:	DS	1	;HASH CODE AFTER CALL ON LOOKUP
;
;	SYMBOL TABLE ENTRY FORMAT IS
;		-----------------
;		: HIGH VAL BYTE	:
;		-----------------
;		: LOW  VAL BYTE	:
;		-----------------
;		: CHARACTER N	:
;		-----------------
;		:    ... 	:
;		-----------------
;		: CHARACTER 1	:
;		-----------------
;		: TYPE  : LENG	:
;		-----------------
;		: HIGH COLLISION:
;		-----------------
;	SYADR=	: LOW COLLISION :
;		-----------------
;
;	WHERE THE LOW/HIGH COLLISION FIELD ADDRESSES ANOTHER ENTRY WITH
;	THE SAME HASH CODE (OR ZERO IF THE END OF CHAIN), TYPE DESCRIBES
;	THE ENTRY TYPE (GIVEN BELOW), LENG IS THE NUMBER OF CHARACTERS IN
;	THE SYMBOL PRINTNAME -1 (I.E., LENG=0 IS A SINGLE CHARACTER PRINT-
;	NAME, WHILE LENG=15 INDICATES A 16 CHARACTER NAME).  CHARACTER 1
;	THROUGH N GIVE THE PRINTNAME CHARACTERS IN ASCII UPPER CASE (ALL
;	LOWER CASE NAMES ARE TRANSLATED ON INPUT), AND THE LOW/HIGH VALUE
;	GIVE THE PARTICULAR ADDRESS OR CONSTANT VALUE ASSOCIATED WITH THE
;	NAME.  THE REPRESENTATION OF MACROS DIFFERS IN THE FIELDS WHICH
;	FOLLOW THE VALUE FIELD (MACROS ARE NOT CURRENTLY IMPLEMENTED).
;
;	THE TYPE FIELD CONSISTS OF FOUR BITS WHICH ARE ASSIGNED AS
;	FOLLOWS:
;
;		0000	UNDEFINED SYMBOL
;		0001	LOCAL	LABELLED PROGRAM
;		0010	LOCAL	LABELLED DATA
;		0011	(UNUSED)
;		0100		EQUATE
;		0101		SET
;		0110		MACRO
;		0111		(UNUSED)
;
;		1000		(UNUSED)
;		1001	EXTERN	LABELLED PROGRAM
;		1010	EXTERN	LABELLED DATA
;		1011		REFERENCE TO MODULE
;		1100		(UNUSED)
;		1101	GLOBAL	UNDEFINED SYMBOL
;		1110	GLOBAL	LABELLED PROGRAM
;		1111		(UNUSED)
;
;	TYPE DEFINITIONS
;
PLABT	EQU	0001B	;PROGRAM LABEL
DLABT	EQU	0010B	;DATA LABEL
EQUT	EQU	0100B	;EQUATE
SETT	EQU	0101B	;SET
MACT	EQU	0110B	;MACRO
;
EXTT	EQU	1000B	;EXTERNAL ATTRIBUTE
REFT	EQU	1011B	;REFER
GLBT	EQU	1100B	;GLOBAL ATTRIBUTE
;
;
INISY:	;INITIALIZE THE SYMBOL TABLE
	LXI	H,HASHT	;ZERO THE HASH TABLE
	MVI	B,HSIZE
	XRA	A	;CLEAR ACCUM
INI0:
	MOV	M,A
	INX	H
	MOV	M,A	;CLEAR DOUBLE WORD
	INX	H
	DCR	B
	JNZ	INI0
;
;	SET SYMBOL TABLE POINTERS
	LXI	H,0
	SHLD	SYADR
;
	RET
;
CHASH:	;COMPUTE HASH CODE FOR CURRENT ACCUMULATOR
	LXI	H,ACCLEN
	MOV	B,M	;GET ACCUM LENGTH
	XRA	A	;CLEAR ACCUMULATOR
CH0:	INX	H	;MOVE TO FIRST/NEXT CHARACTER POSITION
	ADD	M	;ADD WITH OVERFLOW
	DCR	B
	JNZ	CH0
	ANI	HMASK	;MASK BITS FOR MODULO HZISE
	STA	HASHC	;FILL HASHC WITH RESULT
	RET
;
SETLN:	;SET THE LENGTH FIELD OF THE CURRENT SYMBOL
	MOV	B,A	;SAVE LENGTH IN B
	LHLD	SYADR
	INX	H
	INX	H
	MOV	A,M	;GET TYPE/LENGTH FIELD
	ANI	0F0H	;MASK OUT TYPE FIELD
	ORA	B	;MASK IN LENGTH
	MOV	M,A
	RET
;
GETLN:	;GET THE LENGTH FIELD TO REG-A
	LHLD	SYADR
	INX	H
	INX	H
	MOV	A,M
	ANI	0FH
	INR	A	;LENGTH IS STORED AS VALUE - 1
	RET
;
FOUND:	;FOUND RETURNS TRUE IF SYADR IS NOT ZERO (TRUE IS NZ FLAG HERE)
	LHLD	SYADR
	MOV	A,L
	ORA	H
	RET
;
LOOKUP:	;LOOK FOR SYMBOL IN ACCUMULATOR
	CALL	CHASH	;COMPUTE HASH CODE
;	NORMALIZE IDENTIFIER TO 16 CHARACTERS
	LXI	H,ACCLEN
	MOV	A,M
	CPI	17
	JC	LENOK
	MVI	M,16
LENOK:
;	LOOK FOR SYMBOL THROUGH HASH TABLE
	LXI	H,HASHC
	MOV	E,M
	MVI	D,0	;DOUBLE HASH CODE IN D,E
	LXI	H,HASHT	;BASE OF HASH TABLE
	DAD	D
	DAD	D	;HASHT(HASHC)
	MOV	E,M	;LOW ORDER ADDRESS
	INX	H
	MOV	H,M
	MOV	L,E	;HEADER TO LIST OF SYMBOLS IS IN H,L
LOOK0:	SHLD	SYADR
	CALL	FOUND
	RZ		;RETURN IF SYADR BECOMES ZERO
;
;	OTHERWISE EXAMINE CHARACTER STRING FOR MATCH
	CALL	GETLN	;GET LENGTH TO REG-A
	LXI	H,ACCLEN
	CMP	M
	JNZ	LCOMP
;
;	LENGTH MATCH, TRY TO MATCH CHARACTERS
	MOV	B,A	;STRING LENGTH IN B
	INX	H	;HL ADDRESSES ACCUM
	XCHG		;TO D,E
	LHLD	SYADR
	INX	H
	INX	H
	INX	H	;ADDRESSES CHARACTERS
LOOK1:	LDAX	D	;NEXT CHARACTER FROM ACCUM
	CMP	M	;NEXT CHARACTER IN SYMBOL TABLE
	JNZ	LCOMP
;	CHARACTER MATCHED, INCREMENT TO NEXT
	INX	D
	INX	H
	DCR	B
	JNZ	LOOK1
;
;	COMPLETE MATCH AT CURRENT SYMBOL, SYADR IS SET
	RET
;
LCOMP:	;NOT FOUND, MOVE SYADR DOWN ONE COLLISION ADDRESS
	LHLD	SYADR
	MOV	E,M
	INX	H
	MOV	D,M	;COLLISION ADDRESS IN D,E
	XCHG
	JMP	LOOK0
;
;
ENTER:	;ENTER SYMBOL IN ACCUMULATOR
;	ENSURE THERE IS ENOUGH SPACE IN THE TABLE
	LXI	H,ACCLEN
	MOV	E,M
	MVI	D,0	;DOUBLE PRECISION ACCLEN IN D,E
	LHLD	SYTOP
	SHLD	SYADR	;NEXT SYMBOL LOCATION
	DAD	D	;SYTOP+ACCLEN
	LXI	D,FIXD	;FIXED DATA/SYMBOL
	DAD	D	;HL HAS NEXT TABLE LOCATION FOR SYMBOL
	XCHG		;NEW SYTOP IN D,E
	LHLD	SYMAX	;MAXIMUM SYMTOP VALUE
	MOV	A,E
	SUB	L	;COMPUTE 16-BIT DIFFERENCE
	MOV	A,D
	SBB	H
	XCHG		;NEW SYTOP IN H,L
	JNC	OVERER	;OVERFLOW IN TABLE
;
;	OTHERWISE NO ERROR
	SHLD	SYTOP	;SET NEW TABLE TOP
	LHLD	SYADR	;SET COLLISION FIELD
	XCHG		;CURRENT SYMBOL ADDRESS TO D,E
	LXI	H,HASHC	;HASH CODE FOR CURRENT SYMBOL TO H,L
	MOV	C,M	;LOW BYTE
	MVI	B,0	;DOUBLE PRECISION VALUE IN B,C
	LXI	H,HASHT	;BASE OF HASH TABLE
	DAD	B
	DAD	B	;HASHT(HASHC) IN H,L
;	D,E ADDRESSES CURRENT SYMBOL - CHANGE LINKS
	MOV	C,M	;LOW ORDER OLD HEADER
	INX	H
	MOV	B,M	;HIGH ORDER OLD HEADER
	MOV	M,D	;HIGH ORDER NEW HEADER TO HASH TABLE
	DCX	H
	MOV	M,E	;LOW ORDER NEW HEADER TO HASH TABLE
	XCHG		;H,L HOLDS SYMBOL TABLE ADDRESS
	MOV	M,C	;LOW ORDER OLD HEADER TO COLLISION FIELD
	INX	H
	MOV	M,B	;HIGH ORDER OLD HEADER TO COLLISION FIELD
;
;	HASH CHAIN NOW REPAIRED FOR THIS ENTRY, COPY THE PRINTNAME
	LXI	D,ACCLEN
	LDAX	D	;GET SYMBOL LENGTH
	CPI	17	;LARGER THAN 16 SYMBOLS?
	JC	ENT1
	MVI	A,16	;TRUNCATE TO 16 CHARACTERS
;	COPY LENGTH FIELD, FOLLOWED BY PRINTNAME CHARACTERS
ENT1:	MOV	B,A	;COPY LENGTH TO B
	DCR	A	;1-16 CHANGED TO 0-15
	INX	H	;FOLLOWING COLLISION FIELD
	MOV	M,A	;STORE LENGTH WITH UNDEFINED TYPE (0000)
ENT2:	INX	H
	INX	D
	LDAX	D
	MOV	M,A	;STORE NEXT CHARACTER OF PRINTNAME
	DCR	B	;LENGTH=LENGTH-1
	JNZ	ENT2	;FOR ANOTHER CHARACTER
;
;	PRINTNAME COPIED, ZERO THE VALUE FIELD
	XRA	A	;ZERO A
	INX	H	;LOW ORDER VALUE
	MOV	M,A
	INX	H
	MOV	M,A	;HIGH ORDER VALUE
	RET
;
OVERER:	;OVERFLOW IN SYMBOL TABLE
	LXI	H,ERRO
	CALL	PCON
	JMP	EOR	;END OF EXECUTION
ERRO:	DB	'SYMBOL TABLE OVERFLOW',CR
;
SETTY:	;SET CURRENT SYMBOL TYPE TO VALUE IN REG-A
	RAL
	RAL
	RAL
	RAL
	ANI	0F0H	;TYPE MOVED TO HIGH ORDER 4-BITS
	MOV	B,A	;SAVE IT IN B
	LHLD	SYADR	;BASE OF SYMBOL TO ACCESS
	INX	H
	INX	H	;ADDRESS OF TYPE/LENGTH FIELD
	MOV	A,M	;GET IT AND MASK
	ANI	0FH	;LEAVE LENGTH
	ORA	B	;MASK IN TYPE
	MOV	M,A	;STORE IT
	RET
;
GETTY:	;RETURN THE TYPE OF THE VALUE IN CURRENT SYMBOL
	LHLD	SYADR
	INX	H
	INX	H
	MOV	A,M
	RAR
	RAR
	RAR
	RAR
	ANI	0FH	;TYPE MOVED TO LOW 4-BITS OF REG-A
	RET
;
VALADR:	;GET VALUE FIELD ADDRESS FOR CURRENT SYMBOL
	CALL	GETLN	;PRINTNAME LENGTH TO ACCUM
	LHLD	SYADR	;BASE ADDRESS
	MOV	E,A
	MVI	D,0
	DAD	D	;BASE(LEN)
	INX	H
	INX	H	;FOR COLLISION FIELD
	INX	H	;FOR TYPE/LEN FIELD
	RET		;WITH H,L ADDRESSING VALUE FIELD
;
SETVAL:	;SET THE VALUE FIELD OF THE CURRENT SYMBOL
;	VALUE IS SENT IN H,L
	PUSH	H	;SAVE VALUE TO SET
	CALL	VALADR
	POP	D	;POP VALUE TO SET, HL HAS ADDRESS TO FILL
	MOV	M,E
	INX	H
	MOV	M,D	;FIELD SET
	RET
;
GETVAL:	;GET THE VALUE FIELD OF THE CURRENT SYMBOL TO H,L
	CALL	VALADR	;ADDRESS OF VALUE FIELD TO H,L
	MOV	E,M
	INX	H
	MOV	D,M
	XCHG
	RET
;
ENDMOD	EQU	($ AND 0FFE0H) + 20H
	END
