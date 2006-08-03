;paint1.asm - Overflow from paint.asm
;History:38,1
;


data	segment	public

	include	paint.def

	extrn	clip_rect: word
	extrn	screen: byte
	extrn	pen: byte
	extrn	cancel_rect_1: word
	extrn	cancel_string: byte
	extrn	fillPat: word
	extrn	fillPat_num: word
	extrn	edit_rect: byte
	extrn	black_pat: byte
	extrn	ok_rect: byte
	extrn	ok_string: byte
	extrn	cancel_rect: byte
	extrn	cancel_string: byte
	extrn	fatedit_rect: byte
	extrn	paint_frame: byte
	extrn	paint_rect: byte
	extrn	first_bit_rect: byte
	extrn	white_pat: byte
	extrn	down_button: byte
wind1	rect<>
our_pattern	db	8 dup(?)

data	ends

code	segment	public
	assume	cs:code, ds:data

	extrn	pset_verb: byte
	extrn	use_system_font: near
	extrn	read_style: near
	extrn	store_style: near
	extrn	makepen_dot: near
	extrn	make_fillPat_white: near
	extrn	protect_mouse: near
	extrn	frame_round: near
	extrn	center_string: near
	extrn	unprotect_mouse: near
	extrn	store_rect: near
	extrn	restore_rect: near
	extrn	nice_frame_rect: near
	extrn	wait_for_up: near
	extrn	pointing_shape: near
	extrn	use_system_font: near
	extrn	make_fillPat: near
	extrn	frame_round: near
	extrn	frame_rect: near
	extrn	wait_for_down: near
	extrn	pt_in_rect: near
	extrn	pt_in_numbered: near
	extrn	ring_bell: near
	extrn	get_mouse: near
	extrn	select_new_pattern: near
	extrn	fill_rect: near
	extrn	make_numbered_rect: near

	public	edit_pattern_goodies
edit_pattern_goodies:
	mov	bx,offset edit_rect
	call	protect_mouse
	push	clip_rect
	mov	clip_rect,offset screen
	call	store_rect
	call	nice_frame_rect
	call	unprotect_mouse
	call	read_style		;set the style to plain.
	push	ax
	mov	al,0
	call	store_style
	call	edit_pat
	pop	ax
	call	store_style
	call	restore_rect
	call	wait_for_up
	pop	clip_rect
	ret


edit_pat:
	call	pointing_shape
	call	use_system_font
	mov	bx,offset edit_rect
	call	protect_mouse
	mov	si,fillPat
	mov	di,offset our_pattern
	mov	cx,8
	push	ds
	pop	es
	rep	movsb
	mov	si,offset black_pat
	call	make_fillPat
	mov	ax,0
edit_pat_0:
	call	make_bit
	call	make_bit_box
	inc	ax
	cmp	ax,64
	jb	edit_pat_0
	call	make_fillPat_white
	mov	bx,offset ok_rect
	mov	si,offset ok_string
	call	center_string
	call	frame_round
	mov	bx,offset cancel_rect
	mov	si,offset cancel_string
	call	center_string
	call	frame_round
	mov	bx,offset fatedit_rect
	call	frame_rect
	mov	bx,offset paint_frame
	call	frame_rect
	mov	si,offset our_pattern
	call	make_fillPat
	mov	bx,offset paint_rect
	call	fill_rect
	call	unprotect_mouse
	call	wait_for_up
edit_pat_1:
	call	wait_for_down
	mov	bx,offset ok_rect
	call	pt_in_rect
	jnc	edit_pat_2
	mov	bx,offset cancel_rect
	call	pt_in_rect
	jc	edit_pat_6
	ret
edit_pat_6:
	mov	si,offset first_bit_rect
	mov	bp,8
	mov	ax,64
	call	pt_in_numbered
	jnc	edit_pat_5
	call	ring_bell
	call	wait_for_up
	jmp	edit_pat_1
edit_pat_5:
	call	make_bit
	mov	al,[si]
	and	al,dl
	mov	ah,0
	mov	bp,ax
edit_pat_4:
	call	get_mouse
	test	bl,down_button
	je	edit_pat_1
	push	bp
	mov	si,offset first_bit_rect
	mov	bp,8
	mov	ax,64
	call	pt_in_numbered
	pop	bp
	jc	edit_pat_4		;if not in box, ignore it.
	call	make_bit
	mov	dh,[si]
	or	[si],dl
	cmp	bp,0			;set or reset?
	je	edit_pat_3
	not	dl
	and	[si],dl
	not	dl
edit_pat_3:
	xor	dh,[si]			;did the bit change?
	test	dh,dl
	je	edit_pat_4		;no - don't rewrite the bit.
	push	bp
	call	make_bit_box
	mov	si,offset our_pattern
	call	make_fillPat
	mov	bx,offset paint_rect
	call	protect_mouse
	call	fill_rect
	call	unprotect_mouse
	pop	bp
	jmp	edit_pat_4
edit_pat_2:
	mov	si,offset our_pattern
	mov	di,fillPat
	mov	cx,8
	push	ds
	pop	es
	rep	movsb
	mov	ax,fillPat_num
	call	select_new_pattern
	ret


make_bit_box:
;enter with ax=box number, si->byte, dl=bit.
;exit with bit painted.
	mov	pen.pnMode,offset pset_verb
	push	ax
	push	si
	push	dx
	mov	bx,offset wind1
	mov	si,offset first_bit_rect
	mov	cx,8
	call	make_numbered_rect
	pop	dx
	pop	si
	test	[si],dl			;is the bit set?
	mov	si,offset black_pat	;if no, paint in black.
	je	make_bit_box_1		;no.
	mov	si,offset white_pat	;yes - paint in white.
make_bit_box_1:
	call	make_fillPat
	mov	bx,offset wind1
	dec	[bx].right
	dec	[bx].bot
	call	protect_mouse
	call	fill_rect
	call	unprotect_mouse
	pop	ax
	ret


make_bit:
;enter with ax=box number.
;exit with si->byte in edit pattern, dl=bit.
	mov	si,ax
	shr	si,1
	shr	si,1
	shr	si,1
	add	si,offset our_pattern
	mov	cl,al
	and	cl,7
	mov	dl,80h
	shr	dl,cl
	ret




	public	draw_cancel_box
draw_cancel_box:
	push	clip_rect
	mov	clip_rect,offset screen

	call	use_system_font		;set right font.

	call	read_style
	push	ax
	mov	al,0			;set plain style.
	call	store_style

	mov	pen.pnMode,offset pset_verb
	call	makepen_dot

	call	make_fillPat_white

	mov	bx,offset cancel_rect_1
	call	protect_mouse
	call	frame_round
	mov	si,offset cancel_string
	call	center_string
	call	unprotect_mouse

	pop	ax			;reset style.
	call	store_style

	pop	clip_rect
	ret


code	ends

	end
