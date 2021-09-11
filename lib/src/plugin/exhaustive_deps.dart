import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;

class ExhaustiveDepsVisitor<R> extends GeneralizingAstVisitor<R> {
  ExhaustiveDepsVisitor({
    required this.file,
    required this.unit,
    required this.onReport,
  });

  final String file;
  final CompilationUnit unit;
  final Function(String, String, plugin.Location) onReport;

  @override
  R? visitMethodInvocation(MethodInvocation node) {
    final lineInfo = unit.lineInfo!;
    final begin = node.beginToken.charOffset;
    final end = node.endToken.charEnd;
    final loc = lineInfo.getLocation(begin);
    final locEnd = lineInfo.getLocation(end);

    if (node.methodName.name == 'useEffect') {
      final actualDeps = [];
      final expectedDeps = [];

      final arguments = node.argumentList.arguments;

      if (arguments.isNotEmpty) {
        // useEffect(() {})
        if (arguments.length == 1) {}

        // useEffect(() {}, deps)
        if (arguments.length == 2) {
          final deps = arguments[1];

          // useEffect(() {}, [deps])
          if (deps is ListLiteral) {
            final visitor = _DepsIdentifierVisitor();

            deps.visitChildren(visitor);

            actualDeps.addAll(visitor.idents);
          }
        }

        final visitor = _DepsIdentifierVisitor();

        final body = arguments[0];
        body.visitChildren(visitor);

        expectedDeps.addAll(visitor.idents);

        final missingDeps = [];

        for (final dep in expectedDeps) {
          if (!actualDeps.contains(dep)) {
            missingDeps.add(dep);
          }
        }

        if (missingDeps.isNotEmpty) {
          onReport(
            "missing deps '${missingDeps.join(',')}'",
            'missing_deps',
            plugin.Location(
              file,
              node.beginToken.charOffset,
              node.endToken.end,
              loc.lineNumber,
              loc.columnNumber,
              endLine: locEnd.lineNumber,
              endColumn: locEnd.columnNumber,
            ),
          );
        }
      }
    }

    return super.visitMethodInvocation(node);
  }
}

class _DepsIdentifierVisitor<R> extends GeneralizingAstVisitor<R> {
  final List<String> _idents = [];

  @override
  R? visitIdentifier(Identifier node) {
    _idents.add(node.name);
    return super.visitIdentifier(node);
  }

  List<String> get idents => _idents;
}
