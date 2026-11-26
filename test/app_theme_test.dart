import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/core/theme/app_theme.dart';
import 'package:movil/features/reportes/modelo_reporte.dart';

double contraste(Color a, Color b) {
  final claro = math.max(a.computeLuminance(), b.computeLuminance());
  final oscuro = math.min(a.computeLuminance(), b.computeLuminance());
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  test('los colores principales mantienen contraste para texto', () {
    expect(contraste(Colors.white, AppTheme.primario), greaterThanOrEqualTo(4.5));
    expect(contraste(Colors.white, AppTheme.azulOscuro), greaterThanOrEqualTo(4.5));
    expect(contraste(AppTheme.tinta, AppTheme.fondo), greaterThanOrEqualTo(4.5));
    expect(contraste(AppTheme.textoSecundario, Colors.white), greaterThanOrEqualTo(4.5));
    expect(contraste(AppTheme.azulOscuro, AppTheme.acento), greaterThanOrEqualTo(4.5));
  });

  test('cada estado conserva etiqueta y contraste sobre su color', () {
    for (final estado in EstadosReporte.etiquetas.keys) {
      expect(EstadosReporte.etiqueta(estado), isNotEmpty);
      expect(contraste(Colors.white, EstadosReporte.color(estado)),
          greaterThanOrEqualTo(4.5), reason: estado);
    }
  });
}
