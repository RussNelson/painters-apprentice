# painters-apprentice
Automatically exported from code.google.com/p/painters-apprentice
MS-DOS paint program
At one time this program was called Mockpaint ... because it was a pixel-for-pixel clone of the MacPaint program, only for the Zenith Z-100.  It was written by Russell Nelson and Patrick Naughton mostly in the summer of 1984.  Later, Russell ported it to the PC using VGA video.

It has some innovative features.  Everything is painted to the screen using a compiling bitblt routing.  Since it was written for the 8086, which lacked a barrel shifter, it needed to produce optimized code.

Various printers are supported through the use of a minilanguage created for printing.  Printer drivers are written as small ASCII files containing minilanguage instructions.
