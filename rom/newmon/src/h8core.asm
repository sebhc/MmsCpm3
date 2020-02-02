; H8 Z80-CPU v3.2 Monitor (EEPROM 28C256)
VERN	equ	020h	; ROM version

false	equ	0
true	equ	not false

alpha	equ	true
beta	equ	false

	maclib	ram
	maclib	z80
	$*macro

CR	equ	13
LF	equ	10
BEL	equ	7
TAB	equ	9
ESC	equ	27
TRM	equ	0
DEL	equ	127

memtest	equ	03000h
ramboot	equ	0c000h
; fudge this... H17 junk
R$CONST	equ	01f5ah	; 037.132 R.CONST block...
CLOCK	equ	01c19h	; 034.031 CLOCK

btovl	equ	1000h		; boot module overlay area (RAM)
btbase	equ	btovl+2		; base phy drv num
btinit	equ	btovl+4		; init entry point
btboot	equ	btovl+7		; boot entry point
btchr	equ	btovl+10	; device letter
btkey	equ	btovl+11	; device key
btport	equ	btovl+12	; device port, 0 if variable
btdisp	equ	btovl+13	; boot front panel mnemonic
btname	equ	btovl+16	; boot string

btmods	equ	2000h	; boot modules start in ROM
bterom	equ	8000h	; end/size of ROM

rptcnt	equ	16
debounce equ	1

; Start of ROM code
	org	00000h

rombeg:
rst0:	nop	; can't be JMP or Heath CP/M thinks we're an H89
	jmp	init

	db	0,0,0,0

rst1:	call	intsetup
	lhld	ticcnt
	jmp	int1$cont
if ((high int1$cont) <> 0)
	.error 'Overlapped NOP error'
endif

rst2	equ	$-1	; must be a nop...
	call	intsetup
	ldax	d
	jmp	int2$cont

rst3:	jmp	vrst3

	db	0,0,0,0,0

rst4:	jmp	vrst4

	db	0,0,0	; overlayed by WizNet boot, others
	dw	conout	; pointer, not vector; A=char

rst5:	jmp	vrst5
delayx:
	jmp	delay

qmsg:	db	'?',TRM

rst6:	jmp	vrst6

	db	0,0,0,0,0	; overlayed by WizNet boot, others

rst7:	jmp	vrst7

; routines made public (to modules)
	jmp	hwboot
	jmp	hxboot
	jmp	take$A

; TODO: restore Z80 registers...
intret:
	pop	psw
	pop	psw
	pop	b
	pop	d
	pop	h
nulint:
	ei
	ret

int1$cont:
	inx	h
	shld	ticcnt
	lda	ctl$F2
	out	0f2h
	jmp	int1$fp

; TODO: save Z80 registers...
intsetup:
	xthl
	push	d
	push	b
	push	psw
	xchg
	lxi	h,10
	dad	sp
	push	h
	push	d
	lxi	d,ctl$F0
	ldax	d
	cma
	ani	030h
	rz
	lxi	h,2
	dad	sp
	shld	monstk
	ret

re$entry:		; re-entry point for errors, etc.
	lxi	h,ctl$F0
	mvi	m,0f0h	; !beep, 2mS, MON, !SI
	lhld	monstk
	sphl
	call	belout	; TODO: beep front panel if appropriate
	;jmp	start
start:
	ei
	lxi	h,start
	push	h
	; reset FP display... this doesn't make a lot of sense...
	lda	DspMod
	ani	00000001b
	cma
	sta	DsProt
	;
	lxi	h,prompt
	call	msgout
prloop:
	; could take one of two paths here,
	; console or kaypad...
	call	cmdin
	ani	11011111b ; toupper
	jp	cmchr	; from console...
	; keypad pressed...
	cpi	8ah	; non-digit (hex req first be '0')
	jrnc	cmchr
	mov	b,a
	lda	DspMod
	rrc	; CY=alter mode
	jc	kpalter	; alter mode - numeric values only
	mov	a,b
cmchr:	lxi	h,cmdtab
	mvi	b,numcmd
cmloop:
	cmp	m
	inx	h
	jrz	docmd
	inx	h
	inx	h
	djnz	cmloop
	call	belout
	jr	prloop

docmd:
	ora	a
	cp	conout
	mov	c,m
	inx	h
	mov	h,m
	mov	l,c
icall:	pchl

cmdtab:
	db	'G'
	dw	cmdgo
	db	'S'
	dw	cmdsub
	db	'P'
	dw	cmdpc
	db	'B'
	dw	cmdboot
	db	'M'
	dw	cmdmt
	db	'T'
	dw	termod
	db	'V'
	dw	prtver
	db	'L'	; list boot modules
	dw	cmdlb
	db	'H'	; long list (help) boot modules
	dw	cmdhb
	db	'A'	; add boot module
	dw	cmdab
	db	'U'	; update entire ROM
	dw	cmdur
	; front-panel commands
	db	80h	; [0]
	dw	kpubt	; Universal Boot
	db	81h	; [1]
	dw	kpdbg
	db	82h	; [2]
	dw	kpdbg
	db	83h	; [3]
	dw	kpdbg
	db	84h	; [4]
	dw	kpdbg
	db	85h	; [5]
	dw	kpdbg
	db	86h	; [6]
	dw	kpdbg
	db	87h	; [7]
	dw	kpdbg
	db	88h	; [8]
	dw	kpdbg
	db	89h	; [9]
	dw	kpdbg
	db	8ah	; [A] [+]
	dw	kpdbg
	db	8bh	; [B] [-]
	dw	kpdbg
	db	8ch	; [C] [*]
	dw	kpdbg
	db	8dh	; [D] [/]
	dw	kpdbg
	db	8eh	; [E] [#]
	dw	kpdbg
	db	8fh	; [F] [.]
	dw	kpdbg
numcmd	equ	($-cmdtab)/3

	rept	0137h-$
	db	0ffh
	endm
if	($ <> 0137h)
	.error 'HDOS entry overrun 0137h'
endif
	jmp	0	; initialized by H47 boot module

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; PC command (set PC)
cmdpc:
	lxi	h,pcms
	call	msgout
	lxi	h,12
	dad	sp
	mov	e,m
	inx	h
	mov	d,m
	xchg
	call	inhexcr
	jrc	cmdpc0
	call	adrnl
	call	inhexcr
	rnc
cmdpc0:
	xchg
cmdpc1:
	mvi	d,CR
	jmp	adrin
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Go command
cmdgo:
	lxi	h,goms
	call	msgout
	lxi	h,13
	dad	sp
	call	inhexcr
	cc	cmdpc1	; read HEX until CR
	call	crlf
	mvi	a,0d0h	; no-beep, 2mS, !MON, !single-step
	jr	cmdgo0
	di
	lda	ctl$F0
	xri	010h	; toggle single-step
	out	0f0h
cmdgo0:
	sta	ctl$F0
	pop	h
	jmp	intret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

int2$cont:
	ori	010h	; disable single-step
	out	0f0h
	stax	d
	ani	020h	; MON active?
	jnz	start	; break to monitor code
	jmp	vrst2	; else chain to (possible) user code.

take$5:
	mvi	a,5	; 5 seconds
take$A:	; set a timeout for A seconds
	lxi	h,timeout
	shld	vrst1+1
	sta	SEC$CNT
	mvi	a,1
	sta	MFlag
	ei
	ret

timeout:
	lxi	h,ticcnt
	xra	a
	ora	m
	rnz
	inx	h
	mov	a,m
	rrc
	rc
	; every 512 ticks... 1024mS
	lxi	h,SEC$CNT
	dcr	m
	rnz
error:
	lhld	monstk
	sphl
	lxi	h,qmsg
	call	msgout
	lxi	h,nulint
	shld	vrst1+1
	sta	MFlag
	in	0f2h
	ani	00000011b
	jrnz	error0
	out	07fh
error0:
	jmp	re$entry

; determine device for port 078H
; return phy drv number in D.
gtdev1:
	mvi	d,0	; Z17
	in	0f2h
gtdev0:
	ani	00000011b	; port 078H device
	rz		; Z17 (or Z37)
	cpi	01b
	mvi	d,5
	rz		; Z47
	cpi	10b
	mvi	d,3	; Z67/MMS77320
	rz
	mvi	d,0ffh
	ret	; NZ

; determine device for port 078H
; return phy drv number in D.
gtdev2:
	mvi	d,46	; Z37
	in	0f2h
	rrc
	rrc
	jr	gtdev0	; rest are same

; determine default boot device.
gtdfbt:
	lxi	d,0
	in	0f2h
	ani	01110000b	; default boot selection
	cpi	00100000b	; device at 07CH
	jrz	gtdev1
	cpi	00110000b	; device at 078H
	jrz	gtdev2
	jmp	gtdvtb		; get MMS device

; Check SW501 for installed device.
; C = desired port pattern, 00=Z17/Z37, 01=Z47, 10=Z67, 11=undefined
; returns base I/O port adr in B.
getport:
	mvi	b,07ch
	in	0f2h
	ani	003h
	cmp	c
	rz
	mvi	b,078h
	in	0f2h
	rrc
	rrc
	ani	003h
	cmp	c
	rz
	pop	h	; discard return address
s501er:
	lxi	h,s501ms
	jmp	msgout

s501ms:	db	'SW1 wrong',TRM

inport0:
	ora	a	; NC
; input from cport+CY
inportx:
	push	b
	lda	cport
	aci	0
	mov	c,a
	inp	a
	pop	b
	ret

delay:
	push	h
	lxi	h,ticcnt
	add	m
delay0:
	cmp	m
	jrnz	delay0
	pop	h
	ret

digerr:
	call	belout
	jr	btdig0
; Got a digit in boot command, parse it
btdig:	; boot by phys drive number, E=0
	call	conout	; echo digit
	ani	00fh	; convert to binary
	mov	d,a
btdig0:
	call	conin	; get another, until term char (C)
	cmp	c
	jrz	gotnum
	cpi	'0'
	jrc	digerr
	cpi	'9'+1
	jrnc	digerr
	call	conout
	ani	00fh
	mvi	b,10	; add 10 times, i.e. D = (D * 10) + A
btdig1:
	add	d
	jc	error
	djnz	btdig1
	mov	d,a
	cpi	200
	jnc	error
	jr	btdig0

gotnum:	; Boot N... "N" in D
	mov	a,d
	cpi	5
	jc	goboot
	cpi	9
	jnc	goboot
	adi	200	; modify 5..8 to not conflict
	mov	d,a
	jmp	goboot

cmdboot:
	lxi	h,bootms
	call	msgout	; complete (B)oot
	mvi	a,0c3h
	sta	bootbf	; mark "no string"
	lxi	sp,bootbf
	call	gtdfbt
	mvi	c,CR	; end input on CR
	jr	boot0
bterr:
	call	belout
boot0:
	call	conin
	cmp	c
	jz	goboot
	mvi	e,0
	cpi	'0'
	jrc	nodig
	cpi	'9'+1
	jrc	btdig
nodig:	; boot by letter... Boot alpha-
	ani	05fh ; toupper
	cpi	'Z'+1
	jrnc	bterr
	cpi	'A'
	jrc	bterr
	call	conout
	call	conout
	cpi	'B'
	jrnc	gotit1
	; 'A' is synonym for default
	mov	a,d
	cpi	0ffh
	jz	s501er
	jr	gotit
gotit1:	push	b
	mov	c,a
	lxi	h,bfchr
	call	bfind
	pop	b
	jc	error
	lda	btovl+2	; base phy drv num
	mov	d,a
gotit:
	mvi	a,'-'	; next is optional unit number...
	call	conout
	jr	luboot0

lunerr:
	call	belout
luboot0:
	call	conin
	cmp	c
	jrz	goboot
	cpi	':'
	jrz	colon
	cpi	' '
	jrz	space
	cpi	'0'
	jrc	lunerr
	cpi	'9'+1
	jrnc	lunerr
	call	conout
	sui	'0'
	mov	e,a	; single digit (0..9)
luboot1:
	call	conin
	cmp	c
	jrz	goboot
	cpi	':'	; Boot alpha-dig:str
	jrz	colon
	cpi	' '	; cosmetic spaces?
	jrz	space
	mvi	a,BEL
space:
	call	conout
	jr	luboot1

colon:	; get arbitrary string as last boot param
	mvi	b,0
	lxi	h,bootbf
btstr0:
	call	conout
	call	conin
	inr	b
	inx	h
	mov	m,a
	cmp	c
	jrnz	btstr0
	mov	a,b
	sta	bootbf	; bootbf: <len> <string...> as in CP/M cmd buf
	xra	a	; TRM - string terminator
btstr1:	; use stack as char array...
	push	psw
	inx	sp	; undo half of push
	dcx	h
	mov	a,m
	djnz	btstr1
; D=Phys Drive base number, E=Unit number
; (or, D=Phys Drive unit, E=0)
goboot:
	call	crlf
	lxi	h,error
	push	h
	push	d	; save unit num (E)
	mov	c,d
	lxi	h,bfnum
	call	bfind	; might have already been loaded...
	pop	d
	rc
	call	h17init
	mov	a,e
	sta	AIO$UNI	; relative unit num
	add	d
	sta	l2034h	; boot phys drv unit num
	jmp	btboot

hwboot:	xra	a
	sta	MFlag
hxboot:	lxi	h,CLOCK
	shld	vrst1+1
	jmp	bootbf

msg$die:
	call	msgout
	di
	hlt

; ROM start point - initialize everything
; We know we have at least 64K RAM...
; But, right now, ROM is in 0000-7FFF so must copy
; core code and switch to RAM...
init:
	lxi	h,0
	lxi	d,0
	lxi	b,2000h	; copy everything?
	ldir
	lxi	h,0ffffh
	sphl
	push	h	; save top on stack
	lxi	h,re$entry
	push	h
	call	coninit
	xra	a
	sta	l2153h
	mvi	a,00100000b	; ORG0 on, 2mS off...
	sta	ctl$F2	; 2mS off, Org0 on
	out	0f2h	; enable RAM now...
	mvi	a,0c9h	; RET
	sta	PrsRAM
	lxi	h,05000h	; 0, (beep, 2mS, !MON, !SI)
	shld	MFlag
	mvi	a,2	; display registers
	sta	DspMod
	mvi	a,debounce
	sta	kpcnt
	rst	1	; kick-start clock
	lxi	h,signon
	call	msgout
	; save registers on stack, for debugger access...
	xthl
	push	d
	push	b
	push	psw
	xchg
	lxi	h,10
	dad	sp
	push	h
	push	d
	lxi	d,ctl$F0
	ldax	d
	cma
	ani	030h
	rz
	lxi	h,2
	dad	sp
	shld	monstk
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Substitute command
cmdsub:
	lxi	h,subms
	call	msgout
	lxi	h,l2003h
	mvi	d,CR
	call	adrin
	xchg
cmdsub0:
	call	adrnl
	mov	a,m
	call	hexout
	call	spout
cmdsub1:
	call	hexin
	jrnc	cmdsub4
	cpi	CR
	jrz	cmdsub2
	cpi	'-'
	jrz	cmdsub3
	cpi	'.'
	rz
	call	belout
	jr	cmdsub1
cmdsub2:
	inx	h
	jr	cmdsub0
cmdsub3:
	call	conout
	dcx	h
	jr	cmdsub0
cmdsub4:
	mvi	m,000h
cmdsub5:
	call	conout
	call	hexbin
	rld
	call	inhexcr
	jrnc	cmdsub2
	jr	cmdsub5

inhexcr:
	call	conin
	cpi	CR
	rz
	call	hexchk
	cmc
	rc
	call	belout
	jr	inhexcr

belout:
	mvi	a,BEL
conout:
	push	psw
conot1:
	in	0edh
	ani	00100000b
	jrz	conot1
	pop	psw
	out	0e8h
	ret

; D=term char (e.g. '.' for Substitute)
; HL=location to store address
adrin:
	push	h
	lxi	h,0
adrin0:
	cnc	conin
	call	hexchk
	jrc	adrin1
	call	conout
	call	hexbin
	dad	h
	dad	h
	dad	h
	dad	h
	ora	l
	mov	l,a
	jr	adrin0
adrin1:
	cmp	d
	jrz	adrin2
	call	belout
	ora	a
	jr	adrin0
adrin2:
	call	conout
	xchg
	pop	h
	mov	m,d
	dcx	h
	mov	m,e
	ret

hexbin:
	sui	'9'+1
	jrnc	hexbi0
	adi	7
hexbi0:
	adi	3
	ret

hexin:
	call	conin
hexchk:
	cpi	'0'
	rc
	cpi	'9'+1
	cmc
	rnc
	ani	05fh	; toupper
	cpi	'A'
	rc
	cpi	'F'+1
	cmc
	ret

adrnl:
	call	crlf
adrout:
	mov	a,h
	call	hexout
	mov	a,l
	call	hexout
spout:
	mvi	a,' '
	jr	conout

hexout:
	push	psw
	rlc
	rlc
	rlc
	rlc
	call	hexdig
	pop	psw
hexdig:
	ani	00fh
	adi	090h
	daa
	aci	040h
	daa
	jr	conout

coninit:
	mvi	c,12	; 9600 baud
	in	0f2h
	ani	10000000b	; 9600/19.2K?
	jrz	ci0
	mvi	c,6	; 19.2K baud
ci0:	mvi	a,083h
	out	0ebh
	xra	a
	out	0e9h
	mov	a,c
	out	0e8h
	mvi	a,003h
	out	0ebh
	xra	a
	out	0e9h
	mvi	a,00001111b	; OUT2=1 hides 16C2550 intr enable diff
	out	0ech
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Memory Test command
cserr:
	lxi	h,cserms
	jmp	msgout

cserms:	db	BEL,'Cksum error',TRM
topms:	db	'Top of Mem: ',TRM

cmdmt:
	lxi	h,mtms
	call	msgout
	call	waitcr
	lxi	h,topms
	call	msgout
	lxi	h,0
	dad	sp
	mov	a,h
	inr	a
	jrz	cmdmt0
	sui	020h
cmdmt0:
	mov	h,a
	mvi	l,0
	dcx	h
	sui	'0'
	mov	e,a
	call	adrout
	call	crlf
	mvi	d,000h
	mvi	c,030h
	mvi	b,000h
	exx
	lxi	h,mtest0
	lxi	d,memtest - (mtest1-mtest0)
	lxi	b,mtestZ-mtest0
	ldir
	lxi	d,memtest
	lxi	h,mtest1
	mvi	c,mtestZ-mtest1
	xra	a
	exaf
	xra	a
cmdmt1:
	add	m
	exaf
	xchg
	add	m
	exaf
	xchg
	inx	h
	inx	d
	dcr	c
	jrnz	cmdmt1
	mov	c,a
	exaf
	cmp	c
	jnz	cserr
	di
	jmp	memtest - (mtest1-mtest)

;------------------------------------------------
; Start of relocated code...
; Memory Test routine, position-independent
;
mtest0:
mtest:
	mvi	a,20h	; ORG0 on (ROM off)
	out	0f2h
mtest1:		; lands at 03000h - retained relocated code
	exx
	mov	h,d
	mvi	l,0
	mov	a,b
	exx
	mov	c,a
	mvi	b,2
mtest2:
	mov	a,c
	rlc
	rlc
	rlc
	rlc
	mov	c,a
	ani	00fh
	adi	090h
	daa
	aci	040h
	daa
	out	0e8h
mtest3:
	in	0edh
	ani	020h
	jrz	mtest3
	dcr	b
	jrnz	mtest2
	mvi	a,CR
	out	0e8h
	exx
	mov	a,b
mtest4:
	mov	m,a
	adi	1
	daa
	inr	l
	jrnz	mtest4
	inr	h
	dcr	c
	jrnz	mtest4
	mov	a,h
	sub	d
	mov	c,a
	mov	h,d
	mvi	l,0
	mov	a,b
mtest5:
	cmp	m
	jrnz	mtest9
	adi	1
	daa
	inr	l
	jrnz	mtest5
	inr	h
	dcr	c
	jrnz	mtest5
	exx
	lxi	h,memtest
	lxi	d,0
	lxi	b,mtestZ-mtest1
	exx
	mov	a,d
	xri	030h
	mov	d,a
	jrz	mtest6
	mov	c,e
	jr	mtest7
mtest6:
	mvi	c,030h
	mvi	a,001h
	add	b
	daa
	mov	b,a
	exx
	xchg
	exx
mtest7:
	exx
	ldir
	mov	a,d
	ani	0f0h
	mov	h,a
	mvi	l,0
	mvi	c,mtestZ-mtest1
	xra	a
mtest8:
	add	m
	inx	h
	dcr	c
	jrnz	mtest8
	mov	c,a
	exaf
	cmp	c
	jrnz	mtestE
	exaf
	mov	a,d
	ani	0f0h
	mov	h,a
	mvi	l,0
	pchl
mtest9:
	xra	m
	mov	d,a
	mvi	a,LF
	out	0e8h
mtestA:
	in	0edh
	ani	020h
	jrz	mtestA
	mvi	c,2
	mvi	b,4
mtestB:
	mov	a,h
	rlc
	rlc
	rlc
	rlc
	ani	00fh
	adi	090h
	daa
	aci	040h
	daa
	out	0e8h
mtestC:
	in	0edh
	ani	020h
	jrz	mtestC
	dad	h
	dad	h
	dad	h
	dad	h
	djnz	mtestB
	mvi	a,' '
	out	0e8h
mtestD:
	in	0edh
	ani	020h
	jrz	mtestD
	dcr	c
	xchg
	mvi	b,002h
	jrnz	mtestB
	mvi	a,'*'
	out	0e8h
	jr	mtestG
mtestE:
	in	0edh
	ani	020h
	jrz	mtestE
	mvi	a,LF
	out	0e8h
mtestF:
	in	0edh
	ani	020h
	jrz	mtestF
	mvi	a,'!'
	out	0e8h
mtestG:
	in	0edh
	ani	020h
	jrz	mtestG
	xra	a
	mvi	b,0fah
mtestH:
	dcr	a
	jrnz	mtestH
	djnz	mtestH
	mvi	a,BEL
	out	0e8h
	jr	mtestG
; End of relocated code
mtestZ	equ	$
;------------------------------------------------

prompt:	db	CR,LF,'H8: ',TRM

; Special entry points expected by HDOS, or maybe Heath CP/M boot.
	rept	0613h-$
	db	0ffh
	endm
if	($ <> 0613h)
	.error 'HDOS entry overrun 0613h'
endif
	jmp	0	; initialized by H47 boot module
	db	0
	jmp	0	; initialized by H47 boot module

bootms:	db	'oot ',TRM
goms:	db	'o ',TRM
subms:	db	'ubstitute ',TRM
pcms:	db	'rog Counter ',TRM
mtms:	db	'em test',TRM

kpubt:
	lda	MFlag
	ori	00000010b	; disable disp updates
	sta	MFlag
	call	clrdisp	; clean slate
	lxi	b,dDev
	lxi	d,ALeds
	call	mov3dsp
	call	keyin	; get device
	ani	01111111b
	cpi	0ch	; cancel
	jz	kperr
	sta	BDF
	mov	c,a
	lxi	h,bfkey
	call	bfind
	jrc	deverr
	lxi	b,btdisp
	lxi	d,ALeds
	call	mov3dsp
	push	d	; save LEDs pointer
	; determine if fixed port...
	lda	btport
	ora	a
	jrnz	gotprt
	lxi	b,dPor
	call	mov3dsp
	call	keyin	; get port
	ani	01111111b
	cpi	04h	; 0..3 allowed
	jnc	deverr
	mov	e,a
	mvi	d,0
	lxi	h,ports
	dad	d
	mov	a,m
gotprt:	pop	h	; LEDs pointer
	sta	cport
	call	dod	; decode number to HL
	mov	d,h
	mov	e,l
	lxi	b,dUni
	call	mov3dsp
	call	keyin	; get unit
	ani	01111111b
	sta	AIO$UNI
	mov	b,a
	lda	btbase
	add	b
	sta	l2034h
	; now boot...
	mvi	a,0c3h
	sta	bootbf	; mark "no string"
	lxi	sp,bootbf
	call	btboot	; only returns if error...

kperr:
deverr:	; TODO: implement
	lxi	h,MFlag
	mov	a,m
	ani	11111110b	; disable "private" clock intr
	mov	m,a
	lxi	b,dErr
	lxi	d,ALeds
	mvi	l,6
	call	movLdsp
	mvi	c,10000000b	; beep on/off bit
	lxi	h,ticcnt
	lxi	d,ctl$F0
bterr0:
	ldax	d
	xra	c	; beep on
	stax	d
	mov	a,m
	adi	25	; 50mS
bterr2:
	cmp	m
	jrnz	bterr2
	ldax	d
	xra	c	; beep off
	stax	d
	mov	a,m
	adi	-1
bterr1:	cmp	m
	jrz	bterr0
	lda	kpchar
	cpi	01101111b	; raw pattern for '*' or CANCEL
	jrnz	bterr1
	xra	a
	sta	kpchar
	lxi	h,MFlag
	mov	a,m
	ani	10111101b	; normal mode...
	mov	m,a
	; this duplicates some code in re$entry...
	lhld	monstk
	sphl
	lxi	h,start
	push	h
	jmp	prloop

; port options for keys 0-3
ports:	db	078h,07ch,0b8h,0bch

; A=DspMod >> 1, B=key
kpalter:
	lhld	ABUSS
	rrc	; register (else memory)
	jrc	kpreg
	call	iob
	inx	h
	shld	ABUSS
	jmp	prloop

; B=key
kpreg:
	lda	RegI
	ora	a
	jz	kperr	; RegI == 0 (SP) not allowed
	mov	e,a
	mvi	d,0
	lhld	RegPtr
	dad	d
	inx	h	; HL=high byte of address
	stc
	call	iob
	dcx	h	; HL=low byte of address
	call	iob
	jmp	prloop

; B=key, CY=first digit
iob:	rarr	c	; save CY => C bit 7
	lda	Radix
	ora	a
	mov	a,b
	jrz	ioboct
; iobhex - to avoid conflict with cmd keys A-F, first input must be [0]
	ani	01111111b
	jnz	kperr
	ralr	c	; restore CY
	mvi	d,2
iobh0:	cnc	keyin
	ani	01111111b
	mov	e,a
	mov	a,m
	rlc
	rlc
	rlc
	rlc
	ani	11110000b
	ora	e	; also ensure NC for loop
	mov	m,a
	dcr	d
	jrnz	iobh0
	jr	iob0
ioboct:
	ralr	c	; restore CY
	mvi	d,3
iobo0:	cnc	keyin
	ani	01111111b
	cpi	8
	jnc	kperr
	mov	e,a
	mov	a,m
	rlc
	rlc
	rlc
	ani	11111000b
	ora	e	; also ensure NC for loop
	mov	m,a
	dcr	d
	jrnz	iobo0
iob0:
	; TODO: blip to ack entry?
	ret

; temporary: for debugging
kpdbg:	call	hexdig
	jmp	prloop

; returns with interrupts disabled
h17init:
	di
	xra	a
	out	07fh
	push	d
	lxi	h,ctl$F0
	mvi	m,0d0h	; !beep, 2mS, !mon, !SI
	lxi	h,R$CONST
	lxi	d,D$CONST
	lxi	b,88
	ldir
	mov	l,e
	mov	h,d
	inx	d
	mvi	c,30
	mov	m,a
	ldir	; fill l20a0h...
	inr	a	; A=1
	lxi	h,intvec	; vector area
h17ini0:
	mvi	m,0c3h
	inx	h
	mvi	m,LOW (nulint-rst0)
	inx	h
	mvi	m,HIGH (nulint-rst0)
	inx	h
	add	a	; shift left, count 7
	jp	h17ini0
	pop	d
	ret

waitcr:
	call	conin
	cpi	CR
	jrnz	waitcr
crlf:
	mvi	a,CR
	call	conout
	mvi	a,LF
	jmp	conout

msgout:
	mov	a,m
	ora	a
	rz
	call	conout
	inx	h
	jr	msgout

; called in the context of a command on console
conin:	in	0edh
	rrc
	jrc	conin0
	lda	kpchar
	ora	a
	jrz	conin
	; cancel console cmd, leave keypad char for cmdin
	jmp	start

conin0:	in	0e8h
	ani	07fh
	cpi	DEL	; DEL key restarts from anywhere?
	jz	re$entry
	ret

; called in the context of command on front-panel
keyin:	lda	kpchar
	ora	a
	jrnz	getkey
	in	0edh
	rrc
	jrnc	keyin
	; cancel kaypad cmd, leave console char for cmdin
	; TODO: what modes need reset?
	jmp	start

; wait for command - console or keypad
cmdin:
	in	0edh
	rrc
	jrc	conin0
	lda	kpchar
	ora	a
	jrz	cmdin
getkey:	push	psw	; A=scan code
	xra	a
	sta	kpchar
	pop	psw
	xri	11111110b
	rrc
	jrnc	gotkey
	rrc
	rrc
	rrc
	rrc
gotkey:	ani	00001111b
	ori	10000000b	; distinguish from console input
	; TODO: check for CANCEL key?
	ret

; keypad check at 32mS
kpchk:	lxi	h,RckA
	in	0f0h
	cmp	m	; RckA
	jrnz	kpchk0
	ani	00010001b
	cpi	00010001b
	rz	; nothing pressed
	mov	a,m
	; need to count auto-repeat/debounce
	inx	h	; kpcnt
	dcr	m
	rnz
	; got a key press...
	sta	kpchar
	mvi	m,rptcnt
	ret
kpchk0:	mov	m,a	; RckA
	inx	h	; kpcnt
	mvi	m,debounce
	ret

; Update Front-panel Display
ufd:	mvi	a,00000010b
	ana	b
	rnz		; updates disabled
	mvi	l,LOW DsProt
	mov	a,m
	rlc
	mov	m,a
	mov	b,a
	inx	h	; DspMod
	mov	a,m
	ani	00000010b
	lhld	ABUSS
	jrz	ufd1	; displaying memory
	; displaying registers
	call	lra	; locate register address offset (DE)
	push	h
	lxi	h,LedRegTbl
	dad	d
	mov	a,m
	inx	h
	mov	h,m
	mov	l,a
	xthl
	ora	h
	mov	a,m
	inx	h
	mov	h,m
	mov	l,a
ufd1:	push	psw
	xchg
	lxi	h,ALeds
	mov	a,d
	call	dod
	mov	a,e
	call	dod
	pop	psw
	ldax	d
	jrz	dod	; if displaying memory
	; displaying register name
	pop	b
	lxi	d,DLeds
mv3byt:	mvi	l,3
mvb:	ldax	b
	stax	d
	inx	b
	inx	d
	dcr	l
	jrnz	mvb
	ret

dod:	mov	c,a	; value to display
	lda	Radix
	ana	a	; Z if octal (also CY=0)
	mov	a,c
	jrnz	dodhex
	push	d
	mvi	c,3
dodr5:	ral
	ral
	ral
	push	psw
	ani	07h
	add	LOW doddig
	mov	e,a
	mvi	a,HIGH doddig
	aci	0
	mov	d,a
	ldax	d
	xra	b	; DP on/off
	and	01111111b	; why???
	xra	b
	mov	m,a
	inx	h
	mov	a,b	; rlcr b
	rlc
	mov	b,a
	pop	psw
	dcr	c
	jrnz	dodr5
	pop	d
	ret

dodhex:	push	d
	mvi	c,2
deh55:	rlc
	rlc
	rlc
	rlc
	push	psw
	ani	0fh
	add	LOW doddig
	mov	e,a
	mvi	a,HIGH doddig
	aci	0
	mov	d,a
	ldax	d
	xra	b	; DP on/off
	mov	m,a
	inx	h
	mov	a,b	; rlcr b
	rlc
	mov	b,a
	pop	psw
	dcr	c
	jrnz	deh55
	pop	d
	mvi	a,01101111b	; "o."
	xra	b	; DP on/off
	and	01111111b	; why???
	xra	b
	mov	m,a
	inx	h
	mov	a,b	; rlcr b
	rlc
	mov	b,a
	ret

; octal (base 8) 7-seg translation
doddig:	db	00000001b	; "0."
	db	01110011b	; "1."
	db	01001000b	; "2."
	db	01100000b	; "3."
	db	00110010b	; "4."
	db	00100100b	; "5."
	db	00000100b	; "6."
	db	01110001b	; "7."
	db	00000000b	; "8."
	db	00100000b	; "9."
	db	00010000b	; "A."
	db	00000110b	; "b."
	db	00001101b	; "C."
	db	01000010b	; "d."
	db	00001100b	; "E."
	db	00011100b	; "F."

dSP:	db	11111111b,10100100b,10011000b	; " SP"
dPSW:	db	11111111b,10010000b,10011100b	; " AF"
dBC:	db	11111111b,10000110b,10001101b	; " BC"
dDE:	db	11111111b,11000010b,10001100b	; " DE"
dHL:	db	11111111b,10010010b,10001111b	; " HL"
dIX:	db	11111111b,11110011b,10110110b	; " IX"
dIY:	db	11111111b,11110011b,11011110b	; " IY"
dIR:	db	11111111b,11110011b,11010011b	; " IR"
dPSWp:	db	10010000b,10011100b,10111111b	; "AF'"
dBCp:	db	10000110b,10001101b,10111111b	; "BC'"
dDEp:	db	11000010b,10001100b,10111111b	; "DE'"
dHLp:	db	10010010b,10001111b,10111111b	; "HL'"
dPC:	db	11111111b,10011000b,11001110b	; " PC"

dDev:	db	11000010b,10001100b,10000011b	; "dEU" (dev)
dPor:	db	10011000b,11000110b,11011110b	; "Por"
dUni:	db	10000011b,11010110b,11110111b	; "Uni"
dErr:	db	10001100b,11011110b,11011110b	; "Error "
	db	11000110b,11011110b,11111111b

LedRegTbl:
	dw	dSP	; 0
	dw	dPSW	; 1
	dw	dBC	; 2
	dw	dDE	; 3
	dw	dHL	; 4
	dw	dIX	; 5	- TODO
	dw	dIY	; 6	- TODO
	dw	dIR	; 7	- TODO
	dw	dPSWp	; 8	- TODO
	dw	dBCp	; 9	- TODO
	dw	dDEp	; 10	- TODO
	dw	dHLp	; 11	- TODO
	dw	dPC	; 12	- 5

lra:	lda	RegI
lrax:	mov	e,a
	mvi	d,0
	lhld	RegPtr
	dad	d
	ret

mov3dsp:
	mvi	l,3
movLdsp:
md0:	ldax	b
	stax	d
	inx	b
	inx	d
	dcr	l
	jrnz	md0
	ret

clrdisp:
	lxi	h,fpLeds
	mov	e,l
	mov	d,h
	lxi	b,9-1
	mvi	m,11111111b
	inx	d
	ldir
	ret

; Front panel display refresh and keypad check
int1$fp:
	lxi	h,MFlag
	mov	a,m
	mov	b,a
	ani	01000000b	; refresh display?
	inx	h	; ctl$F0
	mov	a,m
	mvi	c,0
	jrnz	fp3
	inx	h	; Refind
	dcr	m
	jrnz	fp2
	mvi	m,9
fp2:	mov	e,m	; 1-9
	mvi	d,0
	dad	d	; fpLeds[E-1]
	mov	c,e
fp3:	ora	c
	out	0f0h
	mov	a,m
	out	0f1h
	; See if time to update display values or check keypad
	mvi	l,LOW ticcnt
	mov	a,m
	push	psw
	ani	31	; 64mS
	cz	ufd
	pop	psw
	ani	15	; 32mS
	cz	kpchk
	jmp	intret

; match boot module by character (letter)
bfchr:	ldx	a,+10
	cmp	c
	ret

; match boot module by FP key
bfkey:	ldx	a,+11
	cmp	c
	ret

; match boot module by phy drv number
bfnum:	mov	a,c
	subx	+2
	cmpx	+3
	jrnc	bfn0 ; might be Z...
	xra	a
	ret
bfn0:	xra	a
	inr	a
	ret

bflst:	mov	a,c
	ora	a
	mvi	a,','
	cnz	conout
	inr	c
	mov	a,b
	subx	+2
	cmpx	+3
	jrnc	bfl2
	mvi	a,'*'
	call	conout
bfl2:
	pushix
	pop	h
	lxi	d,16
	dad	d
	call	msgout
	lxi	h,bflst
	xra	a
	inr	a	; NZ - keep going
	ret

bfllst:	mov	a,b
	subx	+2
	cmpx	+3
	mvi	a,' '
	jrnc	bfll2
	mvi	a,'*'
bfll2:	call	conout
	pushix
	pop	h
	lxi	d,16
	dad	d
	call	msgout
	mvi	a,TAB
	call	conout
	ldx	a,+10
	call	conout
	mvi	a,' '
	call	conout
	ldx	a,+11
	adi	'0'
	jrnc	bfll0
	mvi	a,'-'
bfll0:	call	conout
	mvi	a,' '
	call	conout
	ldx	a,+2
	call	decout
	ldx	a,+3
	dcr	a
	jrz	bfll1
	mvi	a,'-'
	call	conout
	ldx	a,+2
	addx	+3
	dcr	a
	call	decout
bfll1:	call	crlf
	lxi	h,bfllst
	xra	a
	inr	a	; NZ - keep going
	ret

; Find boot module and load into 1000h if necessary.
; HL=match function: returns Z if found, BC=target, IX=module
; Return CY at end of modules (not found)
bfind:
	; first, check if already loaded
	lxix	btovl
	call	icall
	rz
bfind0:
	; must map ROM back in, so prevent interruptions...
	; also, we loose memory at SP...
	di
	lxiy	0
	dady	sp
	lxi	sp,0e000h	; a safe SP?
	lda	ctl$F2
	push	psw
	ani	11011111b	; ORG0 off
	out	0f2h
	lxix	btmods	; start of modules...
bf0:	call	icall
	jrz	bf9
	ldx	e,+0
	ldx	d,+1
	dadx	d
	db 0ddh ! mov	a,h	; mov a,IX(h)
	cpi	HIGH bterom	; end of ROM
	jrnc	bf1
	ldx	a,+0
	orax	+1
	jrz	bf1
	ldx	a,+0
	anax	+1
	cpi	0ffh
	jrnz	bf0
bf1:	pop	psw
	out	0f2h
	stc	; CY = end of list (not found)
	spiy
	ei
	ret

bf9:	; match found, now load into place and init
	ldx	c,+0
	ldx	b,+1
	pushix
	pop	h
	lxi	d,btovl
	ldir
	; now call init routine... but must restore RAM...
	pop	psw
	out	0f2h
	call	btinit
	xra	a	; NC
	spiy
	ei
	ret

; assume < 100
decout:
	mvi	b,'0'
decot0:
	sui	10
	jc	decot1
	inr	b
	jmp	decot0
decot1:
	adi	10
	adi	'0'
	push	psw
	mov	a,b
	call	conout
	pop	psw
	jmp	conout

; Returns NZ if found, D=phy drv
gtdvtb:
	in	0f2h
	ani	01110000b	; default boot device
	rlc
	rlc
	rlc
	rlc
	lxi	h,defbt
gtdvtb0:
	add	l
	mov	l,a
	mvi	a,0
	adc	h
	mov	h,a
	mov	a,m
	cpi	0ffh
	mov	d,a
	ret	; NZ=none, Z=found

defbt:	; default boot table... port F2 bits 01110000b
	db	33	; -000---- MMS 5" floppy 0
	db	29	; -001---- MMS 8" floppy 0
	db	0ffh	; -010---- n/a  (port 7CH)
	db	0ffh	; -011---- n/a  (port 78H)
	db	41	; -100---- VDIP1
	db	70	; -101---- GIDE disk part 0
	db	60	; -110---- Network
	db	0ffh	; -111---- none

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; List available boot modules
cmdlb:	lxi	h,lbmsg
	call	msgout
	call	gtdfbt
	mov	b,d
	lxi	h,bflst
	mvi	c,0
	call	bfind0
	ret

lbmsg:	db	'ist boot modules',CR,LF,0
hbmsg:	db	'elp boot',CR,LF,0

cmdhb:	lxi	h,hbmsg
	call	msgout
	call	gtdfbt
	mov	b,d
	lxi	h,bfllst
	call	bfind0
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Add new boot module
cmdab:	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Update ROM
cmdur:	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Terminal mode - shuttle I/O between H19 and serial port
; since both ports operate at the same speed, don't need
; to check ready as often.
termod:
	lxi	h,terms
	call	msgout
	call	waitcr
termfl:
	in	0edh
	ani	01100000b
	cpi	01100000b
	jrnz	termfl	; wait for output to flush
	in	0ebh
	ori	10000000b
	out	0ebh
	out	0dbh
	in	0e8h
	out	0d8h
	in	0e9h
	out	0d9h
	in	0ebh
	ani	01111111b
	out	0ebh
	out	0dbh
	xra	a
	out	0d9h
	in	0d8h
	mvi	a,00fh
	out	0dch
termlp:
	in	0ddh
	ani	00000001b
	jrz	terml0
	in	0d8h
	out	0e8h
terml0:
	in	0edh
	ani	00000001b
	jrz	termlp
	in	0e8h
	out	0d8h
	jr	termlp

terms:	db	'erminal Mode',TRM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Print ROM version command
prtver:
	lxi	h,versms
	call	msgout
	ret

versms:	db	'ersion '
	db	(VERN SHR 4)+'0','.',(VERN AND 0fh)+'0',0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
signon:	db	'H8 Monitor v'
	db	(VERN SHR 4)+'0','.',(VERN AND 0fh)+'0'
if alpha
	db	'(alpha)'
endif
if beta
	db	'(beta)'
endif
	db	CR,LF,0

	rept	1000h-$
	db	0ffh
	endm
if	($ <> 1000h)
	.error 'core ROM overrun'
endif

; module overlay area starts here...
; ensure this does not match any...
	dw	-1
	db	0,0

	rept	1800h-$
	db	0ffh
	endm
if	($ <> 1800h)
	.error 'overlay ROM overrun'
endif
	end
