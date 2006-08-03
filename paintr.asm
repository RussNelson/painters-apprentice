;paintr.asm - Rectangle Functions
;History:39,1

data	segment	public

	include	paint.def

angle_table	label	word
	dw	360+8000h	;0
	dw	270		;1
	dw	0		;2
	dw	90+8000h	;3
	dw	180		;4
	dw	270+8000h	;5
	dw	180+8000h	;6
	dw	90		;7

tan_table	label	word
;this table contains fixed-point fractions between zero and one, the ratio of
;  dx/dy or dy/dx, whichever is less than one.  There are 45 entries plus
;  1 sentinel (65535).
	dw	00000, 01144, 02289, 03435, 04583, 05734
	dw	06888, 08047, 09210, 10380, 11556, 12739
	dw	13930, 15130, 16340, 17560, 18792, 20036
	dw	21294, 22566, 23853, 25157, 26478, 27818
	dw	29178, 30559, 31964, 33392, 34846, 36327
	dw	37837, 39377, 40951, 42559, 44204, 45888
	dw	47614, 49384, 51202, 53069, 54990, 56969
	dw	59008, 61112, 63286, 65535

temp_rect	rect	<>

	extrn	pen: byte			;painti

	extrn	free_space: word		;paint

	extrn	screen_seg: word

data	ends

code	segment	public
	assume	cs:code, ds:data

	extrn	do_line: near			;painti
	extrn	protect_mouse: near		;paintmse
	extrn	unprotect_mouse: near		;paintmse
	extrn	check_free_space: near		;paintdio


	public	frame_rect
frame_rect:
;enter with bx->rect.
	call	draw_left		;draw the left edge regardless.
	mov	cx,[bx].left
	add	cx,pen.pnSize.h
	cmp	cx,[bx].right		;will two pens fit horizontally?
	jae	frame_rect_done		;no.
	call	draw_right		;if you drew the right and left
	call	draw_top		;  then you can draw the top regardless.
	mov	cx,[bx].top
	add	cx,pen.pnSize.v
	cmp	cx,[bx].bot		;will two pens fit vertically?
	jae	frame_rect_done		;no.
	call	draw_bot
frame_rect_done:
	ret

draw_left:
	mov	cx,[bx].left
	mov	si,cx
	mov	dx,[bx].top
	mov	di,[bx].bot
	sub	di,pen.pnSize.v
	push	bx
	call	do_line
	pop	bx
	ret

draw_right:
	mov	cx,[bx].right
	sub	cx,pen.pnSize.h
	mov	si,cx
	mov	dx,[bx].top
	mov	di,[bx].bot
	sub	di,pen.pnSize.v
	push	bx
	call	do_line
	pop	bx
	ret

draw_top:
	mov	cx,[bx].left
	mov	si,[bx].right
	sub	si,pen.pnSize.h
	mov	dx,[bx].top
	mov	di,dx
	push	bx
	call	do_line
	pop	bx
	ret

draw_bot:
	mov	cx,[bx].left
	mov	si,[bx].right
	sub	si,pen.pnSize.h
	mov	dx,[bx].bot
	sub	dx,pen.pnSize.v
	mov	di,dx
	push	bx
	call	do_line
	pop	bx
	ret


	public	make_numbered_rect
make_numbered_rect:
;enter with ax=rect number,
;  si->upper left rect (rect 0),
;  cx=number of rects horizontally,
;  bx->destination rect (source and destination may be the same.)
;exit with bx->proper rect.
;destroys cx, dx.
	push	ax
	mov	dx,0
	div	cx
;ax=number in v, dx=number in h.
	push	ax
	mov	ax,dx
	mov	cx,[si].right		;compute the width of the rect.
	sub	cx,[si].left
	mul	cx			;compute the h offset.
	add	ax,[si].left		;compute left
	mov	[bx].left,ax
	add	ax,cx			;compute right
	mov	[bx].right,ax
	pop	ax
	mov	cx,[si].bot		;compute the height of the rect.
	sub	cx,[si].top
	mul	cx			;compute the v offset.
	add	ax,[si].top		;compute top
	mov	[bx].top,ax
	add	ax,cx			;compute bot
	mov	[bx].bot,ax
	pop	ax
	ret


	public	pt_in_numbered
pt_in_numbered:
;enter with cx, dx=point, si->first rect, bp=number of rects h, ax=number of
;  rects.
;exit with nc, ax=rect number if in a rect, otherwise cy.
	dec	ax			;rects are numbered 0..n-1
pt_in_numbered_0:
	push	cx
	push	dx
	mov	cx,bp
	mov	bx,offset temp_rect
	call	make_numbered_rect
	pop	dx
	pop	cx
	call	pt_in_rect
	jnc	pt_in_numbered_1
	dec	ax			;done with all?
	jns	pt_in_numbered_0	;not negative, so continue.
	stc
	ret
pt_in_numbered_1:
	ret


	public	sect_rect
sect_rect:
;enter with bx->rectA, si->rectB, di->destRect
;exit with destRect=intersection of rectA and rectB, cy if rects do not intersect.
	mov	ax,[bx].top
	cmp	ax,[si].top
	jg	sect_rect_1
	mov	ax,[si].top
sect_rect_1:
	mov	[di].top,ax
	mov	ax,[bx].bot
	cmp	ax,[si].bot
	jl	sect_rect_2
	mov	ax,[si].bot
sect_rect_2:
	mov	[di].bot,ax
	mov	ax,[bx].left
	cmp	ax,[si].left
	jg	sect_rect_3
	mov	ax,[si].left
sect_rect_3:
	mov	[di].left,ax
	mov	ax,[bx].right
	cmp	ax,[si].right
	jl	sect_rect_4
	mov	ax,[si].right
sect_rect_4:
	mov	[di].right,ax
	mov	ax,[di].left
	cmp	ax,[di].right
	jge	sect_rect_5
	mov	ax,[di].top
	cmp	ax,[di].bot
	jge	sect_rect_5
	clc
	ret
sect_rect_5:
	mov	[di].left,0
	mov	[di].right,0
	mov	[di].top,0
	mov	[di].bot,0
	stc
	ret


	public	union_rect
union_rect:
;enter with bx->rectA, si->rectB, di->destRect
;exit with destRect=union of rectA and rectB.
	call	empty_rect		;is bx empty?
	jnc	assign_rect		;yes - di=si.
	mov	ax,[bx].top
	cmp	ax,[si].top
	jl	union_rect_1
	mov	ax,[si].top
union_rect_1:
	mov	[di].top,ax
	mov	ax,[bx].bot
	cmp	ax,[si].bot
	jg	union_rect_2
	mov	ax,[si].bot
union_rect_2:
	mov	[di].bot,ax
	mov	ax,[bx].left
	cmp	ax,[si].left
	jl	union_rect_3
	mov	ax,[si].left
union_rect_3:
	mov	[di].left,ax
	mov	ax,[bx].right
	cmp	ax,[si].right
	jg	union_rect_4
	mov	ax,[si].right
union_rect_4:
	mov	[di].right,ax
	ret


	public	assign_rect
assign_rect:
;enter with si-> source rect, di->dest rect.
;exit with rectangle assigned.
	push	ds
	pop	es
	mov	cx,(size rect)
	rep	movsb
	ret


	public	pt_in_rect
pt_in_rect:
;enter with bx->rect, cx,dx=x,y.
;return cy if point not in rect.
	cmp	cx,[bx].left
	jl	pt_in_rect_1
	cmp	dx,[bx].top
	jl	pt_in_rect_1
	cmp	cx,[bx].right
	jge	pt_in_rect_1
	cmp	dx,[bx].bot
	jge	pt_in_rect_1
	clc
	ret
pt_in_rect_1:
	stc
	ret


  if 0
clip_line_to_rect:
;enter with cx, dx and si, di as endpoints of a line, clip_rect->the clipping
;  rect.
;exit with nc, cx, dx, si, di clipped if the line is on screen, cy if off.
	mov	bx,clip_rect
	cmp	si,[bx].left		;rightmost line to left of screen?
	jl	clip_line_to_rect_1
	cmp	cx,[bx].right		;leftmost line to right of screen?
	jge	clip_line_to_rect_1
	cmp	di,[bx].top		;lower line above screen?
	jl	clip_line_to_rect_1
	cmp	dx,[bx].bot		;upper line below screen?
	jge	clip_line_to_rect_1
	cmp	si,[bx].right		;rightmost to right of screen?
	jl	clip_line_to_rect_2
	mov	si,[bx].right
clip_line_to_rect_2:
	cmp	cx,[bx].left		;leftmost to left of screen?
	jge	clip_line_to_rect_3
	mov	cx,[bx].left
clip_line_to_rect_3:
	cmp	di,[bx].bot		;lower below screen border?
	jl	clip_line_to_rect_4
	mov	di,[bx].bot
clip_line_to_rect_4:
	cmp	dx,[bx].top		;upper above screen border?
	jge	clip_line_to_rect_5
	mov	dx,[bx].top
clip_line_to_rect_5:
	clc
	ret
clip_line_to_rect_1:
	stc
	ret
  endif


	public	empty_rect
empty_rect:
;return nc if the rect at bx is empty.
	mov	ax,[bx].left
	cmp	ax,[bx].right
	jge	empty_rect_1
	mov	ax,[bx].top
	cmp	ax,[bx].bot
	jge	empty_rect_1
	stc
	ret
empty_rect_1:
	clc
	ret


	public	set_rect
set_rect:
;enter with bx->rect, cx,dx=topLeft, si,di=botRight.
	cmp	cx,si
	jle	set_rect_1
	xchg	cx,si
set_rect_1:
	cmp	dx,di
	jle	set_rect_2
	xchg	dx,di
set_rect_2:
	store2	[bx].topleft
	store22	[bx].botright
	ret


	public	near_pt
near_pt:
;enter with si, di and cx, dx = two points to test for closeness.
;exit with cy if not within 5 bits.
;preserve cx,dx.
	sub	si,cx			;find x distance.
	jns	near_pt_1		;negative?
	neg	si			;yes - take absolute value.
near_pt_1:
	cmp	si,5			;within 5 bits?
	ja	near_pt_3		;no - leave.
	sub	di,dx			;find y distance.
	jns	near_pt_2		;negative?
	neg	di			;yes - take absolute value.
near_pt_2:
	cmp	di,5			;within 5 scanlines?
	ja	near_pt_3		;no - leave.
	clc				;yes - it is near enough.
	ret
near_pt_3:
	stc				;no - it is not near enough.
	ret


	public	equal_pt
equal_pt:
;enter with bx->point, cx, dx=other point.
;exit with nc if they're equal, cy otherwise.
	cmp	cx,[bx].h
	jne	equal_pt_1
	cmp	dx,[bx].v
	jne	equal_pt_1
	clc
	ret
equal_pt_1:
	stc
	ret


	public	add_pt
add_pt:
;enter with bx->point, cx, dx=other point.
;exit with point added to cx, dx.
	add2	[bx]
	ret


	public	offset_rect
offset_rect:
;enter with bx->rect, cx, dx=delta x, delta y.
;exit with rectangle moved.
	add	[bx].left,cx
	add	[bx].top,dx
	add	[bx].right,cx
	add	[bx].bot,dx
	ret


	public	make_rect_bigger
make_rect_bigger:
	dec	[bx].left
	dec	[bx].top
	inc	[bx].right
	inc	[bx].bot
	ret


	public	make_rect_smaller
make_rect_smaller:
	inc	[bx].left
	inc	[bx].top
	dec	[bx].right
	dec	[bx].bot
	ret


	public	inset_rect
inset_rect:
	sub	[bx].left,cx
	sub	[bx].top,dx
	add	[bx].right,cx
	add	[bx].bot,dx
	mov	ax,[bx].left
	cmp	ax,[bx].right
	jge	inset_rect_1
	mov	ax,[bx].top
	cmp	ax,[bx].bot
	jge	inset_rect_1
	ret
inset_rect_1:
	public	set_empty_rect
set_empty_rect:
;enter with bx->rect.
	xor	ax,ax
	mov	[bx].left,ax
	mov	[bx].top,ax
	mov	[bx].right,ax
	mov	[bx].bot,ax
	ret


	public	stay_in_rect
stay_in_rect:
;enter with bx->enclosing rect, cx,dx=point
;exit with cx,dx adjusted so that point stays within enclosing rect.
	mov	ax,[bx].left
	cmp	cx,ax			;to left of window?
	jg	stay_in_rect_1
	mov	cx,ax
stay_in_rect_1:
	mov	ax,[bx].top
	cmp	dx,ax			;above window?
	jg	stay_in_rect_2
	mov	dx,ax
stay_in_rect_2:
	mov	ax,[bx].right
	cmp	cx,ax			;to right of window?
	jl	stay_in_rect_3
	mov	cx,ax
stay_in_rect_3:
	mov	ax,[bx].bot
	cmp	dx,ax
	jl	stay_in_rect_4
	mov	dx,ax
stay_in_rect_4:
	ret


	public	peg_rect
peg_rect:
;enter with si->moving rect, di->enclosing rect, cx,dx=upper left corner of
;  moving rect.
;exit with cx,dx adjusted so that moving rect stays within enclosing rect.
	mov	ax,[di].left
	cmp	cx,ax			;to left of window?
	jg	peg_rect_1
	mov	cx,ax
peg_rect_1:
	mov	ax,[di].top
	cmp	dx,ax			;above window
	jg	peg_rect_2
	mov	dx,ax
peg_rect_2:
	mov	ax,[di].right		;clip_rect.right-(select.right-select.left)
	sub	ax,[si].right
	add	ax,[si].left
	cmp	cx,ax			;to right of window?
	jl	peg_rect_3
	mov	cx,ax
peg_rect_3:
	mov	ax,[di].bot		;clip_rect.bot-(select.bot-select.top)
	sub	ax,[si].bot
	add	ax,[si].top
	cmp	dx,ax
	jl	peg_rect_4
	mov	dx,ax
peg_rect_4:
	ret


	public	store_rect
store_rect:
;enter with bx->rectangle to store.
	call	protect_mouse
	push	bx

	mov	di,free_space
	push	di

	mov	si,bx
	push	ds			;put ds where we need it.
	pop	es
	assume	es:data
	movsw				;move the rectangle in.
	movsw
	movsw
	movsw
	push	di			;we need the screen pointer in si.
	call	screen_setup
	mov	si,di
	pop	di
	jz	store_rect_2
	mov	ds,cx
	assume	ds:nothing
store_rect_1:
	mov	cx,bx
	rep	movsb
	sub	si,bx			;move back to original position,
	add	si,screen_bytes		;  and move down a line.
	dec	dx
	jne	store_rect_1

store_rect_2:
	push	es			;restore ds
	pop	ds
	assume	ds:data

	pop	[di]			;remember the old free space.
	add	di,2			;leave room for it.
	mov	free_space,di		;remember the new free space.
	call	check_free_space

	pop	bx			;restore rect pointer.
	call	unprotect_mouse
	ret


	public	restore_rect
restore_rect:
	mov	si,free_space
	mov	si,[si-2]		;get the new free space.
	mov	free_space,si
	mov	bx,si
	call	protect_mouse
	call	screen_setup
	jz	restore_rect_2
	add	si,(size rect)
	mov	es,cx
restore_rect_1:
	mov	cx,bx
	rep	movsb
	sub	di,bx			;move back to original position,
	add	di,screen_bytes		;  and move down a line.
	dec	dx
	jne	restore_rect_1
restore_rect_2:
	call	unprotect_mouse
	ret


screen_setup:
;enter with bx->rectangle
;exit with di->first byte on screen,
;  bx=number of bytes on each scan line,
;  cx=segment of screen,
;  dx=number of scan lines.
;  zr if the rectangle is empty.

	mov	ax,screen_bytes		;compute scan line from top.
	mul	[bx].top
	mov	di,ax

	mov	dx,[bx].bot		;dx=scan line count.
	sub	dx,[bx].top

	mov	ax,[bx].left		;compute offset of byte
	shr	ax,1			;  containing left.
	shr	ax,1
	shr	ax,1
	add	di,ax

	mov	bx,[bx].right
	add	bx,7			;round up to next byte.
	shr	bx,1
	shr	bx,1
	shr	bx,1
	sub	bx,ax			;compute range of bytes to store.

	mov	cx,screen_seg

	or	bx,bx			;no bytes?
	je	screen_setup_1
	or	dx,dx
screen_setup_1:

	ret


	public	arctan
arctan:
;enter with bx->rect.
;exit with ax=angle of line from topleft to botright.
	mov	ax,0
	mov	bp,0
	mov	dx,[bx].bot		;compute delta y
	sub	dx,[bx].top
	jge	arctan_2		;positive?
	neg	dx			;  make it positive.
	or	bp,2*2			;remember negative
arctan_2:
	mov	cx,[bx].right		;compute delta x
	sub	cx,[bx].left
	jge	arctan_1		;positive?
	neg	cx			;no - make it positive.
	or	bp,4*2
arctan_1:
	mov	ax,65535
	cmp	cx,dx			;deltax > deltay?
	je	arctan_5
	jg	arctan_3
	or	bp,1*2			;remember that dx<dy
	xchg	cx,dx
arctan_3:
	mov	ax,0			;divide dx:0 by cx.
	div	cx
arctan_5:
	mov	cx,ax			;remember the quotient
	mov	si,offset tan_table
arctan_4:
	lodsw				;look for the one that's greater.
	cmp	ax,cx
	jb	arctan_4
	mov	ax,offset tan_table+2	;make the index into degrees.
	sub	si,ax
	shr	si,1
	mov	ax,angle_table[bp]	;get the base angle and negative bit.
	or	ax,ax
	jns	arctan_6		;go if positive.
	and	ax,7fffh		;get rid of sign bit.
	neg	si			;subtract from angle.
arctan_6:
	add	ax,si
	ret


code	ends

	end
