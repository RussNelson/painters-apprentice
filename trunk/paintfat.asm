;paintfat.asm - Fatbits Handler
;History:25,1
;03-20-88 16:58:14 restructure the innermost loop.

	include	paint.def

data	segment	public

	extrn	clip_rect: word		;points to the clipping rectangle.

bit_count	dw	?
lower_limit	dw	?
bit_offset	dw	?

do_bits_table	label	word
	dw	do_bit_7
	dw	do_bit_6
	dw	do_bit_5
	dw	do_bit_4
	dw	do_bit_3
	dw	do_bit_2
	dw	do_bit_1
	dw	do_bit_0

	extrn	screen_seg: word

data	ends

code	segment	public
	assume	cs:code, ds:data, ss:data

do_bit	macro	a, done
	jcxz	done
do_bit_&a:
	cbw
	shr	ah,1			;move a zero in from the left.
	mov	[di+0*screen_bytes],ah		;store this byte's value.
	mov	[di+1*screen_bytes],ah
	mov	[di+2*screen_bytes],ah
	mov	[di+3*screen_bytes],ah
	mov	[di+4*screen_bytes],ah
	mov	[di+5*screen_bytes],ah
	mov	[di+6*screen_bytes],ah
	mov	[di+7*screen_bytes],byte ptr 0
	dec	cx
  if a gt 0
	shl	al,1
  endif
	inc	di
	endm

	extrn	point_to_pointer: near
				;enter with cx,dx=point.
				;exit with es:di->byte, bp=bit alignment.

	public	paint_fatbits
paint_fatbits:
	mov	si,[bx].left		;determine the top left corner.
	shr	si,1			;get rid of bit position
	shr	si,1
	shr	si,1
	mov	ax,screen_bytes		;compute y-position*screen_bytes
	mul	[bx].top
	add	si,ax
	mov	di,si			;get a copy to store bytes in.

	mov	ax,[bx].bot		;compute the bottom of the small box.
	inc	ax			;leave room for the frame.
	mov	dx,screen_bytes
	mul	dx
	mov	lower_limit,ax

	mov	ax,[bx].right		;compute size of box.
	sub	ax,[bx].left
	add	ax,7
	mov	cl,3
	shr	ax,cl
	mov	bit_offset,ax

	mov	dx,[bx].bot
	sub	dx,[bx].top
	mov	cx,[bx].right
	sub	cx,[bx].left
	mov	bit_count,cx
	push	ds			;save data
	mov	ax,screen_seg		;get the green plane.
	mov	es,ax
	mov	ds,ax
	assume	ds:nothing
paint_fatbits_2:
	push	si
	push	di
	mov	cx,bit_count
	cmp	di,lower_limit		;do we still need to clip?
	jae	paint_fatbits_3		;no.
	mov	ax,cx			;skip this many bits.
	call	do_short_line
	jmp	short paint_fatbits_4
paint_fatbits_3:
	call	do_scan_line
paint_fatbits_4:
	pop	di
	pop	si
	add	si,screen_bytes			;move down a scan line.
	add	di,screen_bytes*8		;move down eight scan lines.
	dec	dx
	jne	paint_fatbits_2
	pop	ds			;restore data.
	assume	ds:data
	ret


	assume	ds:nothing
do_short_line:
;enter with si->small rect, di->large rect, cx=number of bits to do,
;  ax=number of bits to skip at left.
	sub	cx,bit_offset
	add	di,bit_offset
	mov	bx,bit_offset		;shift the pointer over by the right
	shr	bx,1			;  number of bytes.
	shr	bx,1
	shr	bx,1
	add	si,bx
	mov	bx,bit_offset		;now move over by the right number of
	and	bl,7			;  bits.
	xchg	cx,bx
	lodsb
	shl	al,cl
	xchg	cx,bx
	shl	bx,1			;now make it into a table index.
	jmp	do_bits_table[bx]
do_scan_line:
;enter with si->small rect, di->large rect, cx=number of bits to do.
do_scan_line_2:
	lodsb
	do_bit	7, done2
	do_bit	6, done2
done2:
	do_bit	5, done1
	do_bit	4, done1
	do_bit	3, done1
done1:
	do_bit	2, done
	do_bit	1, done
	do_bit	0, done
	jmp	do_scan_line_2
done:
	ret
	assume	ds:data


code	ends

	end
