PORTB 	= $6000
PORTA 	= $6001
DDRB  	= $6002
DDRA  	= $6003

PCR		= $600c		; W65C22 VIA Periferal Control Register
IFR		= $600d		; W65C22 VIA Interrupt Flag Register
IER		= $600e		; W65C22 VIA Interrupt Enable Register

value 	= $1000		; 2 bytes
mod10 	= $1002		; 2 bytes
message = $1004		; 6 bytes
counter = $100a		; 2 bytes

E     	= %10000000
RW    	= %01000000
RS    	= %00100000

ISR_LOC = $04		; location of IRQ handler

	.org $0200

reset:

	lda #<irq       ; set up IRQ handler for sixty5o2
	sta ISR_LOC
	lda #>irq
	sta ISR_LOC + 1

	lda #$ff		; Set up stack pointer
	txs

	lda #$82		; Enable CA1 interrupt on the VIA (10000010)
	sta IER
	lda #$00
	sta PCR			; Set CA1 to trigger on negative transition (going low)

	lda #%11111111	; Set all pins on PORTB to output
	sta DDRB

	lda #%11100000  ; Set top 3 pins on PORTA to output (bottom 5 pins as input)
	sta DDRA

	lda #%00111000	; Set 8-bit mode; 2 line display; 5x8 font
	jsr lcd_instruction

	lda #%00001110	; Display on; cursor on; blink off
	jsr lcd_instruction

    lda #%00000110	; Increment / shift cursor; don't shift display
	jsr lcd_instruction

	lda #%00000001	; Clear display
	jsr lcd_instruction

	lda #0			; Initialize the counter to zero
	sta counter
	sta counter + 1
	cli				; clear interrupt disable bit (enable interrupts)

loop:
	lda #%00000010	; Move cursor to home
	jsr lcd_instruction

bin2dec:
	; initialise the output message
	lda #0
	sta message

	sei				; Disable interrupts. (the name of this instruction is misleading)

	; initialize the value to convert
	lda counter
	sta value
	lda counter + 1
	sta value + 1

	cli				; clear interrupt disable bit (enable interrupts)

divide:
	; Initialise the remainder to zero
	lda #0
	sta mod10
	sta mod10 + 1
	clc

	ldx #16
divloop:
	; Rotate the quotient and remainder
	rol value
	rol value + 1
	rol mod10
	rol mod10 + 1

	; a, y = dividend - divisor
	sec
	lda mod10
	sbc #10
	tay				; save low byte
	lda mod10 + 1
	sbc #0
	bcc  ignore_result ; branch if dividend < divisor

	sty mod10
	sta mod10 + 1

ignore_result:
	dex
	bne divloop
	rol value	; shift in the last bit of the qotient
	rol value + 1

	lda mod10
	clc
	adc #"0"
	jsr push_char

	; if value is not zero we need to continue dividing
	lda value
	ora value + 1
	bne divide

	ldx #0
print:
	lda message,x
	beq loop
	jsr print_char
	inx
	jmp print

	jmp loop

number: .word 1729

; Add the character in the A register to the beginning of the 
; null-terminated string `message`
push_char:
	pha	; Push new char to the stack
	ldy #0
char_loop:
	lda message,y	; Get char from the string and put to x reg
	tax
	pla
	sta message,y	; Pull char off the stack and push to the string
	iny
	txa
	pha				; Push char from stirng on to stack
	bne	char_loop
	pla
	sta message,y	; Pull the null off the stack and add to end of string
	rts

lcd_wait:
	pha
	lda #%00000000
	sta DDRB
lcdbusy:
	lda #RW
	sta PORTA
	lda #(RW | E)
	sta PORTA
	lda PORTB
	and #%10000000
	bne lcdbusy

	lda #RW
	sta PORTA
	lda #%11111111
	sta DDRB

	pla
	rts

lcd_instruction:
	jsr lcd_wait
    sta PORTB
    lda #0
    sta PORTA       ; Clear RS/RW/E bits
    lda #E          ; Set E bit to send instruction
    STA PORTA
    lda #0
    sta PORTA       ; Clear RS/RW/E bits
    rts

print_char:
	jsr lcd_wait
	sta PORTB
	lda #RS					
	sta PORTA		; Set RS; Clear RW/E bits
	lda #(RS | E)  	; Set E bit to send instruction
	STA PORTA
	lda #RS
	sta PORTA		; Clear RS/RW/E bits
	rts

irq:
	pha
	txa
	pha
	tya
	pha

	inc counter
	bne exit_irq
	inc counter + 1

exit_irq:
	ldy #$80
.outer:
	ldx #$ff
.inner:
	dex
	bne .inner
	dey
	bne .outer

	bit PORTA

	pla
	tay
	pla
	tax
	pla

	rti


