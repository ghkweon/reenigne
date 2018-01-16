  %include "../../defaults_bin.asm"

ITERS EQU 8
LENGTH EQU 2048

%macro outputByte 0
%rep 8
  rcr dx,1
  sbb bx,bx
  mov bl,[cs:lut+1+bx]
  mov bh,0
  mov ax,[bx]
  times 10 nop
%endrep
%endmacro

; Loop over tests
;   Do {1, 9} iterations
;     Copy N instances of test code to CS + 64kB
;     Safe refresh off
;     Read timer
;     Execute test
;     Read timer
;     Subtract timer
;     Safe refresh on
;   Subtract timer deltas
;   Compare to expected
;   If not equal
;     Print failing test number
;     Copy an instance of test code
;     Execute under trace

  outputCharacter 8

  xor ax,ax
  mov ds,ax
  mov word[8*4],irq0
  mov [8*4+2],cs
  mov word[0xff*4],interruptFF
  mov word[0xff*4+2],cs

  mov ax,cs
  mov ds,ax

  cli
  mov ss,ax
  xor sp,sp
  sti
  mov si,testCases+2
  mov [testCaseOffset],si
testLoop:
  mov ax,si
  sub ax,testCases+2
  cmp ax,[testCases]
  jb notDone

  mov si,passMessage
  mov cx,5
  outputString
  mov ax,[testCaseIndex]
  call outputDecimal
  outputCharacter 10

  complete
notDone:
;    mov ax,[testCaseIndex]
;    call outputDecimal
;    outputCharacter ' '

  mov cx,ITERS+1   ; Number of iterations in primary measurement
  call doMeasurement
  push bx
  mov cx,1       ; Number of iterations in secondary measurement
  call doMeasurement
  pop ax         ; The primary measurement will have the lower value, since the counter counts down
  sub ax,bx      ; Subtract the secondary value, which will be higher, now AX is negative
  neg ax         ; Negate to get the positive difference.
  mov si,[testCaseOffset]
  cmp ax,[si]
  jne testFailed

  inc word[testCaseIndex]
  mov bl,[si+3]      ; Number of preamble bytes
  mov bh,0
  lea si,[si+bx+4]   ; Points to instruction bytes count
  mov bl,[si]        ; Number of instruction bytes
  inc si             ; Points to first instruction byte
  add si,bx          ; Points to fixup count
  mov bl,[si]        ; Number of fixups
  inc si             ; Points to first fixup
  add si,bx
  mov [testCaseOffset],si
  jmp testLoop

testFailed:
  push ax
  shr ax,1
  mov [countedCycles],ax

  mov ax,[testCaseIndex]
  outputHex
  outputCharacter ' '

  outputCharacter 'o'
  pop ax
  call outputDecimal
  outputCharacter ' '
  outputCharacter 'e'
  mov si,[testCaseOffset]
  mov ax,[si]
  call outputDecimal
  outputCharacter 10

  mov ax,[countedCycles]
  mov si,[testCaseOffset]
  mov bx,[si]
  cmp ax,bx
  jae noSatLow
  mov ax,bx
noSatLow:
  cmp ax,2047
  jb noSatHigh
  mov ax,2047
noSatHigh:
  mov [countedCycles],ax


  mov si,failMessage
  mov cx,5
  outputString
  mov ax,[testCaseIndex]
  call outputDecimal

  outputCharacter 10

  mov word[sniffer],0x8000

  outputCharacter 6

  mov cx,16
loopTop:
  mov [savedCX],cx
  mov cx,1
;    mov word[countedCycles],2047
  call doMeasurement

  mov ax,[countedCycles]
  mov dx,25
  mul dx
  mov cx,ax
flushLoop2:
  loop flushLoop2

  mov cx,[savedCX]
  loop loopTop2
  outputCharacter 7
  complete
loopTop2:
  jmp loopTop

doMeasurement:
  mov ax,cs
  add ax,0x1000
  mov es,ax
  xor di,di
  mov si,[testCaseOffset]
  mov bl,[si+2]
repeatLoop:

  push cx
  mov bp,di
  mov cl,[si+3]
  push si
  add si,4
  rep movsb

  mov al,bl
  and al,0xe0
  cmp al,0
  jne notQueueFiller0
  mov ax,0x00b0  ; 'mov al,0'
  stosw
  mov ax,0xe0f6  ; 'mul al'
  stosw
  jmp doneQueueFiller
notQueueFiller0:

  jmp testFailed
doneQueueFiller:
  mov cl,bl
  and cl,0x1f
  mov al,0x90
  rep stosb
  mov cl,[si]
  inc si
  push bx
  mov bx,di
  rep movsb
  mov ax,0x00eb  ; 'jmp ip+0'
  stosw

  push di
  mov cl,[si]
  inc si
  jcxz .overLoop
.loopTop:
  lodsb
  test al,0x80
  jnz .fixupMain
  ; fixup preamble
  cbw
  mov di,ax
  add word[es:di+bp],bx
  jmp .doneFixup
.fixupMain:
  and al,0x7f
  cbw
  mov di,ax
  add word[es:di+bx],bx
.doneFixup:
  loop .loopTop
.overLoop:
  pop di
  pop bx
  pop si
  pop cx

  loop repeatLoop
  mov ax,0xffcd  ; 'int 0xff'
  stosw
  xor ax,ax
  stosw
  stosw

%if 0
;  cmp word[sniffer],0x8000
;  jne .noDump
    push di
    push si
    push ds
    push cx
    push ax

    mov si,0
    mov ax,es
    mov ds,ax
    mov cx,11
.dump:
    lodsw
    outputHex
    loop .dump

    pop ax
    pop cx
    pop ds
    pop si
    pop di
;  .noDump:
%endif


;    push di
;    push si
;    push ds
;    push cx
;    push ax
;
;    mov si,-14
;    mov ax,es
;    mov ds,ax
;    mov cx,7
;.dumpStack:
;    lodsw
;    outputHex
;    loop .dumpStack
;
;    pop ax
;    pop cx
;    pop ds
;    pop si
;    pop di

  safeRefreshOff
  writePIT16 0, 2, 2    ; Ensure an IRQ0 is pending
  writePIT16 0, 2, 100  ; Queue an IRQ0 to execute from HLT
  sti
  hlt                   ; ACK first IRQ0
  hlt                   ; wait for second IRQ0
  writePIT16 0, 2, 1500 ; Queue an IRQ0 for after the test (>1000 <2000)
;  cli
  xor ax,ax
  mov ds,ax
  mov word[0x20],irq0a

  mov ds,[cs:sniffer]
  mov ax,[0]      ; Trigger: Start of command load sequence
  times 10 nop
  mov dl,16
  mov cx,[cs:savedCX]
  sub dl,cl

  outputByte
  mov si,[cs:testCaseOffset]
  mov dx,[cs:countedCycles]
  outputByte
  outputByte
  mov dx,714
  outputByte
  outputByte

  mov [cs:savedSP],sp
  mov [cs:savedSS],ss
  mov ax,cs
  add ax,0x1000
  mov ds,ax
  mov es,ax
  mov ss,ax

  xor ax,ax
  mov dx,ax
  mov bx,ax
  mov cx,ax
  mov si,ax
  mov di,ax
  mov bp,ax
  mov sp,ax
  mov word[cs:testBuffer],0
  mov [cs:testBuffer+2],ds
  jmp far [cs:testBuffer]

irq0:
  push ax
  mov al,0x20
  out 0x20,al
  pop ax
  iret

irq0a:
  mov al,0x20
  out 0x20,al

interruptFF:
  mov al,0
  out 0x43,al
  in al,0x40
  mov bl,al
  in al,0x40
  mov bh,al

  xor ax,ax
  mov ds,ax
  mov word[0x20],irq0

  mov sp,[cs:savedSP]
  mov ss,[cs:savedSS]

  safeRefreshOn

  mov ax,cs
  mov ds,ax
  ret


outputDecimal:
  cmp ax,10000
  jae .d5
  cmp ax,1000
  jae .d4
  cmp ax,100
  jae .d3
  cmp ax,10
  jae .d2
  jmp .d1
.d5:
  mov bx,10000
  xor dx,dx
  div bx
  add al,'0'
  push dx
  outputCharacter
  pop ax
.d4:
  mov bx,1000
  xor dx,dx
  div bx
  add al,'0'
  push dx
  outputCharacter
  pop ax
.d3:
  mov bx,100
  xor dx,dx
  div bx
  add al,'0'
  push dx
  outputCharacter
  pop ax
.d2:
  mov bl,10
  div bl
  add al,'0'
  push ax
  outputCharacter
  pop ax
  mov al,ah
.d1:
  add al,'0'
  outputCharacter
  ret


failMessage: db "FAIL "
passMessage: db "PASS "

testCaseIndex: dw 0
testCaseOffset: dw 0
testBuffer: dw 0, 0
savedSP: dw 0
savedSS: dw 0
savedCX: dw 0
lut: db 0x88,8
sniffer: dw 0x7000
countedCycles: dw 1
testSP: dw 0


testCases:

; Format of testCases:
;   2 bytes: total length of testCases data excluding length field
;   For each testcase:
;     2 bytes: cycle count
;     1 byte: queueFiller operation (0 = MUL) * 32 + number of NOPs
;     1 byte: number of preamble bytes
;     N bytes: preamble
;     1 byte: number of instruction bytes
;     N bytes: instructions
;     1 byte: number of fixups
;     N entries:
;       1 byte: offset of address to fix up relative to start of preamble/main. Offset of main is added to value at this address + 128*(0 = address in preamble, 1 = address in main code)


