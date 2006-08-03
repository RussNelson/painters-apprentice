;paintscr.asm - Scroll bars
;History:143,1

data	segment	public

BUTTON_SIZE	equ	16
THUMB_SIZE	equ	16

	include	paint.def

scroll_bar	struc
scroll_bounds	db	(size rect) dup(?) ;bounding rectangle.
scroll_current	dw	?		;current value lies in the range
scroll_size	dw	?		;  0..size-1
scroll_bar	ends

top_or_left		rect	<>	;top or left button
top_or_left_arrow	dw	?

bot_or_right	rect	<>		;bot or right button.
bot_or_right_arrow	dw	?

temp_rect	rect	<>

slide_rect	rect	<>		;area that the thumb slides in.
thumb_top	dw	?
thumb_bot	dw	?
thumb_offset	dw	?

timeout	dw	?			;time to autorepeat in hundreths.

	extrn	up_arrow: byte		;paintdat
	extrn	down_arrow: byte	;paintdat
	extrn	left_arrow: byte	;paintdat
	extrn	right_arrow: byte	;paintdat

	extrn	white_pat: byte		;paintdat
	extrn	black_pat: byte		;paintdat
	extrn	gray_pat: byte		;paintdat

	extrn	put_byte_subr: word
data	ends

code	segment	public
	assume	cs:code, ds:data

	extrn	preset_verb: near
	extrn	pset_verb: near
	extrn	protect_mouse: near	;paintmse
	extrn	unprotect_mouse: near	;paintmse
	extrn	makepen_dot: near
	extrn	make_fillPat: near
	extrn	fill_rect: near
	extrn	make_fillPat_white: near
	extrn	frame_rect: near
	extrn	put_rect: near
	extrn	inset_rect: near
	extrn	pt_in_rect: near


paint_arrow:
;enter with bx->rect, si->arrow to put inside the rect.
	push	si
	call	makepen_dot
	mov	si,offset black_pat
	call	make_fillPat
	call	fill_rect
	call	make_fillPat_white
	call	frame_rect
	pop	si

	load2	[bx].topleft
	mov	ax,[bx].right		;center it by computing the white
	sub	ax,cx
	sub	ax,[si].h		;  space, dividing it by two, and
	sar	ax,1			;  adding it to the x position.
	add	cx,ax

	mov	ax,[bx].bot
	sub	ax,dx
	sub	ax,[si].v
	sar	ax,1
	add	dx,ax

	push	bx
	mov	bx,offset temp_rect	;make a proper rectangle out of it.
	store2	[bx].topleft
	add2	[si]
	store2	[bx].botright
	mov	put_byte_subr,offset preset_verb
	call	put_rect
	pop	bx
	ret


	public	identify_bar
identify_bar:
;enter with si = max item, cx,dx = point,
;exit with nc, ax=BAR_UPARROW, BAR_PGUP, BAR_THUMB, BAR_PGDN, BAR_DOWNARROW,
;  or cy if not in the bar.
	mov	bx,offset top_or_left
	call	pt_in_rect
	mov	ax,BAR_UPARROW
	jnc	identify_bar_1

	mov	bx,offset bot_or_right
	call	pt_in_rect
	mov	ax,BAR_DOWNARROW
	jnc	identify_bar_1

	mov	bx,offset slide_rect
	call	pt_in_rect
	jc	identify_bar_1

	mov	ax,BAR_PGUP
	cmp	dx,thumb_top
	jb	identify_bar_2

	mov	ax,BAR_PGDN
	cmp	dx,thumb_bot
	jae	identify_bar_2

	sub	dx,thumb_top		;remember what the thumb offset was.
	mov	thumb_offset,dx

	mov	ax,BAR_THUMB
identify_bar_2:
	clc
identify_bar_1:
	ret


	public	measure_bar
measure_bar:
	mov	ax,si			;compute the item number that we're on.
	mov	bx,offset slide_rect
	call	pt_in_rect		;if they're not in the slide,
	jc	measure_bar_3		;  return cy.
	mov	cx,[bx].bot
	sub	cx,[bx].top
	sub	cx,THUMB_SIZE
	sub	dx,[bx].top
	sub	dx,thumb_offset
	jb	measure_bar_2
	mul	dx			;number of items *
	div	cx			;  distance down slide / size of slide
	cmp	ax,si
	ja	measure_bar_1
	clc
	ret
measure_bar_1:
	mov	ax,si
	clc
	ret
measure_bar_2:
	xor	ax,ax
	clc
	ret
measure_bar_3:
	stc
	ret


	public	paint_bar
paint_bar:
;enter with ax = thumb position, cx = max thumb position.
	mov	bx,offset slide_rect
	mov	dx,[bx].bot		;compute the available space.
	sub	dx,[bx].top
	sub	dx,THUMB_SIZE
	ja	paint_bar_1		;go if it's big enough.
	ret				;too small to paint the whole thumb.
paint_bar_1:
	mul	dx
	div	cx
	load2	[bx].topleft		;make it narrower so we don't screw
	store2	temp_rect.topleft
	mov	cx,[bx].right
	add	dx,ax			;adjust y by the x amount.
	store2	temp_rect.botright	;remember where the top area ends.

	call	protect_mouse
	mov	bx,offset temp_rect	;now gray the top area.
	mov	si,offset gray_pat
	call	make_fillPat
	inc	[bx].left
	dec	[bx].right
	call	fill_rect
	dec	[bx].left
	inc	[bx].right

	mov	ax,temp_rect.bot
	mov	temp_rect.top,ax
	mov	thumb_top,ax
	add	ax,THUMB_SIZE
	mov	temp_rect.bot,ax
	mov	thumb_bot,ax

	call	make_fillPat_white	;now draw the thumb.
	call	frame_rect		;outline.
	mov	cx,-1
	mov	dx,-1
	call	inset_rect
	mov	si,offset black_pat
	call	make_fillPat
	call	fill_rect		;fill the inside.
	mov	cx,1
	mov	dx,1
	call	inset_rect

	mov	ax,temp_rect.bot
	mov	temp_rect.top,ax
	mov	ax,slide_rect.bot
	mov	temp_rect.bot,ax

	mov	si,offset gray_pat	;now fill the bottom area.
	call	make_fillPat
	inc	[bx].left
	dec	[bx].right
	call	fill_rect
	dec	[bx].left
	inc	[bx].right

	call	unprotect_mouse

	ret


	public	setup_bar
setup_bar:
;enter with bx -> scroll bar,
;  cx,dx = mouse click,
;  bp = callback routine.
;  button is down.
	mov	top_or_left_arrow,offset up_arrow
	mov	bot_or_right_arrow,offset down_arrow
	load2	[bx].topleft
	store2	top_or_left.topleft
	mov	slide_rect.left,cx
	add	cx,BUTTON_SIZE
	add	dx,BUTTON_SIZE
	store2	top_or_left.botright
	mov	slide_rect.top,dx

	mov	cx,[bx].left
	mov	dx,[bx].bot
	mov	bot_or_right.left,cx
	mov	bot_or_right.bot,dx
	add	cx,BUTTON_SIZE
	sub	dx,BUTTON_SIZE
	mov	bot_or_right.right,cx
	mov	bot_or_right.top,dx
	mov	slide_rect.right,cx
	mov	slide_rect.bot,dx

	mov	bx,offset slide_rect	;frame the slide rectangle.
	mov	cx,0
	mov	dx,1
	call	inset_rect
	call	make_fillPat_white
	call	frame_rect

	mov	bx,offset top_or_left
	mov	si,top_or_left_arrow
	call	paint_arrow

	mov	bx,offset bot_or_right
	mov	si,bot_or_right_arrow
	call	paint_arrow
	ret


code	ends

	end
