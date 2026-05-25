; ISR_KB.ASM — ISR personalizado para IRQ1 (teclado) - VERSIÓN COMPLETA Y SEGURA
; Compila: nasm -f bin ISR_KB.ASM -o ISR_KB.COM

[BITS 16]
[ORG 0x100]

section .data
    contador DW 0         ; Número de teclas atendidas
    MAX_KEYS EQU 5
    old_isr  DD 0         ; Almacena SEG:OFF del handler original de la BIOS
    
    msg_fin  DB 0Dh, 0Ah, "ISR restaurado. Fin del programa.$"
    
    ; Mensaje para volcar directo a la VRAM dentro de la ISR (24 caracteres exactos)
    msg_vram DB " [ISR: Tecla Detectada] " 

section .text
start:
    ; === 1. GUARDAR VECTOR ORIGINAL INT 09h ===
    MOV AX, 3509h     ; AH=35h: Obtener vector actual de la INT 09h
    INT 21h           ; Retorna ES:BX = dirección física del handler actual
    MOV [old_isr], BX
    MOV [old_isr+2], ES

    ; === 2. INSTALAR ISR PROPIO ===
    PUSH DS
    MOV AX, CS
    MOV DS, AX
    MOV DX, mi_isr    ; DS:DX = dirección de nuestra nueva rutina de interrupción
    MOV AX, 2509h     ; AH=25h: Fijar nuevo vector para la INT 09h
    INT 21h
    POP DS
    STI               ; Asegurar que las interrupciones generales estén habilitadas

    ; === 3. BUCLE DE ESPERA SEGURO ===
.esperar:
    HLT               ; Duerme la CPU emulada hasta que ocurra una interrupción (evita saturar DOSBox)
    MOV AX, [contador]
    CMP AX, MAX_KEYS
    JL .esperar       ; Repetir bucle hasta procesar 5 pulsaciones

    ; === 4. RESTAURAR HANDLER ORIGINAL (Modificación de Seguridad) ===
    CLI               ; Deshabilitar interrupciones durante el cambio crítico de vectores
    
    ; Usamos el prefijo [CS:] para asegurar que lea 'old_isr' directamente desde 
    ; el segmento de código, evitando desalineamientos de memoria en DOSBox.
    LDS DX, [CS:old_isr] 
    
    MOV AX, 2509h     ; Restaurar el vector original de la BIOS
    INT 21h
    STI               ; Rehabilitar interrupciones globales

    ; Forzamos que DS vuelva a apuntar al segmento de nuestro programa
    MOV AX, CS
    MOV DS, AX

    ; === 5. MENSAJE DE DESPEDIDA ===
    MOV AH, 09h
    MOV DX, msg_fin
    INT 21h

    ; Terminar programa regresando al sistema operativo de forma limpia
    MOV AH, 4Ch
    INT 21h

; ── ISR PROPIO (Rutina de Interrupción de Hardware para IRQ1) ──────────
mi_isr:
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DI
    PUSH ES
    PUSH DS

    ; Leer y descartar el scancode del buffer del teclado (Puerto 60h)
    ; Obligatorio para liberar el controlador 8042 y permitir más teclas
    IN AL, 60h

    ; --- ESCRIBIR EN LA MEMORIA DE VIDEO (Alternativa segura a INT 21h) ---
    MOV AX, 0B800h    ; Dirección base del segmento de memoria de video (Modo Texto)
    MOV ES, AX
    MOV DI, 160       ; Ubicación: Fila 1, Columna 0 (Evita pisar el prompt de DOS)
    
    MOV AX, CS
    MOV DS, AX
    LEA BX, [msg_vram] ; DS:BX apunta al string del mensaje
    MOV CX, 24        ; Cantidad de caracteres a transferir

.escribir_ciclo:
    MOV AL, [BX]      ; Cargar carácter ASCII
    MOV AH, 0Fh       ; Atributo: Texto blanco brillante con fondo negro
    MOV [ES:DI], AX   ; Escribir directamente en el búfer de la pantalla
    INC BX
    ADD DI, 2         ; Avanzar 2 bytes (1 byte carácter + 1 byte atributo)
    LOOP .escribir_ciclo

    ; Incrementar el contador global apuntando al segmento correcto
    MOV AX, CS
    MOV DS, AX
    INC WORD [contador]

    ; --- ENVIAR EOI (End Of Interrupt) AL PIC MAESTRO (Puerto 20h) ---
    ; Le notifica al controlador de interrupciones que la IRQ1 ya fue atendida
    MOV AL, 20h
    OUT 20h, AL

    POP DS
    POP ES
    POP DI
    POP CX
    POP BX
    POP AX
    IRET              ; Retorno de interrupción: restaura FLAGS, CS e IP de golpe