void line(UInt16 x0, UInt16 y0, UInt16 x1, UInt16 y1, UInt8 c)
{
    ES = 0xb800;
    dy = abs(y1 - y0);
    dx = abs(x1 - x0);
    if (dx < dy) {
        dy2 = dy << 1;
        dx2 = dx << 1;
        UInt16 e = -dx;
        if (y0 > y1) {
            DX = x0;
            x0 = x1;
            x1 = DX;
            DX = y0;
            y0 = y1;
            y1 = DX;
        }
        initPosition(x0, y0);
        UInt16 count = dy + 1;
        if (x1 < x0) while (count-->0) { plot(); down(); e += dx2; if (e > 0) { left();  e -= dy2; } }
        else         while (count-->0) { plot(); down(); e += dx2; if (e > 0) { right(); e -= dy2; } }
    }
    else {
        dx2 = dx << 1;
        dy2 = dy << 1;
        UInt16 e = -dy;
        if (x0 > x1) {
            DX = x0;
            x0 = x1;
            x1 = DX;
            DX = y0;
            y0 = y1;
            y1 = DX;
        }
        initPosition(x0, y0);
        UInt16 count = dx + 1;
        if (y1 < y0) { while (count-->0) { plot(); right(); e += dy2; if (e > 0) { up();   e -= dx2; } }
        else           while (count-->0) { plot(); right(); e += dy2; if (e > 0) { down(); e -= dx2; } }
    }
}

void line(UInt16 x0, UInt16 y0, UInt16 x1, UInt16 y1, UInt8 c)
{
    ES = 0xb800;
    initPosition(x0, y0);
    UInt16 dx = x1 - x0;
    UInt16 dy = y1 - y0;
    if (dy >= 0) {
        if (dx >= 0) {
            if (dx < dy) {
                UInt16 e = -dy;
                UInt16 count = dy + 1;
                dx <<= 1;
                dy <<= 1;
                while (count-->0) { plot(); down();  e += dx; if (e > 0) { right(); e -= dy; } }
            }
            else {
                UInt16 e = -dx;
                UInt16 count = dx + 1;
                dx <<= 1;
                dy <<= 1;
                while (count-->0) { plot(); right(); e += dy; if (e > 0) { down();  e -= dx; } }
            }
        }
        else {
            dx = -dx;
            if (dx < dy) {
                UInt16 e = -dy;
                UInt16 count = dy + 1;
                dx <<= 1;
                dy <<= 1;
                while (count-->0) { plot(); down();  e += dx; if (e > 0) { left();  e -= dy; } }
            }
            else {
                UInt16 e = -dx;
                UInt16 count = dx + 1;
                dx <<= 1;
                dy <<= 1;
                while (count-->0) { plot(); left();  e += dy; if (e > 0) { down();  e -= dx; } }
            }
        }
    }
    else {
        dy = -dy;
        if (dx >= 0) {
            if (dx < dy) {
                UInt16 e = -dy;
                UInt16 count = dy + 1;
                dx <<= 1;
                dy <<= 1;
                while (count-->0) { plot(); up();    e += dx; if (e > 0) { right(); e -= dy; } }
            }
            else {
                UInt16 e = -dx;
                UInt16 count = dx + 1;
                dx <<= 1;
                dy <<= 1;
                while (count-->0) { plot(); right(); e += dy; if (e > 0) { up();    e -= dx; } }
            }
        }
        else {
            dx = -dx;
            if (dx < dy) {
                UInt16 e = -dy;
                UInt16 count = dy + 1;
                dx <<= 1;
                dy <<= 1;
                while (count-->0) { plot(); up();    e += dx; if (e > 0) { left();  e -= dy; } }
            }
            else {
                UInt16 e = -dx;
                UInt16 count = dx + 1;
                dx <<= 1;
                dy <<= 1;
                while (count-->0) { plot(); left();  e += dy; if (e > 0) { up();    e -= dx; } }
            }
        }
    }
}

// One way of specifying a line:
//   x0 - 2 bytes
//   y0 - 1 byte
//   x1 - 2 bytes
//   y1 - 1 byte
//   colour - 1 byte
//   total = 7 bytes
// Another:
//   routine - 1 byte
//   major & number of pixels - 2 bytes
//   minor & initial error - 2 bytes
//   initial location - 2 bytes
//   total = 7 bytes

// Incoming:
//   DL = colour
//   DI = y0
//   CX = x0
//

// Inner loop:
//   AL = byte read or to write
//   AH = mask
//   DL = colour
//   DH = temporary
//   DI = screen memory location
//   ES = screen memory segment
//   CX = number of pixels to plot remaining
//   SI = error
//   BP = error increment
//   SP = error decrement
//   BL = inverse mask

// TODO: unroll the loop by 2 for verticals, 4 for horizontals

// Down major, right minor

// Non-unrolled
lineLoop:
  xor [di],dl          ; 2 2 16 21
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  add si,bp            ; 2 0  8  3
  jle noAdjust         ; 2 0  8  4/16
  ror dl,1             ; 2 0  8  2
  ror dl,1             ; 2 0  8  2
  adc di,0             ; 3 0 12  4
  sub si,bx            ; 2 0  8  3
noAdjust:
  loop lineLoop        ; 2 0  8  5/17

// Unrolled
lineLoop0:
  xor [di],dl          ; 2 2 16 21
  add di,ax            ; 2 0  8  3
  add si,bp            ; 2 0  8  3
  jle noAdjust0        ; 2 0  8  4/16
  ror dl,1             ; 2 0  8  2
  ror dl,1             ; 2 0  8  2
  adc di,0             ; 3 0 12  4
  sub si,bx            ; 2 0  8  3
noAdjust0:
  loop lineLoop1       ; 2 0  8  5/17
  jmp done
lineLoop1:
  xor [di],dl          ; 2 2 16 21
  add di,sp            ; 2 0  8  3
  add si,bp            ; 2 0  8  3
  jle noAdjust1        ; 2 0  8  4/16
  ror dl,1             ; 2 0  8  2
  ror dl,1             ; 2 0  8  2
  adc di,0             ; 3 0 12  4
  sub si,bx            ; 2 0  8  3
noAdjust1:
  loop lineLoop0       ; 2 0  8  5/17
done:

// Unrolled all the way (100 iterations needed @ 32 bytes per = 3200 bytes):
// 18 IOs per pixel
lineLoop0:
  xor [di],dl          ; 2 2 16 21
  add di,ax            ; 2 0  8  3
  add si,bp            ; 2 0  8  3
  jle noAdjust0        ; 2 0  8  4/16
  ror dl,1             ; 2 0  8  2
  ror dl,1             ; 2 0  8  2
  adc di,cx            ; 2 0  8  3
  sub si,bx            ; 2 0  8  3
noAdjust0:
  xor [di],dl          ; 2 2 16 21
  add di,sp            ; 2 0  8  3
  add si,bp            ; 2 0  8  3
  jle noAdjust1        ; 2 0  8  4/16
  ror dl,1             ; 2 0  8  2
  ror dl,1             ; 2 0  8  2
  adc di,cx            ; 2 0 12  4
  sub si,bx            ; 2 0  8  3
noAdjust1:

// Erase: 14 IOs per pixel. 100 iterations needed @ 26 bytes per = 2600 bytes:
  stosb                ; 1 1  8 11
  add di,dx            ; 2 0  8  3
  add si,bp            ; 2 0  8  3
  jle noAdjust0        ; 2 0  8  4/16
  add cl,ch            ; 2 0  8  3
  adc di,ax            ; 2 0  8  3
  sub si,bx            ; 2 0  8  3
noAdjust0:
  stosb                ; 1 1  8 11
  add di,sp            ; 2 0  8  3
  add si,bp            ; 2 0  8  3
  jle noAdjust1        ; 2 0  8  4/16
  add cl,ch            ; 2 0  8  3
  adc di,ax            ; 2 0  8  3
  sub si,bx            ; 2 0  8  3
noAdjust1:

// If we have a 64-byte wide screen:
lineLoop0:
  xor [bx],al          ; 2 2 16 21
  add bx,di            ; 2 0  8  3
  add dx,bp            ; 2 0  8  3
  jle noAdjust0        ; 2 0  8  4/16
  pop ax               ; 1 2
  add bl,ah            ; 2 0
  sub dx,sp            ; 2 0  8  3
noAdjust0:
  xor [bx],al          ; 2 2 16 21
  add bx,cx            ; 2 0  8  3
  add dx,bp            ; 2 0  8  3
  jle noAdjust1        ; 2 0  8  4/16
  pop ax               ; 1 2
  add bl,ah            ; 2 0
  sub dx,sp            ; 2 0  8  3
noAdjust1:





// Right major, down minor

// Non-unrolled
lineLoop:
  xor [di],dl          ; 2 2 16 21
  ror dl,1             ; 2 0  8  2
  ror dl,1             ; 2 0  8  2
  adc di,0             ; 3 0  8  3
  add si,bp            ; 2 0  8  3
  jle noAdjust         ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  sub si,bx            ; 2 0  8  3
noAdjust:
  loop lineLoop        ; 2 0  8  5/17

// Unrolled:
lineLoop0:
  xor [di],0c0         ; 3 2 20 22
  add si,bp            ; 2 0  8  3
  jle noAdjust0        ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  sub si,bx            ; 2 0  8  3
noAdjust0:
  loop lineLoop1       ; 2 0  8  5/17
  jmp done
lineLoop1:
  xor [di],030         ; 3 2 20 22
  add si,bp            ; 2 0  8  3
  jle noAdjust1        ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  sub si,di            ; 2 0  8  3
noAdjust1:
  loop lineLoop2       ; 2 0  8  5/17
  jmp done
lineLoop2:
  xor [di],0c          ; 3 2 20 22
  add si,bp            ; 2 0  8  3
  jle noAdjust2        ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  sub si,di            ; 2 0  8  3
noAdjust2:
  loop lineLoop3       ; 2 0  8  5/17
  jmp done
lineLoop3:
  xor [di],03          ; 3 2 20 22
  inc di               ; 1 0  4  2
  add si,bp            ; 2 0  8  3
  jle noAdjust3        ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  sub si,di            ; 2 0  8  3
noAdjust3:
  loop lineLoop0       ; 2 0  8  5/17
done:

// Unrolled all the way (80 iterations needed @ 45 bytes per = 3600 bytes):
// 13 IOs per pixel
lineLoop0:
  xor [di],dl          ; 2 2 16 21
  add si,bp            ; 2 0  8  3
  jle noAdjust0        ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  sub si,bx            ; 2 0  8  3
noAdjust0:
  xor [di],dh          ; 2 2 16 21
  add si,bp            ; 2 0  8  3
  jle noAdjust1        ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  sub si,bx            ; 2 0  8  3
noAdjust1:
  xor [di],cl          ; 2 2 16 21
  add si,bp            ; 2 0  8  3
  jle noAdjust2        ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  sub si,bx            ; 2 0  8  3
noAdjust2:
  xor [di],ch          ; 2 2 16 21
  inc di               ; 1 0  4  2
  add si,bp            ; 2 0  8  3
  jle noAdjust3        ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  sub si,bx            ; 2 0  8  3
noAdjust3:

// Without using SP:

lineLoop0:
  xor [di],dl          ; 2 2 16 21
  add si,bp            ; 2 0  8  3
  jle noAdjust0        ; 2 0  8  4/16
  add di,8192          ; 2 0  8  3
  sub si,bx            ; 2 0  8  3
  jmp noAdjust0_1
noAdjust0:
  xor [di],dh          ; 2 2 16 21
  add si,bp            ; 2 0  8  3
  jle noAdjust1        ; 2 0  8  4/16
  add di,8192          ; 2 0  8  3
  sub si,bx            ; 2 0  8  3
  jmp noAdjust1_1
noAdjust0_1:
  xor [di],dh          ; 2 2 16 21
  add si,bp            ; 2 0  8  3
  jle noAdjust1_1      ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  sub si,bx            ; 2 0  8  3
noAdjust1:
  xor [di],cl          ; 2 2 16 21
  add si,bp            ; 2 0  8  3
  jle noAdjust2        ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  sub si,bx            ; 2 0  8  3
noAdjust2:
  xor [di],ch          ; 2 2 16 21
  inc di               ; 1 0  4  2
  add si,bp            ; 2 0  8  3
  jle noAdjust3        ; 2 0  8  4/16
  add di,ax            ; 2 0  8  3
  xchg sp,ax           ; 1 0  4  3
  sub si,bx            ; 2 0  8  3
noAdjust3:



// Erase: 12 IOs for 4 pixels (80 iterations needed @ 11 bytes per = 880 bytes):
lineLoop0:
  stosb                ; 1 1  8 11
  add si,bp            ; 2 0  8  3
  jle noAdjust0        ; 2 0  8  4/16
  add di,cx            ; 2 0  8  3
  xchg sp,cx           ; 2 0  8  3
  sub si,bx            ; 2 0  8  3
noAdjust0:


// Averaging 16 IOs per pixel gives us 1244 pixels per frame excluding setup time.
//   Also need to erase, so halve that.
//     Can we make faster line-erase routines?
//       Use same increments


// Draw (horizontal major) lines bottom to top to eliminate "cmp bh,040"


void draw_line(int xP, int yP, int xQ, int yQ)
{
    int x = xP;
    int y = yP;
    int D = 0;
    int dx = xQ - xP;
    int dy = yQ - yP;
    int c;
    int M;
    int xinc = 1;
    int yinc = 1;
    if (dx < 0) { xinc = -1; dx = -dx; }
    if (dy < 0) { yinc = -1; dy = -dy; }
    if (dy < dx) {
        c = 2 * dx;
        M = 2 * dy;
        while (x != xQ) {
            putpix(x, y);
            x += xinc;
            D += M;
            if (D > dx) {
                y += yinc;
                D -= c;
            }
        }
    }
    else {
        c = 2 * dy;
        M = 2 * dx;
        while (y != yQ) {
            putput(x, y);
            y += yinc;
            D += M;
            if (D > dy) {
                x += xinc
                D -= c;
            }
        }
    }
}
