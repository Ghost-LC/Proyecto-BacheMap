import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/sesion_provider.dart';
import '../../core/offline/cola_reportes.dart';
import '../../core/network/dio_client.dart';
import '../../core/storage/acceso_offline.dart';
import '../../core/storage/sesion_storage.dart';
import '../../core/theme/app_theme.dart';

class _Modulo {
  final IconData icono;
  final String titulo;
  final String detalle;
  final String? ruta; // null = disponible en una iteracion posterior
  const _Modulo(this.icono, this.titulo, this.detalle, this.ruta);
}

const Map<String, List<_Modulo>> _modulosPorRol = {
  'ciudadano': [
    _Modulo(Icons.add_photo_alternate, 'Registrar reporte',
        'Describe un daño y adjunta fotografías', '/reportes/nuevo'),
    _Modulo(Icons.flag_outlined, 'Mis reportes',
        'Consulta el estado y detalle de tus reportes', '/reportes'),
    _Modulo(Icons.sync, 'Envíos pendientes',
        'Estado y reintento de reportes guardados', '/reportes/pendientes'),
    _Modulo(Icons.map_outlined, 'Mapa de reportes', 'Explora los daños reportados',
        '/mapa'),
    _Modulo(Icons.health_and_safety, 'Verificar servidor', 'Comprueba la conexión', '/salud'),
  ],
  'inspector': [
    _Modulo(Icons.assignment_outlined, 'Bandeja de evaluación',
        'Revisa y evalúa los reportes pendientes', '/bandeja'),
    _Modulo(Icons.construction_outlined, 'Asignar reparaciones',
        'Asigna reportes aprobados a trabajadores', '/asignaciones'),
    _Modulo(Icons.report_gmailerrorred, 'Todos los reportes',
        'Consulta todos los reportes registrados', '/reportes'),
    _Modulo(Icons.map_outlined, 'Mapa de reportes', 'Explora los daños reportados',
        '/mapa'),
    _Modulo(Icons.health_and_safety, 'Verificar servidor', 'Comprueba la conexión', '/salud'),
  ],
  'mantenimiento': [
    _Modulo(Icons.work_outlined, 'Mis trabajos',
        'Consulta y actualiza tus reparaciones asignadas', '/mis-trabajos'),
    _Modulo(Icons.report_gmailerrorred, 'Todos los reportes',
        'Consulta todos los reportes registrados', '/reportes'),
    _Modulo(Icons.map_outlined, 'Mapa de reportes', 'Explora los daños reportados',
        '/mapa'),
    _Modulo(Icons.health_and_safety, 'Verificar servidor', 'Comprueba la conexión', '/salud'),
  ],
  'administrador': [
    _Modulo(Icons.groups_outlined, 'Cuentas y roles', 'Administra las cuentas del personal',
        '/admin/cuentas'),
    _Modulo(Icons.category_outlined, 'Categorías de daño', 'Gestiona los tipos de daño',
        '/admin/categorias'),
    _Modulo(Icons.engineering, 'Cuadrillas', 'Organiza los equipos de mantenimiento',
        '/admin/cuadrillas'),
    _Modulo(Icons.location_city_outlined, 'Barrios', 'Gestiona los límites de los barrios',
        '/admin/barrios'),
    _Modulo(Icons.report_gmailerrorred, 'Todos los reportes',
        'Consulta todos los reportes registrados', '/reportes'),
    _Modulo(Icons.rule_outlined, 'Reglas de priorización',
        'Configura cómo se priorizan los reportes', '/admin/reglas'),
    _Modulo(Icons.map_outlined, 'Mapa de reportes', 'Explora los daños reportados',
        '/mapa'),
    _Modulo(Icons.health_and_safety, 'Verificar servidor', 'Comprueba la conexión', '/salud'),
  ],
};

const Map<String, String> _nombresRol = {
  'ciudadano': 'Ciudadano',
  'inspector': 'Inspector municipal',
  'mantenimiento': 'Personal de mantenimiento',
  'administrador': 'Administrador',
};

/// Menu principal: muestra las funciones disponibles segun el rol de la sesion.
class PantallaMenu extends ConsumerStatefulWidget {
  const PantallaMenu({super.key});

  @override
  ConsumerState<PantallaMenu> createState() => _PantallaMenuState();
}

class _PantallaMenuState extends ConsumerState<PantallaMenu> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarSesion());
  }

  Future<void> _verificarSesion() async {
    final sesion = await ref.read(sesionProvider.future);
    if (sesion == null && mounted) context.go('/');
    if (sesion?.rol == 'ciudadano') {
      ColaReportes.instancia.iniciar();
      try {
        await ColaReportes.instancia.categorias();
      } catch (_) {
        // El formulario informará si el almacenamiento local no está disponible.
      }
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas salir de tu cuenta? Si activaste el PIN, '
            'podrás usarlo cuando el servidor no esté disponible. Los reportes pendientes '
            'permanecerán en este dispositivo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirmar != true) return;
    await ref.read(sesionProvider.notifier).cerrar();
    if (mounted) context.go('/');
  }

  Future<void> _configurarPin(Sesion sesion) async {
    final pin = TextEditingController();
    final confirmacion = TextEditingController();
    final resultado = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activar o cambiar PIN'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Necesitas conexión y una sesión válida. El PIN de 6 dígitos '
                'permitirá acceder a esta cuenta en este dispositivo cuando el servidor '
                'no esté disponible. Sustituye cualquier PIN de otra cuenta guardada.'),
            TextField(controller: pin, obscureText: true, maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nuevo PIN')),
            TextField(controller: confirmacion, obscureText: true, maxLength: 6,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Confirmar PIN')),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, [pin.text, confirmacion.text]),
              child: const Text('Guardar')),
        ],
      ),
    );
    pin.dispose();
    confirmacion.dispose();
    if (resultado == null || !mounted) return;
    if (!RegExp(r'^\d{6}$').hasMatch(resultado[0]) || resultado[0] != resultado[1]) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El PIN debe tener 6 dígitos y ambas entradas deben coincidir.')));
      return;
    }
    try {
      // La configuración no debe habilitarse con una sesión offline o caducada.
      final respuesta = await dio.get('/api/acceso/yo');
      final datos = Map<String, dynamic>.from(respuesta.data);
      final actual = await SesionStorage.leer();
      if (actual == null || actual.idUsuario != sesion.idUsuario ||
          actual.token != sesion.token || datos['id_usuario'] != sesion.idUsuario ||
          datos['rol'] != 'ciudadano') {
        throw StateError('La sesión cambió. Inicia sesión nuevamente.');
      }
      await AccesoOffline.configurar(sesion, resultado[0]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN de acceso sin conexión activado.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo activar el PIN. Comprueba la conexión y la sesión: $e')));
      }
    }
  }

  Future<void> _desactivarPin() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar acceso sin conexión'),
        content: const Text('Se eliminará el PIN guardado en este dispositivo. '
            'Los reportes pendientes no se eliminan, pero necesitarás conexión '
            'para volver a entrar hasta configurar otro PIN.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Desactivar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await AccesoOffline.eliminar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Acceso sin conexión desactivado.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo desactivar el PIN: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesionAsync = ref.watch(sesionProvider);

    return sesionAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error de sesión: $e')),
      ),
      data: (sesion) {
        if (sesion == null) {
          return const Scaffold(body: Center(child: Text('Sin sesión')));
        }
        final modulos = _modulosPorRol[sesion.rol] ?? const <_Modulo>[];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Menú principal'),
            actions: [
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.azulOscuro, AppTheme.primario],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: AppTheme.acento,
                      foregroundColor: AppTheme.azulOscuro,
                      child: Text(
                        sesion.nombre.isNotEmpty ? sesion.nombre[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BIENVENIDO A TU ESPACIO',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFFFFDB86),
                              letterSpacing: 0.9, fontWeight: FontWeight.w800,
                            )),
                        const SizedBox(height: 4),
                        Text(sesion.nombre,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                            )),
                        const SizedBox(height: 2),
                        Text(_nombresRol[sesion.rol] ?? sesion.rol,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFDCEBF4),
                            )),
                      ],
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (sesion.rol == 'ciudadano')
                Card(child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const _IconoModulo(icono: Icons.pin_outlined),
                  title: const Text('Configurar acceso sin conexión'),
                  subtitle: const Text('Activar o cambiar el PIN de este dispositivo'),
                  trailing: IconButton(
                    tooltip: 'Desactivar PIN',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _desactivarPin,
                  ),
                  onTap: () => _configurarPin(sesion),
                )),
              const SizedBox(height: 20),
              Text('¿Qué necesitas hacer?',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Selecciona una opción para continuar.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              ...modulos.map((m) => Card(
                     child: ListTile(
                       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                       leading: _IconoModulo(
                         icono: m.icono,
                         destacado: m.ruta == '/reportes/nuevo',
                       ),
                       title: Text(m.titulo),
                       subtitle: Text(m.detalle),
                      trailing: m.ruta == null
                          ? const Chip(label: Text('Pendiente'))
                          : const Icon(Icons.chevron_right),
                      onTap: m.ruta == null ? null : () => context.go(m.ruta!),
                    ),
                   )),
            ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IconoModulo extends StatelessWidget {
  const _IconoModulo({required this.icono, this.destacado = false});
  final IconData icono;
  final bool destacado;

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: destacado ? const Color(0xFFFFE8A9) : AppTheme.superficieAzul,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icono, color: destacado ? const Color(0xFF755200) : AppTheme.primario),
      );
}
