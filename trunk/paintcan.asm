;paintcan.asm - Paint Can Fill
;History:44,1
;03-06-88 22:28:09 check for h edges.

	include	paint.def

checking_v	equ	0	;=1 if we're checking for top and bot of screen.
checking_h	equ	1	;=1 if we're checking for left and right of screen.

data	segment	public

val	struc
val1	dw	?			;->current byte.
val2	db	?,?			;(bit number) (direction flag)
val3	dw	?			;bit count
val	ends

screen_bpsl	dw	screen_bytes

byte_ptr	dw	?
bit_number	db	?

direction_flag	db	?		;=0 if we're done, bit 7=1 if up else down.
right_border_ptr	dw	?
right_bit_num	db	?
start		dw	?
finish		dw	?
left_bit	db	?
right_bit	db	?

begin_q		dw	?		;->beginning of queue
end_q		dw	?		;->after end of queue

tail_q		dw	?		;->tail of queue
head_q		dw	?		;->head of queue

size_q		dw	?		;=number of bytes in queue.

max_q		dw	4000		;=maximum size of queue (in bytes)

save_stack	dw	?		;used for emergency exit from paintcan.

	extrn	put_byte_subr: word
	extrn	free_space: word
	extrn	disk_font: word

	extrn	screen_seg: word

data	ends

code	segment	public
	assume	cs:code, ds:data

	extrn	flip_cpu: near

	public	paint_shape
paint_shape:
;enter with cx,dx=x,y of initial cell.
	mov	save_stack,sp

	mov	ax,disk_font		;compute the amount of memory
	sub	ax,free_space		;  available.
	mov	max_q,ax

	mov	put_byte_subr,offset pset_verb

	mov	ax,screen_seg		;set the green plane.
	mov	es,ax
	call	flip_cpu

	mov	bx,free_space
	mov	begin_q,bx
	add	bx,max_q
	mov	end_q,bx

	mov	size_q,0		;init the queue to empty.
	mov	bx,begin_q
	mov	tail_q,bx
	mov	head_q,bx

	call	xy_to_bitbyte
	mov	dx,1			;look at this bit.
	call	paint_to_right
	jz	paint_exit		;exit now if we have nothing to do.

	push	bx
	call	paint_to_left
	pop	dx
	add	dx,bx
	mov	ch,40h			;say to look down
	call	queue_this_bit
	mov	ch,0c0h			;say to look up
	jmp	first_point		;jump into the middle.

paint_exit:
	mov	sp,save_stack
	ret


	extrn	bitopt_line: near
	extrn	pset_verb: near


bitbyte_to_xy:
;enter with dh=bit_number, bx=byte_ptr
;exit with cx=x, dx=y.

	mov	ax,bx
	mov	bl,dh			;save the bit.
	mov	dx,0
	mov	cx,screen_bytes
	div	cx
	mov	cx,dx			;we want remainder (x) in cx.
	mov	dx,ax			;we want quotient (y) in dx.
	shl	cx,1			;convert bytes to bits.
	shl	cx,1
	shl	cx,1

bitbyte_to_xy_1:
	inc	cx
	shl	bl,1
	jnc	bitbyte_to_xy_1
	dec	cx			;account for preincrement.
	ret


big_pset:
;enter with dl=leftmost bit in this byte to set, bx=> byte, cx=bit count.
	push	cx
	push	bx
	push	dx
	push	es
	mov	dh,dl
	push	cx
	call	bitbyte_to_xy
	pop	bx
	call	bitopt_line
	pop	es
	pop	dx
	pop	bx
	pop	cx
	xor	ax,ax			;start with no bits.
big_pset_2:
	or	ah,dl			;get the bit.
	dec	cx			;dec bit count.
	jle	big_pset_1		;leave if done.
	rcr	dl,1			;move the bit to the right.
	jnc	big_pset_2		;continue if it didn't fall off the end.
big_pset_1:
	not	ah
	and	es:[bx],ah		;set the bits in that byte.
	inc	bx			;go to the next byte.

	push	cx			;save ch (and cl) for later.
	shr	cx,1			;get cl=# of bytes to set.
	shr	cx,1
	shr	cx,1
	mov	di,bx
	xor	al,al
	rep	stosb
	mov	bx,di		;update di
	pop	cx		;get the bit count back.

	and	cl,7
	mov	ax,0ff00h
	shr	ax,cl
	not	al
	and	es:[bx],al
	ret


xy_to_bitbyte:
;enter with cx=x, dx=y.
;exit with al=bit_number, bx=byte_ptr
	mov	bx,cx		;get x
	shr	bx,1		;get rid of bit position
	shr	bx,1
	shr	bx,1
	mov	ax,screen_bytes
	mul	dx
	add	bx,ax		;merge x and y
	mov	byte_ptr,bx
	and	cl,7		;get the low 3 bits of x
	mov	al,80h		;put a one in bit 7
	shr	al,cl		;shift it to the right place.
	mov	bit_number,al
	ret


paint_exit_j_1:
	jmp	paint_exit

next_point_check:
;check for ^c if desired.
next_point:
	call	remove_q
	mov	byte_ptr,bx
	mov	bit_number,cl
first_point:
	mov	direction_flag,ch	;remember which direction we're moving in.
	add	ch,ch
	jz	paint_exit_j_1		;if queue empty, exit.

	push	dx
	jnc	should_move_down
  if checking_v
	mov	ax,byte_ptr
	or	ax,ax
	jz	next_point
  endif
	sub	byte_ptr,screen_bytes
	jmp	short done_moving_up
should_move_down:
  if checking_v
	mov	ax,byte_ptr
	add	ax,screen_bytes
	cmp	ax,screen_lines*screen_bytes
	jae	next_point
  endif
	add	byte_ptr,screen_bytes
done_moving_up:
	pop	dx
	jc	next_point		;go if end of screen.

	call	paint_to_right
	jz	next_point

	call	paint_to_left
	mov	dx,bx
	or	cl,cl
	jz	llab
	dec	bx
	dec	bx

	js	llab
	mov	ch,direction_flag	;move in the opposite direction
	not	ch
	mov	bx,byte_ptr
	mov	cl,bit_number
	call	add_q
llab:
	add	dx,start
	call	queue_save_bit

	mov	bx,right_border_ptr
	mov	al,right_bit_num
	mov	byte_ptr,bx
	mov	bit_number,al

qlab:	mov	bx,finish
	mov	dx,start
	sub	bx,dx
	jz	next_point_check_j_1	;we're there, exit now.
	jb	plab		;we ended up with a negative result.
	xchg	bx,dx
	call	paint_to_right
	jz	next_point_check_j_1
	or	cl,cl
	jz	qlab
	mov	dx,bx
	mov	bx,right_border_ptr
	mov	cl,right_bit_num
	mov	ch,direction_flag	;keep moving in the same direction
	call	add_q
	jmp	qlab

plab:
	neg	bx
	dec	bx
	dec	bx
	js	next_point_check_j_1
	inc	bx

	push	bx
	xchg	bx,dx
slab:	call	bit_left
	dec	dx
	jnz	slab
	pop	dx

	mov	ch,direction_flag	;move in the opposite direction
	not	ch
	call	queue_this_bit
next_point_check_j_1:
	jmp	next_point_check


queue_save_bit:
	mov	cl,left_bit		;any left?
	mov	al,right_bit		;or right?
	or	al,cl
	jz	queue_save_bit_1	;no, exit now.
	mov	ch,direction_flag
queue_this_bit:
;enter with ch=direction flag.
	mov	bx,byte_ptr
	mov	cl,bit_number
	call	add_q
queue_save_bit_1:
	ret


paint_to_right:
	call	set_right
	mov	finish,dx
	mov	start,bx
	or	bx,bx
	mov	right_bit,cl
	ret


paint_to_left:
	mov	bx,byte_ptr
	mov	al,bit_number
	xchg	bx,right_border_ptr
	xchg	al,right_bit_num
	mov	byte_ptr,bx
	mov	bit_number,al
	call	set_left
	mov	left_bit,cl
	ret


add_q:
;enter with val1=bx, val2=cx, val3=dx
	push	bx
	mov	bx,size_q
	add	bx,size val
	mov	size_q,bx
	cmp	bx,max_q
	jb	add_q_1
	jmp	paint_exit
add_q_1:
	mov	bx,tail_q
	call	next_q
	pop	[bx].val1
	mov	word ptr [bx].val2,cx
	mov	[bx].val3,dx
	add	bx,size val
	mov	tail_q,bx
	ret


remove_q:
	mov	bx,size_q
	cmp	bx,0
	mov	ch,0			;if the queue is empty, return ch=0.
	je	remove_q_1
	sub	bx,size val
	mov	size_q,bx
	mov	bx,head_q		;get the next item off the queue.
	call	next_q
	push	[bx].val1
	mov	cx,word ptr [bx].val2
	mov	dx,[bx].val3
	add	bx,size val
	mov	head_q,bx
	pop	bx
remove_q_1:
	ret


next_q:
;enter with bx=queue pointer.  Exit with bx=succ(bx)
	push	bx
	add	bx,size val
	cmp	bx,end_q
	pop	bx
	jb	next_q_1
	mov	bx,begin_q
next_q_1:
	ret


set_right:
	call	scan_right
	mov	bx,right_border_ptr
	mov	ah,right_bit_num
	jmp	set_1
set_left:
	call	scan_left
set_1:
	push	si
	mov	dl,ah
	push	cx
	push	bp
	jcxz	set_2			;if no bits, don't do anything.
;dl=leftmost bit in this byte to set, bx=> byte, cx=bit count.
	call	big_pset
set_2:
	pop	cx			;pushed as bp
	or	cl,ch
	pop	bx			;pushed as cx
	pop	dx			;pushed as si
	ret


scan_left:
	call	scan_init
	xor	si,si
	jmp	scan_left_2
scan_left_1:
	test	ah,dh		;did we find the paint color?
	jz	scan_left_2	;no
	mov	bp,ax		;yes, save the bit in which it was found.
scan_left_2:
	call	move_left	;move left
	jc	scan_left_3	;end of line - exit.
	inc	si		;count # bits.
	test	ah,dl		;did we find the border color?
	jnz	scan_left_1	;yes, keep going.
	dec	si		;adjust for pre-increment
	clc
	rcr	ah,1		;byte boundary?
	jnc	scan_left_3	;no.
	rcr	ah,1		;yes - leftmost bit of byte to right.
	inc	bx
scan_left_3:
	mov	cx,si		;set count
	mov	bit_number,ah
	mov	byte_ptr,bx
	ret


scan_right:
;enter with dx=number of bits to look at.
	call	scan_init
scan_right_3:
	test	ah,dl		;did we find the border color?
	jnz	scan_right_1	;yes, leave loop.
	dec	si		;more bits to check?
	jz	scan_right_2	;no, we must not have found the border.
	call	move_right	;move to the right.
	jnc	scan_right_3	;continue if we didn't find the edge.
scan_right_2:
	xor	cx,cx
	mov	si,cx
	ret
scan_right_1:
	push	si		;save the count.
	mov	right_border_ptr,bx	;save the starting bit, byte.
	mov	right_bit_num,ah
	xor	si,si		;reset the count.
scan_right_6:
	inc	si		;count one bit.
	test	ah,dh		;did we find the painted color?
	jz	scan_right_4	;no.
	mov	bp,ax		;yes, save the bit in question.
scan_right_4:
	call	move_right	;move to the right.
	jc	scan_right_5	;leave if we found the border.
	test	ah,dl		;did we find the border?
	jnz	scan_right_6	;keep going if we did.
scan_right_5:
	mov	cx,si
	pop	si
	mov	bit_number,ah
	mov	byte_ptr,bx
	ret


scan_init:
	mov	ah,bit_number
	mov	bx,byte_ptr
	mov	si,dx
	xor	bp,bp
	call	read_planes
	ret


move_left:
	rol	ah,1		;move left
	jc	move_left_1
	ret
move_left_1:
  if checking_h
	push	ax
	push	dx
	mov	ax,bx
	xor	dx,dx
	div	screen_bpsl
	or	dx,dx
	pop	dx
	pop	ax
	jz	move_left_2
  endif
	dec	bx
	call	read_planes
	clc
	ret
move_left_2:
	ror	ah,1
	stc
	ret


move_right:
	ror	ah,1
	jc	move_right_1
	ret
move_right_1:
  if checking_h
	push	ax
	push	dx
	mov	ax,bx
	xor	dx,dx
	div	screen_bpsl
	cmp	dx,80-1
	pop	dx
	pop	ax
	jae	move_right_2
  endif
	inc	bx
	call	read_planes
	clc
	ret
move_right_2:
	rol	ah,1
	stc
	ret


read_planes:
	mov	dl,es:[bx]
	mov	dh,dl
	ret


bit_left:
	rol	bit_number,1
	jnc	bit_left_1
	dec	byte_ptr
bit_left_1:
	ret


code	ends

	end
