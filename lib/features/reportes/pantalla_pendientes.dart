import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/offline/cola_reportes.dart';
import '../../core/widgets/boton_menu.dart';

class PantallaPendientes extends StatefulWidget {
  const PantallaPendientes({super.key});

  @override
  State<PantallaPendientes> createState() => _PantallaPendientesState();
}

class _PantallaPendientesState extends State<PantallaPendientes> {
  final cola = ColaReportes.instancia;
  @override
  void initState() {
    super.initState();
    cola.iniciar();
  }

  Future<void> _eliminar(Map<String, Object?> fila) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar registro local'),
        content: const Text('Se eliminarán los datos y fotografías locales. '
            'Si un envío anterior llegó al servidor pero se perdió la respuesta, '
            'el reporte podría existir allí. Comprueba Mis reportes antes de crear otro.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await cola.eliminar(fila['id'] as String);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _cambiarCategoria(String id) async {
    try {
      final categorias = await cola.categorias();
      if (!mounted) return;
      if (categorias.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay categorías disponibles. Conéctate y vuelve a intentar.')));
        return;
      }
      final seleccion = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Elige una categoría vigente'),
          children: categorias.map((c) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, c['id_categoria'] as int),
            child: Text(c['nombre'] as String),
          )).toList(),
        ),
      );
      if (seleccion != null) await cola.cambiarCategoria(id, seleccion);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Envíos de reportes'),
          actions: const [BotonMenuPrincipal()]),
      body: ValueListenableBuilder<int>(
        valueListenable: cola.cambios,
        builder: (context, _, _) => FutureBuilder<List<Map<String, Object?>>>(
          future: cola.listar(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Error al leer los envíos: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final filas = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Los envíos se intentan automáticamente mientras la aplicación está abierta. '
                    'Necesitas conexión y una sesión válida.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => cola.sincronizar(),
                  icon: const Icon(Icons.sync), label: const Text('Sincronizar ahora')),
                if (filas.isEmpty) const Padding(
                  padding: EdgeInsets.all(24), child: Text('No hay envíos guardados en esta cuenta.')),
                ...filas.map((fila) {
                  final datos = Map<String, dynamic>.from(jsonDecode(fila['datos'] as String));
                  final estado = fila['estado'] as String;
                  final etiquetas = {'pendiente': 'Pendiente de envío', 'enviando': 'Enviando',
                    'error': 'Requiere atención', 'enviado': 'Enviado al municipio'};
                  final fecha = DateTime.tryParse(fila['creado'] as String)?.toLocal();
                  return Card(child: ListTile(
                    title: Text(datos['descripcion'] as String),
                    subtitle: Text('${etiquetas[estado] ?? estado}'
                        '${fecha == null ? '' : '\n${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}'}'
                        '${fila['error'] == null ? '' : '\n${fila['error']}'}'
                        '${fila['id_remoto'] == null ? '' : '\nReporte #${fila['id_remoto']}'}'),
                    isThreeLine: true,
                    trailing: Wrap(children: [
                      if (estado == 'error' || estado == 'pendiente')
                        IconButton(tooltip: 'Reintentar', icon: const Icon(Icons.refresh),
                            onPressed: () => cola.reintentar(fila['id'] as String)),
                      if (estado == 'error' &&
                          (fila['error'] as String? ?? '').contains('categoria indicada'))
                        IconButton(tooltip: 'Cambiar categoría', icon: const Icon(Icons.category),
                            onPressed: () => _cambiarCategoria(fila['id'] as String)),
                      if (estado == 'enviado')
                        IconButton(tooltip: 'Ver reporte', icon: const Icon(Icons.open_in_new),
                            onPressed: () => context.go('/reportes/${fila['id_remoto']}')),
                      IconButton(tooltip: 'Eliminar registro local', icon: const Icon(Icons.delete_outline),
                          onPressed: () => _eliminar(fila)),
                    ]),
                  ));
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
