import 'package:analyzer/file_system/file_system.dart';
import 'package:yaml/yaml.dart';

/// Provides the options found in the nearest `analysis_options.yaml` file.
///
/// This implements the subset of the Analyzer 9 `AnalysisOptionsProvider`
/// behavior used by this plugin. In particular, included options files are not
/// resolved.
class AnalysisOptionsProvider {
  const AnalysisOptionsProvider();

  /// Returns the options found in [root] or one of its ancestor directories.
  ///
  /// Returns an empty map if no options file exists or the file cannot be
  /// parsed as a YAML map.
  YamlMap getOptions(Folder root) {
    final optionsFile = _getOptionsFile(root);
    if (optionsFile == null) {
      return YamlMap();
    }

    try {
      final content = optionsFile.readAsStringSync();
      final options = loadYamlNode(content);
      return options is YamlMap ? options : YamlMap();
    } catch (_) {
      return YamlMap();
    }
  }

  File? _getOptionsFile(Folder root) {
    for (final folder in root.withAncestors) {
      final file = folder.getFile('analysis_options.yaml');
      if (file.exists) {
        return file;
      }
    }
    return null;
  }
}
