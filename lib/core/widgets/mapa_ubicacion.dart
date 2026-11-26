import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Vista de solo lectura de la ubicación registrada de un reporte.
class MapaUbicacion extends StatelessWidget {
  const MapaUbicacion({
    super.key,
    required this.latitud,
    required this.longitud,
  });

  final double latitud;
  final double longitud;

  @override
  Widget build(BuildContext context) {
    if (!latitud.isFinite || !longitud.isFinite ||
        latitud < -90 || latitud > 90 || longitud < -180 || longitud > 180) {
      return const Text('La ubicación registrada no es válida.');
    }
    final punto = LatLng(latitud, longitud);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ubicación', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: 'Abrir mapa de la ubicación del reporte',
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => _MapaCompleto(punto: punto),
            )),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: Stack(
                  children: [
                    IgnorePointer(child: _Mapa(punto: punto, interactivo: false)),
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: Chip(
                        avatar: Icon(Icons.open_in_full, size: 16),
                        label: Text('Toca para ampliar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('El mapa necesita conexión a internet.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MapaCompleto extends StatelessWidget {
  const _MapaCompleto({required this.punto});
  final LatLng punto;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ubicación del reporte')),
        body: Stack(
          children: [
            _Mapa(punto: punto, interactivo: true),
            const Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Desliza o acerca el mapa para explorar. '
                      'La marca indica la ubicación registrada y no se puede modificar aquí. '
                      'El mapa necesita conexión a internet.'),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Mapa extends StatelessWidget {
  const _Mapa({required this.punto, required this.interactivo});
  final LatLng punto;
  final bool interactivo;

  @override
  Widget build(BuildContext context) => FlutterMap(
        options: MapOptions(
          initialCenter: punto,
          initialZoom: 16,
          interactionOptions: InteractionOptions(
            flags: interactivo ? InteractiveFlag.all : InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'bo.optaiv.movil',
          ),
          MarkerLayer(markers: [
            Marker(
              point: punto,
              width: 44,
              height: 44,
              child: const Icon(Icons.location_pin, color: Colors.red, size: 44),
            ),
          ]),
          const RichAttributionWidget(attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ]),
        ],
      );
}
