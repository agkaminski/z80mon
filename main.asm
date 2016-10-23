ROM_BEGIN	equ 0x0000
ROM_END		equ	0x1FFF
RAM_BEGIN	equ	0x8000
RAM_END		equ	0x9FFF

CR			equ	0x0D
LF			equ	0x0A
TAB			equ	0x09
BS			equ	0x7F
SPACE		equ	0x20

;variables
rxd_buff	equ	0x9E00

rxd_rptr	equ	0x9F00
rxd_wptr	equ	0x9F01
addr_l		equ	0x9F02
addr_h		equ	0x9F03
byte_buff	equ 0x9F04
tmp			equ	0x9F05		;4 bytes

;io ports
UDR			equ	0x00

org 0x0000
reset:	ld sp, RAM_END
		
		ld a, 0
		ld (rxd_rptr), a
		ld (rxd_wptr), a
		
		;set up interrupts
		im 1
		ei
		jp main

org 0x0010		

org 0x0018
		
;print routine
org 0x0020
		jp print
		db 'PRINT'
		
;uart write routine
org 0x0028
		jp txd
		db 'TXD', 0, 0

;uart read routine
org 0x0030
		jp rxd_pop
		db 'RXD', 0, 0

;interrupt service routine
org 0x0038
irq:	push af
		push bc
		push hl
		in a, (UDR)
		ld b, a
		ld h, high rxd_buff
		ld a, (rxd_rptr)
		ld l, a
		ld a, (rxd_wptr)
		inc a
		cp l
		jr z, irq_buffer_full
		dec a
		ld l, a
		ld (hl), b
		inc a
		ld (rxd_wptr), a
irq_buffer_full:
		pop hl
		pop bc
		pop af
		ei
		ret
		
;######################################

main_done:
		ld hl, done_msg
		rst 0x20
		jr main_loop
main:
		ld hl, welcome_msg
		rst 0x20
		
main_help:
		ld hl, menu_msg
		rst 0x20
		
main_loop:
		ld a, 0
		rst 0x30
		
		cp 'r'
		jp z, read
		
		cp 'w'
		jp z, write
		
		cp 'm'
		jp z, modify
		
		cp 'e'
		jp z, execute

		cp ':'
		jp z, intelhex
		
		cp 'h'
		jr z, main_help
		
		ld hl, invalid_msg
		rst 0x20
		ld b, a
		ld a, 0x27	;'
		rst 0x28
		ld a, b
		rst 0x28
		ld a, 0x27	;'
		rst 0x28
		ld hl, new_line
		rst 0x20
		jr main_loop
		
;######################################

read:
		ld hl, read_addr_msg
		rst 0x20
		call get_addr
		
		ld hl, read_len_msg
		rst 0x20
		call get_byte
		jr c, main_done		;user aborted
		
		ld a, (addr_h)
		ld h, a
		ld a, (addr_l)
		and 0xF0
		ld l, a
		
		ld a, (byte_buff)
		ld d, a
		ld a, 0
		ld e, a
		
read_loop:	
		ld a, d
		cp 0
		jp z, main_done
		dec a
		ld d, a
		
		ld a, e
		cp 0
		call z, print_addr
		
		ld a, e
		cp 0
		jr nz, read_no_new_line
		ld a, 16
read_no_new_line:
		dec a
		ld e, a
		
		ld a, (hl)
		inc hl
		call byte2hex
		
		ld a, b
		rst 0x28
		ld a, c
		rst 0x28
		ld a, SPACE
		rst 0x28
		
		jr read_loop

;######################################
		
write:
		ld hl, write_addr_msg
		rst 0x20
		call get_addr

		ld a, (addr_h)
		ld h, a
		ld a, (addr_l)
		ld l, a	
		
write_loop:
		;print begin address
		call print_addr
		
		ld c, 0
		
		push hl
		call get_byte_loop		;skip msg print
		pop hl
		jp c, main_done			;user aborted
		
		ld a, (byte_buff)
		ld (hl), a
		inc hl
		
		jr write_loop
		
;######################################
		
modify:
		call get_addr
		;todo
		jp main_loop
		
;######################################
		
execute:
		call get_addr
		;todo
		jp main_loop

;######################################

intelhex:
		;todo
		jp main_loop
		
;######################################

get_addr:	
		ld hl, address_msg
		rst 0x20
		ld c, 0		;number of aquired digits
		ld hl, tmp
		
get_addr_loop:
		ld a, 0
		rst 0x30
		cp BS
		jr z, get_addr_bs
		cp CR
		jr z, get_addr_enter
		ld b, a
		ld a, c
		cp 4
		jr z, get_addr_loop
		ld a, b
		call ishex
		jr c, get_addr_loop
		inc c
		rst 0x28
		ld (hl), a
		inc hl
		jr get_addr_loop
get_addr_bs:
		ld a, c
		cp 0
		jr z, get_addr_loop
		ld a, BS
		rst 0x28
		dec c
		dec hl
		jr get_addr_loop
get_addr_enter:
		ld a, c
		cp 4
		jr nz, get_addr_loop
		
		ld hl, tmp
		ld b, (hl)
		inc hl
		ld c, (hl)
		ld h, b
		ld l, c
		call hex2byte
		ld (addr_h), a
		
		ld hl, tmp+2
		ld b, (hl)
		inc hl
		ld c, (hl)
		ld h, b
		ld l, c
		call hex2byte
		ld (addr_l), a
		
		ld hl, new_line
		rst 0x20
		ret
		
;######################################
		
get_byte:	
		ld hl, byte_msg
		rst 0x20
		ld c, 0		;number of aquired digits
		
get_byte_loop:
		ld a, 0
		rst 0x30
		cp BS
		jr z, get_byte_bs
		cp CR
		jr z, get_byte_enter
		cp 'q'
		jr z, get_byte_aborted
		ld b, a
		ld a, c
		cp 2
		jr z, get_byte_loop
		ld a, b
		call ishex
		jr c, get_byte_loop
		inc c
		rst 0x28
		ld b, a
		ld a, c
		cp 2
		jr z, get_byte_store_low
		ld h, b
		jr get_byte_loop
get_byte_aborted:
		ld hl, abort_msg
		rst 0x20
		scf
		ret
get_byte_store_low
		ld l, b
		jr get_byte_loop
get_byte_bs:
		ld a, c
		cp 0
		jr z, get_byte_loop
		ld a, BS
		rst 0x28
		dec c
		jr get_byte_loop
get_byte_enter:
		ld a, c
		cp 2
		jr nz, get_byte_loop
		
		call hex2byte
		ld (byte_buff), a
		
		ld hl, new_line
		rst 0x20
		scf
		ccf
		ret
		
;######################################
		
;general purpose routines

print_addr:
		ld a, CR
		rst 0x28
		ld a, LF
		rst 0x28
		ld a, h
		call byte2hex
		ld a, b
		rst 0x28
		ld a, c
		rst 0x28
		ld a, l
		call byte2hex
		ld a, b
		rst 0x28
		ld a, c
		rst 0x28
		ld a, SPACE
		rst 0x28
		ret

;######################################

;converts value in a to hex
;returns 2 ascii hex character in bc (b, c) == (high, low)
byte2hex:
		ld b, a
		call nibble2hex
		ld c, a
		ld a, b
		srl a
		srl a
		srl a
		srl a
		call nibble2hex
		ld b, a
		ret

;convers nibble to hex
;in a, out a
nibble2hex:
		and 0x0F
		cp 10
		jr c, nibble2hex_digit
		sub 10
		add a, 'A'
		ret
nibble2hex_digit:
		add a, '0'
		ret
		
;######################################
		
;checks if digit is valid hexadecimal
;sets carry if not
ishex:
		cp '0'
		jr c, ishex_no
		cp ':'
		jr nc, ishex_no_digit
		scf
		ccf
		ret
ishex_no_digit:
		cp 'A'
		jr c, ishex_no
		cp 'G'
		jr nc, ishex_lower
		scf
		ccf
		ret
ishex_lower
		cp 'a'
		jr c, ishex_no
		cp 'g'
		jr nc, ishex_no
		scf
		ccf
		ret
ishex_no:
		scf
		ret
		
;######################################

;reads hexadecimal value (in HL) to byte (to A)
hex2byte:
		push bc
		ld a, h
		call hex2nibble
		sla a
		sla a
		sla a
		sla a
		ld b, a
		ld a, l
		call hex2nibble
		or b
		pop bc
		ret
		
;reads one hexadecimal character	
hex2nibble:
		cp 'a'
		jr nc, hex2nibble_nup
		cp 'A'
		jr nc, hex2nibble_up
		sub '0'
		ret
hex2nibble_nup:
		sub 'a'
		add a, 10
		ret
hex2nibble_up:
		sub 'A'
		add a, 10
		ret
		
;######################################

;pop received byte from the buffer
;if a == 0 wait for data if the buffer is empty
;returns received byte in a
rxd_pop:
		push bc
		push hl
rxd_pop_loop:
		ld c, a
		di		;can't allow irq to interrupt us now
		ld a, (rxd_wptr)
		ld l, a
		ld a, (rxd_rptr)
		cp l
		jr z, rxd_pop_empty
		ld h, high rxd_buff
		ld l, a
		ld a, (hl)
		ei		;reenable interrupts
		inc l
		ld b, a
		ld a, l
		ld (rxd_rptr), a
		ld a, b
rxd_pop_end:		
		pop hl
		pop bc
		ret
rxd_pop_empty:
		ei
		ld a, c
		cp 0
		jr nz, rxd_pop_end
		halt	;wait for data
		jr rxd_pop_loop
		
;######################################

;sends byte in a
txd:
		out (UDR), a
		ret
		
;######################################

;prints string till terminator (\0)
;pointer to the string in HL
print:
		push af
print_loop:
		ld a, (HL)
		inc hl
		cp 0
		jr z, print_end
		out (UDR), a
		jr print_loop
print_end:
		pop af
		ret
		
;######################################
		
;constants storage
welcome_msg:
		db 'Z80simple system monitor', CR, LF, 'A.Kaminski 2016', CR, LF, 0

menu_msg:
		db 'Avaiable options:', CR, LF, TAB, 'h - this help', CR, LF, TAB, 'r - read memory', CR, LF, TAB, 'w - write memory', CR, LF, TAB, 'e - execute program', CR, LF, TAB, ': - Intel HEX (just send line)', CR, LF, 0

new_line:
		db CR, LF, 0
	
invalid_msg:
		db 'Invalid choice: ', CR, LF, 0
		
address_msg:
		db 'Input address (hex): ', 0

byte_msg:
		db 'Input byte (hex): ', 0
		
done_msg:
		db CR, LF, 'Done.', CR, LF, 0
		
abort_msg:
		db CR, LF, 'Aborted.', CR, LF, 0

read_addr_msg:
		db 'Provide start address for read', CR, LF, 0
		
read_len_msg:
		db 'Provide number of bytes to read', CR, LF, 0
		
write_addr_msg:
		db 'Provide start address for write', CR, LF, 0
		
write_len_msg:
		db 'Provide number of bytes to write', CR, LF, 0
		
