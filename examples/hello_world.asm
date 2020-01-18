PORTB = $6000                               ; VIA port B
PORTA = $6001                               ; VIA port A
DDRB = $6002                                ; Data Direction Register B
DDRA = $6003                                ; Data Direction Register A

E =  %10000000
RW = %01000000
RS = %00100000

    .org $0200

;
; main
;
main:
    jsr init_via_ports
    jsr init_lcd
    lda #<message
    ldy #>message
    jsr write_to_screen
loop:
    jmp loop

;
; clear_lcd
;
clear_lcd:
    pha
    lda #%00000001                          ; Clear Display
    jsr send_lcd_instruction
    lda #$80
    jsr sleep                               ; Sleep for a while, because the display is not fast enough
    pla

    rts

;
; init_via_ports
;
init_via_ports:
    lda #%11111111                          ; Set all pins on port B to output
    sta DDRB
    
    lda #%11100001                          ; Set top 3 pins and bottom ones to on port A to output, 4 middle ones to input
    sta DDRA

;
; init_lcd - initialize the display
;
init_lcd:
    lda #%00111000                          ; Set 8-bit mode; 2-line display; 5x8 font
    jsr send_lcd_instruction
    
    lda #%00001110                          ; Display on; cursor on; blink off
    jsr send_lcd_instruction
    
    lda #%00000110                          ; Increment and shift cursor; don't shift display
    jsr send_lcd_instruction

    jsr clear_lcd

    rts

;
; write_to_screen - writes a message to the LCD screen
;
write_to_screen:
STRING = $fe                                ; string pointer needs to be in zero page for indirect indexed addressing
    sta STRING
    sty STRING+1
    ldy #0
write_chars:
    lda (STRING),Y
    beq wc_return
    jsr send_lcd_data
    iny

    jmp write_chars
wc_return:

    rts

;
; send_lcd_instruction - sends instruction commands to the LCD screen
;
send_lcd_instruction:
    sta PORTB                               ; Write accumulator content into PORTB
    lda #0
    sta PORTA                               ; Clear RS/RW/E bits
    lda #E
    sta PORTA                               ; Set E bit to send instruction
    lda #0
    sta PORTA                               ; Clear RS/RW/E bits

    rts

;
; send_lcd_data - sends data to be written to the LCD screen
;
send_lcd_data:
    sta PORTB                               ; Write accumulator content into PORTB
    lda #0
    sta PORTA                               ; Clear RS/RW/E bits
    lda #(RS | E)
    sta PORTA                               ; SET E bit AND register select bit to send instruction
    lda #0
    sta PORTA                               ; Clear RS/RW/E bits

    rts

;
; sleep - subroutine - sleeps for number of cycles read from accumulator
;
sleep:
    tay
loops:
    dey
    bne loops
    rts

message:
    .asciiz "Hello, World!"