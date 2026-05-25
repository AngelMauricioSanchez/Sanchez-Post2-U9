# Laboratorio: Entrada y Salida Avanzados

**Curso:** Arquitectura de Computadores  
**Herramientas:** NASM 2.x + DOSBox 0.74-3  

---

## Descripción

Este laboratorio implementa Rutinas de Servicio de Interrupción (ISR) personalizadas en ensamblador x86 que reemplazan temporalmente el handler del IRQ1 (teclado), programa el PIC 8259A para enmascarar y desenmascarar interrupciones, y verifica el flujo completo de atención de interrupción hardware en DOSBox.

---

## Archivos

| Archivo | Descripción |
|---|---|
| `ISR_KB.ASM` | ISR propio que reemplaza INT 09h y detecta 5 pulsaciones |
| `MASK_KB.ASM` | Enmascara IRQ1 durante ~3 segundos con el PIC 8259A |
| `ISR_CHAIN.ASM` | ISR encadenado que registra teclas sin interrumpir el sistema |

---

## Prerrequisitos

- DOSBox 0.74 o superior
- NASM 2.x disponible en el PATH de DOSBox
- Conocimiento de la tabla de vectores de interrupción (IVT) e INT 21h

---

## Configuración del Entorno

```
MOUNT C C:\DOSBOX
C:
mkdir U9P2
cd U9P2
nasm -v
```

Copiar los archivos `.ASM` en `C:\U9P2\`.

---

## Compilar y Ejecutar

```
nasm -f bin ISR_KB.ASM    -o ISR_KB.COM
nasm -f bin MASK_KB.ASM   -o MASK_KB.COM
nasm -f bin ISR_CH~1.ASM -o ISR_CHAIN.COM
```

Ejecutar cada programa:

```
ISR_KB
MASK_KB
ISR_CHAIN
```

---

## Descripción de Cada Programa

### ISR_KB.ASM — ISR personalizado para INT 09h

Este programa realiza un "secuestro" temporal de la interrupción de hardware INT 09h (IRQ1), que es la señal eléctrica que emite el teclado cada vez que se presiona o se suelta una tecla. El programa modifica la Tabla de Vectores de Interrupción (IVT) en modo real para apuntar a una rutina propia (mi_isr). Su función principal es contar de forma pasiva las pulsaciones de los usuarios. Al registrar exactamente 5 pulsaciones, restaura el vector original de la BIOS y finaliza de manera segura.

**Resultado esperado:** Muestra `"Tecla detectada por ISR propio"` exactamente 5 veces y termina con `"ISR restaurado. Fin del programa."`

---

### MASK_KB.ASM — Enmascaramiento de IRQ1

Lee el IMR actual del puerto 21h, activa el bit 1 (`OR AL, 02h`) para enmascarar IRQ1 y espera ~3 segundos con el timer del BIOS (INT 1Ah, 55 ticks). Durante ese tiempo el teclado no genera eventos visibles. Al finalizar restaura el IMR original con `OUT 21h, AL`.

**Resultado esperado:** Durante ~3 segundos el teclado no responde. Luego muestra `"IRQ1 restaurado."` y termina.

---

### ISR_CHAIN.ASM — ISR encadenado

Este programa avanza un paso más en el control del hardware mediante la técnica de Encadenamiento de Interrupciones (Interrupt Chaining). A diferencia del programa anterior (que bloqueaba el comportamiento normal de la computadora), este diseño actúa de manera cooperativa. Intercepta la pulsación para sumar a nuestro contador y pintar el aviso en pantalla, pero inmediatamente después deriva la ejecución hacia el handler original de la BIOS mediante un salto far simulado (PUSHF + CALL FAR).

**Resultado esperado:** Muestra `"[ISR propio] Tecla registrada."` con el número de cada pulsación, y el eco normal de DOS también aparece en pantalla. Tras 5 teclas restaura el handler y termina.

---

## Conceptos Clave

- **INT 21h / AH=35h** — Obtiene el vector actual de una interrupción. Retorna `ES:BX` = dirección del handler.
- **INT 21h / AH=25h** — Fija un nuevo vector de interrupción. Requiere `DS:DX` = dirección del nuevo handler.
- **Puerto 60h** — Data Port del 8042. Debe leerse en cada ISR de teclado para liberar la línea IRQ1.
- **Puerto 20h** — PIC maestro. Escribir `20h` envía el EOI (End Of Interrupt), sin el cual el PIC bloquea IRQs de igual o menor prioridad.
- **Puerto 21h** — IMR del PIC maestro. Bit 1 = IRQ1 (teclado). `OR AL, 02h` enmascara; `AND AL, FDh` desenmascara.
- **IRET** — Retorna de una interrupción restaurando IP, CS y FLAGS que el procesador guardó automáticamente.
- **Encadenamiento** — `PUSHF` + `CALL FAR [old_isr]` simula lo que hace `INT` internamente, permitiendo llamar al handler anterior sin romper el flujo.
- **CLI / STI** — Deshabilitan/habilitan el flag IF para proteger secciones críticas donde se modifica la IVT.
