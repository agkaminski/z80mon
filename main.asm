ROM_BEGIN	equ 0x0000
ROM_END		equ	0x1FFF
RAM_BEGIN	equ	0x8000
RAM_END		equ	0x9FFF

CR			equ	0x0D
LF			equ	0x0A
TAB			equ	0x09
BS			equ	0x7F

;variables
rxd_buff	equ	0x9E00

rxd_rptr	equ	0x9F00
rxd_wptr	equ	0x9F01
addr_l		equ	0x9F02
addr_h		equ	0x9F03
tmp			equ	0x9F04		;4 bytes

;io ports
UDR			equ	0x00

org 0x0000
reset:	ld sp, 0x9F20
		
		ld a, 0
		ld (rxd_rptr), a
		ld (rxd_wptr), a
		
		;set up interrupts
		im 1
		ei
		jp main
		
;print routine
org 0x0020
		jp print
		
;uart write routine
org 0x0028
		jp txd

;uart read routine
org 0x0030
		jp rxd_pop

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
		jp z, read
		
		cp 'e'
		jp z, execute

		cp ':'
		jp z, intelhex
		
		cp 'h'
		jr z, main_help
		
		ld hl, invalid_msg
		rst 0x20
		jr main_loop

read:
		call get_addr
		;todo
		jp main_loop
		
write:
		call get_addr
		;todo
		jp main_loop
		
execute:
		call get_addr
		;todo
		jp main_loop

intelhex:
		;todo
		jp main_loop

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
		ld c, (hl)
		inc hl
		ld b, (hl)
		ld h, c
		ld l, c
		call hex2byte
		ld (addr_h), a
		
		ld hl, tmp+2
		ld c, (hl)
		inc hl
		ld b, (hl)
		ld h, c
		ld l, c
		call hex2byte
		ld (addr_l), a
		
		ld hl, new_line
		rst 0x20
		ret
		
;general purpose routines

;checks if digit is valid hexadecimal
;sets carry if not
ishex:
		cp '0'
		jr c, ishex_no
		cp ':'
		jr nc, ishex_no_digit
		ccf
		ret
ishex_no_digit:
		cp 'A'
		jr c, ishex_no
		cp 'G'
		jr nc, ishex_lower
		ccf
		ret
ishex_lower
		cp 'a'
		jr c, ishex_no
		cp 'g'
		jr nc, ishex_no
		ccf
		ret
ishex_no:
		scf
		ret

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

;sends byte in a
txd:
		out (UDR), a
		ret

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
		
