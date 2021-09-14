import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/utils.dart';

class ExhaustiveDepsHookWidgetVisitor<R> extends GeneralizingAstVisitor<R> {
  ExhaustiveDepsHookWidgetVisitor({
    required this.context,
    required this.onReport,
  });

  final ExhaustiveDepsContext context;
  final Function(LintError) onReport;

  @override
  R? visitClassDeclaration(ClassDeclaration node) {
    if (node.extendsClause?.superclass.name.name == 'HookWidget') {
      final buildVisitor = _BuildVisitor(context: context, onReport: onReport);

      node.visitChildren(buildVisitor);
    }

    return super.visitClassDeclaration(node);
  }
}

class ExhaustiveDepsContext {
  final List<Identifier> _constants = [];

  void ignore(Identifier node) {
    _constants.add(node);
  }

  bool shouldIgnore(Identifier node) {
    return _constants.any(node.equalsByStaticElement);
  }
}

extension on Identifier {
  bool equalsByStaticElement(Identifier other) {
    if (staticElement == null) return false;

    return staticElement?.id == other.staticElement?.id;
  }
}

class _BuildVisitor<R> extends GeneralizingAstVisitor<R> {
  _BuildVisitor({
    required this.context,
    required this.onReport,
  });

  final ExhaustiveDepsContext context;
  final Function(LintError) onReport;

  @override
  R? visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.name != 'build') return super.visitMethodDeclaration(node);

    final constDeclarationVisitor = _ConstDeclarationVisitor(context: context);

    node.visitChildren(constDeclarationVisitor);

    final useStateVisitor = _UseStateVisitor(context: context);

    node.visitChildren(useStateVisitor);

    final useEffectVisitor = _UseEffectVisitor(
      context: context,
      onReport: onReport,
    );

    node.visitChildren(useEffectVisitor);

    return super.visitMethodDeclaration(node);
  }
}

class _UseStateVisitor<R> extends GeneralizingAstVisitor<R> {
  _UseStateVisitor({
    required this.context,
  });

  final ExhaustiveDepsContext context;

  @override
  R? visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;

    if (initializer is MethodInvocation &&
        initializer.methodName.name == 'useState') {
      context.ignore(node.name);
    }

    return super.visitVariableDeclaration(node);
  }
}

class _ConstDeclarationVisitor<R> extends GeneralizingAstVisitor<R> {
  _ConstDeclarationVisitor({
    required this.context,
  });

  final ExhaustiveDepsContext context;

  @override
  R? visitVariableDeclaration(VariableDeclaration node) {
    if (node.isConst) {
      context.ignore(node.name);
    }

    return super.visitVariableDeclaration(node);
  }
}

class _UseEffectVisitor<R> extends GeneralizingAstVisitor<R> {
  _UseEffectVisitor({
    required this.context,
    required this.onReport,
  });

  final ExhaustiveDepsContext context;
  final Function(LintError) onReport;

  @override
  R? visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'useEffect') {
      final actualDeps = <Identifier>[];
      final expectedDeps = <Identifier>[];

      final arguments = node.argumentList.arguments;

      if (arguments.isNotEmpty) {
        // useEffect(() {})
        if (arguments.length == 1) {}

        // useEffect(() {}, deps)
        if (arguments.length == 2) {
          final deps = arguments[1];

          // useEffect(() {}, [deps])
          if (deps is ListLiteral) {
            final visitor = _DepsIdentifierVisitor(
              context: context,
            );

            deps.visitChildren(visitor);

            actualDeps.addAll(visitor.idents);
          }
        }

        final visitor = _DepsIdentifierVisitor(
          context: context,
        );

        final body = arguments[0];
        body.visitChildren(visitor);

        expectedDeps.addAll(visitor.idents);

        final missingDeps = [];
        final unnecessaryDeps = [];

        for (final dep in expectedDeps) {
          if (!actualDeps.any(dep.equalsByStaticElement)) {
            missingDeps.add(dep);
          }
        }

        for (final dep in actualDeps) {
          if (!expectedDeps.any(dep.equalsByStaticElement)) {
            unnecessaryDeps.add(dep);
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

        if (unnecessaryDeps.isNotEmpty) {
          onReport(
            LintError(
              message: "unnecessary deps '${unnecessaryDeps.join(',')}'",
              code: 'unnecessary_deps',
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
  _DepsIdentifierVisitor({
    required this.context,
  });

  final ExhaustiveDepsContext context;

  final List<Identifier> _idents = [];

  @override
  R? visitIdentifier(Identifier node) {
    if (node.staticElement == null) return super.visitIdentifier(node);

    if (!context.shouldIgnore(node)) {
      _idents.add(node);
    }

    return super.visitIdentifier(node);
  }

  List<Identifier> get idents => _idents;
}
