import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future<DatabaseFactory> initializePlatformDatabaseFactory() async {
  if (Platform.isWindows || Platform.isLinux) {
    ffi.sqfliteFfiInit();
    return ffi.databaseFactoryFfi;
  }
  return databaseFactory;
}

Future<String> platformDatabasePath() async =>
    p.join((await getApplicationSupportDirectory()).path, 'finpilot_ai.db');
