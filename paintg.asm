;paintg.asm - Graphics setup
;History:162,1
;01-02-88 23:50:44 remove the machine dependent stuff.
;queue=1 if we're using an event queue.
queue	equ	0

data	segment	public

segoff	struc
offs	dw	?
segm	dw	?
segoff	ends

point	struc
h	dw	?
v	dw	?
point	ends

rect	struc
left	dw	?
top	dw	?
right	dw	?
bot	dw	?
rect	ends

rect1		struc
topleft		db	(size point) dup(?)
botright	db	(size point) dup(?)
rect1		ends

penState	struc
pnLoc		db	(size point) dup(?)
pnSize		db	(size point) dup(?)
pnMode		dw	?
penState	ends

	extrn	pen: byte
	extrn	pnPat: byte

	public	this_pen
this_pen	dw	?

	public	brush_cursor
brush_cursor	label	word
	dw	?,?
	dw	16 dup(0FFFFh)
cursor_data	label	word
	dw	16 dup(0)

	extrn	dot_pen: byte

data	ends


code	segment	public
	assume	cs:code, ds:data

	extrn	point_to_pointer: near

	public	make_mouse_pen
make_mouse_pen:
;enter with si=pen to select.
	push	ds
	pop	es

;put the hot spot in the middle of the pen.
	mov	ah,0
	lodsb
	shr	ax,1
	mov	brush_cursor.h,ax
	lodsb
	shr	ax,1
	mov	brush_cursor.v,ax

	cmp	byte ptr [si-2],8		;triple?
	ja	make_mouse_triple_1		;yes - have to do three bytes.
	mov	di,offset cursor_data
	mov	cx,8
	mov	ah,0
make_mouse_double_1:
	lodsb
	stosw
	loop	make_mouse_double_1

	mov	cx,8			;clear the rest of the cursor.
	xor	ax,ax
	rep	stosw
	ret

make_mouse_triple_1:
	mov	di,offset cursor_data
	mov	cx,16
	rep	movsw
	ret


makepen_11:
	ret
	public	makepen_dot
makepen_dot:
	mov	si,offset dot_pen
	public	makepen
makepen:
;enter with si=pen to select.
;preserve bx.
	cmp	si,this_pen		;are we already set up?
	je	makepen_11		;yes - exit.

	mov	this_pen,si
	push	ds
	pop	es
	mov	ah,0
	lodsb
	mov	pen.pnSize.h,ax
	lodsb
	mov	pen.pnSize.v,ax

	cmp	pen.pnSize.h,8		;triple?
	ja	makepen_triple_1		;yes - have to do three bytes.
	mov	di,offset pnPat
	mov	cx,8
	mov	ah,0
makepen_double_1:
	lodsb
	stosw
	loop	makepen_double_1
	mov	dx,7			;seven more pens to do.
	mov	si,offset pnPat
makepen_double_2:
	mov	cx,8
makepen_double_3:
	lodsb
	shr	al,1
	stosb
	lodsb
	rcr	al,1
	stosb
	loop	makepen_double_3
	dec	dx
	jne	makepen_double_2

	jmp	short makepen_10

makepen_triple_1:
	mov	di,offset pnPat
	mov	cx,16
	mov	ah,0
makepen_triple_2:
	movsw
	xor	al,al
	stosb
	loop	makepen_triple_2
	mov	dx,7			;seven more pens to do.
	mov	si,offset pnPat
makepen_triple_3:
	mov	cx,16
makepen_triple_4:
	lodsb
	shr	al,1
	stosb
	lodsb
	rcr	al,1
	stosb
	lodsb
	rcr	al,1
	stosb
	loop	makepen_triple_4
	dec	dx
	jne	makepen_triple_3

makepen_10:
	ret


code	ends

	end
