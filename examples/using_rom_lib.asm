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

E       = %10000000
RW      = %01000000
RS      = %00100000

; ROM ADDRESSES
VIA__read_keyboard_input            = $8275
VIA__configure_ddrs                 = $827E
LCD__clear_video_ram                = $8285
LCD__print                          = $8299
LCD__print_with_offset              = $829F
LCD__print_text                     = $82BB
LCD__initialize                     = $832A
LCD__set_cursor                     = $8340
LCD__set_cursor_second_line         = $8343
LCD__render                         = $834B
LCD__check_busy_flag                = $836F
LCD__send_instruction               = $8384
LCD__send_data                      = $8399
LIB__bin_to_hex                     = $83A7
LIB__sleep                          = $83C1
VIDEO_RAM                           = $3FDE     ; $3fde - $3ffd - Video RAM for 32 char LCD display
WAIT                                = $3fdb
WAIT_C                              = $ff       ; global wait multiplier.

    .org $0200

reset:
    ldx #$ff                                    ; initialize the stackpointer with 0xff
    txs

    jsr LCD__initialize
    jsr LCD__clear_video_ram

    lda #<message                               ; render the boot screen
    ldy #>message
    jsr LCD__print

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
    lda #<up
    ldy #>up
    jmp .do
.down:
    lda #<down
    ldy #>down
    jmp .do
.left:
    lda #<left
    ldy #>left
    jmp .do
.right:
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
