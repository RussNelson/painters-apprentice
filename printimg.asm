code	segment	public
	assume	cs:code, ds:code

	include	paint.def
	include	findfile.inc

CR	equ	0dh
LF	equ	0ah

	org	2ch
phd_env	label	word

	org	80h
phd_dioa	label	byte

	org	100h
start:
	jmp	start_1
;
;
	jmp	print_get_byte	;103h
	jmp	print_abort	;106h
	jmp	print_print	;109h
;
program_size	equ	1024
program		label	byte
program_id	dw	?
program_margins	dw	?,?
program_label	label	near
		db	program_size-($-program) dup(?)

disk_full_msg	db	'Disk Full!',0
no_print_msg	db	'Can',"'",'t find paint.pri.',0
not_found_msg	db	' not found!',0
usage_msg	db	'PrintImg - print a Painter',"'",'s Apprentice image file using PAINT.PRI.',CR,LF
		db	'Copyright 1988, Russell Nelson.  Version 2.0',CR,LF
		db	CR,LF
		db	'usage: printimg image-name [output-name]',CR,LF
		db	0

prn_name	db	'prn',0

printer_title_msg	label	byte
		db	'Printer is: '
printer_title		label	byte
		db	30 dup(?)		;leave room for the printer name.


program_msg	db	'Bad program file!',0
memory_msg	db	'Not enough memory!',0
press_x_msg	db	'Press Escape to abort the print.',0
dir_full_msg	db	'Directory Full!',0
no_exist_msg	db	' not found!',0

page_seg	dw	?

	db	128 dup(?)
stack	label	byte

parse_pointer	dw	?
char_buffer	db	?

program_name	db	'paint.pri',0

buffer_size	equ	1024
buffer		db	buffer_size dup(?)
buffer_ptr	dw	?		;->next byte to transfer.
buffer_contents	dw	?		;=number of bytes in buffer.
read_not_write	db	?		;=1 if reading, =0 if writing.

error_msg	db	40 dup(?)

current_dir	db	64+2 dup(?)		;base subdir for pa files.

paint_env_str	db	"PAINT="
paint_env_len	equ	$-paint_env_str

paint_dir_str	db	"\paint",0

find_buf	find_buf_struc<>

byte_buffer	label	byte
word_buffer	dw	?

bin_subdir	db	'bin',0

handle		dw	?
filename	db	64 dup(?)
current_filename	db	64 dup(?)

wind_on_page	point	<>

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

argv		dw	10 dup(?)	;pointers to arguments.
argv_end	label	word

start_2:
	mov	si,offset memory_msg
	call	error_alert
	int	20h			;not enough memory.
start_1:
	mov	bx,cs			;get start of code.
	cli
	mov	ss,bx			;set stack segment to same as ds.
	mov	sp,offset stack		;set stack pointer to our stack area.
	sti
	mov	ax,offset code_size+0fh	;reserve space for data segment.
	shr	ax,1
	shr	ax,1
	shr	ax,1
	shr	ax,1
	add	ax,bx
	mov	page_seg,ax		;compute the page segment.
	add	ax,1000h		;assume 64K page.
	cmp	ax,cs:[2]		;do we have enough memory?
	ja	start_2			;no - crap out.

	call	load_pri

	cmp	program_id,'P' + '1'*256		;is there a program?
	jae	print_cmd_0		;yes.
	mov	si,offset no_print_msg	;no - flag the error.
	call	error_alert
	int	20h
print_cmd_0:
	mov	si,offset program_label	;see if this printer driver has a title.
	cmp	byte ptr [si],0ebh	;is this a short jump?
	jne	print_cmd_4
	add	si,2			;the title starts here.
	mov	di,offset printer_title	;copy the title in here.
	call	strcpy
	mov	byte ptr [di-1],CR	;terminate the message.
	mov	al,LF
	stosb
	xor	al,al
	stosb
	mov	si,offset printer_title_msg
	call	error_alert
print_cmd_4:

	call	setargv

	mov	si,argv[0]
	call	load_file
	jc	print_cmd_1

	mov	si,argv[2]
	or	si,si
	jne	print_cmd_5
	mov	si,offset prn_name
print_cmd_5:
	xor	bx,bx
	call	copy_to_filename
	call	create_file
	jc	print_cmd_1

	mov	si,offset press_x_msg
	call	error_alert
	call	program_label
	call	close_file
print_cmd_1:
	int	20h
start_6:
	mov	si,offset usage_msg
	call	error_alert
	int	20h


setargv:
	mov	si,offset phd_dioa
	mov	di,offset argv		;parse the arguments here.
	push	ds
	pop	es
setargv_1:
	inc	si
	mov	al,[si]
setargv_5:
	cmp	al,' '			;remove leading blanks.
	je	setargv_1
	cmp	al,9			;remove leading tabs.
	je	setargv_1
	cmp	al,','			;remove leading commas.
	je	setargv_1
	cmp	al,13			;empty line?
	je	setargv_2		;yes - give the usage message.
	mov	ax,si			;store this one in argv[].
	stosw
setargv_3:
	mov	al,[si]
	cmp	al,' '			;quit on space, tab, or cr.
	je	setargv_4
	cmp	al,9
	je	setargv_4
	cmp	al,13
	je	setargv_4
	inc	si			;otherwise go to the next char.
	jmp	setargv_3
setargv_4:
	mov	[si].b,0		;store the trailing null.
	jmp	setargv_5		;and do another argument.
setargv_2:
	mov	cx,offset argv_end	;now null fill to the end.
	sub	cx,di
	xor	al,al
	rep	stosb
	ret


load_pri:
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
load_pri_3:
	ret
load_pri_1:
	mov	si,offset program_msg
	call	error_alert
load_pri_2:
	mov	program_id,0
	stc
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


get_current:
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


strcpy:
	push	ds
	pop	es
strcpy_1:
	lodsb
	stosb
	or	al,al
	jne	strcpy_1
	ret


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


directions	label	word
	dw	move_up
	dw	move_down
	dw	move_left
	dw	move_right


print_get_byte:
;enter with cx,dx=starting point, bx=direction to run in.
	push	cx
	push	dx

	cmp	bx,3
	ja	print_get_byte_3
	shl	bx,1
	mov	bp,directions[bx]

	mov	bx,cx
	shr	bx,1
	shr	bx,1
	shr	bx,1

	mov	ax,dx
	shl	ax,1
	shl	ax,1
	shl	ax,1
	shl	ax,1
	add	bx,ax
	shl	ax,1
	shl	ax,1
	add	bx,ax

	and	cx,7
	mov	dl,80h
	shr	dl,cl

	mov	cx,8
	mov	ax,0
	push	ds
	mov	ds,page_seg
print_get_byte_1:
	test	[bx],dl
	jne	print_get_byte_2
	inc	al
print_get_byte_2:
	ror	al,1
	jmp	bp
move_left:
	rol	dl,1
	jnc	print_get_byte_4
	dec	bx
	jmp	short print_get_byte_4
move_right:
	ror	dl,1
	jnc	print_get_byte_4
	inc	bx
	jmp	short print_get_byte_4
move_up:
	sub	bx,80
	jmp	short print_get_byte_4
move_down:
	add	bx,80
print_get_byte_4:
	loop	print_get_byte_1
	pop	ds
print_get_byte_3:
	pop	dx
	pop	cx
	ret


print_abort:
;exit with cy=abort, nc=no abort.
;preserve cx,dx
	push	cx
	push	dx
	mov	ah,6			;check for key.
	mov	dl,0ffh
	int	21h
	clc
	je	print_abort_1		;go if no key.
	cmp	al,'['-40h
	clc
	jne	print_abort_1		;go if not ^X.
	stc
print_abort_1:
	pop	dx
	pop	cx
	ret


load_file:
;enter with si->file to read.
	call	set_current_file
	call	parse_name
	jc	load_file_no_ldi
	call	open_file
	jnc	load_file_exist

	mov	si,offset not_found_msg
	call	error_alert
	stc
	ret
load_file_no_ldi:
	ret
load_file_exist:
	call	load_using_ldi
	jc	read_error
	call	close_file
	ret
read_error:
	call	close_file
	stc
	ret


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


print_print:
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
	jne	parse_name_1		;no - give up.

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
	mov	si,offset error_msg
	call	error_alert
	stc
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


error_alert:
alert:
	lodsb
	or	al,al
	je	alert_1
	mov	dl,al
	mov	ah,2
	int	21h
	jmp	alert
alert_1:
	ret


code_size	equ	$

code	ends

	end	start

