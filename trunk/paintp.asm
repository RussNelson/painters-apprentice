;paintp.asm - Pulldown Menu Handler
;History:237,1
;02-07-88 14:41:58 put a small vertical line between menu entries.
;02-07-88 13:25:21 move the filename into the pull down bar
;02-06-88 23:43:28 split the drawing code out of append_menu into paint_menu

data	segment	public

	include	paint.def

pull_struc	struc
pull_x		dw	?		;ending x position
pull_name	dw	?		;->name of menu.
pull_strings	dw	?		;->menu strings.
pull_size	db	(size point) dup(?)	;height and width of menu rectangle.
pull_struc	ends

h_top_margin		equ	4
h_bot_margin		equ	4
w_left_margin		equ	10
w_right_margin		equ	10
w_pull_down_space	equ	16

pull_recs	db	14*(size pull_struc) dup(?)	;at most 14 pull down menus.
this_pull_rec	dw	-1
last_pull_rec	dw	0

compute_keybd	db	?

bar_flag	db	0
pull_box	rect	<>
bar_box		rect	<>
line_box	rect	<>
this_pull_line	dw	-1
last_pull_line	dw	-1
disabled	db	20 dup(?)	;disabled flags from menus.

pull_down_bar	rect	<>

	extrn	wind_pull: byte		;paint
	extrn	clip_rect: word		;paint
	extrn	screen: byte		;paint
	extrn	down_button: byte	;paint
	extrn	pen: byte		;paintdat
	extrn	white_pat: byte		;paintdat
	extrn	black_pat: byte		;paintdat
	extrn	dot_pen: byte		;paintdat
	extrn	font: byte		;paintf
	extrn	current_filename: byte	;paintd

data	ends

code	segment	public
	assume	cs:code, ds:data

	extrn	string_width: near	;paintf
	extrn	draw_char: near		;paintf
	extrn	draw_string: near	;paintf
	extrn	use_system_font: near	;paintf
	extrn	read_style: near	;paintf
	extrn	store_style: near	;paintf
	extrn	makepen: near		;paintg
	extrn	makepen_dot: near	;paintg
	extrn	do_line: near		;painti
	extrn	invert_rect: near	;painti
	extrn	restore_rect: near	;painti
	extrn	store_rect: near	;painti
	extrn	clear_rect: near	;painti
	extrn	halftone_rect: near	;painti
	extrn	pset_verb: near		;painti
	extrn	make_fillPat: near	;painti
	extrn	make_fillPat_white: near;painti
	extrn	protect_mouse: near	;paintmse
	extrn	unprotect_mouse: near	;paintmse
	extrn	get_mouse: near		;paintmse
	extrn	frame_rect: near	;paintr
	extrn	pt_in_rect: near	;paintr

  if 0
	public	load_check
load_check:
;enter with dx=menu, entry number
;  exit with al=check mark.
	call	get_menu_ptr
	jc	load_check_1
	mov	al,[si].pulls_check
load_check_1:
	ret
  endif

	public	store_check
store_check:
;enter with dx=menu, entry number, al=check mark to store.
	call	get_menu_ptr
	jc	store_check_1
	mov	[si].pulls_check,al
store_check_1:
	ret


	public	store_disabled
store_disabled:
;enter with dx=menu, entry number, al=enabled flag to store.
	call	get_menu_ptr
	jc	store_disabled_1
	mov	[si].pulls_disabled,al
store_disabled_1:
	ret


	public	store_menu_style
store_menu_style:
;enter with dx=menu, entry number, al=menu style to store.
	call	get_menu_ptr
	jc	store_menu_style_1
	mov	[si].pulls_style,al
store_menu_style_1:
	ret


	public store_name
store_name:
;enter with dx=menu, entry number, si->name to store (null terminated.)

	push	si
	call	get_menu_ptr
	lea	di,[si]+(size pulls_struc)
	pop	si
	jc	store_name_end

	push	cx			;don't change cx.

	mov	cx,si			;save start
	call	strend			;goto one past end.
	xchg	cx,si			;save it and get start back
	sub	cx,si			;figure out size of name.
	dec	cx			;for one past.

	push	ds
	pop	es
	rep	movsb			;store name.

	pop	cx
store_name_end:
	ret


get_menu_ptr:
;enter with dx=menu, entry number.
;exit with nc, si->pulls_struc, di->pull_struc
;          cy if menu doesn't exist.
	push	ax
	push	cx
	push	dx
	mov	di,offset pull_recs
	mov	cx,dx			;remember their menu number.
	mov	dh,0			;start at menu 0.
get_menu_ptr_1:
	cmp	di,last_pull_rec	;is this the end?
	jae	get_menu_ptr_5		;yes - give error (return with cy set).
	mov	si,[di].pull_strings
	mov	dl,0
get_menu_ptr_2:
	cmp	dx,cx			;is this the one they want?
	clc				;return nc.
	je	get_menu_ptr_3		;yes - return it.
	cmp	byte ptr [si],-1	;last menu?
	je	get_menu_ptr_4		;yes - try the next one.
	inc	dl			;no - skip this menu.
	add	si,(size pulls_struc)
	call	strend			;skip next menu item name.
	jmp	get_menu_ptr_2
get_menu_ptr_4:
	add	di,(size pull_struc)	;go to next menu
	inc	dh			;count up a menu.
	jmp	get_menu_ptr_1
get_menu_ptr_5:
	stc				;say that we didn't find it.
get_menu_ptr_3:
	pop	dx
	pop	cx
	pop	ax
	ret


	public	menu_key
menu_key:
;enter with al=key to look up.
;exit with ax=-1 if no key matched, else ax=menu, entry number.
	mov	bx,offset pull_recs
	mov	dh,0			;start at menu 0.
menu_key_1:
	cmp	bx,last_pull_rec	;is this the end?
	jae	menu_key_5		;yes - return -1.
	mov	si,[bx].pull_strings
	mov	dl,0
menu_key_2:
	cmp	byte ptr [si],-1	;last menu?
	je	menu_key_4
	cmp	[si].pulls_disabled,0	;is this disabled?
	jne	menu_key_6		;yes - ignore.
	cmp	[si].pulls_keybd,al	;is this the key?
	je	menu_key_3		;yes.
menu_key_6:
	inc	dl			;no - skip this menu.
	add	si,(size pulls_struc)
	call	strend
	jmp	menu_key_2
menu_key_4:
	add	bx,(size pull_struc)	;go to next menu
	inc	dh			;count up a menu.
	jmp	menu_key_1
menu_key_3:
	push	dx
	mov	di,bx			;bx->pull_struc entry.
	call	highlight_menu
	pop	ax			;pushed as dx.
	ret
menu_key_5:
	mov	ax,-1
	ret


	public	do_pull_down
do_pull_down:
	call	read_style
	push	ax
	call	use_system_font
	mov	bx,offset wind_pull
	push	[bx].bot
	mov	[bx].bot,16
	push	cx
	push	dx
	call	protect_mouse
	inc	[bx].bot
	call	store_rect
	dec	[bx].bot
	call	paint_menu
	call	unprotect_mouse
	pop	dx
	pop	cx
do_pull_down_0:
	call	correct_pull
	call	get_mouse
	test	bl,down_button
	jne	do_pull_down_0		;not yet.
	mov	ax,this_pull_rec	;is there a menu down?
	cmp	ax,-1
	je	do_pull_down_1		;no.
	mov	bx,offset pull_recs
	sub	ax,bx			;which one is it?
	mov	cx,(size pull_struc)
	cwd
	div	cx
do_pull_down_1:
	mov	bh,al			;save the number.
	mov	bl,byte ptr this_pull_line
	pop	wind_pull.bot		;restore the menu bar size.
	pop	ax
	push	bx
	call	store_style		;restore their style.
	call	remove_pull
	call	restore_rect
	cmp	bar_flag,0		;do we have something highlighted?
	je	do_pull_down_2		;no.
	mov	bx,offset bar_box
	mov	ax,wind_pull.bot	;adjust the bar box.
	mov	[bx].bot,ax
	call	invert_rect
do_pull_down_2:
	pop	ax
	ret


correct_pull:
;enter with cx,dx=point.  ensure that the correct pull down menu is down.
	mov	bx,offset wind_pull	;are we in the pull down bar?
	call	pt_in_rect
	jnc	correct_pull_4_j_1	;yes - we might have to change the pull.
	mov	bx,offset pull_box	;pull_box contains the entire pull down box.
	call	pt_in_rect
	jc	correct_pull_5		;not in box - remove highlight (if any)
;create the new highlight.
	mov	ax,dx			;calculate the last row.
	sub	ax,pull_box.top
	sub	ax,h_top_margin
	jb	correct_pull_5		;above the first line.
	mov	cx,font.ascent		;compute height of line.
	add	cx,font.descent
	add	cx,font.leading
	add	cx,font.leading
	cwd				;divide the y by the size of a line.
	div	cx
	cmp	ax,last_pull_line	;past the last line?
	jae	correct_pull_5
	cmp	this_pull_line,ax	;is this menu already up?
	je	correct_pull_6		;yes - don't put it up again.
	mov	bx,ax			;see if this one's disabled.
	cmp	disabled[bx],0
	jne	correct_pull_5		;yes - don't select it.
	push	ax
	push	cx
	call	correct_pull_5		;get rid of any existing highlight.
	pop	cx
	pop	ax
	mov	this_pull_line,ax	;save the pull down line.
	mul	cx
	add	ax,pull_box.top
	add	ax,h_top_margin
	mov	line_box.top,ax
	add	ax,cx
	mov	line_box.bot,ax
	mov	ax,pull_box.left	;inset the box horizontally.
	inc	ax
	mov	line_box.left,ax
	mov	ax,pull_box.right
	dec	ax
	mov	line_box.right,ax
	mov	bx,offset line_box
	call	invert_rect
	ret
correct_pull_4_j_1:
	jmp	correct_pull_4
correct_pull_5:
	cmp	this_pull_line,-1	;is a line highlighted?
	je	correct_pull_6
	mov	bx,offset line_box	;unhighlight the line.
	call	invert_rect
	mov	this_pull_line,-1
correct_pull_6:
	ret


correct_pull_4:
	push	cx
	call	correct_pull_5		;get rid of any highlight.
	pop	cx

	mov	di,last_pull_rec
correct_pull_3:
	sub	di,(size pull_struc)	;try next pull.
	cmp	di,offset pull_recs	;is this the last one?
	jbe	correct_pull_7		;yes - quit.
	cmp	cx,[di].pull_x		;this menu item?
	jb	correct_pull_3		;no - keep going.

correct_pull_7:
	cmp	di,this_pull_rec	;is this one already up?
	je	correct_pull_1		;yes - don't put it up again.
	push	di			;remove the old one.
	call	remove_pull
	call	unhighlight_menu
	pop	di
	mov	this_pull_rec,di	;remember the new one,
	call	put_pull		;  and put it up.
correct_pull_1:
	ret


remove_pull:
;remove the current pull down menu item.
	call	correct_pull_5		;get rid of bar.
	cmp	this_pull_rec,-1	;is there one up?
	je	remove_pull_1		;no - don't remove it.
	call	restore_rect
	mov	this_pull_rec,-1	;nothing pulled down.
remove_pull_1:
	ret


	public	unhighlight_menu
unhighlight_menu:
	cmp	bar_flag,0
	je	unhighlight_menu_1
	mov	bar_flag,0
	mov	bx,offset bar_box
	call	invert_rect
unhighlight_menu_1:
	ret


highlight_menu:
;enter with di->pull_struc entry.
	mov	cx,[di].pull_x		;get the x position
	mov	bar_box.left,cx
	mov	ax,[di+(size pull_struc)].pull_x	;get next x position.
	mov	bar_box.right,ax
	mov	bar_box.top,0
	mov	dx,wind_pull.bot
	mov	bar_box.bot,dx

	push	di
	mov	bx,offset bar_box	;highlight the menu title.
	call	invert_rect
	mov	bar_flag,1		;remember that it's highlighted.
	pop	di

	ret


put_pull:
;enter with di->pull_struc entry.
	call	highlight_menu

	mov	cx,[di].pull_x		;get the x position
	mov	dx,wind_pull.bot
	store2	pull_box.topleft

	add2	[di].pull_size		;compute bounding box.
	store2	pull_box.botright

	push	clip_rect
	mov	clip_rect,offset screen

	push	di

	mov	bx,offset pull_box	;save what's under the menu.
	inc	[bx].right
	inc	[bx].bot
	call	protect_mouse
	call	store_rect

	call	clear_rect

	call	makepen_dot
	call	make_fillPat_white
	mov	pen.pnMode,offset pset_verb
	call	frame_rect		;frame the rectangle in white.
	dec	[bx].right
	dec	[bx].bot
	call	frame_rect

	pop	di			;-> our pull_struc

	mov	si,[di].pull_strings	;point to the the strings.

	load2	pull_box.topleft
	add	cx,w_left_margin	;go to left margin.
	add	dx,font.ascent		;go to first base line.
	add	dx,h_top_margin		;go to top margin.
	add	dx,font.leading		;center the line in the space.
	mov	last_pull_line,0
put_pull_3:
	cmp	byte ptr [si],-1	;last string?
	je	put_pull_4

	call	put_one_pull

	xor	al,al			;go down a normal line.
	call	store_style

	add	dx,font.descent		;compute height of line.
	add	dx,font.leading
	add	dx,font.leading
	add	dx,font.ascent
	inc	last_pull_line
	jmp	put_pull_3

put_pull_4:
	call	unprotect_mouse
	pop	clip_rect
	ret


put_one_pull:
	mov	al,[si].pulls_check	;get the check mark
	or	al,al
	je	put_one_pull_1		;but only if it's not null.
	mov	al,0			;always plain style.
	call	store_style
	mov	al,[si].pulls_check	;put the check mark
	push	cx
	push	si
	call	draw_char
	pop	si
	pop	cx
put_one_pull_1:
	mov	al,[si].pulls_keybd	;is there a keyboard equivalent?
	or	al,al
	je	put_one_pull_2		;no.
	push	cx
	push	si
	push	ax
	mov	al,0			;output in plain style.
	call	store_style
	mov	cx,pull_box.right
	sub	cx,w_right_margin	;move past the right margin.
	sub	cx,font.widMax		;compute where the keyboard equivalent goes.
	sub	cx,2
	sub	cx,font.widMax
	mov	al,81h
	call	draw_char		;draw the command character.
	pop	ax
	add	cx,2
	call	draw_char		;draw the character.
	pop	si
	pop	cx
put_one_pull_2:
	mov	al,[si].pulls_style	;set the style.
	call	store_style
	mov	al,[si].pulls_disabled	;is this one disabled?
	mov	bx,last_pull_line	;remember if it's disabled.
	mov	disabled[bx],al
	add	si,(size pulls_struc)
	push	ax
	push	cx
	add	cx,font.widMax		;always leave room for check mark.
	add	cx,2			;leave some extra room.
	call	draw_string
	pop	cx
	pop	ax
	or	al,al			;disabled?
	je	put_one_pull_3		;no.

	mov	line_box.left,cx	;compute the bounding box for the item.
	mov	ax,dx
	sub	ax,font.ascent
	mov	line_box.top,ax
	mov	ax,pull_box.right
	dec	ax			;don't halftone the border.
	mov	line_box.right,ax
	mov	ax,dx
	add	ax,font.descent
	mov	line_box.bot,ax

	push	cx			;and with a halftone.
	push	dx
	push	si
	mov	bx,offset line_box
	call	halftone_rect
	pop	si
	pop	dx
	pop	cx

put_one_pull_3:
	ret


	public	new_menu
new_menu:
;enter with si->pull down menu, al=menu number (0...) to replace.
;note that you can't change the title of a menu using this routine.
;exits with menu installed.
	push	si
	call	use_system_font		;use the system font for compute_menu.
	mov	dh,al
	mov	dl,0
	call	get_menu_ptr
	pop	si
	call	strend			;skip the name.
	call	compute_menu
	ret


	public	kill_menus
kill_menus:
	mov	last_pull_rec,0		;there are no menus.
	ret


	public	append_menu
append_menu:
;enter with si->pull down menu.
;exit with si->first byte after pull down menu.
	push	clip_rect
	mov	clip_rect,offset screen

	push	si
	call	use_system_font
	call	makepen_dot
	call	make_fillPat_white
	pop	si

	mov	di,last_pull_rec	;is this the first?
	or	di,di
	jne	append_menu_0		;no - get the menu bar x.
	mov	cx,w_pull_down_space/2	;yes - start at the left
	mov	di,offset pull_recs
	mov	[di].pull_x,cx		;save the first x position.
	jmp	short append_menu_1
append_menu_0:
	mov	cx,[di].pull_x		;get the next x position.
append_menu_1:

	xor	al,al			;set all the style variations off.
	call	store_style

	mov	[di].pull_name,si	;remember what the menu name is.


	add	cx,w_pull_down_space/2
	push	cx
	call	string_width
	add	cx,dx
	pop	dx

	push	si
	push	di
	push	cx

	mov	si,dx
	mov	dx,wind_pull.bot
	dec	dx
	mov	di,dx
	call	do_line
	pop	cx

	pop	di
	pop	si

	add	cx,w_pull_down_space/2
	mov	[di+(size pull_struc)].pull_x,cx	;save the last x position.

	call	compute_menu

	add	di,(size pull_struc)
	mov	last_pull_rec,di

	pop	clip_rect

	ret


	public	paint_menu
paint_menu:
;exit with the menu bar painted.
;bombs if there are no menus.
	push	clip_rect
	mov	clip_rect,offset screen

	call	use_system_font

	mov	bx,offset wind_pull
	call	clear_rect

	mov	di,offset pull_recs
paint_menu_1:
	mov	cx,[di].pull_x		;get the next x position.
	add	cx,w_pull_down_space/2	;center it in the given space.

	mov	dx,wind_pull.bot	;compute the height of the bar.
	sub	dx,wind_pull.top
	sub	dx,font.ascent		;compute the whitespace above and below.
	sub	dx,font.descent
	shr	dx,1			;compute half (the whitespace below)
	neg	dx
	add	dx,wind_pull.bot
	sub	dx,font.descent		;baseline=bot-whitespace below-descent.

	xor	al,al			;set all the style variations off.
	call	store_style

	mov	si,[di].pull_name	;get the menu name.
	push	di
	call	draw_string
	pop	di

	add	di,(size pull_struc)
	cmp	di,last_pull_rec	;any items left?
	jne	paint_menu_1		;yes - continue.

	mov	cx,[di].pull_x
	add	cx,w_pull_down_space/2	;center it in the given space.
	mov	al,'"'
	call	draw_char
	mov	si,offset current_filename
	call	draw_string
	mov	al,'"'
	call	draw_char

	call	makepen_dot
	call	make_fillPat_white
	mov	cx,wind_pull.left
	mov	dx,wind_pull.bot
	mov	si,wind_pull.right
	mov	di,wind_pull.bot
	call	do_line

	pop	clip_rect

	ret


compute_menu:
;enter with si->first pulls_struc, di->pull_struc.
;exit with pull_struc entries set correctly.

	call	read_style		;preserve the style.
	push	ax
	xor	al,al			;set all the style variations off.
	call	store_style

	mov	[di].pull_strings,si	;save the strings.

	mov	bp,0			;max width.
	mov	cx,h_top_margin		;height of rectangle.
	mov	compute_keybd,0		;no keyboard equivalents yet.
compute_menu_2:
	cmp	byte ptr [si],-1	;last string?
	je	compute_menu_3
	mov	al,[si].pulls_style	;do this for style size considerations.
	call	store_style
	mov	al,[si].pulls_keybd
	or	compute_keybd,al	;remember any keyboard equivalents.
	add	si,(size pulls_struc)	;skip to the string.
	call	string_width		;skip past the string.
	add	cx,font.ascent		;compute height of line.
	add	cx,font.descent
	add	cx,font.leading
	add	cx,font.leading
	cmp	dx,bp			;is this one longer?
	jb	compute_menu_2
	mov	bp,dx
	jmp	compute_menu_2
compute_menu_3:
	add	cx,h_bot_margin		;add the bottom margin,
	mov	[di].pull_size.v,cx	;  and remember the height.

	mov	cx,w_left_margin
	add	cx,font.widMax		;allow room for a check mark
	add	cx,2			;leave some extra room.
	add	cx,bp			;maximum line length.
	cmp	compute_keybd,0		;are there any keyboard equivalents?
	je	compute_menu_4		;no - don't leave room for any.
	add	cx,2			;allow room for a keyboard equivalent.
	add	cx,font.widMax		;. .
	add	cx,2			;. .
	add	cx,font.widMax		;. .
compute_menu_4:
	add	cx,w_right_margin
	mov	[di].pull_size.h,cx

	inc	si			;skip to beginning of next menu.

	pop	ax
	call	store_style

	ret


	public	strend
strend:
;enter with si->null terminated string.
;exit with si->after null.
	push	ax
strend_1:
	lodsb
	or	al,al
	jne	strend_1
	pop	ax
	ret


code	ends

	end
