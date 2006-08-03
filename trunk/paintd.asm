;paintd.asm - Dialog Manager
;History:394,1
;08-18-88 18:34:07 make our own copy of add_char and kill_char.
;08-07-88 09:04:34 in dir_select, use and return a file number.
;06-15-88 22:48:15 clean up select_string.
;06-15-88 22:40:11 get rid of not_bug ifdef.
;06-15-88 22:39:04 get rid of dialog_yn ifdef.
;06-15-88 22:38:24 get rid of list_no_blink ifdef.
;06-15-88 22:35:31 get rid of repeated_press ifdef.
;queue=1 if we're using an event queue.
queue	equ	0

data	segment	public

	include	paintflg.asm

	include	paint.def

edge		equ	5
w_screen	equ	640
h_screen	equ	240
middle_x	equ	w_screen/2
middle_y	equ	h_screen/2
icon_w		equ	24
icon_h		equ	16
w_dialog	equ	edge+9*30+edge
h_dialog	equ	edge+3*18+edge
dialog_x	equ	middle_x-w_dialog/2
dialog_y	equ	middle_y-h_dialog/2
dialog_rect	rect	<dialog_x, dialog_y, dialog_x+w_dialog, dialog_y+h_dialog>

w_files		equ	edge+9*30+edge
h_files		equ	2*edge+7*13+2*edge
files_x		equ	middle_x-w_files/2
files_y		equ	middle_y-h_files/2
files_rect	rect	<files_x, files_y, files_x+w_files, files_y+h_files>
files_list_rect	rect	<files_x+2*edge-1, files_y+2*edge-1, middle_x+2, files_y+h_files-(2*edge)+1>
first_file_rect	rect	<files_x+2*edge, files_y+2*edge, middle_x, files_y+2*edge+13>
files_button	rect	<middle_x+2*edge+16, middle_y-9, files_x+w_files-(2*edge), middle_y+9>
first_file_ptr	dw	?
this_file	dw	?
last_file	dw	?
old_file	dw	?

alert_icon_rect	rect	<dialog_x+2*edge, dialog_y+2*edge, dialog_x+2*edge+icon_w, dialog_y+2*edge+icon_h>

prompt_pt	point	<dialog_x+2*edge+icon_w-1+edge, dialog_y+2*edge+12>

left_rect	rect	<dialog_x+2*edge, dialog_y+h_dialog-2*edge-18, middle_x-edge,            dialog_y+h_dialog-2*edge>
right_rect	rect	<middle_x+2*edge, dialog_y+h_dialog-2*edge-18, dialog_x+w_dialog-2*edge, dialog_y+h_dialog-2*edge>

ok_string	db	'OK',0
cancel_string	db	'Cancel',0
no_files_msg	db	'No image files found',0

null_list	db	0,0,0,0		;null attribute byte, null string, dummy attribute byte, end of list.

string_pt	point	<>
event_point	point	<>
temp_rect	rect	<>
old_style	dw	?
old_clip_rect	dw	?

dialog_max	equ	64
dialog_buf	db	dialog_max+1 dup(0)	;leave room for a null
	public	current_filename
current_filename	db	80 dup(0)

dialog_len	dw	0		;length of dialog_buf.
dialog_buf_rect	rect	<>

check_buttons	dw	?

	extrn	screen: word		;paint
	extrn	clip_rect: word		;paint
	extrn	free_space: word	;paint
	extrn	alert_stop: word	;paintdat
	extrn	alert_note: word	;paintdat
	extrn	alert_caution: word	;paintdat
	extrn	cursor_pt: word		;painth
	extrn	last_time: word		;painth
	extrn	buttons: word		;paintmse
	extrn	h_pixel: word		;paintmse
	extrn	v_pixel: word		;paintmse
	extrn	put_byte_subr: word	;painti

  if queue
queue_head	dw	event_queue
queue_tail	dw	event_queue

event_queue	db	queue_size*(size event_struc) dup(?)
event_queue_end
  endif

	extrn	font: byte

data	ends

code	segment	public
	assume	cs:code, ds:data

	extrn	time_now: word		;paintg
	extrn	pointing_shape: near	;paint
	extrn	wait_for_up: near	;paint
	extrn	ring_bell: near		;paint
	extrn	use_system_font: near	;paintf
	extrn	read_style: near	;paintf
	extrn	store_style: near	;paintf
	extrn	draw_char: near		;paintf
	extrn	draw_string: near	;paintf
	extrn	center_string: near	;paintf
	extrn	char_width: near	;paintf
	extrn	draw_char_cursor: near	;painth
	extrn	remove_char_cursor:near ;painth
	extrn	store_rect: near	;paintr
	extrn	restore_rect: near	;painti
	extrn	clear_rect: near	;painti
	extrn	put_rect: near		;painti
	extrn	get_mouse: near		;paintmse
	extrn	protect_mouse: near	;paintmse
	extrn	unprotect_mouse: near	;paintmse
	extrn	frame_round: near	;paintc
	extrn	frame_rect: near	;painti
	extrn	nice_frame_rect: near	;paintr
	extrn	pt_in_rect: near	;paintr
	extrn	pt_in_numbered: near	;paintr
	extrn	inset_rect: near	;paintr
	extrn	make_numbered_rect: near	;paintr
	extrn	preset_verb: near	;painti
	extrn	strend: near		;paint
	extrn	offset_rect: near	;paintr
	extrn	make_char_box: near	;paintf
	extrn	string_width: near	;paintf
	extrn	paint_bar: near		;paintscr
	extrn	setup_bar: near		;paintscr
	extrn	identify_bar: near	;paintscr
	extrn	measure_bar: near	;paintscr


  if queue
	public	register_event
register_event:
;enter with al=event_mods, ah=event_type
;don't change any registers.
	push	ax
	push	bx
	mov	bx,queue_tail		;any room left in the queue?
	call	succ_queue
	cmp	bx,queue_head
	je	register_event_1	;no.
	mov	bx,queue_tail
	mov	[bx].event_type,ah
	mov	[bx].event_mods,al
	mov	ax,buttons
	mov	[bx].event_buttons,al
	mov	ax,h_pixel
	mov	[bx].event_pt.h,ax
	mov	ax,v_pixel
	mov	[bx].event_pt.v,ax
	mov	ax,time_now
	mov	[bx].event_time,ax
	call	succ_queue
	mov	queue_tail,bx
register_event_1:
	pop	bx
	pop	ax
	ret
  endif

	public	event_manager
event_manager:
;enter with nothing
;exit with cy if no event.
;else if mouse click then ax=-1; event_point=point.
;     if keypressed then al=key.
;bx, cx, dx preserved.
	push	bx
	push	cx
	push	dx
	call	get_mouse		;just get the buttons in bx.
	test	bl,3			;either button down?
	je	event_1			;no - check for keypress.
	mov	ax,-1			;say it was the mouse.
	store2	event_point		;say where.
	clc
	jmp	short event_exit
event_1:
	mov	dl,0ffh			;read keyboard.
	mov	ah,6			;only if key is available.
	int	21h
	clc				;assume there is a character.
	jnz	event_exit		;character available in ax?
	stc				;no - error.
event_exit:
	pop	dx
	pop	cx
	pop	bx
	ret


	public	dir_select
dir_select:
;enter with ax = desired filename number, si->filename list (in free space).
;exit with ax = current filename number, si->filename, nc, or cy if aborted.
	mov	first_file_ptr,si
	inc	ax			;select_string starts from one.
	mov	this_file,ax

	mov	ax,0			;now count the strings.
	call	select_string
	neg	cx
	dec	cx
	mov	last_file,cx

	call	skip_subdirs

	mov	bx,offset files_rect
	call	pre_dialog_0

	mov	bx,offset files_list_rect
	call	frame_rect

	mov	si,offset cancel_string
	mov	bx,offset files_button
	call	center_string
	call	frame_round

	mov	ax,files_list_rect.top
	mov	temp_rect.top,ax
	mov	ax,files_list_rect.bot
	mov	temp_rect.bot,ax
	mov	ax,files_list_rect.right
	dec	ax
	mov	temp_rect.left,ax

	mov	bx,offset temp_rect
	call	setup_bar

	call	unprotect_mouse
	call	write_dir
	call	wait_for_up
dir_select_2:
	call	event_manager		;wait for something to happen.
	jc	dir_select_2		;nothing yet.
	cmp	ax,-1			;button?
	jne	dir_select_2		;no.
	load2	event_point		;yes - get the point.
	mov	bx,offset files_button
	call	pt_in_rect
	cmc
	jc	dir_select_3_j_1	;if in the cancel button, abort.
	mov	si,offset first_file_rect
	mov	bp,1			;one column
	mov	ax,7			;five names + two buttons.
	call	pt_in_numbered
	jnc	dir_select_4
	call	identify_bar
	jnc	dir_scroll_1
	call	ring_bell		;say that we don't understand.
	call	wait_for_up
	jmp	dir_select_2
dir_select_3_j_1:
	jmp	dir_select_3
dir_scroll_1:
	mov	bx,time_now		;remember
	add	bx,400/10		;add extra to the wait time.
	mov	last_time,bx
	cmp	ax,BAR_UPARROW
	je	dir_select_7
	cmp	ax,BAR_DOWNARROW
	je	dir_select_8
	cmp	ax,BAR_PGUP
	je	dir_page_up
	cmp	ax,BAR_PGDN
	je	dir_page_down
	cmp	ax,BAR_THUMB
	jne	dir_select_2
	jmp	dir_thumb

dir_select_4:
	add	ax,this_file		;get the file.
	mov	si,first_file_ptr
	call	select_string
	jc	dir_select_2
	jmp	dir_select_3


dir_select_7:
	cmp	this_file,1		;are there previous strings?
	jbe	dir_select_wait		;no.
	dec	this_file
	call	write_dir
	call	repeated
	jnc	dir_select_7
	jmp	dir_select_2

dir_select_8:
	mov	ax,this_file		;any more files?
	cmp	ax,last_file
	jae	dir_select_wait		;no - ignore.
	inc	this_file
	call	write_dir
	call	repeated
	jnc	dir_select_8
	jmp	dir_select_2

dir_page_down:
	mov	ax,this_file		;any more files?
	cmp	ax,last_file
	jae	dir_select_2_j_1	;no - ignore.
	add	ax,7			;another whole page?
	cmp	ax,last_file
	jl	dir_page_down_1
	mov	ax,last_file		;no, partial.
dir_page_down_1:
	mov	this_file,ax
	call	write_dir
dir_select_wait:
	call	wait_for_up
dir_select_2_j_1:
	jmp	dir_select_2

dir_page_up:
	mov	ax,this_file		;any more files?
	cmp	ax,1
	jle	dir_select_wait		;no - ignore.
	sub	ax,7			;another whole page?
	cmp	ax,1
	jg	dir_page_up_1
	mov	ax,1			;no, partial.
dir_page_up_1:
	mov	this_file,ax
	call	write_dir
	call	wait_for_up
	jmp	dir_select_2

dir_thumb:
	mov	ax,this_file		;remember what the old file number was.
	mov	old_file,ax
dir_thumb_0:
	call	get_mouse		;get the position again.
	test	bl,3
	je	dir_thumb_1		;go if they released it.
	mov	si,last_file
	dec	si
	call	measure_bar
	jc	dir_thumb_2
	inc	ax
	jmp	short dir_thumb_3
dir_thumb_2:
	mov	ax,old_file
dir_thumb_3:
	mov	this_file,ax
	call	write_dir
	jmp	dir_thumb_0
dir_thumb_1:
	call	wait_for_up		;wait for them to let go.
	jmp	dir_select_2

dir_select_3:
	call	post_dialog
	mov	ax,this_file		;return the file number in ax.
	dec	ax
	mov	bx,free_space
	mov	bx,[bx-2]
	mov	free_space,bx
	ret


repeated:
;return cy if the button was released, nc if not and time out occurred.
repeated_0:
	call	get_mouse		;is the button still down?
	test	bl,3
	je	repeated_1		;no - return cy.
	mov	ax,time_now		;see if it's time to repeat.
	sub	ax,last_time
	cmp	ax,100/10		;that many ms passed yet?
	jl	repeated_0
	mov	ax,time_now
	mov	last_time,ax
	clc
	ret
repeated_1:
	stc
	ret


skip_subdirs:
	push	this_file
skip_subdirs_0:
	mov	ax,this_file		;check out this string.
	mov	si,first_file_ptr
	call	select_string
	jc	skip_subdirs_1		;doesn't exist.
	test	[si].b,10h		;is this a subdir?
	je	skip_subdirs_2		;no - this is it!
	inc	this_file		;yes - look for another.
	jmp	skip_subdirs_0
skip_subdirs_2:
	pop	ax			;exit without restoring this_file.
	ret
skip_subdirs_1:
	pop	this_file
	ret


select_string:
;enter with ax number of the string in the list.
;exit with nc, si ->string if we found it, cy if there aren't that many.
	mov	cx,ax
	jmp	short select_string_1
select_string_4:
	inc	si			;skip the attribute byte.
select_string_2:
	lodsb
	or	al,al
	jne	select_string_2
select_string_1:
	cmp	[si+1].b,0		;did we hit the end?
	loopne	select_string_4
	stc
	je	select_string_3		;yes - ignore.
	clc
select_string_3:
	ret


write_dir:
	mov	ax,this_file
	dec	ax
	mov	cx,last_file
	dec	cx
	call	paint_bar

	mov	ax,this_file
	mov	si,first_file_ptr
	call	select_string

	call	read_style
	push	ax
	mov	bx,offset files_list_rect
	call	protect_mouse
	mov	ax,0
write_dir_2:
	push	si			;preserve the filename list.
	mov	si,offset first_file_rect	;frame the first button
	mov	bx,offset temp_rect
	mov	cx,1
	call	make_numbered_rect
	pop	si			;restore the filename list.

	push	ax			;preserve the rectangle number.

	lodsb				;get the attribute byte
	test	al,10h			;is this a subdir?
	mov	al,0			;if not, use no special style.
	je	write_dir_4
	mov	al,BOLD_STYLE
write_dir_4:
	call	store_style

	load2	[bx].topleft		;get the topleft of the first line.
	add	dx,font.ascent
	add	cx,edge
	call	draw_string
	sub	dx,font.ascent
	store2	temp_rect.topleft
	mov	bx,offset temp_rect

	push	si
	call	clear_rect
	pop	si

	pop	ax			;restore the rectangle number.

	cmp	[si+1].b,0		;end of the list?
	jne	write_dir_3		;no.
	mov	si,offset null_list	;keep showing the null string.
write_dir_3:
	inc	ax
	cmp	ax,7			;done all 7 lines?
	jb	write_dir_2		;not yet.
write_dir_1:
	call	unprotect_mouse
	pop	ax
	call	store_style
	ret


	public	dialog
dialog:
;enter with si->string to prompt with.
;exit with si->string entered at keyboard.
	push	cursor_pt.v
	push	cursor_pt.h
	call	pre_dialog
	load2	prompt_pt
	call	draw_string
	add	cx,4			;move input away from prompt.
	store2	string_pt		;save where string starts.
	mov	bx,offset dialog_buf_rect
	sub	dx,font.ascent		;get the top left.
	store2	[bx].topleft
	add	dx,font.ascent		;get the top left.
	add	dx,font.descent		;get the bot.
	mov	cx,dialog_rect.right	;  and the right.
	sub	cx,14
	store2	[bx].botright
	mov	cx,2			;make the rect a little bigger.
	mov	dx,2
	call	inset_rect
	call	frame_rect
	mov	cx,-2			;make the rect a little smaller.
	mov	dx,-2
	call	inset_rect

	call	caution_alert
	call	put_both
	call	unprotect_mouse
	mov	di,offset dialog_buf
	mov	[di].b,0		;null terminate it.
	push	ds
	pop	es
	mov	dialog_len,0		;zero length.
	load2	string_pt
	store2	cursor_pt
cursor_wait_0:
	call	wait_for_up
cursor_wait:
	mov	ax,time_now		;time to blink?
	sub	ax,last_time
	cmp	ax,50			;blink the cursor every 1/2 second.
	jb	cursor_wait_1
	call	draw_char_cursor	;draw cursor at cursor_pt.
cursor_wait_1:
	call	event_manager		;is anything happening?
	jc	cursor_wait		;no - keep looking.
	push	ax			;yes - save result.
	call	remove_char_cursor	;get rid of cursor if up.
	pop	ax
	cmp	ax,-1			;mouse?
	jne	get_key			;no - keypressed.
	call	pt_in_button		;yes - process where it clicked.
	jc	cursor_wait_0
	or	al,al
	jz	cr_or_ok		;ok.
	stc				;cancel
	jmp	short dialog_done
get_key:
	cmp	al,0dh			;return?
	je	cr_or_ok
	cmp	al,08h			;back space?
	je	delete_char
	cmp	al,7fh			;delete?
	je	delete_char
	ja	dialog_err
	cmp	al,' '
	jbe	dialog_err
	mov	si,offset dialog_buf
	mov	bx,dialog_len		;get length.
	cmp	bx,dialog_max		;have they typed too many chars?
	jae	dialog_err
insert_char:
	push	ds			;is this char illegal?
	pop	es
	inc	dialog_len		;increment length.
	add	bx,si			;bx->spot to add character.
	mov	[bx],al
	mov	[bx+1].b,0		;null terminate the line.
	mov	bx,offset dialog_buf_rect
	call	paint_line		;write the whole thing.
	jmp	cursor_wait
delete_char:
	cmp	dialog_len,0		;yes - beginning of buffer?
	je	dialog_err		;yes - done.
	dec	dialog_len		;make it one less.
	mov	bx,dialog_len
	mov	si,offset dialog_buf
	add	bx,si			;bx->character to delete.
	mov	byte ptr[bx],0		;null it out.
	mov	bx,offset dialog_buf_rect
	call	paint_line		;write the whole thing.
	jmp	cursor_wait

cr_or_ok:
	cmp	dialog_len,0		;zero length?
	stc				;assume yes, (cancel).
	je	dialog_done		;yes - crap out.
	clc				;no - no errors.
	mov	bx,dialog_len
	mov	si,offset dialog_buf
	mov	[bx][si].b,0		;store a null after the end of the string..
dialog_done:
	call	post_dialog
	pop	cursor_pt.h
	pop	cursor_pt.v
	ret


dialog_err:
	call	ring_bell
	jmp	cursor_wait


paint_line:
;enter with bx -> rect to fill with characters, si->null terminated buffer.
	call	protect_mouse
	push	bx
	call	remove_char_cursor	;erase the old.
	pop	bx
	push	clip_rect		;only paint inside the rect.
	mov	clip_rect,bx
	push	si
	call	string_width		;return dx = width of string.
	pop	si
	mov	cx,[bx].left
	mov	ax,[bx].right		;compute the width of the rect.
	sub	ax,cx
	cmp	dx,ax			;is the string wider than the rect?
	jb	paint_line_1
	mov	cx,[bx].right		;yes - right justify it.
	sub	cx,dx
paint_line_1:
	mov	dx,[bx].top
	add	dx,font.ascent
	push	bx
	call	draw_string		;draw the string.
	pop	bx
	store2	cursor_pt
	push	[bx].left		;clear the rest of the string
	mov	[bx].left,cx
	call	clear_rect
	pop	[bx].left
	pop	clip_rect
	call	unprotect_mouse
	push	bx
	call	draw_char_cursor	;draw the new
	pop	bx
	ret

	public	alert, error_alert
alert:
	call	pre_dialog
	load2	prompt_pt
	call	draw_string
	call	stop_alert
	call	put_both
	mov	check_buttons,offset pt_in_button
	call	unprotect_mouse
	jmp	short alert_wait


error_alert:
;enter with si->message to display.
;exit with nothing.
	call	pre_dialog
	load2	prompt_pt
	call	draw_string
	call	note_alert
	call	put_ok
	mov	check_buttons,offset pt_in_left
	call	unprotect_mouse
;fall through

alert_wait:
	call	wait_for_up
alert_wait_1:
	call	event_manager		;is anything happening?
	jc	alert_wait_1		;no - keep looking.
	cmp	ax,-1			;yes - is it the mouse?
	je	alert_wait_2		;yes - look for position.
	or	al,20h
	cmp	al,'o'			;'o'k, 'y'es are ok.
	clc
	je	alert_ok
	cmp	al,'y'
	clc
	je	alert_ok
	cmp	al,'c'			;'c'ancel, 'n'o are not ok.
	je	alert_not_ok
	cmp	al,'n'
	je	alert_not_ok
	call	ring_bell		;all other keys are ignored.
	jmp	alert_wait_1
alert_wait_2:
	call	check_buttons		;yes - process where it clicked.
	jc	alert_wait
	or	al,al
	clc
	jz	alert_ok		;ok.
alert_not_ok:
	stc
alert_ok:
	call	post_dialog
	ret


pre_dialog:
;call before a dialog, alert, or error_alert.
	mov	bx,offset dialog_rect	;protect mouse where we are working.
pre_dialog_0:
;enter with bx->dialog rectangle.
	push	si
	mov	ax,clip_rect
	mov	old_clip_rect,ax
	mov	clip_rect,offset screen
	call	protect_mouse
	mov	di,free_space
	call	store_rect		;save the screen data.
	call	nice_frame_rect		;put up the border.
	call	pointing_shape		;change mouse shape.
	call	use_system_font
	call	read_style		;get old style.
	mov	old_style,ax		;save it.
	mov	al,0			;use plain style.
	call	store_style
	pop	si
	ret


post_dialog:
	push	si			;save a string result.
	pushf				;save result of routine. (if any)
	mov	si,free_space
	call	restore_rect		;get screen data back up.
	call	wait_for_up		;wait till they let go.
	mov	bx,old_clip_rect
	mov	clip_rect,bx
	mov	ax,old_style		;get old style.
	call	store_style		;put old style back.
	popf				;restore result of routine.
	pop	si			;restore string result.
	ret


pt_in_button:
;call after polling the event manager and receiving an al=-1.
;al returns 0 if left, 1 if right.  cy if neither.
	load2	event_point
	mov	bx,offset dialog_rect	;are we in the dialog rect?
	call	pt_in_rect
	jnc	pt_in_button_left	;yes - keep looking.
	call	ring_bell
	jmp	short pt_in_button_none
pt_in_button_left:
	mov	bx,offset left_rect	;are we inside the left rect?
	call	pt_in_rect
	jc	pt_in_button_right	;no.
	clc
	mov	al,0
	ret
pt_in_button_right:
	mov	bx,offset right_rect	;are we inside the right rect?
	call	pt_in_rect
	jc	pt_in_button_none	;no.
	clc
	mov	al,1
	ret
pt_in_button_none:
	stc
	ret

pt_in_left:
	load2	event_point
	mov	bx,offset dialog_rect	;are we in the dialog rect?
	call	pt_in_rect
	jnc	pt_in_left_1		;yes - keep looking.
	call	ring_bell
	jmp	pt_in_button_none
pt_in_left_1:
	mov	bx,offset left_rect	;are we inside the left rect?
	call	pt_in_rect
	jc	pt_in_button_none	;no.
	clc
	mov	al,0
	ret


put_both:
	mov	si,offset cancel_string
	mov	bx,offset right_rect
	call	center_string
	call	frame_round
put_ok:
	mov	si,offset ok_string
	mov	bx,offset left_rect
	call	center_string
	call	frame_round
	ret


stop_alert:
	mov	si,offset alert_stop
	mov	bx,offset alert_icon_rect
	push	put_byte_subr
	mov	put_byte_subr,offset preset_verb
	call	put_rect
	pop	put_byte_subr
	ret


note_alert:
	mov	si,offset alert_note
	mov	bx,offset alert_icon_rect
	push	put_byte_subr
	mov	put_byte_subr,offset preset_verb
	call	put_rect
	pop	put_byte_subr
	ret


caution_alert:
	mov	si,offset alert_caution
	mov	bx,offset alert_icon_rect
	push	put_byte_subr
	mov	put_byte_subr,offset preset_verb
	call	put_rect
	pop	put_byte_subr
	ret


	public	itod
itod:
;enter with ax=number, es:di->place to put number.
	mov	bx,10			;divide the number by ten.
	xor	dx,dx
	div	bx
	push	dx
	or	ax,ax			;is the quotient zero?
	je	itod_1			;yes - don't recurse further.
	call	itod
itod_1:
	pop	ax			;get this digit back.
	add	al,'0'
	stosb
	ret

code	ends
	end
