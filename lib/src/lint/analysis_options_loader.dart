// based on https://github.com/dart-lang/sdk/blob/1699debb3148703273ddb668222ab52674d0e596/pkg/analyzer/lib/src/analysis_options/analysis_options_parser.dart
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/source/file_source.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/utilities/extensions/file_system.dart';
import 'package:analyzer/src/workspace/workspace.dart';
import 'package:analyzer/workspace/workspace.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/cache.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/config.dart';
import 'package:yaml/yaml.dart';

final class AnalysisOptionsLoader {
  final _optionsCache = Cache<String, Options>(100);

  Options load(WorkspacePackage? package, File file) {
    if (package is! WorkspacePackageImpl) {
      return const Options();
    }

    final folder = file.parent;

    final optionsFile = folder.findAnalysisOptionsYamlFile();
    if (optionsFile == null) {
      return const Options();
    }

    final key = optionsFile.path;

    return _optionsCache.doCache(
      key,
      () => _parseFile(
        sourceFactory: package.workspace.partialSourceFactory,
        file: optionsFile,
        options: const Options(),
        includeChain: {optionsFile},
      ),
    );
  }

  Options _parseFile({
    required SourceFactory sourceFactory,
    required File file,
    required Options options,
    required Set<File> includeChain,
  }) {
    final yaml = _readYaml(file);
    if (yaml == null) {
      return options;
    }

    var result = options;

    for (final include in _includes(yaml)) {
      final source = sourceFactory.resolveUri(FileSource(file), include);

      if (source is! FileSource) {
        continue;
      }

      final includedFile = source.file;

      if (!includeChain.add(includedFile)) {
        continue;
      }

      result = _parseFile(
        sourceFactory: sourceFactory,
        file: includedFile,
        options: result,
        includeChain: includeChain,
      );
    }

    final pluginConfig = Options.fromYaml(yaml);

    return result.applyYaml(pluginConfig);
  }

  YamlMap? _readYaml(File file) {
    try {
      final yaml = loadYamlNode(file.readAsStringSync());
      return yaml is YamlMap ? yaml : null;
    } on FileSystemException {
      return null;
    } on YamlException {
      return null;
    }
  }

  Iterable<String> _includes(YamlMap yaml) sync* {
    switch (yaml['include']) {
      case String uri:
        yield uri;
      case YamlList includes:
        yield* includes.whereType<String>();
    }
  }
}
