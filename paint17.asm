;paint17.asm - Printer interceptor.
;History:26,1

	include	paintflg.asm

data	segment	public

	include	paint.def

	extrn	page_seg: word

state		dw	?

count		label	word		;the count of graphics bytes.
lo_count	db	?
hi_count	db	?

page_x		dw	?		;pixel locations on the page.
page_y		dw	?

data	ends

code	segment	public
	assume	cs:code, ds:data

;have to be able to find these off of cs:.

printer_num	dw	0		;default to the first printer.
their_17	dd	?
our_data	dw	?

	public	init_17
init_17:
	mov	our_data,ds
	mov	state,offset state_init

	mov	ax,3517h
	int	21h
	mov	their_17.offs,bx
	mov	their_17.segm,es

	mov	ah,25h
	mov	dx,offset our_17
	push	ds
	mov	bx,cs
	mov	ds,bx
	int	21h
	pop	ds

	ret


	public  uninit_17
uninit_17:
	push	ds
	lds	dx,their_17
	mov	ax,2517h
	int	21h
	pop	ds
	ret

our_17:
	assume	ds:nothing
	cmp	dx,printer_num		;is the the printer we're emulating?
	jne	our_17_2		;no - let the bios service it.

	or	ah,ah			;printing a character?
	jne	our_17_1		;no - just return.

	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	ds
	push	es
	mov	ds,our_data
	assume	ds:data

	jmp	state			;call the correct state.
all_done:
	pop	state

	pop	es
	pop	ds
	assume	ds:nothing
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
our_17_1:
	mov	ah,10010000b		;Return printer status good
	iret
our_17_2:
	assume	ds:nothing
	jmp	their_17
	assume	ds:data


state_init:
	mov	es,page_seg
	xor	di,di
	mov	cx,792*80/2
	mov	ax,-1
	rep	stosw
	mov	page_x,0
	mov	page_y,0
state_waiting:
	call	all_done
	cmp	al,1bh			;is this an escape?
	je	state_escape		;yes - go wait for the escape char.
	cmp	al,0dh			;return?
	je	state_cr
	cmp	al,0ah			;line feed?
	je	state_lf
	jmp	state_waiting		;not special - keep waiting.
state_cr:
	mov	page_x,0		;move to the left hand column
	jmp	state_waiting
state_lf:
	add	page_y,8		;move down a line.
	jmp	state_waiting
state_escape:
	call	all_done

	cmp	al,'L'			;low resolution graphics?
	je	state_graphics
	cmp	al,'M'			;high resolution graphics?
	jne	state_waiting		;no - keep waiting for it.
state_graphics:
	call	all_done		;wait for the low count.
	mov	lo_count,al
	call	all_done		;wait for the high count.
	mov	hi_count,al
state_chars:
	cmp	count,0			;all done?
	je	state_waiting		;yes - we're done.
	call	all_done

	mov	es,page_seg		;get the segment of the page.
	mov	bx,ax			;compute the position on the page.
	mov	ax,80
	mul	page_y			;y first.
	mov	cx,3
	mov	dx,page_x		;plus the byte part of x
	shr	dx,1
	jc	state_chars_1		;ignore odd bytes.
	shr	dx,cl
	add	ax,dx			;add the x position to the y position.
	mov	di,ax
	mov	cx,page_x
	shr	cx,1
	and	cl,7			;plus the bit part of x.
	mov	dx,0ff7fh
	shr	dx,cl

	mov	cx,8			;eight bits.
state_bit:
	shl	bl,1			;test a bit of the character.
	jnc	state_bit_1
	and	es:[di],dl		;if set, "set" the pixel there.
state_bit_1:
	add	di,80			;move down a line.
	loop	state_bit		;do all eight bits.

state_chars_1:
	dec	count
	inc	page_x
	jmp	state_chars


code	ends

	end
