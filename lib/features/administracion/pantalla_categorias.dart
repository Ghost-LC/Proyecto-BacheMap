import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/dio_client.dart';
import '../../core/widgets/boton_menu.dart';

class Categoria {
  final int id;
  final String nombre;
  final bool habilitada;

  const Categoria({required this.id, required this.nombre, required this.habilitada});

  factory Categoria.fromJson(Map<String, dynamic> j) => Categoria(
        id: j['id_categoria'] as int,
        nombre: j['nombre'] as String,
        habilitada: j['habilitada'] as bool,
      );
}

/// RF-042 · Gestión de categorías de daño (solo administrador).
class PantallaCategorias extends StatefulWidget {
  const PantallaCategorias({super.key});

  @override
  State<PantallaCategorias> createState() => _PantallaCategoriasState();
}

class _PantallaCategoriasState extends State<PantallaCategorias> {
  List<Categoria> _categorias = [];
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
      final r = await dio.get('/api/administracion/categorias');
      setState(() {
        _categorias = (r.data as List)
            .map((e) => Categoria.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } on DioException catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _alternar(Categoria c, bool valor) async {
    try {
      await dio.patch(
        '/api/administracion/categorias/${c.id}',
        data: {'habilitada': valor},
      );
      await _cargar();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  Future<void> _crear() async {
    final nombre = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva categoría de daño'),
        content: TextField(
          controller: nombre,
          decoration: const InputDecoration(labelText: 'Nombre'),
          autofocus: true,
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
    );
    if (confirmado != true) return;
    try {
      await dio.post(
        '/api/administracion/categorias',
        data: {'nombre': nombre.text.trim()},
      );
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
        title: const Text('Categorías de daño'),
        actions: const [BotonMenuPrincipal()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
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
                          'Las categorías deshabilitadas dejan de ofrecerse al '
                          'registrar un reporte; los reportes existentes la conservan.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      ..._categorias.map(
                        (c) => Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: Icon(
                              c.habilitada
                                  ? Icons.check_circle
                                  : Icons.cancel_outlined,
                              color: c.habilitada ? Colors.green : Colors.red,
                            ),
                            title: Text(c.nombre),
                            subtitle:
                                Text(c.habilitada ? 'Habilitada' : 'Deshabilitada'),
                            trailing: Switch(
                              value: c.habilitada,
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
