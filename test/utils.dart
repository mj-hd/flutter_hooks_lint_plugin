import 'dart:io';

import 'package:analyzer/utilities/package_config_file_builder.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:logging/logging.dart';

void setUpLogging() {
  if (Platform.environment['LOG_LEVEL'] != null) {
    Logger.root.level = Level(
      '',
      int.tryParse(Platform.environment['LOG_LEVEL']!) ?? Level.INFO.value,
    );
  }

  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });
}

extension AnalysisRuleTestExt on AnalysisRuleTest {
  // basically, compile time errors are ignored, but several type definitions are needed to work properly
  static const _flutterHooksStub = '''
    class ValueNotifier<T> {
      T value;
    }

    ValueNotifier<T> useState<T>(T initialData) {}
  ''';

  void setupFlutterHooksStub() {
    const flutterHooksPath = '/packages/flutter_hooks';
    newFile('$flutterHooksPath/lib/flutter_hooks.dart', _flutterHooksStub);
    writeTestPackageConfig(
      PackageConfigFileBuilder()
        ..add(name: 'flutter_hooks', rootPath: convertPath(flutterHooksPath)),
    );
  }
}
