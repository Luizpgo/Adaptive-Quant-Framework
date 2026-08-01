# Adaptive Quant Framework (AQF)

# Software Architecture

Version: 0.1

---

# 1. Purpose

Adaptive Quant Framework (AQF) es una plataforma de trading algorítmico desarrollada para MetaTrader 5.

El objetivo del framework es desacoplar completamente la lógica de trading del resto del sistema para permitir desarrollar múltiples estrategias sobre una misma infraestructura.

---

# 2. Architectural Principles

El framework seguirá los siguientes principios:

- Modularidad
- Bajo acoplamiento
- Alta cohesión
- Programación orientada a objetos
- Reutilización de componentes
- Separación de responsabilidades
- Escalabilidad
- Mantenibilidad

---

# 3. High Level Architecture

                +------------------------+
                |        AQF EA          |
                +-----------+------------+
                            |
                            v
                  +---------+----------+
                  |   Core Controller  |
                  +---------+----------+
                            |
    --------------------------------------------------------
    |          |             |            |                |
    v          v             v            v                v

 Risk Engine  Market Engine Strategy Engine Trade Engine Statistics Engine

---

# 4. Core Controller

El Core Controller es el cerebro del framework.

Responsabilidades:

- Inicializar módulos.
- Coordinar comunicación.
- Controlar el ciclo OnInit().
- Controlar OnTick().
- Controlar OnTimer().
- Controlar OnTrade().
- Finalizar recursos.

Nunca contendrá lógica de trading.

---

# 5. Risk Engine

Responsabilidades:

- Calcular tamaño del lote.
- Gestión del riesgo.
- Control de drawdown.
- Protección de capital.
- Límites diarios.
- Validación de margen.
- Gestión de exposición.

---

# 6. Market Engine

Responsabilidades:

- Analizar tendencia.
- Analizar volatilidad.
- Detectar sesiones.
- Analizar spread.
- Analizar liquidez.
- Detectar consolidaciones.
- Calcular ATR.
- Calcular momentum.

No toma decisiones de compra.

Solo analiza.

---

# 7. Strategy Engine

Responsabilidades:

Convertir la información del Market Engine en señales.

Ejemplo:

BUY

SELL

NO TRADE

El Strategy Engine nunca enviará órdenes.

---

# 8. Trade Engine

Responsabilidades:

Abrir órdenes.

Cerrar órdenes.

Modificar Stop Loss.

Modificar Take Profit.

Trailing Stop.

Break Even.

Gestión del Basket.

Control de posiciones.

---

# 9. Statistics Engine

Responsabilidades:

Registrar absolutamente todo.

Operaciones.

Drawdown.

Tiempo.

Spread.

Volumen.

Profit.

Comisiones.

Slippage.

Exportación CSV.

---

# 10. Logger

Todo evento deberá quedar registrado.

Ejemplos:

Inicio.

Errores.

Órdenes.

Cierres.

Advertencias.

Eventos críticos.

---

# 11. Configuration

Toda configuración será externa.

Nunca se utilizarán constantes internas cuando puedan convertirse en parámetros.

---

# 12. Data Flow

Tick

↓

Market Engine

↓

Strategy Engine

↓

Risk Engine

↓

Trade Engine

↓

Statistics Engine

↓

Logger

---

# 13. Scalability

El framework permitirá agregar nuevas estrategias sin modificar el núcleo.

Ejemplo:

AQF XAU Scalper

AQF NASDAQ Scalper

AQF EURUSD Swing

AQF BTC Momentum

Todos compartirán:

- Risk Engine
- Trade Engine
- Statistics Engine
- Logger

---

# 14. Coding Rules

Cada clase tendrá una única responsabilidad.

Máximo recomendado:

500 líneas por archivo.

Funciones pequeñas.

Código documentado.

Sin duplicación.

Sin variables globales innecesarias.

---

# 15. Future Modules

Learning Engine

Optimization Engine

Machine Learning Engine

Portfolio Manager

Cloud Synchronization

AI Decision Engine

Dashboard

Remote Monitoring

Telegram Notifications

REST API

---

# End of Document