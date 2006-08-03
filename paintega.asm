;paint100.asm - hardware dependencies, Z-100 version.
;History:20,1
;Wed Dec 14 23:34:21 1988 add this_thing so that multiple pastes clear first.
;Fri Nov 11 23:07:44 1988 add printer_ready()
;06-16-88 23:35:22 add page flipping.
;06-16-88 21:13:29 define screen_seg

;queue=1 if we're using an event queue.
queue	equ	0

	include	paint.def

data	segment	public

	public	screen_seg
screen_seg	dw	0a000h

	public	z100_flag
z100_flag	db	0

	public	this_thing
this_thing	db	?
last_thing	db	?

key	struc
key_value	db	?
key_address	dw	?
key_menu	dw	?
key	ends

key_map_list	label	byte
	key	<46,do_menu,002h>	;alt-c = Change Drive
	key	<73,do_menu,003h>	;Pg Up = Load...
	key	<81,do_menu,004h>	;Pg Dn = Save
	key	<118,do_menu,005h>	;Ctrl-Pg Dn = Save As...
	key	<45,do_menu,009h>	;alt-x = Quit
	key	<83,do_menu,105h>	;Del   = Clear
	key	<71,do_menu,208h>	;Home  = Help
	key	<119,do_menu,209h>	;Ctrl-Home  = Quickies
	key	<72,font_size_dec>
	key	<80,font_size_inc>
	key	<75,font_dec>
	key	<77,font_inc>
	key	<79,popup_tools>
  if 0	;don't use alt letters for shortcuts.
	key	<16,do_menu_key,'Q'>
	key	<17,do_menu_key,'W'>
	key	<18,do_menu_key,'E'>
	key	<19,do_menu_key,'R'>
	key	<20,do_menu_key,'T'>
	key	<21,do_menu_key,'Y'>
	key	<22,do_menu_key,'U'>
	key	<23,do_menu_key,'I'>
	key	<24,do_menu_key,'O'>
	key	<25,do_menu_key,'P'>
	key	<30,do_menu_key,'A'>
	key	<31,do_menu_key,'S'>
	key	<32,do_menu_key,'D'>
	key	<33,do_menu_key,'F'>
	key	<34,do_menu_key,'G'>
	key	<35,do_menu_key,'H'>
	key	<36,do_menu_key,'J'>
	key	<37,do_menu_key,'K'>
	key	<38,do_menu_key,'L'>
	key	<44,do_menu_key,'Z'>
	key	<45,do_menu_key,'X'>
	key	<46,do_menu_key,'C'>
	key	<47,do_menu_key,'V'>
	key	<48,do_menu_key,'B'>
	key	<49,do_menu_key,'N'>
	key	<50,do_menu_key,'M'>
  endif
	db	0

	extrn	menu_hook_key: word
	extrn	menu_hook_show: word
	extrn	menu_hook_hide: word

data	ends


code	segment	public
	assume	cs:code, ds:data

	extrn	do_menu: near
	extrn	font_size_dec: near
	extrn	font_size_inc: near
	extrn	font_dec: near
	extrn	font_inc: near
	extrn	popup_tools: near


	public	time_now
time_now	dw	?

our_ds	dw	?

  if queue
int_ukb		equ	50h
their_ukb	dd	?
  endif

int_utm		equ	1ch
their_utm	dd	?

	extrn	point_to_pointer: near


	public	ring_bell
ring_bell:
	push	bx
	push	cx
	mov	bx,6779
	call	beep
	pop	cx
	pop	bx
	ret


;Beep procedure count values
;---------------------------
;To generate a given freqency note out of the speaker with the Beep procedure
;on the PC using Channel 2 of the 8253 timer, the channel 2 count register
;must be loaded with a value such that the 8253 input clock frequency
;(1.19318 MHz) divided by the count figure equals the audio frequency.
;enter with bx=count figure for frequency to be generated.
beep:
	mov	al,0b6h		; Channel 2, LSB then MSB, Square Wave, Binary
	out	43h,al		; Program 8253 command register
	mov	ax,bx		; Get the frequency to be generated
	out	42h,al		; Load Channel 2 count register LSB
	mov	al,ah
	out	42h,al		; Load Channel 2 count register MSB
	in	al,61h		; Read settings from 8255 PPI I/O Port "PB"
	mov	ah,al		; Save original settings in AH
	or	al,3		; Enable Timer Channel 2 & Speaker data
	out	61h,al		; program the 8255 with new setting-speaker on
	sub	cx,cx		; Sneaky way to put 0FFFFH into CX when
wait2:	loop	wait2		; LOOP is first executed
	mov	al,ah		; Get original 8255 Port "PB" settings
	out	61h,al		; Reset port to original values-speaker off
	ret


	public	read_screen_color
read_screen_color:
;enter with cx, dx=point.
;exit with cy = bit under point.
	call	point_to_pointer
	mov	cx,bp
	inc	cl			;move it into the carry.
	mov	al,es:[di]		;get the byte,
	shl	al,cl			;  and shift the bit into the carry.
  if black_on_white
	cmc
  else
  endif
	ret


	public	init_screen
init_screen:
	mov	our_ds,ds

	mov	ax,10h			;go into hi-resolution video mode.
	int	10h

	cli
	xor	ax,ax
	mov	es,ax

	mov	ax,es:[int_utm*4].offs
	mov	dx,es:[int_utm*4].segm
	mov	es:[int_utm*4].offs,offset our_utm
	mov	es:[int_utm*4].segm,cs
	mov	their_utm.offs,ax
	mov	their_utm.segm,dx

  if queue
	mov	ax,es:[int_ukb*4].offs
	mov	dx,es:[int_ukb*4].segm
	mov	es:[int_ukb*4].offs,offset our_ukb
	mov	es:[int_ukb*4].segm,cs
	mov	their_ukb.offs,ax
	mov	their_ukb.segm,dx
  endif

	sti

	ret


	public	uninit_screen
uninit_screen:
	mov	ax,3			;go back into text mode.
	int	10h

	cli
	xor	bx,bx
	mov	es,bx

	mov	ax,their_utm.offs
	mov	dx,their_utm.segm
	mov	es:[int_utm*4].offs,ax
	mov	es:[int_utm*4].segm,dx

  if queue
	mov	ax,their_ukb.offs
	mov	dx,their_ukb.segm
	mov	es:[int_ukb*4].offs,ax
	mov	es:[int_ukb*4].segm,dx
  endif

	sti
	ret

our_utm:
	add	time_now,5
	jmp	their_utm


  if queue
our_ukb:
	push	ds
	pushf
	cli
	push	ax

	pop	ax
	popf
	pop	ds
	jmp	their_ukb
  endif


	extrn	menu_key: near
	extrn	paste_number: near
	extrn	copy_number: near
	extrn	clear: near		;painth


	public	do_key
do_key:
	xor	ah,ah			;prepare to forget what we were doing.
	xchg	ah,this_thing		;remember what we were doing.
	mov	last_thing,ah
	cmp	al,0			;function key prefix?
	jne	do_key_1		;no - run it through the hook.
	mov	ah,6			;get the key that's waiting.
	mov	dl,0ffh
	int	21h
	cmp	al,59			;F1
	jb	do_key_0
	cmp	al,68
	jbe	do_function_key		;through F10
	cmp	al,84			;sF1
	jb	do_key_0
	cmp	al,93
	jbe	do_shifted_function_key	;through sF10
do_key_0:
	mov	bx,offset key_map_list-(size key)
do_key_2:
	add	bx,(size key)
	cmp	[bx].key_value,0	;end of the list?
	je	do_key_done		;yes - we'll ignore it.
	cmp	al,[bx].key_value	;does this one match?
	jne	do_key_2		;no - try the next.
	mov	ax,[bx].key_menu	;get the menu number.
	jmp	[bx].key_address	;go execute the key.

do_menu_key:
	call	menu_key		;look up the key.
	cmp	ax,-1			;did we find it?
	je	do_key_done		;no - ignore it.
	call	do_menu
	ret
do_key_1:
	push	ax
	add	al,'@'
	call	menu_key		;look up the key.
	cmp	ax,-1			;did we find it?
	je	do_key_3		;no - send it through the hook.
	call	do_menu
	pop	ax
	ret
do_key_3:
	pop	ax
	call	menu_hook_key
do_key_done:
	ret


do_function_key:
	sub	al,59-1
	push	ax
	call	menu_hook_hide
	cmp	last_thing,0		;was the last thing we did a paste?
	je	do_function_key_1
	call	clear
do_function_key_1:
	pop	ax
	call	paste_number
	call	menu_hook_show
	inc	this_thing		;remember that this thing was a paste.
	ret


do_shifted_function_key:
	sub	al,84-1
	push	ax
	call	menu_hook_hide
	pop	ax
	call	copy_number
	call	menu_hook_show
	ret


	public	printer_ready
printer_ready:
;return cy if printer not ready.
	mov	dx,0
	mov	ah,2
	int	17h
	shl	ah,1
	cmc
	ret

code	ends

	end
