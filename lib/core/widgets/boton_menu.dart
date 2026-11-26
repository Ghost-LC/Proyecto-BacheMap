import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Boton en la AppBar para volver al menu principal.
///
/// Se agrega a todas las pantallas de la aplicacion porque, al navegar con
/// `context.go`, no queda historial y el boton Atras del telefono cerraria
/// la aplicacion en las pantallas de primer nivel.
class BotonMenuPrincipal extends StatelessWidget {
  const BotonMenuPrincipal({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: 'Menu principal',
      onPressed: () => context.go('/menu'),
    );
  }
}
