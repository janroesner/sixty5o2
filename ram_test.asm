;================================================================================
;
;                                   "Ram Test"
;                                    _________
;
;                                      v0.1
;
;   Ram Test - Simple module to test the RAM in a 6502 system 
;
;   Written by Chris McBrien <jjack.flash42@gmail.com> for Sixty/5o2 by Jan Roesner
;   
;   Credits:
;               - Ben Eater             (Project 6502)
;               - Steven Wozniak        (bin2hex routine)
;               - Anke L.               (love, patience & support)
;               - Jan Roesner           (Sixty/5o2)
;
;================================================================================
;   Constants
RAM_TEST__STATUS_RUNNING            = $0
RAM_TEST__STATUS_FAIL               = $1
RAM_TEST__STATUS_PASS               = $2
RAM_TEST__LAST_BYTE                 = $3fd7             ; 2 bytes - Last address in RAM which can be tested
RAM_TEST__FIRST_BYTE                = $0006             ; 2 bytes - First address in RAM which can be tested
RAM_TEST__NUM_PATTERNS              = $04               ; 1 byte  - Number of patterns
;   Variables
RAM_TEST_TARGET                     = $04               ; 2 bytes - Zero-page vector for RAM location to test
RAM_TEST__STATUS                    = $3fd9             ; 1 byte  - Indicates the test current status
RAM_TEST__CURRENT_PATTERN_OFFSET    = $3fd8             ; 1 byte  - The bit pattern read/written to RAM

;================================================================================
;
;  RAM_TEST__main - main entry point for the ram test function
;
;   Writes various bit patterns to all accessible RAM locaitons and verifies 
;   that the same value is read back.  
;   The stack page is skipped.  
;   Some reserved bytes in the zero-page and at the end of RAM are not tested.
;   When complete the test result is displaed on the LCD.  If the test failed,
;   then the memory location which caused the failure is also shown.
;   Pressing the 'exit' (left-key) will return to the Sixty/5o2 bootloader menu.
;   ————————————————————————————————————
;   Preparatory Ops: none
;
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;
;   ————————————————————————————————————
;
;================================================================================
RAM_TEST__main:
  jsr .display_start_msg
  lda #RAM_TEST__STATUS_RUNNING
  sta RAM_TEST__STATUS                      ; set the status to running
  ldx #RAM_TEST__NUM_PATTERNS - 1
  stx RAM_TEST__CURRENT_PATTERN_OFFSET       ; initialize with the first test bit-pattern
.main_loop
  jsr .test_pattern                         ; run a test with the current bit-pattern
  ldy RAM_TEST__STATUS
  bne .main_done                            ; exit if no longer running
  dec RAM_TEST__CURRENT_PATTERN_OFFSET      ; set to the next test bit-pattern
  ldy #255                                  ; done with all patterns?
  cpy RAM_TEST__CURRENT_PATTERN_OFFSET
  beq .main_done                            ; exit if all of the patterns have been run
  jmp .main_loop
.main_done
  cpy #RAM_TEST__STATUS_FAIL
  beq .main_fail                            ; test failed?
  lda #RAM_TEST__STATUS_PASS
  sta RAM_TEST__STATUS
  jsr .display_pass                         ; show that test passed
  jmp .main_exit
.main_fail  
  jsr .display_fail
.main_exit:
  rts
  

;================================================================================
;
;   .display_start_msg - displays message indicating the RAM test is about to start` 
;
;   ————————————————————————————————————
;   Preparatory Ops: none
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================    
.display_start_msg:
  jsr LCD__clear_video_ram
  lda #<RAM_TEST__START_MSG
  ldy #>RAM_TEST__START_MSG
  jsr LCD__print
  jsr .long_wait
  rts


;================================================================================
;
;   .display_fail - displays a message on the LCD indicating that the test failed 
;
;   Shows the memory location that failed
;   and waits for the 'exit' (left) key to be pressed
;
;   ————————————————————————————————————
;   Preparatory Ops: RAM_TEST_TARGET - contains the last address to be tested
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;   ————————————————————————————————————
;
;================================================================================  
.display_fail:
  jsr LCD__clear_video_ram
  lda #<RAM_TEST__FAIL_MSG
  ldy #>RAM_TEST__FAIL_MSG
  jsr LCD__print                            ; show fail message
  lda RAM_TEST_TARGET + 1
  ldx #12
  jsr .print_hex_num                        ; show high-byte of failed memory location
  lda RAM_TEST_TARGET
  ldx #14
  jsr .print_hex_num                        ; show low-byte of failed memory location
  jsr LCD__render
  jsr LCD__print_text.wait_for_input        ; wait for the exit key to be pressed
  rts
  

;================================================================================
;
;   .display_pass - displays a test passed message on the LCD
;
;   Shows the message and waits for the 'exit' (left) key to be pressed
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
.display_pass:
  lda #<RAM_TEST__PASS_MSG
  ldy #>RAM_TEST__PASS_MSG
  ldx #1
  jsr LCD__print_text
  rts


;================================================================================
;
;  .test_pattern - Tests all available RAM using a pattern of bits
;
;   ————————————————————————————————————
;   Preparatory Ops:  RAM_TEST__FIRST_BYTE - contains first testable byte
;                     RAM_TEST__LAST_BYTE - contains last testable byte
;                     RAM_TEST__CURRENT_PATTERN_OFFSET - contains offset into pattern array
;               
;   Returned Values:  RAM_TEST__STATUS - Indicates that the test passed or failed
;
;   Destroys:         .A, .X, .Y
;
;   ————————————————————————————————————
;
;================================================================================    
.test_pattern:
  lda #<RAM_TEST__FIRST_BYTE        
  sta RAM_TEST_TARGET               
  lda #>RAM_TEST__FIRST_BYTE
  sta RAM_TEST_TARGET + 1               ; put first testable byte in zero-page vector
  ldx RAM_TEST__CURRENT_PATTERN_OFFSET
  lda RAM_TEST__PATTERNS, x             ; put the test bit-pattern in .A
  jsr .display_page                     
.pattern_loop:
  sta (RAM_TEST_TARGET)                 ; write a test pattern to RAM
  cmp (RAM_TEST_TARGET)                 ; read the pattern back
  bne .pattern_fail                     ; stop if they don't match
  inc RAM_TEST_TARGET                   ; move to next location in RAM
  bne .continue_same_page   
  inc RAM_TEST_TARGET + 1               ; move to next page
  jsr .display_page                     ; show the current page under test on the LCD
  ldx #$1                   
  cpx RAM_TEST_TARGET + 1               ; check for stack-page
  bne .pattern_continue             
  inc RAM_TEST_TARGET + 1               ; skip stack-page
  jsr .display_page
.continue_same_page:
  ldx #>RAM_TEST__LAST_BYTE             ; if on the last testable page....
  cpx RAM_TEST_TARGET + 1
  bne .pattern_continue
  ldx #<RAM_TEST__LAST_BYTE           
  cpx RAM_TEST_TARGET
  bne .pattern_continue
  jmp .pattern_end                      ; end if on the last testable byte
.pattern_continue:
  jmp .pattern_loop
.pattern_fail:
  ldx #RAM_TEST__STATUS_FAIL
  stx RAM_TEST__STATUS
.pattern_end:
  rts


;================================================================================
;
;  .display_page - Shows a progress message on the LCD 
;
;  Provides the pattern being used for testing and the page in memory being tested
;
;   ————————————————————————————————————
;   Preparatory Ops:  RAM_TEST_TARGET + 1 - contains the memory being being tested
;                     RAM_TEST__CURRENT_PATTERN_OFFSET - contains offset into pattern array
;               
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;
;   ————————————————————————————————————
;
;================================================================================      
.display_page:
  pha
  jsr LCD__clear_video_ram
  ldx RAM_TEST__CURRENT_PATTERN_OFFSET
  lda RAM_TEST__PATTERNS, x             ; get the bit-pattern of the current test
  ldx #0                                ; offset into video ram 
  jsr .print_hex_num                    ; show the current test pattern stored in A
  lda #' '          
  sta VIDEO_RAM + 2                     ; append a space character
  lda #<RAM_TEST__PAGE_MSG
  ldy #>RAM_TEST__PAGE_MSG
  ldx #3
  jsr LCD__print_with_offset            ; append 'PAGE='
  lda RAM_TEST_TARGET + 1               ; the current page in RAM of the test
  ldx #8                                
  jsr .print_hex_num
  jsr LCD__render
  pla
  rts


;================================================================================
;
;  .print_hex_num - Prints a hex number
;
;  Displays a 2-digit hex value on the LCD by directly appending to video RAM
;
;   ————————————————————————————————————
;   Preparatory Ops:  .A - contains the value to print
;                     .X - contains the current offset into video RAM
;               
;   Returned Values: none
;
;   Destroys:        .A, .X, .Y
;
;   ————————————————————————————————————
;
;================================================================================        
.print_hex_num:
  stx Z3                      ; save offset into video RAM

  jsr LIB__bin_to_hex         ; get the ASCII representation
  stx Z2                      ; save the low-digit

  ldx Z3                      ; restore video RAM location
  sta VIDEO_RAM, x            ; put high-digit in video RAM
  inx                         ; move to next character position
  lda Z2                      ; restore low-digit
  sta VIDEO_RAM, x            ; put low-digit in video RAM

  rts


;================================================================================
;
;  .long_wait - Provides a long wait 
;
;  Gives a timeout to allow the user to read messages before they disappear
;
;   ————————————————————————————————————
;   Preparatory Ops:  none
;               
;   Returned Values: none
;
;   Destroys:        .X, .Y 
;
;   ————————————————————————————————————
;
;================================================================================            
.long_wait:
  ldx #0
  ldy #0                    ; count down from 256 * 256
.wait_loop:
  nop  
  dex
  bne .wait_loop
  dey
  bne .wait_loop
  rts  

RAM_TEST__PAGE_MSG:
  string "PAGE="
RAM_TEST__PASS_MSG:
  string "PASS"
RAM_TEST__START_MSG:
  string "Starting RAM test..."
RAM_TEST__FAIL_MSG:
  string "FAILURE AT $"
RAM_TEST__PATTERNS:
  byte $00, $ff, $aa, $55