# Adaptive Quant Framework (AQF)

# Software Requirements Specification (SRS)

Version: 0.1

---

# 1. Objetivo

Desarrollar un framework de trading algorítmico para MetaTrader 5 capaz de ejecutar estrategias cuantitativas de forma automática, modular, segura y escalable.

La primera estrategia implementada será:

**AQF XAU Scalper**

---

# 2. Requisitos Funcionales

## RF-001 Configuración

El usuario deberá poder configurar todos los parámetros del robot desde MetaTrader 5 sin modificar el código fuente.

---

## RF-002 Gestión del Riesgo

El framework deberá:

- Calcular automáticamente el tamaño del lote.
- Controlar el riesgo por operación.
- Controlar el drawdown máximo.
- Controlar el riesgo diario.
- Controlar el número máximo de operaciones abiertas.
- Validar el margen disponible antes de abrir una operación.

---

## RF-003 Análisis del Mercado

El sistema deberá analizar:

- Tendencia.
- Volatilidad.
- Spread.
- Sesión de mercado.
- Liquidez.
- Momentum.

---

## RF-004 Generación de Señales

Cada estrategia deberá devolver únicamente uno de estos estados:

- BUY
- SELL
- NO TRADE

---

## RF-005 Ejecución

El sistema deberá poder:

- Abrir órdenes.
- Cerrar órdenes.
- Modificar Stop Loss.
- Modificar Take Profit.
- Aplicar Break Even.
- Aplicar Trailing Stop.
- Gestionar múltiples posiciones.

---

## RF-006 Estadísticas

El framework deberá registrar:

- Hora.
- Precio de entrada.
- Precio de salida.
- Beneficio.
- Pérdida.
- Drawdown.
- Spread.
- Slippage.
- Duración.
- Comisión.

---

## RF-007 Exportación

Toda la información deberá poder exportarse a archivos CSV.

---

# 3. Requisitos No Funcionales

El framework deberá ser:

- Modular.
- Escalable.
- Reutilizable.
- Fácil de mantener.
- Documentado.
- Programado mediante Programación Orientada a Objetos.

---

# 4. Restricciones

El proyecto será desarrollado utilizando:

- MetaTrader 5
- MQL5
- Git
- GitHub

---

# 5. Reglas del Proyecto

Las siguientes reglas son obligatorias:

- No utilizar Martingala.
- No utilizar Grid Martingale.
- No duplicar código.
- Una clase por responsabilidad.
- Todas las estrategias deberán ser independientes del núcleo del framework.
- Todo evento importante deberá registrarse en el Logger.

---

# 6. Estrategia Inicial

Nombre:

AQF XAU Scalper

Activo:

XAUUSD

---

# 7. Futuras Estrategias

El framework deberá permitir incorporar nuevas estrategias sin modificar el núcleo.

Ejemplos:

- XAU Scalper
- NASDAQ Scalper
- EURUSD Swing
- BTC Momentum

---

# 8. Criterios de Éxito

El proyecto se considerará exitoso cuando:

- El framework compile sin errores.
- Permita ejecutar estrategias de forma modular.
- Genere estadísticas completas.
- Sea posible ampliar el proyecto sin reescribir el código existente.

---

# Fin del Documento