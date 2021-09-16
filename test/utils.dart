import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as path;

Future<CompilationUnit> compileCode(String source) async {
  final overlay = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);
  final filePath = path.join(Directory.current.absolute.path, 'main.dart');

  overlay.setOverlay(
    filePath,
    content: source,
    modificationStamp: _nowInUnix(),
  );

  final result = await resolveFile2(path: filePath, resourceProvider: overlay)
      as ResolvedUnitResult;

  if (!result.exists) {
    throw Error();
  }

  return result.unit;
}

int _nowInUnix() {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
