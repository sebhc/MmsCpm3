/*TRACE ROUTINE FOR C/80.  TO USE, ASSEMBLE THIS FILE		(1/16/84)
  TO A:CPROF.ASM, AND COMPILE AND ASSEMBLE THE C
  PROGRAM WITH THE -P COMPILER OPTION.
  FOR MACRO-80 COMPATIBILITY, ASSEMBLE AND LINK THIS.  */
CALL_() {
#asm
	POP H		;GET CALLING ADDRESS
	INX H		;COMPUTE REAL RETURN ADDRESS
	INX H
	INX H
	INX H
	PUSH H		;AND REPLACE IT
	PUSH B
	PUSH D
	DCX H
	DCX H
	DCX H
	MOV D,M 	;GET ROUTINE CALLED
	DCX H
	MOV E,M
	PUSH D		;SAVE CALLED ROUTINE.
	XCHG		;CHECK FOR 6 BLANK BYTES
	MVI B,6
	XRA A
CALL6:	DCX H		;(IF NOT, IT IS A
	CMP M		;SYSTEM RTN WITH NO
	JNZ CALL7	;NAME.)
	DCR B
	JNZ CALL6
CALL1:	DCX H		;BACK UP OVER NAME.
	CMP M
	JZ CALL2
	INR B
	JMP CALL1
CALL2:	INX H
	MOV A,B
	ORA A
	JZ CALL7
	CPI 8
	JNC CALL7
	PUSH H		;SAVE NAME ADDR
	LXI H,CALL3
	CALL CALL@O	;OUTPUT 'CALLING'
	POP H
	CALL CALL@O
	LXI H,CALL4
	CALL CALL@O
CALL7:	POP H		;RESTORE CALLED ROUTINE ADDRESS
	POP D		;RESTORE BC & DE PAIRS
	POP B
	PCHL		;GO TO CALLED ROUTINE
	
CALL3:	DB 'Calling ',0
CALL4:	DB 12Q,0
CALL5:	DB ' returns BCDE,HL = ',0
CALL@O: MOV A,M 	;OUTPUT BYTES
	ORA A		;UNTIL
	RZ		;A ZERO BYTE
	MOV E,A
	MVI D,0
	PUSH H
	PUSH D
	CALL putchar
	POP D
	POP H
	INX H
	JMP CALL@O
#endasm
}

RET_() {
#asm
	XTHL		;SAVE RETURN VALUE
	PUSH D		;SAVE FLOATING REG IF USED (DE FIRST)
	PUSH B
	MOV E,M 	;GET ADDRESS OF
	INX H		;ROUTINE RETURNING.
	MOV D,M
	LXI H,-6	;GET NAME
	DAD D
	XRA A		;BACK OVER NAME
RET1:	DCX H
	CMP M
	JNZ RET1
	INX H
	CALL CALL@O	;OUTPUT IT
	LXI H,CALL5
	CALL CALL@O
	POP H		;OUTPUT BC
	PUSH H
	CALL O@HEX
	POP B		;OUTPUT DE
	POP H
	PUSH H
	PUSH B
	CALL O@HEX
	LXI H,2CH	;OUTPUT SEPARATOR
	PUSH H
	CALL putchar
	POP H
	POP B
	POP D
	POP H		;OUTPUT HL
	PUSH H
	PUSH D
	PUSH B
	CALL O@HEX
	LXI H,CALL4
	CALL CALL@O
	POP B
	POP D
	POP H		;RESTORE VALUE
	RET		;REALLY RETURN

O@HEX:	MVI B,4 	;OUTPUT 4 HEX DIGITS FROM HL
O@H1:	MOV A,H 	;OUTPUT FROM HIGH NYBBLE OF HL
	RAR
	RAR
	RAR
	RAR
	ANI 17Q 	;CONVERT TO HEX
	ADI 220Q
	DAA
	ACI 100Q
	DAA
	MOV C,A
	PUSH H
	PUSH B
	CALL putchar	;OUTPUT IT
	POP B
	POP H
	DAD H		;SHIFT HL LEFT 4
	DAD H
	DAD H
	DAD H
	DCR B
	JNZ O@H1
	RET
#endasm
	putchar();	/* To declare external */
}
