import 'package:geolocator/geolocator.dart';

/// Coordenada leida del GPS con su precision en metros.
class UbicacionGps {
  final double latitud;
  final double longitud;
  final double precision; // metros

  const UbicacionGps({
    required this.latitud,
    required this.longitud,
    required this.precision,
  });

  /// RF-003: se advierte cuando la precision supera los 50 metros.
  bool get esImprecisa => precision > 50;
}

class ExcepcionUbicacion implements Exception {
  final String mensaje;
  const ExcepcionUbicacion(this.mensaje);

  @override
  String toString() => mensaje;
}

/// RF-003 · Obtiene la posicion actual: servicio activo + permiso concedido.
Future<UbicacionGps> obtenerUbicacionGps() async {
  final servicioActivo = await Geolocator.isLocationServiceEnabled();
  if (!servicioActivo) {
    throw const ExcepcionUbicacion(
      'El GPS del telefono esta apagado. Activa la ubicacion desde los '
      'ajustes rapidos del telefono.',
    );
  }

  var permiso = await Geolocator.checkPermission();
  if (permiso == LocationPermission.denied) {
    permiso = await Geolocator.requestPermission();
  }
  if (permiso == LocationPermission.deniedForever) {
    throw const ExcepcionUbicacion(
      'La app no tiene permiso de ubicacion. Otorgalo en: Ajustes > '
      'Aplicaciones > Reporte de Baches > Permisos > Ubicacion.',
    );
  }
  if (permiso == LocationPermission.denied) {
    throw const ExcepcionUbicacion('Permiso de ubicacion denegado.');
  }

  final posicion = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );

  return UbicacionGps(
    latitud: posicion.latitude,
    longitud: posicion.longitude,
    precision: posicion.accuracy,
  );
}
