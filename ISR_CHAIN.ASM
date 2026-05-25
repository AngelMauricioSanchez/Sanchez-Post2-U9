; CHAIN.ASM — Versión con Limpieza Dinámica de Mensaje
; Compila: nasm -f bin CHAIN.ASM -o CHAIN.COM

[BITS 16]
[ORG 0x100]

section .data
    contador DW 0         
    MAX_KEYS EQU 5
    old_isr  DD 0         
    
    msg_fin  DB 0Dh, 0Ah, "ISR encadenado restaurado. Fin del programa.$"
    msg_vram DB " [CHAIN: Tecla Detectada] " ; 26 caracteres

section .text
start:
    ; === 1. GUARDAR VECTOR ORIGINAL ===
    MOV AX, 3509h     
    INT 21h           
    MOV [old_isr], BX
    MOV [old_isr+2], ES

    ; === 2. INSTALAR ISR ===
    PUSH DS
    MOV AX, CS
    MOV DS, AX
    MOV DX, mi_isr_chain 
    MOV AX, 2509h     
    INT 21h
    POP DS
    STI               

    ; === 3. BUCLE DE ESPERA CON LIMPIEZA DINÁMICA ===
    MOV BX, [contador]   ; Guardamos el estado inicial del contador en BX
.esperar:
    HLT                  ; Relajar la CPU hasta la interrupción

    ; COMPROBACIÓN DE CAMBIO: ¿Se presionó una tecla?
    CMP [contador], BX
    JE .verificar_fin    ; Si el contador no ha cambiado, saltar a verificar el fin

    ; --- EFECTO DE RETARDO Y LIMPIEZA ---
    ; Si el contador cambió, significa que la ISR pintó el mensaje amarillo.
    ; Esperamos un microsegundo para que el ojo humano lo vea, y luego lo borramos.
    MOV CX, 0FFFFh
.delay: LOOP .delay       ; Pequeña pausa visual

    ; BORRAR EL MENSAJE DE LA PANTALLA (Escribir espacios vacíos)
    PUSH ES
    PUSH DI
    MOV AX, 0B800h
    MOV ES, AX
    MOV DI, 160          ; Apuntar a la Fila 1
    MOV CX, 26           ; Borrar los 26 caracteres del mensaje
.borrar_ciclo:
    MOV AX, 0720h        ; 20h = Espacio en blanco ASCII, 07h = Color gris estándar
    MOV [ES:DI], AX
    ADD DI, 2
    LOOP .borrar_ciclo
    POP DI
    POP ES

    MOV BX, [contador]   ; Actualizar nuestro registro de control BX con el nuevo valor

.verificar_fin:
    MOV AX, [contador]
    CMP AX, MAX_KEYS
    JL .esperar          ; Continuar esperando si no van 5 teclas

    ; === 4. RESTAURAR HANDLER ===
    CLI
    LDS DX, [CS:old_isr] 
    MOV AX, 2509h
    INT 21h
    STI

    MOV AX, CS
    MOV DS, AX

    ; === 5. DESPEDIDA ===
    MOV AH, 09h
    MOV DX, msg_fin
    INT 21h

    MOV AH, 4Ch
    INT 21h

; ── ISR CON ENCADENAMIENTO ─────────────────────────────────────────
mi_isr_chain:
    PUSHF
    CALL FAR [CS:old_isr] ; Llamar primero a la BIOS original

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DI
    PUSH ES
    PUSH DS

    ; --- PINTAR EL MENSAJE EN AMARILLO ---
    MOV AX, 0B800h
    MOV ES, AX
    MOV DI, 160          
    
    MOV AX, CS
    MOV DS, AX
    LEA BX, [msg_vram]
    MOV CX, 26           

.escribir_ciclo:
    MOV AL, [BX]
    MOV AH, 0Eh          ; Amarillo brillante
    MOV [ES:DI], AX
    INC BX
    ADD DI, 2
    LOOP .escribir_ciclo

    ; Incrementar el contador para avisarle al programa principal
    MOV AX, CS
    MOV DS, AX
    INC WORD [contador]

    POP DS
    POP ES
    POP DI
    POP CX
    POP BX
    POP AX
    IRET