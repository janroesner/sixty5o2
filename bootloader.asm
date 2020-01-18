;================================================================================
;
;                                   "Sixty/5o2"
;                                    _________
;
;                                      v1.0
;
;   Sixty/5o2 - minimal bootloader and monitor (r/o) w/ serial connection support
;
;   Written by Jan Roesner <jan@roesner.it> for Ben Eater's "Project 6502"
;   
;   Credits:
;               - Ben Eater             (Project 6502)
;               - Steven Wozniak        (bin2hex routine)
;               - Anke L.               (love, patience & support)
;
;================================================================================

PORTB = $6000                                   ; VIA port B
PORTA = $6001                                   ; VIA port A
DDRB = $6002                                    ; Data Direction Register B
DDRA = $6003                                    ; Data Direction Register A
IER = $600e                                     ; VIA Interrupt Enable Register

E =  %10000000
RW = %01000000
RS = %00100000

Z0 = $00                                        ; General purpose zero page locations
Z1 = $01
Z2 = $02
Z3 = $03

VIDEO_RAM = $3fde                               ; $3fde - $3ffd - Video RAM for 32 char LCD display
POSITION_MENU = $3fdc                           ; initialize positions for menu and cursor in RAM
POSITION_CURSOR = $3fdd
WAIT = $3fdb
WAIT_C = $18                                    ; global sleep multiplicator (adjust for slower clock)
ISR_FIRST_RUN = $3fda                           ; used to determine first run of the ISR

PROGRAM_LOCATION = $0200                        ; memory location for user programs

    .org $8000


;================================================================================
;
;   main - routine to initialize the bootloader
;
;   Initializes the bootloader, LCD, VIA, Video Ram and prints a welcome message
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .Y, .X
;   ————————————————————————————————————
;
;================================================================================

main:                                           ; boot routine, first thing loaded
    jsr LCD__initialize
    jsr LCD__clear_screen
    jsr LCD__clear_video_ram

    lda #<message                               ; render the boot screen
    ldy #>message
    jsr LCD__print

    ldx #$20                                    ; delay further progress for a bit longer
    lda #$ff
.wait:
    jsr LIB__sleep
    dex
    bne .wait

    jsr MENU_main                               ; start the menu routine
    jmp main                                    ; should the menu ever return ...


;================================================================================
;
;   MENU_main - renders a scrollable menu w/ dynamic number of entries
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;                    
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

MENU_main:
    lda #0                                      ; since in RAM, positions need initialization
    sta POSITION_MENU
    sta POSITION_CURSOR

    jmp .start
.MAX_SCREEN_POS:                                ; define some constants in ROM     
    .byte $05                                   ; its always number of items - 2, here its 6 windows ($00-$05) in 7 items
.OFFSETS:
    .byte $00, $10, $20, $30, $40, $50          ; content offsets for all 6 screen windows
.start:                                         ; and off we go
    jsr LCD__clear_video_ram
    ldx POSITION_MENU
    ldy .OFFSETS,X
                                                ; load first offset into Y
    ldx #0                                      ; set X to 0
.loop:
    lda menu_items,Y                            ; load string char for Y
    sta VIDEO_RAM,X                             ; store in video ram at X
    iny
    inx
    cpx #$20                                    ; repeat 32 times
    bne .loop

.render_cursor:                                 ; render cursor position based on current state
    lda #">"
    ldy POSITION_CURSOR
    beq .lower_cursor
    sta VIDEO_RAM
    bne .render
.lower_cursor:
    sta VIDEO_RAM+$10

.render:                                        ; and update the screen
    jsr LCD__render

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
    beq .move_up                                ; UP key pressed
    cmp #$02
    beq .move_down                              ; DOWN key pressed
    cmp #$08
    beq .select_option                          ; RIGHT key pressed
    lda #0                                      ; explicitly setting A is a MUST here
    jmp .wait_for_input                         ; and go around

.move_up:
    lda POSITION_CURSOR                         ; load cursor position
    beq .dec_menu_offset                        ; is cursor in up position? yes?
    lda #0                                      ; no? 
    sta POSITION_CURSOR                         ; set cursor in up position
    jmp .start                                  ; re-render the whole menu
.dec_menu_offset:
    lda POSITION_MENU
    beq .wait_for_input                         ; yes, just re-render
.decrease:
    dec POSITION_MENU                           ; decrease menu position by one
    jmp .start                                  ; and re-render

.move_down:
    lda POSITION_CURSOR                         ; load cursor position
    cmp #1                                      ; is cursor in lower position?
    beq .inc_menu_offset                        ; yes?
    lda #1                                      ; no?
    sta POSITION_CURSOR                         ; set cursor in lower position
    jmp .start                                  ; and re-render the whole menu
.inc_menu_offset:
    lda POSITION_MENU                           ; load current menu positions
    cmp .MAX_SCREEN_POS                         ; are we at the bottom yet?
    bne .increase                               ; no?
    jmp .wait_for_input                         ; yes
.increase:
    adc #1                                      ; increase menu position
    sta POSITION_MENU
    jmp .start                                  ; and re-render

.select_option:
    clc
    lda #0                                      ; clear A
    adc POSITION_MENU
    adc POSITION_CURSOR                         ; calculate index of selected option
    cmp #0                                      ; branch trough all options
    beq .load_and_run
    cmp #1
    beq .load
    cmp #2
    beq .run
    cmp #3
    beq .monitor
    cmp #4
    beq .clear_ram
    cmp #5
    beq .about
    cmp #6
    beq .credits
    jmp .end                                    ; should we have an invalid option, restart

.load_and_run:                                  ; load and directly run
    jsr .do_load                                ; load first
    jsr .do_run                                 ; run immediately after
    jmp .start                                  ; should a program ever return ...
.load:                                          ; load program and go back into menu
    jsr .do_load
    jmp .start
.run:                                           ; run a program already loaded
    jsr .do_run
    jmp .start
.monitor:                                       ; start up the monitor
    lda #<PROGRAM_LOCATION                      ; have it render the start location
    ldy #>PROGRAM_LOCATION                      ; can also be set as params during debugging
    jsr MONITOR__main
    jmp .start
.clear_ram:                                     ; start the clear ram routine
    jsr BOOTLOADER__clear_ram
    jmp .start
.about:                                         ; start the about routine
    lda #<about
    ldy #>about
    ldx #3
    jsr LCD__print_text
    jmp .start
.credits:                                       ; start the credits routine
    lda #<credits
    ldy #>credits
    ldx #3
    jsr LCD__print_text
    jmp .start
.do_load:                                       ; orchestration of program loading
    lda #$ff                                    ; wait a bit
    jsr LIB__sleep
    jsr BOOTLOADER__program_ram                 ; call the bootloaders programming routine

    rts
.do_run:                                        ; orchestration of running a program
    jmp BOOTLOADER__execute
.end
    jmp .start                                  ; should we ever reach this point ...


;================================================================================
;
;   BOOTLOADER__program_ram - writes serial data to RAM
;
;   Used in conjunction w/ the ISR, orchestrates user program reading
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;                    none
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

BOOTLOADER__program_ram:
CURRENT_RAM_ADDRESS_L = Z0
CURRENT_RAM_ADDRESS_H = Z1
LOADING_STATE = Z2
    lda #%01111111                              ; we disable all 6522 interrupts!!!
    sta IER

    lda #0                                      ; for a reason I dont get, the ISR is triggered...
    sta ISR_FIRST_RUN                           ; one time before the first byte arrives, so we mitigate here

    jsr LCD__clear_video_ram
    lda #<message4                              ; Rendering a message
    ldy #>message4
    jsr LCD__print

    lda #$00                                    ; initializing loading state byte
    sta LOADING_STATE

    lda #>PROGRAM_LOCATION                      ; initializing RAM address counter
    sta CURRENT_RAM_ADDRESS_H
    lda #<PROGRAM_LOCATION
    sta CURRENT_RAM_ADDRESS_L

    cli                                         ; enable interrupt handling

    lda #%00000000                              ; set all pins on port B to input
    ldx #%11100001                              ; set top 3 pins and bottom ones to on port A to output, 4 middle ones to input
    jsr VIA__configure_ddrs

.wait_for_first_data:
    lda LOADING_STATE                           ; checking loading state
    cmp #$00                                    ; the ISR will set to $01 as soon as a byte is read
    beq .wait_for_first_data

.loading_data
    lda #$02                                    ; assuming we're done loading, we set loading state to $02
    sta LOADING_STATE

    ldx #$20                                    ; then we wait for * cycles !!!! Increase w/ instable loading
    lda #$ff
.loop:
    jsr LIB__sleep
    dex
    bne .loop

    lda LOADING_STATE                           ; check back loading state, which was eventually updated by the ISR
    cmp #$02
    bne .loading_data
                                               ; when no data came in in last * cycles, we're done loading  
.done_loading:
    jsr LCD__initialize
    jsr LCD__clear_screen
    jsr LCD__clear_video_ram

    lda #<message6
    ldy #>message6
    jsr LCD__print
    lda #$ff                                    ; wait a moment before we return to main menu
    jsr LIB__sleep

    rts


;================================================================================
;
;   BOOTLOADER__execute - executes a user program in RAM
;
;   Program needs to be loaded via serial loader or other mechanism beforehand
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;                    
;   Destroys:        .A, .Y
;   ————————————————————————————————————
;
;================================================================================

BOOTLOADER__execute:
    sei                                         ; disable interrupt handling
    jsr LCD__clear_video_ram                    ; print a message
    lda #<message7
    ldy #>message7
    jsr LCD__print
    jmp PROGRAM_LOCATION                        ; and jump to program location

;================================================================================
;
;   BOOTLOADER__clear_ram - clears RAM from $0200 up to $3fff
;
;   Useful during debugging or when using non-volatile RAM chips
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .Y
;   ————————————————————————————————————
;
;================================================================================

BOOTLOADER__clear_ram:
    jsr LCD__clear_video_ram                    ; render message 
    lda #<message8
    ldy #>message8
    jsr LCD__print

    ldy #<PROGRAM_LOCATION                      ; load start location into zero page
    sty Z0
    lda #>PROGRAM_LOCATION
    sta Z1
    lda #$00                                    ;  load 0x00 cleaner byte
.loop:
    sta (Z0),Y                                  ; store it in current location
    iny                                         ; increase 16 bit address by 0x01
    bne .loop    
    inc Z1
    bit Z1                                      ; V is set on bit 6 (= $40)
    bvs .loop
    rts                                         ; yes, return from subroutine

;================================================================================
;
;   MONITOR__main - RAM/ROM Hexmonitor (r/o)
;
;   Currently read only, traverses RAM and ROM locations, shows hex data contents
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

MONITOR__main:
    sta Z0                                      ; store LSB
    sty Z1                                      ; store MSB

.render_current_ram_location:
    jsr LCD__clear_video_ram

    lda #$00                                    ; select upper row of video ram
    sta Z3                                      ; #TODO
    jsr .transform_contents                     ; load and transform ram and address bytes

    clc                                         ; add offset to address
    lda Z0
    adc #$04
    sta Z0
    bcc .skip
    inc Z1
.skip:    

    lda #$01                                    ; select lower row of video ram
    sta Z3
    jsr .transform_contents                     ; load and transform ram and address bytes there

    jsr LCD__render

.wait_for_input:                                ; wait for key press
    ldx #$04                                    ; debounce #TODO
.wait:
    lda #$ff                                    
    jsr LIB__sleep
    dex
    bne .wait

    lda #0
    jsr VIA__read_keyboard_input
    beq .wait_for_input                         ; a key was pressed? no
 
.handle_keyboard_input:                         ; determine action for key pressed
    cmp #$01    
    beq .move_up                                ; UP key pressed
    cmp #$02
    beq .move_down                              ; DOWN key pressed
    cmp #$04
    beq .exit_monitor                           ; LEFT key pressed
    cmp #$08
    beq .fast_forward                           ; RIGHT key pressed
    lda #0                                      ; explicitly setting A is a MUST here
    jmp .wait_for_input
.exit_monitor:
    lda #0                                      ; needed for whatever reason
    rts

.move_down:
    jmp .render_current_ram_location            ; no math needed, the address is up to date already
.move_up:
    sec                                         ; decrease the 16bit RAM Pointer
    lda Z0
    sbc #$08
    sta Z0
    lda Z1
    sbc #$00
    sta Z1
    jmp .render_current_ram_location            ; and re-render
.fast_forward:                                  ; add $0800 to current RAM location
    sec
    lda Z0
    adc #$00
    sta Z0
    lda Z1
    adc #$04
    sta Z1
    jmp .render_current_ram_location            ; and re-render
.transform_contents:                            ; start reading address and ram contents into stack
    ldy #3
.iterate_ram:                                   ; transfer 4 ram bytes to stack
    lda (Z0),Y
    pha
    dey
    bne .iterate_ram
    lda (Z0),Y
    pha

    lda Z0                                      ; transfer the matching address bytes to stack too
    pha
    lda Z1 
    pha

    ldy #0
.iterate_stack:                                 ; transform stack contents from bin to hex
    cpy #6
    beq .end
    sty Z2                                      ; preserve Y #TODO
    pla
    jsr LIB__bin_to_hex
    ldy Z2                                      ; restore Y
    pha                                         ; push least sign. nibble (LSN) onto stack
    txa
    pha                                         ; push most sign. nibble (MSN) too

    tya                                         ; calculate nibble positions in video ram
    adc MON__position_map,Y                     ; use the static map for that
    tax
    pla
    jsr .store_nibble                           ; store MSN to video ram
    inx
    pla
    jsr .store_nibble                           ; store LSN to video ram

    iny
    jmp .iterate_stack                          ; repeat for all 6 bytes on stack
.store_nibble:                                  ; subroutine to store nibbles in two lcd rows
    pha
    lda Z3
    beq .store_upper_line                       ; should we store in upper line? yes
    pla                                         ; no, store in lower line
    sta VIDEO_RAM+$10,X
    jmp .end_store
.store_upper_line                               ; upper line storage
    pla
    sta VIDEO_RAM,X
.end_store:
    rts
.end:
    lda #":"                                    ; writing the two colons
    sta VIDEO_RAM+$4
    sta VIDEO_RAM+$14

    rts


;================================================================================
;
;   VIA__read_keyboard_input - returns 4-key keyboard inputs
;
;   Input is read, normalized and returned to the caller
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: .A: (UP: $1, DOWN: $2, LEFT: $4, RIGHT: $8)
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

VIA__read_keyboard_input:
    lda PORTA                                   ; load current key status from VIA
    ror                                         ; normalize the input to $1, $2, $4 and $8
    and #$0f

    rts


;================================================================================
;
;   VIA__configure_ddrs - configures data direction registers of the VIA chip
;
;   Expects one byte per register with bitwise setup input/output directions
;   ————————————————————————————————————
;   Preparatory Ops: .A: Byte for DDRB
;                    .X: Byte for DDRA
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

VIA__configure_ddrs:
    sta DDRB                                    ; configure data direction for port B from A reg.
    stx DDRA                                    ; configure data direction for port A from X reg.

    rts


;================================================================================
;
;   LCD__clear_video_ram - clears the Video Ram segment with 0x00 bytes
;
;   Useful before rendering new contents by writing to the video ram
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

LCD__clear_video_ram:
    pha                                         ; preserve A via stack
    tya                                         ; same for Y
    pha
    ldy #$20                                    ; set index to 32
    lda #$20                                    ; set character to 'space'
.loop:
    sta VIDEO_RAM,Y                             ; clean video ram
    dey                                         ; decrease index
    bne .loop                                   ; are we done? no, repeat
    sta VIDEO_RAM                               ; yes, write zero'th location manually
    pla                                         ; restore Y
    tay
    pla                                         ; restore A

    rts

;================================================================================
;
;   LCD__print - prints a string to the LCD (highlevel)
;
;   String must be given as address pointer, subroutines are called
;   The given string is automatically broken into the second display line and
;   the render routines are called automatically
;
;   Important: String MUST NOT be zero terminated
;   ————————————————————————————————————
;   Preparatory Ops: .A: LSN String Address
;                    .Y: MSN String Address
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

LCD__print:
    ldx #0                                      ; set offset to 0 as default
    jsr LCD__print_with_offset                  ; call printing subroutine

    rts


;================================================================================
;
;   LCD__print_with_offset - prints string on LCD screen at given offset
;
;   String must be given as address pointer, subroutines are called
;   The given string is automatically broken into the second display line and
;   the render routines are called automatically
;
;   Important: String MUST NOT be zero terminated
;   ————————————————————————————————————
;   Preparatory Ops: .A: LSN String Address
;                    .Y: MSN String Address
;                    .X: Offset Byte
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

LCD__print_with_offset:
STRING_ADDRESS_PTR = Z0
    sta STRING_ADDRESS_PTR                      ; load t_string lsb
    sty STRING_ADDRESS_PTR+1                    ; load t_string msb
    stx Z2                                      ; X can not directly be added to A, therefore we store it #TODO
    ldy #0
.loop:
    clc
    tya
    adc Z2                                      ; compute offset based on given offset and current cursor position
    tax
    lda (STRING_ADDRESS_PTR),Y                  ; load char from given string at position Y
    beq .return                                 ; is string terminated via 0x00? yes
    sta VIDEO_RAM,X                             ; no - store char to video ram
    iny
    jmp .loop                                   ; loop until we find 0x00
.return:
    jsr LCD__render                             ; render video ram contents to LCD screen aka scanline

    rts


;================================================================================
;
;   LCD__print_text - prints a scrollable / escapeable multiline text (highlevel)
;
;   The text location must be given as memory pointer, the number of pages to
;   be rendered needs to be given as well
;
;   Important: The text MUST be zero terminated
;   ————————————————————————————————————
;   Preparatory Ops: .A: LSN Text Address
;                    .Y: MSN Text Address
;                    .X: Page Number Byte
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

LCD__print_text:
    sta Z0                                      ; store text pointer in zero page
    sty Z1
    dex                                         ; reduce X by one to get cardinality of pages
    stx Z2                                      ; store given number of pages
.CURRENT_PAGE = Z3
    lda #0
    sta Z3
.render_page:
    jsr LCD__clear_video_ram                    ; clear video ram
    ldy #0                                      ; reset character index
.render_chars:
    lda (Z0),Y                                  ; load character from given text at current character index
    cmp #$00
    beq .do_render                              ; text ended? yes then render
    sta VIDEO_RAM,Y                             ; no, store char in video ram at current character index
    iny                                         ; increase index
    bne .render_chars                           ; repeat with next char
.do_render:
    jsr LCD__render                             ; render current content to screen

.wait_for_input:                                ; handle keyboard input
    ldx #4
.wait:
    lda #$ff                                    ; debounce
    jsr LIB__sleep
    dex
    bne .wait

    lda #0
    jsr VIA__read_keyboard_input
    bne .handle_keyboard_input                  ; do we have input? yes?
    jmp .wait_for_input                         ; no

.handle_keyboard_input:
    cmp #$01    
    beq .move_up                                ; UP key pressed
    cmp #$02
    beq .move_down                              ; DOWN key pressed
    cmp #$04
    beq .exit                                   ; LEFT key pressed
    lda #0                                      ; Explicitly setting A is a MUST here
    jmp .wait_for_input
.exit:

    rts
.move_up:
    lda .CURRENT_PAGE                           ; are we on the first page?
    beq .wait_for_input                         ; yes, just ignore the keypress and wait for next one

    dec .CURRENT_PAGE                           ; no, decrease current page by 1

    sec                                         ; decrease reading pointer by 32 bytes
    lda Z0
    sbc #$20
    sta Z0
    bcs .skipdec
    dec Z1
.skipdec:    
    jmp .render_page                            ; and re-render

.move_down:
    lda .CURRENT_PAGE                           ; load current page
    cmp Z2                                      ; are we on last page already
    beq .wait_for_input                         ; yes, just ignore keypress and wait for next one

    inc .CURRENT_PAGE                           ; no, increase current page by 1

    clc                                         ; add 32 to the text pointer
    lda Z0
    adc #$20
    sta Z0
    bcc .skipinc
    inc Z1
.skipinc:
    jmp .render_page                            ; and re-render

;================================================================================
;
;   LCD__initialize - initializes the LCD display
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .X
;   ————————————————————————————————————
;
;================================================================================

LCD__initialize:
    lda #%11111111                              ; set all pins on port B to output
    ldx #%11100000                              ; set top 3 pins and bottom ones to on port A to output, 5 middle ones to input
    jsr VIA__configure_ddrs

    lda #%00111000                              ; set 8-bit mode, 2-line display, 5x8 font
    jsr LCD__send_instruction

    lda #%00001110                              ; display on, cursor on, blink off
    jsr LCD__send_instruction
    
    lda #%00000110                              ; increment and shift cursor, don't shift display
    jmp LCD__send_instruction

;================================================================================
;
;   LCD__clear_screen - clears the screen on hardware level (low level)
;
;   Not to confuse with LCD__clear_video_ram, which in contrast just deletes
;   the stored RAM values which shall be displayed
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

LCD__clear_screen:
    pha
    lda #%00000001                              ; clear display
    jsr LCD__send_instruction
    lda #$80                                    ; #TODO: better wait for busy flag to be clear
    jsr LIB__sleep                              ; sleep for a while, because the display is not fast enough with a 103 capacitor
    pla

    rts


;================================================================================
;
;   LCD__set_cursor - sets the cursor on hardware level into upper or lower row
;
;   Always positions the cursor in the first column of the chosen row
;   ————————————————————————————————————
;   Preparatory Ops: .A: byte representing upper or lower row
;
;   Returned Values: none
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

LCD__set_cursor:
    jmp LCD__send_instruction

;================================================================================
;
;   LCD__set_cursor_second_line - sets cursor to second row, first column
;
;   Low level convenience function
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

LCD__set_cursor_second_line:
    pha                                         ; preserve A
    lda #%11000000                              ; set cursor to line 2 hardly
    jsr LCD__send_instruction
    pla                                         ; restore A

    rts

;================================================================================
;
;   LCD__render - transfers Video Ram contents onto the LCD display
;
;   Automatically breaks text into the second row if necessary but takes the
;   additional LCD memory into account
;   ————————————————————————————————————
;   Preparatory Ops: Content in Video Ram needs to be available
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================

LCD__render:
    lda #%10000000                              ; force cursor to first line
    jsr LCD__set_cursor                         
    ldx #0
.write_char:                                    ; start writing chars from video ram
    lda VIDEO_RAM,X                             ; read video ram char at X
    cpx #$10                                    ; are we done with the first line?
    beq .next_line                              ; yes - move on to second line
    cpx #$20                                    ; are we done with 32 chars?
    beq .return                                 ; yes, return from routine
    jsr LCD__send_data                          ; no, send data to lcd
    inx
    jmp .write_char                             ; repeat with next char
.next_line:
    jsr LCD__set_cursor_second_line             ; set cursort into line 2
    jsr LCD__send_data                          ; send dataa to lcd
    inx
    jmp .write_char                             ; repear with next char
.return:

    rts


;================================================================================
;
;   LCD__check_busy_flag - returns the LCD's busy status flag
;
;   Since the LCD needs clock cycles internally to process instructions, it can
;   not handle instructions at all times. Therefore it provides a busy flag,
;   which when 0 signals, that the LCD is ready to accept the next instruction
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: .A: LCD's busy flag (busy: $01, ready: $00)
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

LCD__check_busy_flag:
    lda #0                                      ; clear port A
    sta PORTA                                   ; clear RS/RW/E bits

    lda #RW                                     ; prepare read mode
    sta PORTA

    bit PORTB                                   ; read data from LCD
    bpl .ready                                  ; bit 7 not set -> ready
    lda #1                                      ; bit 7 set, LCD is still busy, need waiting
    rts
.ready:
    lda #0
.return:
    rts

;================================================================================
;
;   LCD__send_instruction - sends a control instruction to the LCD display
;
;   In contrast to data, the LCD accepts a number of control instructions as well
;   This routine can be used, to send arbitrary instructions following the LCD's
;   specification
;   ————————————————————————————————————
;   Preparatory Ops: .A: control byte (see LCD manual)
;
;   Returned Values: none
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

LCD__send_instruction:
    pha                                         ; preserve A
.loop                                           ; wait until LCD becomes ready
    jsr LCD__check_busy_flag
    bne .loop
    pla                                         ; restore A

    sta PORTB                                   ; write accumulator content into PORTB
    lda #E
    sta PORTA                                   ; set E bit to send instruction
    lda #0
    sta PORTA                                   ; clear RS/RW/E bits

    rts


;================================================================================
;
;   LCD__send_data - sends content data to the LCD controller
;
;   In contrast to instructions, there seems to be no constraint, and data can
;   be sent at any rate to the display (see LCD__send_instruction)
;   ————————————————————————————————————
;   Preparatory Ops: .A: Content Byte
;
;   Returned Values: none
;
;   Destroys:        .A
;   ————————————————————————————————————
;
;================================================================================

LCD__send_data:
    sta PORTB                                   ; write accumulator content into PORTB
    lda #(RS | E)
    sta PORTA                                   ; set E bit AND register select bit to send instruction
    lda #0
    sta PORTA                                   ; clear RS/RW/E bits

    rts

;================================================================================
;
;   LIB__bin_to_hex: CONVERT BINARY BYTE TO HEX ASCII CHARS - THX Woz!
;
;   Slighty modified version - original from Steven Wozniak for Apple I
;   ————————————————————————————————————
;   Preparatory Ops: .A: byte to convert
;
;   Returned Values: .A: LSN ASCII char
;                    .X: MSN ASCII char
;   ————————————————————————————————————
;
;================================================================================

LIB__bin_to_hex:
    ldy #$ff                                    ; state for output switching #TODO
    pha                                         ; save A for LSD
    lsr
    lsr
    lsr                     
    lsr                                         ; MSD to LSD position
    jsr .to_hex                                 ; output hex digit, using internal recursion
    pla                                         ; restore A
.to_hex
    and #%00001111                              ; mask LSD for hex print
    ora #"0"                                    ; add "0"
    cmp #"9"+1                                  ; is it a decimal digit?
    bcc .output                                 ; yes! output it
    adc #6                                      ; add offset for letter A-F
.output
    iny                                         ; set switch for second nibble processing
    bne .return                                 ; did we process second nibble already? yes
    tax                                         ; no
.return

    rts

;================================================================================
;
;   LIB__sleep - sleeps for a given amount of cycles
;
;   The routine does not actually sleep, but wait by burning cycles in TWO(!)
;   nested loops. The user can configure the number of inner cycles via .A.
;   In addition there is an outer loop, which nests the inner one, hence multiplies
;   the number of burned cycles for ALL LIB__sleep calls by a globals multiplier.
; 
;   This way the whole codebase can easily be adjusted to other clock rates then
;   1MHz. The global number of outer cycles for 1MHz is $18 and stored in WAIT
;   
;   Unfortunately this calls for errors, where the global wait is not set back
;   correctly. PR welcome
;   ————————————————————————————————————
;   Preparatory Ops: .A: byte representing the sleep duration
;
;   Returned Values: none
;
;   Destroys:       .Y
;   ————————————————————————————————————
;
;================================================================================

LIB__sleep:
    ldy #WAIT_C
    sty WAIT
.outerloop:
    tay
.loop:
    dey
    bne .loop
    dec WAIT
    bne .outerloop
    rts

message:
    .asciiz "Sixty/5o2       Bootloader v0.1"
message2:
    .asciiz "Enter Command..."
message3:
    .asciiz "Programming RAM"
message4:
    .asciiz "Awaiting data..."
message6:
    .asciiz "Loading done!"
message7:
    .asciiz "Running $0x200"
message8:
    .asciiz "Cleaning RAM    Patience please!"
MON__position_map:
    .byte $00, $01, $03, $05, $07, $09
menu_items:
    .text " Load & Run     "
    .text " Load           "
    .text " Run            "
    .text " Monitor        "
    .text " Clear RAM      "
    .text " About          "
    .text " Credits        "
about:
    .asciiz "Sixty/5o2       Bootloader and  Monitor written by Jan Roesner  <jan@roesner.it>git.io/JvTM1   "
credits:
    .asciiz "Ben Eater       6502 Project    Steven Wozniak  bin2hex routine Anke L.         love & patience"

;================================================================================
;
;   ISR - Interrupt Service Routine
;
;   This might be the most naive approach to serial RAM writing ever, but it is
;   enormously stable and effective.
;
;   Whenever the Arduino set up a data bit on the 8 data lines of VIA PortB, it
;   pulls the 6502's interrupt line low for 3 microseconds. This triggers an
;   interrupt, and causes the 6502 to lookup the ISR entry vector in memory
;   location $fffe and $ffff. This is, where this routines address is put, so
;   each time an interrupt is triggered, this routine is called.
;
;   The routine reads the current byte from VIA PortB, writes it to the RAM and
;   increases the RAM address by $01.
;
;   In addition it REsets the LOADING_STATE byte, so the BOOTLOADER__program_ram
;   routine knows, there is still data flowing in. Since there is no "Control Byte"
;   that can be used to determine EOF, it is ust assumed, that EOF is reached, when
;   no data came in for a defined number of cycles.
;
;   Important: Due to the current hardware design (interrupt line) there is no 
;              way to have the ISR service different interrupt calls.
;
;   Important: The routine is put as close to the end of the ROM as possible to
;              not fragment the ROM for additional routines. In case of additional
;              operations, the entry address needs recalculation!
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        none
;   ————————————————————————————————————
;
;================================================================================

    .org $FFC9                                  ; as close as possible to the ROM's end

ISR:
CURRENT_RAM_ADDRESS = Z0                        ; a RAM address handle for indirect writing

    pha
    tya
    pha
                                                ; for a reason I dont get, the ISR is called once with 0x00
    lda ISR_FIRST_RUN                           ; check whether we are called for the first time
    bne .write_data                             ; if not, just continue writing

    lda #1                                      ; otherwise set the first time marker
    sta ISR_FIRST_RUN                           ; and return from the interrupt

    jmp .doneisr

.write_data:
    lda #$01                                    ; progressing state of loading operation
    sta LOADING_STATE                           ; so program_ram routine knows, data's still flowing

    lda PORTB                                   ; load serial data byte
    ldy #0
    sta (CURRENT_RAM_ADDRESS),Y                 ; store byte at current RAM location

                                               ; increase the 16bit RAM location
    inc CURRENT_RAM_ADDRESS_L
    bne .doneisr
    inc CURRENT_RAM_ADDRESS_H
.doneisr

    pla                                         ; restore Y
    tay                                     
    pla                                         ; restore A

    rti

    .org $fffc                                  
    .word main                                  ; entry vector main routine
    .word ISR                                   ; entry vector interrupt service routine