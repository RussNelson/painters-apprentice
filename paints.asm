;paints.asm - Scrolling
;History:25,1

data	segment	public

	include	paint.def

page_bytes	equ	80
page_lines	equ	792

	public	page_size
page_size	equ	page_bytes*page_lines

	public	wind_ptr, wind_on_page
wind_ptr	dw	?		;->upper left byte of window.
wind_on_page	point	<>

	extrn	page_seg: word		;paint
	extrn	wind_bytes: word	;paint
	extrn	h_window: word		;paint
	extrn	draw_window: byte	;paint

	extrn	screen_seg: word

data	ends

code	segment	public
	assume	cs:code, ds:data

	extrn	protect_mouse: near	;paintmse
	extrn	unprotect_mouse: near	;paintmse


	public	copy_window_to_page
copy_window_to_page:
	mov	bx,offset draw_window
	call	protect_mouse
	push	ds
	push	bp
	call	compute_page_ptr
	mov	di,ax			;->upper left byte on the page.
	mov	bx,wind_bytes		;width of window.
	mov	ax,page_bytes		;width of the page.
	sub	ax,bx			;ax=offset from page pointer for next scanline.
	mov	bp,screen_bytes			;width of screen
	sub	bp,bx			;bp=offset from window pointer for next scanline.
	mov	dx,h_window		;height of window.
	mov	es,page_seg		;page segment.
	mov	cx,screen_seg		;green plane segment.
	mov	si,wind_ptr		;window pointer.
	mov	ds,cx			;window segment.
copy_window_to_page_1:
	mov	cx,bx			;how many bytes to move. (wind_bytes)
	shr	cx,1
	jnc	copy_window_to_page_2
	movsb
copy_window_to_page_2:
	rep	movsw			;move one scan line from window to page.
	add	si,bp			;move window pointer down a scan line.
	add	di,ax			;move page pointer down a "scan line".
	dec	dx			;one less scan line to copy.
	jnz	copy_window_to_page_1	;if more to copy then do it.
	pop	bp
	pop	ds
	call	unprotect_mouse
	ret


	public	copy_page_to_window
copy_page_to_window:
	mov	bx,offset draw_window
	call	protect_mouse
	push	ds
	push	bp
	call	compute_page_ptr
	mov	si,ax			;->upper left byte on the page.
	mov	bx,wind_bytes		;width of window.
	mov	ax,page_bytes		;width of the page.
	sub	ax,bx			;ax=offset from page pointer for next scanline.
	mov	bp,screen_bytes			;width of screen.
	sub	bp,bx			;bp=offset from window pointer for next scan line.
	mov	dx,h_window		;height of window.
	mov	cx,screen_seg		;green plane segment.
	mov	es,cx			;window page.
	mov	di,wind_ptr		;window pointer.
	mov	ds,page_seg		;page segment.
copy_page_to_window_1:
	mov	cx,bx			;how many bytes to move.
	shr	cx,1
	jnc	copy_page_to_window_2
	movsb
copy_page_to_window_2:
	rep	movsw			;move one scan line from page to window.
	add	si,ax			;move page pointer down a "scan line".
	add	di,bp			;move window pointer down a scan line.
	dec	dx			;one less scan line to copy.
	jnz	copy_page_to_window_1	;if more to move then do it.
	pop	bp
	pop	ds
	call	unprotect_mouse
	ret


	public	swap_page_and_window
swap_page_and_window:
	mov	bx,offset draw_window
	call	protect_mouse
	push	ds
	push	bp
	call	compute_page_ptr
	mov	di,ax			;->upper left byte on the page.
	mov	bx,wind_bytes		;width of window.
	mov	ax,page_bytes		;width of the page.
	sub	ax,bx			;ax=offset from page pointer for next scanline.
	mov	bp,screen_bytes			;width of screen
	sub	bp,bx			;bp=offset from window pointer for next scanline.
	mov	dx,h_window		;height of window.
	mov	es,page_seg		;page segment.
	mov	cx,screen_seg		;green plane segment.
	mov	si,wind_ptr		;window pointer.
	mov	ds,cx			;window segment.
swap_page_and_window_1:
	mov	cx,bx			;how many bytes to move. (wind_bytes)
	push	ax
swap_page_and_window_2:
	lodsb				;get a byte from the window
	xchg	al,es:[di]		;swap it with the page.
	mov	ds:[si-1],al		;move the swapped one back into the window.
	inc	di			;go to the next page byte.
	loop	swap_page_and_window_2	;if more to copy then do it.
	pop	ax
	add	si,bp			;move window pointer down a scan line.
	add	di,ax			;move page pointer down a "scan line".
	dec	dx			;one less scan line to copy.
	jnz	swap_page_and_window_1	;if more to copy then do it.
	pop	bp
	pop	ds
	call	unprotect_mouse
	ret


compute_page_ptr:
	mov	ax,wind_on_page.v
	mov	dx,page_bytes		;width of the page
	mul	dx
	mov	dx,wind_on_page.h
	shr	dx,1
	shr	dx,1
	shr	dx,1
	add	ax,dx
	ret


code	ends

	end
