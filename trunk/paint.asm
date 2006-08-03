;paint.asm - Main Program
;History:692,1
;Fri Jul 27 08:07:08 1990 move waiting_shape call to *before* init.
;Fri Apr 27 21:16:35 1990 add a message explaining why about.scr wasn't found.
;Fri Apr 27 21:04:59 1990 don't protect_rect for get_screen -- it does itself.
;Fri Apr 27 20:41:15 1990 get rid of the not_bug ifdef.
;Thu Nov 17 22:57:35 1988 display the about screen at startup.
;Wed Nov 16 23:40:50 1988 change the order of wait_for_full_click and do_key.
;Fri Nov 11 23:06:46 1988 add a check for printer ready.
;Fri Nov 11 12:20:57 1988 add screen_color.
;10-28-88 23:41:58 check for font files also.
;08-14-88 11:09:07 Allow printer drivers with a P2 signature.
;08-14-88 11:03:48 if no printer driver, disable Margin.
;08-07-88 23:01:36 after shelling to dos, reload paint.pri and find .ldi files again.
;
;06-16-88 23:57:02 Add About... menu item.
;06-16-88 21:12:18 use screen_seg in show_rect.
;06-16-88 20:48:27 define screen_segm
;06-16-88 00:03:47 remove font_list ifdef.
;05-11-88 22:17:45 reduce the double click time to 1/4 second.
;04-30-88 02:02:06 If they press a key while reading the intro, do it.
;03-31-88 22:45:43 reduce the number of patterns and move them to the left a bit.
;03-15-88 22:16:22 use a menu rectangle as a pattern box.
;03-15-88 21:59:48 don't make a rect bigger before filling it!
;02-07-88 13:23:58 put the filename into the pull down bar.

	include	paintflg.asm

code	segment	public
code	ends

data	segment	public

	include	paint.def

screen_right	equ	640
screen_bot	equ	350
page_lines	equ	792
page_bytes	equ	80
page_size	equ	page_lines*page_bytes

h_pull_down	equ	2
h_above_window	equ	5		;was 5
h_window_header	equ	0		;was 17

h_one_menu	equ	18

h_below_window	equ	31

window_y	equ	h_pull_down+h_above_window+h_window_header

height_window	equ	screen_bot-window_y-h_below_window

	public	h_window
h_window	dw	height_window

num_patterns	equ	36
num_pats_in_x	equ	6
num_pats_in_y	equ	(num_patterns + num_pats_in_x - 1) / num_pats_in_x

w_one_pattern	equ	25
h_one_pattern	equ	16

pats_top	equ	window_y + height_window - num_pats_in_y*h_one_pattern - 1
pats_left	equ	window_x + w_window - w_one_pattern*num_pats_in_x - 1
pats_bot	equ	window_y + height_window
pats_right	equ	window_x + w_window - 1

num_menus	equ	18
pattern_menu	equ	num_menus
w_one_menu	equ	32
w_left_menu	equ	(screen_right - (num_menus + 1) * w_one_menu) / 3

pattern_menu_x	equ	w_left_menu + num_menus * w_one_menu + w_left_menu

menu_x	equ	window_x
menu_y	equ	screen_bot - h_below_window + (h_below_window - h_one_menu)/2
num_menus_x	equ	18
pattern_rect	rect	<pattern_menu_x, menu_y, pattern_menu_x + w_one_menu, menu_y + h_one_menu>

;make sure that the window begins on a byte boundary.
window_to_left	equ	0
window_x	equ	(window_to_left+7) and 0fff8h
w_left_window	equ	window_x-window_to_left

;make sure that the window ends on a byte boundary.
w_window	equ	(screen_right);was-window_x-1) and 0fff8h;was 9
w_right_window	equ	screen_right-window_x-w_window

	public	wind_bytes		;paints
wind_bytes	dw	w_window/8

	public	max_wind_bytes		;paintdio
max_wind_bytes	dw	w_window/8

	public	screen, screen_mouse
screen	rect	<0, 0, screen_right, screen_bot>
screen_9	rect	<0,0, screen_right, 25*16>
screen_mouse	rect	<0,0, screen_right - w_right_window/2, screen_bot-2+16>


	public	max_window
max_window	rect	<window_x, window_y, window_x+w_window, window_y+height_window>

	public	draw_window
draw_window	rect	<window_x, window_y, window_x+w_window, window_y+height_window>

	public	center_window
center_window	point	<>

	public	wind_pull
wind_pull	rect	<0, 0, screen_right, h_pull_down>

num_pens	equ	8*4
brush_rect	rect	<100, window_y+20, 100+40+((num_pens/4)*22), window_y+130>
first_pen_rect	rect	<100+10, window_y+20+10, 100+10+22, window_y+20+10+22>

num_drives	equ	3*3
d_size		equ	32
drive_rect	rect	<100, window_y+10, 100+10+3*d_size+10, window_y+10+d_size+3*d_size+10>
first_drv_rect	rect	<100+10, window_y+10+d_size, 100+10+d_size, window_y+10+d_size+d_size>
cd_title_rect	rect	<100, window_y+10, 100+10+3*d_size+10, window_y+10+d_size>
cd_title_msg	db	'Select Drive',0
temp_drive	db	2 dup(0)

header_x	equ	window_x
header_y	equ	h_pull_down+h_above_window

  if h_window_header
header_rect	rect	<header_x  , header_y  , header_x+w_window  , header_y+h_window_header-1>
  endif

wind1	rect	<>
wind2	rect	<>

line_rect	rect	<>
	public	select_rect
select_rect	rect<>

first_menu_rect	rect	<w_left_menu, menu_y, w_left_menu+w_one_menu, menu_y+h_one_menu>

first_pat_rect	rect	<pats_left, pats_top, pats_left + w_one_pattern, pats_top + h_one_pattern>

all_pats_rect	rect	<pats_left, pats_top, pats_right, pats_bot>

	public	line_width
line_width	dw	0		;one bit pen.

	public	free_space
free_space	dw	?		;->space that's free to use.

	public	clip_rect
clip_rect	dw	screen		;->rectangle to clip brushes to.

page_line_count		dw	?

screen_line_count	dw	?

	public	page_rect
page_rect	rect<0, 0, page_bytes*8, page_lines>

	public	page_bitmap
page_bitmap	rect<>
	public	page_seg
page_seg	equ	this word + pntr1
		bitmap_trailer<page_bytes>

	public	fatbits_window
fatbits_window	rect<window_x, window_y, window_x+(w_window/8)-1, window_y+(height_window/8)>
		bitmap_trailer<screen_bytes, 0, 0>

middle_x	equ	screen_right/2
middle_y	equ	screen_bot/2

show_frame	rect<middle_x-120, 0, middle_x+120+50, screen_bot>
show_rect	rect<middle_x-120+5, 5, middle_x+120-5, screen_bot-5>
		bitmap_trailer<screen_bytes, 0, 0>
show_button	rect<middle_x+120+5, middle_y-8, middle_x+120+50-5, middle_y+8>

edge	equ	5+16

w_edit	equ	edge+1+64+1+16+1+64+1+edge
h_edit	equ	edge+1+64+1+16+1+16+1+edge
edit_x	equ	middle_x-w_edit/2
edit_y	equ	middle_y-h_edit/2

	public	edit_rect
edit_rect	rect<edit_x, edit_y, edit_x+w_edit, edit_y+h_edit>

	public	fatedit_rect
fatedit_x	equ	edit_x+edge
fatedit_y	equ	edit_y+edge
fatedit_rect	rect<fatedit_x, fatedit_y, fatedit_x+65, fatedit_y+65>

	public	first_bit_rect
first_bit_rect	rect<fatedit_x+1, fatedit_y+1, fatedit_x+1+8, fatedit_y+1+8>

	public	paint_frame, paint_rect
paint_x		equ	fatedit_x+65+16
paint_frame	rect<paint_x, fatedit_y, paint_x+65, fatedit_y+65>
paint_rect	rect<paint_x+1, fatedit_y+1, paint_x+65-1, fatedit_y+65-1>

mirror_rect	rect<edit_x, edit_y, edit_x+w_edit, edit_y+h_edit>
mirror_box	rect<fatedit_x, fatedit_y, fatedit_x+65-1, fatedit_y+65-1>

	public	cancel_rect_2		;for paintlan
print_rect	rect<middle_x-40,middle_y-20,middle_x+40,middle_y+20>
cancel_rect_2	rect<middle_x-32,middle_y-8,middle_x+32,middle_y+8>

	public	ok_rect, cancel_rect, cancel_rect_1
ok_rect		rect<fatedit_x, fatedit_y+65+16, fatedit_x+65, fatedit_y+65+16+16>
cancel_rect	rect<fatedit_x+65+16, fatedit_y+65+16, fatedit_x+65+16+65, fatedit_y+65+16+16>
cancel_rect_1	rect	<window_x+w_window - 100, window_y + height_window - 32, window_x + w_window - 10, window_y + height_window - 16>

	public	cancel_string, ok_string
ok_string	db	'OK',0
none_string	db	'None',0
cancel_string	db	'Cancel',0
about_name	db	'About.scr',0
intro_name	db	'Help.scr',0
short_name	db	'Quickies.scr',0


	public	changes_flag
changes_flag	db	0

quit_save_msg	db	"Quit: Save modifications?",0
quit_msg	db	"Quit: Are you sure?",0
lost_msg	db	"Discard current picture?",0
not_ready_msg	db	"Printer not ready",0
noname_msg	db	"NONAME",0
signon_msg	db	"Painter's Apprentice V1.9 - "
		db	"Russell Nelson and Patrick Naughton",0
memory_error	db	"Not enough memory",'$'
mouse_error	db	"No mouse installed",'$'
no_about_msg	label	byte
 db "You probably didn't run install, or else didn't set the environment",0dh,0ah
 db "variable PAINT to the location of PA's BIN, FONTS, and SCRAPS subdirs.",'$'

	public	pen_mirror
pen_mirror	db	0
pen_bits	db	0

	public	grid_flag
grid_flag	db	0

margins_flag	db	0

	public	fatbits_flag
fatbits_flag	db	0

	public	loaded_from_disk
loaded_from_disk	db	0

	public	down_button
down_button	db	?

	public	mem_top
mem_top		dw	0c00h		;reserve 46K for data segment.

	public	current_pen
current_pen	dw	first_pen
current_menu	dw	-1
previous_menu	dw	-1
current_shape	dw	-1

	public	fillPat, fillPat_num
fillPat		dw	0
fillPat_num	dw	0
old_fillPat_num	dw	0

	public	constrain_flag
constrain_flag	db	0		;0=none, 1=v, 2=h.
new_constrain	db	0

	public	last_click
last_click	point<8000h,8000h>

	public	menu_hook_constrain, menu_hook_cursor
	public	menu_hook_hide, menu_hook_show, menu_hook_key
first_menu_hook	label	word
count_menu_hooks	equ	8
menu_hook_poll		dw	?
menu_hook_remove	dw	?
menu_hook_hide		dw	?
menu_hook_show		dw	?
menu_hook_key		dw	?
menu_hook_button	dw	?
menu_hook_cursor	dw	?
menu_hook_constrain	dw	?

file_menu_list	label	byte
	db	"File",0		;name of menu
	pdi	0,0,0,0,Scratch
	pdi	0,0,0,0,Restore
	pdi	0,0,0,0,<Select Drive>
	pdi	0,0,0,0,<Load...>
	pdi	0,0,0,0,Save
	pdi	0,0,0,0,<Save as...>
	pdi	0,0,0,0,Print
	pdi	0,0,0,0,<About...>
	pdi	0,0,0,0,Dos
	pdi	0,0,0,0,Quit
	db	-1

edit_menu_list	label	byte
	db	"Edit",0		;name of menu
	pdi	0,0,'Z',0,Undo
	pdi	1,0,0,0,< >
	pdi	1,0,'X',0,Cut
	pdi	1,0,'D',0,Copy
	pdi	0,0,'V',0,Paste
	pdi	1,0,0,0,Clear
	pdi	1,0,0,0,< >
	pdi	1,0,0,0,Invert
	pdi	1,0,0,0,Fill
	pdi	1,0,'E',0,<Outline>
	pdi	1,0,0,0,<Flip Horizontal>
	pdi	1,0,0,0,<Flip Vertical>
	pdi	1,0,0,0,Rotate
	db	-1

goodies_menu_list	label	byte
	db	"Assist",0		;name of menu
	pdi	0,0,0,0,<Grid>
	pdi	0,0,0,0,<Magnify>
	pdi	0,0,0,0,<Preview Page>
	pdi	0,0,0,0,<Edit Pattern>
	pdi	0,0,0,0,<Brush Shape>
	pdi	0,0,0,0,<Brush Mirrors>
	pdi	0,0,0,0,<Margins>
	pdi	0,0,0,0,<Clear Window>
	pdi	0,0,0,0,<Help>
	pdi	0,0,0,0,<Quickies>
	db	-1

	extrn	font_menu_list: byte

fontsize_menu_list	label	byte
	db	"FontSize",0		;name of menu
	pdi	0,0,0,OUTLINE_STYLE,<Actual>
	pdi	0,0,0,0,< 9>
	pdi	0,0,0,0,<10>
	pdi	0,0,0,0,<12>
	pdi	0,0,0,0,<14>
	pdi	0,0,0,0,<18>
	pdi	0,0,0,0,<24>
	pdi	0,0,0,0,<36>
	pdi	0,0,0,0,<48>
	pdi	0,0,0,0,<72>
	db	-1

style_menu_list	label	byte
	db	"Style",0		;name of menu
	pdi	0,80h,'P',0,Plain
	pdi	0,0,'B',BOLD_STYLE,Bold
	pdi	0,0,'I',ITALIC_STYLE,Italic
	pdi	0,0,'U',UNDERLINE_STYLE,Underline
	pdi	0,0,'O',OUTLINE_STYLE,Outline
	pdi	0,0,'S',SHADOW_STYLE,Shadow
	pdi	0,0,'N',COMP_STYLE,Narrow
	pdi	1,0,0,0,< >
	pdi	0,80h,'L',0,<Align Left>
	pdi	0,0,'C',0,<Align Center>
	pdi	0,0,'R',0,<Align Right>
	db	-1


lineWidth_menu_list	label	byte
	db	"LineWidth",0		;name of menu
	pulls_struc<0,80h,0,COMP_STYLE>
	db	83h,83h,83h,83h,83h,83h,83h,0
	pulls_struc<0,0,0,COMP_STYLE>
	db	84h,84h,84h,84h,84h,84h,84h,0
	pulls_struc<0,0,0,COMP_STYLE>
	db	85h,85h,85h,85h,85h,85h,85h,0
	pulls_struc<0,0,0,COMP_STYLE>
	db	86h,86h,86h,86h,86h,86h,86h,0
	db	-1


	public	pull_down_items
pull_down_items	label	word
	dw	do_file_menu
	dw	do_edit_menu
	dw	do_goodies_menu
	dw	do_fonts_menu
	dw	do_fontsize_menu
	dw	do_style_menu
	dw	do_lineWidth_menu

file_menu	label	word
	dw	new_cmd
	dw	revert_cmd
	dw	change_drive_cmd
	dw	load_cmd
	dw	save_cmd
	dw	prompt_write_file
	dw	print_cmd
	dw	about_cmd
	dw	dos_cmd
	dw	quit_cmd

edit_menu	label	word
	dw	undo_update
	dw	0
	dw	cut
	dw	copy
	dw	paste
	dw	clear
	dw	0
	dw	invert_edit
	dw	fill_edit
	dw	trace_edges_edit
	dw	flip_horizontal_edit
	dw	flip_vertical_edit
	dw	rotate_edit

goodies_menu	label	word
	dw	grid_goodies
	dw	fatbits_goodies
	dw	show_page_goodies
	dw	edit_pattern_goodies
	dw	brush_shape_goodies
	dw	brush_mirrors_goodies
	dw	margins_goodies
	dw	clear_screen_goodies
	dw	introduction_goodies
	dw	shortcuts_goodies

fonts_menu	label	word
	dw	get_fonts
	dw	load_menu_font
	dw	load_font
	dw	load_font
	dw	load_font
	dw	load_font
	dw	load_font
	dw	load_font
	dw	load_font
	dw	load_font

	db	1000 dup(?)	;maximum number of bytes in queue
stack	label	byte

save_stack	dw	?
save_break	db	?

	extrn	current_filename: byte	;paintd
	extrn	pens: byte		;paintdat
	extrn	dot_pen: byte		;paintdat
	extrn	three_dot_pen: byte	;paintdat
	extrn	big_dot_pen: byte	;paintdat
	extrn	first_pen: byte		;paintdat
	extrn	pointing_cursor: word	;paintdat
	extrn	waiting_cursor: word	;paintdat
	extrn	menu_items: word	;paintdat
	extrn	pull_down_storage: byte	;paintdat
	extrn	white_pat: byte		;paintdat
	extrn	black_pat: byte		;paintdat
	extrn	gray_pat: byte		;paintdat
	extrn	patterns: byte		;paintdat
	extrn	font: byte		;paintf
	extrn	lo_water: word		;paintf
	extrn	first_pt: word		;painth
	extrn	menu_hooks: word	;painth
	extrn	alignment: byte		;painth
	extrn	put_byte_subr: word	;painti
	extrn	pen: byte		;painti
	extrn	wind_ptr: word		;paints
	extrn	wind_on_page: word	;paints
	extrn	font_size_list: word	;paintf
	extrn	mouse_color: byte	;paintmse
	extrn	screen_color: byte	;paintmse
	extrn	ldi_list: byte		;paintdio
	extrn	new_font_menu: byte	;paintdio
	extrn	this_thing: byte	;paintega

	extrn	screen_seg: word

data	ends

code	segment	public
	assume	cs:code, ds:data

	extrn	wait_for_up: near		;painth
	extrn	wait_for_down: near		;painth
	extrn	wait_for_full_click: near	;painth
	extrn	get_key: near			;painth
	extrn	time_now: word			;paintg
	extrn	load_pri: near
	extrn	frame_round: near		;paintc
	extrn	alert: near			;paintd
	extrn	last_code: byte			;paintdat
	extrn	cut: near			;paintdio
	extrn	copy: near			;paintdio
	extrn	paste: near			;paintdio
	extrn	copy_number: near		;paintdio
	extrn	paste_number: near		;paintdio
	extrn	clear: near			;paintdio
	extrn	fatal_error: near		;paintdio
	extrn	get_screen: near		;paintdio
	extrn	alert: near			;paintd
	extrn	error_alert: near		;paintd
	extrn	last_code: byte			;paintdat
	extrn	load_font: near			;paintf
	extrn	load_menu_font: near		;paintf
	extrn	get_fonts: near			;paintf
	extrn	read_font_number: near		;paintf
	extrn	read_font_count: near		;paintdio
	extrn	use_system_font: near		;paintf
	extrn	read_style: near		;paintf
	extrn	store_style: near		;paintf
	extrn	read_size: near			;paintf
	extrn	store_size: near		;paintf
	extrn	font_exists: near		;paintf
	extrn	center_string: near		;paintf
	extrn	paint_fatbits: near		;paintfat
	extrn	init_screen: near		;paintg
	extrn	uninit_screen: near		;paintg
	extrn	makepen: near			;paintg
	extrn	makepen_dot: near		;paintg
	extrn	get_select: near		;painth
	extrn	start_select: near		;painth
	extrn	update_page: near		;painth
	extrn	update_window: near		;painth
	extrn	undo_update: near		;painth
	extrn	erase_moving: near		;painth
	extrn	center_select: near		;painth
	extrn	clear_original: near		;painth
	extrn	draw_moving: near		;painth
	extrn	do_fatbits: near		;painth
	extrn	map_fatbits: near		;painth
	extrn	blit: near			;painti
	extrn	do_line: near			;painti
	extrn	put_brush: near			;painti
	extrn	make_fillPat: near		;painti
	extrn	make_fillPat_white: near	;painti
	extrn	put_rect: near			;painti
	extrn	get_rect: near			;painti
	extrn	get_flip_h: near		;painti
	extrn	get_rotate: near		;painti
;	extrn	clip_line_to_rect: near		;painti
	extrn	pset_verb: near			;painti
	extrn	preset_verb: near		;painti
	extrn	and_verb: near			;painti
	extrn	and_not_verb: near		;painti
	extrn	or_verb: near			;painti
	extrn	or_not_verb: near		;painti
	extrn	xor_verb: near			;painti
	extrn	frame_rect: near		;painti
	extrn	invert_rect: near		;painti
	extrn	fill_rect: near			;painti
	extrn	clear_rect: near		;painti
	extrn	flip_ram: near			;paintmap
	extrn	flip_crt: near			;paintmap
	extrn	flip_cpu: near			;paintmap
	extrn	flip_ok: near			;paintmap
	extrn	flip: near			;paintmap
	extrn	unflip: near			;paintmap
	extrn	protect_mouse: near		;paintmse
	extrn	unprotect_mouse: near		;paintmse
	extrn	init_mouse: near		;paintmse
	extrn	uninit_mouse: near		;paintmse
	extrn	make_mouse: near		;paintmse
	extrn	mouse_on: near			;paintmse
	extrn	mouse_off: near			;paintmse
	extrn	get_mouse: near			;paintmse
	extrn	do_pull_down: near		;paintp
	extrn	unhighlight_menu: near		;paintp
	extrn	kill_menus: near		;paintp
	extrn	append_menu: near		;paintp
	extrn	menu_key: near			;paintp
	extrn	store_check: near		;paintp
	extrn	store_disabled: near		;paintp
	extrn	store_menu_style: near		;paintp
	extrn	arctan: near			;paintr
	extrn	make_numbered_rect: near	;paintr
	extrn	pt_in_numbered: near		;paintr
	extrn	empty_rect: near		;paintr
	extrn	set_empty_rect: near		;paintr
	extrn	store_rect: near		;paintr
	extrn	restore_rect: near		;paintr
	extrn	set_rect: near			;paintr
	extrn	sect_rect: near			;paintr
	extrn	peg_rect: near			;paintr
	extrn	assign_rect: near		;paintr
	extrn	pt_in_rect: near		;paintr
	extrn	near_pt: near			;paintr
	extrn	make_rect_bigger: near		;paintr
	extrn	make_rect_smaller: near		;paintr
	extrn	inset_rect: near		;paintr
	extrn	offset_rect: near		;paintr
	extrn	prompt_write_file: near		;paints
	extrn	just_resave_file: near		;paints
	extrn	prompt_read_file: near		;paints
	extrn	just_reload_file: near		;paints
	extrn	copy_page_to_window: near	;paints
	extrn	frame_round: near		;paintc
	extrn	do_key: near			;paint?
	extrn	ring_bell: near			;paint?
	extrn	shell_to_dos: near		;painth
	extrn	edit_pattern_goodies: near	;paint1
	extrn	draw_cancel_box: near		;paint1
	extrn	printer_ready: near		;paintega
	extrn	printer_init: near		;paintdio

	org	2ch
	public	phd_env
phd_env	dw	?

	org	80h
phd_dioa	label	byte

	org	100h
start:
	jmp	start_1


	jmp	print_get_byte	;103h
	jmp	print_abort	;106h
	jmp	print_print	;109h

	public	program_size, program, program_id
program_size	equ	1024
program		label	byte
program_id	dw	?
program_margins	point	<>
program_label	label	near
		db	program_size-($-program) dup(?)

start_2:
	mov	dx,offset memory_error
	jmp	short start_4
start_3:
	mov	dx,offset mouse_error
start_4:
	mov	ah,9
	int	21h
	int	20h			;not enough memory.
screen_color_i	db	7
mouse_color_i	db	15
start_1:
	mov	ax,cs			;get start of code.
	mov	bx,offset last_code+0fh	;find out how big our code is...
	shr	bx,1			;turn
	shr	bx,1			; it
	shr	bx,1			; into
	shr	bx,1			; paragraphs.
	add	ax,bx			;add that to code segment.
	mov	ds,ax			;make that the data segment
	cli
	mov	ss,ax			;set stack segment to same as ds.
	mov	sp,offset stack		;set stack pointer to our stack area.
	sti
	add	ax,mem_top		;reserve space for data segment.
	mov	page_seg,ax		;compute the page segment.
	add	ax,1000h		;assume 64K page.
	cmp	ax,cs:[2]		;do we have enough memory?
	ja	start_2			;no - crap out.

	mov	bx,ax			;get the top of our memory
	mov	ax,es
	sub	bx,ax			;compute the new size.
	mov	ah,4ah			;modify allocated memory size.
	int	21h

	push	ds			;get the mouse's interrupt segment.
	xor	ax,ax
	mov	ds,ax
	mov	ax,ds:[33h*4+2]
	pop	ds
	or	ax,ax			;is it zero?
	je	start_3			;yes - no mouse.
	cmp	ax,40h			;is it in the bios?
	je	start_3
	mov	ax,0			;reset the mouse.
	int	33h
	cmp	ax,0			;is the mouse there?
	je	start_3			;no - abort.
	cld
	mov	wind_ptr,(window_x shr 3) + (window_y*screen_bytes)

	mov	free_space,offset pull_down_storage+height_window*(w_window/8)

	mov	dx,mem_top
	shl	dx,1			;change from
	shl	dx,1			; paragraphs
	shl	dx,1			;     to
	shl	dx,1			;   bytes.
	mov	lo_water,dx		;set lo_water mark

	call	waiting_shape

	call	init
	mov	al,mouse_color_i	;init the mouse color.
	mov	mouse_color,al
	mov	al,screen_color_i	;init the mouse color.
	mov	screen_color,al

	mov	ax,0
	call	select_new_pattern

	mov	ax,6
	call	select_new_menu

	mov	put_byte_subr,offset pset_verb
	push	clip_rect
	mov	clip_rect,offset screen

	mov	si,offset about_name
	call	get_screen		;now try to read it off the disk.
	jc	start_9			;can't read it -- quit.

	pop	clip_rect

	call	draw_cancel_box

	call	get_fonts

	mov	si,offset phd_dioa
start_5:
	inc	si
	mov	al,cs:[si]
	cmp	al,' '			;remove leading blanks.
	je	start_5
	cmp	al,9			;remove leading tabs.
	je	start_5
	cmp	al,13			;empty line?
	je	start_6			;yes - just paint.
	mov	di,offset current_filename	;no - get the name and try to load it.
	push	ds
	pop	es
start_7:
	mov	al,cs:[si]
	inc	si
	stosb
	cmp	al,13
	jne	start_7
	mov	[di-1].b,0		;store the trailing null.
	call	resize_window		;now paint the window.
	call	just_reload_file	;no - try to load that file.
	jmp	short start_8
start_6:
	mov	free_space,offset pull_down_storage
	mov	bx,offset cancel_rect_1	;now wait for them to look 
	call	wait_for_full_click
	pushf
	push	ax
	call	wait_for_up
	call	resize_window		;now paint the window.
	call	new_cmd
	pop	ax
	popf
	jc	start_8			;if they had pressed a key, do it.
	call	do_key
start_8:

	mov	free_space,offset pull_down_storage

	call	paint
	call	uninit
	int	20h

start_9:
	call	uninit
	mov	dx,offset no_about_msg
	mov	ah,9
	int	21h
	int	20h

init:
	call	init_screen

	call	flip

	mov	ax,3300h
	int	21h
	mov	save_break,dl
	mov	ax,3301h
	mov	dl,0
	int	21h

	push	ds			;set the disk error handler.
	mov	ax,cs
	mov	ds,ax
	mov	dx,offset fatal_error
	mov	ax,2524h
	int	21h
	mov	dx,offset no_ctrlc_handler
	mov	ax,2523h
	int	21h
	pop	ds

	mov	ax,8			;tell the mouse that the screen is bigger.
	mov	cx,0
	mov	dx,screen_bot - 3
	int	33h

	call	init_mouse
	call	paint_screen
	call	mouse_on

	call	load_pri

	ret

uninit:
	call	mouse_off
	call	uninit_mouse

	call	unflip
	call	uninit_screen

	mov	ax,3301h
	mov	dl,save_break
	int	21h

	ret

no_ctrlc_handler	proc	far
	ret
no_ctrlc_handler	endp



paint:
	mov	save_stack,sp
paint_again:
	call	set_checks		;ensure that all the checks are correct.
paint_waiting:
	call	menu_hook_poll		;nothing happened - keep polling.
	call	correct_shape		;ensure that the shape is correct.
	call	get_key
	je	paint_1			;no key.
	call	do_key
	jmp	paint_again
paint_1:
	call	get_mouse
	test	bl,1			;check for left button
	je	paint_2
	mov	down_button,1
	call	do_button
	mov	down_button,0
	jmp	paint_again
paint_2:
	test	bl,2			;check for right button
	je	paint_waiting
	mov	down_button,2
	call	do_button
	mov	down_button,0
	jmp	paint_again
paint_exit:
	mov	sp,save_stack
	ret


set_checks:
	mov	bx,offset select_rect
	call	empty_rect		;is there a select rect?
	jc	set_checks_1		;go if not empty.
	mov	al,1			;empty select rect - disable them.
	jmp	short set_checks_2
set_checks_1:
	mov	al,0			;not empty - enable.
set_checks_2:
	mov	dx,102h			;cut
	call	store_disabled
	mov	dx,103h			;copy
	call	store_disabled
	mov	dx,105h			;clear
	call	store_disabled
	mov	dx,107h			;invert
	call	store_disabled
	mov	dx,108h			;fill
	call	store_disabled
	mov	dx,109h			;trace edges
	call	store_disabled
	mov	dx,10ah			;flip h
	call	store_disabled
	mov	dx,10bh			;flip v
	call	store_disabled
	mov	dx,10ch			;rotate
	call	store_disabled

	mov	al,0			;assume no pens.
	cmp	pen_mirror,0		;any pens?
	je	set_checks_3		;no.
	mov	al,80h			;yes - store check.
set_checks_3:
	mov	dx,205h			;brush mirrors
	call	store_check

	mov	dx,401h			;fontsize menu, first item.
set_checks_4:
	mov	al,0			;turn them all off.
	call	store_check
	call	font_exists		;get al=menu style.
	mov	al,0
	jc	set_checks_5		;go if it doesn't
	mov	al,OUTLINE_STYLE
set_checks_5:
	call	store_menu_style
	inc	dl			;go to next menu item.
	cmp	dl,9
	jbe	set_checks_4

	mov	dx,400h			;fontsize menu, first item.
	mov	al,0			;turn the check off.
	call	store_check
	mov	al,0
	cmp	font_size_list,0	;is there an actual font size?
	je	set_checks_7		;no - no outline.
	mov	al,OUTLINE_STYLE
set_checks_7:
	call	store_menu_style

	call	read_size		;store a check on the actual one.
	mov	dl,al
	mov	al,80h
	call	store_check

	mov	dx,301h			;fonts menu, second item.
set_checks_6:
	xor	al,al			;turn off all the font checks.
	call	store_check
	inc	dl
	call	read_font_count
	add	al,2			;two extra entries that aren't fonts.
	cmp	dl,al
	jb	set_checks_6

	call	read_font_number	;get the current font
	mov	dl,al
	mov	al,80h
	call	store_check

	xor	al,al			;assume no program.
	cmp	program_id,'P' + '1'*256 ;is there a program?
	je	set_checks_8		;yes.
	cmp	program_id,'P' + '2'*256 ;is there a program?
	je	set_checks_8		;yes.
	mov	al,1			;no.
set_checks_8:
	mov	dx,006h			;Print menu item.
	call	store_disabled
	mov	dx,206h			;Margins menu item.
	call	store_disabled

	xor	al,al			;assume no .ldi files.
	cmp	ldi_list,0		;are there any .ldi files?
	jne	set_checks_9		;yes.
	mov	al,1			;no.
set_checks_9:
	mov	dx,003h			;Load...
	call	store_disabled
	mov	dx,004h			;Save
	call	store_disabled
	mov	dx,005h			;Save As...
	call	store_disabled

	xor	al,al			;assume no .fnt files.
	cmp	new_font_menu,-1	;are there any .fnt files?
	jne	set_checks_a		;yes.
	mov	al,1			;no.
set_checks_a:
	mov	dx,301h			;Load Font From Menu
	call	store_disabled

	ret


double_time	equ	250/10

do_button:
	mov	this_thing,0		;not doing pastes.
	cmp	time_now,double_time	;short enough for double click?
	ja	do_button_0		;no - do single.
	load22	last_click
	call	near_pt			;close enough for double click?
	jc	do_button_0		;no - do single.
	call	do_double		;yes.
	ret

do_button_0:
	store2	last_click		;handle non-double click.
	mov	time_now,0
	mov	bx,offset draw_window	;in the draw window?
	call	pt_in_rect
	jc	do_button_1		;no - go try pattern.
	cmp	fatbits_flag,0		;in fatbits mode?
	je	do_button_3		;no.
	mov	bx,offset fatbits_window	;yes - in fatbits window?
	call	pt_in_rect
	jnc	do_button_4		;yes - toggle fatbits off.
do_button_3:
	mov	al,new_constrain	;say that we should start constraining.
	mov	constrain_flag,al
	call	menu_hook_button
	mov	constrain_flag,0	;say that we aren't constraining.
	call	deselect_constrain	;turn constraining off.
	ret
do_button_4:
	call	toggle_fatbits
	call	wait_for_up
	ret
do_button_1:
	call	is_pat
	jnc	do_button_2
	call	is_menu
	jnc	do_button_2
	mov	bx,offset wind_pull
	call	pt_in_rect
	jc	do_button_2
	call	do_pull_down
	call	do_menu
	ret
do_button_2:
	call	wait_for_up
	ret


	public	do_menu
do_menu:
	push	ax
	call	menu_hook_hide
	pop	ax
	cmp	ah,-1			;did they pick any menu?
	je	do_menu_1		;no.
	cmp	al,-1			;did they pick any menu?
	je	do_menu_1		;no.
	xchg	al,ah
	mov	bx,offset pull_down_items
	call	case_of
do_menu_1:
	call	menu_hook_show
	call	unhighlight_menu
	ret


	public	font_inc, font_dec
font_inc:
	call	read_font_number
	inc	al
	push	ax
	call	read_font_count
	inc	al			;account for "Load Font From Menu".
	mov	dl,al
	pop	ax
	cmp	al,dl
	jbe	font_set
	jmp	short font_done
font_dec:
	call	read_font_number
	dec	al
	cmp	al,2
	jb	font_done
font_set:
	mov	ah,3
	jmp	do_menu
font_done:
	ret


	public	font_size_inc, font_size_dec
font_size_inc:
	call	read_size
	inc	al
	cmp	al,9
	jbe	font_size_set
	jmp	short font_size_done
font_size_dec:
	call	read_size
	dec	al
	js	font_size_done
font_size_set:
	mov	ah,4
	jmp	do_menu
font_size_done:
	ret


do_double:
	push	previous_menu		;remember the one before the first click.
	call	is_menu			;double click on menu?
	pop	bx
	jc	do_double_1		;no.
	mov	ax,current_menu
	cmp	ax,16			;constrain menu?
	jae	do_double_done		;yes - double has no meaning.
	cmp	ax,6			;double click brush?
	jne	do_double_3
	call	brush_shape_goodies
	jmp	short do_double_done
do_double_3:
	cmp	ax,7			;double click eraser?
	jne	do_double_4
	mov	ax,bx			;restore the old menu item.
	call	select_new_menu
	call	clear_screen_goodies
	jmp	short do_double_done
do_double_4:
	cmp	ax,5			;double click pencil?
	jne	do_double_5
	call	toggle_fatbits
	jmp	short do_double_done
do_double_5:
	cmp	ax,2			;double click grabber?
	jne	do_double_6
	call	show_page_goodies
	jmp	short do_double_done
do_double_6:
	cmp	ax,0			;double click selection box?
	jne	do_double_7
	call	menu_hook_hide
  	call	menu_hook_remove
	mov	si,clip_rect
	mov	di,offset select_rect	;get the rectangle.
	call	assign_rect
	call	get_select
	mov	si,offset select_rect
	call	start_select
	jmp	short do_double_done
do_double_1:
	call	make_pattern_rect
	call	pt_in_rect		;double click pattern?
	jc	do_double_2		;no.
	call	edit_pattern_goodies
	jmp	short do_double_done
do_double_7:
;process double clicks on other menus here.
	jmp	short do_double_done
do_double_2:
;process double clicks on other things here.
	call	do_button_0		;double clicks are same as normal.
do_double_done:
	call	wait_for_up
	ret


case_of:
;enter with al=menu item, bx->table of routines.
;branch to al'th word following the call.
	push	ax
	mov	ah,0
	or	al,al
	js	case_of_1
	add	ax,ax
	add	bx,ax
	pop	ax
	jmp	[bx].w
case_of_1:
	pop	ax
	ret


do_file_menu:
	mov	bx,offset file_menu
	mov	al,ah
	call	case_of
	ret


do_edit_menu:
	mov	bx,offset edit_menu
	mov	al,ah
	call	case_of
	ret


do_goodies_menu:
	mov	bx,offset goodies_menu
	mov	al,ah
	call	case_of
	ret


do_style_menu:
	cmp	ah,7			;font style or placement style?
	jae	do_style_menu_4		;placement style.
	mov	al,0
	cmp	ah,0			;selecting plain resets all but plain.
	je	do_style_menu_3
	dec	ah			;first style is BOLD_STYLE
	mov	cl,ah			;compute the style bit number.
	mov	ah,1
	shl	ah,cl
	call	read_style
	xor	al,ah			;toggle the bit.
do_style_menu_3:
	call	store_style
	mov	dx,0500h		;fifth menu, first line. (Plain)
	push	ax			;remember the style.
	cmp	al,0			;is the style plain?
	mov	al,80h			;assume that it is.
	je	do_style_menu_5
	xor	al,al
	jmp	short do_style_menu_5
do_style_menu_2:
	shr	al,1			;is this bit set?
	push	ax
	mov	al,0			;assume not.
	jnc	do_style_menu_5		;no - no check.
	mov	al,80h			;bit is set - store check.
do_style_menu_5:
	call	store_check
	pop	ax
	inc	dl			;go on to the next menu.
	cmp	dl,8			;done with all of them?
	jb	do_style_menu_2		;no.
	jmp	short do_style_menu_1
do_style_menu_4:
	push	ax
	mov	dx,0508h		;turn off 8,9,10.
	xor	al,al
	call	store_check
	inc	dl
	call	store_check
	inc	dl
	call	store_check
	inc	dl
	pop	ax
	mov	dl,ah			;turn on their desired alignment.
	sub	ah,8
	mov	alignment,ah
	mov	dh,5
	mov	al,80h
	call	store_check
do_style_menu_1:
	ret


do_fonts_menu:
	mov	al,ah
	mov	bx,offset fonts_menu
	call	case_of
do_fonts_menu_1:
	ret


do_fontsize_menu:
	mov	al,ah
	call	store_size
	ret


do_lineWidth_menu:
	mov	al,ah
	push	ax
	mov	al,0
	mov	dx,line_width		;old position in dl.
	mov	dh,6			;line width menu...
	call	store_check		;remove old check.
	pop	ax
	mov	ah,0
	mov	line_width,ax
	mov	dl,al			;this choice.
	mov	al,80h
	mov	dh,6			;line width menu...
	call	store_check		;add new check.
	ret


save_cmd:
	cmp	current_filename,'@'	;special kludge
	je	save_cmd_2
	cmp	loaded_from_disk,0	;have we loaded this file from disk?
	jne	save_cmd_1		;yes - just resave it.
save_cmd_2:
	jmp	prompt_write_file	;no - prompt for a real name.
save_cmd_1:
	jmp	just_resave_file


  if 1
	extrn	change_drive_cmd: near
	call	change_drive_cmd
  else
change_drive_cmd:
	call	pointing_shape
	push	clip_rect
	mov	clip_rect,offset screen
	mov	bx,offset drive_rect
	call	protect_mouse
	call	store_rect

	call	use_system_font		;set right font.

	call	read_style
	push	ax
	call	nice_frame_rect

	mov	al,UNDERLINE_STYLE
	call	store_style
	mov	bx,offset cd_title_rect
	mov	si,offset cd_title_msg
	call	center_string

	mov	ah,19h			;dosf_getdsk
	int	21h
	xor	ah,ah
	mov	dx,ax			;save current disk in dx.

	mov	ax,0
change_drive_1:

	push	ax
	mov	al,0			;set default to plain style.
	call	store_style
	pop	ax
	cmp	ax,dx			;is this the current disk?
	jne	change_drive_0		;no - go on.
	push	ax
	mov	al,OUTLINE_STYLE	;yeah - make it stand out.
	call	store_style
	pop	ax
change_drive_0:

	push	dx			;remember current drive.
	mov	bx,offset wind1
	mov	cx,3
	mov	si,offset first_drv_rect
	call	make_numbered_rect

	mov	si,offset temp_drive

	push	ax			;save number
	add	al,'A'			;make it a letter.
	mov	[si],al			;put it in string
	mov	[si+1],byte ptr 0
	call	center_string

	mov	cx,-2
	mov	dx,-2
	call	inset_rect
	call	frame_round
	pop	ax

	pop	dx
	inc	ax
	cmp	ax,num_drives
	jb	change_drive_1

	call	unprotect_mouse
	call	wait_for_up
	call	wait_for_down

	mov	ax,0
change_drive_2:
	push	cx
	push	dx
	mov	bx,offset wind1
	mov	cx,3
	mov	si,offset first_drv_rect
	call	make_numbered_rect
	pop	dx
	pop	cx

	call	pt_in_rect
	jnc	change_drive_3
	inc	ax
	cmp	ax,num_drives
	jb	change_drive_2
	jmp	short change_drive_4
change_drive_3:
	mov	dl,al
	mov	ah,0eh			;dosf_seldsk
	int	21h
change_drive_4:
	pop	ax
	call	store_style
	call	restore_rect
	call	wait_for_up
	pop	clip_rect
	ret
  endif


revert_cmd:
	cmp	loaded_from_disk,0	;have we loaded this file from disk?
	je	new_cmd			;no - New the page.
	call	menu_hook_remove
	call	just_reload_file	;yes - reload it.
	mov	changes_flag,0
	ret

load_cmd:
	call	menu_hook_remove
	call	prompt_read_file
	ret

new_cmd:
	cmp	changes_flag,0		;any changes?
	je	new_cmd_ok		;no - ok to new.
	mov	si,offset lost_msg	;if we're sure then do it.
	call	alert
	jnc	new_cmd_ok		;yes
	ret
new_cmd_ok:
	call	menu_hook_remove
	push	es
	mov	es,page_seg		;make es:di->the page.
	mov	di,0			;start at beginning.
	mov	cx,page_size		;number of bytes on page.
  if black_on_white
	mov	al,-1			;store ones.
  else
	mov	al,0			;store zeroes.
  endif
	rep	stosb			;do it.
	pop	es
	call	update_window		;show the blank page.
	mov	loaded_from_disk,0	;it is not loaded from disk.
	mov	si,offset noname_msg
	mov	di,offset current_filename
	call	strcpy
	mov	changes_flag,0
	xor	cx,cx
	xor	dx,dx
	store2	wind_on_page
	ret


print_cmd:
	call	printer_ready
	jnc	print_cmd_1
	mov	si,offset not_ready_msg
	call	error_alert
	ret
print_cmd_1:

	call	update_page		;save the current window.

	call	pointing_shape
	mov	bx,offset print_rect
	call	protect_mouse
	push	clip_rect
	mov	clip_rect,offset screen
	call	store_rect
	call	nice_frame_rect
	call	use_system_font

	call	read_style
	push	ax
	xor	al,al
	call	store_style

	mov	bx,offset cancel_rect_2
	mov	si,offset cancel_string
	call	center_string
	call	frame_round

	call	unprotect_mouse

	mov	ax,5			;kill the down counts.
	mov	bx,0
	int	33h
	mov	ax,5			;kill the down counts.
	mov	bx,1
	int	33h

	mov	bx,offset program_label
	call	printer_init

	pop	ax
	call	store_style

	call	restore_rect
	call	wait_for_up
	pop	clip_rect
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
	mov	ax,5			;kill the down counts.
	mov	bx,0
	int	33h
	or	bx,bx			;any presses?
	jne	print_abort_1		;yes.
	mov	ax,5			;kill the down counts.
	mov	bx,1
	int	33h
	or	bx,bx			;any presses?
	jne	print_abort_1		;yes.
	clc
	jmp	short print_abort_3
print_abort_1:
	mov	bx,offset cancel_rect_2	;did they click in the cancel rect?
	call	pt_in_rect
	jnc	print_abort_2	;yes - say to cancel.
	call	ring_bell
	clc
	jmp	short print_abort_3
print_abort_2:
	stc
print_abort_3:
	pop	dx
	pop	cx
	ret


print_print:
;enter with al=char to print.
	push	ax
	push	dx
	mov	dl,al
	mov	ah,5
	int	21h
	pop	dx
	pop	ax
	ret


quit_cmd:
	cmp	changes_flag,0		;have they made changes?
	je	quit_ok			;no - ok to quit.
	mov	si,offset quit_save_msg
	call	alert
	jc	quit_ok
	call	save_cmd
quit_ok:
	mov	si,offset quit_msg
	call	alert
	jc	quit_exit		;no
	jmp	paint_exit
quit_exit:
	ret


invert_edit:
	mov	si,offset invert_rect
	jmp	short do_rect_op


fill_edit:
	mov	si,fillPat
	call	make_fillPat
	mov	si,offset fill_rect
	jmp	short do_rect_op


do_rect_op:
	mov	bx,offset select_rect
	call	protect_mouse
	call	si
	call	unprotect_mouse
do_rect_op_1:
	ret


grid_goodies:
	xor	grid_flag,2			;toggle the enabled bit.
	mov	al,0
	cmp	grid_flag,0
	je	grid_goodies_1
	mov	al,80h
grid_goodies_1:
	mov	dx,200h				;turn the check off.
	call	store_check
	ret


	public	margins_goodies
margins_goodies:
	mov	al,0
	mov	page_rect.right,page_bytes*8
	mov	page_rect.bot,page_lines
	cmp	margins_flag,0			;is the flag on now?
	jne	margins_goodies_1
	load2	program_margins
	store2	page_rect.botright
	mov	al,80h
margins_goodies_1:
	mov	margins_flag,al			;turn the flag on or off.
	mov	dx,206h				;turn the check on or off.
	call	store_check
	call	update_page			;don't destroy what's there.
	call	resize_window
	call	update_window
	ret


	public	set_margins
set_margins:
	load2	program_margins
	store2	page_rect.botright
	mov	margins_flag,1			;turn the flag on.
	mov	al,80h
	mov	dx,206h				;turn the check on.
	call	store_check
	ret


	public	toggle_fatbits
toggle_fatbits:
	call	menu_hook_hide
	call	fatbits_goodies
	call	menu_hook_show
	ret


fatbits_select	equ	0

fatbits_goodies:
  ife fatbits_select
	call	menu_hook_hide
	call	menu_hook_remove	;get rid of any cursor.
  endif

	mov	bx,offset draw_window
	call	protect_mouse
	call	update_page		;get a copy of what's on the window.
	xor	fatbits_flag,1		;flip it.
	cmp	fatbits_flag,0		;is it on now?
	jne	fatbits_goodies_0	;yes - turn fatbits on
	jmp	fatbits_goodies_1	;no - turn fatbits off.
fatbits_goodies_0:

  if fatbits_select
	mov	bx,offset select_rect	;is there a select rect?
	call	empty_rect
	jc	fatbits_goodies_3	;yes - center it.
  endif

;what we want to happen is we want to ensure that first_pt appears in the small
;  window in such a place that the cursor (assumed to be at first_pt) is still
;  over first_pt.
	load2	first_pt		;position the small window to
	sub2	draw_window		;  the middle of where they were.

	mov	si,cx			;compute where they will be in fatbits.
	mov	di,dx
	sar	si,1
	sar	si,1
	sar	si,1
	sar	di,1
	sar	di,1
	sar	di,1

	sub	cx,si			;place the point that they hit in the window.
	sub	dx,di

	add2	wind_on_page		;add in where we already are.
  if fatbits_select
	jmp	short fatbits_goodies_4
fatbits_goodies_3:
	load2	fatbits_window.botright	;compute the size of the window.
	sub2	fatbits_window.topleft

	mov	bx,offset select_rect
	sub2	[bx].botright
	add2	[bx].topleft
	sar	cx,1			;distribute the difference on both sides.
	sar	dx,1

	mov	ax,cx
	or	ax,dx

	neg	cx			;put the window outside the select rect.
	neg	dx
	add2	[bx].topleft		;compute where it is on the screen.
	sub2	fatbits_window.topleft
	add2	wind_on_page
	or	ax,ax			;did the select box fit?
	jns	fatbits_goodies_4	;yes.
	call	set_empty_rect		;no - kill it.
	mov	free_space,offset pull_down_storage
  endif
fatbits_goodies_4:
	mov	si,offset fatbits_window;->box we're dragging around.
	mov	di,offset page_rect
	call	peg_rect
	xchg2	wind_on_page		;say that we're here.

  if fatbits_select
	mov	bx,offset select_rect	;is there a select rect?
	call	empty_rect
	jnc	fatbits_goodies_6	;no.
	sub2	wind_on_page		;compute the distance from where we were.
	call	offset_rect
fatbits_goodies_6:
  endif

	mov	bx,offset draw_window	;clear the entire window.
	call	clear_rect
	call	undo_update		;copy the screen here.
	call	make_fillPat_white	;prepare to make a white frame.
	call	makepen_dot
	mov	pen.pnMode,offset or_verb
	mov	bx,offset fatbits_window
	call	make_rect_bigger
	call	frame_rect
	call	make_rect_smaller
	mov	bx,offset fatbits_window	;paint the fatbits window.
	call	paint_fatbits
	mov	bx,offset fatbits_window	;clip to the fatbits window.
	mov	al,80h			;turn check on.
	jmp	short fatbits_goodies_2
fatbits_goodies_1:
	load2	wind_on_page		;ensure that the whole thing shows.

	mov	bx,offset fatbits_window	;compute the size of the fatbits window.
	load22	[bx].botright
	sub22	[bx].topleft
	sar	si,1			;compute the middle of the fatbits window.
	sar	di,1

	add	cx,si			;compute the place on the page that was in the middle.
	add	dx,di

	mov	bx,offset draw_window	;compute the size of the draw window.
	load22	[bx].botright
	sub22	[bx].topleft
	sar	si,1			;compute the middle of the fatbits window.
	sar	di,1

	sub	cx,si			;place their point in the middle.
	sub	dx,di

	store2	first_pt		;remember where we were in case they toggle again.

	mov	si,offset draw_window	;->box we're dragging around.
	mov	di,offset page_rect
	call	peg_rect
	xchg2	wind_on_page		;say that we're here.

	mov	bx,offset select_rect	;is there a select rect?
	call	empty_rect
	jnc	fatbits_goodies_5	;no.
	sub2	wind_on_page		;compute the distance from where we were.
	call	offset_rect
fatbits_goodies_5:

	call	copy_page_to_window
	mov	bx,offset draw_window	;clip to the draw window.
	mov	al,0			;turn check off.
fatbits_goodies_2:
	mov	clip_rect,bx		;bx is the new clipping window.
	mov	dx,201h			;store the new fatbits check mark.
	call	store_check
	call	unprotect_mouse
	ret


clear_screen_goodies:
	mov	changes_flag,1		;say that there have been changes.
	call	menu_hook_remove
	call	update_page		;save the window for undo.
	mov	bx,clip_rect
	call	protect_mouse
	call	clear_rect		;erase whole window.
	call	do_fatbits		;echo to fatbits.
	call	unprotect_mouse
	ret


dos_cmd:
	mov	ax,fillPat_num
	mov	old_fillPat_num,ax
	call	unhighlight_menu	;get rid of it because we clear.
	call	update_page		;don't destroy what's there.
	call	uninit
	call	shell_to_dos
	call	init
	call	resize_window		;now paint the window.
	call	update_window
	mov	ax,current_menu		;select the menu entry again.
	call	toggle_menu
	mov	ax,old_fillPat_num	;redraw the selected pattern.
	call	select_new_pattern
	call	load_pri		;reload PAINT.PRI just in case.
	ret


about_cmd:
	mov	si,offset about_name
	jmp	short display_help

introduction_goodies:
	mov	si,offset intro_name
	jmp	short display_help

shortcuts_goodies:
	mov	si,offset short_name
;fall through

display_help:
	push	clip_rect
	mov	clip_rect,offset screen

	push	si
	mov	bx,offset max_window
	call	store_rect
	pop	si

	call	get_screen		;now try to read it off the disk.
	jc	wait_for_cancel_end

	call	draw_cancel_box

	mov	bx,offset cancel_rect_1
	call	wait_for_full_click

wait_for_cancel_end:
	call	restore_rect		;get old screen back.
	call	wait_for_up
	pop	clip_rect
	ret


show_page_goodies:
	call	update_page		;save current window.
	call	waiting_shape
	mov	bx,offset show_frame
	call	protect_mouse
	push	clip_rect
	mov	clip_rect,offset screen
	call	store_rect
	call	nice_frame_rect

	mov	si,offset page_rect	;get the whole page rect.
	mov	di,offset page_bitmap
	call	assign_rect

	mov	bx,offset show_rect
	call	protect_mouse

	mov	ax,screen_seg
	mov	show_rect.pntr.segm,ax
	mov	put_byte_subr,offset pset_verb
	mov	si,offset page_bitmap	;shrink the page to the show rect.
	mov	di,offset show_rect
	call	blit

	call	read_style
	push	ax
	mov	ax,0
	call	store_style
	call	use_system_font
	mov	bx,offset show_button
	call	protect_mouse
	mov	si,offset ok_string
	call	center_string
	call	frame_round
	call	unprotect_mouse
	pop	ax
	call	store_style

	call	unprotect_mouse

	call	unprotect_mouse

	mov	bx,offset show_button	;the ok button.
	call	wait_for_full_click

	call	restore_rect
	call	wait_for_up
	pop	clip_rect
	ret


flip_horizontal_edit:
	mov	bx,offset select_rect
	call	protect_mouse
	mov	bx,offset select_rect
	mov	si,offset pull_down_storage
	call	get_flip_h
	mov	put_byte_subr,offset pset_verb
	mov	si,offset pull_down_storage	;put the left at the right.
	mov	bx,offset select_rect
	call	put_rect
	call	unprotect_mouse
	ret


rotate_edit:
	mov	bx,offset select_rect
	call	protect_mouse
	mov	bx,offset select_rect
	mov	si,offset pull_down_storage
	call	get_rotate
	mov	put_byte_subr,offset pset_verb
	mov	si,offset pull_down_storage	;put the left at the right.
	mov	bx,offset select_rect
	load2	[bx].topleft
	add2	[si]
	store2	[bx].botright		;rotate the select rectangle.
	call	center_select
	call	erase_moving
	call	clear_original
	call	draw_moving
	call	unprotect_mouse
rotate_edit_1:
	ret


flip_vertical_edit:
	mov	bx,offset select_rect
	call	protect_mouse
	mov	cx,select_rect.left
	mov	si,select_rect.right
	mov	wind1.left,cx
	mov	wind1.right,si
	mov	wind2.left,cx
	mov	wind2.right,si
	mov	put_byte_subr,offset pset_verb
	mov	dx,select_rect.top
	mov	di,select_rect.bot
	dec	di			;start just inside the bounding rect.
flip_vertical_edit_1:
	cmp	dx,di
	jae	flip_vertical_edit_2
	push	dx
	push	di
	mov	wind1.top,dx		;make a one pixel high rect.
	inc	dx
	mov	wind1.bot,dx
	mov	wind2.top,di		;make another.
	inc	di
	mov	wind2.bot,di
	mov	si,offset pull_down_storage	;get the top row.
	mov	bx,offset wind1
	call	get_rect
	push	si			;save the bot row.
	mov	bx,offset wind2
	call	get_rect
	mov	si,offset pull_down_storage	;put the left at the right.
	mov	bx,offset wind2
	call	put_rect
	pop	si			;put the right at the left.
	mov	bx,offset wind1
	call	put_rect
	pop	di
	pop	dx
	inc	dx			;move top in
	dec	di			;move bot in.
	jmp	flip_vertical_edit_1
flip_vertical_edit_2:
	call	unprotect_mouse
	ret


trace_edges_edit:
	mov	si,offset select_rect
	mov	di,offset wind1
	call	assign_rect

	mov	bx,offset wind1
	call	protect_mouse
	call	flip_ram
	call	flip_crt

	mov	bx,offset wind1	;save the box.
	mov	cx,-1
	mov	dx,-1
	call	inset_rect		;make it slightly smaller.
	call	empty_rect		;is it now empty?
	jnc	trace_edges_edit_1

	mov	si,offset pull_down_storage
	call	get_rect

  if black_on_white
	mov	put_byte_subr,offset and_verb
  else
	mov	put_byte_subr,offset or_verb
  endif
	load2	wind1.topleft
	inc	cx
	call	trace_rect		;right
	inc	dx
	call	trace_rect		;down,right
	dec	cx
	call	trace_rect		;down
	dec	cx
	call	trace_rect		;down,left
	dec	dx
	call	trace_rect		;left
	dec	dx
	call	trace_rect		;up,left
	inc	cx
	call	trace_rect		;up
	inc	cx
	call	trace_rect		;up,right
	inc	dx
	dec	cx

  if black_on_white
	mov	put_byte_subr,offset or_not_verb
  else
	mov	put_byte_subr,offset and_not_verb
  endif
	call	trace_rect

trace_edges_edit_1:
	call	flip_crt
	call	unprotect_mouse
	ret


trace_rect:
	push	cx
	push	dx
	mov	si,offset pull_down_storage
	mov	bx,offset wind1
	store2	[bx].topleft
	add2	[si]
	store2	[bx].botright
	call	put_rect
	pop	dx
	pop	cx
	ret


brush_mirrors_goodies:
	call	pointing_shape
	call	use_system_font
	mov	bx,offset mirror_rect
	call	protect_mouse
	push	clip_rect
	mov	clip_rect,offset screen
	call	read_style		;set the style to plain.
	push	ax
	mov	al,0
	call	store_style

	call	store_rect
	call	nice_frame_rect

	mov	bx,offset ok_rect
	mov	si,offset ok_string
	call	center_string
	call	frame_round

	mov	bx,offset cancel_rect
	mov	si,offset none_string
	call	center_string
	call	frame_round

	call	unprotect_mouse
brush_mirrors_6:
	mov	bx,offset mirror_box		;clear and redraw box.
	call	protect_mouse
	call	clear_rect
	call	make_fillPat_white
	call	makepen_dot
  if black_on_white
	mov	pen.pnMode,offset and_verb
  else
	mov	pen.pnMode,offset or_verb
  endif
	call	frame_rect
	call	makepen_dot
	test	pen_bits,1		;   _
	je	brush_mirrors_1
	mov	si,offset three_dot_pen
	call	makepen
brush_mirrors_1:
	mov	cx,[bx].left
	mov	dx,[bx].bot
	sub	dx,[bx].top
	sub	dx,pen.pnSize.v
	shr	dx,1
	add	dx,[bx].top
	mov	si,[bx].right
	mov	di,dx
	sub	si,pen.pnSize.h
	push	bx
	call	line_to
	pop	bx
	call	makepen_dot
	test	pen_bits,4		;   |
	je	brush_mirrors_2
	mov	si,offset three_dot_pen
	call	makepen
brush_mirrors_2:
	mov	cx,[bx].right
	sub	cx,[bx].left
	sub	cx,pen.pnSize.h
	shr	cx,1
	add	cx,[bx].left
	mov	dx,[bx].top
	mov	si,cx
	mov	di,[bx].bot
	sub	di,pen.pnSize.v
	push	bx
	call	line_to
	pop	bx
	call	makepen_dot
	test	pen_bits,8		;   \
	je	brush_mirrors_3
	mov	si,offset three_dot_pen
	call	makepen
brush_mirrors_3:
	load2	[bx].topleft
	load22	[bx].botright
	sub22	pen.pnSize
	push	bx
	call	line_to
	pop	bx
	call	makepen_dot
	test	pen_bits,2		;   /
	je	brush_mirrors_4
	mov	si,offset three_dot_pen
	call	makepen
brush_mirrors_4:
	mov	cx,[bx].left
	mov	dx,[bx].bot
	mov	si,[bx].right
	mov	di,[bx].top
	sub	si,pen.pnSize.h
	sub	dx,pen.pnSize.v
	push	bx
	call	line_to
	pop	bx
	call	unprotect_mouse
brush_mirrors_8:
	call	wait_for_up
	call	wait_for_down

	mov	bx,offset mirror_rect
	call	pt_in_rect
	jnc	brush_mirrors_9
	call	ring_bell
	jmp	brush_mirrors_8
brush_mirrors_9:
	mov	bx,offset ok_rect	;did they say ok?
	call	pt_in_rect
	jnc	brush_mirrors_5		;yes - exit.
	mov	bx,offset cancel_rect	;did they say none?
	call	pt_in_rect
	jc	brush_mirrors_7		;no - flip a line.
	mov	pen_bits,0		;yes - turn them off,
	jmp	brush_mirrors_5		;  and exit.
brush_mirrors_7:
	mov	bx,offset wind2
	store2	[bx].botright
	load2	mirror_box.botright
	sub2	mirror_box.topleft
	shr	cx,1
	shr	dx,1
	add2	mirror_box.topleft
	store2	[bx].topleft
	call	arctan
	add	ax,45/2			;rotate by a half a notch.
	mov	bx,45
	mov	dx,0
	div	bx
	and	al,3			;only 4 different mirrors.
	mov	cl,al			;make a numbered bit out of it.
	mov	al,1
	shl	al,cl
	xor	pen_bits,al		;flip that pen mirror on or off.
	jmp	brush_mirrors_6
brush_mirrors_5:
	mov	al,pen_bits
	cmp	al,1110b
	je	brush_mirrors_b
	cmp	al,1101b
	je	brush_mirrors_b
	cmp	al,1011b
	je	brush_mirrors_b
	cmp	al,0111b
	jne	brush_mirrors_a
brush_mirrors_b:
	mov	al,1111b
brush_mirrors_a:
	mov	pen_mirror,al
	call	restore_rect
	call	wait_for_up
	pop	ax
	call	store_style
	pop	clip_rect
	ret


brush_shape_goodies:
brush_shape:
	call	pointing_shape
	push	clip_rect
	mov	clip_rect,offset screen
	mov	bx,offset brush_rect
	call	protect_mouse
	call	store_rect
	call	nice_frame_rect
	mov	ax,0
brush_shape_2:
	push	ax
	mov	bx,offset wind1
	call	make_pen_rect
	push	si
	call	makepen
	load2	[bx].botright		;compute the size of the pen window.
	sub2	[bx].topleft
	sub2	pen.pnSize		;compute the area not used by the pen.
	shr	cx,1			;halve it, and center the pen.
	shr	dx,1
	add2	[bx].topleft
	call	put_brush
	pop	si
	cmp	si,current_pen
	jne	brush_shape_6
	mov	si,offset big_dot_pen
	call	makepen
	mov	pen.pnMode,offset or_verb
	mov	bx,offset wind1
	call	frame_rect
brush_shape_6:
	pop	ax
	inc	ax
	cmp	ax,num_pens
	jb	brush_shape_2
	call	unprotect_mouse
	call	wait_for_up
	call	wait_for_down
	mov	ax,0
brush_shape_3:
	mov	bx,offset wind1
	push	cx
	push	dx
	call	make_pen_rect
	pop	dx
	pop	cx
	call	pt_in_rect
	jnc	brush_shape_4
	inc	ax
	cmp	ax,num_pens
	jb	brush_shape_3
	jmp	short brush_shape_5
brush_shape_4:
	mov	current_pen,si
	mov	current_shape,-1
brush_shape_5:
	call	correct_shape		;we may have changed the shape.
	call	restore_rect
	call	wait_for_up
	pop	clip_rect
	ret


	public	nice_frame_rect
nice_frame_rect:
;enter with bx->rect.
;put a nice frame around the rect.
	call	protect_mouse
	push	clip_rect
	mov	clip_rect,offset screen
	mov	pen.pnMode,offset pset_verb
	call	makepen_dot
	call	clear_rect
	call	make_fillPat_white
	call	frame_rect
	mov	cx,-1
	mov	dx,-1
	call	inset_rect
	call	frame_rect
	mov	cx,-3
	mov	dx,-3
	call	inset_rect
	call	frame_rect
	mov	cx,4
	mov	dx,4
	call	inset_rect
	pop	clip_rect
	call	unprotect_mouse
	ret


	public	select_new_menu
select_new_menu:
;enter with ax=new menu item to select.
;exit with cy if we already are in it, nc if it's new.
	cmp	ax,16			;handle 16 and 17 differently.
	jae	select_new_menu_3
	xchg	current_menu,ax
	mov	previous_menu,ax	;always remember the previous menu.
	cmp	ax,current_menu		;do we already have this one?
	je	select_new_menu_1	;yes.
	cmp	ax,-1			;was there any current menu?
	je	select_new_menu_2	;no.
	push	ax
	call	menu_hook_hide
	call	menu_hook_remove	;remove the old menu.
	pop	ax
	call	toggle_menu
select_new_menu_2:
	mov	ax,count_menu_hooks*2
	mul	current_menu
	add	ax,offset menu_hooks
	mov	si,ax
	push	ds
	pop	es
	mov	di,offset first_menu_hook
	mov	cx,count_menu_hooks
	rep	movsw
	mov	ax,current_menu		;invert the new menu
	call	toggle_menu
	clc
	ret
select_new_menu_1:
	stc
	ret
select_new_menu_3:
	cmp	ax,16
	jne	select_new_menu_4
	call	toggle_menu		;turn 16 on or off.
	mov	al,2
	xchg	al,new_constrain	;what did it used to be?
	or	al,al
	je	select_new_menu_1	;if it was off, it's now on.
	cmp	al,1			;was 17 on?
	je	select_new_menu_5	;yes - turn it off.
	mov	new_constrain,0		;it used to be on, turn it off.
	jmp	select_new_menu_1
select_new_menu_5:
	mov	ax,17
	call	toggle_menu
	jmp	select_new_menu_1
select_new_menu_4:
	call	toggle_menu		;turn 17 on or off.
	mov	al,1
	xchg	al,new_constrain	;what did it used to be?
	or	al,al
	je	select_new_menu_1	;if it was off, it's now on.
	cmp	al,2			;was 16 on?
	je	select_new_menu_6	;yes - turn it off.
	mov	new_constrain,0		;it used to be on, turn it off.
	jmp	select_new_menu_1
select_new_menu_6:
	mov	ax,16
	call	toggle_menu
	jmp	select_new_menu_1


deselect_constrain:
	xor	al,al
	xchg	al,new_constrain
	dec	al			;was it one (v)?
	jne	deselect_constrain_1	;no.
	mov	ax,17			;turn v off.
	call	toggle_menu
	ret
deselect_constrain_1:
	dec	al			;was it two (h)?
	jne	deselect_constrain_2	;no.
	mov	ax,16			;turn h off.
	call	toggle_menu
deselect_constrain_2:
	ret


toggle_menu:
;enter with ax=number of menu item to invert.
	mov	bx,offset wind1
	call	make_menu_rect
	mov	cx,-1
	mov	dx,-1
	call	inset_rect		;make it one smaller.
	call	protect_mouse
	call	invert_rect
	call	unprotect_mouse
	ret


	public	select_new_pattern
select_new_pattern:
;enter with ax=new pattern to select.
	mov	fillPat_num,ax
	mov	si,ax
	shl	si,1
	shl	si,1
	shl	si,1			;*8
	lea	si,patterns[si]
	mov	fillPat,si
	call	make_fillPat
	call	make_pattern_rect	;fill the rect with the pattern.
	call	protect_mouse
	call	make_rect_smaller	;don't fill quite that much.
	call	fill_rect
	call	make_rect_bigger

	mov	si,offset white_pat	;now frame it in white.
	call	make_fillPat
	call	makepen_dot
	call	frame_rect

	call	unprotect_mouse
	ret


	public	line_to
line_to:
;draws line from cx,dx->si,di
	push	cx
	push	dx
	push	si
	push	di
	mov	bx,offset line_rect
	call	set_rect
	mov	ax,pen.pnSize.h
	sub	[bx].left,ax
	add	[bx].right,ax
	mov	ax,pen.pnSize.v
	sub	[bx].top,ax
	add	[bx].bot,ax
	call	protect_mouse
	pop	di
	pop	si
	pop	dx
	pop	cx
	push	bp
	call	do_line
	pop	bp
	call	unprotect_mouse
	ret


	public	correct_shape, pointing_shape, waiting_shape
correct_shape:
;enter with cx, dx=point.
;exit with cursor set to the correct shape.
	call	map_fatbits
	mov	bx,clip_rect		;are we inside the draw rect?
	call	pt_in_rect
	jc	pointing_shape		;no - set to pointing shape.
	call	menu_hook_cursor	;yes - returns with si->desired cursor.
	jmp	short set_cursor_shape

	public	waiting_shape, pointing_shape
waiting_shape:
;set cursor to wrist watch icon.
	mov	si,offset waiting_cursor
	jmp	short pointing_shape_0
pointing_shape:
;set cursor to standard pointer.
	mov	si,offset pointing_cursor
pointing_shape_0:
	test	grid_flag,1		;is gridding turned on?
	je	pointing_shape_1	;no.
	shl	grid_flag,1		;yes - turn it off.
pointing_shape_1:
;
;fall through.
;
set_cursor_shape:
;enter with si->new mouse cursor
	cmp	si,current_shape
	je	set_cursor_shape_1
	mov	current_shape,si
	call	make_mouse
set_cursor_shape_1:
	ret


	public	strcpy
strcpy:
	push	ds
	pop	es
strcpy_1:
	lodsb
	stosb
	or	al,al
	jne	strcpy_1
	ret


  ifdef header_rect
	public	do_header
do_header:
;enter with si->string to put up as name.
	push	clip_rect
	mov	clip_rect,offset screen
	call	read_style
	push	ax
	mov	al,0			;set the style to plain.
	call	store_style
	push	si
	call	use_system_font
	pop	si
	mov	bx,offset header_rect
	call	protect_mouse
	push	si
	call	clear_rect
	pop	si
	call	center_string
	call	unprotect_mouse
	pop	ax
	call	store_style
	pop	clip_rect
	ret
  endif


	public	popup_tools
popup_tools:
;pop up a tool box.
	push	clip_rect
	mov	clip_rect,offset screen

  if 1
	call	get_mouse
	mov	si,offset first_menu_rect
	store2	[si].topleft
	add	cx,w_one_menu
	add	dx,h_one_menu
	store2	[si].botright
  endif
	mov	bx,offset wind1
	mov	ax,0
	call	make_menu_rect
	push	[bx].left
	push	[bx].top
	mov	ax,num_menus-1
	call	make_menu_rect
	pop	[bx].top
	pop	[bx].left
	call	protect_mouse
	call	store_rect

	call	paint_tools
	call	unprotect_mouse

	call	wait_for_down
	call	wait_for_up

	call	restore_rect

	pop	clip_rect

	ret


paint_tools:
	mov	ax,0
	mov	si,offset menu_items	;center each name over menu.
paint_tools_1:
	push	ax
	push	si
	mov	bx,offset wind1		;make a menu rectangle.
	call	make_menu_rect
	mov	si,offset black_pat	;fill it with black
	call	make_fillPat
	mov	bx,offset wind1
	call	fill_rect
	call	make_fillPat_white	;frame it in white.
	call	frame_rect
	pop	si
	load2	wind1.topleft
	mov	ax,w_one_menu		;center it by computing the white
	sub	ax,[si]			;  space, dividing it by two, and
	shr	ax,1			;  adding it to the x position.
	add	cx,ax
	mov	ax,h_one_menu
	sub	ax,2[si]
	shr	ax,1
	add	dx,ax
	mov	bx,offset wind2		;make a proper rectangle out of it.
	store2	[bx].topleft
	add2	[si]
	store2	[bx].botright
	push	put_byte_subr
	mov	put_byte_subr,offset preset_verb
	call	put_rect
	pop	put_byte_subr
	pop	ax
	inc	ax
	cmp	ax,num_menus
	jb	paint_tools_1
	ret

paint_screen:
;no arguments, no values returned.
	call	makepen_dot
	mov	pen.pnMode,offset pset_verb
	mov	clip_rect,offset screen
	mov	si,offset gray_pat
	call	make_fillPat
	mov	bx,offset screen
	call	fill_rect			;paint whole desktop grey.
	mov	si,offset black_pat
	call	make_fillPat
	call	make_pattern_rect
	call	fill_rect
	mov	bx,offset wind_pull		;pull down menu bar rect.
	call	fill_rect

	call	kill_menus

	mov	si,offset file_menu_list
	call	append_menu
	mov	si,offset edit_menu_list
	call	append_menu
	mov	si,offset goodies_menu_list
	call	append_menu
	mov	si,offset font_menu_list
	call	append_menu
	mov	si,offset fontsize_menu_list
	call	append_menu
	mov	si,offset style_menu_list
	call	append_menu
	mov	si,offset lineWidth_menu_list
	call	append_menu

	call	paint_tools

	call	makepen_dot
	call	make_fillPat_white

	call	make_pattern_rect
	call	frame_rect
  ifdef header_rect
	mov	bx,offset header_rect		;title rect.
	call	make_rect_bigger
	call	frame_rect
	call	make_rect_smaller
  endif

	mov	clip_rect,offset draw_window
	ret


resize_window:
	load2	program_margins
	cmp	margins_flag,0		;are the margins on?
	jne	resize_window_1			;yes.
	load2	max_window.botright
	sub2	max_window.topleft
resize_window_1:

	push	clip_rect
	mov	clip_rect,offset screen
	mov	pen.pnMode,offset pset_verb

	and	cx,not 7		;ensure that it's a multiple of eight.
	add2	draw_window.topleft
	store2	draw_window.botright

	mov	si,offset draw_window	;ensure that it's no bigger than max.
	mov	di,si
	mov	bx,offset max_window
	call	sect_rect

	load2	draw_window.botright	;recompute the center.
	sub2	draw_window.topleft
	shr	cx,1
	shr	dx,1
	add2	draw_window.topleft
	store2	center_window

	mov	ax,draw_window.right	;compute wind_bytes.
	sub	ax,draw_window.left
	add	ax,7
	shr	ax,1
	shr	ax,1
	shr	ax,1
	mov	wind_bytes,ax
	add	ax,fatbits_window.left
	mov	fatbits_window.right,ax

	xor	cx,cx			;position the window to the top left.
	xor	dx,dx
	store2	wind_on_page

	mov	bx,offset screen
	call	protect_mouse

	mov	si,offset gray_pat
	call	make_fillPat
	mov	bx,offset max_window
	call	fill_rect		;paint whole desktop grey.
  ifdef header_rect
	mov	dx,max_window.right
	mov	header_rect.right,dx	;also adjust the header size.
	mov	bx,offset header_rect
	call	fill_rect		;paint header grey.
  endif

	mov	si,offset black_pat
	call	make_fillPat
	mov	bx,offset draw_window	;paint draw rect black.
	call	fill_rect
  ifdef header_rect
	mov	dx,draw_window.right
	mov	header_rect.right,dx	;also adjust the header size.
	mov	bx,offset header_rect	;title rect.
	call	fill_rect
  endif

	call	makepen_dot
	call	make_fillPat_white

  ifdef header_rect
	mov	bx,offset header_rect
	call	make_rect_bigger
	call	frame_rect
	call	make_rect_smaller
  endif
	mov	bx,offset draw_window
	call	make_rect_bigger
	call	frame_rect
	call	make_rect_smaller

	cmp	fatbits_flag,0		;should we frame the fatbits window?
	je	resize_window_2

	mov	bx,offset fatbits_window
	call	make_rect_bigger
	call	frame_rect
	call	make_rect_smaller
resize_window_2:

	call	unprotect_mouse
	pop	clip_rect

	ret


make_pattern_rect:
;exit with bx ->pattern_rect.
	mov	bx,offset pattern_rect
	ret


make_menu_rect:
;enter with ax=menu number, bx->rect.
;exit with ax=pat number, bx->rect=menu rect.
	mov	si,offset first_menu_rect
	mov	cx,num_menus_x
	call	make_numbered_rect
	inc	[bx].right
	inc	[bx].bot
	ret


is_menu:
;enter with cx,dx=selected point.
;exit with new menu item selected, cy, or nc if not menu item.
	mov	si,offset first_menu_rect
	mov	bp,num_menus_x
	mov	ax,num_menus
	call	pt_in_numbered
	jc	is_menu_1
is_menu_2:
	call	select_new_menu
	clc
is_menu_1:
	ret


is_pat_3:
	ret
is_pat:
;enter with cx,dx=selected point.
;exit with new pattern selected, nc, or cy if not pattern.
	call	make_pattern_rect
	call	pt_in_rect
	jc	is_pat_3

	push	clip_rect
	mov	clip_rect,offset screen

	mov	pen.pnMode,offset pset_verb
	call	makepen_dot

	mov	bx,offset all_pats_rect	;covers all the patterns.
	call	store_rect

	call	clear_rect
	call	protect_mouse

	mov	ax,0
is_pat_2:				;fill in patterns at bottom.
	mov	bx,offset wind1
	mov	si,offset first_pat_rect
	mov	cx,num_pats_in_x
	call	make_numbered_rect
	inc	[bx].right		;make the frames overlap
	inc	[bx].bot
	push	ax
	mov	si,ax
	shl	si,1
	shl	si,1
	shl	si,1
	lea	si,patterns[si]
	call	make_fillPat
	call	fill_rect
	call	make_fillPat_white
	call	frame_rect
	pop	ax
	inc	ax
	cmp	ax,num_patterns
	jb	is_pat_2
	call	unprotect_mouse

	mov	ax,fillPat_num
	mov	old_fillPat_num,ax
is_pat_4:
	call	get_mouse
	mov	si,offset first_pat_rect
	mov	bp,num_pats_in_x
	mov	ax,num_patterns
	call	pt_in_numbered		;did we find one?
	jnc	is_pat_1		;yes.
	mov	ax,old_fillPat_num	;no - use the old one.
is_pat_1:
	call	select_new_pattern
	call	get_mouse
	test	bl,down_button
	jne	is_pat_4

	pop	clip_rect
	call	restore_rect
	clc
	ret


make_pen_rect:
;enter with bx->rect, ax=pen number.
;exit with rect surrounding the pen, si->pen.
	mov	si,offset first_pen_rect
	mov	cx,8
	call	make_numbered_rect
	mov	cx,ax
	mov	si,offset pens+2
	jcxz	make_pen_rect_2
make_pen_rect_1:
	add	si,[si-2].w
	add	si,2
	loop	make_pen_rect_1
make_pen_rect_2:
	ret


code	ends

	end	start
