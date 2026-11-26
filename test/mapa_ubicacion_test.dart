import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/core/widgets/mapa_ubicacion.dart';

void main() {
  testWidgets('rechaza coordenadas fuera de rango', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MapaUbicacion(latitud: 100, longitud: 0)),
    ));
    expect(find.text('La ubicación registrada no es válida.'), findsOneWidget);
    expect(find.text('Toca para ampliar'), findsNothing);
  });

  testWidgets('permite abrir el mapa de una ubicación válida', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MapaUbicacion(latitud: -21.535, longitud: -64.73)),
    ));
    expect(find.text('Toca para ampliar'), findsOneWidget);
    await tester.tap(find.text('Toca para ampliar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ubicación del reporte'), findsOneWidget);
    expect(find.textContaining('La marca indica la ubicación registrada'), findsOneWidget);
  });
}
