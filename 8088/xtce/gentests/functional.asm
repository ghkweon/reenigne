org 0
cpu 8086

test0:
  dw 0     ; cycle count ignored (computed by emulator)
  db 0x40  ; No queuefiller, no NOPs
  db 0     ; Refresh period
  db 0     ; Refresh phase
  db .preambleEnd - ($+1)
.preambleEnd:
  db .instructionsEnd - ($+1)

  in al,0x61
  or al,1
  out 0x61,al
  mov al,0x94
  out 0x43,al
  mov al,2
  out 0x42,al

  in al,0x62
  mov ah,al
  in al,0x62
  mov bl,al
  in al,0x62
  mov bh,al
  in al,0x62
  mov cl,al
  in al,0x62
  mov ch,al
  in al,0x62
  mov dl,al
  in al,0x62
  mov dh,al
  in al,0x62

  and ax,0x0202
  cmp ax,0x0202
  jne .fail
  and bx,0x0202
  cmp ax,0x0202
  jne .fail
  and cx,0x0202
  cmp cx,0x0000
  jne .fail
  and dx,0x0202
  cmp dx,0x0000
  jne .fail
  int 0xff
.fail:
  int 0xfe

.instructionsEnd:
  db .fixupsEnd - ($+1)
.fixupsEnd:

