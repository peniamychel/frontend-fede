import '../core/api_client.dart';
import 'central_repository.dart';
import 'directorio_repository.dart';
import 'federacion_repository.dart';
import 'importacion_repository.dart';
import 'lote_repository.dart';
import 'observacion_repository.dart';
import 'productor_repository.dart';
import 'reunion_repository.dart';
import 'sindicato_repository.dart';

export '../core/api_client.dart' show ApiClient;
export '../core/api_config.dart';
export '../core/api_exception.dart';
export '../core/pagina.dart';
export '../models/auditoria.dart';
export '../models/cargo.dart';
export '../models/central.dart';
export '../models/federacion.dart';
export '../models/imagen.dart';
export '../models/importacion.dart';
export '../models/lote.dart';
export '../models/observacion.dart';
export '../models/productor.dart';
export '../models/reunion.dart';
export '../models/sindicato.dart';
export 'central_repository.dart';
export 'directorio_repository.dart';
export 'federacion_repository.dart';
export 'importacion_repository.dart';
export 'lote_repository.dart';
export 'observacion_repository.dart';
export 'productor_repository.dart';
export 'reunion_repository.dart';
export 'sindicato_repository.dart';

/// Punto único de acceso a la API del padrón.
///
/// Agrupa los seis repositorios sobre un mismo [ApiClient], para no tener que
/// construirlos por separado ni repartir el cliente HTTP por toda la app.
class Padron {
  Padron({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  late final FederacionRepository federaciones = FederacionRepository(api);
  late final CentralRepository centrales = CentralRepository(api);
  late final SindicatoRepository sindicatos = SindicatoRepository(api);
  late final ProductorRepository productores = ProductorRepository(api);
  late final LoteRepository lotes = LoteRepository(api);
  late final ObservacionRepository observaciones = ObservacionRepository(api);
  late final ImportacionRepository importaciones = ImportacionRepository(api);

  /// Directorios de los tres niveles. Va aparte de sindicatos, centrales y
  /// federaciones porque el mecanismo es el mismo en todos.
  late final DirectorioRepository directorios = DirectorioRepository(api);

  /// Reuniones y pase de lista.
  late final ReunionRepository reuniones = ReunionRepository(api);

  void cerrar() => api.cerrar();
}
