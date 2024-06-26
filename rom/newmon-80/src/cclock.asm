; Command module for FP clock display

	maclib	core
	maclib	ram

CR	equ	13
LF	equ	10
CTLC	equ	3

rtc	equ	0a0h	; standard port address

	org	1000h
first:	db	HIGH (last-first)	; +0: num pages
	db	HIGH first		; +1: ORG page
	db	255,0	; +2,+3: phy drv base, num

	jmp	init	; +4: init entry
	jmp	exec	; +7: action entry

	db	'c'	; +10: Command letter
	db	-1	; +11: front panel key
	db	0	; +12: port, 0 if variable
	db	11111111b,11111111b,11111111b	; +13: FP display
	db	'FP Clock Display',0	; +16: mnemonic string

init:
	in	rtc+15
	ori	00000100b ; 24-hour format
	out	rtc+15
	; more to init?
	xra	a	; NC
	ret

exec:
	lxi	h,signon
	call	msgout
	lda	MFlag
	ori	00000010b	; disable disp updates
	sta	MFlag

clock:
	call	gettime
	lxi	h,time
	lda	lastsec
	cmp	m
	cnz	show	; HL=time
	; delay a bit, do not always keep RTC in HOLD
	lxi	h,ticcnt
	mvi	a,50	; 100mS
	add	m
	mov	c,a
wait0:	call	chkabort
	jc	fin
	mov	a,m
	cmp	c
	jnz	wait0
	jmp	clock

fin:	call	crlf
	lda	MFlag
	ani	11111101b	; enable disp updates
	sta	MFlag
	ret

chkabort:
	in	0edh
	ani	1
	rz
	in	0e8h
	cpi	CTLC
	rnz
	stc
	ret

; HL=time[0]
show:
	mov	a,m	; seconds LSD
	sta	lastsec
	lxi	d,fpLeds+8
	mvi	b,6
show0:	mov	a,m
	push	h
	lxi	h,fpdig
	add	l
	mov	l,a
	jnc	show2
	inr	h
show2:	mov	a,m
	stax	d
	pop	h
	inx	h
	dcx	d
	dcr	b
	mov	a,b
	ani	1
	jnz	show1
	mvi	a,01111111b	; " ."
	stax	d
	dcx	d
show1:	mov	a,b
	ora	a
	jnz	show0
	ret

fpdig:	
	db	10000001b	; "0"
	db	11110011b	; "1"
	db	11001000b	; "2"
	db	11100000b	; "3"
	db	10110010b	; "4"
	db	10100100b	; "5"
	db	10000100b	; "6"
	db	11110001b	; "7"
	db	10000000b	; "8"
	db	10100000b	; "9"

gettime:
	call	hold
	lxi	h,time
	mvi	c,rtc-1
	mvi	b,6
gettm0:	inr	c
	call	inp$a
	ani	0fh
	mov	m,a
	inx	h
	dcr b ! jnz gettm0
	call	unhold
	ret

hold:	in	rtc+13
	ori	0001b	; HOLD
	out	rtc+13
	in	rtc+13
	ani	0010b	; BUSY
	rz
	ani	00001110b
	out	rtc+13
	; TODO: pause?
	jmp	hold

unhold:	in	rtc+13
	ani	11111110b
	out	rtc+13
	ret

inp$a:	mov	a,c
	sta	inp$a0+1
inp$a0:	in	0
	ret

lastsec:
	db	0ffh

time:	db	0,0,0,0,0,0	;1sec,10sec,1min,10min,1hr,10hr

signon:	db	' FP clock',CR,LF
	db	'Ctl-C to quit ',0

	rept	(($+0ffh) and 0ff00h)-$
	db	0ffh
	endm

last:	end
