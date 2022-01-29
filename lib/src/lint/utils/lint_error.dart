import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;

class LintError {
  const LintError({
    required this.message,
    required this.code,
    this.ctxNode,
    required this.errNode,
  });

  static final String _exhaustiveKeysCode = 'exhaustive_keys';
  static final String _nestedHooks = 'nested_hooks';

  factory LintError.missingKey(
      String key, String? kind, AstNode? ctxNode, AstNode errNode) {
    return LintError(
      message: "Missing key '$key' " +
          (kind != null ? '($kind) ' : '') +
          'found. Add the key, or ignore this line. ',
      code: _exhaustiveKeysCode,
      ctxNode: ctxNode,
      errNode: errNode,
    );
  }

  factory LintError.unnecessaryKey(
      String key, String? kind, AstNode? ctxNode, AstNode errNode) {
    return LintError(
      message: "Unnecessary key '$key' " +
          (kind != null ? '($kind) ' : '') +
          'found. Remove the key, or ignore this line.',
      code: _exhaustiveKeysCode,
      ctxNode: ctxNode,
      errNode: errNode,
    );
  }

  factory LintError.functionKey(
    String functionName,
    AstNode? ctxNode,
    AstNode errNode,
  ) {
    return LintError(
      message:
          "'$functionName' changes on every re-build. Move its definition inside the hook, or wrap with useCallback.",
      code: _exhaustiveKeysCode,
      ctxNode: ctxNode,
      errNode: errNode,
    );
  }

  factory LintError.nestedHooks(String hookName, AstNode node) {
    return LintError(
      message:
          'Avoid nested use of $hookName. Hooks must be used in top-level scope of the build function.',
      code: _nestedHooks,
      errNode: node,
    );
  }

  final String message;
  final String code;
  final AstNode? ctxNode;
  final AstNode errNode;

  plugin.AnalysisError toAnalysisError(String file, CompilationUnit unit) {
    final location = _toLocation(errNode, file, unit);

    return plugin.AnalysisError(
      plugin.AnalysisErrorSeverity.INFO,
      plugin.AnalysisErrorType.LINT,
      location,
      message,
      code,
    );
  }

  plugin.Location _toLocation(AstNode node, String file, CompilationUnit unit) {
    final lineInfo = unit.lineInfo!;
    final begin = node.beginToken.charOffset;
    final end = node.endToken.charEnd;
    final loc = lineInfo.getLocation(begin);
    final locEnd = lineInfo.getLocation(end);

    return plugin.Location(
      file,
      errNode.beginToken.charOffset,
      errNode.length,
      loc.lineNumber,
      loc.columnNumber,
      endLine: locEnd.lineNumber,
      endColumn: locEnd.columnNumber,
    );
  }

  String toReadableString(String file, CompilationUnit unit) {
    final errLoc = _toLocation(errNode, file, unit);

    return '''${errLoc.file} (Line: ${errLoc.startLine}, Col: ${errLoc.startColumn}): $message ($code)

      ${ctxNode?.toSource() ?? errNode.toSource()}
    ''';
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
            // the value has no meanings, so use just 0 or -1
            //   @see https://groups.google.com/a/dartlang.org/g/analyzer-discuss/c/lfRzX0yw3ZU
            //   @see https://github.com/dart-code-checker/dart-code-metrics/blob/0813a54f2969dbaf5e00c6ae2c4ab1132a64580a/lib/src/analyzer_plugin/analyzer_plugin_utils.dart#L47
            analysisResult.exists ? 0 : -1,
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
