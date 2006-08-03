;paintc.asm - Circle Handler
;History:325

data	segment	public

	include	paint.def

dload	macro	mem
	mov	ax,mem
	mov	dx,mem+2
	endm

dstore	macro	mem
	mov	mem,ax
	mov	mem+2,dx
	endm

dtimes2	macro
	shl	ax,1
	rcl	dx,1
	endm

dadd	macro	mem
	add	ax,mem
	adc	dx,mem+2
	endm

dsub	macro	mem
	sub	ax,mem
	sbb	dx,mem+2
	endm

djns	macro	adr
	or	dx,dx
	jns	adr
	endm

djs	macro	adr
	or	dx,dx
	js	adr
	endm

t1	dw	?,?
t2	dw	?,?
t3	dw	?,?
t4	dw	?,?
t5	dw	?,?
t6	dw	?,?
t7	dw	?,?
t8	dw	?,?
t9	dw	?,?

d1	dw	?,?
d2	dw	?,?

plot_subr	dw	?

fill_or_frame	dw	?

temp		rect	<>

delta		point	<>

y_axis		dw	?

center		rect	<>

ell_ab		point	<>

extrn	pen: byte		;painti

data	ends


code	segment	public
	assume	cs:code, ds:data

	extrn	put_brush: near		;painti
	extrn	do_line: near		;painti
	extrn	bitopt_line: near	;painti
	extrn	inset_rect: near	;paintr
	extrn	set_rect: near		;paintr
	extrn	fill_rect: near		;paintr
	extrn	empty_rect: near	;paintr
	extrn	assign_rect: near	;paintr
	extrn	frame_rect: near	;paintr


ellipse:
;  ell_ab.h, ell_ab.v = the a and b of ax^2+by^2=1
	cmp	ell_ab.v,1
	jbe	regular
	cmp	ell_ab.h,1
	jae	regular
  if 0
	load2	center.topleft
	store2	temp.topleft
	load2	center.botright
	store2	temp.botright
	load2	ell_ab
	shr	cx,1
	shr	dx,1
	sub	temp.top,dx
	add	temp.bot,dx
	sub	temp.left,cx
	add	temp.right,cx
	mov	bx,offset temp
  endif
	call	frame_rect
	ret

regular:
	mov	ax,ell_ab.h
	mov	delta.h,ax		;start plotting
	mov	delta.v,0		; at due east.

	mul	ax
	dstore	t1		;t1 = a ^ 2
	dtimes2
	dstore	t2		;t2 = 2 * t1
	dtimes2
	dstore	t3		;t3 = 2 * t2
	mov	ax,ell_ab.v
	mul	ax
	dstore	t4		;t4 = b ^ 2
	dtimes2
	dstore	t5		;t5 = 2 * t4
	dtimes2
	dstore	t6		;t6 = 2 * t5
	mov	ax,ell_ab.h
	mul	t5
	dstore	t7		;t7 = a * t5
	dtimes2
	dstore	t8		;t8 = 2 * t7
	xor	ax,ax
	xor	dx,dx
	dstore	t9		;t9 = 0
	dload	t2
	dsub	t7
	dadd	t4
	dstore	d1		;d1 = t2 - t7 + t4
	dload	t1
	dsub	t8
	dadd	t5
	dstore	d2		;d2 = t1 - t8 + t5
while:				;while d2 < 0 do ...
	dload	d2
	djs	while_1		;if d2>=0 then exit.
	jmp	repeat
while_1:
	call	plot_4
	inc	delta.v
	dload	t9
	dadd	t3
	dstore	t9		;t9 = t9 + t3
	dload	d1
	djns	pixel_c
pixel_d:			;if d1 < 0 then ....
	dload	d1
	dadd	t9
	dadd	t2
	dstore	d1		;d1 = d1 + t9 + t2
	dload	d2
	dadd	t9
	dstore	d2		;d2 = d2 + t9
	jmp	while
pixel_c:			;else  (d1 >= 0)
	dec	delta.h
	dload	t8
	dsub	t6
	dstore	t8		;t8 = t8 - t6
	dload	d1
	dsub	t8
	dadd	t9
	dadd	t2
	dstore	d1		;d1 = d1 - t8 + t9 + t2
	dload	d2
	dsub	t8
	dadd	t5
	dadd	t9
	dstore	d2		;d2 = d2 - t8 + t5 + t9
	jmp	while
repeat:				;repeat ... until delta.h < 0
	call	plot_4
	dec	delta.h
	dload	t8
	dsub	t6
	dstore	t8		;t8 = t8 - t6
	dload	d2
	djns	pixel_b
	inc	delta.v
	dload	t9
	dadd	t3
	dstore	t9		;t9 = t9 + t3
	dload	d2
	dsub	t8
	dadd	t5
	dadd	t9
	dstore	d2		;d2 = d2 - t8 + t5 + t9
	jmp	short until
pixel_b:
	dload	d2
	dsub	t8
	dadd	t5
	dstore	d2		;d2 = d2 - t8 + t5
until:
	mov	ax,delta.h
	or	ax,ax
	js	repeat_end
	jmp	repeat
repeat_end:
	ret

plot_4:
	load2	center.botright
	add2	delta
	call	plot_subr		;quadrant #4

	mov	cx,center.left
	mov	dx,center.bot
	sub	cx,delta.h
	add	dx,delta.v
	call	plot_subr		;quadrant #3

	load2	center.topleft
	sub2	delta
	call	plot_subr		;quadrant #2

	mov	cx,center.right
	mov	dx,center.top
	add	cx,delta.h
	sub	dx,delta.v
	call	plot_subr		;quadrant #1
	ret


fill_line:
;enter with cx, dx = point to fill to from y axis -> out.
	mov	bx,y_axis
	sub	bx,cx
	jns	do_fill
	neg	bx
	mov	cx,y_axis
do_fill:
	call	bitopt_line
	ret


find_center_and_ab:
;enter with bx->rect.
;exit with ell_ab = a and b of circle and center = center of ellipse.
	xor	si,si
	xor	di,di
	mov	cx,[bx].right
	sub	cx,[bx].left
	sub	cx,pen.pnSize.h
	shr	cx,1				;find a (x size)
	jnc	not_odd_1
	inc	si
not_odd_1:
	mov	dx,[bx].bot
	sub	dx,[bx].top
	sub	dx,pen.pnSize.v
	shr	dx,1				;find b (y size).
	jnc	not_odd_2
	inc	di
not_odd_2:
	store2	ell_ab
	add2	[bx].topleft
	mov	y_axis,cx
	store2	center.topleft
	add	cx,si
	add	dx,di
	store2	center.botright
	ret


	public	fill_circle
fill_circle:
;enter with bx->rectangle to put filled circle into.
	mov	plot_subr,offset fill_line
	jmp	short do_circle


	public	frame_circle
frame_circle:
;enter with bx->rectangle to put circle into.
	mov	plot_subr,offset put_brush
do_circle:
	call	find_center_and_ab
	call	ellipse
	ret


	public	fill_round
fill_round:
;enter with bx->rect to put rounded rect into.
	mov	plot_subr,offset fill_line
	mov	fill_or_frame,offset fill_rect_part
	jmp	short do_round

	public	frame_round
frame_round:
;enter with bx->rect to put rounded rect into.
;preserve bx.
	mov	plot_subr,offset put_brush
	mov	fill_or_frame,offset frame_rect_part
do_round:
	push	bx
	call	find_center_and_ab
	cmp	ell_ab.v,1
	jbe	regular_round
	cmp	ell_ab.h,1
	ja	regular_round
  if 0
	mov	si,offset center
	mov	di,offset temp
	call	assign_rect
	load2	ell_ab
	sub	temp.top,dx
	add	temp.bot,dx
	sub	temp.left,cx
	add	temp.right,cx
	mov	bx,offset temp
  endif
	call	frame_rect
	pop	bx
	ret

regular_round:
	load2	ell_ab
	mov	si,0
	cmp	cx,8
	jl	noxadj
	sub	cx,8
	mov	si,cx
	mov	cx,8
noxadj:
	mov	di,0
	cmp	dx,8
	jl	noyadj
	sub	dx,8
	mov	di,dx
	mov	dx,8
noyadj:
	store2	ell_ab
	add	center.right,si
	sub	center.left,si
	add	center.bot,di
	sub	center.top,di
	call	ellipse
	call	fill_or_frame
	pop	bx
	ret

fill_rect_part:
	load2	center.topleft
	sub	cx,ell_ab.h
	load22	center.botright
	add	si,ell_ab.h
	mov	bx,offset temp
	call	set_rect
	call	fill_rect
	ret

frame_rect_part:
	load2	center.topleft
	sub	cx,ell_ab.h
	mov	si,cx
	mov	di,center.bot
	call	do_line			;left

	load2	center.botright
	add	cx,ell_ab.h
	mov	si,cx
	mov	di,center.top
	call	do_line			;right

	load2	center.topleft
	sub	dx,ell_ab.v
	mov	di,dx
	mov	si,center.right
	call	do_line			;top

	load2	center.botright
	add	dx,ell_ab.v
	mov	di,dx
	mov	si,center.left
	call	do_line			;bottom

	ret

code	ends
	end
