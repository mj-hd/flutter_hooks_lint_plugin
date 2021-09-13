import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/utils.dart';

class ExhaustiveDepsVisitor<R> extends GeneralizingAstVisitor<R> {
  ExhaustiveDepsVisitor({
    required this.onReport,
  });

  final Function(LintError) onReport;

  @override
  R? visitMethodInvocation(MethodInvocation node) {
    // TODO(mj-hd): useMemo
    // TODO(mj-hd): useCallback
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

        // TODO(mj-hd): exclude references that will not be changed
        final body = arguments[0];
        body.visitChildren(visitor);

        expectedDeps.addAll(visitor.idents);

        final missingDeps = [];

        // TODO(mj-hd): find unnecessary deps
        for (final dep in expectedDeps) {
          if (!actualDeps.contains(dep)) {
            missingDeps.add(dep);
          }
        }

        if (missingDeps.isNotEmpty) {
          onReport(
            LintError(
              message: "missing deps '${missingDeps.join(',')}'",
              code: 'missing_deps',
              node: node,
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
    // NOTE: node.staticType represents the runtime type statically resolved
    return super.visitIdentifier(node);
  }

  List<String> get idents => _idents;
}
