# COMANDOS BLE - Arduino Control v2b

## 📡 **COMANDOS IMPLEMENTADOS**

### **LED Builtin (PIN13)**
```
LED_ON          # Encender LED builtin
LED_OFF         # Apagar LED builtin
```

### **Pines Digitales (D2-D13)**
```
DIGITAL_2_HIGH     # Activar pin digital 2
DIGITAL_2_LOW      # Desactivar pin digital 2
DIGITAL_3_HIGH     # Activar pin digital 3
DIGITAL_3_LOW      # Desactivar pin digital 3
...
DIGITAL_13_HIGH    # Activar pin digital 13
DIGITAL_13_LOW     # Desactivar pin digital 13
```

### **Lectura de Pines Digitales**
```
READ_DIGITAL_2     # Leer estado del pin digital 2
READ_DIGITAL_3     # Leer estado del pin digital 3
...
READ_DIGITAL_13    # Leer estado del pin digital 13
READ_ALL_DIGITAL   # Leer todos los pines digitales
```

### **Lectura de Pines Analógicos**
```
READ_ANALOG_A0     # Leer valor del pin analógico A0
READ_ANALOG_A1     # Leer valor del pin analógico A1
READ_ANALOG_A2     # Leer valor del pin analógico A2
READ_ANALOG_A3     # Leer valor del pin analógico A3
READ_ANALOG_A4     # Leer valor del pin analógico A4
READ_ANALOG_A5     # Leer valor del pin analógico A5
READ_ALL_ANALOG    # Leer todos los pines analógicos
```

### **Estado General**
```
GET_STATUS         # Solicitar estado general del Arduino
```

## 🔧 **COMPATIBILIDAD PIN13**

El **PIN13** tiene compatibilidad especial:
1. **Primera opción:** Usa `LED_ON`/`LED_OFF` (compatible con v2a)
2. **Segunda opción:** Si falla, usa `DIGITAL_13_HIGH`/`DIGITAL_13_LOW`

Esto garantiza compatibilidad con códigos Arduino anteriores.

## 📱 **RESPUESTAS ESPERADAS**

El Arduino debe responder via BLE con información sobre:
- Estados de pines confirmados
- Valores leídos de pines analógicos (0-1023)
- Confirmaciones de comandos ejecutados
- Estados de error si aplica

## 🔌 **PINES SOPORTADOS**

### **Digitales (Control ON/OFF):**
- D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13

### **Analógicos (Solo Lectura):**
- A0, A1, A2, A3, A4, A5

### **LED Builtin:**
- PIN13 (LED_L en Arduino UNO R4 WiFi)

---
*Comandos definidos para Arduino UNO R4 WiFi con BLE*
*Versión: v2b*