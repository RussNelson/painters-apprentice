;painth.asm - Handlers
;History:1483,1
;Sat Mar 10 20:26:06 1990 Allow characters >127 to be entered.
;Wed Nov 16 23:38:17 1988 wait_for_full_click should return nc if mouse, cy if key.
;08-18-88 18:35:27 move add_char and kill_char to paintd
;06-16-88 21:10:44 use screen_seg in paint_fatbits.
;06-16-88 20:58:47 use screen_seg in screen_bitmap
;06-16-88 20:48:58 define screen_segm
;02-05-88 22:59:39 if they press a key while moving, plop a copy down.
;01-19-88 22:35:43 when doing brush mirror, adjust for the pen size.

data	segment	public

	include	paint.def

blink_time	equ	75		;milliseconds between marquee rolls.
flash_time	equ	500		;milliseconds between cursor flashes.

; poll		(called frequently when waiting for an event)
; remove	(called just before exiting the mode)
; hide		(called before pull down menus)
; show          called after pull down menus)
; key 		key pressed (al=key).
; button 	button pressed (cx,dx=point, down_button=button).
; cursor	set cursor shape (cx,dx=cursor position)
; constrain	constrain movement (cx,dx=cursor position)


	public	menu_hooks
menu_hooks	label	word
;select_hook
	dw	select_poll
	dw	select_remove
	dw	select_hide
	dw	select_show
	dw	select_key
	dw	select_button
	dw	select_$cursor
	dw	constrain_axes
;letter_hook
	dw	letter_poll
	dw	letter_remove
	dw	letter_hide
	dw	letter_show
	dw	letter_key
	dw	letter_button
	dw	letter_$cursor
	dw	just_return
;scroll_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	scroll_button
	dw	scroll_$cursor
	dw	constrain_axes
;spray_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	spray_button
	dw	spray_$cursor
	dw	constrain_axes
;paint_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	paint_button
	dw	paint_$cursor
	dw	just_return
;pencil_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	pencil_button
	dw	pencil_$cursor
	dw	constrain_axes
;brush_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	brush_button
	dw	brush_$cursor
	dw	constrain_axes
;eraser_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	eraser_button
	dw	eraser_$cursor
	dw	constrain_axes
;line_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	line_button
	dw	rubber_$cursor_grid
	dw	constrain_axes
;open_poly_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	open_poly_handler
	dw	rubber_$cursor_grid
	dw	just_return
;open_rect_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	open_rect_button
	dw	rubber_$cursor_grid
	dw	constrain_diagonal
;fill_rect_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	fill_rect_button
	dw	rubber_$cursor_grid
	dw	constrain_diagonal
;open_round_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	open_round_button
	dw	rubber_$cursor_grid
	dw	constrain_diagonal
;fill_round_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	fill_round_button
	dw	rubber_$cursor_grid
	dw	constrain_diagonal
;open_oval_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	open_oval_button
	dw	rubber_$cursor_grid
	dw	constrain_diagonal
;fill_oval_hook
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	just_return
	dw	fill_oval_button
	dw	rubber_$cursor_grid
	dw	constrain_diagonal

cross_cursors	label	word
	dw	cross_cursor_1
	dw	cross_cursor_2
	dw	cross_cursor_4
	dw	cross_cursor_8

pen_list	label	word
	dw	dot_pen
	dw	big_dot_pen
	dw	pen_4
	dw	pen_8

select_angle_hook	dw	?
select_angle_hooks	label	word
	dw	select_angle_0
	dw	select_angle_1
	dw	select_angle_2
	dw	select_angle_3
	dw	select_angle_4
	dw	select_angle_5
	dw	select_angle_6
	dw	select_angle_7

	extrn	changes_flag: byte

	public	put_brush_subr
put_brush_subr	dw	put_brush

drag_hook	dw	?

	public	last_time
last_time	dw	?

	public	alignment
alignment	db	0		;0=left, 1=middle, 2=right.

	public	cursor_pt, first_pt
cursor_pt	point	<>		;point that cursor is at.
letter_pt	point	<>		;initial point of string.
first_pt	point	<>
second_pt	point	<>

	public	redraw_flag
redraw_flag	db	0

old_input_len	dw	?
old_style	db	?
old_font_number	db	?
old_size	db	?
old_alignment	db	?
old_letter_pt	point	<>


rubber_do	dw	?
rubber_exit	dw	rubber_while_down
poly_close	dw	0

frame_pattern	dw	?

pattern_offset	dw	0
spray_counter	db	0

on_not_off	db	?
cursor_flag	db	0
input_max_len	equ	80
input_buffer	db	input_max_len+1 dup(0)	;leave room for a null.
input_len	dw	0
undo_len	dw	0

plop_down	db	0  ;=1 if we should plop a copy down.
keep_oring	db	0  ;=1 if we should keep oring the background in.
undo_select	rect	<> ;holds the old select rect.
temp_select	rect	<> ;holds the just-moved select rect.
old_select_rect	rect	<> ;used to remember where it is on the "other" page.
original_select	rect	<> ;holds where the select rect was picked up from.

old_line_rect	rect	<>
new_line_rect	rect	<>
temp_rect	rect	<>

screen_bitmap	rect	<>
		bitmap_trailer<screen_bytes, 0, 0>

data_bitmap	bitmap<>

new_char_rect	rect	<>
old_char_rect	rect	<>
	extrn	actual_char_rect: word

no_font_msg	db	'No fonts found.',0

pen_center	point	<>		;center of the window, taking pen size into account.

	public	comspec
comspec		db	20 dup(?)

	extrn	pen_mirror: byte	;paint
	extrn	free_space: word	;paint
	extrn	clip_rect: word		;paint
	extrn	fatbits_window: byte	;paint
	extrn	fatbits_flag: byte	;paint
	extrn	page_bitmap: byte	;paint
	extrn	center_window: byte	;paint
	extrn	screen: byte		;paint
	extrn	draw_window: byte	;paint
	extrn	select_rect: byte	;paint
	extrn	down_button: byte	;paint
	extrn	current_pen: word	;paint
	extrn	fillPat: word		;paint
	extrn	last_click: word	;paint
	extrn	constrain_flag: byte	;paint
	extrn	grid_flag: byte		;paint
	extrn	page_rect: byte		;paint
	extrn	line_width: word	;paint
	extrn	menu_hook_constrain: word	;paint
	extrn	menu_hook_cursor: word	;paint
	extrn	stripe_pat: byte	;paintdat
	extrn	white_pat: byte		;paintdat
	extrn	black_pat: byte		;paintdat
	extrn	big_block: byte		;paintdat
	extrn	dot_pen: byte		;paintdat
	extrn	spray_pen: byte		;paintdat
	extrn	big_dot_pen: byte	;paintdat
	extrn	pen_8: byte		;paintdat
	extrn	pen_4: byte		;paintdat
	extrn	pointing_cursor: word	;paintdat
	extrn	select_cursor: word	;paintdat
	extrn	scroll_cursor: word	;paintdat
	extrn	letter_cursor: word	;paintdat
	extrn	paint_cursor: word	;paintdat
	extrn	spray_cursor: word	;paintdat
	extrn	brush_cursor: word	;paintg
	extrn	pencil_cursor: word	;paintdat
	extrn	eraser_cursor: word	;paintdat
	extrn	cross_cursor_1: word	;paintdat
	extrn	cross_cursor_2: word	;paintdat
	extrn	cross_cursor_4: word	;paintdat
	extrn	cross_cursor_8: word	;paintdat
	extrn	pull_down_storage: byte	;paintdat
	extrn	font: byte		;paintf
	extrn	disk_font: word		;paintf
	extrn	put_byte_subr: word	;painti
	extrn	pen: byte		;painti
	extrn	wind_on_page: byte	;paints

	extrn	screen_seg: word

data	ends


code	segment	public
	assume	cs:code, ds:data

	extrn	time_now: word			;paintg
	extrn	toggle_fatbits: near		;paint
	extrn	line_to: near			;paint
	extrn	frame_circle: near		;paintc
	extrn	fill_circle: near		;paintc
	extrn	frame_round: near		;paintc
	extrn	fill_round: near		;paintc
	extrn	paint_shape: near		;paintcan
	extrn	draw_string: near		;paintf
	extrn	draw_char: near			;paintf
	extrn	use_font: near			;paintf
	extrn	char_width: near		;paintf
	extrn	paint_fatbits: near		;paintfat
	extrn	make_mouse_pen: near		;paintg
	extrn	put_brush: near			;painti
	extrn	make_fillPat: near		;painti
	extrn	make_fillPat_white: near	;painti
	extrn	makepen: near			;painti
	extrn	makepen_dot: near		;painti
	extrn	get_rect: near			;painti
	extrn	blit: near			;painti
	extrn	pset_verb: near			;painti
	extrn	xor_verb: near			;painti
	extrn	or_verb: near			;painti
	extrn	and_verb: near			;painti
	extrn	clear_rect: near		;painti
	extrn	fill_rect: near			;painti
	extrn	read_screen_color: near		;paintg
	extrn	flip_ram: near			;paintmap
	extrn	flip_crt: near			;paintmap
	extrn	flip_cpu: near			;paintmap
	extrn	flip_ok: near			;paintmap
	extrn	protect_mouse: near		;paintmse
	extrn	unprotect_mouse: near		;paintmse
	extrn	make_mouse: near		;paintmse
	extrn	get_mouse: near			;paintmse
	extrn	equal_pt: near			;paintr
	extrn	arctan: near			;paintr
	extrn	near_pt: near			;paintr
	extrn	empty_rect: near		;paintr
	extrn	set_empty_rect: near		;paintr
	extrn	set_rect: near			;paintr
	extrn	sect_rect: near			;paintr
	extrn	pt_in_rect: near		;paintr
	extrn	inset_rect: near		;paintr
	extrn	offset_rect: near		;paintr
	extrn	peg_rect: near			;paintr
	extrn	assign_rect: near		;paintr
	extrn	frame_rect: near		;paintr
	extrn	copy_window_to_page: near	;paints
	extrn	copy_page_to_window: near	;paints
	extrn	swap_page_and_window: near	;paints
	extrn	error_alert: near		;paintd

	extrn	read_font_number: near		;paintf
	extrn	read_style: near		;paintf
	extrn	read_size: near			;paintf
	extrn	check_free_space: near		;paintdio
	extrn	set_font: near			;paintf
	extrn	do_key: near			;paint?
	extrn	ring_bell: near			;paint?
	extrn	pointing_shape: near		;paint
	extrn	make_char_box: near		;paintf


grid_on:
	test	grid_flag,2		;is gridding enabled?
	je	grid_on_1		;no.
	shr	grid_flag,1		;yes - turn it on.
grid_on_1:
	ret


grid_off:
	test	grid_flag,1		;is gridding enabled?
	je	grid_off_1		;no.
	shl	grid_flag,1		;yes - turn it off.
grid_off_1:
	ret


	public	do_fatbits
do_fatbits:
	cmp	fatbits_flag,0
	je	do_fatbits_1
	mov	bx,offset draw_window	;protect the whole thing.
	call	protect_mouse
	mov	bx,offset fatbits_window
	call	paint_fatbits
	call	unprotect_mouse
do_fatbits_1:
	ret


	public	map_fatbits
map_fatbits:
	call	get_mouse
	call	menu_hook_constrain	;perform any constraining.
	cmp	fatbits_flag,0
	je	map_fatbits_1
	sub2	draw_window.topleft
	sar	cx,1
	sar	cx,1
	sar	cx,1
	sar	dx,1
	sar	dx,1
	sar	dx,1
	add2	fatbits_window.topleft
map_fatbits_1:
	ret



constrain_diagonal:
;enter with last_click = start of rubber rectangle.
;           cx, dx = cursor position.
	cmp	constrain_flag,0	;are we constraining?
	jne	constrain_diagonal_0	;yes - constrain.
	ret				;no - return.

constrain_diagonal_0:
	push	ax
	push	bx
	mov	ax,cx
	mov	bx,dx
	load22	last_click
	sub	ax,si
	jnb	constrain_diagonal_1
	neg	ax			;ax = |cx - si|   abs(delta x)
constrain_diagonal_1:
	sub	bx,di
	jnb	constrain_diagonal_2
	neg	bx			;bx = |dx - di|   abs(delta y)
constrain_diagonal_2:
	cmp	ax,bx
	jb	constrain_adjust_dx
	je	constrain_diagonal_end

;delta y (|dx - di|) is smaller.
	cmp	cx,si
	ja	to_right
	mov	cx,si
	sub	cx,bx
	jmp	short constrain_diagonal_end
to_right:
	mov	cx,si
	add	cx,bx
	jmp	short constrain_diagonal_end

constrain_adjust_dx:
;delta x (|dx - di|) is smaller.
	cmp	dx,di
	ja	to_bot
	mov	dx,di
	sub	dx,ax
	jmp	short constrain_diagonal_end
to_bot:
	mov	dx,di
	add	dx,ax

constrain_diagonal_end:
	pop	bx
	pop	ax
	ret


constrain_axes:
	push	ax
	mov	al,constrain_flag	;=0 for no constrain,=1 for h,=2 for v.
	or	al,al
	je	constrain_axes_1
	dec	al			;in h?
	je	constrain_axes_2
	mov	dx,last_click.v		;in v.
	jmp	short constrain_axes_1
constrain_axes_2:
	mov	cx,last_click.h		;in v.
constrain_axes_1:
	pop	ax
	ret


	public	put_rect
put_rect:
;enter with bx->rect to put object at, si->put object.

;setup the source bitmap.
	mov	data_bitmap.bounds.left,0
	mov	data_bitmap.bounds.top,0
	load2	[si]
	store2	data_bitmap.bounds.botright

	mov	ax,[si].h		;compute the width of the source bitmap.
	add	ax,7			;round up.
	shr	ax,1
	shr	ax,1
	shr	ax,1
	mov	data_bitmap.bytes,ax

	add	si,(size point)
	mov	data_bitmap.pntr.segm,ds	;ds:si->source bitmap.
	mov	data_bitmap.pntr.offs,si


;setup the dest bitmap
	mov	ax,screen_seg
	mov	screen_bitmap.pntr.segm,ax

	mov	si,bx			;copy the source rect to the source bitmap.
	mov	bx,clip_rect
	mov	di,offset screen_bitmap.bounds
	call	sect_rect

	mov	bx,offset data_bitmap.bounds
	load2	[di].topleft		;how much did the rect get clipped by?
	sub2	[si].topleft
	add	[bx].left,cx		;reduce the source rect by that amount.
	add	[bx].top,dx

	load2	[si].botright		;. .
	sub2	[di].botright
	sub	[bx].right,cx		;. .
	sub	[bx].bot,dx
	xchg	di,si			;now copy the clipped rect back.
	call	assign_rect

;now do the transfer.
	mov	si,offset data_bitmap
	mov	di,offset screen_bitmap
	call	blit
	ret


	public	update_page
update_page:
;this used to be do_undo.
	mov	bx,offset draw_window	;protect the whole thing.
	call	protect_mouse
	cmp	fatbits_flag,0
	je	update_page_1
	call	setup_fatbits
	call	blit
	mov	bx,offset fatbits_window
	call	paint_fatbits
	jmp	short update_page_2
update_page_1:
	call	copy_window_to_page
update_page_2:
	call	unprotect_mouse
	ret


	public	undo_update
undo_update:
	mov	bx,offset draw_window	;protect the whole thing.
	call	protect_mouse
	mov	ax,input_len
	xchg	ax,undo_len
	mov	input_len,ax
	load2	select_rect.topleft
	xchg2	undo_select.topleft
	store2	select_rect.topleft
	load2	select_rect.botright
	xchg2	undo_select.botright
	store2	select_rect.botright
	cmp	fatbits_flag,0
	je	undo_update_1
	call	setup_fatbits
	mov	put_byte_subr,offset xor_verb
	xchg	si,di			;copying from page to fatbits
	push	si
	push	di
	call	blit
	pop	si
	pop	di
	push	di
	push	si
	call	blit
	pop	di
	pop	si
	call	blit
	call	do_fatbits
	jmp	short undo_update_2
undo_update_1:
	call	swap_page_and_window
undo_update_2:
	call	unprotect_mouse
	ret


	public	update_window
update_window:
; this is the opposite of update_page!
	mov	bx,offset draw_window	;protect the whole thing.
	call	protect_mouse
	cmp	fatbits_flag,0		;are we doing fatbits?
	je	update_window_3	;no.
	call	setup_fatbits
	xchg	si,di			;copying from page to fatbits
	call	blit
	mov	bx,offset fatbits_window
	call	paint_fatbits
	jmp	short update_window_4
update_window_3:
	call	copy_page_to_window
update_window_4:
	call	unprotect_mouse
	ret


setup_fatbits:
	mov	si,offset fatbits_window
	mov	ax,screen_seg
	mov	[si].pntr.segm,ax
	mov	di,offset page_bitmap
	load2	wind_on_page
	store2	[di].topleft
	mov	ax,[si].right
	sub	ax,[si].left
	add	cx,ax
	mov	ax,[si].bot
	sub	ax,[si].top
	add	dx,ax
	store2	[di].botright
	mov	put_byte_subr,offset pset_verb
	ret

	public	restore_page
restore_page:
;enter with bx->rectangle on screen to restore from the page.
	mov	put_byte_subr,offset pset_verb

restore_page_pbs:
	call	empty_rect
	jnc	restore_page_2

	call	protect_mouse
	push	bx

	mov	ax,screen_seg
	mov	screen_bitmap.pntr.segm,ax

	mov	si,clip_rect		;only restore the part on the screen.
	mov	di,offset screen_bitmap
	call	sect_rect

	mov	si,offset page_bitmap
	mov	di,offset screen_bitmap
	load2	wind_on_page		;get the window's location on the page.
	cmp	fatbits_flag,0		;if we're not in fatbits, truncate
	jne	restore_page_1
	and	cx,0fff8h
restore_page_1:
	add2	[di].topleft
	mov	bx,clip_rect
	sub2	[bx].topleft
	store2	[si].topleft
	add2	[di].botright
	sub2	[di].topleft
	store2	[si].botright

	call	blit
	call	unprotect_mouse
	pop	bx
restore_page_2:
	ret


line_to_first_point:
	load22	first_pt
	jmp	line_to


	public	clear
clear:
	mov	changes_flag,1		;say that there have been changes.
	mov	bx,offset select_rect
	call	restore_page
	call	set_empty_rect
	mov	free_space,offset pull_down_storage
	call	clear_original
	ret


select_poll:
	mov	bx,offset select_rect	;get the rectangle.
	call	empty_rect		;is there one?
	jnc	select_poll_2		;no - skip this stuff.
	mov	ax,time_now		;time to blink?
	sub	ax,last_time
	cmp	ax,blink_time/10	;blink every blink_time.
	jb	select_poll_2
	mov	ax,time_now
	mov	last_time,ax
	mov	ax,pattern_offset	;and put the new one up shifted over.
	dec	ax
	and	ax,7
	mov	pattern_offset,ax
	call	draw_select
	call	do_fatbits
select_poll_2:
	ret

select_remove:
	mov	bx,offset select_rect	;kill the select rect.
	call	set_empty_rect
	mov	bx,offset undo_select	;say that there wasn't one before.
	call	set_empty_rect
	mov	free_space,offset pull_down_storage
	jmp	short select_hook_exit

select_hide:
	mov	bx,offset select_rect	;get the rectangle.
	call	empty_rect		;is there one?
	jnc	select_hook_exit	;no - skip this stuff.
	mov	keep_oring,0		;not oring at this time.
	call	draw_moving
	jmp	short select_hook_exit

select_show:
	mov	bx,offset select_rect	;get the rectangle.
	call	empty_rect		;is there one?
	jnc	select_hook_exit	;no - skip this stuff.

	call	get_select

	mov	si,offset select_rect	;remember where we just put it.
	mov	di,offset old_select_rect
	call	assign_rect

	call	draw_select		;put the marquee back.
	jmp	short select_hook_exit

select_key:
	ret

select_button:
	mov	changes_flag,1		;say that there have been changes.
	call	select_handler

select_hook_exit:
	call	do_fatbits
	ret


select_$cursor:
	call	grid_on
	mov	bx,offset select_rect
	call	pt_in_rect		;are we in the select rect?
	mov	si,offset pointing_cursor	;assume yes.
	jnc	select_cursor_1
	mov	si,offset select_cursor	;no - use crosshairs.
select_cursor_1:
	ret


select_handler:
	mov	keep_oring,0		;not oring at this time.
	call	map_fatbits
	mov	bx,offset select_rect
	call	pt_in_rect		;click in box?
	jnc	select_handler_1	;yes - we want to move it.
  if 0
	call	is_fingers		;are they using the right button?
	jnc	select_handler_3	;yes - scroll.
  endif
	store2	first_pt		;save where first click was.
	mov	bx,offset select_rect	;is there a select rect already?
	call	empty_rect
	jnc	select_handler_2	;no - don't get rid of it.
	call	draw_moving		;get rid any old select marquee.
select_handler_2:
	call	make_select_rect	;rubber marquee handler.
	mov	bx,offset select_rect
	call	empty_rect
	jnc	select_handler_3

	call	get_select		;get it off of the screen.

	mov	si,offset select_rect	;this is where we picked it up from.
	call	start_select		;make it ready to move, size, etc.
	call	draw_select		;draw the marquee.

select_handler_3:
	ret

select_handler_1:
	sub2	select_rect.topleft	;remember how far into the rect it was.
	store2	first_pt
	load2	select_rect.topleft	;remember where the rect originally was.
	store2	second_pt
	cmp	down_button,2		;is the right button down?
	jne	select_handler_4	;no.
	load2	second_pt		;recover the original point.
	add2	first_pt
	call	select_angle		;determine which edge they selected.
select_handler_4:
	call	do_fatbits
	mov	si,offset select_rect	;keep a copy for moving.
	mov	di,offset temp_select
	call	assign_rect
	mov	plop_down,0		;not plopping down.
	call	flip_ok			;should we flip?
	jc	select_handler_5	;no.
	mov	bx,offset draw_window
	call	protect_mouse
	call	flip_ram
	call	flip_cpu		;remove it from the other page.
	call	erase_moving
	call	flip_cpu
	call	unprotect_mouse
select_handler_5:
	mov	dl,0ffh			;read keyboard.
	mov	ah,6			;only if key is available.
	int	21h
	jz	select_handler_9	;no key available.
	mov	plop_down,1
select_handler_9:
	cmp	down_button,1		;did they press the left button?
	jne	select_handler_6	;no.
	call	get_mouse		;is the right button down also?
	test	bl,2
	je	select_handler_6	;no.
	mov	keep_oring,1		;yes - left was pressed, then right.
	mov	second_pt.h,-1		;ensure that it gets redrawn.
	mov	second_pt.v,-1
select_handler_6:
	call	map_fatbits
	push	bx
	call	move_select
	pop	bx
	test	bl,down_button
	jne	select_handler_5
	mov	bx,offset select_rect	;did they shrink it to nothingness?
	call	empty_rect
	jnc	select_handler_7	;yes - no marquee, no select box.
	call	draw_moving		;get rid of the marquee
	call	get_select		;get the new select box.
select_handler_7:
	ret


	public	get_select
get_select:
	mov	bx,offset select_rect
	call	protect_mouse
	mov	si,offset pull_down_storage
	call	get_rect
	mov	free_space,si
	call	check_free_space
	call	unprotect_mouse
	ret


	public	start_select
start_select:
;enter with si->where the rect used to be.
	mov	keep_oring,0		;not oring at this time.
	mov	di,offset original_select
	call	assign_rect

	mov	bx,offset undo_select	;say that there wasn't one before.
	call	set_empty_rect
	call	update_page			;so that when we move it, it's gone.
	call	draw_moving		;put the contents back up.
	mov	si,offset select_rect
	mov	di,offset old_select_rect
	call	assign_rect
	ret


select_angle:
;enter with cx,dx=clicked point.
	mov	bx,offset temp_rect
	mov	[bx].right,cx
	mov	[bx].bot,dx
	mov	cx,select_rect.right
	sub	cx,select_rect.left
	shr	cx,1
	add	cx,select_rect.left
	mov	[bx].left,cx
	mov	dx,select_rect.bot
	sub	dx,select_rect.top
	shr	dx,1
	add	dx,select_rect.top
	mov	[bx].top,dx
	call	arctan
	add	ax,45/2			;rotate by a half a notch.
	mov	bx,45
	mov	dx,0
	div	bx
	mov	bl,al			;make bx index into table of 8 words.
	and	bl,7
	mov	bh,0
	shl	bx,1
	mov	bx,select_angle_hooks[bx]
	mov	select_angle_hook,bx
	ret


select_angle_0:
	add	[bx].right,cx
	ret
select_angle_1:
	add	[bx].right,cx
	add	[bx].top,dx
	ret
select_angle_2:
	add	[bx].top,dx
	ret
select_angle_3:
	add	[bx].left,cx
	add	[bx].top,dx
	ret
select_angle_4:
	add	[bx].left,cx
	ret
select_angle_5:
	add	[bx].left,cx
	add	[bx].bot,dx
	ret
select_angle_6:
	add	[bx].bot,dx
	ret
select_angle_7:
	add	[bx].right,cx
	add	[bx].bot,dx
	ret


move_select:
;we get here with the select box at select_rect.
;  the distance from the original point to the original topleft is in first_pt
;  the point that they most recently were at is second_pt.
;  the new point is in cx,dx.
	sub2	first_pt
	mov	bx,offset second_pt
	call	equal_pt
	jc	move_select_2		;changed?
	ret				;no.
move_select_2:
	store2	second_pt		;yes - remember where the point is now.
	push	cx
	push	dx
	mov	si,offset temp_select	;restore the original rect.
	mov	di,offset select_rect
	call	assign_rect
	pop	dx
	pop	cx
	cmp	down_button,2		;is the right button down?
	je	move_select_1
	mov	si,offset select_rect
	mov	di,clip_rect
	call	peg_rect
	sub2	temp_select.topleft	;compute the total distance moved.
	mov	bx,offset select_rect
	call	offset_rect
	jmp	short move_select_3
move_select_1:
	sub2	temp_select.topleft	;compute the total distance moved.
	mov	bx,offset select_rect
	call	select_angle_hook
	load2	[bx].topleft
	load22	[bx].botright
	call	set_rect
	mov	di,bx			;now intersect it with the window.
	mov	si,clip_rect
	call	sect_rect
	cmp	cx,si			;zero width?
	jne	move_select_6		;no.
	inc	[bx].right		;yes - make it one wide.
move_select_6:
	cmp	dx,di			;zero height?
	jne	move_select_3		;no.
	inc	[bx].bot		;yes - make it one tall.
move_select_3:
	mov	bx,offset screen
	call	protect_mouse

	call	flip_ok			;should we flip?
	jc	move_select_4		;no.
	call	flip_cpu
	call	clear_original
	call	draw_moving		;draw the new on the other page
	call	draw_select
	call	do_fatbits
	call	flip_crt		;show the other page.

	call	flip_cpu
	call	erase_moving		;erase the old from this page.
	call	flip_cpu
	jmp	short move_select_5
move_select_4:
	call	erase_moving		;erase the old from this page.
	call	clear_original
	call	draw_moving		;draw the new on the other page
	call	draw_select
	call	do_fatbits
move_select_5:

	mov	si,offset select_rect	;now remember where we just put it.
	mov	di,offset old_select_rect
	call	assign_rect

	call	unprotect_mouse
	ret


	public	erase_moving
erase_moving:
	mov	bx,offset old_select_rect
	call	protect_mouse
	call	restore_page
	cmp	plop_down,0		;should we plop a copy down?
	jz	erase_moving_1
	mov	put_byte_subr,offset pset_verb
	mov	si,offset pull_down_storage
	call	put_rect
	call	update_page		;now put it back on the page.
	mov	plop_down,0		;remember that we've done it.
erase_moving_1:
	call	unprotect_mouse
	ret


	public	clear_original
clear_original:
	mov	bx,offset original_select	;erase where we picked it up from.
	call	clear_rect
	ret


	public	draw_moving
draw_moving:
	mov	put_byte_subr,offset pset_verb
	mov	si,offset pull_down_storage
	mov	bx,offset select_rect
	call	protect_mouse
	call	put_rect
	call	unprotect_mouse
	cmp	keep_oring,0		;should we be oring?
	je	draw_moving_1		;no.
draw_moving_2:
  if black_on_white
	mov	put_byte_subr,offset and_verb	;yes - and it in.
  else
	mov	put_byte_subr,offset or_verb	;yes - or it in.
  endif
	mov	bx,offset select_rect
	call	restore_page_pbs
draw_moving_1:
	ret


	public	center_select
center_select:
	mov	bx,clip_rect		;compute the size of the window
	load2	[bx].botright
	sub2	[bx].topleft
	sar	cx,1
	sar	dx,1
	add2	[bx].topleft		;compute the center of the window.

	store2	select_rect.topleft	;now put the select in the topleft
	mov	bx,offset pull_down_storage
	load2	[bx]
	add2	select_rect.topleft
	store2	select_rect.botright

	load2	[bx]			;now center the select in the window.
	sar	cx,1
	sar	dx,1
	neg	cx
	neg	dx
	mov	bx,offset select_rect
	call	offset_rect

	load2	select_rect.topleft	;compute the current position on the
	mov	bx,clip_rect		;  page.
	sub2	[bx]
	add2	wind_on_page
	and	cx,7
	and	dx,7

	neg	cx			;now move it back by that much.
	neg	dx
	mov	bx,offset select_rect
	call	offset_rect
	ret


draw_select:
	mov	pen.pnMode,offset pset_verb
draw_select_xor:
	mov	si,offset stripe_pat
	add	si,pattern_offset
	call	make_fillPat
	call	makepen_dot
	mov	bx,offset select_rect
	call	protect_mouse
	call	frame_rect
	call	unprotect_mouse
	ret


make_select_rect:
;enter with first_pt = corner of rect.
;exit with select box removed from the screen.
	mov	pen.pnMode,offset xor_verb
	load2	first_pt
	store2	second_pt
make_select_rect_1:
	load2	second_pt		;calculate the rectangle
	load22	first_pt
	mov	bx,offset select_rect
	call	set_rect
	inc	[bx].right		;include the bottom right.
	inc	[bx].bot
	mov	di,bx
	mov	si,clip_rect
	call	sect_rect		;clip to the window.
	call	draw_select_xor		;draw the new.
make_select_rect_2:
	call	do_fatbits
	call	map_fatbits
	test	bl,down_button		;is the button up?
	je	make_select_rect_3	;yes.
	mov	ax,time_now		;time to blink?
	sub	ax,last_time
	cmp	ax,blink_time/10	;blink every blink_time.
	jae	make_select_rect_4
	mov	bx,offset second_pt
	call	equal_pt		;has endpoint changed?
	jnc	make_select_rect_2	;no.
	store2	second_pt		;remember the new endpoint.
	call	draw_select_xor		;erase the old.
	jmp	make_select_rect_1
make_select_rect_4:
	store2	second_pt		;remember the new endpoint.
	mov	ax,time_now
	mov	last_time,ax
	call	draw_select_xor		;erase the old.
	mov	ax,pattern_offset	;and put the new one up shifted over.
	dec	ax
	and	ax,7
	mov	pattern_offset,ax
	jmp	make_select_rect_1
make_select_rect_3:
	call	draw_select_xor		;erase the old.
	ret


scroll_$cursor:
	call	grid_on
	mov	si,offset scroll_cursor
	ret


scroll_button:
	call	get_mouse
	store2	first_pt		;save old mouse position.
	load2	wind_on_page		;remember where we were on the page.
	store2	second_pt
	call	update_page			;save the current screen.
scroll_1:
	call	get_mouse		;get new mouse position.
	test	bl,down_button		;did they release yet?
	je	scroll_2
	sub2	first_pt
	neg	dx
	neg	cx
	add2	second_pt
	mov	si,clip_rect		;->box we're dragging around.
	mov	di,offset page_rect
	call	peg_rect
	mov	bx,offset wind_on_page	;have we moved?
	call	equal_pt
	jnc	scroll_1		;no.
	store2	[bx]			;say that we're here.

	call	update_window
  if 0
	mov	bx,offset select_rect	;is there a select rect?
	call	empty_rect
	jnc	scroll_1		;no.

	call	draw_moving		;place it in its old location.
	call	draw_select		;put a box around it.
	call	do_fatbits

  endif
	jmp	scroll_1
scroll_2:
	ret


letter_poll:
	cmp	cursor_flag,0		;should we blink?
	je	letter_poll_2		;no.
	mov	ax,time_now		;time to blink?
	sub	ax,last_time
	cmp	ax,flash_time/10	;blink every flash_time.
	jb	letter_poll_2
	call	draw_char_cursor	;blink the cursor.
letter_poll_1:
	call	do_fatbits
letter_poll_2:
	ret
letter_remove:
	mov	bx,offset old_char_rect	;are we in the letter rect?
	call	set_empty_rect
	mov	cursor_flag,0
	jmp	short letter_hook_exit
letter_hide:
	cmp	cursor_flag,0		;should we draw?
	je	letter_hook_exit	;no.
	mov	si,disk_font
	call	use_font		;use the font off the disk now.
	call	remove_char_cursor
	jmp	short letter_hook_exit
letter_show:
	cmp	cursor_flag,0		;should we draw?
	je	letter_hook_exit	;no.
	mov	si,disk_font
	call	use_font		;use the font off the disk now.
	call	redraw_line		;redisplay the entire thing.
letter_hook_exit:
	call	do_fatbits
	ret
letter_key:
	cmp	cursor_flag,0		;did they select a cursor?
	je	letter_key_1		;no - ignore keys.
	mov	si,disk_font
	call	use_font		;use the font off the disk now.
	call	char_handler
	call	do_fatbits
letter_key_1:
	ret


letter_button:
	mov	changes_flag,1		;say that there have been changes.
	cmp	disk_font,0		;is there a font to use?
	jne	letter_button_3
	call	set_font		;get the font from the disk.
letter_button_3:
	cmp	disk_font,0		;is there a font to use?
	jne	letter_button_1
	mov	si,offset no_font_msg	;no - give them an error.
	call	error_alert
	ret
letter_button_1:
	call	map_fatbits
  if 0
	cmp	cursor_flag,0		;are there letters up already?
	je	letter_handler		;no - start a new letter rect.
  else
	mov	bx,offset old_char_rect	;are we in the letter rect?
	call	pt_in_rect
	jc	letter_handler		;no - start a new letter rect.
	sub2	old_letter_pt		;find out how far into the rect we are.
	store2	first_pt
	add2	old_letter_pt		;restore the point.
  endif
letter_button_2:
	sub2	first_pt		;compute where the new letter point should be.
	store2	letter_pt		;remember the new first point.
	call	redraw_line		;put the line up here.
	call	map_fatbits
	test	bl,down_button		;is the button up yet?
	jne	letter_button_2		;no - keep moving the letters around.
	ret
letter_handler:
	push	cx
	push	dx
	mov	si,disk_font
	call	use_font		;use the font off the disk now.
	call	remove_char_cursor	;kill any old one.
	call	update_page
	call	flip_ram
	pop	dx
	pop	cx
	store2	letter_pt		;remember where we started.
	store2	cursor_pt		;remember where the cursor is.
	mov	input_len,0		;zero length.
	mov	old_input_len,-1	;remember to draw it.
	mov	si,disk_font
	call	use_font		;use the font off the disk now.
	mov	bx,offset old_char_rect
	call	set_empty_rect
	call	wait_for_up
	call	draw_char_cursor	;draw the new cursor.
	mov	cursor_flag,1
	jmp	letter_hook_exit


letter_$cursor:
	call	grid_on
	mov	bx,offset old_char_rect
	call	pt_in_rect		;are we in the letter rect?
	mov	si,offset pointing_cursor	;assume yes.
	jnc	letter_cursor_1
	mov	si,offset letter_cursor	;no - use I beam.
letter_cursor_1:
	ret


redraw_line:
;enter with input_buffer, input_len describing the line.
;using alignment, place the line.
;exit with old_char_rect enclosing the line.
	cmp	redraw_flag,0		;should we redraw?
	jne	redraw_line_0		;yes.
	mov	ax,letter_pt.h
	cmp	ax,old_letter_pt.h
	jne	redraw_line_0
	mov	ax,letter_pt.v
	cmp	ax,old_letter_pt.v
	jne	redraw_line_0
	mov	ax,input_len
	cmp	ax,old_input_len
	jne	redraw_line_0
	call	read_style
	cmp	al,old_style
	jne	redraw_line_0
	call	read_font_number
	cmp	al,old_font_number
	jne	redraw_line_0
	call	read_size
	cmp	al,old_size
	jne	redraw_line_0
	mov	al,alignment
	cmp	al,old_alignment
	jne	redraw_line_0
	ret
redraw_line_0:
	mov	redraw_flag,0
	mov	ax,letter_pt.h
	mov	old_letter_pt.h,ax
	mov	ax,letter_pt.v
	mov	old_letter_pt.v,ax
	mov	al,alignment
	mov	old_alignment,al
	mov	ax,input_len
	mov	old_input_len,ax
	call	read_style
	mov	old_style,al
	call	read_font_number
	mov	old_font_number,al
	call	read_size
	mov	old_size,al

  if 0
	call	flip_cpu		;draw the new one.
	call	flip_ok			;should we erase first?
	jnc	redraw_line_5		;no.
	call	remove_char_cursor
	mov	bx,offset old_char_rect	;erase what was there.
	call	restore_page
redraw_line_5:
  else
	call	remove_char_cursor
	mov	bx,offset old_char_rect	;erase what was there.
	call	restore_page
  endif

	load2	letter_pt		;get the starting point.
	sub	dx,font.ascent
	store2	new_char_rect.topleft

;compute the width of the line.
	mov	si,offset input_buffer
	mov	bx,input_len
	or	bx,bx
	je	redraw_line_2
redraw_line_1:
	lodsb
	call	char_width
	mov	ah,0
	add	cx,ax
	dec	bx
	jne	redraw_line_1
redraw_line_2:
	mov	dx,letter_pt.v
	add	dx,font.descent
	store2	new_char_rect.botright

;now handle the alignment.
	mov	bx,offset new_char_rect
	mov	ax,[bx].right		;compute the width of the rect.
	sub	ax,[bx].left
	xor	cx,cx
	xor	dx,dx
	cmp	alignment,0		;left?
	je	redraw_line_3
	cmp	alignment,2		;right?
	je	redraw_line_4
	sar	ax,1			;center it horizontally.
redraw_line_4:
	mov	cx,ax			;right align it.
	neg	cx
redraw_line_3:
	call	offset_rect

	mov	bx,offset new_char_rect
	call	protect_mouse

	mov	cx,new_char_rect.left
	mov	dx,letter_pt.v
	mov	si,offset input_buffer
	mov	bx,input_len
	mov	input_buffer[bx],0	;store a terminating null.
	call	draw_string
	store2	cursor_pt

	call	draw_char_cursor
	call	unprotect_mouse

  if 0
	call	flip_ok			;should we flip?
	jc	redraw_line_6		;no.
	call	flip_crt		;now show the new and erase the old.
	call	flip_cpu
	call	remove_char_cursor
	mov	bx,offset old_char_rect	;erase what was there.
	call	restore_page
	call	flip_cpu
redraw_line_6:
  endif
	mov	si,offset actual_char_rect
	mov	di,offset old_char_rect
	call	assign_rect
;	mov	bx,offset old_char_rect	;make it a bit bigger
;	mov	cx,20
;	mov	dx,20
;	call	inset_rect
	ret


char_handler:
	cmp	al,8dh			;enter?
	je	char_handler_enter
	cmp	al,0dh			;return?
	je	char_handler_cr
	cmp	al,08h			;back space?
	je	char_handler_del
	cmp	al,7fh			;delete?
	je	char_handler_del
;	ja	char_handler_exit	;special key? yes - ignore it.
	cmp	al,' '			;control key?
	jb	char_handler_exit	;yes - ignore it.

	mov	bx,input_len		;get length.
	cmp	bx,input_max_len	;did we overflow the input buffer?
	jae	char_handler_exit	;yes - ignore this char.
	mov	input_buffer[bx],al	;store the char in the right place.
	inc	input_len
char_handler_redraw:
	call	redraw_line		;add this char in.
char_handler_exit:
	ret

char_handler_enter:
;start a new line at the same place.
	load2	cursor_pt
	jmp	letter_handler

char_handler_cr:
;move the cursor down a line.
	load2	letter_pt		;get the old first point back.
	add	dx,font.descent
	add	dx,font.leading
	add	dx,font.ascent		;go down to the next baseline.
	jmp	letter_handler		;pretend that they pressed the button.

char_handler_del:
;delete a character from the end.
	cmp	input_len,0		;at beginning of buffer?
	je	char_handler_exit	;yes - ignore it.
	dec	input_len
	jmp	char_handler_redraw


	public	remove_char_cursor, draw_char_cursor
remove_char_cursor:
	cmp	on_not_off,0		;is the cursor up?
	je	remove_char_cursor_1	;no.
draw_char_cursor:
	mov	ax,time_now		;remember when it's next time to blink.
	mov	last_time,ax
  if black_on_white
	mov	si,offset black_pat
  else
	mov	si,offset white_pat
  endif
	call	make_fillPat
	call	makepen_dot
	mov	pen.pnMode,offset xor_verb	;xor.
	load2	cursor_pt
	mov	si,cx
	mov	di,dx
	sub	dx,font.ascent
	add	di,font.descent
	call	line_to
	xor	on_not_off,1		;toggle the cursor.
remove_char_cursor_1:
	ret


paint_$cursor:
	mov	si,offset paint_cursor
	ret


paint_button:
	mov	changes_flag,1		;say that there have been changes.
	mov	si,fillPat
	call	make_fillPat
	call	update_page
	mov	bx,clip_rect		;protect the whole screen.
	call	protect_mouse
	call	flip_ram
	call	flip_crt

	call	map_fatbits		;convert the coordinates.
	store2	first_pt
	call	paint_shape

	call	wait_for_up
	call	unprotect_mouse
	call	do_fatbits
	ret


is_fingers:
;see if they're using the right button to scroll around.
;return cy if they aren't, nc if they did.
	cmp	down_button,2		;did they press the right button?
	stc
	jne	is_fingers_1		;no.
	push	cx
	push	dx
	call	scroll_$cursor
	call	make_mouse
	pop	dx
	pop	cx
	call	scroll_button		;scroll around.
	call	grid_off		;turn the grid off in case it's on.
	call	menu_hook_cursor	;find out what cursor we were using.
	call	make_mouse
	call	map_fatbits		;did they press the left button too?
	test	bl,1
	je	is_fingers_2	;no.
	mov	down_button,bl		;say that the left button was pressed.
	store2	first_pt		;remember where we were.
	call	toggle_fatbits
	call	wait_for_up
is_fingers_2:
	clc
is_fingers_1:
	ret


spray_$cursor:
	mov	si,offset spray_cursor
	ret

spray_button:
	call	is_fingers
	jnc	spray_button_2
	mov	spray_counter,0
	mov	put_brush_subr,offset put_spray
	mov	ax,offset pset_verb
	mov	bx,offset do_spray
	mov	cx,fillPat
	mov	dx,offset spray_pen
	call	drag_around
	mov	put_brush_subr,offset put_brush
spray_button_2:
	ret


brush_$cursor:
	mov	si,current_pen		;the pen shape may have changed.
	call	make_mouse_pen
	mov	si,offset brush_cursor
	ret


brush_button:
	call	is_fingers
	jnc	pencil_button_2
	load2	center_window		;make a new center, adjusted by the
	call	adjust_by_pnSize	;  pen size.
	store2	pen_center
	mov	ax,offset pset_verb
	mov	cx,fillPat
	mov	dx,current_pen
	mov	bx,offset do_brush
	jmp	drag_around


eraser_$cursor:
	mov	si,offset eraser_cursor
	ret

eraser_button:
	call	is_fingers
	jnc	pencil_button_2
	mov	dx,offset big_block
	cmp	fatbits_flag,0		;fatbits?
	je	eraser_button_3
	mov	dx,offset big_dot_pen	;yes - use a two by two eraser.
eraser_button_3:
	mov	ax,offset pset_verb
	mov	bx,offset do_eraser
	mov	cx,offset black_pat
	jmp	drag_around


pencil_$cursor:
	mov	si,offset pencil_cursor
	ret

pencil_button:
	call	is_fingers
	jnc	pencil_button_2
	mov	bx,clip_rect
	call	protect_mouse
	call	map_fatbits
	call	read_screen_color	;don't read the mouse cursor's pixel.
	mov	cx,offset black_pat
	jc	pencil_button_4		;if it's a one, use black.
	mov	cx,offset white_pat
pencil_button_4:
	call	unprotect_mouse
	mov	ax,offset pset_verb
	mov	bx,offset do_pencil
	mov	dx,offset dot_pen
	jmp	drag_around
pencil_button_2:
	ret


do_spray:
do_pencil:
do_eraser:
	mov	si,cx
	mov	di,dx
	load2	first_pt
	jmp	line_to

put_spray:
	inc	spray_counter
	cmp	spray_counter,15
	jne	put_spray_1
	mov	spray_counter,0
	call	put_brush
put_spray_1:
	ret


do_brush:
	mov	si,cx
	mov	di,dx
	load2	first_pt
	call	line_to
	test	pen_mirror,1		;mirror around 0 --.
	je	do_brush_3
	mov	cx,first_pt.h
	mov	dx,pen_center.v
	shl	dx,1
	sub	dx,first_pt.v
	mov	si,second_pt.h
	mov	di,pen_center.v
	shl	di,1
	sub	di,second_pt.v
	call	line_to
do_brush_3:
	test	pen_mirror,4		;mirror around 90 |.
	je	do_brush_4
	mov	cx,pen_center.h
	shl	cx,1
	sub	cx,first_pt.h
	mov	dx,first_pt.v
	mov	si,pen_center.h
	shl	si,1
	sub	si,second_pt.h
	mov	di,second_pt.v
	call	line_to
do_brush_4:
	mov	al,pen_mirror		;combination of 45 + 135 \ /
	and	al,2+8
	cmp	al,2+8
	je	do_brush_8
	mov	al,pen_mirror		;combination of 0 + 90 | --
	and	al,1+4
	cmp	al,1+4
	jne	do_brush_7
do_brush_8:
	load2	pen_center
	sub2	first_pt
	add2	pen_center
	load22	pen_center
	sub22	second_pt
	add22	pen_center
	call	line_to
do_brush_7:
	test	pen_mirror,8		;mirror around 135 \.
	je	do_brush_5
	load2	first_pt
	sub2	pen_center
	xchg	cx,dx			;swap them
	add2	pen_center		;center them again.
	load22	second_pt		;do the same for the second point.
	sub22	pen_center
	xchg	si,di
	add22	pen_center
	call	line_to
do_brush_5:
	test	pen_mirror,2		;mirror around 45 /.
	je	do_brush_6
	load2	pen_center
	sub2	first_pt
	xchg	cx,dx
	add2	pen_center
	load22	pen_center
	sub22	second_pt
	xchg	si,di
	add22	pen_center
	call	line_to
do_brush_6:
	mov	al,pen_mirror		;combination of 45 + 0 / --.
	and	al,2+1
	cmp	al,2+1
	jne	do_brush_9
	load2	pen_center
	sub2	first_pt
	xchg	cx,dx
	neg	dx
	add2	pen_center
	load22	pen_center
	sub22	second_pt
	xchg	si,di
	neg	di
	add22	pen_center
	call	line_to
do_brush_9:
	mov	al,pen_mirror		;combination of 135 + 0 \ --.
	and	al,8+1
	cmp	al,8+1
	jne	do_brush_a
	load2	first_pt
	sub2	pen_center
	xchg	cx,dx
	neg	dx
	add2	pen_center
	load22	second_pt
	sub22	pen_center
	xchg	si,di
	neg	di
	add22	pen_center
	call	line_to
do_brush_a:
	mov	al,pen_mirror		;combination of 135 + 90 \ |.
	and	al,8+4
	cmp	al,8+4
	jne	do_brush_b
	load2	first_pt
	sub2	pen_center
	xchg	cx,dx
	neg	cx
	add2	pen_center
	load22	second_pt
	sub22	pen_center
	xchg	si,di
	neg	si
	add22	pen_center
	call	line_to
do_brush_b:
	mov	al,pen_mirror		;combination of 45 + 90 / |.
	and	al,2+4
	cmp	al,2+4
	jne	do_brush_c
	load2	pen_center
	sub2	first_pt
	xchg	cx,dx
	neg	cx
	add2	pen_center
	load22	pen_center
	sub22	second_pt
	xchg	si,di
	neg	si
	add22	pen_center
	call	line_to
do_brush_c:
	ret


drag_around:
;enter with:
;  ax = pen mode
;  bx->routine to continue dragging,
;  cx = fill pattern
;  dx = new pen
	mov	changes_flag,1		;say that there have been changes.
	mov	pen.pnMode,ax
	push	cx
	mov	drag_hook,bx
	mov	si,dx
	call	makepen
	pop	si			;pushed as cx (fill pattern)
	call	make_fillPat
	call	update_page
	call	map_fatbits
	call	adjust_by_pnSize
	store2	first_pt
drag_around_1:
	store2	second_pt
	call	drag_hook		;do anything else we want to do.
	load2	second_pt
	store2	first_pt
	call	do_fatbits
drag_around_4:
	call	map_fatbits
	test	bl,down_button
	je	drag_around_2
	call	adjust_by_pnSize
	mov	bx,offset second_pt	;are we still there?
	call	equal_pt
	jnc	drag_around_4		;yes - wait for a change.
	jmp	drag_around_1
drag_around_2:
	ret


line_button:
	mov	bx,offset do_line_button
	jmp	rubber_handler
do_line_button:
	load2	second_pt
	call	line_to_first_point	;draw the line
	ret



open_rect_button:
	mov	bx,offset do_opened_rect
	jmp	rubber_handler

fill_rect_button:
	mov	bx,offset do_fill_rect
	jmp	rubber_handler


do_fill_rect:
	mov	si,fillPat		;fill the box with our pattern.
	call	make_fillPat

	mov	si,bx
	mov	di,offset temp_rect
	call	assign_rect

	push	bx
	mov	bx,offset temp_rect
	mov	di,bx
	mov	si,clip_rect
	call	sect_rect		;clip it to the draw window
	call	fill_rect		;fill it.
	pop	bx
;fall through...

do_opened_rect:
	mov	si,frame_pattern
	call	make_fillPat
	call	frame_rect		;draw the box.
	ret


open_round_button:
	mov	bx,offset do_open_round
	jmp	rubber_handler

fill_round_button:
	mov	bx,offset do_fill_round
	jmp	rubber_handler


do_fill_round:
	mov	si,fillPat		;use the current pattern.
	call	make_fillPat
	push	bx
	call	fill_round		;fill it.
	pop	bx
;fall through...

do_open_round:
	mov	si,frame_pattern
	call	make_fillPat
	call	frame_round		;frame it.
	ret


open_oval_button:
	mov	bx,offset do_open_oval
	jmp	rubber_handler

fill_oval_button:
	mov	bx,offset do_fill_oval
	jmp	rubber_handler


do_fill_oval:
	mov	si,fillPat		;use the current pattern.
	call	make_fillPat
	push	bx
	call	fill_circle		;fill it.
	pop	bx
;fall through...

do_open_oval:
	mov	si,frame_pattern
	call	make_fillPat
	call	frame_circle		;frame it.
	ret

  if 0
open_region_handler:
	call	map_fatbits
	store2	first_pt
	store2	second_pt
	call	make_fillPat_white
	mov	pen.pnMode,offset pset_verb
	call	update_page
	mov	bx,line_width
	shl	bx,1			;make it a word pointer.
	mov	si,pen_list[bx]
	call	makepen
open_region_handler_1:
	call	map_fatbits
	mov	bx,offset first_pt
	call	equal_pt
	jnc	open_region_handler_3
	xchg2	first_pt
	call	line_to_first_point
	call	do_fatbits
open_region_handler_3:
	call	map_fatbits
	test	bl,down_button
	jne	open_region_handler_1
open_region_handler_2:
	load2	second_pt
	call	line_to_first_point
	call	do_fatbits
	ret

fill_region_handler:
	call	start_collecting
	call	open_region_handler
	call	stop_collecting
	mov	si,fillPat		;use the current pattern.
	call	make_fillPat
	call	fill_rgn		;fill it.
	call	do_fatbits
	ret
  endif

open_poly_handler:
	call	wait_for_down
	call	map_fatbits
	store2	cursor_pt
	mov	poly_close,0

	mov	rubber_exit,offset rubber_while_down
	mov	bx,offset do_line_button
	call	rubber_handler

open_poly_1:
	load2	second_pt
	store2	first_pt
	mov	rubber_exit,offset rubber_while_up
	call	rubber_00

	mov	rubber_exit,offset rubber_while_down
	load2	second_pt
	call	rubber_entry_point

	cmp	poly_close,1
	je	open_poly_close

	load2	cursor_pt		;get starting point
	load22	second_pt		;get last point.
	call	near_pt			;within 5?
	jc	open_poly_1		;no - keep going.

open_poly_close:
	load2	second_pt
	load22	cursor_pt
	call	line_to
	call	do_fatbits
	mov	rubber_exit,offset rubber_while_down
	call	wait_for_up
	ret


rubber_$cursor_grid:
	call	grid_on
rubber_$cursor_nogrid:
	mov	si,line_width
	shl	si,1
	mov	si,cross_cursors[si]
	ret


rubber_handler:
;enter with bx->routine which, given bx->rect, draws something within the rect,
;rubber_exit->routine to check mouse buttons (only useful for polygons)
;  and modifies the rect so that it covers what was drawn.
	mov	changes_flag,1		;say that there have been changes.
	mov	rubber_do,bx
	call	map_fatbits
	store2	first_pt
	store2	second_pt
rubber_00:
	call	flip_ram
	call	update_page
	mov	pen.pnMode,offset pset_verb
	mov	put_byte_subr,offset pset_verb

	mov	si,offset white_pat	;do everything in white and pset.
	test	down_button,2		;is the right button down?
	je	frame_in_white
	mov	si,fillPat		;frame in the fill pattern.
frame_in_white:
	mov	frame_pattern,si
	call	make_fillPat

	mov	bx,line_width
	shl	bx,1
	mov	si,pen_list[bx]
	call	makepen			;use the current pensize.

	mov	bx,offset old_line_rect	;make the old line rect empty.
	call	set_empty_rect
rubber_handler_1:
	call	flip_cpu		;draw the new one.
	call	flip_ok			;should we erase first?
	jnc	rubber_handler_4	;no.
	mov	bx,offset old_line_rect	;yes.
	call	restore_page		;erase the old rectangle.
rubber_handler_4:
	load2	second_pt
	load22	first_pt
	mov	bx,offset new_line_rect	;remember what the box touches,
	call	set_rect		;  so that we can remove it.
	load2	pen.pnSize
	add	[bx].right,cx
	add	[bx].bot,cx
	mov	di,bx
	mov	si,clip_rect
	call	sect_rect		;clip to the window.
	call	protect_mouse
	call	rubber_do		;do whatever in the rect.
	call	unprotect_mouse
	call	do_fatbits
	call	flip_ok			;should we flip?
	jc	rubber_handler_3	;no.
	call	flip_crt		;now show the new and erase the old.
	call	flip_cpu
	mov	bx,offset old_line_rect
	call	restore_page		;erase the old rectangle.
	call	flip_cpu
rubber_handler_3:
	mov	si,offset new_line_rect
	mov	di,offset old_line_rect
	call	assign_rect
rubber_handler_2:
	call	map_fatbits
	call	rubber_exit
	jc	rubber_handler_end
rubber_entry_point:			;entry point for polygons.
	mov	bx,offset second_pt
	call	equal_pt		;has endpoint changed?
	jnc	rubber_handler_2	;no.
	store2	second_pt
	jmp	rubber_handler_1
rubber_handler_end:
	pushf
	call	do_fatbits
	popf
	ret


rubber_while_down:
	test	bl,down_button		;is the button down?
	jnz	rubber_while_down_1	;yes - continue.
	stc				;no - done.
	ret
rubber_while_down_1:
	clc
	ret


rubber_while_up:
	test	bl,down_button		;is the button down?
	je	rubber_while_up_1	;no - continue.

	cmp	time_now,50		;yes - soon enough for double click?
	ja	rubber_while_up_2	;no - go on.

	load22	last_click		;remember last click.
	call	near_pt			;near enough for double click?
	jc	rubber_while_up_2	;no - go on.

	mov	poly_close,1		;yes - all done.
	stc
	ret

rubber_while_up_2:
	mov	time_now,0		;set double click timer.
	store2	last_click		;save where clicked.
	stc				;say the button is down.
	ret

rubber_while_up_1:
	clc				;say the button is still up.
	ret


just_return:
;this "routine" is called whenever a hook is called that does nothing.
	ret

adjust_by_pnSize:
;adjust cx,dx downward to the middle of the pen.
	mov	ax,pen.pnSize.h
	sar	ax,1
	sub	cx,ax
	mov	ax,pen.pnSize.v
	sar	ax,1
	sub	dx,ax
	ret


	public	get_key
get_key:
	mov	dl,0ffh			;check for a key.
	mov	ah,6
	int	21h
	ret


	public	wait_for_up
wait_for_up:
	call	get_mouse
	test	bl,3
	jne	wait_for_up
	ret


	public	wait_for_down
wait_for_down:
	call	get_mouse
	test	bl,3
	je	wait_for_down
	ret


	public	wait_for_full_click
wait_for_full_click:
;enter with bx->rect to click in.  Exit with cy if key, nc if mouse.
	push	bx
	call	pointing_shape
wait_for_full_click_2:
	call	get_key			;did they press a key?
	jne	wait_for_full_click_3	;yes - we'll accept any key.
	call	get_mouse		;did they press either button?
	test	bl,3
	je	wait_for_full_click_2	;no - keep checking.
	pop	bx
	call	pt_in_rect		;click in the rect?
	jc	wait_for_full_click_1	;no.
	ret				;yes.
wait_for_full_click_3:
	pop	bx
	stc
	ret
wait_for_full_click_1:
	push	bx
	call	ring_bell
	call	wait_for_up		;wait for them to release it.
	pop	bx
	jmp	wait_for_full_click


our_sp	dw	?
our_ss	dw	?

parameters	dw	0
		dw	80h, ?
		dw	5ch, ?
		dw	6ch, ?

	extrn	init_17: near
	extrn	uninit_17: near


	public	shell_to_dos
shell_to_dos:
	call	init_17

	mov	our_sp,sp		;remember our stack.
	mov	our_ss,ss

	mov	dx,offset comspec	;ds:dx -> filename to execute.
	mov	bx,offset parameters	;es:bx -> parameters.
	mov	ax,cs
	mov	es,ax
	assume	es:code
	mov	word ptr es:[80h],0h + 0dh*100h
	mov	es:[bx]+4,ax		;use original phd parameters.
	mov	es:[bx]+8,ax
	mov	es:[bx]+12,ax
	mov	ax,4b00h
	int	21h
	jc	shell_to_dos_1
	xor	ax,ax			;make sure ax is zero if no errors.
shell_to_dos_1:

	cli				;get our stack back.
	mov	ss,cs:our_ss
	mov	sp,cs:our_sp
	sti
	mov	ds,cs:our_ss		;also get ds back.
	cld				;clear direction flag, just in case.

	call	uninit_17

	ret


code	ends

	end
