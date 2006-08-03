.asm.obj:
	tasm $*;

OBJS = paintf1.obj paintmse.obj paintdat.obj paintg.obj paintcan.obj \
paintfat.obj paintr.obj paintp.obj paints.obj painti.obj paintf.obj \
paintc.obj painth.obj paint.obj paintd.obj paintdio.obj paint17.obj \
paint1.obj paintscr.obj

all: convert.com printimg.com pa.com

convert.com: convert.obj
	tlink convert
	exe2com convert
	del convert.exe

printimg.com: printimg.obj
	tlink printimg
	exe2com printimg
	del printimg.exe

pa.com : $(OBJS) paintega.obj
	tlink @paintega.bll
	exe2com pa
	del pa.exe
