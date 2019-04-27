section .rodata           
  format_string:  db "%s", 10, 0       ; format string
  format_hex:   db "%X", 0           ; format number in hexa
  prompt_str:   db "calc: ", 0
  operand_error:  db "Error: Operand Stack Overflow", 0
  args_error:   db "Error: Insufficient Number of Arguments on Stack", 0
  Y_error_message:  db "wrong Y value", 0
  newLine:      db "", 0
  debug_message:  db "Debug mode: ", 0
  stack_capacity EQU 5

section .bss
  buffer: resb 82                   ; storing input
  stack: resd stack_capacity        ; allocating 20 bytes for 5 pointers
  zero_bool_stack: resb stack_capacity  ; allocating 5 bytes for 5 booleans

section .data
  current_size: dd 0          ; amount of operands in the stack
  num_of_ops: dd 0            ; total number of operations
  new_link_address: dd 0      ; saving the current number last link address
  link_counter: dd 0          ; counter for the amount of link
  leading_zero_flag: db 0     ; flag for leading zero links
  first_link_flag: db 0       ; flag for recognizing the first link
  one_bits_counter: dd 0      ; counter for '1' bits
  last_digit_one_bits: db 0   ; save the right-most digit in one_bits function
  links_sum: dd 0             ; saves the sum of 2 links in addition
  carry_flag_value: db 0      ; saving carry-flag value for addition function
  first_link_address: dd 0    ; saving address of first link for addition function
  digit_counter: db 0         ; counter for digits
  leading_zero_counter: db 0  ; counter for leading zeros
  x_operand: dd 0             ; X operand in power operations
  debug_mode: db 0        ; 1 - debug mode is on, 0 - debug mode is off
section .text
  align 16
  global main 
  global handle_input
  extern printf 
  extern fflush
  extern malloc 
  extern calloc 
  extern free 
  extern fgets 
  extern stdin
  extern stdout
  extern stderr

main:
  mov eax, [esp + 4]        ; moving argc to eax
  cmp eax, 1            ; checking if there is only one argument
  je start_calc           ; if not - debug mode is on

  mov byte [debug_mode], 1

start_calc:
  call mycalc         ; actual function

  push eax          ; pushing number of operations on Stack
  push format_hex         ; pushing format_hex
  call printf         ; printing 
  add esp, 8          ; freeing func memory

  call newLine_printer
  ret

mycalc:
  push ebp          ; backup last activation frame
  mov ebp, esp        ; save current activation frame
  pushad            ; backup registers

  main_loop:
  push prompt_str
  push format_string
  call printf
  add esp, 8            ; remove pushed argument

  push dword [stdin]              ; reading from stdin
  push 82                       ; max length
  push buffer                   ; input buffer
  call fgets            ; reading input
  add esp, 12                     ; remove args from stack

switch:
  cmp byte [buffer], 'q'        
  je q_case
  cmp byte [buffer], '+'        
  je add_case
  cmp byte [buffer], 'p'
  je pop_and_print
  cmp byte [buffer], 'd'
  je duplicate
  cmp byte [buffer], '^'
  je power
  cmp byte [buffer], 'v'
  je negative_power
  cmp byte [buffer], 'n'
  je one_bits

  jmp operand

; eax - contains memory of current link, ecx - contains the number to print, ebx - temp memory

  pop_and_print:
    inc dword [num_of_ops]    ; increasing number of operations counter
    cmp dword [current_size], 0 ; making sure there are numbers in the stack
    jne before_pop
    call print_rator_error    ; print error message
    jmp main_loop

  before_pop:
    mov byte [first_link_flag], 1 ; initiallizing flag to true
    mov ebx, dword [current_size]   ; for memory computation
    mov eax, dword [stack+ebx*4-4]  ; saving address of first link

    .pop:       
    mov ecx, 0          ; zeroing ecx
    mov cl, byte [eax]      ; extracting actual number  
    push ecx          ; pushing the actual number to the stack
    inc dword [link_counter]  ; increasing link counted
    mov ebx, dword [eax+1]    ; saving address to next link

    push eax          ; pushing argument to free
    call free           ; freeing current link
    add esp, 4          ; freeing argument from stack

    cmp ebx, 0          ; checking if we reached the end of the link
    je print

    mov eax, ebx        ; moving address of next link to eax
    jmp .pop          ; continuing loop
    print:
    cmp dword [esp], 16         ; checking if the link has a first digit zero
    jge actual_print          ; if not - print as normal
    cmp byte [first_link_flag], 1   ; checking if it is the first link
    je actual_print           ; if yes - print without zero
    cmp dword [link_counter], 1     ; check if last link
    jne zero_print            ; if not - print as normal
    mov ebx, dword [current_size]   ; for memory access computation management purposes
    cmp byte [zero_bool_stack+ebx-1], 0 ; checking (stack)zero flag of number
    jne actual_print

    zero_print:
    push 0            
    push format_hex       ; print a zero before the digit
    call printf
    add esp, 8

    actual_print:
    mov byte [first_link_flag], 0   ; falsing first link flag after first print 
    push format_hex           ; pushing number format
    call printf           ; printing the number
    add esp, 8            ; removing the format arg and one number from the stack
    dec dword [link_counter]
    cmp dword [link_counter], 0   ; checking if finished printing
    jne print

    call newLine_printer

    dec dword [current_size]      ; removing number of arguments in the stack
    jmp main_loop

; power case vars:     
; ebx - temp
; ecx - current link
; edx - next link
; eax - al as Y, in inner loop as temp

  power: 
    inc dword [num_of_ops]        ; increasing number of operations done    
    cmp dword [current_size], 1
    jg .Y_check
    call print_rator_error      ; not emough operands in the stack, print error
    jmp main_loop
  .Y_check:
    mov ecx, 0
    mov ebx, dword [current_size]   ; for computation purposes 
    mov edx, dword [stack+ebx*4-8]  ; saving address of second linked list
    mov ecx, dword [edx+1]          ; saving address of second link
    cmp ecx, 0                      ; checking if there is a second link
    jne failed                      ; necessarily greater than 200 
    cmp byte [edx], 0xC8            ; check if Y operand exceeds 200 (= 0xC8)
    jng failed
    mov al, byte [edx]              ; Y operand
    mov ebx, dword [current_size]   ; for computation purposes 
    mov ecx, dword [stack+ebx*4-4]  ; saving address of first linked list
    mov edx, dword [stack+ebx*4-8]  ; saving address of second linked list
    mov byte [carry_flag_value], 0  ; zeroing carry_flag_value

    pushad
    push edx
    call free
    add esp, 4                      ; freeing Y arg memory (only one link by def)
    popad

    mov dword [stack+ebx*4-8], ecx   ; X overrides second linked list
    mov dword [stack+ebx*4-4], 0
    dec dword [current_size]        ; reducing amount of items in the stack

    power_loop:
      cmp al, 0                       ; check if we completed power operation
      jne .cont_loop                    ; finished operation
      cmp byte [debug_mode], 1
      jne main_loop
      call print_debug
      jmp main_loop
    .cont_loop:
      mov byte [carry_flag_value], 0  ; zeroing cf-value
      pushad                          ; backing up registers for inner loop
      shift_loop:  
        mov ebx, 0
        mov edx, 0
        mov dl, byte [ecx]                ; current link data
        mov bl, byte[carry_flag_value]    ; CF for computation purposes
        mov byte [carry_flag_value], 0    ; zeroing cf-value
        shl dl, 1                         ; multiplying current link by 2 
        adc byte [carry_flag_value], 0    ; updating value of carry_flag_value
        mov byte [ecx], dl                ; link data after multipication
        add byte [ecx], bl                ; adding carry_flag_value to link

        mov edx, dword[ecx+1]             ; save next link address
        cmp edx, 0                        ; check end of linked list
        je end_shift

        mov ecx, edx                      ; ecx updates to next link address
        jmp shift_loop                    ; begin of loop
      end_shift:
        cmp byte[carry_flag_value], 0     ; check if a new link is needed
        jne carry_link                    ; creates a new link
        popad
        dec al
        jmp power_loop                    ; end of linked list, no carry link is needed
      carry_link:
        mov bl, byte[carry_flag_value]    ; for computation purposes

        pushad
        push 1
        push 5                            ; callocating memory for link
        call calloc
        add esp, 8
        mov dword [new_link_address], eax
        popad

        mov eax, dword [new_link_address]     ; for computation purposes
        mov dword [ecx+1], eax                ; pointing last link to the created link
        mov byte [eax], 1                     ; setting value to the new link
        mov ebx, dword [current_size]         ; for computation purposes
        mov byte [zero_bool_stack+ebx-2], 0   ; signaling to print 2 zeros before the carry link
        popad   
        dec al                              ; restoring registers at the end of inner loop
        jmp power_loop

  failed:
    push Y_error_message
    push format_string
    call printf
    add esp, 8
    jmp main_loop    

; negative power case vars:     
; ebx - temp
; ecx - current link
; edx - next link
; eax - al as Y, in inner loop as prev link


  negative_power:

    inc dword [num_of_ops]        ; increasing number of operations done    
    cmp dword [current_size], 1
    jg .Y_check
    call print_rator_error      ; not emough operands in the stack, print error
    jmp main_loop
    .Y_check:
    mov ecx, 0
    mov ebx, dword [current_size]   ; for computation purposes 
    mov edx, dword [stack+ebx*4-8]  ; saving address of second linked list
    mov ecx, dword [edx+1]          ; saving address of second link
    cmp ecx, 0                      ; checking if there is a second link
    jne failed                      ; necessarily greater than 200 
    cmp byte [edx], 0xC8            ; check if Y operand exceeds 200 (= 0xC8)
    jng failed
    mov al, byte [edx]              ; Y operand
    mov ebx, dword [current_size]   ; for computation purposes 
    mov ecx, dword [stack+ebx*4-4]  ; saving address of first linked list
    mov edx, dword [stack+ebx*4-8]  ; saving address of second linked list
    mov byte [carry_flag_value], 0  ; zeroing carry_flag_value

    pushad
    push edx
    call free
    add esp, 4                      ; freeing Y arg memory (only one link by def)
    popad

    mov dword [stack+ebx*4-8], ecx   ; X overrides second linked list
    mov dword [stack+ebx*4-4], 0
    dec dword [current_size]        ; reducing amount of items in the stack

    neg_power_loop:
      cmp al, 0                       ; check if we completed power operation
      jne .cont_loop                  ; finished operation
      cmp byte [debug_mode], 1
      jne main_loop
      call print_debug
      jmp main_loop
    .cont_loop:
      mov byte [carry_flag_value], 0  ; zeroing cf-value
      pushad                          ; backing up registers for inner loop
      mov eax, 0
      .shift_loop:  
        mov ebx, 0
        mov edx, 0
        mov dl, byte [ecx]                ; current link data
        mov bl, byte[carry_flag_value]    ; CF for computation purposes
        mov byte [carry_flag_value], 0    ; zeroing cf-value
        shr dl, 1                         ; dividing current link by 2 
        adc byte [carry_flag_value], 0    ; updating value of carry_flag_value
        mov byte [ecx], dl                ; link data after division
        cmp eax, 0                        ; check if is first link in loop
        je .cont
        add byte [eax], bl                ; adding carry_flag_value to prev link
        .cont:
        mov eax, ecx                      ; eax is prev link for the next loop run
        mov edx, dword[ecx+1]             ; save next link address
        cmp edx, 0                        ; check end of linked list
        je .end_shift

        mov ecx, edx                      ; ecx updates to next link address
        jmp .shift_loop                    ; begin of loop
      .end_shift:
        cmp byte[ecx], 0                  ; check if last link data is 0 for free memory purposes 
        je free_last_link                 ; creates a new link
        popad
        dec al
        jmp neg_power_loop                ; end of linked list, no carry link is needed

        ;;;;;;;;;
      free_last_link:
        pushad
        push ecx
        call free
        add esp, 4                            ; current link memory (only one link by def)
        popad
        mov dword[eax+1], 0                   ; zeroing prev link pointer to current link 
        
        popad   
        dec al                              ; restoring registers at the end of inner loop
        jmp neg_power_loop

  ;failed:
   ; push Y_error_message
    ;push format_string
    ;call printf
    ;add esp, 8
    ;jmp main_loop 


  add_case:
    inc dword [num_of_ops]      ; increasing number of operations done
    cmp dword [current_size], 1
    jg addition
    call print_rator_error
    jmp main_loop

  addition:
  mov ebx, dword [current_size]   ; for computation purposes 
  mov ecx, dword [stack+ebx*4-4]  ; saving address of first linked list
  mov edx, dword [stack+ebx*4-8]  ; saving address of second linked list
  mov byte [carry_flag_value], 0  ; zeroing carry_flag_value

    .loop:
      mov eax, 0
      mov al, byte [carry_flag_value]   ; for computation purposes
      mov byte [carry_flag_value], 0    ; zeroing cf-value
      add byte [edx], al                ; adding carry_flag_value to link
      adc byte [carry_flag_value], 0    ; updating value of carry_flag_value

      mov al, byte [ecx]                ; for computation purposes
      add byte [edx], al                ; summing value of both links
      adc byte [carry_flag_value], 0    ; updating value of carry_flag_value

      mov eax, [ecx+1]
      mov ebx, [edx+1]                  ; saving addresses of next links

      pushad
      push ecx
      call free
      add esp, 4                            ; freeing first link memory
      popad
      
      cmp eax, 0            ; checking if the first list is finished 
      jne check_second_list

      cmp ebx, 0            ; first list finished, now checking second list
      jne first_list_finished     ; if second list is not finished, prepare its tail for chaining

      mov ecx, edx          ; moving adress of last link to ecx for convention
      cmp byte [carry_flag_value], 1  ; both lists finished, checking if there is carry left
      je create_carry_link      ; if yes - create another link containing the carry
      jmp finish_sum          ; if not - finish addition

      second_list_finished:
      mov ecx, eax        ; moving list to ecx for convention
      mov dword [edx+1], eax    ; moving the tail of the first list to the second list
    jmp finish_tail

      first_list_finished:
      mov ecx, ebx        ; moving adress of last link to ecx for convention
    jmp finish_tail

      check_second_list:        ; first list not finished
    cmp ebx, 0          ; check if second list is finished
    je second_list_finished   ; if yes - chain the tail of the first list

    mov ecx, eax          ; if not - continue the addition with the next links
    mov edx, ebx
    jmp addition.loop

    finish_tail:
    cmp byte [carry_flag_value], 1
    jne finish_sum

    add byte [ecx], 1         ; adding carry-flag to link
    mov ebx, dword [current_size]     ; for computation purposes
    mov byte [zero_bool_stack+ebx-2], 0 ; signaling to print 2 zeros before the carry link
    jnc finish_sum            ; checking if there was overflow, if not - finish

    mov byte [carry_flag_value], 1      ; updating carry_flag_value
    mov eax, dword [ecx+1]              ; saving next link address
    cmp eax, 0                          ; checking if we finished the linked list
    je create_carry_link                ; if yes - create a new link for the carry

    mov ecx, eax                        ; saving address of next link
    jmp finish_tail

  create_carry_link:
    pushad
    push 1
    push 5                              ; callocating memory for link
    call calloc
    add esp, 8
    mov dword [new_link_address], eax
    popad

    mov eax, dword [new_link_address]     ; for computation purposes
    mov dword [ecx+1], eax                ; pointing last link to the created link
    mov byte [eax], 1                     ; setting value to the new link
    mov ebx, dword [current_size]       ; for computation purposes
    mov byte [zero_bool_stack+ebx-2], 0   ; signaling to print 2 zeros before the carry link
    jmp finish_sum

  finish_sum:
    dec dword [current_size]             ; reducing amount of items in the stack
    cmp byte [debug_mode], 1
    jne main_loop
    call print_debug
    jmp main_loop

  ; create a copy of the number at the top of the stack and push it to the stack
  ; eax - address of current link, ebx - address of next link, ecx - value of link

  duplicate:
    inc dword [num_of_ops]      ; increasing number of operations done
    cmp dword [current_size], 0   ; making sure there is at least one number in the stack
    je .not_enough_operands     ; if not - send error
    cmp dword [current_size], 4 ; making sure there is enough room for the duplicate
    jng start_duplicate         ; starting to duplicate if there is enough space in the stack

    call print_operand_error    ; too many operands error
    jmp main_loop
  .not_enough_operands:
    call print_rator_error      ; not enough operands error
    jmp main_loop

  start_duplicate:
    mov ebx, dword [current_size]   ; for memory computation
    mov eax, dword [stack+ebx*4-4]  ; saving address of first link

  ; pushing data of links into stack
    .pop:       
    mov ecx, 0                ; zeroing ecx
    mov cl, byte [eax]        ; extracting actual number  
    push ecx                  ; pushing the actual number to the stack
    inc dword [link_counter]  ; increasing link counted
    mov ebx, dword [eax+1]    ; saving address to next link

    cmp ebx, 0                ; checking if we reached the end of the link
    je actual_duplicate

    mov eax, ebx              ; moving address of next link to eax
    jmp .pop                  ; continuing loop

  ; extracting pushed data to make the new linked list
    actual_duplicate:
    push 1              ; size of char for calloc
    push 5              ; num of bytes to callocate (1 for digits + 4 for pointer)
    call calloc         ; allocating memory for the first link
    add esp, 8          ; remove pushed argument

    mov ebx, dword [current_size]   ; putting current_size in ebx for memory addition
    mov dword [stack+ebx*4], eax    ; storing pointer to linked list in the stack

    dec dword [link_counter]

    duplicate_loop:
      pop ecx               ; storing data in ecx
      mov byte [eax], cl        ; putting data in the new link

      mov ecx, dword [zero_bool_stack+ebx-1]    ; saving in ecx duplicated zero flag
      mov dword [zero_bool_stack+ebx], ecx      ; duplicating zero flag

      cmp dword [link_counter], 0           ; checking if we finished duplicating the linked list
      je end_duplicate

      dec dword [link_counter]    ; decreasing amount of links left
      mov edx, eax                    ; saving address of previous link

      pushad
      push 1                          ; size of char for calloc
      push 5                          ; num of bytes to callocate (1 for digits + 4 for pointer)
      call calloc                     ; allocating memory for the first link
      add esp, 8                      ; remove pushed argument
      mov dword [new_link_address], eax     ; saving returned adress
      popad

      mov eax, dword [new_link_address] 
      mov ebx, dword [current_size]       ; for memory computation
      mov dword [stack+ebx*4], eax        ; pushing address of link on to the stack
      mov [eax+1], edx                ; storing the next link address in current link
      jmp duplicate_loop

    end_duplicate:
      inc dword [current_size]
      cmp byte [debug_mode], 1
      jne main_loop
      call print_debug
      jmp main_loop

  ; prints the amount of '1' bits in the number at the top of the stack
  one_bits:
    inc dword [num_of_ops]        ; increasing number of operations done
    cmp dword [current_size], 0   ; making sure there is at least one number in the stack
    je .not_enough_operands       ; if not - send error
    jmp count_bits

  .not_enough_operands:
    call print_rator_error        ; not enough operands error
    jmp main_loop

  count_bits:
    mov ebx, dword [current_size]   ; for memory computation
    mov eax, dword [stack+ebx*4-4]  ; saving address of first link
    mov dword [one_bits_counter], 0 ; initiallizing counter for '1' bits

    .loop:
    mov edx, 8            ; initiallizing edx to 8 for shr operations
    mov ecx, 0            ; zeroing ecx
    mov cl, byte [eax]      ; extracting actual number  

    count_bits_loop:
      shr ecx, 1            ; shr ecx in order to count '1' bits
      jnc skip
      inc dword [one_bits_counter]      ; adding the carry-flag value to the counter

    skip:
      dec edx                 ; removing number of iterations left
      cmp edx, 0                ; checking if finished iteration
      jne count_bits_loop

    ready_next_link:
      mov ebx, dword [eax+1]    ; saving address to next link

      push eax
      call free           ; freeing memory of current link
      add esp, 4

      cmp ebx, 0          ; checking if we reached the end of the link
      je finish_one_bits

      mov eax, ebx        ; saving address of next link in eax
      jmp count_bits.loop

    finish_one_bits:
      cmp dword [one_bits_counter], 255 ; checking if need 2 links or 1 is enough
      jg handle_two_links

      push 1                  ; size of char for calloc
      push 5                  ; num of bytes to callocate (1 for digits + 4 for pointer)
      call calloc               ; allocating memory for the first link
      add esp, 8                ; remove pushed argument

      mov ebx, dword [one_bits_counter]
      mov [eax], ebx              ; storing the amount of one_bits in the link
      mov ebx, dword [current_size]     ; for memory computation
      mov dword [stack+ebx*4-4], eax      ; pushing link to the stack instead of the old number
      jmp finish_func

    handle_two_links:
      push 1            ; size of char for calloc
      push 5            ; num of bytes to callocate (1 for digits + 4 for pointer)
      call calloc         ; allocating memory for the first link
      add esp, 8          ; remove pushed argument
    
      mov ebx, dword [one_bits_counter]   ; for computation purposes
      shr ebx, 4              ; getting rid of the least significant digit
      mov byte [eax], bl          ; insert value in first link
      mov dword [new_link_address], eax   ; save links address

      mov eax, dword [one_bits_counter] ; for div computation purposes
      mov edx, 0
      mov ebx, 0x10           ; for div computation purposes
      div ebx
      mov byte [last_digit_one_bits], dl  ; saves digit for later use

      push 1            ; size of char for calloc
      push 5            ; num of bytes to callocate (1 for digits + 4 for pointer)
      call calloc         ; allocating memory for the second link
      add esp, 8          ; remove pushed argument

      mov ebx, dword [new_link_address]     ; moving adress of old link to ebx
      mov dword [eax+1], ebx            ; storing pointer to 2nd link in first link
      mov ecx, dword [current_size]       ; for computation purposes
      mov dword [stack+ecx*4-4], eax        ; store pointer to link in the stack in the place of the old number

      mov bl, byte [last_digit_one_bits]    ; for computation purposes
      mov byte [eax], bl          ; put the remaining value in the link
    finish_func:
      cmp byte [debug_mode], 1
      jne main_loop
      call print_debug
      jmp main_loop

  operand:
    cmp dword [current_size], stack_capacity    ; checking if stack is full
    jne count_digits
    call print_operand_error
    jmp main_loop

  count_digits:
    mov byte [digit_counter], 0        ; zeroing counter
    mov edx, 0                         ; index for buffer
    mov byte [leading_zero_flag], 1    ; zeroing leading_zero_flag
    .loop:
    cmp byte [buffer+edx], 0xA       ; check for '\n'
    je read_operand
    cmp byte [leading_zero_flag], 1  ; checking if we started reading the actual number
    jne read_actual_number

    cmp byte [buffer+edx], '0'         ; checking if current char is a '0'
    je read_leading_zero
    mov byte [leading_zero_flag], 0

    read_actual_number:
    inc edx
    inc byte [digit_counter]
    jmp count_digits.loop

    read_leading_zero: 
    inc edx
    jmp count_digits.loop

  read_operand:
    sub dl, byte [digit_counter]        ; saving number of leading zeros for later use
    cmp byte [digit_counter], 0       ; checking if there where only zeros as input
    je create_zero_link           ; if yes - create a solo link containing zero

    mov byte [leading_zero_counter], dl      ; for later use
    mov eax, 0
    mov al, byte [digit_counter]             ; for computation purposes
    mov edx, 0
    mov ebx, 0x2
    div ebx                           ; digit_counter % 2
    cmp edx, 0
    je read_operand_even

  read_operand_odd:
    push 1              ; size of char for calloc
    push 5              ; num of bytes to callocate (1 for digits + 4 for pointer)
    call calloc         ; allocating memory for the first link
    add esp, 8          ; remove pushed argument

    mov ebx, [current_size]           ; putting current_size in ebx for memory addition
    mov dword [stack+ebx*4], eax      ; storing pointer to linked list in the stack

    mov ebx, 0
    mov bl, byte [leading_zero_counter]
    mov edx, 0                      ; zeroing edx
    mov dl, byte [buffer+ebx]         ; reading first odd digit
    cmp dl, '9'                     ; checkinf if number or letter
    jg .letter
    sub dl, '0'                     ; turning from ascii to actual value
    jmp enter_to_odd_link

    .letter:
    sub dl, 55                    ; turning from ascii to actual value

    enter_to_odd_link:
    mov byte [eax], dl                  ; storing current numbers in the linked list
    mov ecx, 0
    mov cl, byte [leading_zero_counter] ; increasing index of buffer by amount of leading zeros
    inc ecx                             ; increasing index of input buffer

    cmp byte [buffer+ecx], 0xA        ; check if finished reading the number
    je end_loop                       ; if yes - finish

    mov edx, eax                    ; saving address of previous link
    pushad                        ; backup registers
    push 1                        ; size of char for calloc
    push 5                        ; num of bytes to callocate (1 for digits + 4 for pointer)
    call calloc                     ; allocating memory for next link
    add esp, 8              ; remove pushed argument
    mov dword [new_link_address], eax   ; saving returned adress
    popad                         ; restore registers

    mov eax, dword [new_link_address]   ; for memory access computation management
    mov ebx, [current_size]       ; for computation purposes
    mov dword [stack+ebx*4], eax    ; storing pointer to linked list in the stack
    mov [eax+1], edx                ; storing the next link address in current link
    jmp operand_loop

  read_operand_even:
    push 1              ; size of char for calloc
    push 5              ; num of bytes to callocate (1 for digits + 4 for pointer)
    call calloc         ; allocating memory for the first link
    add esp, 8          ; remove pushed argument

    mov ebx, [current_size]           ; putting current_size in ebx for memory addition
    mov dword [stack+ebx*4], eax      ; storing pointer to linked list in the stack

    mov ecx, 0
    mov cl, byte [leading_zero_counter]  ; initiallizing ecx as input index
    mov byte [leading_zero_flag], 1      ; initiallizing flag to true

    operand_loop:
    mov edx, 0                ; zeroing edx
    mov dh, byte [buffer+ecx]     ; extracting current numbers to dx
    cmp dh, '9'               ; checking if it is a number or a letter
    jg .letter
    sub dh, '0'               ; turning to number from ascii
    jmp check_zero

    .letter:
      sub dh, 55              ; reducing to match letter value in hex

    check_zero:
    cmp dh, 0
    je zero
    mov byte [zero_bool_stack+ebx], 1   ; signaling not zero-something
    jmp continue
    zero:
    mov byte [zero_bool_stack+ebx], 0   ; signaling zero-something

    continue:
    cmp byte [buffer+ecx+1], 0xA      ; checking if there is an odd number of digits
    jne second_digit
    mov byte [zero_bool_stack+ebx], 1   ; signaling not to add zero
    shr edx, 8                    ; adjusting in case of odd number of digits
    mov byte [eax], dl              ; storing current numbers in the linked list
    jmp end_loop

    second_digit:
    shr dx, 4                 ; adjusting the number 
    add dl, byte [buffer+ecx+1]   ; moving current numbers to edx
    cmp byte [buffer+ecx+1], '9'  ; checking if the second_digit is a letter
    jg .letter      
    sub dl, '0'               ; turning to number from ascii
    jmp continue_read_second  
    .letter: 
      sub dl, 55              ; turning letter to actual hex value

    continue_read_second:
    cmp dl, 0                 ; checking if the whole number is 0
    jne enter_to_link           ; if not - continue normally
    cmp byte [leading_zero_flag], 0 ; check if there are leading zeros
    je enter_to_link            ; if not - continue normally

    inc ecx                   ; increase input index
    inc ecx 
    jmp operand_loop            ; continue reading

    enter_to_link:
    mov byte [leading_zero_flag], 0 ; no leading zeros from this point
    mov byte [eax], dl            ; storing current numbers in the linked list

    inc ecx             ; increasing index of input buffer
    inc ecx             ; same

    cmp byte [buffer+ecx], 0xA      ; check if finished reading the number
    je end_loop                 ; if yes - finish

    mov edx, eax                ; saving address of previous link
    pushad                    ; backup registers
    push 1                    ; size of char for calloc
    push 5                    ; num of bytes to callocate (1 for digits + 4 for pointer)
    call calloc                     ; allocating memory for next link
    add esp, 8                      ; remove pushed argument
    mov dword [new_link_address], eax   ; saving returned adress
    popad                         ; restore registers

    mov eax, dword [new_link_address]   ; for memory access computation management
    mov dword [stack+ebx*4], eax        ; storing pointer to linked list in the stack
    mov [eax+1], edx                ; storing the next link address in current link
    jmp operand_loop

  end_loop:
    inc dword [current_size]          ; increasing amount of items in the stack
    cmp byte [debug_mode], 1      ; check if debug mode is on
    jne main_loop             ; if not, end
    call print_debug          ; if yes - print debug message
    jmp main_loop

  create_zero_link:
  push 1              ; size of char for calloc
    push 5              ; num of bytes to callocate (1 for digits + 4 for pointer)
    call calloc         ; allocating memory for the first link
    add esp, 8          ; remove pushed argument

    mov ebx, [current_size]             ; putting current_size in ebx for memory addition
    mov dword [stack+ebx*4], eax        ; storing pointer to linked list in the stack
  inc dword [current_size]      ; increasing amount of numbers in the stack

    mov byte [eax], 0         ; inserting 0 in the link
    jmp main_loop


  print_rator_error:
    pushad                ; backup registers

    push args_error         ; pushing error message
    push format_string        ; pushing format
    call printf             ; printing error messsage
    add esp, 8              ; remove args from stack

    popad                 ; restore registers
    ret

  print_operand_error:
    pushad

    push operand_error    ; pushing error message
    push format_string    ; pushing format
    call printf           ; printing error messsage
    add esp, 8            ; remove args from stack

    popad
    ret

  newLine_printer:
    pushad

    push newLine
    push format_string    ; new line
    call printf
    add esp, 8            ; removing args

    popad
    ret

  print_debug:
    mov byte [first_link_flag], 1     ; flagging first link
    mov ebx, dword [current_size]     ; for computation purposes
    mov eax, dword [stack + ebx*4 - 4]  ; saving address of first link in the list
    push eax              ; pushing onto stack adress of first link
    call print_loop

    add esp, 8
    call newLine_printer
    jmp main_loop             ; after returning from last link, return to main loop

    print_loop:
      mov eax, dword [esp+4]      ; get argument of recursion - address of current link
      cmp dword [eax+1], 0      ; check if reached the last link
      je last_link

      mov ebx, dword [eax+1]      ; save address of next link
      push ebx
      call print_loop

      add esp, 4            ; removing last link from stack
      mov ecx, 0
      mov edx, dword [esp+4]
      mov cl, byte [edx]

      cmp cl, 16          ; checking if only 1 digit
      jg print_normally
      call print_zero       ; adding a 0 before the solo digit

    print_normally:
      pushad
      push ecx
      push format_hex
      call printf
      add esp, 8
      popad
      ret

      last_link:
        pushad
        mov ebx, 0          ; zeroing ebx
        mov bl, byte [eax]      ; mov to ebx the actual number
        push ebx          ; push first arg of printf
        push format_hex       ; push second arg of printf
        call printf
        add esp, 8
        popad
        ret

  print_zero:
    pushad
    push 0
    push format_hex
    call printf
    add esp, 8
    popad
    ret

  q_case:
    cmp dword [current_size], 0
    je quit

    mov ebx, dword [current_size]   ; for memory computation
    mov eax, dword [stack+ebx*4-4]  ; saving address of first link

    free_loop:
    mov ebx, dword [eax+1]      ; saving address to next link

    pushad
    push eax
    call free           ; freeing memory of current link
    add esp, 4
    popad

    cmp ebx, 0          ; checking if we reached the end of the link
    je quit

    mov eax, ebx        ; saving address of next link in eax
    jmp free_loop

    dec dword [current_size]    ; decreasing amount of stacks in args
    jmp q_case
    
  quit:
    popad             ; restore registers
    mov eax, [num_of_ops]   ; return value
    mov esp, ebp        ; freeing func AF
    pop ebp           ; restore AF of main
    ret
