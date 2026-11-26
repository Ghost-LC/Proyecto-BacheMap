import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';
import 'modelo_trabajo.dart';

/// RF-041 · Gestion de cuadrillas: el administrador las crea, renombra y
/// define sus integrantes (rol mantenimiento).
class PantallaCuadrillas extends StatefulWidget {
  const PantallaCuadrillas({super.key});

  @override
  State<PantallaCuadrillas> createState() => _PantallaCuadrillasState();
}

class _PantallaCuadrillasState extends State<PantallaCuadrillas> {
  List<Cuadrilla> _cuadrillas = [];
  List<Map<String, dynamic>> _cuentas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _snack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final respuestas = await Future.wait([
        dio.get('/api/reparaciones/cuadrillas'),
        dio.get('/api/administracion/cuentas'),
      ]);
      setState(() {
        _cuadrillas = (respuestas[0].data as List)
            .map((e) => Cuadrilla.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _cuentas = (respuestas[1].data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } on DioException catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar(Cuadrilla? existente, String nombre, Set<int> ids) async {
    try {
      if (existente == null) {
        await dio.post(
          '/api/reparaciones/cuadrillas',
          data: {'nombre': nombre, 'integrantes': ids.toList()},
        );
        _snack('Cuadrilla creada');
      } else {
        await dio.patch(
          '/api/reparaciones/cuadrillas/${existente.idCuadrilla}',
          data: {'nombre': nombre, 'integrantes': ids.toList()},
        );
        _snack('Cuadrilla actualizada');
      }
      await _cargar();
    } catch (e) {
      _snack(mensajeDeError(e));
    }
  }

  Future<void> _dialogoCuadrilla({Cuadrilla? existente}) async {
    final controlador = TextEditingController(text: existente?.nombre ?? '');
    final seleccion = <int>{
      if (existente != null) ...existente.integrantes.map((i) => i.idUsuario)
    };
    final mantenimiento = _cuentas
        .where((c) => c['rol'] == 'mantenimiento' && c['habilitado'] == true)
        .toList();

    final guardado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setEstado) => AlertDialog(
          title: Text(existente == null ? 'Nueva cuadrilla' : 'Editar cuadrilla'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controlador,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                Text('Integrantes (rol mantenimiento)',
                    style: Theme.of(context).textTheme.bodySmall),
                if (mantenimiento.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No hay cuentas de mantenimiento. Crealas primero en '
                      'Cuentas y roles.',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: mantenimiento
                          .map((c) => CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(c['nombre'] as String,
                                    style: const TextStyle(fontSize: 14)),
                                subtitle: Text(c['correo'] as String,
                                    style: const TextStyle(fontSize: 12)),
                                value: seleccion.contains(c['id_usuario'] as int),
                                onChanged: (valor) => setEstado(() {
                                  if (valor == true) {
                                    seleccion.add(c['id_usuario'] as int);
                                  } else {
                                    seleccion.remove(c['id_usuario'] as int);
                                  }
                                }),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    controlador.dispose();
    if (guardado != true) return;
    final nombre = controlador.text.trim();
    if (nombre.length < 2) {
      _snack('El nombre necesita al menos 2 caracteres');
      return;
    }
    await _guardar(existente, nombre, seleccion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuadrillas'),
        actions: const [BotonMenuPrincipal()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _dialogoCuadrilla(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: _cuadrillas.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.groups_outlined,
                                size: 64, color: Colors.black26),
                            SizedBox(height: 16),
                            Center(
                              child: Text(
                                'Aun no hay cuadrillas.\nCrea la primera con '
                                'el boton "Nueva".',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: _cuadrillas.length,
                          itemBuilder: (context, i) {
                            final c = _cuadrillas[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: ListTile(
                                leading: const CircleAvatar(
                                    child: Icon(Icons.groups)),
                                title: Text(c.nombre),
                                subtitle: Text(c.integrantes.isEmpty
                                    ? 'Sin integrantes'
                                    : c.integrantes
                                        .map((x) => x.nombre)
                                        .join(', ')),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: () => _dialogoCuadrilla(existente: c),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
