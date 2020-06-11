org 0x100
cpu 8086

pitCyclesPerScanline equ 76     ; Fixed by CGA hardware
scanlinesPerFrame    equ 262    ; Fixed by NTSC standard
activeScanlines      equ 200    ; Standard CGA full-screen
screenSize_x         equ 80     ; Standard CGA full-screen
scanlinesPerRow      equ 2
tileSize_x           equ 8
tileSize_y           equ 16
bufferStride         equ 0x100
mapStride            equ 0x100
xAcceleration        equ 0x10
yAcceleration        equ 0x10
xMaxVelocity         equ 0x100
yMaxVelocity         equ 0x100
updateBufferSize     equ 100
visual_profiler      equ 0

screenWidthBytes     equ screenSize_x*2
bufferTileStride     equ tileSize_y*bufferStride
onScreenPitCycles    equ pitCyclesPerScanline*activeScanlines - 22
offScreenPitCycles   equ pitCyclesPerScanline*scanlinesPerFrame - (onScreenPitCycles)
tileWidthBytes       equ tileSize_x*2
screenSize_y         equ activeScanlines/scanlinesPerRow
upMap                equ 1
downMap              equ 1 + (tilesPerScreen_y + 1)*mapStride
%define bufferPosition(x, y) (tileWidthBytes*(x) + bufferTileStride*(y))
%define mapPosition(x, y)    ((x) + mapStride*(y))
up_leftBuffer               equ bufferPosition(1, 1)
up_leftMap                  equ mapPosition(1, 1)
up_rightBuffer              equ bufferPosition(tilesPerScreen_x, 1)
up_rightMap                 equ mapPosition(tilesPerScreen_x, 1)
down_leftBuffer             equ bufferPosition(1, tilesPerScreen_y)
down_leftMap                equ mapPosition(1, tilesPerScreen_y)
down_rightBuffer            equ bufferPosition(tilesPerScreen_x, tilesPerScreen_y)
down_rightMap               equ mapPosition(tilesPerScreen_x, tilesPerScreen_y)
playerTopLeft               equ yPlayer*bufferStride + xPlayer*2
noneScrollIncrement         equ 0
noneBufferScrollIncrement   equ 0

%include "cpp/u6conv/gameMacros.inc"

; Stomps ax, bx, cx, dx, si, di, bp, es, ds
%macro drawTile 0  ; buffer location in di, map location in bx
  add di,[bufferTL]
  add bx,[mapTL]

  mov es,[bufferSegment]

  %if tileWidthBytes*tileSize_y == 0x100
  mov ds,[foregroundSegment]
  mov ah,[bx]
  mov ds,[cs:backgroundSegment]
  mov bh,[bx]
  mov bl,0
  mov al,0
  xchg ax,si
  %else
  mov ds,[backgroundSegment]
  mov al,[bx]
  mov ds,[cs:foregroundSegment]
  mov bl,[bx]
  mov bh,0
  add bx,bx
  mov si,[cs:tilePointers + bx]
  mov bl,al
  mov bh,0
  add bx,bx
  mov bx,[cs:tilePointers + bx]
  %endif

  mov ds,[cs:tilesSegment]
  mov bp,tileSize_y
  mov dx,bufferStride-tileWidthBytes
  mov ch,0
  %%yLoop:
  mov cl,tileSize_x
  %%xLoop:
  lodsw
  cmp ax,0xffff
  jne %%opaque
  mov ax,[bx]
  %%opaque:
  stosw
  inc bx
  inc bx
  loop %%xLoop
  add di,dx
  dec bp
  jnz %%yLoop
%endmacro

%macro drawPlayer 0
  mov ax,cs
  mov es,ax
  mov si,playerTopLeft + playerDrawInitialOffset
  add si,[bufferTopLeft]
  mov dx,si
  mov di,underPlayer
  mov bx,[bufferSegment]
  mov ds,bx
  playerDraw si

  mov ds,ax
  mov es,bx
  mov di,dx
  mov si,playerSprite
  playerDraw di

  mov byte[redrawPlayer],0
%endmacro

setUpMemory:
  mov ax,cs
  mov ds,ax
  cli
  mov ss,ax
  mov sp,stackHigh
  sti
  mov [soundPointer+2],ax
  mov [musicPointer+2],ax
  mov bx,endPreBuffer
  add bx,15
  mov cl,4
  shr bx,cl
  add ax,bx
  mov [bufferSegment],ax
  add ax,0x1000
  mov [foregroundSegment],ax
  add ax,0x1000
  mov [backgroundSegment],ax
  add ax,0x1000
  mov [tilesSegment],ax
  push ds
  mov bx,0x40
  mov ds,bx
  mov bx,[0x13]
  pop ds
  add ax,0x1000
  mov cl,6
  shl bx,cl
  cmp ax,bx
  jbe .noError
  mov ah,9
  mov dx,memoryError
  int 0x21
  jmp exit
.noError:

loadWorldDat:
  mov dx,worldDat
  mov ax,0x3d00
  int 0x21
  jnc .noError
.error:
  mov ah,9
  mov dx,worldDatError
  int 0x21
  jmp exit
.noError:
  mov bx,ax

  mov ah,0x3f
  mov cx,0x8000
  xor dx,dx
  mov ds,[backgroundSegment]
  int 0x21
  jc .error

  mov ah,0x3f
  mov dx,cx
  int 0x21
  jc .error

  mov ds,[cs:tilesSegment]
  mov ah,0x3f
  xor dx,dx
  int 0x21
  jc .error

  mov ah,0x3f
  mov dx,cx
  int 0x21
  jc .error

  mov ds,[cs:foregroundSegment]
  mov ah,0x3f
  xor dx,dx
  int 0x21
  jc .error

  mov ah,0x3f
  mov dx,cx
  int 0x21
  jc .error

  mov ah,0x3e
  int 0x21

drawInitialScreen:
  xor di,di
  xor bx,bx
  mov cx,tilesPerScreen_y + 2
.yLoop:
  push cx
  mov cx,tilesPerScreen_x + 2
.xLoop:
  push cx
  push bx
  push di
  mov ax,cs
  mov ds,ax
  drawTile
  pop di
  add di,tileWidthBytes
  pop bx
  inc bx
  pop cx
  loop .xLoop
  pop cx
  add bx,mapStride - (tilesPerScreen_x + 2)
  add di,bufferTileStride - tileWidthBytes*(tilesPerScreen_x + 2)
  loop .yLoop
  mov ax,cs
  mov ds,ax
  drawPlayer

  mov ax,0x40
  mov ds,ax
checkMotorShutoff:
  cmp byte[0x40],0
  je noMotorShutoff
  mov byte[0x40],1
  jmp checkMotorShutoff
noMotorShutoff:

  mov ax,cs
  mov ds,ax
  in al,0x61
  or al,3
  out 0x61,al
  or al,0x80
  mov [port61high+1],al
  and al,0x7f
  mov [port61low+1],al

  mov al,0xb6
  out 0x43,al
  mov al,0x02
  out 0x42,al
  mov al,0x00
  out 0x42,al

  in al,0x21
  mov [imr],al
  mov al,0xfe  ; Enable IRQ0 (timer), disable all others
  out 0x21,al

  mov ax,3
  int 0x10
  mov dx,0x3d8
  mov al,1
  out dx,al

  mov ax,cs
  mov ds,ax
  mov es,ax
  mov di,[updatePointer]
  add di,8
  mov ax,offScreenHandlerEnd
  stosw
  mov [updatePointer],di

  mov ax,0xb800
  mov es,ax
  xor di,di
  mov si,[bufferTopLeft]
  mov ds,[bufferSegment]
  mov ax,bufferStride - screenWidthBytes
  mov bx,screenSize_y
  mov bp,screenSize_x
firstDrawY:
  mov cx,bp
  rep movsw
  add si,ax
  dec bx
  jnz firstDrawY

  mov al,9
  out dx,al
  mov dl,0xd4
  mov ax,0x0f03
  out dx,ax
  mov ax,0x7f04
  out dx,ax
  mov ax,0x6406
  out dx,ax
  mov ax,0x7007
  out dx,ax
  mov ax,0x0109
  out dx,ax
  mov dl,0xda
  cli
  xor ax,ax
  mov ds,ax

  mov al,0x0a  ; OCW3 - no bit 5 action, no poll command issued, act on bit 0,
  out 0x20,al  ;  read Interrupt Request Register

  mov al,0x34
  out 0x43,al

%macro setPIT0Count 1
  mov al,(%1) & 0xff
  out 0x40,al
  %if ((%1) & 0xff) != ((%1) >> 8)
  mov al,(%1) >> 8
  %endif
  out 0x40,al
%endmacro

  setPIT0Count 2  ; PIT was reset so we start counting down from 2 immediately

%macro waitForVerticalSync 0
  %%waitForVerticalSync:
    in al,dx
    test al,8
    jz %%waitForVerticalSync       ;         jump if not +VSYNC, finish if +VSYNC
%endmacro

%macro waitForNoVerticalSync 0
  %%waitForNoVerticalSync:
    in al,dx
    test al,8
    jnz %%waitForNoVerticalSync    ;         jump if +VSYNC, finish if -VSYNC
%endmacro

  ; Wait for a while to be sure that IRQ0 is pending
  waitForVerticalSync
  waitForNoVerticalSync
  waitForVerticalSync

waitForDisplayEnable:
  in al,dx
  test al,1
  jnz waitForDisplayEnable

  setPIT0Count onScreenPitCycles

  ; PIT channel 0 is now counting down from onScreenPitCycles in top half of onscreen area and IRQ0 is pending

  mov ax,[0x20]
  mov [cs:oldInterrupt8],ax
  mov ax,[0x22]
  mov [cs:oldInterrupt8+2],ax
  mov word[0x20],transitionHandler
  mov [0x22],cs

  sti
  jmp idle

transitionHandler:
  mov al,0x20
  out 0x20,al

  ; PIT channel 0 is now counting down from onScreenPitCycles in onscreen area

  setPIT0Count offScreenPitCycles

  ; When the next interrupt happens, PIT channel 0 will start counting down from offScreenPitCycles in offscreen area

  mov word[0x20],offScreenHandler
  mov [0x22],cs


  sti

idle:
  hlt
  jmp idle


%macro axisInfo 3
  tilesPerScreen_%1     equ (screenSize_%1 + 2*tileSize_%1 - 2) / tileSize_%1
  %1Player              equ (screenSize_%1 - tileSize_%1)/2
  %define %1Perpendicular %2
  %define %1SubTileReg    %3
  %1Velocity: dw 0
  %1SubTile: dw 0
  db 0  ; So that we can load word[%1SubTile + 1]
%endmacro
axisInfo x, y, dh
axisInfo y, x, bh

%macro directionInfo 4
  %define %1Axis            %2
  %1Total                   equ tilesPerScreen_%[%[%1Axis]Perpendicular]
  %1MidTile                 equ %1Total/2
  %1Increase                equ %3
  %1TileIncrement           equ %3*tileSize_%[%1Axis]
  %ifidn %2,x
    %1MapIncrement          equ %3
    %1BufferIncrement       equ %3*tileWidthBytes
    %1ScrollIncrement       equ %3
    %1BufferScrollIncrement equ %3*2
  %else
    %1MapIncrement          equ %3*mapStride
    %1BufferIncrement       equ %3*bufferTileStride
    %1ScrollIncrement       equ %3*screenSize_x
    %1BufferScrollIncrement equ %3*bufferStride
  %endif
  %1Start: db 0
  %1End: db %1Total
  %1Direction               equ %4
%endmacro
directionInfo left, x, -1, 2
directionInfo up, y, -1, 4
directionInfo right, x, 1, 8
directionInfo down, y, 1, 0x10


%assign i 1
%rep screenSize_x
  %assign plotterHeights%[i] 0
  %assign updaterHeights%[i] 0
  %assign i i+1
%endrep

%macro makeUpdater 2.nolist  ;  width height
  %if %2 > updaterHeights%[%1]
    %assign updaterHeights%[%1] %2
  %endif
%endmacro

worldDat: db 'world.dat',0
worldDatError: db 'Error reading world.dat file.$'
memoryError: db 'Not enough memory.$'
oldInterrupt8: dw 0, 0
frameCount: dw 0, 0
soundPointer: dw silent, 0
musicPointer: dw demoMusicStart, 0
startAddress: dw 0
vramTopLeft: dw 0
bufferTopLeft: dw up_leftBuffer
bufferTL: dw 0
mapTL: dw 0x8080  ; Start location
oldMapTL: dw 0
soundEnd: dw silent+2
soundStart: dw silent
;musicEnd: dw silent+2
;musicStart: dw silent
musicEnd: dw demoMusicEnd
musicStart: dw demoMusicStart
silent: dw 20
bufferSegment: dw 0
foregroundSegment: dw 0
backgroundSegment: dw 0
tilesSegment: dw 0
imr: db 0
shifts: db 1,2,4,8,0x10,0x20,0x40,0x80
directionTable:
  db             0,                 rightDirection, -1,                 leftDirection
  db downDirection, downDirection | rightDirection, -1, downDirection | leftDirection
  db            -1,                             -1, -1,                            -1
  db   upDirection,   upDirection | rightDirection, -1,   upDirection | leftDirection
keyboardFlags: times 16 db 0
updatePointer: dw updateBufferStart
direction: dw 0
tileDirection: dw 0
redrawPlayer: db 0
tileModificationPointer: dw 0
xSubTileHighOld: db 0
ySubTileHighOld: db 0
landed: db 0

%macro linear 4
  %1:
  %assign i %3
  %rep %2
    dw i
  %assign i i + %4
  %endrep
%endmacro

linear leftBuffer, leftTotal, bufferTileStride, bufferTileStride
linear leftMap, leftTotal, mapStride, mapStride
linear upBuffer, upTotal, tileWidthBytes, tileWidthBytes
;linear upMap, upTotal, 1, 1
linear rightBuffer, rightTotal, (tilesPerScreen_x + 1)*tileWidthBytes + bufferTileStride, bufferTileStride
linear rightMap, rightTotal, tilesPerScreen_x + 1 + mapStride, mapStride
linear downBuffer, downTotal, (tilesPerScreen_y + 1)*bufferTileStride + tileWidthBytes, tileWidthBytes
;linear downMap, downTotal, (tilesPerScreen_y + 1)*mapStride + 1, 1

%macro positive 1
  %if %1 < 0
    db 0
  %else
    db %1
  %endif
%endmacro

leftTransitionCount:
%assign i 0
%rep tileSize_x
positive (tileSize_x - i)*(tilesPerScreen_y + 1)/tileSize_x - 1
%assign i i + 1
%endrep

upTransitionCount:
%assign i 0
%rep tileSize_y
positive (tileSize_y - i)*(tilesPerScreen_x + 1)/tileSize_y - 1
%assign i i + 1
%endrep

rightTransitionCount:
%assign i 0
%rep tileSize_x
positive (1 + i)*(tilesPerScreen_y + 1)/tileSize_x - 1
%assign i i + 1
%endrep

downTransitionCount:
%assign i 0
%rep tileSize_y
positive (1 + i)*(tilesPerScreen_x + 1)/tileSize_y - 1
%assign i i + 1
%endrep

%if tileWidthBytes*tileSize_y != 0x100
linear tilePointers, 0x100, 0, tileWidthBytes*tileSize_y
%endif

offScreenHandler:
  mov al,0x20
  out 0x20,al

%if visual_profiler!=0
    mov al,14
    mov dx,0x3d9
    out dx,al
%endif

  xor ax,ax
  mov ds,ax
  mov word[0x20],onScreenHandler

  setPIT0Count onScreenPitCycles

  lds si,[cs:musicPointer]
  lodsw
  out 0x42,al
  mov al,ah
  out 0x42,al
  cmp si,[musicEnd]
  jne noRestartMusic
  mov si,[musicStart]
noRestartMusic:
  mov [musicPointer],si

  mov ax,cs
  mov ss,ax
  mov sp,updateBufferStart
  mov ax,0xb800
  mov es,ax
  mov ds,[bufferSegment]
  mov ch,0
  pop si
  pop di
  pop bx
  pop dx
  ret

offScreenHandlerEnd:
%if visual_profiler!=0
    mov al,15
    mov dx,0x3d9
    out dx,al
%endif
  mov sp,stackHigh
  sti
  jmp idle


onScreenHandler:
  push cx
  push bx
  push di
  push si
  mov al,0x20
  out 0x20,al
%if visual_profiler!=0
    mov al,1
    mov dx,0x3d9
    out dx,al
%endif

  xor ax,ax
  mov ds,ax
  mov word[0x20],offScreenHandler

  setPIT0Count offScreenPitCycles

  lds si,[cs:soundPointer]
  lodsw
  out 0x42,al
  mov al,ah
  out 0x42,al
  cmp si,[soundEnd]
  jne noRestartSound
  mov si,[soundStart]
noRestartSound:
  mov [soundPointer],si

  inc word[frameCount]
  jnz noFrameCountCarry
  inc word[frameCount+2]
noFrameCountCarry:

  mov word[updatePointer],updateBufferStart

checkKey:
  in al,0x20
  and al,2    ; Check for IRR bit 1 (IRQ 1) high
  jz noKey
  ; Read the keyboard byte and store it
  in al,0x60
  xchg ax,bx
  ; Acknowledge the previous byte
port61high:
  mov al,0xcf
  out 0x61,al
port61low:
  mov al,0x4f
  out 0x61,al

  mov al,bl
  and bx,7
  mov dl,[shifts+bx]
  mov bl,al
  shr bl,1
  shr bl,1
  shr bl,1
  and bl,0x0f
  test al,0x80
  jz keyPressed
  not dl
  and [keyboardFlags+bx],dl
;  jmp checkKey
    jmp noKey
keyPressed:
  or [keyboardFlags+bx],dl
;  jmp checkKey

; keyboardFlags    1     2      4    8  0x10   0x20      0x40 0x80

;  0                   Esc      1    2     3      4         5    6
;  1               7     8      9    0     -      = Backspace  Tab
;  2               Q     W      E    R     T      Y         U    I
;  3               O     P      [    ] Enter   Ctrl         A    S
;  4               D     F      G    H     J      K         L    ;
;  5               '     ` LShift    \     Z      X         C    B
;  6               B     N      M    ,     .      /    RShift  KP*
;  7             Alt Space   Caps   F1    F2     F3        F4   F5
;  8              F6    F7     F8   F9   F10    Num    Scroll Home
;  9              Up  PgUp    KP- Left   KP5  Right       KP+  End
; 10            Down  PgDn    Ins  Del                         F11
; 11             F12

noKey:
%if visual_profiler!=0
    mov al,2
    mov dx,0x3d9
    out dx,al
%endif
  mov ax,[xVelocity]
  test byte[keyboardFlags+9],8
  jz leftNotPressed
  test byte[keyboardFlags+9],0x20
  jnz noHorizontalAcceleration
  ; Speed up leftwards
  sub ax,xAcceleration
  cmp ax,-xMaxVelocity
  jge doneHorizontalAcceleration
  mov ax,-xMaxVelocity
  jmp doneHorizontalAcceleration
leftNotPressed:
  test byte[keyboardFlags+9],0x20
  jz rightNotPressed
  ; Speed up rightwards
  add ax,xAcceleration
  cmp ax,xMaxVelocity
  jle doneHorizontalAcceleration
  mov ax,xMaxVelocity
  jmp doneHorizontalAcceleration
rightNotPressed:
  ; Slow down
  cmp ax,0
  jl slowDownLeftwards
  sub ax,xAcceleration
  jge doneHorizontalAcceleration
stopHorizontal:
  xor ax,ax
  jmp noHorizontalAcceleration
slowDownLeftwards:
  add ax,xAcceleration
  jg stopHorizontal
doneHorizontalAcceleration:
  mov [xVelocity],ax
noHorizontalAcceleration:
  mov dx,[xSubTile]
  mov cl,dh
  add dx,ax
  mov [xSubTile],dx

;  mov ax,[yVelocity]
;  test byte[keyboardFlags+9],1
;  jz upNotPressed
;  test byte[keyboardFlags+10],1
;  jnz noVerticalAcceleration
;  ; Speed up upwards
;  sub ax,yAcceleration
;  cmp ax,-yMaxVelocity
;  jge doneVerticalAcceleration
;  mov ax,-yMaxVelocity
;  jmp doneVerticalAcceleration
;upNotPressed:
;  test byte[keyboardFlags+10],1
;  jz downNotPressed
;  ; Speed up downwards
;  add ax,yAcceleration
;  cmp ax,yMaxVelocity
;  jle doneVerticalAcceleration
;  mov ax,yMaxVelocity
;  jmp doneVerticalAcceleration
;downNotPressed:
;  ; Slow down
;  cmp ax,0
;  jl slowDownUpwards
;  sub ax,yAcceleration
;  jge doneVerticalAcceleration
;stopVertical:
;  xor ax,ax
;  jmp noVerticalAcceleration
;slowDownUpwards:
;  add ax,yAcceleration
;  jg stopVertical
;doneVerticalAcceleration:
;  mov [yVelocity],ax
;noVerticalAcceleration:

  mov ax,[yVelocity]
  add ax,4
  cmp ax,0x100
  jle notTerminalVelocity
  mov ax,0x100
notTerminalVelocity:
  cmp byte[landed],0
  je noJump
  test byte[keyboardFlags+7],2
  jz noJump
  mov ax,-0x100
noJump:
  mov [yVelocity],ax

  mov bx,[ySubTile]
  mov ch,bh
  add bx,ax
  mov [ySubTile],bx

  cmp bh,ch
  je noResetLanded
  mov byte[landed],0
noResetLanded:

  mov ax,[mapTL]
  mov [oldMapTL],ax
  mov [xSubTileHighOld],cx
  mov word[tileModificationPointer],tileModificationBufferStart

%macro restartCollisionLoop 0
  mov dh,[xSubTile+1]
  mov bh,[ySubTile+1]
  mov cx,[xSubTileHighOld]
  jmp normalize
%endmacro

  ; The collision loop may run more than once as a position correction from
  ; hitting a hard object may push the player into another object. However,
  ; we should design our levels and collision routines such that the loop
  ; does not run more than twice.
normalize:
  cmp dh,tileSize_x
  jge .right
  cmp dh,0
  jnl .notLeft
  mov dh,tileSize_x - 1
  mov [xSubTile+1],dh
  cmp bh,tileSize_y
  jge .leftDown
  cmp bh,0
  jnl .leftNotUp
  mov bh,tileSize_y - 1
  mov [ySubTile+1],bh
  sub word[mapTL],mapStride + 1
  jmp .done
.leftNotUp:
  dec word[mapTL]
  jmp .done
.leftDown:
  mov bh,0
  mov [ySubTile+1],bh
  add word[mapTL],mapStride - 1
  jmp .done
.notLeft:
  cmp bh,tileSize_y
  jge .down
  cmp bh,0
  jnl .notUp
  mov bh,tileSize_y - 1
  mov [ySubTile+1],bh
  sub word[mapTL],mapStride
  jmp .done
.notUp:
  jmp .done
.down:
  mov bh,0
  mov [ySubTile+1],bh
  add word[mapTL],mapStride
  jmp .done
.right:
  mov dh,0
  mov [xSubTile+1],dh
  cmp bh,tileSize_y
  jge .rightDown
  cmp bh,0
  jnl .rightNotUp
  mov bh,tileSize_y - 1
  mov [ySubTile+1],bh
  sub word[mapTL],mapStride - 1
  jmp .done
.rightNotUp:
  inc word[mapTL]
  jmp .done
.rightDown:
  mov bh,0
  mov [ySubTile+1],bh
  add word[mapTL],mapStride + 1
.done:

%if visual_profiler!=0
    push dx
    mov al,3
    mov dx,0x3d9
    out dx,al
    pop dx
%endif

  mov al,dh
  sub al,cl
  and al,3
  mov bl,bh
  sub bl,ch
  and bl,3
  mov bh,0
  add bx,bx
  add bx,bx
  add bx,directionTable
  xlatb
  mov [direction],al

%if visual_profiler!=0
    push dx
    mov al,4
    mov dx,0x3d9
    out dx,al
    pop dx
%endif

%macro checkPlayerTileCollision 2  ; x, y  (tileNumber to collide with in bl)
  mov bh,0
  add bx,bx
  mov bp,bx
  mov dx,[collisionMasks+bx]

  mov bx,[xSubTile+1]
  %if %1==0
    mov cl,[leftCollisionTable+bx]
    mov ch,cl
  %else
    mov cl,[rightCollisionTable+bx]
    mov ch,cl
  %endif
  add bx,bx
  mov si,[playerMaskOffsetForX+bx]

  mov bx,[ySubTile+1]
  %if %2==0
    add bx,bx
    mov ax,[collisionTableUp+bx]
  %else
    mov al,[collisionDownAdjust+bx]
    cbw
    add dx,ax
    sub si,ax
    add bx,bx
    mov ax,[collisionTableDown+bx]
  %endif

  mov bx,dx
  xor dx,dx
  call ax

%endmacro

%if visual_profiler!=0
    mov al,5
    mov dx,0x3d9
    out dx,al
%endif

  mov bl,[xSubTile+1]
  mov bh,0
  %if mapStride != 0x100
    %error "Collision handling needs to be changed to handle map strides other than 0x100."
  %endif
  mov al,[xSubTileToMapOffset+bx]
  mov bl,[ySubTile+1]
  mov ah,[ySubTileToMapOffset+bx]
  mov di,[mapTL]
  add di,ax
  %if tileSize_x != 8
    %error "Collision handling needs to be changed to handle tile widths other than 8."
  %endif

  mov es,[foregroundSegment]
  mov bl,[es:di]
  checkPlayerTileCollision 0, 0
  inc di
  mov bl,[es:di]
  checkPlayerTileCollision 1, 0
  add di,mapStride - 1
collisionLower:
  mov bl,[es:di]
  checkPlayerTileCollision 0, 1
  inc di
  mov bl,[es:di]
  checkPlayerTileCollision 1, 1

%if visual_profiler!=0
    mov al,6
    mov dx,0x3d9
    out dx,al
%endif

calculateTileDirection:
  mov ax,[mapTL]
  sub ax,[oldMapTL]
  cmp ax,0
  jl .negative
  jg .positive
  mov byte [tileDirection],0
  jmp .done
.negative:
  cmp ax,-mapStride
  jl .upLeft
  jg .upRightOrLeft
  mov byte[tileDirection],upDirection
  jmp .done
.upLeft:
  mov byte[tileDirection],upDirection | leftDirection
  jmp .done
.upRightOrLeft:
  cmp ax,-1
  jl .upRight
  mov byte[tileDirection],leftDirection
  jmp .done
.upRight:
  mov byte[tileDirection],upDirection | rightDirection
  jmp .done
.positive:
  cmp ax,mapStride
  jl .downLeftOrRight
  jg .downRight
  mov byte[tileDirection],downDirection
  jmp .done
.downLeftOrRight:
  cmp ax,1
  jg .downLeft
  mov byte[tileDirection],rightDirection
  jmp .done
.downLeft:
  mov byte[tileDirection],downDirection | leftDirection
  jmp .done
.downRight:
  mov byte[tileDirection],downDirection | rightDirection
.done:


%macro twice 1.nolist
  %1
  %1
%endmacro

%macro addConstantHelper 3.nolist
  %ifidni %1,ax
    twice {%3 %1}
  %elifidni %1,bx
    twice {%3 %1}
  %elifidni %1,cx
    twice {%3 %1}
  %elifidni %1,dx
    twice {%3 %1}
  %elifidni %1,si
    twice {%3 %1}
  %elifidni %1,di
    twice {%3 %1}
  %elifidni %1,sp
    twice {%3 %1}
  %elifidni %1,bp
    twice {%3 %1}
  %else
    add %1,%2
  %endif
%endmacro

%macro addConstant 2.nolist
  %if %2==2
    addConstantHelper %1, %2, inc
  %elif %2==-2
    addConstantHelper %1, %2, dec
  %elif %2==1
    inc %1
  %elif %2==-1
    dec %1
  %elif %2!=0
    add %1,%2
  %endif
%endmacro

%macro fillEdge 1
  mov byte[%1Start],0
  mov byte[%1End],%1Total
%endmacro

%macro emptyEdge 2
  %if %2==-1
    mov byte[%1Start],%1Total
    mov byte[%1End],%1Total
  %elif %2==1
    mov byte[%1Start],0
    mov byte[%1End],0
  %else
    mov byte[%1Start],%1MidTile
    mov byte[%1End],%1MidTile
  %endif
%endmacro

%macro incrementBound 2
  cmp byte[%1%2],%1Total
  jge %%noIncrement
  inc byte[%1%2]
  %%noIncrement:
%endmacro

%macro incrementEdge 1
  incrementBound %1,Start
  incrementBound %1,End
  mov al,[%1Start]
  cmp al,[%1End]
  jne %%noClear
  emptyEdge %1,1
  %%noClear:
%endmacro

%macro decrementBound 2
  cmp byte[%1%2],0
  jle %%noDecrement
  dec byte[%1%2]
  %%noDecrement:
%endmacro

%macro decrementEdge 1
  decrementBound %1,Start
  decrementBound %1,End
  mov al,[%1Start]
  cmp al,[%1End]
  jne %%noClear
  emptyEdge %1,-1
  %%noClear:
%endmacro

%macro drawTile2 2
  mov di,%1
  mov bx,%2
  drawTile
  mov ax,cs
  mov ds,ax
%endmacro

%macro doTileBoundary 1
  add word[bufferTL],%1BufferIncrement
  emptyEdge %1,0
  %ifidn %1,left
    fillEdge right
    incrementEdge up
    incrementEdge down
  %endif
  %ifidn %1,up
    fillEdge down
    incrementEdge left
    incrementEdge right
  %endif
  %ifidn %1,right
    fillEdge left
    decrementEdge up
    decrementEdge down
  %endif
  %ifidn %1,down
    fillEdge up
    decrementEdge left
    decrementEdge right
  %endif
%endmacro

%if visual_profiler!=0
    mov al,7
    mov dx,0x3d9
    out dx,al
%endif

  test byte[tileDirection],rightDirection
  jz noTileRight
  doTileBoundary right
  jmp checkTileVertical
noTileRight:
  test byte[tileDirection],leftDirection
  jz checkTileVertical
  doTileBoundary left
checkTileVertical:
  test byte[tileDirection],downDirection
  jz noTileDown
  doTileBoundary down
  jmp checkTileDiagonal
noTileDown:
  test byte[tileDirection],upDirection
  jz checkTileDiagonal
  doTileBoundary up
checkTileDiagonal:

  mov bx,[tileDirection]
  jmp [tileDiagonalTable + bx]
tileDiagonalTable:
  dw noTileDiagonal
  dw noTileDiagonal
  dw noTileDiagonal
  dw tileDiagonalUpLeft
  dw noTileDiagonal
  dw 0
  dw tileDiagonalUpRight
  dw 0
  dw noTileDiagonal
  dw tileDiagonalDownLeft
  dw 0
  dw 0
  dw tileDiagonalDownRight
tileDiagonalUpLeft:
  drawTile2 up_leftBuffer, up_leftMap
  jmp noTileDiagonal
tileDiagonalUpRight:
  drawTile2 up_rightBuffer, up_rightMap
  jmp noTileDiagonal
tileDiagonalDownLeft:
  drawTile2 down_leftBuffer, down_leftMap
  jmp noTileDiagonal
tileDiagonalDownRight:
  drawTile2 down_rightBuffer, down_rightMap
  jmp noTileDiagonal
noTileDiagonal:

%if visual_profiler!=0
    mov al,8
    mov dx,0x3d9
    out dx,al
%endif

  cmp byte[direction],0
  je stopped
  mov byte[redrawPlayer],1
stopped:
  cmp byte[redrawPlayer],0
  jz noPlayerRestore

  mov es,[bufferSegment]
  mov di,playerTopLeft + playerDrawInitialOffset
  add di,[bufferTopLeft]
  mov si,underPlayer
  playerDraw di
noPlayerRestore:

%macro addUpdateBlock 4  ; left top width height
  %assign width %3
  %assign height %4
  mov di,[updatePointer]
  mov ax,[bufferTopLeft]
  add ax,(%1)*2 + (%2)*bufferStride
  stosw                              ; source top-left
  mov ax,[vramTopLeft]
  add ax,(%1)*2 + (%2)*screenWidthBytes
  stosw                              ; destination top-left
  mov ax,screenWidthBytes - 2*width
  stosw                              ; destination add
  mov ax,bufferStride - 2*width
  stosw                              ; source add
  makeUpdater width, height
  mov ax,updater%[width]_%[height]
  stosw                              ; code chunk (encodes width and height)
  mov [updatePointer],di
%endmacro

%macro addTileUpdateBlock 0  ; ax = buffer position, width = tileSize_x, height = tileSize_y
  %assign width tileSize_x
  %assign height tileSize_y
  mov di,[updatePointer]
  add ax,[bufferTL]
  stosw                              ; source top-left
  sub ax,[bufferTopLeft]
  xor bx,bx
  xchg bl,ah
  add bx,bx
  add ax,[rowToVRAM + bx]
  add ax,[vramTopLeft]
  stosw
  mov ax,screenWidthBytes - tileWidthBytes
  stosw
  mov ax,bufferStride - tileWidthBytes
  stosw
  makeUpdater width, height
  mov ax,updater%[width]_%[height]
  stosw
  mov [updatePointer],di
%endmacro

%macro ensureEnoughTiles 1
  %%loopTop:
  mov al,[%1End]
  sub al,[%1Start]
  mov bl,[%[%1Axis]SubTile+1]
  mov bh,0
  cmp al,[%1TransitionCount + bx]
  jge %%enoughTiles
  cmp word[%[%[%1Axis]Perpendicular]Velocity],0
  jl %%decreasing

  cmp byte[%1End],%1Total
  jge %%useEarlier
  %%useLater:
  mov bl,[%1End]
  inc byte[%1End]
  jmp %%doDraw
  %%decreasing:
  cmp byte[%1Start],0
  jle %%useLater
  %%useEarlier:
  dec byte[%1Start]
  mov bl,[%1Start]
  %%doDraw:
  %ifidn %1,up
  lea ax,[bx+1]
  add bx,bx
  mov di,[bx+%1Buffer]
  xchg ax,bx
  %elifidn %1,down
  lea ax,[bx+(tilesPerScreen_y + 1)*mapStride + 1]
  add bx,bx
  mov di,[bx+%1Buffer]
  xchg ax,bx
  %else
  add bx,bx
  mov di,[bx+%1Buffer]
  mov bx,[bx+%1Map]
  %endif
  drawTile
  mov ax,cs
  mov ds,ax
  jmp %%loopTop
  %%enoughTiles:
%endmacro

%macro checkTileBoundary1 2
  %ifnidn %1,none
    %if %1Increase==1
      cmp %[%1Axis]SubTileReg,tileSize_%[%1Axis]
      jl %%noTileBoundary
    %else
      cmp %[%1Axis]SubTileReg,0
      jge %%noTileBoundary
    %endif
    doTileBoundary %1
    %2
    %%noTileBoundary:
  %endif
%endmacro

%macro diagonal 2
  checkTileBoundary1 %2, {drawTile2 %1_%2Buffer, %1_%2Map}
%endmacro

%macro checkTileBoundary 2
  %ifnidn %1,none
    %if %1Increase==1
      cmp %[%1Axis]SubTileReg,%1TileIncrement
      jl %%noTileBoundary
    %else
      cmp %[%1Axis]SubTileReg,0
      jge %%noTileBoundary
    %endif
    doTileBoundary %1
    %2
    %%noTileBoundary:
  %endif
%endmacro

%macro scroll 2                  ; %1 == up/down/none, %2 == left/right/none
  addConstant word[startAddress],%1ScrollIncrement + %2ScrollIncrement
  mov ax,[vramTopLeft]
  addConstant ax,2*(%1ScrollIncrement + %2ScrollIncrement)
  and ax,0x3fff
  mov [vramTopLeft],ax
  addConstant word[bufferTopLeft],%1BufferScrollIncrement + %2BufferScrollIncrement
  mov ax,cs
  mov es,ax
  %ifidn %2,left
    addUpdateBlock 0, 0, 1, screenSize_y
    %ifidn %1,up
      addUpdateBlock 1, 0, screenSize_x - 1, 1
      addUpdateBlock xPlayer, yPlayer, tileSize_x + 1, tileSize_y + 1
    %elifidn %1,none
      addUpdateBlock xPlayer, yPlayer, tileSize_x + 1, tileSize_y
    %else
      addUpdateBlock 1, screenSize_y - 1, screenSize_x - 1, 1
      addUpdateBlock xPlayer, yPlayer - 1, tileSize_x + 1, tileSize_y + 1
    %endif
  %elifidn %2,none
    %ifidn %1,up
      addUpdateBlock 0, 0, screenSize_x, 1
      addUpdateBlock xPlayer, yPlayer, tileSize_x, tileSize_y + 1
    %elifidn %1,none
    %else
      addUpdateBlock 0, screenSize_y - 1, screenSize_x, 1
      addUpdateBlock xPlayer, yPlayer - 1, tileSize_x, tileSize_y + 1
    %endif
  %else
    addUpdateBlock screenSize_x - 1, 0, 1, screenSize_y
    %ifidn %1,up
      addUpdateBlock 0, 0, screenSize_x - 1, 1
      addUpdateBlock xPlayer - 1, yPlayer, tileSize_x + 1, tileSize_y + 1
    %elifidn %1,none
      addUpdateBlock xPlayer - 1, yPlayer, tileSize_x + 1, tileSize_y
    %else
      addUpdateBlock 0, screenSize_y - 1, screenSize_x, 1
      addUpdateBlock xPlayer - 1, yPlayer - 1, tileSize_x + 1, tileSize_y + 1
    %endif
  %endif
  %ifnidn %1_%2,none_none
    %ifnidn %2,left
      ensureEnoughTiles right
    %endif
    %ifnidn %1,up
      ensureEnoughTiles down
    %endif
    %ifnidn %2,right
      ensureEnoughTiles left
    %endif
    %ifnidn %1,down
      ensureEnoughTiles up
    %endif
  %endif
%endmacro

%if visual_profiler!=0
    mov al,9
    mov dx,0x3d9
    out dx,al
%endif

  mov bx,[direction]
  jmp [scrollTable + bx]
scrollTable:
  dw scrollNone
  dw scrollLeft
  dw scrollUp
  dw scrollUpLeft
  dw scrollRight
  dw 0
  dw scrollUpRight
  dw 0
  dw scrollDown
  dw scrollDownLeft
  dw 0
  dw 0
  dw scrollDownRight
scrollLeft:
  scroll none, left
  jmp scrollNone
scrollUp:
  scroll up, none
  jmp scrollNone
scrollUpLeft:
  scroll up, left
  jmp scrollNone
scrollRight:
  scroll none, right
  jmp scrollNone
scrollUpRight:
  scroll up, right
  jmp scrollNone
scrollDown:
  scroll down, none
  jmp scrollNone
scrollDownLeft:
  scroll down, left
  jmp scrollNone
scrollDownRight:
  scroll down, right
scrollNone:

%if visual_profiler!=0
    mov al,10
    mov dx,0x3d9
    out dx,al
%endif

  mov si,tileModificationBufferStart
checkTileModifications:
  cmp si,[tileModificationPointer]
  je doneTileModifications
  lodsw
  inc si  ; Ignore tile number for now. Eventually use it to optimize draw and update
  push si
  sub ax,[mapTL]
  mov di,ax
  %if bufferStride != 0x100
    %error "Collision handling needs to be modified to handle buffer strides other than 0x100."
  %endif
  %if mapStride != 0x100
    %error "Collision handling needs to be changed to handle map strides other than 0x100."
  %endif
  mov bl,al
  mov bh,0
  mov al,[mapToBufferX+bx]
  mov bl,ah
  mov ah,[mapToBufferY+bx]
  xchg ax,di
  xchg bx,ax
  push di
  drawTile
  mov ax,cs
  mov ds,ax
  mov es,ax
  pop ax                   ; == b  (add bufferTL to this to get actual buffer address)
  addTileUpdateBlock
  pop si
  jmp checkTileModifications
doneTileModifications:

%if visual_profiler!=0
    mov al,11
    mov dx,0x3d9
    out dx,al
%endif

  cmp byte[redrawPlayer],0
  je skipRedrawPlayer
  drawPlayer
skipRedrawPlayer:

%if visual_profiler!=0
    mov al,12
    mov dx,0x3d9
    out dx,al
%endif

  mov ax,cs
  mov ds,ax
  mov es,ax
  mov di,[updatePointer]
  add di,8
  mov ax,offScreenHandlerEnd
  stosw
  mov [updatePointer],di

%if visual_profiler!=0
    mov al,13
    mov dx,0x3d9
    out dx,al
%endif

  mov ax,cs
  mov ds,ax
  mov dx,0x3d4
  mov al,0x0c
  mov ah,[startAddress+1]
  out dx,ax
  inc ax
  mov ah,[startAddress]
  out dx,ax

%if visual_profiler!=0
    mov al,0
    mov dx,0x3d9
    out dx,al
%endif

  sti

  test byte[keyboardFlags],2
  jz idle


teardown:
  xor ax,ax
  mov ds,ax
  cli
  mov ax,[cs:oldInterrupt8]
  mov [0x20],ax
  mov ax,[cs:oldInterrupt8+2]
  mov [0x22],ax
  sti

  in al,0x61
  and al,0xfc
  out 0x61,al

  mov ax,cs
  mov ds,ax
  mov al,[imr]
  out 0x21,al

  setPIT0Count 0

  mov ax,3
  int 0x10

  mov ax,19912
  mul word[frameCount]
  mov cx,dx
  mov ax,19912
  mul word[frameCount+2]
  add ax,cx
  adc dx,0
  mov cx,0x40
  mov ds,cx
  add [0x6c],ax
  adc [0x6e],dx
dateLoop:
  cmp word[0x6c],0x18
  jb doneDateLoop
  cmp word[0x6e],0xb0
  jb doneDateLoop
  mov byte[0x70],1
  sub word[0x6c],0xb0
  sbb word[0x6e],0x18
  jmp dateLoop
doneDateLoop:
exit:
  mov ax,0x4c00
  int 0x21


%assign i tileSize_y
%rep tileSize_y/2
collisionTest%[i]:
  lodsw
  and ax,[bx+tileSize_y-i]
  or dx,ax
  %assign i i-2
%endrep
  test dx,cx
  jnz collided
collisionTest0:
  ret
%assign i tileSize_y-1
%rep (tileSize_y-1)/2
collisionTest%[i]:
  lodsw
  and ax,[bx+tileSize_y-i]
  or dx,ax
  %assign i i-2
%endrep
collisionTest1:
  lodsb
  and al,[bx+tileSize_y-1]
  or dl,al
  test dx,cx
  jnz collided
  ret
collided:
  jmp word[collisionHandlers + bp]

collisionTable:
%assign i 0
%rep tileSize_y+1
  dw collisionTest%[i]
  %assign i i+1
%endrep

leftCollisionTable:
%assign i 0
%rep tileSize_x
  db (0xff << ((i + xPlayer) & 7)) & 0xff
  %assign i i+1
%endrep

rightCollisionTable:
%assign i 0
%rep tileSize_x
  db (~(0xff << ((i + xPlayer) & 7))) & 0xff
  %assign i i+1
%endrep

playerMaskOffsetForX:
  %assign i 0
  %rep 8
    dw collisionData + i
    %assign i i+tileSize_y
  %endrep

collisionTableUp:
%assign i 0
%rep tileSize_y
  %assign p tileSize_y - (yPlayer + i) % tileSize_y
  dw collisionTest%[p]
  %assign i i+1
%endrep

collisionTableDown:
%assign i 0
%rep tileSize_y
  %assign p (yPlayer + i) % tileSize_y
  dw collisionTest%[p]
  %assign i i+1
%endrep

collisionDownAdjust:
%assign i 0
%rep tileSize_y
  db (yPlayer + i)%tileSize_y - tileSize_y
  %assign i i+1
%endrep

xSubTileToMapOffset:
%assign i 0
%rep tileSize_x
  db (xPlayer + i)/tileSize_x + 1
  %assign i i+1
%endrep

ySubTileToMapOffset:
%assign i 0
%rep tileSize_y
  db (yPlayer + i)/tileSize_y + 1
  %assign i i+1
%endrep

rowToVRAM:
%assign i 0
%rep screenSize_y
  dw i
  %assign i i+160
%endrep

mapToBufferX:
%assign i 0
%rep tilesPerScreen_x
  db i
  %assign i i+tileWidthBytes
%endrep

mapToBufferY:
%assign i 0
%rep tilesPerScreen_y
  db i
  %assign i i+bufferTileStride/0x100
%endrep

yFromSubTileY:
%assign i 0
%rep tileSize_y
  db (yPlayer + i)%tileSize_y
  %assign i i+1
%endrep



%macro addTileModification 1       ; map location in di, tile number in %1
  mov si,[tileModificationPointer]
  mov [si],di
  mov byte[si+2],%1
  add si,3
  mov [tileModificationPointer],si
%endmacro

collisionHandlerCoin:
  mov byte[es:di],0xff
  addTileModification 6
  mov byte[redrawPlayer],1
  mov word[soundPointer],coinSoundStart
  mov word[soundStart],coinSoundEnd
  mov word[soundEnd],coinSoundEnd+2
  ret

collisionHandlerPlatform:
  cmp word[yVelocity],0
  jle .done
  pop ax                ; Look at the return address to figure out which of the tile positions we're colliding with
  push ax
  cmp ax,collisionLower
  jb .done
  mov bx,[ySubTile+1]
  cmp byte[bx+yFromSubTileY],3
  jg .done
  mov word[yVelocity],0
  mov byte[landed],1
  dec byte[ySubTile+1]
  restartCollisionLoop
.done:
  ret

%assign i 1
%rep screenSize_x
  %assign n updaterHeights%[i]
  %if n > 0
    %assign j 0
    %rep n
      %assign y n-j
      updater%[i]_%[y]:
      %if i < 12
        times i movsw
      %else
        mov cl,i
        rep movsw
      %endif
      %if j < n - 1
        %if i != screenSize_x
          add di,bx
        %endif
        add si,dx
      %endif
      %assign j j+1
    %endrep
    pop si
    pop di
    pop bx
    pop dx
    ret
  %endif

  %assign i i+1
%endrep

%include "cpp/u6conv/collisionData.inc"

coinSoundStart:
  dw 2489,2489,1976,1976,1661,1661,1245,1245,1245,1245
coinSoundEnd:
  dw 20

demoMusicStart:
incbin "../../../projects/code/8088mph/sound/music.pit"
demoMusicEnd:

section .bss

stackLow:
  resb 4096
stackHigh:
  resb 128
updateBufferStart:
  resb updateBufferSize
underPlayer:
  resb tileWidthBytes*tileSize_y
tileModificationBufferStart:
  resb 4*3
endPreBuffer:

