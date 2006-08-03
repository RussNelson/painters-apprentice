;paintdio.asm - Disk Input/Output
;History:1694,1
;Fri Apr 27 21:10:57 1990 Change the default extension to ".ipa".
;Tue Dec 13 23:11:28 1988 split out getenv from get_current.
;Wed Nov 16 23:57:58 1988 save es in [write|read]_[byte_word].
;Sat Nov 12 19:29:40 1988 change the fatal_error handler.
;Thu Nov 10 23:19:21 1988 find PA files by env string, /paint, or current dir.
;Wed Nov 09 22:30:51 1988 correct more stuff for two char extensions.
;Wed Nov 09 22:23:41 1988 find_files doesn't deal with two character extensions.
;10-28-88 23:49:28 add change_drive_cmd
;10-28-88 23:42:11 make new_font_menu public for paint's sake.
;10-28-88 23:35:12 in find_files:, just give them a list of files if they give a subdirectory.
;10-28-88 23:29:16 remember to change drives on load_menu_font also.
;09-17-88 21:37:47 remove error reporting from read_file.
;06-22-88 00:01:56 get rid of font_list ifdef.
;06-10-88 23:57:04 add (some) pathname support.
;02-07-88 13:25:27 move the filename into the pull down bar.
;01-25-88 00:06:48 force find_files to store the extension also.
;01-23-88 15:05:53 add code to find .ldi files.

data	segment	public

	include	paintflg.asm

	include	paint.def

	include	findfile.inc

load_msg	db	'Load:',0
save_msg	db	'Save as:',0
disk_full_msg	db	'Disk Full!',0
dir_full_msg	db	'Directory Full!',0
no_exist_msg	db	' not found!',0
not_found_msg	db	30 dup(?)
too_big_msg	db	'Font is too big!',0
bad_file_msg	db	'Bad File!',0
char_err_msg	db	'Error on character dev',0
fatal_err_msg	db	'Error on drive '
fatal_err_drive	db	?
		db	':!',0
write_prot_msg	label	byte
write_prot_drive	db	?
		db	': is Write protected!',0
no_disk_msg	db	'No disk in drive '
no_disk_drive	db	?
		db	':!',0
lost_msg	db	'Discard current picture?',0
already_msg	db	'Overwrite existing file?',0
program_msg	db	'Bad program file!',0
cancel_msg	db	'Cancel',0
error_msg	db	40 dup(?)

find_buf	find_buf_struc<>

byte_buffer	label	byte
word_buffer	dw	?

fnt_ext		db	'fnt'
		db	0

scrap_name	db	'scrap.scr',0
scrap_00_name	db	'scrap'
scrap_00	db	'00.scr',0

program_name	db	'paint.pri',0

bin_subdir	db	'bin',0
scrap_subdir	db	'scraps',0
font_subdir	db	'fonts',0

handle		dw	?
filename	db	64 dup(?)

MAX_LDI_SIZE	equ	1024
	public	ldi_list
ldi_list	db	30 dup(3 dup(?))	;filenames that we load.
star_dot_ldi	db	'???.ldi',0

xxx_dot_ldi	db	'x'
xx_dot_ldi	db	'xx.ldi',0
img_list	db	'ipa'
		db	0

star_dot_xxx	db	'*.xxx',0	;the xxx gets replaced.
star_dot_star	db	'*.*',0

null_str	db	0,0

star_dot_fnt	db	'*'
dot_fnt		db	'.fnt',0

null_rect	rect	<0,0,0,0>

buffer_size	equ	1024
buffer		db	buffer_size dup(?)
buffer_ptr	dw	?		;->next byte to transfer.
buffer_contents	dw	?		;=number of bytes in buffer.
read_not_write	db	?		;=1 if reading, =0 if writing.

save_stack	dw	?

	public	font_menu_list, new_font_menu
font_menu_list	label	byte
	db	'Font',0		;name of menu
	pdi	0,0,0,0,<Scan Disk for Fonts >
	pdi	0,0,0,0,<Load Font from Menu>
new_font_menu	label	byte
	db	8*(20+(size pulls_struc)) dup(?)

font_count	db	?		;number of fonts found.

	public	lo_water
lo_water	dw	?

current_image	dw	0
current_font	dw	0

filename_struc	struc
filename_name	db	9 dup(?)	;filename of font file.
filename_size	db	?		;fontsize menu that this falls under.
filename_font	db	?		;font menu that this falls under.
filename_struc	ends

max_font_files	equ	20

current_file	dw	-1
last_filename	dw	?		;->after last valid filename.
filenames	db	max_font_files*(size filename_struc) dup(?)
max_filename	label	byte

font_header_len	equ	40		;this is how much we read out of the font file.
font_header	db	font_header_len dup(0)	;this is where we read it.

current_dir	db	64+2 dup(?)		;base subdir for pa files.

paint_env_str	db	"PAINT="
paint_env_len	equ	$-paint_env_str

paint_dir_str	db	"\paint",0

comspec_env_str	db	"COMSPEC="
comspec_env_len	equ	$-comspec_env_str

	extrn	mem_top: word		;paint
	extrn	page_seg: word		;paint
	extrn	free_space: word	;paint
	extrn	loaded_from_disk: byte	;paint
	extrn	changes_flag: byte	;paint
	extrn	fatbits_flag: byte	;paint
	extrn	select_rect: word	;paint
	extrn	current_filename: byte	;paint
	extrn	center_window: word	;paint
	extrn	page_seg: word		;paint
	extrn	max_wind_bytes: word	;paint
	extrn	wind_ptr: word		;paint
	extrn	h_window: word		;paint
	extrn	max_window: word	;paint
	extrn	clip_rect: word		;paint
	extrn	pull_down_storage: byte	;paintdat
	extrn	disk_font: word		;paintf
	extrn	font_size_list: word	;paintf
	extrn	font_size_length: abs	;paintf
	extrn	wind_on_page: word	;paints
	extrn	page_size: abs		;paints
	extrn	redraw_flag: byte	;painth
	extrn	page_rect: word		;paint
	extrn	comspec: byte		;painth

	extrn	screen_seg: word	;paintega

	data	ends

code	segment	public
	assume	cs:code, ds:data

	extrn	program: byte
	extrn	program_id: word
	extrn	program_size: abs

	extrn	set_margins: near	;paint
	extrn	ring_bell: near		;paint
	extrn	toggle_fatbits: near	;paint
	extrn	pointing_shape: near	;paint
	extrn	waiting_shape: near	;paint
	extrn	update_window: near	;paint
	extrn	select_new_menu: near	;paint
	extrn	update_page: near	;paint
	extrn	dir_select: near	;paintd
	extrn	dialog: near		;paintd
	extrn	alert: near		;paintd
	extrn	error_alert: near	;paintd
	extrn	read_font_number: near	;paintf
	extrn	load_font: near		;paintf
	extrn	start_select: near	;painth
	extrn	center_select: near	;painth
	extrn	clear: near		;painth
	extrn	protect_mouse: near	;paintmse
	extrn	unprotect_mouse: near	;paintmse
	extrn	get_mouse: near		;paintmse
	extrn	new_menu: near		;paintp
	extrn	strend: near		;paintp
	extrn	empty_rect: near	;paintr
	extrn	peg_rect: near		;paintr
	extrn	strcpy: near		;paint
	extrn	phd_env: word		;paint

our_data	dw	?

get_current:
	mov	si,offset comspec_env_str	;see if this is the one.
	mov	cx,comspec_env_len
	mov	di,offset comspec
	call	getenv

	mov	si,offset paint_env_str	;see if this is the one.
	mov	cx,paint_env_len
	mov	di,offset current_dir
	call	getenv
	jnc	get_current_5		;go if we found it.

get_current_6:
;now we see if there is a /paint subdirectory.
	mov	dx,offset paint_dir_str
	mov	cx,10h			;find subdirectories also, of course.
	call	find_first
	jc	get_current_7
	push	ds
	pop	es
	mov	di,offset current_dir
	call	store_drive
	mov	si,offset paint_dir_str
	call	strcpy
	mov	[di-1].b,'\'
	mov	[di].b,0
	ret
get_current_7:
	push	ds
	pop	es
	mov	di,offset current_dir
	call	store_drive
	mov	al,'\'			;it's an absolute path name.
	stosb
	mov	ah,47h			;get the current subdirectory.
	mov	si,di
	mov	dl,0			;default drive.
	int	21h
get_current_5:
	call	strend			;find the end of the string.
	cmp	[si-2].b,'\'		;does it end in a slash?
	je	get_current_1
	cmp	[si-2].b,'/'		;does it end in a slash?
	je	get_current_1
	mov	[si-1].b,'\'		;no - append a slash.
	mov	[si].b,0
get_current_1:

	ret


getenv:
;enter with ds:si -> environment string to look for, cx = length of string,
;  ds:di -> place to put the string's value.
	push	di			;remember where we're supposed to put it.

	mov	es,phd_env		;search the environment for PAINT=
	xor	di,di

getenv_2:
	cmp	es:[di].b,0		;see if we're at the end.
	je	getenv_0

	push	cx
	push	si
	push	di
	repe	cmpsb
	pop	di
	pop	si
	je	getenv_3
	mov	cx,-1			;skip to the next null.
	xor	al,al
	repne	scasb
	pop	cx
	jmp	getenv_2
getenv_3:
;copy the environment string to current_dir.
	pop	cx
	add	di,cx			;go to the end of the string.
	pop	si			;pushed as di, -> place to put the string.
getenv_4:
	mov	al,es:[di]
	mov	[si],al
	inc	di
	inc	si
	or	al,al
	jne	getenv_4
	dec	si			;point si to the null again.
	clc
	ret
getenv_0:
	add	sp,2
	stc
	ret


store_drive:
	mov	ah,19h
	int	21h
	add	al,'A'			;store the drive name also.
	stosb
	mov	al,':'
	stosb
	ret

	public	load_pri
load_pri:
	mov	our_data,ds

	call	get_current
	call	find_ldi		;find the ldi files.
	mov	si,offset program_name
	mov	bx,offset bin_subdir
	call	copy_to_filename

	call	open_file
	jc	load_pri_2

	call	get_filsz

	push	cx
	mov	dx,12
	call	skip_bytes
	pop	cx
	sub	cx,12
	jbe	load_pri_1

	mov	di,offset program
	push	cs
	pop	es
	cmp	cx,program_size
	ja	load_pri_1
	call	read_file

	call	close_file
	cmp	program_id,'P' + '1'*256 ;is there a program?
	je	load_pri_4		;yes - turn margins on.
	cmp	program_id,'P' + '2'*256 ;is there a program?
	jne	load_pri_3		;no - don't turn margins on.
load_pri_4:
	call	set_margins
load_pri_3:
	ret
load_pri_1:
	mov	si,offset program_msg
	call	error_alert
load_pri_2:
	mov	program_id,0
	ret


find_ldi:
;find the names of the .ldi files.
	mov	si,offset star_dot_ldi	;actually '???.ldi'.
	mov	bx,offset bin_subdir
	call	copy_to_filename

	mov	di,offset ldi_list
	mov	dx,offset filename
	mov	cx,0
	call	find_first		;any files?
	jc	find_ldi_end		;no - all done.
find_ldi_again:
	mov	si,offset find_buf.find_buf_name	;yes - copy the first three characters
	movsw				;  of the filename in.
	movsb
	call	find_next		;any more files?
	jnc	find_ldi_again
find_ldi_end:
	xor	al,al			;null terminate the list.
	stosb
	ret


	public	cut
cut:
	mov	bx,offset select_rect
	call	empty_rect
	jc	cut_1
	ret
cut_1:
	mov	save_stack,sp
	call	copy
	jc	cut_2
	call	clear
cut_2:
	ret


	public	copy_number
copy_number:
	call	make_scrap_number
	jmp	short copy_0

	public	copy
copy:
	mov	si,offset scrap_name
copy_0:
	mov	bx,offset select_rect
	call	empty_rect
	jc	copy_1
	clc				;say that the copy was ok.
	ret
copy_1:
	mov	save_stack,sp
	mov	bx,offset scrap_subdir
	call	copy_to_filename

	call	create_file		;try to create the file.
	jc	copy_done		;  can't.

	mov	cx,free_space		;compute the size of the scrap.
	sub	cx,offset pull_down_storage
	mov	si,offset pull_down_storage
	push	ds
	pop	es
	call	write_file		;write out the scrap.
	jc	copy_done		;  don't close - already closed.
	call	close_file		;no - close the file.
copy_done:
	ret


make_scrap_number:
;enter with al=scrap number.
	aam
	add	ax,'00'
	xchg	ah,al
	mov	word ptr scrap_00,ax
	mov	si,offset scrap_00_name
	ret


	public	paste_number
paste_number:
	call	make_scrap_number
	jmp	short paste_0

paste_error:
	mov	si,offset not_found_msg
	call	error_alert		;flag the error.
paste_done:
	ret
	public	paste
paste:
	mov	si,offset scrap_name
paste_0:
	mov	changes_flag,1		;say that there have been changes.
	mov	save_stack,sp
	mov	bx,offset scrap_subdir
	call	copy_to_filename

	call	open_file
	jc	paste_error		;file no found - give error.

	call	get_filsz
	push	ds
	pop	es
	mov	di,offset pull_down_storage
	mov	free_space,di
	call	read_file
	mov	free_space,di
	call	check_free_space

	call	close_file

	mov	ax,0			;switch to the select box.
	call	select_new_menu

	mov	bx,clip_rect		;compute the size of the window
	load2	[bx].botright
	sub2	[bx].topleft
	cmp	cx,pull_down_storage.h	;is the window wide enough?
	jb	paste_4			;no.
	cmp	dx,pull_down_storage.v	;is the window high enough?
	jnb	paste_3			;yes.
paste_4:
	call	toggle_fatbits
paste_3:
	call	center_select

	mov	si,offset null_rect
	call	start_select
	ret


	public	get_screen
get_screen:
;enter with si -> filename to use.
	mov	save_stack,sp
	mov	bx,offset scrap_subdir
	call	copy_to_filename

	call	open_file
	jnc	get_screen_1		;no - skip ahead.

	mov	si,offset not_found_msg
	jmp	get_screen_error

get_screen_1:
	mov	bx,offset max_window
	call	protect_mouse

	mov	dx,4			;start at 4 bytes into the file.
	call	skip_bytes

	mov	cx,h_window		;how many scan lines to load.
	mov	di,wind_ptr		;where to start loading.
get_screen_2:
	push	di
	push	cx
	mov	cx,max_wind_bytes
	mov	ax,screen_seg		;read it into the green plane.
	mov	es,ax
	call	read_file
	pop	cx
	pop	di

	jc	get_screen_bad		;if an error occurred then flag it.
	add	di,screen_bytes			;go down a line.
	loop	get_screen_2		;if more to move then do it.

	call	close_file
	call	unprotect_mouse
	clc
	ret

get_screen_bad:
	call	unprotect_mouse
	call	close_file
	mov	si,offset bad_file_msg
get_screen_error:
	call	error_alert		;flag the error.
	stc
	ret


	public	prompt_write_file, just_resave_file
prompt_write_file:
;input the filename in the title window and put it into the filename and then...
        mov	si,offset save_msg	;prompt for filename.
	call	dialog			;get it.
	jnc	save_file		;cancelled? - don't write the file.
	call	ring_bell		;yes - done.
	ret

just_resave_file:
	mov	save_stack,sp
	mov	si,offset current_filename
	call	parse_name
	jnc	save_file_replace
save_file_no_ldi:
	ret

save_file:
;enter with si-> filename
	mov	save_stack,sp
	call	set_current_file
	call	parse_name
	jc	save_file_no_ldi
	call	open_file		;does the file already exist?
	jc	save_file_replace	;no - do it.

	call	close_file		;close the file.

	mov	si,offset already_msg
	call	alert			;yes - prompt for replace verification.
	jnc	save_file_replace	;yes.
save_file_exit:
	ret

save_file_replace:
	call	update_page
	call	create_file
	jc	save_file_exit

	call	save_using_ldi
	jc	write_exit

	mov	loaded_from_disk,1	;say that revert should load a file.
	mov	changes_flag,0
	call	close_file
write_exit:
	ret


change_drive:
;return cy if the thing that they selected is actually a drive or subdir.
;  else return nc, si->filename.
	lodsb				;get the attribute byte.
	test	al,10h			;is this a subdir?
	je	change_drive_1		;no - just load it.
	mov	current_image,0		;we're not in that subdir anymore.
	cmp	[si+1].b,':'		;is this really a drive?
	je	change_drive_2		;yes.
	mov	dx,si			;yes - change to that subdirectory.
	mov	ah,3bh
	int	21h
	clc
	ret
change_drive_2:
	mov	dl,[si]			;select that drive.
	sub	dl,'A'
	mov	ah,0eh
	int	21h
	clc
	ret
change_drive_1:
	stc
	ret


	public	change_drive_cmd
change_drive_cmd:
	mov	si,offset null_str
	xor	bx,bx
	call	find_files
	jc	change_drive_cmd_1
	mov	ax,0
	call	dir_select
	jc	change_drive_cmd_1

	call	change_drive		;change drives if applicable.
	jnc	change_drive_cmd	;go do it again.
change_drive_cmd_1:
	ret


	public	prompt_read_file, just_reload_file
prompt_read_file:
;enter with nothing.
;use dialog manager to get a filename and load the file.
	cmp	changes_flag,0		;any changes?
	je	im_sure			;no - don't prompt.
	mov	si,offset lost_msg	;still want to load?
	call	alert
	jnc	im_sure			;yes
	ret
im_sure:
	mov	si,offset ldi_list
	xor	bx,bx
	call	find_files
	jc	not_sure
	mov	ax,current_image
	call	dir_select
	mov	current_image,ax
	jc	not_sure

	call	change_drive		;change drives if applicable.
	jnc	im_sure
	jmp	short load_file

not_sure:
	call	ring_bell		;yes - done.
	ret

just_reload_file:
	mov	si,offset current_filename
load_file:
;enter with si->file to read.
	mov	save_stack,sp
	call	set_current_file
	call	parse_name
	jc	load_file_no_ldi
	call	open_file
	jnc	load_file_exist

	mov	si,offset not_found_msg
	call	error_alert
	ret
load_file_no_ldi:
	ret
load_file_exist:
	call	load_using_ldi
	jc	read_error
	load2	wind_on_page
	mov	si,clip_rect		;->box we're dragging around.
	mov	di,offset page_rect
	call	peg_rect
	store2	wind_on_page
	call	update_window
	mov	loaded_from_disk,1	;say that revert should load a file.
	mov	changes_flag,0
read_error:
	call	close_file
	ret

	jmp	seek_file
	jmp	report_error
	jmp	get_filename
	jmp	read_eof
	jmp	load_wind_on_page
	jmp	write_file
	jmp	write_word
	jmp	write_byte
	jmp	store_wind_on_page
	jmp	get_page_in_es
	jmp	read_file
	jmp	read_word
	jmp	read_byte
image_code	label	byte
ldi_version	dw	?
load_using_ldi:
	db	3 dup(?)
save_using_ldi:
	org	image_code + MAX_LDI_SIZE

get_filename:
	mov	si,offset current_filename
	ret

get_page_in_es:
	mov	es,page_seg
	ret

load_wind_on_page:
	load2	wind_on_page
	ret

store_wind_on_page:
	store2	wind_on_page
	ret


write_word:
;enter with ax=count of next block.
;preserve cx.
	push	ax
	push	si
	push	cx
	push	es

	mov	word_buffer,ax
	push	ds
	pop	es
	mov	si,offset word_buffer
	mov	cx,2
	call	write_file

	pop	es
	pop	cx
	pop	si
	pop	ax
	ret


write_byte:
;enter with al = byte to write.
	push	ax
	push	si
	push	cx
	push	es
	mov	byte_buffer,al
	push	ds
	pop	es
	mov	si,offset byte_buffer
	mov	cx,1
	call	write_file
	pop	es
	pop	cx
	pop	si
	pop	ax
	ret


set_current_file:
;copy the filename that si points to to the current_filename
	push	si
	mov	di,offset current_filename
	call	strcpy
	pop	si
	ret


read_word:
	push	cx
	push	di
	push	es

	push	ds
	pop	es
	mov	di,offset word_buffer
	mov	cx,2
	call	read_file
	mov	ax,word_buffer

	pop	es
	pop	di
	pop	cx
	ret


read_byte:
	push	cx
	push	di
	push	es

	push	ds
	pop	es
	mov	di,offset byte_buffer
	mov	cx,1
	call	read_file
	mov	al,byte_buffer

	pop	es
	pop	di
	pop	cx
	ret


	public	load_menu_font
load_menu_font:
	mov	si,offset fnt_ext
	mov	bx,offset font_subdir
	call	find_files
	jc	load_menu_font_1
	mov	ax,current_font
	call	dir_select
	mov	current_font,ax
	jc	load_menu_font_1

	call	change_drive		;change drives if applicable.
	jnc	load_menu_font

	push	si
	mov	bx,offset font_subdir
	call	copy_to_filename

	mov	di,last_filename	;any filenames?
	cmp	di,offset filenames
	je	load_menu_font_3	;no - add a new one.
	sub	di,(size filename_struc)	;point to the previous filename.
	cmp	[di].filename_font,1	;is it loaded from a menu?
	je	load_menu_font_2	;yes - store it to this entry.
load_menu_font_3:
	mov	di,last_filename	;no - add one to the filename list.
	add	last_filename,(size filename_struc)
load_menu_font_2:
	mov	[di].filename_font,1	;remember the font number.
	mov	[di].filename_size,0	;remember the font size.

	pop	si
	call	copy_to_fontname

	mov	al,1			;now load the file.
	call	load_font
	mov	redraw_flag,1		;tell letter handler to redraw.
load_menu_font_1:
	ret


copy_to_fontname:
;enter with di -> a font structure.
	push	di
	lea	di,[di].filename_name
copy_to_fontname_1:
	lodsb
	stosb
	cmp	al,'.'
	jne	copy_to_fontname_1
	mov	byte ptr [di-1],0	;replace the dot with a null.
	pop	di

	ret


find_files:
;find files and put their names at free space.
;enter with si->list of extensions to look for, bx -> place to look for them.
;exit with si->list of files.
	mov	save_stack,sp

	push	ds
	pop	es
	mov	di,free_space		;put them at free space.
	push	di			;remember what the old one was.

find_files_again:
	cmp	byte ptr [si],0		;end of the list?
	je	find_files_end		;yes - we're done.

	push	di
	mov	di,offset star_dot_xxx+2
	movsw				;move the extension into the filename.
	movsb
	cmp	[di-1].b,'.'		;correct for two character extensions.
	jne	find_files_dot
	mov	[di-1].b,0
find_files_dot:
	push	si
	mov	si,offset star_dot_xxx	;look where we expect them.
	call	copy_to_filename
	pop	si
	pop	di

	mov	dx,offset filename
	xor	cx,cx
	call	find_some_files
	jmp	find_files_again
find_files_end:
	or	bx,bx			;did they give us a subdirectory?
	jne	find_just_some		;yes - don't look for subdirs.

	mov	dx,offset star_dot_star
	mov	cx,10h			;find subdirectories also.
	call	find_some_files

find_drives:
	mov	ah,19h			;get the current drive.
	int	21h
	mov	dl,al
	mov	ah,0eh			;reselect it and get the number of drives.
	int	21h
	mov	dl,al
	mov	al,'A'			;start with A:
	add	dl,al
find_drives_1:
	mov	[di].b,90h		;pretend that this is a subdir.
	inc	di
	mov	ah,':'
	stosw
	mov	[di].b,0		;now terminate the name.
	add	di,14-3			;always use 14 bytes.
	inc	al
	cmp	al,dl			;have we stored the highest drive?
	jb	find_drives_1

find_just_some:
	xor	al,al			;null terminate the list.
	stosb				;store a dummy attribute byte.
	stosb

find_files_3:
	mov	si,free_space		;get set to sort.
	lea	di,14[si]
	mov	bh,0			;remember that we didn't swap.
	cmp	[si+1].b,0		;any files at all?
	je	find_files_6		;no.
find_files_5:
	cmp	[di+1].b,0		;is this the terminating null?
	je	find_files_6		;yes.
	cmpsb				;compare the subdirs.
	mov	cx,13			;compare the attributes.
	cmc				;use the reverse of the comparison.
	jne	find_files_8		;continue only if they're equal.
	repe	cmpsb
find_files_8:
	pushf				;now skip forward to the end.
	add	si,cx
	add	di,cx
	popf
	jbe	find_files_5		;go if they were in order.
	mov	bh,1			;remember that we swapped.
	sub	si,14			;back up to the beginning of them.
	sub	di,14
	mov	cx,14
find_files_7:
	lodsb				;swap the names.
	xchg	al,[di]
	mov	[si-1],al
	inc	di
	loop	find_files_7
	jmp	find_files_5		;now keep sorting.
find_files_6:
	or	bh,bh			;did we swap any?
	jne	find_files_3		;yes - we have to continue sorting.

	mov	si,free_space
	mov	di,si
find_files_4:
	mov	bx,si			;save this name.
	movsb				;copy the attributes.
	call	strcpy
	lea	si,14[bx]		;go to the next name.
	cmp	[si+1].b,0		;is this a null?
	jne	find_files_4		;no - not end of list.
	movsw				;move the end of list null and attribute.

	mov	si,free_space		;return si->filenames.

	pop	[di]			;now update free space.
	add	di,2
	mov	free_space,di
	call	check_free_space
	clc
	ret


find_some_files:
	call	find_first		;any files?
	jc	find_some_files_2	;no - all done.
find_some_files_1:
	mov	al,find_buf.find_buf_attr	;get the attributes first.
	xor	al,cl
	test	al,10h			;did we find what we're looking for?
	jne	find_some_files_3
	cmp	word ptr find_buf.find_buf_name,'.'	;is this '.'?
	je	find_some_files_3		;yes - ignore it.

	push	si			;copy the entire thing in.
	push	cx
	mov	al,find_buf.find_buf_attr	;store the attributes first.
	and	al,10h			;we're only interested in subdirs.
	or	al,40h			;make sure it isn't zero.
	stosb
	mov	si,offset find_buf.find_buf_name
	mov	cx,13
	rep	movsb
	pop	cx
	pop	si

find_some_files_3:
	call	find_next		;any more files?
	jnc	find_some_files_1	;yes - keep going.
find_some_files_2:
	ret


	public	get_fonts
get_fonts:
;enter with nothing.
;exit with font menu filled with the names of fonts on current disk.
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	call	get_fonts_0		;we do this for error recovery reasons.
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret

get_fonts_0:
	mov	save_stack,sp

	mov	si,offset star_dot_fnt
	mov	bx,offset font_subdir
	call	copy_to_filename

	mov	new_font_menu,-1	;none found so far.
	mov	font_count,0

	mov	si,offset font_menu_list	;in case of any errors.
	mov	al,3
	call	new_menu

	call	waiting_shape
	mov	di,offset filenames	;start with the first filename.
	mov	last_filename,di	;remember that there aren't any.
	push	ds
	pop	es

	mov	dx,offset filename
	xor	cx,cx
	call	find_first
get_fonts_2:
	jc	get_fonts_end
	call	get_one_font

	cmp	di,offset max_filename	;have we found all of them?
	jae	get_fonts_end		;go look for more fonts.
	call	find_next		;any more fonts?
	jmp	get_fonts_2		;yes - go get it.
get_fonts_end:
	mov	last_filename,di
	mov	si,offset font_menu_list
	mov	al,3
	call	new_menu
	mov	al,2			;get the first font.
	call	load_font
	ret


get_one_font:
;get the font in find_buf.find_buf_name.
;  if it's a new font, add it to the pull down list.
	mov	si,offset find_buf.find_buf_name
	mov	bx,offset font_subdir
	call	copy_to_filename	;put the filename into 'filename'.

	call	open_file
	jc	get_one_font_1		;not a font file.

	push	di
	push	ds
	pop	es
	mov	di,offset font_header	;read the font header in.
	mov	cx,font_header_len
	call	read_file
	pop	di
	jc	get_one_font_1		;not a font file.

	pushf
	call	close_file
	popf

	mov	si,offset font_header	;have we loaded this font already?
	call	search_font
	jnc	get_one_font_2		;we found it.
	cmp	font_count,8		;have we found all of them?
	jae	get_one_font_1		;yes - don't get any more.
	inc	font_count
	call	append_font		;not found - append it.
get_one_font_2:

	push	di			;save the pointer to the filenames.
	mov	si,offset font_header	;find the font_struc.
	call	strend
	mov	ax,[si].ascent		;get the ascent of the font.
	mov	di,offset font_size_list
	mov	cx,font_size_length-1	;pretend it's 72 if not found.
	repne	scasw
	mov	dh,font_size_length
	sub	dh,cl
	sub	dh,2

	pop	di			;restore the pointer to the filenames.
	mov	[di].filename_font,dl	;remember the font number.
	mov	[di].filename_size,dh	;remember the font size.

	mov	si,offset find_buf.find_buf_name
	call	copy_to_fontname	;remember the filename.

	add	di,(size filename_struc)	;go to the next.
get_one_font_1:
	ret


	public	load_proper_font
load_proper_font:
;enter with dh=font number, dl=font size.
;note: only call this if we found at least one font.
;ensure that the proper font is in memory.
	mov	save_stack,sp
	push	ds
	pop	es

	mov	disk_font,0		;say there aren't any fonts.

	mov	bx,offset filenames	;look at all the files.
	mov	al,255			;closest font to the one we want.
	cmp	bx,last_filename	;are there any filenames?
	jb	load_proper_font_1	;yes.
	ret				;no - say that no fonts were found.
load_proper_font_1:
	cmp	dh,[bx].filename_font	;is it in this menu?
	jne	load_proper_font_3	;no - try another.
	cmp	dl,[bx].filename_size	;is it the size we're looking for?
	je	load_proper_font_2	;yes - we found it !!!
	mov	ah,dl
	sub	ah,[bx].filename_size
	rol	ah,1
	jns	load_proper_font_4
	neg	ah
load_proper_font_4:
	cmp	ah,al
	ja	load_proper_font_3
	mov	cx,bx			;use the last one that we found.
load_proper_font_3:
	add	bx,(size filename_struc)
	cmp	bx,last_filename
	jb	load_proper_font_1
	mov	bx,cx			;get the font that we found.
load_proper_font_2:

;	cmp	bx,current_file		;do we have the current file?
;	je	load_font_end_j_1	;yes - don't load it again.
;	mov	current_file,bx

	lea	si,[bx].filename_name	;get the drive, filename.
	mov	bx,offset font_subdir
	call	copy_to_filename
	mov	si,offset filename
	call	strend
	lea	di,[si-1]		;point di to the null.
	mov	si,offset dot_fnt	;and append ".fnt".
	call	strcpy

	call	open_file
	mov	si,offset not_found_msg
	jc	load_font_err		;no - flag error.
	call	get_filsz		;get file size for transfer.
	mov	di,mem_top		;transfer to top of data segment
	shl	di,1
	shl	di,1
	shl	di,1
	shl	di,1
	sub	di,cx			;minus size of file.
	mov	si,offset too_big_msg
	cmp	di,free_space		;can we fit it in?
	jb	load_font_err		;no.
	mov	disk_font,di		;save this for font address.
	mov	lo_water,di
	dec	lo_water
	call	read_file
	mov	si,offset bad_file_msg
	jc	load_font_err
	mov	si,disk_font		;get the loaded font.
	call	strend
	mov	ax,[si].ascent		;get the size of the font.
	mov	font_size_list,ax
	jmp	short load_font_3
load_font_err:
	call	error_alert
	mov	disk_font,0
load_font_3:
	call	close_file
	ret


	public	check_free_space
check_free_space:
;check to see if we have just run over the font.
	push	ax
	mov	ax,free_space		;did we just trash the font?
	cmp	ax,disk_font
	jb	check_free_space_1	;no.
	mov	disk_font,0		;yes - "unload" the font.
check_free_space_1:
	pop	ax
	ret


search_font:
;enter with si->new font name, es=ds.
;exit with nc, dl=menu entry number if found, cy if not found,
;  si->font name.
;preserve di.
	push	di
	mov	bx,si			;save a copy of the source name.
	mov	di,offset new_font_menu
	mov	dl,2
search_font_1:
	cmp	[di].b,-1		;is this the end?
	stc				;prepare to return unsuccessfully.
	je	search_font_2
	add	di,(size pulls_struc)	;skip the pull down struc.
	mov	si,bx			;get the source back.
search_font_4:
	cmpsb				;are the strings equal?
	jne	search_font_3		;no - can't possibly match.
	cmp	[si-1].b,0		;did we just match the null?
	jne	search_font_4		;no - continue.
	clc				;say that we found it.
	jmp	short search_font_2
search_font_3:
	inc	dl			;count up a menu.
	dec	di			;since we compared at least one char,
	mov	cx,65535		;any sufficiently large count would do.
	xor	al,al			;search for the null that we know is there.
	repne	scasb
	jmp	search_font_1		;keep searching in all menus.
search_font_2:
	mov	si,bx			;exit with si->font name.
	pop	di
	ret


append_font:
;enter with si->name to store (null terminated.), es=ds.
;exit with dl=new entry number.
;preserve di.
	push	di
	push	si
	mov	si,offset new_font_menu
	mov	dl,2
append_font_1:
	cmp	[si].b,-1		;is this the end?
	je	append_font_2
	add	si,(size pulls_struc)	;skip the pull down struc.
	inc	dl
	call	strend
	jmp	append_font_1		;keep going to the end.
append_font_2:
	mov	di,si
	pop	si			;si->their new name.
	xor	al,al
	mov	[di].pulls_disabled,al
	mov	[di].pulls_check,al
	mov	[di].pulls_keybd,al
	mov	[di].pulls_style,al
	add	di,(size pulls_struc)
	call	strcpy
	mov	[di].b,-1		;store the terminating -1.
	pop	di
	ret


	public	font_exists
font_exists:
;return nc if the font given in dl actually exists.
	push	bx
	push	dx
	mov	bx,offset filenames	;look at all the files.
	call	read_font_number
	mov	dh,al			;get the current font number.
font_exists_1:
	cmp	bx,last_filename	;are there any fonts?
	jae	font_exists_4		;no - say that we didn't find it.
	cmp	dh,[bx].filename_font	;is it in this menu?
	jne	font_exists_3		;no - try another.
	cmp	dl,[bx].filename_size	;is it the size we're looking for?
	clc				;prepare to return successfully.
	je	font_exists_2		;yes - we found it !!!
font_exists_3:
	add	bx,(size filename_struc)
	jmp	font_exists_1
font_exists_4:
	stc				;say that we couldn't find it.
font_exists_2:
	pop	dx
	pop	bx
	ret


	public	read_font_count
read_font_count:
	mov	al,font_count
	ret


	public	printer_init
printer_init:
;save our stack in preperation for printing.
;  *we* always return nc, but if we get a fatal error, it returns cy.
	mov	save_stack,sp
	call	bx
	clc
	ret


device_header	struc
device_next	dd	?
device_attr	dw	?
device_strategy	dw	?
device_intr	dw	?
device_name	db	'        '
device_header	ends

	public	fatal_error
fatal_error:
	or	ah,ah			;block mode or (character mode or FAT err)?
	jns	fatal_error_0		;go if block mode.
	push	ds
	mov	ds,bp
	test	[si].device_attr,8000h	;is this a character device?
	pop	ds
	jz	fatal_error_0		;go if not a character device.
	cmp	di,2			;always retry "drive not ready" errors.
	je	fatal_error_2
	cmp	di,0ah			;always retry write fault errors.
	je	fatal_error_2
	mov	bx,offset char_err_msg
	jmp	short fatal_error_3
fatal_error_0:
	mov	bx,offset fatal_err_msg
fatal_error_3:
	mov	ds,our_data
	mov	ss,our_data
	mov     sp,save_stack
	sti
	cld
	add	al,'A'
	mov	write_prot_drive,al
	mov	no_disk_drive,al
	mov	fatal_err_drive,al
	mov	ah,2ah			;get the date to stablize dos.
	int	21h
	mov     si,offset write_prot_msg
	cmp     di,0
	je      fatal_error_1
	mov	si,offset no_disk_msg
	cmp	di,2
	je	fatal_error_1
	mov	si,bx
fatal_error_1:
	call	error_alert
	stc				;return cy.
	ret
fatal_error_2:
	mov	al,1			;retry
	iret


find_first:
;find the files named in [dx], with attributes in cx.
;return cy if there are no files.
	push	dx
	mov	dx,offset find_buf	;set dta to the buffer.
	mov	ah,1ah			;dosf_sdioa
	int	21h
	pop	dx

	mov	ah,4eh			;find_first
	int	21h
	ret


find_next:
;return cy if there are no more files.
	mov	dx,offset find_buf	;set dta to the buffer.
	mov	ah,1ah			;dosf_sdioa
	int	21h

	mov	ah,4fh
	int	21h
	ret


copy_to_filename:
;enter with si->filename to place into 'filename', bx->subdirectory name.
;  If bx=0, then we use the current subdirectory.
	push	di

	push	ds
	pop	es
	mov	di,offset filename
	push	si

	or	bx,bx
	je	copy_to_filename_1
	mov	si,offset current_dir
	call	strcpy
	dec	di			;point di to the null.
	mov	si,bx
	call	strcpy
	dec	di			;point di to the null.
	jmp	short copy_to_filename_2
copy_to_filename_1:
	mov	al,'\'			;it's an absolute path name.
	stosb
	mov	ah,47h			;get the current subdirectory.
	mov	si,di
	mov	dl,0			;default drive.
	int	21h
	mov	si,di			;find the end of the string.
	call	strend
	lea	di,[si-1]		;point di to the null.
copy_to_filename_2:
	cmp	[di-1].b,'\'		;make sure that it ends in a null.
	je	copy_to_filename_3
	cmp	[di-1].b,'/'
	je	copy_to_filename_3
	mov	al,'\'
	stosb
copy_to_filename_3:
	pop	si
	call	strcpy			;copy their name in.
	pop	di
	ret


parse_name:
;enter with si->image filename to parse.
;return with cy if it's not a good image filename (i.e. we don't have a .LDI for it).
	push	ds
	pop	es
	push	si

;skip to the extension.
parse_name_2:
	lodsb
	cmp	al,'.'			;if we hit dot, we're done.
	je	parse_name_3
	or	al,al			;if there is no dot, give an error.
	jne	parse_name_2
	mov	si,offset img_list	;default to ".ipa".
parse_name_3:
	cmp	[si+2].b,0		;correct for two character extensions.
	je	parse_name_dot
	mov	di,offset xxx_dot_ldi	;make up the .ldi filename.
	movsw
	movsb
	mov	si,offset xxx_dot_ldi
	jmp	short parse_name_ldi
parse_name_dot:
	mov	di,offset xx_dot_ldi	;make up the .ldi filename.
	movsw
	mov	si,offset xx_dot_ldi
parse_name_ldi:

	mov	bx,offset bin_subdir
	call	copy_to_filename

	mov	ldi_version,0		;kill the version word.

	call	open_file		;try to open the .LDI file.
	jc	parse_name_1		;go if we don't have a loader...

	call	get_filsz		;load cx with the size of the file.

	push	cs			;load the whole thing in.
	pop	es
	mov	di,offset image_code
	call	read_file

	call	close_file

	cmp	ldi_version,'L0'	;did we really load something?
	je	parse_name_4		;yes, okay.
	cmp	ldi_version,'L1'	;did we load a newer version driver?
	jne	parse_name_1		;no - give up.
parse_name_4:

	pop	si			;parse the name again.
	mov	di,offset filename
	call	strcpy
	clc
	ret
parse_name_1:
	mov	si,offset not_found_msg
	call	error_alert
	pop	si
	stc
	ret


open_file:
;enter with 'filename' containing file to open.
;exit with nc if the file exists.
	call	waiting_shape
	mov	dx,offset filename
	mov	ax,3d00h		;open for reading.
	int	21h
	pushf
	push	ax			;preserve the found/not found indication.
	push	si
	push	di

	push	ds
	pop	es

	mov	si,offset filename
open_file_1:
	mov	di,offset not_found_msg
open_file_2:
	lodsb				;get a character.
	cmp	al,':'			;if it's a delimiter, then restart.
	je	open_file_1
	cmp	al,'\'
	je	open_file_1
	cmp	al,'/'
	je	open_file_1
	stosb				;otherwise store it until we get a null.
	or	al,al
	jne	open_file_2

	dec	di			;and append " not found!".
	mov	si,offset no_exist_msg
	call	strcpy

	pop	di
	pop	si
	pop	ax
	popf

	mov	handle,ax
	mov	buffer_ptr,offset buffer
	mov	buffer_contents,0	;amount of data in buffer.
	mov	read_not_write,1	;remember that we're reading.
	ret


create_file:
;enter with 'filename' holding the name of the file to create.
;exit with cy if the file wasn't created.
	call	waiting_shape
	mov	dx,offset filename
	mov	cx,0			;no special attributes.
	mov	ah,3ch			;create
	int	21h
	jnc	create_file_1		;if no error then skip ahead.
	mov	si,offset dir_full_msg
	call	error_alert		;flag the error.
	stc
	ret
create_file_1:
	mov	handle,ax
	mov	buffer_ptr,offset buffer
	mov	buffer_contents,0	;amount of data in buffer.
	mov	read_not_write,0	;say that we're writing.
	clc
	ret

report_error:
	pop	si			;get our return address
	push	ds
	pop	es
	mov	di,offset error_msg
report_error_1:
	lods	cs:byte ptr 0
	stosb
	or	al,al
	jne	report_error_1
	push	si			;restore our return address
	push	bp
	mov	si,offset error_msg
	call	error_alert
	pop	bp
	ret

get_filsz:
;get the size of the current file.
	mov	ax,4202h		;find the size of the file.
	mov	bx,handle
	xor	dx,dx
	xor	cx,cx
	int	21h			;seek to the end.
	push	ax			;save the low word.
	mov	ax,4200h		;find the size of the file.
	xor	dx,dx
	xor	cx,cx
	int	21h
	pop	cx			;return the size of the file.
	ret


skip_bytes:
;enter with dx = number of bytes to skip.
;exit with cy if there were any problems.
	mov	ax,4200h		;seek to the place that they want to skip.
	mov	bx,handle
	xor	cx,cx
	int	21h
	ret


read_eof:
;exit with cy if eof, nc if more to read.
	cmp	buffer_contents,0	;anything in the buffer?
	clc
	jne	read_eof_1		;yes--can't be eof.
	call	read_buffer		;try to refill the buffer.
	cmp	buffer_contents,0	;anything now?
	clc
	jne	read_eof_1		;yes--not eof.
	stc				;uh-oh, we didn't read anything--eof.
read_eof_1:
	ret


read_file:
;enter with es:di -> transfer address, cx=number of bytes to read.
;exit with cy if the file wasn't big enough.
	push	cx
	push	dx
	push	si
	mov	dx,cx			;save the count here.
read_file_1:
	mov	cx,buffer_contents	;how much is in the buffer?
	or	cx,cx
	jne	read_file_4
	call	read_buffer		;if nothing in buffer then fill it.
	mov	cx,buffer_contents	;how much is in the buffer?
	stc				;if we didn't read anything, we hit
	jcxz	read_file_3		;  eof prematurely.
read_file_4:
	cmp	cx,dx			;do we want to read more?
	jbe	read_file_2		;no.
	mov	cx,dx			;yes.
read_file_2:
	mov	si,buffer_ptr		;find out where we are in the buffer.
	push	cx
	rep	movsb			;move all that we can.
	pop	cx
	mov	buffer_ptr,si
	sub	buffer_contents,cx	;remember how many are left.
	sub	dx,cx			;now subtract off all that we read.
	ja	read_file_1		;do we have more to read? go if yes.
	clc
read_file_3:
	pop	si
	pop	dx
	pop	cx
	ret


seek_file:
	mov	ax,4200h		;seek from the beginning of the file.
	mov	bx,handle
	int	21h
	mov	buffer_contents,0	;force a read.
	ret


read_buffer:
;reload the buffer.
	push	bx
	push	cx
	push	dx
	mov	dx,offset buffer
	mov	cx,buffer_size
	mov	bx,handle
	mov	ah,3fh
	int	21h
	mov	buffer_ptr,offset buffer
	mov	buffer_contents,ax
	pop	dx
	pop	cx
	pop	bx
	ret


write_file:
;enter with es:si -> transfer address, cx=number of bytes to write.
;exit with cy if the disk gets filled.
	push	cx
	push	dx
	push	di
	mov	dx,cx			;save the count here.
write_file_1:
	mov	cx,buffer_size		;how much room is left in the buffer?
	sub	cx,buffer_contents
	cmp	cx,dx			;do we want to write more than will fit?
	jbe	write_file_2		;yes.
	mov	cx,dx			;no.
write_file_2:
	mov	di,buffer_ptr		;find out where we are in the buffer.
	push	cx
	push	ds			;swap es and ds.
	push	es
	pop	ds
	pop	es
	rep	movsb			;move all that we can.
	push	ds			;swap es and ds.
	push	es
	pop	ds
	pop	es
	pop	cx
	mov	buffer_ptr,di
	add	buffer_contents,cx	;remember how many are left.
	cmp	buffer_contents,buffer_size	;is the buffer full?
	jne	write_file_3		;not yet.
	call	write_buffer		;empty the buffer out.
	jz	write_file_3		;keep going if we succeeded.

	mov	si,offset disk_full_msg	;give an error message.
	push	bp
	call	error_alert		;flag the error.
	pop	bp
	call	close_file
	mov	dx,offset filename	;delete the file.
	mov	ah,41h
	int	21h
	stc
	jmp	write_file_4		;exit now if we filled the disk.
write_file_3:
	sub	dx,cx			;now subtract off all that we write.
	ja	write_file_1		;do we have more to write? go if yes.
	clc				;say that we wrote the whole thing.
write_file_4:
	pop	di
	pop	dx
	pop	cx
	ret



write_buffer:
;enter with buffer_contents=number of bytes to write.
;return nz if we failed to write the whole thing.
;preserve bx,cx,dx.
	push	bx
	push	cx
	push	dx
	mov	dx,offset buffer	;write out everything in the buffer.
	mov	cx,buffer_contents
	mov	bx,handle
	mov	ah,40h
	int	21h
	cmp	ax,buffer_contents	;see if we managed to write the whole thing.
	mov	buffer_ptr,offset buffer
	mov	buffer_contents,0
	pop	dx
	pop	cx
	pop	bx
	ret


close_file:
	cmp	read_not_write,0	;are we only reading?
	jne	close_file_1		;yes.
	call	write_buffer		;no - empty the buffer.
	je	close_file_1		;go if buffer emptied.
	mov	si,offset disk_full_msg
	push	bp
	call	error_alert		;flag the error.
	pop	bp
	mov	bx,handle		;close the file.
	mov	ah,3eh
	int	21h
	mov	dx,offset filename	;delete the file.
	mov	ah,41h
	int	21h
	ret
close_file_1:
	mov	bx,handle		;close the file.
	mov	ah,3eh
	int	21h
	ret


code	ends

	end
