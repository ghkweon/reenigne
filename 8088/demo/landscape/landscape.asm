org 0x100
cpu 8086

  mov ax,1
  int 0x10

  mov dx,0x3d8
  mov al,8
  out dx,al

  mov dl,0xd4
  mov ax,0x7f04
  out dx,ax
  mov ax,0x6406
  out dx,ax
  mov ax,0x7007
  out dx,ax
  mov ax,0x0109
  out dx,ax

  mov ax,0xb800
  mov es,ax
  mov ax,0xb000
  mov cx,40*100
  rep stosw

  std
  mov bx,-79


; 160 entry sine table scaled to 0x7fff
sineTable:
  dw 0x0000, 0x0506, 0x0A0A, 0x0F0B, 0x1405, 0x18F8, 0x1DE1, 0x22BE
  dw 0x278D, 0x2C4D, 0x30FB, 0x3596, 0x3A1B, 0x3E8A, 0x42E0, 0x471C
  dw 0x4B3B, 0x4F3D, 0x5320, 0x56E2, 0x5A81, 0x5DFD, 0x6154, 0x6484
  dw 0x678D, 0x6A6C, 0x6D22, 0x6FAD, 0x720B, 0x743D, 0x7640, 0x7815
  dw 0x79BB, 0x7B30, 0x7C75, 0x7D89, 0x7E6B, 0x7F1B, 0x7F99, 0x7FE5
  dw 0x7FFF, 0x7FE5, 0x7F99, 0x7F1B, 0x7E6B, 0x7D89, 0x7C75, 0x7B30
  dw 0x79BB, 0x7815, 0x7640, 0x743D, 0x720B, 0x6FAD, 0x6D22, 0x6A6C
  dw 0x678D, 0x6484, 0x6154, 0x5DFD, 0x5A81, 0x56E2, 0x5320, 0x4F3D
  dw 0x4B3B, 0x471C, 0x42E0, 0x3E8A, 0x3A1B, 0x3596, 0x30FB, 0x2C4D
  dw 0x278D, 0x22BE, 0x1DE1, 0x18F8, 0x1405, 0x0F0B, 0x0A0A, 0x0506
  dw 0x0000, 0xFAFA, 0xF5F6, 0xF0F5, 0xEBFB, 0xE708, 0xE21F, 0xDD42
  dw 0xD873, 0xD3B3, 0xCF05, 0xCA6A, 0xC5E5, 0xC176, 0xBD20, 0xB8E4
  dw 0xB4C5, 0xB0C3, 0xACE0, 0xA91E, 0xA57F, 0xA203, 0x9EAC, 0x9B7C
  dw 0x9873, 0x9594, 0x92DE, 0x9053, 0x8DF5, 0x8BC3, 0x89C0, 0x87EB
  dw 0x8645, 0x84D0, 0x838B, 0x8277, 0x8195, 0x80E5, 0x8067, 0x801B
  dw 0x8001, 0x801B, 0x8067, 0x80E5, 0x8195, 0x8277, 0x838B, 0x84D0
  dw 0x8645, 0x87EB, 0x89C0, 0x8BC3, 0x8DF5, 0x9053, 0x92DE, 0x9594
  dw 0x9873, 0x9B7C, 0x9EAC, 0xA203, 0xA57F, 0xA91E, 0xACE0, 0xB0C3
  dw 0xB4C5, 0xB8E4, 0xBD20, 0xC176, 0xC5E5, 0xCA6A, 0xCF05, 0xD3B3
  dw 0xD873, 0xDD42, 0xE21F, 0xE708, 0xEBFB, 0xF0F5, 0xF5F6, 0xFAFA

; Our texture samples in each direction don't have to be evenly spaced.
; It makes sense to have those in the far distance further apart.
; Space them on a quadratic curve.
distanceTable:
  db  1,  2,  3,  4,  5,  7,  9, 11, 13, 15, 17, 20, 22, 25, 28, 31
  db 34, 38, 41, 45, 49, 53, 57, 61, 65, 70, 75, 80, 85, 90, 95,101

