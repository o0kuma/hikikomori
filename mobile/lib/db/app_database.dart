/// Platform-specific local database entrypoint.
///
/// - IO (Android / iOS / Linux / …): Drift + SQLCipher (`app_database_native.dart`)
/// - Web (Chrome): in-memory stub (`app_database_web.dart`) — FFI cannot compile
export 'app_database_native.dart' if (dart.library.html) 'app_database_web.dart';
