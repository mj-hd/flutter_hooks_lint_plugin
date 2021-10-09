import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;

class LintError {
  const LintError({
    required this.message,
    required this.code,
    required this.node,
  });

  factory LintError.missingKeys(List<Identifier> keys, AstNode node) {
    return LintError(
      message: "missing keys '${keys.join(',')}'",
      code: 'missing_keys',
      node: node,
    );
  }

  factory LintError.unnecessaryKeys(List<Identifier> keys, AstNode node) {
    return LintError(
      message: "unnecessary keys '${keys.join(',')}'",
      code: 'unnecessary_keys',
      node: node,
    );
  }

  factory LintError.nestedHooks(String hookName, AstNode node) {
    return LintError(
      message: "avoid nested use of '$hookName'",
      code: 'nested_hooks',
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
