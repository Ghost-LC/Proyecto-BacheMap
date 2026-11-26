import 'package:go_router/go_router.dart';

import '../../features/acceso/pantalla_login.dart';
import '../../features/acceso/pantalla_recuperacion.dart';
import '../../features/acceso/pantalla_registro.dart';
import '../../features/administracion/pantalla_barrios.dart';
import '../../features/administracion/pantalla_categorias.dart';
import '../../features/administracion/pantalla_cuentas.dart';
import '../../features/administracion/pantalla_reglas.dart';
import '../../features/evaluacion/pantalla_bandeja.dart';
import '../../features/evaluacion/pantalla_evaluar.dart';
import '../../features/mapa/pantalla_mapa.dart';
import '../../features/reparaciones/pantalla_asignar.dart';
import '../../features/reparaciones/pantalla_asignaciones.dart';
import '../../features/reparaciones/pantalla_cuadrillas.dart';
import '../../features/reparaciones/pantalla_mis_trabajos.dart';
import '../../features/reparaciones/pantalla_trabajo.dart';
import '../../features/reportes/pantalla_crear_reporte.dart';
import '../../features/reportes/pantalla_detalle_reporte.dart';
import '../../features/reportes/pantalla_mis_reportes.dart';
import '../../features/reportes/pantalla_pendientes.dart';
import '../../features/sistema/pantalla_menu.dart';
import '../../features/sistema/pantalla_salud.dart';

/// Rutas de la aplicacion. Cada iteracion agrega las de su modulo.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // M1 · Acceso y roles (I1)
    GoRoute(path: '/', name: 'login', builder: (c, s) => const PantallaLogin()),
    GoRoute(
        path: '/registro',
        name: 'registro',
        builder: (c, s) => const PantallaRegistro()),
    GoRoute(
        path: '/recuperacion',
        name: 'recuperacion',
        builder: (c, s) => const PantallaRecuperacion()),
    // Sistema
    GoRoute(path: '/menu', name: 'menu', builder: (c, s) => const PantallaMenu()),
    GoRoute(
        path: '/salud', name: 'salud', builder: (c, s) => const PantallaSalud()),
    // M2 · Reportes (I2)
    GoRoute(
      path: '/reportes',
      name: 'reportes',
      builder: (c, s) => const PantallaMisReportes(),
      routes: [
        GoRoute(
            path: 'nuevo',
            name: 'nuevo_reporte',
            builder: (c, s) => const PantallaCrearReporte()),
        GoRoute(
            path: 'pendientes',
            name: 'pendientes',
            builder: (c, s) => const PantallaPendientes()),
        GoRoute(
          path: ':id',
          name: 'detalle_reporte',
          builder: (c, s) => PantallaDetalleReporte(
            idReporte: int.parse(s.pathParameters['id']!),
          ),
        ),
      ],
    ),
    // M3 · Evaluacion (I3)
    GoRoute(
        path: '/bandeja',
        name: 'bandeja',
        builder: (c, s) => const PantallaBandeja()),
    GoRoute(
      path: '/evaluar/:id',
      name: 'evaluar',
      builder: (c, s) => PantallaEvaluar(
        idReporte: int.parse(s.pathParameters['id']!),
      ),
    ),
    // M4 · Reparaciones (I4)
    GoRoute(
        path: '/asignaciones',
        name: 'asignaciones',
        builder: (c, s) => const PantallaAsignaciones()),
    GoRoute(
      path: '/asignar/:id',
      name: 'asignar',
      builder: (c, s) =>
          PantallaAsignar(idReporte: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(
        path: '/mis-trabajos',
        name: 'mis_trabajos',
        builder: (c, s) => const PantallaMisTrabajos()),
    GoRoute(
      path: '/mis-trabajos/:id',
      name: 'trabajo',
      builder: (c, s) =>
          PantallaTrabajo(idTrabajo: int.parse(s.pathParameters['id']!)),
    ),
    // M6 · Mapa (I6)
    GoRoute(
        path: '/mapa',
        name: 'mapa',
        builder: (c, s) => const PantallaMapa()),
    // M7 · Administracion (I1)
    GoRoute(
        path: '/admin/cuadrillas',
        name: 'cuadrillas',
        builder: (c, s) => const PantallaCuadrillas()),
    GoRoute(
        path: '/admin/cuentas',
        name: 'cuentas',
        builder: (c, s) => const PantallaCuentas()),
    GoRoute(
        path: '/admin/categorias',
        name: 'categorias',
        builder: (c, s) => const PantallaCategorias()),
    // M7 · Barrios (I5)
    GoRoute(
        path: '/admin/barrios',
        name: 'barrios',
        builder: (c, s) => const PantallaBarrios()),
    // M7 · Reglas de priorizacion (RF-045, I7)
    GoRoute(
        path: '/admin/reglas',
        name: 'reglas',
        builder: (c, s) => const PantallaReglas()),
  ],
);
