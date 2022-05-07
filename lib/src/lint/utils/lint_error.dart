import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;

class LintError {
  const LintError({
    required this.message,
    required this.code,
    this.key,
    this.ctxNode,
    required this.errNode,
    this.fixes = const [],
  });

  final String message;
  final String code;
  final String? key;
  final AstNode? ctxNode;
  final AstNode errNode;
  final List<LintFix> fixes;

  plugin.AnalysisErrorFixes toAnalysisErrorFixes(
    String file,
    ResolvedUnitResult result,
  ) {
    final location = _toLocation(errNode, file, result.unit);

    return plugin.AnalysisErrorFixes(
      plugin.AnalysisError(
        plugin.AnalysisErrorSeverity.INFO,
        plugin.AnalysisErrorType.LINT,
        location,
        message,
        code,
        hasFix: fixes.isNotEmpty,
      ),
      fixes: fixes.map((f) => f.toAnalysisFix(file, result)).toList(),
    );
  }

  plugin.Location _toLocation(AstNode node, String file, CompilationUnit unit) {
    final lineInfo = unit.lineInfo;
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

  @override
  String toString() {
    return [
      'message: $message',
      'code: $code',
      if (key != null) 'key: $key',
      if (ctxNode != null) 'ctxNode: ${ctxNode!.toSource()}',
      'errNode: ${errNode.toSource()}',
      if (fixes.isNotEmpty)
        'fixes: ${fixes.map((e) => '"${e.value}"').join(', ')}'
    ].join(', ');
  }
}

class LintFix {
  const LintFix({
    required this.message,
    required this.start,
    required this.length,
    required this.value,
  });

  LintFix.replaceNode({
    required this.message,
    required AstNode node,
    required this.value,
  })  : start = node.beginToken.charOffset,
        length = node.length;

  LintFix.insert({
    required this.message,
    required this.start,
    required this.value,
  }) : length = 0;

  LintFix.removeNode({
    required this.message,
    required AstNode node,
  })  : start = node.beginToken.charOffset,
        length = node.length,
        value = '';

  factory LintFix.appendListElement({
    required String message,
    required ListLiteral literal,
    required String element,
  }) {
    final commaOffset = _findLastComma(literal.endToken, literal.beginToken);

    if (commaOffset == null) {
      return LintFix.insert(
        message: message,
        start: literal.endToken.charOffset,
        value: (literal.elements.isNotEmpty ? ', ' : '') + element,
      );
    }

    return LintFix.insert(
      message: message,
      start: commaOffset + 1,
      value: ' $element,',
    );
  }

  factory LintFix.removeListElement({
    required String message,
    required ListLiteral literal,
    required AstNode element,
  }) {
    final commaOffset = _findNextComma(element.endToken, literal.endToken);

    if (commaOffset != null) {
      return LintFix(
        message: message,
        start: element.beginToken.charOffset,
        length: commaOffset - element.beginToken.charOffset + 1,
        value: '',
      );
    }

    return LintFix.removeNode(
      message: message,
      node: element,
    );
  }

  factory LintFix.appendFunctionParam({
    required String message,
    required MethodInvocation literal,
    required String param,
  }) {
    if (literal.argumentList.arguments.isEmpty) {
      return LintFix.insert(
        message: message,
        start: literal.endToken.charOffset,
        value: param,
      );
    }

    final firstParam = literal.argumentList.arguments[0];
    final commaOffset = _findLastComma(literal.endToken, firstParam.endToken);

    if (commaOffset == null) {
      return LintFix.insert(
        message: message,
        start: literal.endToken.charOffset,
        value: ', $param',
      );
    }

    return LintFix.insert(
      message: message,
      start: commaOffset + 1,
      value: ' $param,',
    );
  }

  final String message;
  final int start;
  final int length;
  final String value;

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
                start,
                length,
                value,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

int? _findNearestComma(
    Token beginToken, Token endToken, Token? Function(Token?) next) {
  Token? token = beginToken;

  while ((token = next(token)) != endToken) {
    switch (token?.type) {
      case TokenType.COMMA:
        return token!.charOffset;

      case TokenType.MULTI_LINE_COMMENT:
      case TokenType.SINGLE_LINE_COMMENT:
        continue;

      default:
        return null;
    }
  }

  return null;
}

int? _findNextComma(Token beginToken, Token endToken) {
  return _findNearestComma(beginToken, endToken, (token) => token?.next);
}

int? _findLastComma(Token beginToken, Token endToken) {
  return _findNearestComma(beginToken, endToken, (token) => token?.previous);
}
