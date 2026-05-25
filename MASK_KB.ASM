; =============================================================
; MASK_KB.ASM — Enmascarar/desenmascarar IRQ1 con el PIC 8259A
; =============================================================
[BITS 16]
[ORG 0x100]

; -------------------------------------------------------------
; SECCIÓN DE DATOS
; -------------------------------------------------------------
section .data

msg_mask    DB 'IRQ1 enmascarado (teclado deshabilitado)...', 0Dh, 0Ah, '$'
msg_espera  DB 'Esperando ~3 segundos...', 0Dh, 0Ah, '$'
msg_unmask  DB 'IRQ1 restaurado.', 0Dh, 0Ah, '$'
msg_fin     DB 'Programa terminado.', 0Dh, 0Ah, '$'

; -------------------------------------------------------------
; SECCIÓN DE CÓDIGO
; -------------------------------------------------------------
section .text

start:

    IN AL, 21h              ; Leer IMR actual del PIC maestro
    PUSH AX                 ; Guardar en pila para restaurar luego

    OR AL, 02h              ; Activar bit 1 = enmascarar IRQ1
    OUT 21h, AL             ; Escribir nuevo IMR al PIC maestro

    ; Confirmar que el enmascaramiento está activo
    MOV AH, 09h
    MOV DX, msg_mask        ; "IRQ1 enmascarado..."
    INT 21h

    MOV AH, 09h
    MOV DX, msg_espera      ; "Esperando ~3 segundos..."
    INT 21h

    MOV AH, 00h
    INT 1Ah                 ; CX:DX = ticks actuales
    MOV BX, DX              ; BX = tick inicial
    ADD BX, 55              ; BX = tick objetivo (~3 segundos)

.wait:
    MOV AH, 00h
    INT 1Ah                 ; Leer ticks actuales en CX:DX
    CMP DX, BX              ; ¿DX llegó al tick objetivo?
    JL .wait                ; Si no, seguir esperando

    POP AX                  ; Recuperar IMR original de la pila
    OUT 21h, AL             ; Restaurar IMR original en el PIC

    ; Confirmar restauración
    MOV AH, 09h
    MOV DX, msg_unmask      ; "IRQ1 restaurado."
    INT 21h

    MOV AH, 09h
    MOV DX, msg_fin
    INT 21h

    MOV AH, 4Ch
    XOR AL, AL
    INT 21h