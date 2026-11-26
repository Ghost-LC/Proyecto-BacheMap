import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:movil/main.dart';

void main() {
  testWidgets('La app carga en la pantalla de inicio de sesion', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: Aplicacion()));
    await tester.pump(); // post-frame callback de la pantalla
    expect(find.text('Reporte de Baches y Daños Viales'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Regístrate como ciudadano'), findsOneWidget);
  });
}
