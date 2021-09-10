;
; Example program that uses the subroutines available in ROM.
;
; The addresses for these routines are captured by running
;  `vasm -dotdir -Fbin -L bootloader.lst bootloader.asm -o bootloader.out`
; to compile the bootloader bin which you have to do anyway.  The resulting bootloader.lst
; file contains a list of all the lables together with their memory locations.
;
; with this information, we can create an example assembly that defines the addresses of
; the subroutines in ROM and jumps to them as normal.
;
; This program will display a message and indicate on the LCD which button you pressed.
; That's all it does. But it's a good start.
;
 
PORTB   = $6000
PORTA   = $6001
DDRB    = $6002
DDRA    = $6003

PCR     = $600c         ; W65C22 VIA Periferal Control Register
IFR     = $600d         ; W65C22 VIA Interrupt Flag Register
IER     = $600e         ; W65C22 VIA Interrupt Enable Register

E       = %10000000
RW      = %01000000
RS      = %00100000

; ROM ADDRESSES
VIA__read_keyboard_input            = $827D
VIA__configure_ddrs                    = $8286
LCD__clear_video_ram                = $828D
LCD__print                          = $82A1
LCD__initialize                     = $8332
LIB__sleep                          = $83C9
VIDEO_RAM                           = $3FDE     ; $3fde - $3ffd - Video RAM for 32 char LCD display
WAIT                                = $3fdb
WAIT_C                              = $ff       ; global wait multiplier.

ISR_LOC                                = $04

    .org $0200

reset:
    ldx #$ff                                    ; initialize the stackpointer with 0xff
    txs

    lda #<ISR
    sta ISR_LOC
    lda #>ISR
    sta ISR_LOC + 1

    jsr LCD__initialize

    jsr LCD__clear_video_ram

    lda #<message                               ; render the boot screen
    ldy #>message
    jsr LCD__print

    lda #%11111111
    ldx #%11100001                                ; override sixty5o2 PORTA Config
    jsr VIA__configure_ddrs

    lda #%10000010                                ; Enable CA1 interrupt
    sta IER
    lda #$00                                    ; Set CA1 to trigger on negative transition (going low)
    sta PCR

.wait_for_input:                                ; handle keyboard input
    ldx #4
    lda #$ff                                    ; debounce
.wait:
    jsr LIB__sleep
    dex
    bne .wait

    lda #0
    jsr VIA__read_keyboard_input
    beq .wait_for_input                         ; no
      
.handle_keyboard_input:
    cmp #$01    
    beq .up                                     ; UP key pressed
    cmp #$02
    beq .down                                   ; DOWN key pressed
    cmp #$04
    beq .left
    cmp #$08
    beq .right                                  ; RIGHT key pressed
    lda #0                                      ; explicitly setting A is a MUST here
    jmp .wait_for_input                         ; and go around
.up:
    ldy #$ff
    ldx #$f0
    jsr beep

    lda #<up
    ldy #>up
    jmp .do
.down:
    ldy #$ff
    ldx #$d0
    jsr beep

    lda #<down
    ldy #>down
    jmp .do
.left:
    ldy #$ff
    ldx #$b0
    jsr beep

    lda #<left
    ldy #>left
    jmp .do
.right:
    ldy #$ff
    ldx #$90
    jsr beep

    lda #<right
    ldy #>right
    jmp .do
.do:
    jsr LCD__clear_video_ram
    jsr LCD__print

    ldx #$20                                    ; delay further progress for a bit longer
    lda #$ff
.pause:
    jsr LIB__sleep
    dex
    bne .pause


    lda #<message                               ; render the boot screen
    ldy #>message
    jsr LCD__print

    jmp .wait_for_input


; Y = Length of beep  0 - 255
; x = freq.

beep:
    stx $FE

.beep_1:
    ldx $FE
    lda #$01
    sta PORTA
.beep_2:
    dex
    bne .beep_2
    lda #$00
    sta PORTA
    dey
    bne .beep_1



    rts

forever:
    jmp forever

message:
    .asciiz "ROM Routines    Work!"
up:
    .asciiz "Up"
down:
    .asciiz "Down"
left:
    .asciiz "Left"
right:
    .asciiz "Right"

ISR:
    pha
    txa
    pha
    tya
    pha

    ldx #$0
.beeploop:
    ldy #$10
    jsr beep
    inx
    bne .end_isr
    ldy #$10
    jmp .beeploop

.end_isr:
    bit PORTA        ; clear interrupt.

    pla
    tay
    pla
    tax
    pla
    rti
