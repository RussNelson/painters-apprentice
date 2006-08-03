;paintmse.asm - Mouse and Screen Control Routines
;History:782,1
;Mon Dec 10 20:16:00 1990 don't turn off interrupts in flip_crt.  Much faster!
;07-27-88 23:55:01 add screen_color so that paintmse can get at it.
;06-24-88 11:06:24 add a color cursor.
;06-17-88 00:30:59 add wait for vertical retrace to flip_crt
flip_mouse	equ	0	;=1 if we remove and place the mouse upon flipping.
grid_to_page	equ	1

data	segment	public

	include	paintflg.asm

	include	paint.def

	extrn	z100_flag: byte

int_kd		equ	46h*4
xsize		equ	640
ysize		equ	350
zpia		equ	0e0h	; parallel printer plus light pen and
                                ;  video vertical retrace 68a21 port
piactla		equ	1	;control register a
piairq2		equ	01000000b	;irq for ca2(cb2)
screen_size	equ	3*16*4		;3 wide, 16 high, four deep.

screen_copy	db	screen_size dup(0)	;saved copy of screen image.
screen_bits	db	screen_size dup(0)	;modified copy of screen image.
mouse_stack	dw	mouse_stack_0
mouse_stack_0	db	8*(size rect) dup(?)

hot_h		dw	-1		;tip of the arrow.
hot_v		dw	-1

mouse_flag	db	0
mouse_on_screen	db	0

h_in_copy	dw	0
v_in_copy	dw	0
h_in_mem	dw	0
v_in_mem	dw	0
shifted_mouses	label	byte
		db	2*3*16*8 dup(?)	;two copies of three bytes (in h) times
					;sixteen bytes (in v) times
					;eight bit positions.
	public	buttons, h_pixel, v_pixel
buttons		dw	0
pixel_pt	label	word
h_pixel		dw	xsize/2		;center of the screen
v_pixel		dw	ysize/2

	db	screen_bytes dup(?)
stack	label	byte

zcrtc	equ	0dch

flip_ok_flag	db	?		;=0 if ok to flip, =-1 if not ok.

mouse_screen_flag	db	?	;=0 or -1, depending on which screen the cursor is in.
cpu_flag	db	0		;=0 if cpu on first page.
crt_flag	db	0		;=0 if crt on first page.

crt_addr	dw	?
cpu_addr	db	?

	public	mouse_color
mouse_color	db	?

	public	screen_color
screen_color	db	07h

	public	graphics_4
graphics_4	db	3		;bit plane 3.

	extrn	grid_flag: byte		;=1 if grid on, =0 if grid off.
	extrn	fatbits_flag: byte	;=1 if fatbits on, =0 if fatbits off.
	extrn	clip_rect: word
	extrn	screen_mouse: word
  if grid_to_page
grid_pt	point	<>
	extrn	wind_on_page: word
  endif

	extrn	screen_seg: word

data	ends


code	segment	public
	assume	cs:code, ds:data, ss:data

our_data	dw	?		;=our data segment.
their_stack	dw	?,?
their_kd	dd	?
this_frame	db	?
cursor_moved	db	?


	extrn	point_to_pointer: near
	extrn	assign_rect: near
	extrn	union_rect: near
	extrn	sect_rect: near
	extrn	set_rect: near
	extrn	inset_rect: near
	extrn	stay_in_rect: near

	public	init_mouse
init_mouse:
	mov	ax,12
	mov	cx,11111b
	mov	dx,offset our_mouse
	push	cs
	pop	es
	int	33h
	mov	our_data,ds

	cmp	z100_flag,0
	je	init_mouse_1
	cli
	xor	ax,ax
	mov	es,ax
	mov	ax,es:int_kd.offs
	mov	their_kd.offs,ax
	mov	ax,es:int_kd.segm
	mov	their_kd.segm,ax
	mov	es:int_kd.offs,offset isr_kd
	mov	es:int_kd.segm,cs
	sti
init_mouse_1:

	mov	dx,3c4h			;select sequencer register 2
	mov	al,2
	out	dx,al
	inc	dx
	mov	al,screen_color		;set sequencer register 2.
	out	dx,al
	ret


	public	uninit_mouse
uninit_mouse:
	mov	ax,12
	mov	cx,0
	int	33h

	cmp	z100_flag,0
	je	uninit_mouse_1
	cli
	xor	ax,ax
	mov	es,ax
	mov	ax,their_kd.offs
	mov	es:int_kd.offs,ax
	mov	ax,their_kd.segm
	mov	es:int_kd.segm,ax
	sti
uninit_mouse_1:

	ret


our_mouse	proc	far
	mov	ds,our_data
	push	ds
	pop	es
	cld
	mov	buttons,bx

	push	ax
	mov	bx,offset screen_mouse	;keep the mouse in view.
	call	stay_in_rect
	pop	ax

	call	adjust_for_grid
	store2	pixel_pt
	cmp	dx,8			;are we near the top of the screen?
	jb	our_mouse_1		;yes.
	mov	this_frame,0		;no - say that we should move it now.
our_mouse_1:
	and	al,1			;isolate the 'cursor moved' bit.
	or	cursor_moved,al		;remember it.
	je	our_mouse_4		;go if we shouldn't move the cursor.
	cmp	z100_flag,0		;the z100 version moves it later.
	jne	our_mouse_4
	call	remove_mouse
	call	place_mouse
our_mouse_4:
	ret
our_mouse	endp


isr_kd:
	push	ax
	in	al,zpia+piactla		; get status
	test	al,piairq2		; did vertical retrace cause interrupt ?
	jz	isr_kd_1		;   no, skip
	cmp	cursor_moved,0		;did the cursor move?
	je	isr_kd_1		;no, skip.
	not	this_frame		;time to move it?
	cmp	this_frame,0		;should we move it this time?
	je	isr_kd_1		;no.
	mov	their_stack.offs,sp
	mov	their_stack.segm,ss
	mov	ss,our_data
	mov	sp,offset stack
	push	bx
	push	cx
	push	dx
	push	bp
	push	si
	push	di
	push	ds
	push	es
	mov	ds,our_data
	push	ds
	pop	es
	cld
	call	remove_mouse
	call	place_mouse
	mov	cursor_moved,0		;reset flag.
	pop	es
	pop	ds
	pop	di
	pop	si
	pop	bp
	pop	dx
	pop	cx
	pop	bx
	mov	ss,their_stack.segm
	mov	sp,their_stack.offs
isr_kd_1:
	pop	ax
	jmp	cs:their_kd


	assume	cs:code, ds:data, ss:nothing


adjust_for_grid:
	test	grid_flag,1		;are we gridding?
	je	get_mouse_2		;no.
  if grid_to_page

	push	cx
	push	dx

	load2	wind_on_page
	neg	cx
	neg	dx
	and	dx,7			;find out the vertical position
	cmp	fatbits_flag,0		;are we in fatbits?
	jne	make_fillPat_4		;yes - use h position.
	xor	cx,cx			;no - don't use h position.
	jmp	short make_fillpat_3
make_fillPat_4:
	and	cx,7			;isolate the horizontal position.
make_fillPat_3:
	store2	grid_pt

	pop	dx
	pop	cx
	mov	bx,clip_rect		;normalize to the window origin
	sub2	[bx].topleft
	and	cx,not 111b		;clip to nearest grid point.
	and	dx,not 111b
	add2	grid_pt			;adjust for wind_on_page origin.
	add2	[bx].topleft		;normalize back to window origin.
  else
	mov	bx,clip_rect
	sub2	[bx].topleft
	and	cx,not 111b
	and	dx,not 111b
	add2	[bx].topleft
  endif
get_mouse_2:
	ret


	public	get_mouse
get_mouse:
	mov	ah,19h
	int	21h
	cli

	load2	pixel_pt

	call	adjust_for_grid

	mov	bx,buttons

	sti
	ret


	public	mouse_on
mouse_on:
	cli
	mov	mouse_flag,1		;say that mouse is on.
	call	place_mouse
	sti
	ret


	public	mouse_off
mouse_off:
	cli
	mov	mouse_flag,0		;say that mouse is off.
	call	remove_mouse
	sti
	ret


	public	protect_mouse
protect_mouse:
;enter with bx->rect to protect
	cli
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	mov	si,bx
	mov	di,mouse_stack
	add	di,(size rect)
	mov	mouse_stack,di
	call	assign_rect

	call	ok_to_place		;still ok for the mouse to be there?
	jnc	protect_mouse_1		;yes - leave it up.
	call	remove_mouse		;get rid of it.
protect_mouse_1:
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	sti
	ret


	public	unprotect_mouse
unprotect_mouse:
	cli
	mov	ax,mouse_stack
	cmp	ax,offset mouse_stack_0
	je	unprotect_mouse_2
	sub	ax,(size rect)
unprotect_mouse_2:
	mov	mouse_stack,ax
restore_mouse:
	cmp	mouse_on_screen,0	;is the mouse up?
	jne	unprotect_mouse_1	;yes - don't put it back up.
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	call	place_mouse
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
unprotect_mouse_1:
	sti
	ret


	public	make_mouse
make_mouse:
;si->mouse cursor.
	cli				;don't put up a half-baked mouse.
	push	si
	call	remove_mouse
	pop	si
	lodsw
	mov	hot_h,ax
	lodsw
	mov	hot_v,ax

	push	ds			;get our es.
	pop	es
	mov	di,offset shifted_mouses
	mov	cx,16
	mov	al,-1
make_mouse_1:
	movsw
	stosb				;mask extends with -1.
	loop	make_mouse_1

	mov	cx,16
	xor	al,al
make_mouse_0:
	movsw
	stosb				;shape extends with zero.
	loop	make_mouse_0

;now make the shifted versions.
	mov	dx,7			;seven more pens to do.
	mov	si,offset shifted_mouses
	lea	di,[si+2*3*16]
make_mouse_2:
	mov	cx,2*16
make_mouse_3:
	mov	al,2[si]		;set the carry to the rightmost bit.
	shr	al,1
	lodsb
	rcr	al,1
	stosb
	lodsb
	rcr	al,1
	stosb
	lodsb
	rcr	al,1
	stosb
	loop	make_mouse_3
	dec	dx
	jne	make_mouse_2
	call	place_mouse
	sti
	ret


overlap_rect:
;enter with bx->protect rect, cx,dx=topleft corner of mouse rect.
;return nc if the mouse overlaps the protect rect.

	and	cx,not 7
	cmp	cx,[bx].right		;left of mouse >= right of rect?
	jge	overlap_rect_1		;yes - no overlap.
	add	cx,3*8			;mouse can overlap 3 bytes.
	cmp	cx,[bx].left		;right of mouse < left of rect?
	jl	overlap_rect_1		;yes - no overlap.

	cmp	dx,[bx].bot		;top of mouse >= bot of rect?
	jge	overlap_rect_1		;yes - no overlap.
	add	dx,16
	cmp	dx,[bx].top		;bot of mouse < top of rect?
	jl	overlap_rect_1		;yes - no overlap.

	clc
	ret
overlap_rect_1:
	stc
	ret


ok_to_place:
;return cy if it's not ok to place.
	cmp	mouse_flag,0		;is the mouse on?
	stc
	je	ok_to_place_1		;no - don't place.
  if 0
	mov	bl,cpu_flag		;are we writing to the crt page?
	cmp	bl,crt_flag
	clc
	jne	ok_to_place_1		;no - ok to place.
  endif
	mov	bx,mouse_stack
	cmp	bx,offset mouse_stack_0	;is the stack empty?
	clc				;assume it's ok.
	je	ok_to_place_1		;yes - always place.
	mov	cx,h_in_mem
	mov	dx,v_in_mem
	call	overlap_rect		;does the mouse touch the protect rect?
	cmc				;if overlap, not ok to place, vice-versa
ok_to_place_1:
	ret



place_mouse_no:
	ret
  if flip_mouse
place_or_remove_mouse:
	call	ok_to_place
	jnc	place_mouse
	jmp	remove_mouse
  endif
place_mouse:
	mov	ax,[pixel_pt.h]
	sub	ax,[hot_h]		;compute where the new one is.
	mov	[h_in_copy],ax
	mov	[h_in_mem],ax
	mov	ax,[pixel_pt.v]
	sub	ax,[hot_v]
	mov	[v_in_copy],ax
	mov	[v_in_mem],ax

	call	ok_to_place
	jc	place_mouse_no

	mov	al,crt_flag		;put the mouse in the visible page.
	mov	mouse_screen_flag,al	;remember which one it's in.
	cmp	al,cpu_flag		;is this the one we're pointing to?
	je	put_mouse		;yes - just go do it.
	call	internal_flip_cpu		;no - we have to flip.
	call	put_mouse
	call	internal_flip_cpu
	ret


put_mouse:
	push	ds
	pop	es
	call	get_screen
	mov	mouse_on_screen,-1	;remember that we have it.
	mov	si,offset screen_copy	;make a copy of the screen
	mov	di,offset screen_bits
	mov	cx,screen_size/2
	rep	movsw
;setup the graphics cursor.
	mov	ax,[h_in_copy]
	and	al,7
	mov	ah,2*3*16		;length of one shifted version.
	mul	ah

	mov	si,offset shifted_mouses	;make si->mouse shapes
	add	si,ax			;offset it to the correctly shifted one.
	mov	di,offset screen_bits
	mov	bl,4			;bl=plane counter.
	mov	bh,mouse_color		;bh=plane mask.
put_mouse_2:
	push	si			;preserve the pointer to the right mouse.
	mov	cx,16			;three planes, sixteen lines.
put_mouse_1:
  if 1
	test	bh,1			;should we draw this plane or erase it?
	je	put_mouse_3		;erase it.
	mov	ax,[di]			;and with the screen bits
	and	ax,[si]			;get screen mask
	or	ax,[si+3*16]		;xor with the cursor mask
	stosw				;store back in the screen bits
	add	si,2
	mov	al,[di]
	and	al,[si]
	or	al,[si+3*16]
	stosb
	inc	si
	jmp	short put_mouse_4
put_mouse_3:
	mov	ax,[si+3*16]		;xor with the cursor mask
	not	ax
	and	ax,[si]			;get screen mask
	add	si,2
	and	[di],ax			;store back in the screen bits
	add	di,2

	mov	al,[si+3*16]
	not	al
	and	al,[si]
	inc	si
	and	[di],al
	inc	di
put_mouse_4:
  else
	lodsw				;get screen mask
	and	ax,[di]			;and with the screen bits
	xor	ax,[si+3*16-2]		;xor with the cursor mask
	stosw				;store back in the screen bits
	lodsb
	and	al,[di]
	xor	al,[si+3*16-1]
	stosb
  endif
	loop	put_mouse_1
	pop	si
	shr	bh,1
	dec	bl
	jne	put_mouse_2

	mov	si,offset screen_bits
	jmp	short put_screen

remove_no:
	ret
remove_mouse:
	cmp	mouse_on_screen,0	;do we have the mouse on screen?
	je	remove_no		;no.
	mov	mouse_on_screen,0	;yes - not any more.

	mov	ax,[h_in_mem]
	mov	[h_in_copy],ax
	mov	ax,[v_in_mem]
	mov	[v_in_copy],ax
	mov	si,offset screen_copy

	mov	al,mouse_screen_flag	;=0 or -1, depending on which screen.
	cmp	al,cpu_flag		;is the cpu set to this one?
	je	put_screen		;yes - just put it.
	call	internal_flip_cpu		;no - have to flip to it.
	call	put_screen
	call	internal_flip_cpu
	ret

put_screen:
;enter with si->stuff to put on screen.
	mov	ax,screen_seg		;get the video plane.
	mov	es,ax

	mov	di,si			;save the pointer to what we're putting
	call	screen_adr		;get the address on the screen.
	xchg	di,si

	mov	dx,3c4h			;select sequencer register 2
	mov	al,2
	out	dx,al
	inc	dx

	mov	ax,[v_in_copy]
	cmp	ax,ysize-16		;can we possibly be off screen?
	ja	put_screen_clip		;yes.
	mov	ax,[h_in_copy]
	cmp	ax,xsize-16
	ja	put_screen_clip		;yes.

	mov	bl,1000b
put_screen_2:
	push	di
	mov	al,bl			;select plane in bl.
	out	dx,al
	mov	cx,16
put_screen_1:
	movsb				;move one line
	movsb
	movsb
	add	di,screen_bytes-3	;down one line and back to original h.
	loop	put_screen_1
	pop	di
	shr	bl,1
	jnc	put_screen_2
	jmp	short put_screen_exit

put_screen_clip:
	mov	bl,1000b
put_screen_clip_5:
	push	di
	push	h_in_copy
	push	v_in_copy
	mov	al,bl			;select plane in bl.
	out	dx,al
	mov	cx,16			;16 scan lines
put_screen_clip_1:
	mov	ax,[v_in_copy]		;above screen?
	or	ax,ax
	jl	put_screen_clip_2	;yes.
	cmp	ax,ysize		;below screen?
	jge	put_screen_clip_2	;yes.
	push	bx
	push	cx
	mov	cx,3			;to 3 bytes.
put_screen_clip_3:
	mov	bx,[h_in_copy]
	or	bx,bx			;to left of screen?
	jl	put_screen_clip_4	;yes.
	cmp	bx,xsize		;to right of screen?
	jge	put_screen_clip_4	;yes.
	movsb
	dec	si
	dec	di
put_screen_clip_4:
	inc	si			;skip a byte.
	inc	di			;. .
	add	[h_in_copy],8		;move to the right a byte
	loop	put_screen_clip_3
	sub	[h_in_copy],3*8		;back up 3 bytes.
	sub	si,3
	sub	di,3
	pop	cx
	pop	bx
put_screen_clip_2:
	add	si,3			;skip a scan line
	add	di,screen_bytes		;. .
	inc	[v_in_copy]		;move down a line.
	loop	put_screen_clip_1
	pop	v_in_copy
	pop	h_in_copy
	pop	di
	shr	bl,1
	jnc	put_screen_clip_5
put_screen_exit:
	mov	al,screen_color		;restore sequencer register 2.
	out	dx,al
	ret


get_screen:
;enter with [v_in_copy], [h_in_copy] -> cursor point.
	call	screen_adr		;get the pointer to the screen.
	mov	di,offset screen_copy

	push	ds
	mov	ax,screen_seg
	mov	ds,ax
	assume	ds:nothing, es:data
	mov	bl,3
	mov	dx,3ceh			;select graphics controller register 4
	mov	al,4
	out	dx,al
	inc	dx
get_screen_2:
	push	si
	mov	al,bl			;select plane in bl.
	mov	graphics_4,al
	out	dx,al
	mov	cx,16			;sixteen high.
get_screen_1:
	movsb				;movsw doesn't work if we try to
	movsb				;  move the word at offset 0ffffh!
	movsb
	add	si,screen_bytes-3	;down one line and back to original h.
	loop	get_screen_1		;do it for a total of 16 scan lines.
	pop	si
	dec	bl
	jge	get_screen_2
	mov	al,graphics_4		;restore graphics_4
	out	dx,al
	pop	ds
	assume	ds:data
	ret


screen_adr:
;enter with [h_in_copy], [v_in_copy]
;return si = address of screen byte, bx->entry with ->this scan line.
;preserve cx.
	push	cx

	mov	si,[h_in_copy]
	mov	cl,3
	sar	si,cl			;get the byte address

	push	dx
	mov	ax,screen_bytes
	mul	[v_in_copy]
	pop	dx
	add	si,ax
	pop	cx
	ret


;flip_cpu sets the cpu to point to the other screen page.
	public	flip_cpu
flip_cpu:
	pushf
	cli
	call	flip_ok			;should we flip?
	jc	flip_cpu_2		;no.
	call	internal_flip_cpu
  if flip_mouse
	push	ax
	call	place_or_remove_mouse		;put the mouse on the newly visible page.
	pop	ax
  endif
flip_cpu_2:
	popf
	ret


;flip_crt sets the crt to point to the other screen page.
	public	flip_crt
flip_crt:
	call	flip_ok			;should we flip?
	jc	flip_crt_2		;no.

	push	ax

	mov	dx,03dah		;wait for vertical retrace.
al2:
	in	al,dx			;wait for vertical retrace to start.
	test	al,8
	je	al2
al3:
	in	al,dx			;wait for display to begin.
	test	al,8
	jne	al3

	call	internal_flip_crt

	mov	dx,03dah		;wait for vertical retrace.
al4:
	in	al,dx			;wait for vertical retrace to start.
	test	al,8
	je	al4
al5:
	in	al,dx			;wait for display to begin.
	test	al,8
	jne	al5

  if flip_mouse
	call	place_or_remove_mouse		;put the mouse on the newly visible page.
  endif

	pop	ax
flip_crt_2:
	ret


	public	flip_ok
flip_ok:
;return with nc if it's ok to use page flipping, cy if not ok.
	ror	flip_ok_flag,1
	ret


	public	flip
flip:
;call flip once at init time before you call flip_crt or flip_cpu.
	mov	ax,screen_seg		;if the green plane has 64K, assume all do.
	mov	es,ax
	mov	flip_ok_flag,0		;ok to flip.
	call	internal_ram_check	;do they have 64K parts?
	jnz	flip_1			;yes - ok to flip.
	mov	flip_ok_flag,-1		;not ok to flip.
flip_1:
	call	internal_flip
	ret


;call unflip once before your program terminates.
	public	unflip
unflip:
	cmp	crt_flag,0
	je	unflip_1
	call	flip_crt
unflip_1:
	cmp	cpu_flag,0
	je	unflip_2
	call	internal_flip_cpu
unflip_2:
	ret


	public	flip_ram
flip_ram:
;call flip_ram to copy the visible screen to the invisible (other) screen.
	call	flip_ok			;should we flip?
	jc	flip_ram_5		;no.

	call	mouse_off		;ensure that the mouse isn't on invisible page.
	mov	si,0			;move from visible page to
	mov	di,350*80		;  invisible page.
	cmp	cpu_flag,0		;are we on the second page?
	je	flip_ram_3		;no.
	xchg	si,di
	call	internal_flip_cpu
	call	internal_flip_ram
	call	internal_flip_cpu
	jmp	short flip_ram_4
flip_ram_3:
	call	internal_flip_ram
flip_ram_4:
	call	mouse_on
flip_ram_5:
	ret


internal_flip_crt:
	push	bx
	xor	bx,bx
	not	crt_flag
	cmp	crt_flag,0		;are we flipped or normal?
	je	internal_flip_crt_1
	mov	bx,350*80		;flipped - go to other page.
internal_flip_crt_1:
;bx = starting address offset
	mov	dx,03d4h

	mov	al,0ch
	out	dx,al
	inc	dx
	mov	al,bh
	out	dx,al
	dec	dx

	mov	al,0dh
	out	dx,al
	inc	dx
	mov	al,bl
	out	dx,al
	dec	dx

	pop	bx
	ret


internal_flip_cpu:
	push	ax
	mov	ax,0a000h
	not	cpu_flag
	cmp	cpu_flag,0		;are we flipped or normal?
	je	internal_flip_cpu_1
	add	ax,350*80/16		;flipped.
internal_flip_cpu_1:
	mov	screen_seg,ax
	pop	ax
	ret


internal_flip:
	ret


internal_flip_ram:
	mov	ax,screen_seg		;do everything in the green plane.
	mov	ds,ax
	mov	es,ax
	mov	cx,350*80/2		;go for it!
	rep	movsw
	mov	ax,ss
	mov	ds,ax
	ret


internal_ram_check:
;return nz if they have 64K screen chips.
	or	sp,sp
	ret

code	ends

	end
