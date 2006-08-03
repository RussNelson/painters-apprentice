;paintf.asm - Font Handler
;History:245,1
;06-16-88 20:51:34 use screen_seg in screen_bitmap
;06-16-88 20:49:31 define screen_segm
;01-02-88 16:38:24 replace 0e0000000h by screen_seg*10000h

data	segment	public

	include	paintflg.asm

	include	paint.def

	public	font_size_list, font_size_length
font_size_list	label	word
	dw	0			;set when a file is loaded.
	dw	09
	dw	10
	dw	12
	dw	14
	dw	18
	dw	24
	dw	36
	dw	48
	dw	72
font_size_length	equ	$-font_size_list

single_char	db	?,0		;null terminated string.

current_font	dw	-1		;anything invalid is ok.
	public	disk_font
disk_font	dw	0

desired_ascent	dw	?

font_number	db	0		;0 means the system font.
font_size	db	2		;the size in which a font is drawn.
font_style	db	0		;the style in which a font is drawn.

char_height	dw	0		;height of the plain font.

style_width	dw	0
styled_height	dw	0

char_separation	dw	0


string_pt	point	<>

	public	actual_char_rect
actual_char_rect	rect	<>

char_bitmap	bitmap	<>

line_bitmap	rect	<>
		bitmap_trailer	<80>

line_width	dw	?

line1_bitmap	bitmap	<>

screen_bitmap	rect	<>
		bitmap_trailer	<screen_bytes, 0, 0>


	public	font
font		font_struc	<>	;this one is adjusted for style.

sized_font	font_struc	<>	;this one is adjusted for size.

this_font	font_struc	<>	;must be followed by indices.
indices		dw	256 dup(?)	;->character entries.
missing_char	dw	?		;-> missing char entry.

	extrn	free_space: word		;paint
	extrn	clip_rect: word			;paint
	extrn	system_font: word		;paintf1
	extrn	put_byte_subr: word		;painti
	extrn	bit_count: word			;painti
	extrn	line_count: word		;painti

	extrn	screen_seg: word

data	ends

code	segment	public
	assume	cs:code, ds:data

	extrn	point_to_pointer: near		;painti
	extrn	put_scan_line: near		;painti
	extrn	and_verb: near			;painti
	extrn	and_not_verb: near		;painti
	extrn	or_verb: near			;painti
	extrn	or_not_verb: near		;painti
	extrn	pset_verb: near			;painti
	extrn	preset_verb: near		;painti
	extrn	blit: near			;painti
	extrn	assign_rect: near		;paintr
	extrn	sect_rect: near			;paintr
	extrn	offset_rect: near		;paintr
	extrn	set_empty_rect: near		;paintr
	extrn	union_rect: near		;paintr
	extrn	strend: near			;paintp
	extrn	load_proper_font: near		;paintdio


	public	read_size
read_size:
	mov	al,font_size
	ret


	public	store_size
store_size:
	mov	font_size,al
	call	desire_size
	jmp	short set_font


	public	read_font_number
read_font_number:
	mov	al,font_number
	ret


	public	load_font, set_font
load_font:
;enter with al=number in menu to load.
;exit with disk_font->font.
	mov	font_number,al
set_font:
	mov	dh,font_number
	mov	dl,font_size
	call	load_proper_font
	ret


desire_size:
	mov	bl,font_size
	xor	bh,bh
	shl	bx,1
	mov	bx,font_size_list[bx]
	mov	desired_ascent,bx
	ret


	public	use_system_font, use_font
use_system_font:
	mov	si,offset system_font
use_font:
;enter with si->font file.
;exit with the font set up to use.
;don't destroy cx,dx.
	or	si,si			;is it somehow zero?
	je	use_system_font		;yes - use the system font.
	cmp	si,current_font		;are we already using it?
	jne	use_font_2		;no - set it up.
	call	compute_font		;adjust for style, size.
	ret				;yes - we're done.
use_font_2:
	mov	current_font,si		;remember that this is the font.
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	call	strend			;ignore the font name (for now.)
	push	ds
	pop	es
	mov	di,offset this_font
	movsw				;move ascent
	movsw				;move descent
	movsw				;move widMax
	movsw				;move leading
	mov	cx,256			;fill the font with the missing symbol.
	mov	ax,si			;make ax->first entry
	add	ax,2			; (skip the count word)
	mov	missing_char,ax		;remember the missing char.
	mov	di,offset indices
	rep	stosw
	mov	ax,this_font.ascent	;compute height of character.
	add	ax,this_font.descent
	mov	char_height,ax		;save it.
	lodsw				;get the character count
	mov	cx,ax			;save it for loop below.
	lodsb				;get the width of the missing char.
	mov	ah,0
	add	ax,7			;round up to next nearest byte.
	shr	ax,1			;and convert pixels
	shr	ax,1			; to
	shr	ax,1			; bytes.
	mul	char_height		;find the size.
	add	si,ax			;move ahead by this size.
use_font_1:
	lodsb				;get a font index.
	call	font_index		;get pointer into indices.
	mov	[bx],si			;make this entry point to the char.
	lodsb				;get the width of this char.
	mov	ah,0
	add	ax,7			;round up to next nearest byte.
	shr	ax,1			;and convert pixels
	shr	ax,1			; to
	shr	ax,1			; bytes.
	mul	char_height		;find the size.
	add	si,ax			;move ahead by this size.
	loop	use_font_1

	mov	si,offset indices+2*'a'	;see if there are any lower case letters.
	mov	cx,26
use_font_3:
	lodsw
	cmp	ax,missing_char
	loope	use_font_3		;loop while there are no lower case.
	jne	use_font_4		;go if we found a lower case letter.
	mov	si,offset indices+2*'A'	;copy the upper case letters
	mov	di,offset indices+2*'a'	;  to the lower case letters.
	mov	cx,26
	rep	movsw
use_font_4:

	call	compute_font		;adjust for style.
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret


	public	font_index
font_index:
;enter with al=font index.
;exit with bx->font entry.
	mov	bl,al
	xor	bh,bh
	shl	bx,1
	add	bx,offset indices	;make this entry point to the char.
	ret


	public	make_char_box
make_char_box:
;enter with bx->rect, al=char.
;exit with the rect set to the box surrounding the char.
	push	bx
	call	char_width		;get width of character to delete.
	pop	bx
	mov	ah,0			;make it a word.
	mov	[bx].left,0
	mov	[bx].right,ax		;say rect to clear is char_width wide.
	mov	ax,font.ascent
	neg	ax
	mov	[bx].top,ax
	mov	ax,font.descent
	mov	[bx].bot,ax
	ret


	public	char_width
char_width:
;enter with al=character.
;exit with al=width of that character including the little space after it.
	push	bx
	call	font_index
	mov	bx,[bx]
	mov	ax,sized_font.ascent	;are we scaling the font?
	cmp	ax,this_font.ascent
	mov	al,[bx]			;get the width.
	je	char_width_1		;go if not scaling.
	push	dx
	mov	ah,0
	mul	sized_font.ascent
	div	this_font.ascent
	pop	dx
char_width_1:
	add	ax,style_width
	add	ax,char_separation
	pop	bx
	ret


	public	string_width
string_width:
;enter with si->null terminated string.
;exit with dx=width of the string in bits.
	xor	dx,dx
string_width_1:
	lodsb
	or	al,al
	je	string_width_2
	call	char_width
	mov	ah,0
	add	dx,ax
	jmp	string_width_1
string_width_2:
	ret


	public	read_style
read_style:
	mov	al,font_style
	ret


	public	store_style
store_style:
	mov	font_style,al
	call	compute_font
	ret


compute_font:
;enter with this_font, font_style, and desired_ascent.
;exit with font adjusted for style, and size.
;          and style_width = adjustment to width.
;preserve ax, bx, cx, dx, si, di.
	push	ax
	push	bx
	push	cx
	push	dx

	push	si
	mov	si,current_font
	cmp	si,offset system_font
	je	desire_system
	call	desire_size
	jmp	short use_font_end
desire_system:
	mov	ax,this_font.ascent
	mov	desired_ascent,ax
use_font_end:
	pop	si

	mov	ax,this_font.ascent
	mov	bx,this_font.descent
	mov	cx,this_font.widMax
	mov	dx,this_font.leading
	mov	style_width,0

	cmp	ax,desired_ascent	;do we have the desired size?
	je	compute_font_1		;yes - done with this part.

	push	dx
	mov	ax,bx
	mul	desired_ascent
	div	this_font.ascent
	mov	bx,ax
	mov	ax,cx
	mul	desired_ascent
	div	this_font.ascent
	mov	cx,ax
	pop	ax
	mul	desired_ascent
	div	this_font.ascent
	mov	dx,ax
	mov	ax,desired_ascent
compute_font_1:

	mov	sized_font.ascent,ax
	mov	sized_font.descent,bx
	mov	sized_font.widMax,cx
	mov	sized_font.leading,dx

	test	font_style,BOLD_STYLE
	je	compute_font_3
	inc	style_width		;an extra bit in x.
compute_font_3:

	test	font_style,OUTLINE_STYLE
	je	compute_font_4
	inc	ax			;one to top.
	inc	bx			;one to bot.
	inc	style_width		;one to right.
compute_font_4:

	test	font_style,SHADOW_STYLE
	je	compute_font_5
	inc	style_width		;one to right
	inc	bx			;one to bot.
compute_font_5:

	add	cx,style_width

	mov	font.ascent,ax
	mov	font.descent,bx
	mov	font.widMax,cx
	mov	font.leading,dx

	add	ax,bx
	mov	styled_height,ax

	shr	cx,1			;thin amount is widMax div 4.
	shr	cx,1
	mov	char_separation,cx

	test	font_style,COMP_STYLE
	je	compute_font_6
	mov	bp,char_separation	;push the characters right up next to
	sub	style_width,bp		;  each other.
compute_font_6:

	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret


	public	center_string
center_string:
;enter with bx->rect, si->string.
;exit with the string drawn in the middle of the rect.
	push	si
	push	bx
	call	string_width		;dx=string width.
	pop	bx
	pop	si

	mov	cx,[bx].right		;compute the width of the rect.
	sub	cx,[bx].left
	sub	cx,dx			;subtract the width of the string.
	sar	cx,1			;center it horizontally.
	add	cx,[bx].left

	mov	dx,[bx].bot		;compute the height of the rect.
	sub	dx,[bx].top
	sub	dx,styled_height	;subtract the height of the font.
	sar	dx,1			;center it vertically.
	add	dx,[bx].top
	add	dx,font.ascent

	push	bx
	call	draw_string
	pop	bx
	ret


	public	draw_char
draw_char:
;enter with cx, dx=point, al=font index.
;exit with cx, dx->place to put next char.
	mov	single_char,al
	mov	si,offset single_char
;fall through
;
;
	public	draw_string
draw_string:
;enter with cx, dx=place to draw string, si->string.
;exit with cx, dx->place after string, si->after null of string.
	store2	string_pt

	mov	ax,ds
	mov	char_bitmap.pntr.segm,ax
	mov	line_bitmap.pntr.segm,ax
	mov	ax,free_space
	mov	line_bitmap.pntr.offs,ax

	xor	ax,ax			;describe the char as a bitmap.
	mov	char_bitmap.bounds.top,ax
	mov	char_bitmap.bounds.left,ax
	mov	ax,this_font.ascent	;get the real height of this char.
	add	ax,this_font.descent
	mov	char_bitmap.bounds.bot,ax

	xor	ax,ax			;describe the line as a bitmap.
	mov	line_bitmap.bounds.top,ax
	mov	ax,sized_font.ascent	;get the sized height of this line.
	add	ax,sized_font.descent
	mov	line_bitmap.bounds.bot,ax
	mov	line_bitmap.bounds.left,ax	;leave room for bolding.
	mov	line_bitmap.bounds.right,ax
	push	ax			;keep a copy for restoring later.

	mul	line_bitmap.bytes	;multiply the height by the width.
	mov	line_width,ax
	mov	cx,ax			;clear out that many bytes.
	mov	ax,ds
	mov	es,ax
	mov	di,line_bitmap.pntr.offs
  if black_on_white
	mov	ax,-1
  else
	xor	ax,ax
  endif
	rep	stosb

	mov	bx,offset actual_char_rect
	call	set_empty_rect

draw_string_0:
	lodsb
	or	al,al
	je	draw_string_1
	push	si
	call	font_index
	mov	si,[bx]			;get a pointer to the char.
	lodsb				;get the width.
	mov	ah,0
	mov	char_bitmap.bounds.right,ax	;remember the width.

	add	ax,7
	shr	ax,1
	shr	ax,1
	shr	ax,1
	mov	char_bitmap.bytes,ax	;number of bytes wide.

	mov	ax,char_bitmap.bounds.right	;get the current width.

	mov	bx,this_font.ascent	;do we have the proper font size?
	cmp	bx,sized_font.ascent
	je	make_sized_char_1	;yes - use the current width.
	mul	sized_font.ascent	;no - scale it to the new width.
	div	this_font.ascent
	or	ax,ax			;is the width now zero?
	jne	make_sized_char_1	;no.
	inc	ax			;yes - width should be at least one.
make_sized_char_1:
	add	line_bitmap.bounds.right,ax

	mov	char_bitmap.pntr.offs,si

  if black_on_white
	mov	put_byte_subr,offset preset_verb
  else
	mov	put_byte_subr,offset pset_verb
  endif
	mov	si,offset char_bitmap
	mov	di,offset line_bitmap
	call	blit

	mov	ax,line_bitmap.bounds.right	;move to the right by one char.
	add	ax,char_separation
	add	ax,style_width
	mov	line_bitmap.bounds.right,ax	;now remember where the next
	mov	line_bitmap.bounds.left,ax	;  char goes.
	pop	si
	add	ax,sized_font.widMax		;is there room for another char?
	cmp	ax,80*8
	jl	draw_string_0			;yes.
draw_string_5:
	lodsb					;return si->after null.
	or	al,al
	jne	draw_string_5
draw_string_1:

	pop	line_bitmap.bounds.left		;place the entire line.
	push	si

	test	font_style,BOLD_STYLE
	je	draw_string_2

	mov	si,offset line_bitmap
	mov	di,offset line1_bitmap
	push	ds
	pop	es
	mov	cx,(size bitmap)/2
	rep	movsw

	dec	line1_bitmap.bounds.left
	dec	line1_bitmap.bounds.right

  if black_on_white
	mov	put_byte_subr,offset and_verb
  else
	mov	put_byte_subr,offset or_verb
  endif
	mov	si,offset line_bitmap
	mov	di,offset line1_bitmap
	call	blit
	dec	line_bitmap.bounds.left

draw_string_2:

	test	font_style,UNDERLINE_STYLE
	je	draw_string_3

	mov	si,free_space		;find the base line.
	mov	ax,sized_font.ascent
	inc	ax
	mul	line_bitmap.bytes
	add	si,ax
	mov	cx,80			;add the underline to the entire base line.
	mov	ah,0
	lodsb
draw_string_4:
	mov	dl,al			;get the original bit.
	ror	ax,1
	or	dl,al			;make a copy to the right.
	rol	ax,1
	mov	ah,al			;now move over a byte.
	lodsb
	rol	ax,1
	or	dl,ah
	ror	ax,1
	not	dl			;and form an underline out of it.
	xor	dl,ah			;exclusive or with the copy we have.
	mov	[si-2],dl		;and store it back.
	loop	draw_string_4
draw_string_3:
	test	font_style,ITALIC_STYLE
	je	draw_string_6

	mov	ax,sized_font.widMax	;ensure that the rightmost char gets blacked out.
	add	line_bitmap.bounds.right,ax

	mov	si,offset line_bitmap
	mov	di,offset line1_bitmap
	push	ds
	pop	es
	mov	cx,(size bitmap)/2
	rep	movsw

	push	line_bitmap.bounds.bot

	mov	cx,sized_font.ascent		;compute the height of the font.
	add	cx,sized_font.descent
	inc	cx				;round up.
	shr	cx,1				;number of times through the loop.
	push	cx
	jmp	short	draw_string_8
draw_string_7:
	mov	put_byte_subr,offset pset_verb
	mov	si,offset line_bitmap
	mov	di,offset line1_bitmap
	push	cx
	call	blit
	pop	cx

draw_string_8:
	mov	ax,line1_bitmap.bounds.top	;move down by two.
	add	ax,2
	mov	line1_bitmap.bounds.top,ax
	mov	line_bitmap.bounds.top,ax
	add	ax,2
	mov	line1_bitmap.bounds.bot,ax
	mov	line_bitmap.bounds.bot,ax

	dec	line1_bitmap.bounds.left	;move this one to the left.
	dec	line1_bitmap.bounds.right

	loop	draw_string_7

	pop	cx
	dec	cx				;the first one wasn't moved.
	sub	line_bitmap.bounds.left,cx	;remember that it's wider.

	mov	ax,sized_font.widMax		;remove correction for rightmost char.
	sub	line_bitmap.bounds.right,ax

	pop	line_bitmap.bounds.bot		;restore the line bitmap.
	mov	line_bitmap.bounds.top,0

draw_string_6:
;we get here with line_bitmap all set up.

	load2	string_pt
	sub	dx,sized_font.ascent
	mov	put_byte_subr,offset pset_verb
	call	place_string

	test	font_style,OUTLINE_STYLE+SHADOW_STYLE
	je	draw_string_outline_1
  if black_on_white
	mov	put_byte_subr,offset and_verb
  else
	mov	put_byte_subr,offset or_verb
  endif
	inc	dx
	call	place_string		;unshifted
	inc	cx
	call	place_string		;right
	inc	dx
	call	place_string		;down,right
	dec	cx

	test	font_style,SHADOW_STYLE
	je	draw_string_outline_2
	inc	dx
	call	place_string		;down,down
	inc	cx
	call	place_string		;down,down,right
	inc	cx
	call	place_string		;down,down,right,right
	dec	dx
	call	place_string		;down,right,right
	dec	dx
	call	place_string		;right,right
	inc	dx
	sub	cx,2			;leave at down
draw_string_outline_2:

	call	place_string		;down
	dec	cx
	call	place_string		;down,left
	dec	dx
	call	place_string		;left
	dec	dx
	call	place_string		;up,left
	inc	cx
	call	place_string		;up
	inc	cx
	call	place_string		;up,right
	inc	dx
	dec	cx
  if black_on_white
	mov	put_byte_subr,offset or_not_verb
  else
	mov	put_byte_subr,offset and_not_verb
  endif
	call	place_string		;unshifted
	dec	dx
draw_string_outline_1:

	load2	string_pt
	mov	ax,line_bitmap.bounds.right	;compute the length of the line.
	sub	ax,line_bitmap.bounds.left
	add	cx,ax			;return a new point.

	pop	si
	ret


place_string:
;enter with line_bitmap, cx,dx=place on screen to put line_bitmap.
;preserve line_bitmap, cx,dx.

	push	cx			;remember the original point.
	push	dx

	mov	ax,screen_seg
	mov	screen_bitmap.pntr.segm,ax

	store2	screen_bitmap.bounds.topleft

	load2	line_bitmap.bounds.botright
	sub2	line_bitmap.bounds.topleft
	add2	screen_bitmap.bounds.topleft
	store2	screen_bitmap.bounds.botright

	mov	si,offset line_bitmap	;make a copy of the source because
	mov	di,offset line1_bitmap	;  we change it.
	push	ds
	pop	es
	mov	cx,(size bitmap)/2
	rep	movsw

;setup the dest bitmap
	mov	si,offset screen_bitmap.bounds	;copy the source rect to the source bitmap.
	mov	bx,clip_rect
	mov	di,offset line1_bitmap.bounds
	call	sect_rect

	mov	si,offset line1_bitmap.bounds
	mov	di,offset screen_bitmap.bounds
	call	assign_rect

	mov	bx,offset actual_char_rect
	mov	si,offset screen_bitmap.bounds
	mov	di,bx
	call	union_rect		;include this one in the rect.

	pop	dx
	pop	cx
	push	cx
	push	dx

	mov	bx,offset line1_bitmap.bounds
	neg	cx
	neg	dx
	add	cx,line_bitmap.bounds.left
	call	offset_rect

;now do the transfer.
	mov	si,bx			;bx->source bitmap.
	mov	di,offset screen_bitmap
	call	blit

	pop	dx			;restore the original point.
	pop	cx

	ret

code	ends

	end
