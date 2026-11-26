/// Marcador del mapa (RF-032): llega con descripcion y fotografias para
/// el popup al seleccionarlo (RF-034). Nunca trae datos del reportante.
class MarcadorMapa {
  final int idReporte;
  final double latitud;
  final double longitud;
  final String estado;
  final DateTime fechaHora;
  final String descripcion;
  final String categoria;
  final String? barrio;
  final List<FotoMapa> fotografias;

  const MarcadorMapa({
    required this.idReporte,
    required this.latitud,
    required this.longitud,
    required this.estado,
    required this.fechaHora,
    required this.descripcion,
    required this.categoria,
    this.barrio,
    this.fotografias = const [],
  });

  factory MarcadorMapa.fromJson(Map<String, dynamic> j) => MarcadorMapa(
        idReporte: j['id_reporte'] as int,
        latitud: (j['latitud'] as num).toDouble(),
        longitud: (j['longitud'] as num).toDouble(),
        estado: j['estado'] as String,
        fechaHora: DateTime.parse(j['fecha_hora'] as String),
        descripcion: j['descripcion'] as String,
        categoria: j['categoria'] as String,
        barrio: j['barrio'] as String?,
        fotografias: (j['fotografias'] as List? ?? const [])
            .map((f) => FotoMapa.fromJson(Map<String, dynamic>.from(f)))
            .toList(),
      );
}

/// Referencia a una fotografia del reporte; los bytes se piden al servidor
/// con el token de la sesion (RF-007/RF-034).
class FotoMapa {
  final int idFoto;
  final String url;

  const FotoMapa({required this.idFoto, required this.url});

  factory FotoMapa.fromJson(Map<String, dynamic> j) => FotoMapa(
        idFoto: j['id_foto'] as int,
        url: j['url'] as String,
      );
}

/// Zona resaltada en el mapa: uno de los tres barrios con mas reportes
/// activos (RF-035). `poligono` es GeoJSON (Polygon / MultiPolygon).
class SectorMapa {
  final int idBarrio;
  final String nombre;
  final Map<String, dynamic> poligono;
  final int totalActivos;

  const SectorMapa({
    required this.idBarrio,
    required this.nombre,
    required this.poligono,
    required this.totalActivos,
  });

  factory SectorMapa.fromJson(Map<String, dynamic> j) => SectorMapa(
        idBarrio: j['id_barrio'] as int,
        nombre: j['nombre'] as String,
        poligono: Map<String, dynamic>.from(j['poligono'] as Map),
        totalActivos: j['total_activos'] as int,
      );
}
