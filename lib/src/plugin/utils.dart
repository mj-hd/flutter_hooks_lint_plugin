import 'dart:collection';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;

class LintError {
  const LintError({
    required this.message,
    required this.code,
    required this.node,
  });

  static final String _exhaustiveKeysCode = 'exhaustive_keys';
  static final String _nestedHooks = 'nested_hooks';

  factory LintError.missingKey(String key, AstNode node) {
    return LintError(
      message: "missing key '$key'",
      code: _exhaustiveKeysCode,
      node: node,
    );
  }

  factory LintError.unnecessaryKey(String key, AstNode node) {
    return LintError(
      message: "unnecessary key '$key'",
      code: _exhaustiveKeysCode,
      node: node,
    );
  }

  factory LintError.functionKey(String functionName, AstNode node) {
    return LintError(
      message: "wrap '$functionName' with useCallback",
      code: _exhaustiveKeysCode,
      node: node,
    );
  }

  factory LintError.nestedHooks(String hookName, AstNode node) {
    return LintError(
      message: "avoid nested use of '$hookName'",
      code: _nestedHooks,
      node: node,
    );
  }

  final String message;
  final String code;
  final AstNode node;

  plugin.AnalysisError toAnalysisError(String file, CompilationUnit unit) {
    final location = _toLocation(file, unit);

    return plugin.AnalysisError(
      plugin.AnalysisErrorSeverity.INFO,
      plugin.AnalysisErrorType.LINT,
      location,
      message,
      code,
    );
  }

  plugin.Location _toLocation(String file, CompilationUnit unit) {
    final lineInfo = unit.lineInfo!;
    final begin = node.beginToken.charOffset;
    final end = node.endToken.charEnd;
    final loc = lineInfo.getLocation(begin);
    final locEnd = lineInfo.getLocation(end);

    return plugin.Location(
      file,
      node.beginToken.charOffset,
      node.length,
      loc.lineNumber,
      loc.columnNumber,
      endLine: locEnd.lineNumber,
      endColumn: locEnd.columnNumber,
    );
  }
}

class LintFix {
  const LintFix({
    required this.message,
    required this.node,
    required this.replacement,
  });

  final String message;
  final AstNode node;
  final String replacement;

  plugin.PrioritizedSourceChange toAnalysisFix(
    String file,
    ResolvedUnitResult analysisResult,
  ) {
    return plugin.PrioritizedSourceChange(
      1,
      plugin.SourceChange(
        message,
        edits: [
          plugin.SourceFileEdit(
            file,
            analysisResult.libraryElement.source.modificationStamp,
            edits: [
              plugin.SourceEdit(
                node.beginToken.charOffset,
                node.length,
                replacement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Supression {
  static final _ignoreRegExp = RegExp('//[ ]*ignore:(.*)', multiLine: true);

  static final _ignoreForFileRegExp =
      RegExp('//[ ]*ignore_for_file:(.*)', multiLine: true);

  Supression({
    required String content,
    required this.lineInfo,
  }) {
    for (final match in _ignoreForFileRegExp.allMatches(content)) {
      final ids = match.group(1);

      if (ids == null) continue;

      fileScope.addAll(ids.split(',').map((s) => s.trim()));
    }

    for (final match in _ignoreRegExp.allMatches(content)) {
      final ids = match.group(1);
      if (ids == null) continue;

      final loc = lineInfo.getLocation(match.start);

      lineScope
          .putIfAbsent(loc.lineNumber, () => <String>{})
          .addAll(ids.split(',').map((s) => s.trim()));
    }
  }

  final LineInfo lineInfo;
  final Set<String> fileScope = {};
  final Map<int, Set<String>> lineScope = {};

  bool isSupressedLintError(LintError err) {
    final loc = lineInfo.getLocation(err.node.beginToken.charOffset);
    return isSupressed(err.code, loc.lineNumber);
  }

  bool isSupressed(String code, int line) {
    if (fileScope.contains(code)) {
      return true;
    }

    if (lineScope[line]?.contains(code) == true) {
      return true;
    }

    if (lineScope[line - 1]?.contains(code) == true) {
      return true;
    }

    return false;
  }
}

class Cache<K, V> {
  Cache(this.limit);

  final int limit;

  final LinkedHashMap<K, V> _internal = LinkedHashMap<K, V>();

  void remove(K key) => _internal.remove;

  V? operator [](K key) {
    final val = _internal[key];

    if (val != null) {
      _internal.remove(key);
      _internal[key] = val;
    }

    return val;
  }

  void operator []=(K key, V val) {
    _internal[key] = val;

    if (_internal.length > limit) {
      _internal.remove(_internal.values.first);
    }
  }

  V doCache(K key, V Function() f) {
    if (_internal.containsKey(key)) {
      return this[key]!;
    }

    final val = f();
    this[key] = val;
    return val;
  }
}
