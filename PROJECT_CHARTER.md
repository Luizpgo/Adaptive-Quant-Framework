# Adaptive Quant Framework (AQF)

## Project Charter

### Version
0.1

---

# Project Vision

Adaptive Quant Framework (AQF) es una plataforma profesional de trading algorítmico para MetaTrader 5 diseñada para desarrollar, probar y optimizar estrategias cuantitativas de manera modular.

AQF no es un único robot de trading.

Es un framework que permitirá implementar múltiples estrategias utilizando un mismo núcleo de gestión del riesgo, análisis del mercado, estadísticas y registro de datos.

La primera estrategia desarrollada será:

**AQF XAU Scalper**

---

# Mission

Desarrollar un framework de trading robusto, mantenible y extensible que permita construir estrategias de calidad profesional utilizando una arquitectura modular.

---

# Long-Term Goals

- Framework completamente modular.
- Gestión de riesgo adaptativa.
- Motor de ejecución profesional.
- Sistema de estadísticas avanzado.
- Backtesting reproducible.
- Forward testing automatizado.
- Aprendizaje basado en datos históricos.
- Optimización continua basada en evidencia.

---

# Non-Negotiable Rules

Las siguientes reglas nunca podrán romperse.

## Trading

- No utilizar Martingala.
- No utilizar Grid Martingale.
- Nunca aumentar el riesgo después de pérdidas.
- El tamaño del lote será dinámico.
- Todas las estrategias deberán poder desactivarse independientemente.

## Software

- Arquitectura modular.
- Programación orientada a objetos.
- Código documentado.
- Código reutilizable.
- Sin funciones gigantes.
- Sin código duplicado.

---

# First Strategy

AQF XAU Scalper

Mercado:

XAUUSD

Plataforma:

MetaTrader 5

Lenguaje:

MQL5

---

# Development Methodology

El proyecto será desarrollado utilizando Sprints.

Cada Sprint deberá producir una versión funcional.

Cada Sprint deberá actualizar:

- CHANGELOG
- ROADMAP
- Documentación

---

# Success Criteria

El proyecto se considerará exitoso cuando:

- El framework sea estable.
- Sea posible agregar nuevas estrategias sin modificar el núcleo.
- Todas las estrategias puedan evaluarse mediante backtesting y forward testing.
- La documentación permita que otro desarrollador continúe el proyecto.