; SNIOS for H8-WIZ550io
;
	maclib	z80

	public	NTWKIN, NTWKST, CNFTBL, SNDMSG, RCVMSG, NTWKER, NTWKBT, CFGTBL

wiz	equ	40h	; base port
wiz$dat	equ	wiz+0
wiz$ctl	equ	wiz+1
wiz$sta	equ	wiz+1

nsocks	equ	8

SCS	equ	1	; ctl port
BSY	equ	1	; sts port

sock0	equ	000$01$000b	; base pattern for Sn_ regs
txbuf0	equ	000$10$100b	; base pattern for Tx buffer
rxbuf0	equ	000$11$000b	; base pattern for Rx buffer

; common regs
ir	equ	21
sir	equ	23
pmagic	equ	29

; socket regs, relative
sn$cr	equ	1
sn$ir	equ	2
sn$sr	equ	3
sn$prt	equ	4
sn$txwr	equ	36
sn$rxrsr equ	38
sn$rxrd	equ	40

; socket commands
OPEN	equ	01h
CONNECT	equ	04h
SEND	equ	20h
RECV	equ	40h

; socket status
INIT	equ	13h
ESTABLISHED equ	17h

	cseg
;	Slave Configuration Table
CFGTBL:
	ds	1		; network status byte
	ds	1		; slave processor ID number
	ds	2		; A:	Disk device	+2
	ds	2		; B:	"
	ds	2		; C:	"
	ds	2		; D:	"
	ds	2		; E:	"
	ds	2		; F:	"
	ds	2		; G:	"
	ds	2		; H:	"
	ds	2		; I:	"
	ds	2		; J:	"
	ds	2		; K:	"
	ds	2		; L:	"
	ds	2		; M:	"
	ds	2		; N:	"
	ds	2		; O:	"
	ds	2		; P:	"

	ds	2		; console device	+34

	ds	2		; list device:		+36...
	ds	1		;	buffer index	+2
	db	0		;	FMT		+3
	db	0		;	DID		+4
	db	0ffh		;	SID (CP/NOS must still initialize)
	db	5		;	FNC		+6
	db	0		;	SIZ		+7
	ds	1		;	MSG(0)	List number	+8
	ds	128		;	MSG(1) ... MSG(128)	+9...

;	Network Status Byte Equates
;
active		equ	0001$0000b	; slave logged in on network
rcverr		equ	0000$0010b	; error in received message
senderr 	equ	0000$0001b	; unable to send message

srvtbl:	ds	nsocks	; SID, per socket

cursok:	db	0	; current socket select patn
curptr:	dw	0	; into chip mem
msgptr:	dw	0
msglen:	dw	0
totlen:	dw	0

getwiz1:
	mvi	a,SCS
	out	wiz$ctl
	mvi	c,wiz$dat
	outz	; hi adr byte always 0
	outp	e
	res	2,d
	outp	d
	inz	; prime MISO
	inp	a
	inr	c	; ctl port
	outz		; clear SCS
	ret

putwiz1:
	push	psw
	mvi	a,SCS
	out	wiz$ctl
	pop	psw
	mvi	c,wiz$dat
	outz	; hi adr byte always 0
	outp	e
	setb	2,d
	outp	d
	outp	a	; data
	inr	c	; ctl port
	outz		; clear SCS
	ret

; Get 16-bit value from chip
; Prereq: IDM_AR0 already set, auto-incr on
; Entry: A=value for IDM_AR1
; Return: HL=register pair contents
getwiz2:
	mvi	a,SCS
	out	wiz$ctl
	mvi	c,wiz$dat
	outz	; hi adr byte always 0
	outp	e
	res	2,d
	outp	d
	inz	; prime MISO
	inp	h	; data
	inp	l	; data
	inr	c	; ctl port
	outz		; clear SCS
	ret

; Put 16-bit value to chip
; Prereq: IDM_AR0 already set, auto-incr on
; Entry: A=value for IDM_AR1
;        HL=register pair contents
putwiz2:
	mvi	a,SCS
	out	wiz$ctl
	mvi	c,wiz$dat
	outz	; hi adr byte always 0
	outp	e
	setb	2,d
	outp	d
	outp	h	; data to write
	outp	l
	inr	c	; ctl port
	outz		; clear SCS
	ret

; Issue command, wait for complete
; D=Socket ctl byte
; Returns: A=Sn_SR
wizcmd:	mov	b,a
	mvi	e,sn$cr
	setb	2,d
	mvi	a,SCS
	out	wiz$ctl
	mvi	c,wiz$dat
	outz	; hi adr byte always 0
	outp	e
	outp	d
	outp	b	; command
	inr	c	; ctl port
	outz		; clear SCS
wc0:	call	getwiz1
	ora	a
	jrnz	wc0
	mvi	e,sn$sr
	call	getwiz1
	ret

; B=Server ID, preserves HL
; returns DE=socket base (if NC)
getsrv:
	mvi	c,nsocks
	lxi	d,srvtbl
gs1:
	ldax	d
	cmp	b
	jrz	gs0
	inx	d
	dcr	c
	jrnz	gs1
	stc	; not found
	ret
gs0:	; found...
	mvi	a,nsocks
	sub	c	; socket num
	rlc
	rlc
	rlc
	sta	cursok
	ori	sock0
	mov	d,a
	mvi	e,sn$sr
	call	getwiz1
	cpi	ESTABLISHED
	rz
	cpi	INIT
	jrz	gs3
	; try to open socket...
	mvi	a,OPEN
	call	wizcmd
	cpi	INIT
	jrnz	gs2
gs3:	mvi	a,CONNECT
	call	wizcmd
	cpi	ESTABLISHED
	rz
gs2:	stc	; failed to open
	ret

; HL=socket relative pointer (TX_WR)
; DE=length
; Returns: HL=msgptr, C=wiz$dat
cpsetup:
	mvi	a,SCS
	out	wiz$ctl
	mvi	c,wiz$dat
	outp	h
	outp	l
	lda	cursok
	ora	b
	outp	a
	lhld	msgptr
	ret

cpyout:
	mvi	b,txbuf0
	call	cpsetup
	mov	b,e	; fraction of page
	mov	a,e
	ora	a
	jrz	co0	; exactly 256
	outir		; do partial page
	; B is now 0 (256 bytes)
	mov	a,d
	ora	a
	jrz	co1
co0:	outir	; 256 (more) bytes to xfer
co1:	shld	msgptr
	inr	c	; ctl port
	outz		; clear SCS
	ret

; HL=socket relative pointer (RX_RD)
; DE=length
; Destroys IDM_AR0, IDM_AR1
cpyin:
	mvi	b,rxbuf0
	call	cpsetup	;
	inz	; prime MISO
	mov	b,e	; fraction of page
	mov	a,e
	ora	a
	jrz	ci0	; exactly 256
	inir		; do partial page
	; B is now 0 (256 bytes)
	mov	a,d
	ora	a
	jrz	ci1
ci0:	inir	; 256 (more) bytes to xfer
ci1:	shld	msgptr
	inr	c	; ctl port
	outz		; clear SCS
	ret

; L=bits to reset
; D=socket base
wizsts:
	mvi	e,sn$ir
	call	getwiz1	; destroys C
	push	psw
	ana	l
	jrz	ws0	; don't reset if not set (could race)
	mov	a,l
	call	putwiz1
ws0:	pop	psw
	ret

;	Utility Procedures
;
;	Network Initialization
NTWKIN:
	lxix	CFGTBL
	lxi	d,pmagic
	call	getwiz1
	ora	a
	jz	err
	stx	a,+1 ; our slave (client) ID
	mvi	a,active
	stx	a,+0 ; network status byte
	xra	a
	sta	CFGTBL+36+7
	jmp	ntwkbt0	; load data

;	Network Status
NTWKST:
	lda	CFGTBL+0
	mov	b,a
	ani	not (rcverr+senderr)
	sta	CFGTBL+0
	mov	a,b
	ret

;	Return Configuration Table Address
;	Still need this for BDOS func 69
CNFTBL:
	lxi	h,CFGTBL
	ret

;	Send Message on Network
SNDMSG:			; BC = message addr
	sbcd	msgptr
	lixd	msgptr
	ldx	b,+1	; SID - destination
	call	getsrv
	jrc	serr
	; D=socket patn
	lda	CFGTBL+1
	stx	a,+2	; Set Slave ID in header
	ldx	a,+4	; msg siz (-1)
	adi	5+1	; hdr, +1 for (-1)
	mov	l,a
	mvi	a,0
	aci	0
	mov	h,a	; HL=msg length
	shld	msglen
	mvi	e,sn$txwr
	call	getwiz2
	shld	curptr
	lhld	msglen
	lbcd	curptr
	dad	b
	mvi	e,sn$txwr
	call	putwiz2
	; send data
	lhld	msglen
	xchg
	lhld	curptr
	call	cpyout
	lda	cursok
	ori	sock0
	mov	d,a
	mvi	a,SEND
	call	wizcmd
	; ignore Sn_SR?
	mvi	l,00010000b	; SEND_OK bit
	call	wizsts
	cma	; want "0" on success
	ana	l	; SEND_OK
	rz
serr:	lda	CFGTBL
	ori	senderr
	sta	CFGTBL
	mvi	a,0ffh
	ret

; TODO: also check/OPEN sockets?
; That would result in all sockets always being open...
; At least check all, if none are ESTABLISHED then error immediately
check:
	lxi	d,(sock0 shl 8) + sn$sr
	mvi	b,nsocks
chk2:	call	getwiz1
	cpi	ESTABLISHED
	jrz	chk3
	mvi	a,001$00$000b
	add	d	; next socket
	mov	d,a
	djnz	chk2
	stc
	ret
chk3:	lxi	h,32000	; do check for sane receive time...
chk0:	mvi	d,sock0
	mvi	b,nsocks
	push	h
	mvi	l,00000100b	; RECV data available bit
chk1:	call	wizsts
	ana	l	; RECV data available
	jrnz	chk4	; D=socket
	mvi	a,001$00$000b
	add	d	; next socket
	mov	d,a
	djnz	chk1
	pop	h
	dcx	h
	mov	a,h
	ora	l
	jrnz	chk0
	stc
	ret
chk4:	pop	h
	ret

;	Receive Message from Network
RCVMSG:			; BC = message addr
	sbcd	msgptr
	lixd	msgptr
	call	check	; locates socket that is ready
	; D=socket
	jrc	rerr
	lxi	h,0
	shld	totlen
rm0:	; D must be socket base...
	mvi	e,sn$rxrsr	; length
	call	getwiz2
	mov	a,h
	ora	l
	jrz	rm0
	shld	msglen		; not CP/NET msg len
	mvi	e,sn$rxrd	; pointer
	call	getwiz2
	shld	curptr
	lbcd	msglen	; BC=Sn_RX_RSR
	lhld	totlen
	ora	a
	dsbc	b
	shld	totlen	; might be negative...
	lbcd	curptr
	lhld	msglen	; BC=Sn_RX_RD, HL=Sn_RX_RSR
	dad	b	; HL=nxt RD
	mvi	e,sn$rxrd
	call	putwiz2
	; DE destroyed...
	lded	msglen
	lhld	curptr
	call	cpyin
	lda	cursok
	ori	sock0
	mov	d,a
	mvi	a,RECV
	call	wizcmd
	; ignore Sn_SR?
	lhld	totlen	; might be neg (first pass)
	mov	a,h
	ora	a
	jp	rm1
	; can we guarantee at least msg hdr?
	ldx	a,+4	; msg siz (-1)
	adi	5+1	; header, +1 for (-1)
	mov	e,a
	mvi	a,0
	adc	a
	mov	d,a	; true msg len
	dad	d	; subtract what we already have
	jrnc	rerr	; something is wrong, if still neg
	shld	totlen
	mov	a,h
rm1:	ora	l
	jnz	rm0
	ret	; success (A=0)

rerr:	lda	CFGTBL
	ori	rcverr
	sta	CFGTBL
err:	mvi	a,0ffh
NTWKER:	ret

NTWKBT:	; NETWORK WARM START
	lda	CFGTBL
	ani	active
	jz	NTWKIN	; will end up back here, on success
ntwkbt0:
	; load socket server IDs based on WIZ550io current config
	mvi	b,nsocks
	lxi	d,(sock0 shl 8) + sn$prt
	lxi	h,srvtbl
nb1:
	push	h
	call	getwiz2	; destroys C,HL
	mov	a,h
	cpi	31h
	mvi	a,0ffh
	jrnz	nb0
	mov	a,l	; server ID
nb0:	pop	h
	mov	m,a
	inx	h
	mvi	a,001$00$000b
	add	d	; next socket
	mov	d,a
	djnz	nb1
	xra	a
	ret

	end