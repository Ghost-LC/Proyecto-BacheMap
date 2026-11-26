# Guía de estilo: Reporte de Baches y Daños Viales

## Identidad

La interfaz representa un servicio ciudadano y municipal para identificar y atender daños viales. La identidad combina **azul institucional** (confianza y servicio), **ámbar de señalización** (atención en la vía) y superficies claras para facilitar la lectura. El ámbar es un acento; no indica por sí solo que exista una emergencia.

El nombre del proyecto es **BacheMap**. Su icono combina un marcador geográfico, una vía, un bache y una señal de atención. La imagen maestra está en `assets/branding/bachemap_icon.png`; `tool/generar_icono_bachemap.py` permite regenerarla y exportar los tamaños de Android e iOS. Es una identidad de una propuesta académica, no un logotipo municipal oficial.

## Paleta

La fuente de las constantes generales es `lib/core/theme/app_theme.dart`.

| Uso | Color | Código |
|---|---|---|
| Acción principal y enlaces | Azul institucional | `#174B78` |
| Barra superior y cabeceras | Azul profundo | `#102F4B` |
| Acento vial y acción flotante | Ámbar | `#FFC247` |
| Fondo general | Gris azulado claro | `#F3F6F8` |
| Tarjetas y campos | Blanco | `#FFFFFF` |
| Texto principal | Azul tinta | `#172B3B` |
| Texto secundario | Gris azulado | `#516778` |
| Bordes | Gris claro | `#DCE5EB` |
| Fondo de iconos | Azul pálido | `#E8F1F7` |
| Error | Rojo | `#B3261E` |

Los pares principales calculados de contraste son aproximadamente: blanco sobre azul institucional **9,07:1**, blanco sobre azul profundo **13,72:1**, azul tinta sobre fondo general **13,39:1**, texto secundario sobre blanco **5,90:1** y azul profundo sobre ámbar **8,53:1**. Estos cálculos corresponden a colores sólidos; no certifican el contraste de toda la aplicación, degradados, imágenes, estados deshabilitados ni tamaños de texto.

## Estados de reporte

Definidos en `lib/features/reportes/modelo_reporte.dart`; el color siempre se acompaña de una etiqueta:

| Estado | Color |
|---|---|
| Reportado | Azul grisáceo `#496374` |
| Pendiente de revisión | Ocre oscuro `#855300` |
| Aprobado para intervención | Azul `#315B8A` |
| En reparación | Violeta `#6D4C84` |
| Reparado | Verde `#246B4B` |
| Cerrado / descartado | Gris `#52616C` |

El último estado engloba tanto cierres exitosos como descartes; por eso se utiliza un color neutral y no se presupone que todos sean errores.

## Componentes y tipografía

- Material 3 y fuente nativa del sistema, sin descarga ni dependencia de fuentes externas.
- Títulos con mayor peso y cuerpo de texto regular; conservar escalado de texto del sistema.
- Tarjetas blancas con borde suave y esquinas redondeadas; fondo general diferenciado.
- Botones principales azules, secundarios delineados y acción flotante ámbar. Los botones del tema tienen altura mínima de 50 píxeles lógicos; no forzar un ancho que desborde botones en filas o diálogos.
- Campos con fondo blanco, contorno visible y foco azul; errores con mensaje textual, no solo color.
- Espaciado habitual en múltiplos de 4 u 8 píxeles lógicos. Mantener etiquetas descriptivas para iconos y acciones.
- Los mapas e imágenes no deben ser la única forma de comunicar una acción o estado. No usar el color como único indicador.

## Comprobación visual

Antes de distribución, probar con los cuatro roles, pantallas pequeñas, texto ampliado, teclado abierto, errores, diálogos, navegación, conexión lenta y sin conexión. Verificar contraste de componentes específicos y navegación con lector de pantalla en dispositivos reales. El diseño actual no supone soporte de tema oscuro.
