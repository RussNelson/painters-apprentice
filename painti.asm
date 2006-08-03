;painti.asm - Image Processor
;History:212,1
;03-06-88 22:36:57 fix clipping on the left edge.
;02-08-88 22:08:16 fix a clipping bug.

data	segment	public

	include	paint.def

count_begin	macro
thisone	=	$
	dw	?
	endm

count_end	macro	a
  ifdif <a>,<>
	org	$-a
  endif
thatone	=	$
	org	thisone
	dw	thatone-thisone-2
	org	thatone
	endm

;note that the two words previous to the given verb must be the offsets
;  (in the data segment!) of two routines.  The first (cs:put_byte_subr-4) is
;  a routine that puts the byte in al with a mask of 0ffh.  The second
;  (cs:put_byte_subr-2) is a routine that puts the byte in al using the mask
;  in dl.
	public	put_byte_subr
put_byte_subr	dw	or_verb

	db	3 dup(0)		;in case we need to clip on the left.
a_scan_line	db	80 dup(?),?

	public	pen
pen	penState<>

incdir	point	<>
count	dw	?

smaller_delta	dw	?
larger_delta	dw	?
epsilon		dw	?

new_x_size	dw	?
old_x_size	dw	?
smaller_line	dw	?
larger_line	dw	?
compression	db	?
not_compression	db	?

temp	point	<>

	public	bit_count, line_count
bit_count	dw	?
line_count	dw	?
scan_line_count	dw	?
byte_count	dw	?

src_align	dw	?
src_seg		dw	?
src_bytes	dw	?
src_left_bit	db	?

dest_align	dw	?
dest_bytes	dw	?
dest_left_bit	db	?

this_fillPat	dw	?
fillPat_block	label	byte
	dw	24 dup(?)

get_byte_ptr	dw	?
get_ptrs	label	word
	dw	0			;shift count of zero - not used.
	dw	shifted_7_get
	dw	shifted_get
	dw	shifted_get
	dw	shifted_get
	dw	shifted_get
	dw	shifted_get
	dw	shifted_1_get

shifted_get	label	byte
	count_begin
	mov	ax,[si]			;get the next two bytes.
	inc	si
	rol	ax,cl			;align to screen byte.
	count_end

shifted_1_get	label	byte
	count_begin
	mov	ax,[si]			;get the next two bytes.
	inc	si
	xchg	ah,al
	ror	ax,1			;align to screen byte.
	count_end

shifted_7_get	label	byte
	count_begin
	mov	ax,[si]			;get the next two bytes.
	inc	si
	rol	ax,1			;align to screen byte.
	count_end

pset_verb_1	label	byte
	count_begin
	stosb
	count_end
pset_verb_2	label	byte
	count_begin
	xor	al,es:[di]
	and	al,dl
	xor	es:[di],al
	inc	di			;go to the next byte.
	count_end

and_not_verb_1	label	byte
	count_begin
	not	al
	and	es:[di],al
	inc	di			;go to the next byte.
	count_end
and_not_verb_2	label	byte
	count_begin
	not	al
	not	dl
	or	al,dl
	and	es:[di],al
	inc	di			;go to the next byte.
	count_end

preset_verb_1	label	byte
	count_begin
	not	al
	stosb
	count_end
preset_verb_2	label	byte
	count_begin
	not	al
	xor	al,es:[di]
	and	al,dl
	xor	es:[di],al
	inc	di			;go to the next byte.
	count_end

and_verb_1	label	byte
	count_begin
	and	es:[di],al
	inc	di			;go to the next byte.
	count_end
and_verb_2	label	byte
	count_begin
	not	dl
	or	al,dl
	and	es:[di],al
	inc	di			;go to the next byte.
	count_end

or_verb_1	label	byte
	count_begin
	or	es:[di],al
	inc	di			;go to the next byte.
	count_end
or_verb_2	label	byte
	count_begin
	and	al,dl			;only set the bits given in al.
	or	es:[di],al
	inc	di			;go to the next byte.
	count_end

or_not_verb_1	label	byte
	count_begin
	not	al
	or	es:[di],al
	inc	di			;go to the next byte.
	count_end
or_not_verb_2	label	byte
	count_begin
	not	al
	and	al,dl			;only set the bits given in al.
	or	es:[di],al
	inc	di			;go to the next byte.
	count_end

xor_verb_1	label	byte
	count_begin
	xor	es:[di],al
	inc	di			;go to the next byte.
	count_end
xor_verb_2	label	byte
	count_begin
	and	al,dl			;only xor the bits given in al.
	xor	es:[di],al
	inc	di			;go to the next byte.
	count_end

	extrn	clip_rect: word		;paint
	extrn	pnPat: byte		;paintdat
	extrn	this_pen: word		;paintg
	extrn	put_brush_subr: word	;painth
	extrn	white_pat: byte		;paintdat
	extrn	black_pat: byte		;paintdat
	extrn	gray_pat: byte		;paintdat
	extrn	dot_pen: byte		;paintdat
	extrn	wind_on_page: word	;paint
	extrn	fatbits_flag: byte	;paint

	extrn	screen_seg: word

data	ends

code	segment	public
	assume	cs:code, ds:data, ss:data

	extrn	protect_mouse: near	;paintmse
	extrn	unprotect_mouse: near	;paintmse
	extrn	assign_rect: near	;paintr


	public	make_fillPat_white
make_fillPat_white:
	mov	si,offset white_pat
;fall through
	public	make_fillPat
make_fillPat:
;enter with si->fill pattern.
;exit with fillPat_block set to the given fill pattern.
	mov	this_fillPat,si
	push	ds
	pop	es
	mov	di,offset fillPat_block
	load2	wind_on_page
	neg	dx
	and	dx,7			;find out the vertical position
	shl	dx,1
	add	di,dx			;move that far into the fillpat block.
	cmp	fatbits_flag,0		;are we in fatbits?
	jne	make_fillPat_4		;yes - use h position.
	xor	cx,cx			;no - don't use h position.
	jmp	short make_fillpat_3
make_fillPat_4:
	neg	cx
	and	cx,7			;isolate the horizontal position.
make_fillPat_3:
	mov	dx,8
make_fillPat_1:
	lodsb
  if black_on_white
	not	al
  endif
	mov	ah,al			;extend into a word.
	ror	ax,cl			;rotate pattern into position.
	mov	[di+16],ax		;repeat 8 lines down
	mov	[di+32],ax		;repeat 16 lines down.
	stosw
	cmp	di,offset fillPat_block+16	;did we hit the end?
	jne	make_fillPat_2
	mov	di,offset fillPat_block
make_fillPat_2:
	dec	dx
	jne	make_fillPat_1
	ret


	public	do_line
do_line:
	call	no_clipping		;can we optimize h or v lines?
	jc	do_line_1		;no.
	xchg	si,cx
	xchg	di,dx
	call	no_clipping		;can we optimize h or v lines?
	xchg	si,cx
	xchg	di,dx
	jc	do_line_1		;no.

	cmp	put_brush_subr,offset put_brush	;can we optimize in x or y?
	jne	do_line_1		;no.

	cmp	si,cx
	je	line_in_y_j_1		;line varies only in y.
	cmp	di,dx
	je	line_in_x_j_1		;line varies only in x.

do_line_1:
	mov	incdir.h,1
	mov	incdir.v,1
	sub	si,cx			;si=delta x
	sub	di,dx			;di=delta y
	or	si,si
	jge	line_to_1
	neg	si
	neg	incdir.h
line_to_1:
	or	di,di
	jge	line_to_2
	neg	di
	neg	incdir.v
line_to_2:
	cmp	si,di
	jge	x_by_one

y_by_one:
;delta y >= delta x
	mov	larger_delta,si
	mov	smaller_delta,di
	mov	bx,di			;use dx to test when dx is incremented
	sar	bx,1			;/2
	mov	count,di
	inc	count			;include endpoint.
y_by_one_1:
	push	bx
	push	cx
	push	dx
	call	put_brush_subr
	pop	dx
	pop	cx
	pop	bx
	mov	di,smaller_delta
	add	bx,larger_delta
	cmp	bx,di			;past the larger yet?
	jl	y_by_one_2		;no.
	sub	bx,di			;yes - subtract it off.
	add	cx,incdir.h
y_by_one_2:
	add	dx,incdir.v
	dec	count
	jne	y_by_one_1
	ret

line_in_y_j_1:
	jmp	line_in_y

line_in_x_j_1:
	jmp	line_in_x

x_by_one:
;delta x > delta y
	mov	larger_delta,si
	mov	smaller_delta,di
	mov	bx,si			;use ax to test when di is incremented
	sar	bx,1			;/2
	mov	count,si
	inc	count			;include endpoint.
x_by_one_1:
	push	bx
	push	cx
	push	dx
	call	put_brush_subr
	pop	dx
	pop	cx
	pop	bx
	mov	di,larger_delta
	add	bx,smaller_delta
	cmp	bx,di			;past the larger yet?
	jl	x_by_one_2		;no.
	sub	bx,di			;larger.
	add	dx,incdir.v
x_by_one_2:
	add	cx,incdir.h
	dec	count
	jne	x_by_one_1
	ret

line_in_x:
	cmp	si,cx			;ensure that si>cx.
	ja	line_in_x_4
	xchg	si,cx
line_in_x_4:

	cmp	this_pen,offset dot_pen
	jne	line_in_x_2

	mov	ax,pen.pnMode
	mov	put_byte_subr,ax
	mov	bx,si
	sub	bx,cx
	inc	bx			;include endpoint.
	call	bitopt_line
line_in_x_7:
	ret

line_in_x_2:
	sub	si,cx
	inc	si			;include the endpoint.
	mov	line_count,si
	mov	incdir.v,dx
line_in_x_1:
	mov	dx,incdir.v
	push	cx
	call	put_brush_subr
	pop	cx
	inc	cx
	dec	line_count
	jne	line_in_x_1
	ret

line_in_y:
	cmp	di,dx			;ensure that di>dx.
	ja	line_in_y_3
	xchg	di,dx
line_in_y_3:

	cmp	this_pen,offset dot_pen
	jne	line_in_y_2

	sub	di,dx
	mov	bx,di

	call	point_to_pointer

	and	dx,7			;get the low 3 bits of y
	shl	dx,1			;addressing words.
	mov	si,dx

	mov	ah,80h			;put a one in bit 7
	shr	ah,cl			;shift it to the right place.

	mov	cx,bx
	inc	cx
	mov	bx,pen.pnMode
line_in_y_4:
	mov	dl,ah
	mov	al,fillPat_block[si]	;get the byte of the fill pattern.
	add	si,1*2			;add 1 mod 8
	and	si,7*2			;wrap around to the beginning.
	call	bx
	add	di,screen_bytes
	loop	line_in_y_4
line_in_y_7:
	ret
line_in_y_2:
	sub	di,dx
	inc	di
	mov	line_count,di
	mov	incdir.h,cx
line_in_y_1:
	mov	cx,incdir.h
	push	dx
	call	put_brush_subr
	pop	dx
	inc	dx
	dec	line_count
	jne	line_in_y_1
	ret


no_clipping:
;enter with cx,dx=pen point.
;return nc is no clipping is needed.
	mov	bx,clip_rect
	cmp	cx,[bx].left
	jl	no_clipping_1
	cmp	dx,[bx].top
	jl	no_clipping_1
	mov	ax,[bx].right
	sub	ax,pen.pnSize.h
	cmp	cx,ax
	jg	no_clipping_1
	mov	ax,[bx].bot
	sub	ax,pen.pnSize.v
	cmp	dx,ax
	jg	no_clipping_1
	clc
	ret
no_clipping_1:
	stc
	ret


	public	put_brush
put_brush:
;draw a brush at cx,dx.
	call	no_clipping		;see if we need to clip
	jc	put_brush_clip_j_1	;go if we do.

	call	put_brush_setup

	cmp	pen.pnMode,offset xor_verb
	je	put_brush_xor_j_1
	cmp	pen.pnSize.h,8		;if it's more than 8 bits wide,
	ja	put_brush_copy_triple	;  it might overlap three bytes.
	sub	bp,si
	sub	bp,2
	jmp	short put_brush_copy_double	;otherwise do two bytes.
put_brush_clip_j_1:
	jmp	put_brush_clip
put_brush_xor_j_1:
	jmp	put_brush_xor
put_brush_copy_triple:
  if black_on_white
	cmp	this_fillPat,offset white_pat
  else
	cmp	this_fillPat,offset black_pat
  endif
	jne	put_brush_copy_triple_3
;handle black pattern efficiently.
put_brush_copy_triple_1:
	lodsw
	not	ax
	and	es:[di],ax
;now do the third byte.
	lodsb
	not	al
	and	es:[di+2],al
	add	di,screen_bytes			;go down to next line.
	loop	put_brush_copy_triple_1
	ret
put_brush_copy_triple_3:
  if black_on_white
	cmp	this_fillPat,offset black_pat
  else
	cmp	this_fillPat,offset white_pat
  endif
	jne	put_brush_copy_triple_4
;handle white pattern efficiently.
put_brush_copy_triple_5:
	lodsw
	or	es:[di],ax
;now do the third byte.
	lodsb
	or	es:[di+2],al
	add	di,screen_bytes			;go down to next line.
	loop	put_brush_copy_triple_5
	ret
;handle arbitrary pattern.
put_brush_copy_triple_4:
	lodsw
	not	ax
	and	es:[di],ax
	not	ax
	and	ax,[bp]
	or	es:[di],ax
;now do the third byte.
	lodsb
	not	al
	and	es:[di+2],al
	not	al
	and	al,[bp]
	or	es:[di+2],al
	add	bp,2
	add	di,screen_bytes			;go down to next line.
	loop	put_brush_copy_triple_4
	ret
put_brush_copy_double:
	lodsw				;get the mask
	mov	dx,[bp+si]		;get the pattern
	mov	bx,es:[di]		;get the dest
	xor	dx,bx			;flip the bits set in the dest.
	and	dx,ax			;exclude the mask
	xor	bx,dx			;flip the bits back.
	mov	es:[di],bx
	add	di,screen_bytes			;go down to next line.
	loop	put_brush_copy_double
	ret
put_brush_xor:
	cmp	pen.pnSize.h,8
	ja	put_brush_xor_triple
	sub	bp,si
	sub	bp,2
	jmp	short put_brush_xor_double
put_brush_xor_triple:
	lodsw
	and	ax,[bp]
	xor	es:[di],ax
	add	di,2
	lodsb
	and	al,[bp]
	add	bp,2
	xor	es:[di],al
	add	di,screen_bytes			;go down to next line.
	loop	put_brush_xor_triple
	ret
put_brush_xor_double:
	lodsw
	and	ax,[bp+si]
	xor	es:[di],ax
	add	di,screen_bytes			;go down to next line.
	loop	put_brush_xor_double
put_brush_clip_done_1:
	ret
put_brush_clip:
	mov	ax,[bx].left		;any part of brush on screen?
	sub	ax,pen.pnSize.h
	cmp	cx,ax			;too far to left?
	jl	put_brush_clip_done_1	;yes.
	mov	ax,[bx].top
	sub	ax,pen.pnSize.v
	cmp	dx,ax			;too far above?
	jl	put_brush_clip_done_1	;yes.
	cmp	cx,[bx].right		;too far to right?
	jge	put_brush_clip_done_1	;yes.
	cmp	dx,[bx].bot		;too far below?
	jge	put_brush_clip_done_1	;yes.

	push	cx
	push	dx
	call	make_mask
	pop	dx
	pop	cx

	mov	di,[bx].top		;compute the top size.
	sub	di,dx			;is there anything above the top?
	jge	put_brush_clip_7	;yes.
	mov	di,0			;no - nothing falls above the top.
put_brush_clip_7:

	mov	ax,dx			;compute the bottom size.
	add	ax,pen.pnSize.v
	sub	ax,[bx].bot		;are we really below the bottom?
	jge	put_brush_clip_6	;yes.
	mov	ax,0			;no - nothing falls below the bottom.
put_brush_clip_6:
	push	ax
	push	di
	push	cx
	call	put_brush_setup
	pop	bx
	pop	dx
	pop	ax
	sub	cx,ax			;subtract off the bottom size.
	jle	put_brush_clip_done
	sub	cx,dx			;subtract off the top size.
	jle	put_brush_clip_done
	add	bp,dx			;adjust the pointers.  We can't just
	add	bp,dx			;  double it and add once because we
	add	si,dx			;  might need to add 3*dx to si.
	add	si,dx

	push	dx
	mov	ax,screen_bytes		;multiply vertical position by screen_bytes.
	mul	dx
	add	di,ax			;leave it in di.
	pop	dx

	sar	bx,1
	sar	bx,1
	sar	bx,1
	add	bx,offset a_scan_line

	cmp	pen.pnMode,offset xor_verb
	je	put_brush_clip_xor
	cmp	pen.pnSize.h,8		;if it's more than 8 bits wide,
	ja	put_brush_clip_triple	;  it might overlap three bytes.
	sub	bp,si
	sub	bp,2
	jmp	short put_brush_clip_double	;otherwise do two bytes.
put_brush_clip_triple:
	add	si,dx
put_brush_clip_triple_1:
	lodsw
	and	ax,[bx]
	not	ax
	and	es:[di],ax
	not	ax
	and	ax,[bp]
	or	es:[di],ax
;now do the third byte.
	lodsb
	and	al,[bx+2]
	not	al
	and	es:[di+2],al
	not	al
	and	al,[bp]
	or	es:[di+2],al
	add	bp,2
	add	di,screen_bytes			;go down to next line.
	loop	put_brush_clip_triple_1
put_brush_clip_done:
	ret
put_brush_clip_double:
	lodsw
	and	ax,[bx]
	not	ax
	and	es:[di],ax
	not	ax
	and	ax,[bp+si]
	or	es:[di],ax
	add	di,screen_bytes			;go down to next line.
	loop	put_brush_clip_double
	ret
put_brush_clip_xor:
;for now, ignore xor.
	ret



put_brush_setup:
;enter with cx, dx=place to put the brush.
;exit with si->pattern to put,
;  es:di=first byte on screen,
;  bp->fill pattern, cx=brush height.
	mov	si,cx			;compute the bit offset.
	and	si,7
	mov	ax,si			;save a copy.
	shl	si,1			;*2
	cmp	pen.pnSize.h,8		;triple?
	jbe	put_brush_setup_1	;no.
	add	si,ax			;yes - *3
	shl	si,1			;*6 - 6*8=48
put_brush_setup_1:
	shl	si,1			;*8
	shl	si,1
	shl	si,1			;shifted pens contain words.
	lea	si,pnPat[si]

	push	dx
	mov	ax,screen_bytes		;multiply vertical position by screen_bytes.
	mul	dx
	mov	di,ax			;leave it in di.
	pop	dx

	mov	bp,dx			;compute pen mask offset.
	and	bp,7
	shl	bp,1			;addressing words.
	add	bp,offset fillPat_block

	mov	dx,cx			;compute the byte offset.
	sar	dx,1
	sar	dx,1
	sar	dx,1
	add	di,dx			;ensure that di is index into screen.

	mov	cx,pen.pnSize.v

	mov	ax,screen_seg		;any color plane will do.
	mov	es,ax
	ret


make_mask:
;enter with bx->clipping rect.
;exit with a_scan_line set properly.
;doesn't work for zero-width rects.
	push	ds
	pop	es

	mov	di,offset a_scan_line	;start with all zeroes.
	xor	ax,ax
	mov	cx,80/2
	rep	stosw

	mov	di,[bx].left		;compute first byte to have ones in it.
	mov	cx,di
	shr	di,1
	shr	di,1
	shr	di,1
	lea	di,a_scan_line[di]

	and	cl,7			;compute the first bit to set.
	mov	dl,80h			;put a one in bit 7
	shr	dl,cl			;shift it to the right place.

	mov	cx,[bx].right		;compute the number of bits.
	sub	cx,[bx].left
	xor	al,al			;start with no bits.
make_mask_6:
	or	al,dl			;get the bit.
	dec	cx			;dec bit count.
	jle	make_mask_7		;leave if done. (je would have done.)
	rcr	dl,1			;move the bit to the right.
	jnc	make_mask_6		;continue if it didn't fall off the end
make_mask_7:
	stosb				;store the first mask byte.
	ror	cx,1			;get cl=# of bytes to set.
	ror	cx,1
	ror	cx,1
	rol	ch,1			;get ch=# of bits to set.
	rol	ch,1
	rol	ch,1
	push	cx			;save ch (and cl) for later.
	xor	ch,ch			;extend cl into cx.
	mov	al,0ffh			;yes - rip them off.
	rep	stosb
	pop	cx			;get the bit count back.
	mov	dl,80h			;get dl= the leftmost bit in a byte.
	xor	al,al			;start with no bits set.
make_mask_5:
	dec	ch			;predecrement the count.
	jl	make_mask_4		;leave if finished.
	or	al,dl			;get this bit in.
	shr	dl,1			;move the bit to the right.
	jmp	make_mask_5		;and continue
make_mask_4:
	stosb				;store the last mask byte.
	ret


	public	get_rotate
get_rotate:
;enter with bx->rectangle to get, si->place to put the rect.
;exit with si->after last byte used.
	call	get_setup

	mov	[si].h,cx		;save x size
	mov	[si].v,bp		;save y size.
	add	si,(size point)

	push	bx

	push	dx
	mov	ax,screen_bytes
	mul	cx
	add	di,ax			;move down that many lines.
	pop	dx

	mov	cl,dl			;get the first bit into dl.
	mov	dl,80h
	shr	dl,cl
get_rotate_1:
	mov	cx,line_count
	call	rotate_line
	ror	dl,1			;move over one bit.
	adc	di,0			;if needed, move over a byte.
	dec	bit_count
	jne	get_rotate_1
	pop	bx
	ret


rotate_line:
;cx=number of scan lines, es:[di].dl is the bit to test, ds:si->array.
	push	di
	mov	al,1			;start with just a marker bit.
rotate_line_1:
	sub	di,screen_bytes			;back up a line.
	test	es:[di],dl		;test clears cy,
	je	rotate_line_2		;  so if the bit is set,
	stc				;  then we have to set cy.
rotate_line_2:
	rcl	al,1			;shift a new bit in, and an old out.
	jnc	rotate_line_3		;not the marker bit yet.
	mov	[si],al			;store the byte,
	inc	si			;  and move to the next byte.
	mov	al,1			;start with just a marker bit.
rotate_line_3:
	loop	rotate_line_1
	cmp	al,1			;do we have just the marker?
	je	rotate_line_5		;yes - don't bother storing.
rotate_line_4:
	shl	al,1			;rotate until we get the marker bit.
	jnc	rotate_line_4
	mov	[si],al			;finish off the last byte.
	inc	si
rotate_line_5:
	pop	di
	ret


	public	get_flip_h
get_flip_h:
;enter with bx->rectangle to get, si->place to put the rect.
;exit with si->after last byte used.
	call	get_setup

	mov	[si].h,bp		;save x size
	mov	[si].v,cx		;save y size.
	add	si,(size point)

	push	bx
get_flip_h_1:
	mov	bp,bit_count
	call	flip_line
	add	di,screen_bytes
	dec	line_count
	jne	get_flip_h_1
	pop	bx
	ret


flip_line:
;bp is count of bits, es:di->color plane, ds:si->array, dl=alignment of array.
;exit with di unchanged.
;can destroy bp, ax, cx, dh.
	push	di
	push	dx
	mov	dh,0
	add	dx,bp			;dx is now the distance in bits.
	mov	cl,dl
	shr	dx,1
	shr	dx,1
	shr	dx,1
	add	di,dx			;di now ->last byte.
	and	cl,7
	mov	dl,80h
	shr	dl,cl			;dl now ->last bit.
	mov	al,1			;start with just a marker bit.
flip_line_1:
	rol	dl,1			;back up by one bit.
	jnc	flip_line_0
	dec	di			;back up over a byte boundary.
flip_line_0:
	test	es:[di],dl		;test clears cy,
	je	flip_line_2		;  so if the bit is set,
	stc				;  then we have to set cy.
flip_line_2:
	rcl	al,1			;shift a new bit in, and an old out.
	jnc	flip_line_3		;not the marker bit yet.
	mov	[si],al			;store the byte,
	inc	si			;  and move to the next byte.
	mov	al,1			;get the marker bit back again.
flip_line_3:
	dec	bp
	jne	flip_line_1
	cmp	al,1			;do we have just the marker?
	je	flip_line_5		;yes - don't bother storing.
flip_line_4:
	shl	al,1			;rotate until we get the marker bit.
	jnc	flip_line_4
	mov	[si],al			;finish off the last byte.
	inc	si
flip_line_5:
	pop	dx
	pop	di
	ret


	public	get_rect
get_rect:
;enter with bx->rectangle to get, si->place to put the rect.
;exit with si->after last byte used.
	call	get_setup

	mov	[si].h,bp		;save x size
	mov	[si].v,cx		;save y size.
	add	si,(size point)

	mov	cl,dl			;align to array byte.
	add	bp,7			;round up to next highest byte.
	shr	bp,1			;convert bits to byte.
	shr	bp,1			;. .
	shr	bp,1			;. .
;bp is count of bytes, es:di->color plane, ds:si->array, cl=alignment of array.
	mov	dx,line_count		;keep the count of lines in dx.

	mov	ax,screen_bytes		;width of source bitmap in bytes
	sub	ax,bp			;width of rectangle in bytes
	mov	byte_count,ax		;distance from right edge to left edge.

	push	bx
	push	ds
	push	es
	pop	ds
	pop	es
	xchg	si,di
get_rect_1:
	mov	bx,bp			;get the width in bytes.
get_rect_2:
	mov	ax,[si]
	inc	si
	rol	ax,cl
	stosb
	dec	bx			;done with this scan line?
	jne	get_rect_2		;no.
	add	si,es:byte_count
	dec	dx
	jne	get_rect_1
	push	es
	pop	ds
	mov	si,di
	pop	bx
	ret


get_setup:
;enter with bx->rect.
;exit with dl=bit alignment, line_count=cx=number of scan lines,
;  bit_count=bp=number of bits in h,
;  es:di->screen byte.
	mov	bp,[bx].right
	sub	bp,[bx].left
	mov	bit_count,bp

	mov	dx,[bx].bot
	sub	dx,[bx].top
	mov	line_count,dx

;ensure that we have enough room in the array.
	mov	ax,bp			;get the x size.
	add	ax,7			;round up to nearest byte.
	shr	ax,1			;eight bits/byte.
	shr	ax,1
	shr	ax,1
	mul	dx
	add	ax,4			;allow room for x and y sizes.
  if 0
	cmp	ax,free_space		;does it fit in the array that's given?
	jbe	get_3			;yes.
	jmp	g_error
get_3:
  endif

	load2	[bx].topleft
	call	point_to_pointer
	mov	dx,bp			;return the bit alignment in dx.

	mov	cx,line_count
	mov	bp,bit_count

	ret


put_sized:
	mov	compression,1		;assume we're compressing zeroes.
	mov	not_compression,0
	cmp	put_byte_subr,offset pset_verb
	jne	put_sized_1
	mov	compression,-1		;we're compressing ones
	mov	not_compression,1
put_sized_1:

	mov	ax,bit_count
	mov	old_x_size,ax		;remember the old h size.

	mov	cx,src_align
	mov	al,80h
	shr	al,cl
	mov	src_left_bit,al

	mov	ax,[di].right		;compute the new h size.
	sub	ax,[di].left
	mov	new_x_size,ax		;remember the new h size.

	mov	dest_align,bp		;remember the destination alignment.
	mov	cx,bp			;compute the dest left bit.
	mov	al,80h
	shr	al,cl
	mov	dest_left_bit,al

	mov	ax,[di].bot		;compute the new v size.
	sub	ax,[di].top

	cmp	ax,line_count		;which is larger?
	jb	put_shrink_1		;go if we're shrinking
;expand it here.  We have more lines in the dest than the source.
	mov	bx,line_count		;don't include the last scan line.
	mov	smaller_delta,bx

	mov	larger_delta,ax
	mov	line_count,ax
	mov	epsilon,0

	call	blit_setup
	mov	src_seg,ax

	mov	bx,src_bytes
	mov	scan_line_count,bx
put_expand_2:
	push	si
	push	di
	call	put_sized_line
	pop	di
	pop	si

	mov	bx,epsilon
	mov	dx,larger_delta
	add	bx,smaller_delta
	cmp	bx,dx			;past the larger yet?
	jl	put_expand_3		;no.
	sub	bx,dx			;yes - subtract it.
	add	si,src_bytes		;advance to next line.
put_expand_3:
	mov	epsilon,bx

	add	di,dest_bytes
	dec	line_count
	jne	put_expand_2
	ret

put_shrink_1:
;shrink it here.  We have more lines in the source than in the dest.
	mov	smaller_delta,ax

	mov	ax,line_count
	mov	larger_delta,ax
	mov	epsilon,0

	call	blit_setup
	mov	src_seg,ax

	mov	scan_line_count,0

put_shrink_2:
	mov	bx,src_bytes
	add	scan_line_count,bx	;include another scan line in the processing.

	mov	bx,epsilon
	mov	dx,larger_delta
	add	bx,smaller_delta
	mov	epsilon,bx
	cmp	bx,dx			;past the larger yet?
	jl	put_shrink_3		;no.
	sub	bx,dx			;yes - subtract it off.
	mov	epsilon,bx

	push	si
	push	di
	call	put_sized_line
	pop	di
	pop	si

	add	si,scan_line_count	;move the source down a line.
	mov	scan_line_count,0

	add	di,dest_bytes		;move to the next line.

put_shrink_3:
	dec	line_count
	jne	put_shrink_2
	ret


put_sized_line:
;ds:si->array, es:di->screen, bp=destination alignment,
;  scan_line_count=number of scan lines to process.
;don't destroy bp.

	mov	ax,new_x_size		;are we changing the x size?
	cmp	ax,old_x_size
	jb	put_smaller_line	;yes - it's shorter.
	ja	put_larger_line		;yes - it's longer.
	mov	bx,ax
	mov	bp,dest_align		;get the destination alignment.
	jmp	put_scan_line		;no - same size.

put_larger_line:
	mov	larger_line,ax		;new is larger.
	mov	bit_count,ax
	xor	bx,bx

	mov	ax,old_x_size
	mov	smaller_line,ax

	mov	dl,dest_left_bit
	mov	dh,src_left_bit		;dh=source mask.

	mov	cx,bit_count

	push	ds
	mov	ds,src_seg
	assume	ds:nothing

	mov	ah,[si]			;get the first source byte.
	inc	si
put_larger_line_1:

	xor	al,al
	test	dh,ah			;is the source bit set?
	je	put_larger_line_2	;no.
	mov	al,dl			;yes - get the dest bit in question.
put_larger_line_2:
	call	put_byte_subr		;put this byte.

	add	bx,smaller_line
	cmp	bx,larger_line
	jb	put_larger_line_3
	sub	bx,larger_line

	ror	dh,1			;move over a source bit.
	jnc	put_larger_line_3
	mov	ah,[si]
	inc	si
put_larger_line_3:

	ror	dl,1			;move over a dest bit.
	adc	di,0			;if cy, move over in di.
	loop	put_larger_line_1	;no.

	cmp	dh,80h			;did we use any of the source bits?
	jne	put_larger_line_5
	dec	si			;no - backup.
put_larger_line_5:
	pop	ds
	assume	ds:data
	ret


put_smaller_line:
	mov	smaller_line,ax

	mov	ax,old_x_size
	mov	larger_line,ax
	mov	bit_count,ax
	xor	bx,bx

	mov	cx,bit_count

	mov	dl,dest_left_bit
	mov	dh,src_left_bit		;dh=source mask.

	push	ds
	mov	ds,src_seg
	assume	ds:nothing

	mov	ah,7fh			;init the sampling sum.
put_smaller_line_1:

	push	bx

	mov	bx,0
put_smaller_line_6:
	add	ah,not_compression
	test	[si+bx],dh		;is the source bit set?
	je	put_smaller_line_2	;no.
	add	ah,compression		;yes - count this bit.
put_smaller_line_2:
	add	bx,src_bytes		;move down a scan line.
	cmp	bx,scan_line_count	;have we done all of them?
	jne	put_smaller_line_6	;no.

	pop	bx

	add	bx,smaller_line
	cmp	bx,larger_line
	jb	put_smaller_line_4
	sub	bx,larger_line

	xor	al,al			;assume not set.
	xor	ah,compression		;flip the sense if necessary.
	test	ah,80h			;more ones than zeroes?
	je	put_smaller_line_3	;no.
	mov	al,dl			;yes - set this bit.
put_smaller_line_3:
	call	put_byte_subr		;put this byte.
	mov	ah,7fh			;init the sampling sum.

	ror	dl,1			;move over a dest bit.
	adc	di,0			;if cy, move over in di.
put_smaller_line_4:

	ror	dh,1			;move over a source bit.
	adc	si,0
	loop	put_smaller_line_1	;no.

	cmp	dh,80h			;did we use any of the dest bits?
	je	put_smaller_line_5	;no.
	inc	si			;yes - skip to next byte.
put_smaller_line_5:
	pop	ds
	assume	ds:data
	ret


put_sized_j_1:
	jmp	put_sized

blit_1:
	ret
	public	blit
blit:
;enter with si->source bitmap, di->dest bitmap, put_byte_subr=transfer mode.
	mov	ax,[si].right		;compute the h size.
	sub	ax,[si].left
	je	blit_1			;if empty, exit now.
	mov	bit_count,ax
	mov	ax,[si].bot		;compute the v size.
	sub	ax,[si].top
	je	blit_1			;if empty, exit now.
	mov	line_count,ax

	mov	bp,[di].left		;compute the destination alignment.
	and	bp,7

	mov	ax,[si].left		;compute the source alignment.
	and	ax,7
	mov	src_align,ax

	mov	ax,[si].bytes		;get the source width.
	mov	src_bytes,ax

	mov	ax,[di].bytes		;get the destination width.
	mov	dest_bytes,ax

	mov	ax,[di].right		;are we changing the h size?
	sub	ax,[di].left
	cmp	ax,bit_count
	jne	put_sized_j_1		;yes.
	mov	ax,[di].bot		;are we changing the v size?
	sub	ax,[di].top
	cmp	ax,line_count
	jne	put_sized_j_1		;yes.

	cmp	bit_count,8		;does it fit in one byte?
	jbe	blit_2			;yes - do it "quickly"
	jmp	compile_blit		;no - do it "slowly"
blit_2:
	call	blit_setup

	mov	dx,00ffh		;compute the mask.
	mov	cx,bit_count
	ror	dx,cl			;make the necessary number of bits.

	mov	dl,0			;get rid of the unnecessary bits.
	mov	cx,bp
	shr	dx,cl			;shift the mask to where it should be.

	mov	cx,bp			;shift count is dest align-src align.
	sub	cx,src_align
	and	cl,16-1			;only 16 bits in a register.

	mov	bx,put_byte_subr	;get the byte store routine.
	mov	bp,dest_bytes
	dec	bp
	push	ds			;save our data segment,
	mov	ds,ax			;  and get the source segment.
	assume	ds:nothing
blit_3:
	mov	ax,[si]			;get the byte into ax
	add	si,src_bytes		;move down a line.
	ror	ax,cl			;shift it to where it should be.
	xchg	dh,dl
;put the byte in al at es:di using the mask in dl
	call	bx			;bx=put_byte_subr
	inc	di			;move over one byte.
	xchg	dh,dl			;get the right mask.
	mov	al,ah			;get the right byte.
	call	bx			;bx=put_byte_subr
	add	di,bp			;bp=dest_bytes.
	dec	line_count
	jne	blit_3

	pop	ds
	assume	ds:data
	ret


copy_code	macro
	lodsw
	mov	cx,ax
	rep	movsb
	endm


	public	compile_blit
compile_blit:

	push	si
	push	di

	push	cs
	pop	es
	mov	di,offset put_rect_subr

;in the following code, bp is the destination alignment,
;  dx is the byte count, si and cx are scratch, bx is used temporarily,
;  and es:di->the code that we're compiling.

	cmp	bp,src_align
	je	compile_aligned
	jmp	compile_shifted
compile_aligned:
	push	di			;remember where to loop back to.

	mov	bx,bit_count		;get the number of bits left to do.

	or	bp,bp			;dest alignment zero?
	je	compile_aligned_2	;yes - don't mask on the left.

	mov	al,0b2h			;opcode of "mov dl,immed8"
	mov	cx,bp			;store the mask.
	mov	ah,0ffh
	shr	ah,cl
	stosw

	mov	al,0ach			;opcode of lodsb
	stosb

	mov	si,put_byte_subr	;compile the masked version.
	mov	si,cs:[si-2]
	copy_code

	add	bx,bp			;say that we've done the first few bits.
	sub	bx,8			;. .
compile_aligned_2:
	shr	bx,1			;truncate to an even number of bytes.
	shr	bx,1
	shr	bx,1
	cmp	put_byte_subr,offset pset_verb	;are we doing pset?
	jne	compile_aligned_7	;no - have to do it "slowly"

	shr	bx,1			;prepare to move words.
	jnc	compile_aligned_8	;is the count odd? go if not.
	mov	al,0a4h			;opcode of "movsb"
	stosb
compile_aligned_8:
	mov	al,0b9h			;opcode of "mov cx,immed16"
	stosb
	mov	ax,bx
	stosw
	mov	ax,0f3h + 0a5h*256	;opcode of "rep movsw"
	stosw
	jmp	short compile_aligned_5
compile_aligned_7:
	mov	dx,bx			;remember the total number of bytes.
	inc	bx			;round up.
	shr	bx,1			;remember the number of loop iterations.
	or	bx,bx			;are there any iterations at all?
	je	compile_aligned_5	;no - skip the loop.
	mov	al,0b9h			;opcode of "mov cx,immed16"
	stosb
	mov	ax,bx
	stosw

	test	dx,1			;do we need to jump to the second store?
	je	compile_aligned_6	;no.
	mov	ax,0ebh + 256*0		;opcode of "jmp short $+2"
	stosw
compile_aligned_6:

	mov	bx,di			;remember where the jump is.
;bx now holds the offset of the jump into the loop, which is also
;  the beginning of the loop.

	mov	al,0ach			;opcode of lodsb
	stosb

	mov	si,put_byte_subr	;compile the unmasked version.
	mov	si,cs:[si-4]		;get the address of it.
	copy_code

	test	dx,1			;are we jumping into the loop here?
	je	compile_aligned_4	;no.
	mov	ax,di			;yes - compute the jump offset.
	sub	ax,bx
	mov	cs:[bx-1],al		;store it.
compile_aligned_4:

	mov	al,0ach			;opcode of lodsb
	stosb

	mov	si,put_byte_subr	;compile the unmasked version.
	mov	si,cs:[si-4]		;get the address of it.
	copy_code

	mov	al,0e2h			;opcode of "loop"
	stosb

	mov	ax,bx			;compute the jump offset.
	sub	ax,di
	dec	ax			;because bx->jump offset, not afterward.
	stosb

compile_aligned_5:
	mov	cx,bit_count
	add	cx,bp			;dest_align
	and	cx,7			;does it align to a right edge?
	je	compile_aligned_1	;yes - skip the right mask.

;cx now holds the right mask bit count.
	mov	ax,00ffh		;rotate the bits into ah.
	ror	ax,cl
	mov	al,0b2h			;opcode of "mov dl,immed8"
	stosw

	mov	al,0ach			;opcode of lodsb
	stosb

	mov	si,put_byte_subr	;compile the masked version.
	mov	si,cs:[si-2]
	copy_code

compile_aligned_1:
	jmp	compile_blit_2		;join with the shifting code.


compile_shifted:
	mov	si,src_align		;use the proper get byte routine.
	sub	si,bp
	and	si,7			;only eight different ones.
	shl	si,1			;index into word table.
	mov	si,get_ptrs[si]
	mov	get_byte_ptr,si

	mov	al,0b1h			;opcode of "mov cl,immed8"
	stosb
	mov	ax,src_align		;shift count is src align-dest align.
	sub	ax,bp
	and	al,7			;don't shift too far.
	stosb

	cmp	bp,src_align		;if we're shifting right, we need to
	jbe	compile_shifted_0	;  backup the source by one.
	mov	al,4eh			;opcode of "dec si"
	stosb
compile_shifted_0:

	push	di			;remember where the loop code starts.

	mov	bx,bit_count		;get the bit count.

	or	bp,bp			;is dest alignment zero?
	je	compile_shifted_2	;yes - don't bother masking the left.

	mov	al,0b2h			;opcode of "mov dl,immed8"
	mov	cx,bp			;store the mask.
	mov	ah,0ffh
	shr	ah,cl
	stosw

	mov	si,get_byte_ptr		;compile the code to get a byte.
	copy_code

	mov	si,put_byte_subr	;compile the masked version.
	mov	si,cs:[si-2]
	copy_code

	add	bx,bp			;say that we've done the first few bits.
	sub	bx,8			;. .
compile_shifted_2:

	shr	bx,1			;truncate to an even number of bytes.
	shr	bx,1
	shr	bx,1
	mov	dx,bx			;remember the total number of bytes.
	inc	bx			;round up.
	shr	bx,1			;remember the number of loop iterations.
	or	bx,bx			;are there any iterations at all?
	je	compile_shifted_5	;no - skip the loop.

	mov	al,0bbh			;opcode of "mov bx,immed16"
	stosb
	mov	ax,bx
	stosw

	test	dx,1			;do we need to jump to the second store?
	je	compile_shifted_6	;no.
	mov	ax,0ebh + 256*0		;opcode of "jmp short $+2"
	stosw
compile_shifted_6:

	mov	bx,di			;remember where the jump is.
;bx now holds the offset of the jump into the loop, which is also
;  the beginning of the loop.

	mov	si,get_byte_ptr		;compile the code to get a byte.
	copy_code

	mov	si,put_byte_subr	;compile the unmasked version.
	mov	si,cs:[si-4]		;get the address of it.
	copy_code

	test	dx,1			;are we jumping into the loop here?
	je	compile_shifted_4	;no.
	mov	ax,di			;yes - compute the jump offset.
	sub	ax,bx
	mov	cs:[bx-1],al		;store it.
compile_shifted_4:

	mov	si,get_byte_ptr		;compile the code to get a byte.
	copy_code

	mov	si,put_byte_subr	;compile the unmasked version.
	mov	si,cs:[si-4]		;get the address of it.
	copy_code

	mov	ax,4bh + 256*75h	;opcodes of "dec bx" and "jne"
	stosw

	mov	ax,bx			;compute the jump offset.
	sub	ax,di
	dec	ax			;because bx->jump offset, not afterward.
	stosb

compile_shifted_5:
	mov	cx,bit_count
	add	cx,bp			;dest_align
	and	cx,7			;does it align to a right edge?
	je	compile_blit_2		;yes - skip the right mask.

;bx now holds the right mask bit count.
	mov	ax,00ffh		;rotate the bits into ah.
	ror	ax,cl
	mov	al,0b2h			;opcode of "mov dl,immed8"
	stosw

	mov	si,get_byte_ptr		;compile the code to get a byte.
	copy_code

	mov	si,put_byte_subr	;compile the masked version.
	mov	si,cs:[si-2]
	copy_code

compile_blit_2:
;compute the number of bytes that we've affected.
	mov	ax,81h+11000111b*256	;opcode of "add di,immed16"
	stosw

	mov	bx,bit_count		;get the bit count.
	add	bx,bp			;add align (take care of left edge)
	add	bx,7			;round up (take care of right edge)
	shr	bx,1
	shr	bx,1
	shr	bx,1

	mov	ax,dest_bytes		;get the width of the dest bitmap.
	sub	ax,bx			;sub the number of bytes we've done.
	stosw				;ax=# bytes to next line.

	mov	ax,81h+11000110b*256	;opcode of "add si,immed16"
	stosw

	mov	ax,src_bytes		;get the width of the dest bitmap.
	sub	ax,bx			;sub the number of bytes we've done.
	stosw				;ax=# bytes to next line.

	mov	ax,4dh + 256*75h	;opcodes of "dec bp" and "jne"
	stosw

	pop	ax			;jump back to the beginning.
	sub	ax,di			;subtract target-(di+1),
	dec	ax			;  because di->after opcode, not operand
	stosb				;store the jump offset

;if we're shifting right, include the following code:
	cmp	bp,src_align		;are we shifting right?
	jbe	compile_blit_3		;no.
	mov	al,46h			;opcode of "inc si"
	stosb
compile_blit_3:

	mov	ax,01fh + 0c3h*256	;opcodes of "pop ds" and  "ret"
	stosw

	pop	di			;restore the bitmap pointers.
	pop	si

	mov	bp,line_count		;get the scan line count.
	call	blit_setup
	push	ds
	mov	ds,ax

put_rect_subr:
	db	100h dup(90h)


blit_setup:
;enter with ds:si->source bitmap, ds:di->dest bitmap.
;exit with ax:si->source bits, es:di->dest bits
	mov	bx,[di].left		;get x
	shr	bx,1			;get rid of bit position
	shr	bx,1
	shr	bx,1
	mov	ax,[di].top		;compute y-position*dest_bytes
	mul	[di].bytes
	add	bx,ax
	les	di,[di].pntr		;get the pointer to the bitmap.
	add	di,bx			;add the offset into the bitmap.

	mov	bx,[si].left		;get x
	shr	bx,1			;get rid of bit position
	shr	bx,1
	shr	bx,1
	mov	ax,[si].top		;compute y-position*src_bytes
	mul	[si].bytes
	add	bx,ax
	mov	ax,[si].pntr.segm	;get the segment into ax.
	mov	si,[si].pntr.offs	;get the offset into si.
	add	si,bx			;add the offset into the bitmap.
	ret


	public	put_scan_line
put_scan_line:
;ds:si->array, es:di->screen, bx=bit count, bp=destination alignment
;don't destroy bp.
	mov	cx,bp			;get destination alignment.
	jcxz	put_noshift		;go if it aligns.
	mov	dl,0ffh			;al=source mask
	shr	dl,cl
	mov	al,[si]			;dh=source byte
	shr	al,cl			;align to screen byte.
	add	bx,bp			;pretend that we've done a whole byte.
	sub	bx,8			;more bytes?
	jle	put_scan_line_2
	mov	cx,8			;make cl=8-shift count.
	sub	cx,bp
	cmp	put_byte_subr,offset pset_verb
	je	put_scan_line_8
	call	put_byte_subr
	inc	di			;go to the next byte.
	mov	dl,0ffh			;eight bits in the rest of the bytes.
	jmp	short put_scan_line_5
put_scan_line_8:
	mov	ah,es:[di]		;get the dest byte.
	xor	al,ah			;flip the pattern using the dest bits.
	and	al,dl			;get rid of the bits we won't change.
	xor	al,ah			;flip using only the bits that change.
put_scan_line_7:
	stosb
	mov	ax,[si]			;get the next two bytes.
	inc	si			;go to the this byte.
	rol	ax,cl			;align to screen byte.
	sub	bx,8			;more bytes?
	ja	put_scan_line_7		;yes - keep doing them
	mov	dl,0ffh			;eight bits in the next byte.
	jmp	short put_scan_line_2	;no - finish off the last.
put_scan_line_4:
;put the byte in al at es:di using the mask in dl
	call	put_byte_subr
	inc	di
put_scan_line_5:
	mov	ax,[si]			;get the next two bytes.
	inc	si			;go to the next byte.
	rol	ax,cl			;align to screen byte.
	sub	bx,8			;more bytes?
	ja	put_scan_line_4		;yes - keep doing them
put_scan_line_2:
	add	bx,8
	mov	cl,bl
	shr	dl,cl
	not	dl			;we're not including the bits to the right.
	call	put_byte_subr
	cmp	bp,bx			;did we use any bits from the right byte.
	jae	put_scan_line_3		;no.
	inc	si			;yes - skip past it.
put_scan_line_3:
	ret


put_noshift:
;ds:si->array, es:di->screen, bx=bit count, bp=destination alignment (0).
	mov	dl,0ffh			;eight bits in the rest of the bytes.
	mov	cx,bx
	shr	cx,1
	shr	cx,1
	shr	cx,1
	and	bx,7
	jcxz	put_noshift_2
	cmp	put_byte_subr,offset pset_verb
	jne	put_noshift_4
	shr	cx,1			;move words.
	jnc	put_noshift_1
	movsb
put_noshift_1:
	rep	movsw
	jmp	short put_noshift_2
put_noshift_4:
;put the byte in al at es:di using the mask in dl
	lodsb
	call	put_byte_subr
	inc	di
	loop	put_noshift_4
put_noshift_2:
	mov	cx,bx			;get the number of bits in the next byte.
	jcxz	put_noshift_3		;if none, just skip.
	mov	al,[si]
	inc	si
	mov	dx,0ff00h		;shift the bits in from ah.
	shr	dx,cl
	call	put_byte_subr
put_noshift_3:
	ret


;note that the two words previous to the given verb must be the offsets
;  (in the data segment!) of two routines.  The first (cs:put_byte_subr-4) is
;  a routine that puts the byte in al with a mask of 0ffh.  The second
;  (cs:put_byte_subr-2) is a routine that puts the byte in al using the mask
;  in dl.

;new    old
;    | 0   1
;-----------
;  0 | 0   0
;  1 | 1   1
	dw	pset_verb_1
	dw	pset_verb_2
	public	pset_verb
pset_verb:
	xor	al,es:[di]
	and	al,dl
	xor	es:[di],al
	ret


;new    old
;    | 0   1
;-----------
;  0 | 0   1
;  1 | 0   0
	dw	and_not_verb_1
	dw	and_not_verb_2
	public	and_not_verb
and_not_verb:
	not	al
	not	dl
	or	al,dl
	not	dl
	and	es:[di],al
	ret


;new    old
;    | 0   1
;-----------
;  0 | 1   1
;  1 | 0   0
	dw	preset_verb_1
	dw	preset_verb_2
	public	preset_verb
preset_verb:
	not	al
	xor	al,es:[di]
	and	al,dl
	xor	es:[di],al
	ret


;new    old
;    | 0   1
;-----------
;  0 | 0   0
;  1 | 0   1
	dw	and_verb_1
	dw	and_verb_2
	public	and_verb
and_verb:
	not	dl
	or	al,dl
	not	dl
	and	es:[di],al
	ret


;new    old
;    | 0   1
;-----------
;  0 | 0   1
;  1 | 1   1
	dw	or_verb_1
	dw	or_verb_2
	public	or_verb
or_verb:
	and	al,dl			;only set the bits given in dl.
	or	es:[di],al
	ret


;new    old
;    | 0   1
;-----------
;  0 | 1   1
;  1 | 0   1
	dw	or_not_verb_1
	dw	or_not_verb_2
	public	or_not_verb
or_not_verb:
	not	al
	and	al,dl			;only set the bits given in dl.
	or	es:[di],al
	ret


;new    old
;    | 0   1
;-----------
;  0 | 0   1
;  1 | 1   0
	dw	xor_verb_1
	dw	xor_verb_2
	public	xor_verb
xor_verb:
	and	al,dl			;only xor the bits given in dl.
	xor	es:[di],al
	ret


	public	invert_rect
invert_rect:
;enter with bx->rect to invert.
  if black_on_white
	mov	si,offset black_pat
  else
	mov	si,offset white_pat
  endif
	call	make_fillPat
	mov	put_byte_subr,offset xor_verb
	call	bitopt_rect
	ret


	public	fill_rect
fill_rect:
	mov	put_byte_subr,offset pset_verb
	call	bitopt_rect
	ret


	public	halftone_rect
halftone_rect:
	mov	si,offset gray_pat
	call	make_fillPat
  if black_on_white
	mov	put_byte_subr,offset or_verb
  else
	mov	put_byte_subr,offset and_not_verb
  endif
	call	bitopt_rect
	ret


	public	clear_rect
clear_rect:
	mov	si,offset black_pat
	call	make_fillPat
	mov	put_byte_subr,offset pset_verb
	call	bitopt_rect
	ret


bitopt_rect:
;enter with bx->rect to operate on.
	push	bx
	call	protect_mouse
	load2	[bx].topleft
	store2	temp.topleft
	mov	bp,[bx].right
	sub	bp,cx
	mov	dx,[bx].bot
	mov	temp.bot,dx
	mov	bx,bp			;put the bit count where bitopt wants it.
bitopt_rect_1:
	load2	temp.topleft
	cmp	dx,temp.bot
	jae	bitopt_rect_2
	push	bx
	call	bitopt_line
	pop	bx
	inc	temp.top
	jmp	bitopt_rect_1
bitopt_rect_2:
	pop	bx
	call	unprotect_mouse
	ret


	public	bitopt_line
bitopt_line:
;enter with cx,dx=point, bx=number of bits to right of this point.
	call	point_to_pointer

	and	dx,7			;get the low 3 bits of y
	shl	dx,1			;addressing words.
	mov	si,dx
	mov	al,fillPat_block[si]	;get the byte of the fill pattern.
	mov	ah,al			;save the pattern.

	mov	cx,bp			;get destination alignment.
	mov	dl,0ffh			;al=source mask
	shr	dl,cl

	add	bx,bp			;pretend that we've done a whole byte.
	sub	bx,8			;more bytes?
	jb	bitopt_line_1		;no - finish off last byte.
	call	put_byte_subr
	inc	di
	mov	dl,0ffh			;eight bits in the rest of the bytes.
	mov	cx,bx
	shr	cx,1
	shr	cx,1
	shr	cx,1
	jcxz	bitopt_line_1
	cmp	put_byte_subr,offset pset_verb	;are we forcing bits?
	jne	bitopt_line_2		;no - have to do it slowly.
	mov	al,ah			;yes - rip them off.
	rep	stosb
	mov	dl,0ffh			;start with eight bits in the next byte.
	jmp	short bitopt_line_1
bitopt_line_2:
	mov	al,ah
	call	put_byte_subr
	inc	di			;go to the next byte.
	loop	bitopt_line_2
	jmp	short bitopt_line_1
bitopt_line_1:
	and	bx,7
	mov	al,ah			;get the pattern.
	mov	ah,dl			;remember the bits we're affecting.
	mov	dl,0ffh			;shift some new bits in.
	mov	cl,bl
	shr	dl,cl
	xor	dl,ah			;we're not including the bits to the right.
	call	put_byte_subr
	ret


	public	point_to_pointer
point_to_pointer:
;enter with cx,dx=point.
;exit with di->byte, bp=bit alignment.
	mov	ax,screen_seg	;get the green plane.
	mov	es,ax
	mov	di,cx		;get x
	shr	di,1		;get rid of bit position
	shr	di,1
	shr	di,1
	push	dx
	mov	ax,screen_bytes		;compute y-position*screen_bytes
	mul	dx
	pop	dx
	add	di,ax
	and	cx,7		;get the low 3 bits of x
	mov	bp,cx
	ret


if 0
	public	invert_rgn
invert_rgn:
;enter with bx->rgn to invert.
	mov	si,offset white_pat
	call	make_fillPat
	mov	put_byte_subr,offset xor_verb
	call	bitopt_rgn
	ret


	public	fill_rgn
fill_rgn:
	mov	put_byte_subr,offset pset_verb
	call	bitopt_rgn
	ret


	public	halftone_rgn
halftone_rgn:
	mov	si,offset gray_pat
	call	make_fillPat
	mov	put_byte_subr,offset and_not_verb
	call	bitopt_rgn
	ret


	public	clear_rgn
clear_rgn:
	mov	si,offset black_pat
	call	make_fillPat
	mov	put_byte_subr,offset pset_verb
	call	bitopt_rgn
	ret


bitopt_rgn:
;enter with bx->region to operate on.
	push	bx
	call	protect_mouse
	load2	[bx].botright		;remember the bottom right.
	store2	temp.botright
	load2	[bx].topleft
	mov	temp.left,cx
	sub	dx,4			;??? This is the mystery kludge of the week...
	add	bx,(size rect)		;point to start of y-bucket pointers.
bitopt_rgn_1:
	cmp	dx,temp.bot
	ja	bitopt_rgn_end
	mov	cx,temp.left
	mov	di,[bx]			;di->start of this y-bucket data.
	add	cx,[di]			;add the first "not-in" bits.
	add	di,2			;no - look at next "in" bits.
	push	bx
bitopt_rgn_2:
	mov	bx,[di]			;set bit count to the "in" bits.
	push	cx
	push	dx
	push	di
	call	bitopt_line
	pop	di
	pop	dx
	pop	cx
	add	cx,[di]			;add the "in" bits.
	add	cx,2[di]		;add the "not-in" bits
	add	di,4			;skip to the next "in" bits.
	cmp	cx,temp.right		;have we finished this scan line?
	jb	bitopt_rgn_2		;no - continue.
bitopt_rgn_3:
	pop	bx
	add	bx,2
	inc	dx
	jmp	bitopt_rgn_1
bitopt_rgn_end:
	pop	bx
	call	unprotect_mouse
	ret
 endif


code	ends

	end
