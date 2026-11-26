import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';

class Cuenta {
  final int id;
  final String nombre;
  final String correo;
  final String rol;
  final bool habilitado;

  const Cuenta({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.habilitado,
  });

  factory Cuenta.fromJson(Map<String, dynamic> j) => Cuenta(
        id: j['id_usuario'] as int,
        nombre: j['nombre'] as String,
        correo: j['correo'] as String,
        rol: j['rol'] as String,
        habilitado: j['habilitado'] as bool,
      );
}

/// RF-040 · Gestión de cuentas y roles (solo administrador).
class PantallaCuentas extends StatefulWidget {
  const PantallaCuentas({super.key});

  @override
  State<PantallaCuentas> createState() => _PantallaCuentasState();
}

class _PantallaCuentasState extends State<PantallaCuentas> {
  List<Cuenta> _cuentas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await dio.get('/api/administracion/cuentas');
      setState(() {
        _cuentas = (r.data as List)
            .map((e) => Cuenta.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } on DioException catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _alternar(Cuenta cuenta, bool valor) async {
    try {
      await dio.patch(
        '/api/administracion/cuentas/${cuenta.id}/habilitacion',
        data: {'habilitado': valor},
      );
      await _cargar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  Future<void> _crearCuenta() async {
    final nombre = TextEditingController();
    final correo = TextEditingController();
    final clave = TextEditingController();
    String rol = 'inspector';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Crear cuenta de personal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: correo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: clave,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: rol,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: const [
                    DropdownMenuItem(value: 'inspector', child: Text('Inspector')),
                    DropdownMenuItem(
                        value: 'mantenimiento', child: Text('Mantenimiento')),
                    DropdownMenuItem(
                        value: 'administrador', child: Text('Administrador')),
                  ],
                  onChanged: (v) => setDialog(() => rol = v ?? 'inspector'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Crear')),
          ],
        ),
      ),
    );
    if (confirmado != true) return;

    try {
      await dio.post(
        '/api/administracion/cuentas',
        data: {
          'nombre': nombre.text.trim(),
          'correo': correo.text.trim(),
          'contrasena': clave.text,
          'rol': rol,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cuenta creada')));
      }
      await _cargar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas y roles'),
        actions: const [BotonMenuPrincipal()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearCuenta,
        icon: const Icon(Icons.person_add),
        label: const Text('Nueva cuenta'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Total de cuentas: ${_cuentas.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      ..._cuentas.map(
                        (c) => Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(c.nombre.isNotEmpty
                                  ? c.nombre[0].toUpperCase()
                                  : '?'),
                            ),
                            title: Text(c.nombre),
                            subtitle: Text('${c.correo}\nRol: ${c.rol}'),
                            isThreeLine: true,
                            trailing: Switch(
                              value: c.habilitado,
                              onChanged: (v) => _alternar(c, v),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 72),
                    ],
                  ),
                ),
    );
  }
}
