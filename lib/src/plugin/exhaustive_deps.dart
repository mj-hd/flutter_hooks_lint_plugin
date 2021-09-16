import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

void findExhaustiveDeps(
  CompilationUnit unit, {
  required Function(List<Identifier>, AstNode) onMissingDepsReport,
  required Function(List<Identifier>, AstNode) onUnnecessaryDepsReport,
}) {
  final context = _Context();

  unit.visitChildren(
    _TopLevelDeclarationVisitor(
      context: context,
    ),
  );

  unit.visitChildren(
    _HookWidgetVisitor(
      context: context,
      onMissingDepsReport: onMissingDepsReport,
      onUnnecessaryDepsReport: onUnnecessaryDepsReport,
    ),
  );
}

extension on Identifier {
  bool equalsByStaticElement(Identifier other) {
    if (staticElement == null) return false;

    return staticElement?.id == other.staticElement?.id;
  }
}

class _Context {
  final List<Identifier> _constants = [];

  String? _currentLibraryIdentifier;

  void ignore(Identifier node) {
    _constants.add(node);
  }

  bool shouldIgnore(Identifier node) {
    return _constants.any(node.equalsByStaticElement);
  }

  void setCurrentLibrary(LibraryElement? lib) {
    if (lib == null) return;

    _currentLibraryIdentifier = lib.identifier;
  }

  bool shouldIgnoreLibrary(LibraryElement? lib) {
    if (_currentLibraryIdentifier == null) return false;

    return _currentLibraryIdentifier != lib?.identifier;
  }
}

class _TopLevelDeclarationVisitor<R> extends GeneralizingAstVisitor<R> {
  _TopLevelDeclarationVisitor({
    required this.context,
  });

  final _Context context;

  @override
  R? visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      if (variable.isConst || variable.isFinal) {
        context.ignore(variable.name);
      }
    }
  }
}

class _HookWidgetVisitor<R> extends GeneralizingAstVisitor<R> {
  _HookWidgetVisitor({
    required this.context,
    required this.onMissingDepsReport,
    required this.onUnnecessaryDepsReport,
  });

  final _Context context;
  final Function(List<Identifier>, AstNode) onMissingDepsReport;
  final Function(List<Identifier>, AstNode) onUnnecessaryDepsReport;

  @override
  R? visitClassDeclaration(ClassDeclaration node) {
    switch (node.extendsClause?.superclass.name.name) {
      case 'HookWidget':
      case 'HookConsumerWidget':
        context.setCurrentLibrary(node.name.staticElement?.library);

        final buildVisitor = _BuildVisitor(
          context: context,
          onMissingDepsReport: onMissingDepsReport,
          onUnnecessaryDepsReport: onUnnecessaryDepsReport,
        );

        node.visitChildren(buildVisitor);
    }

    return super.visitClassDeclaration(node);
  }
}

class _BuildVisitor<R> extends GeneralizingAstVisitor<R> {
  _BuildVisitor({
    required this.context,
    required this.onMissingDepsReport,
    required this.onUnnecessaryDepsReport,
  });

  final _Context context;
  final Function(List<Identifier>, AstNode) onMissingDepsReport;
  final Function(List<Identifier>, AstNode) onUnnecessaryDepsReport;

  @override
  R? visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.name != 'build') return super.visitMethodDeclaration(node);

    final constDeclarationVisitor = _ConstDeclarationVisitor(context: context);

    node.visitChildren(constDeclarationVisitor);

    final useStateVisitor = _UseStateVisitor(context: context);

    node.visitChildren(useStateVisitor);

    final useEffectVisitor = _UseEffectVisitor(
      context: context,
      onMissingDepsReport: onMissingDepsReport,
      onUnnecessaryDepsReport: onUnnecessaryDepsReport,
    );

    node.visitChildren(useEffectVisitor);

    return super.visitMethodDeclaration(node);
  }
}

class _UseStateVisitor<R> extends GeneralizingAstVisitor<R> {
  _UseStateVisitor({
    required this.context,
  });

  final _Context context;

  @override
  R? visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;

    if (initializer is MethodInvocation &&
        initializer.methodName.name == 'useState') {
      context.ignore(node.name);
    }

    if (initializer is MethodInvocation &&
        initializer.methodName.name == 'useRef') {
      context.ignore(node.name);
    }

    return super.visitVariableDeclaration(node);
  }
}

class _ConstDeclarationVisitor<R> extends GeneralizingAstVisitor<R> {
  _ConstDeclarationVisitor({
    required this.context,
  });

  final _Context context;

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
    required this.onMissingDepsReport,
    required this.onUnnecessaryDepsReport,
  });

  final _Context context;
  final Function(List<Identifier>, AstNode) onMissingDepsReport;
  final Function(List<Identifier>, AstNode) onUnnecessaryDepsReport;

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

        final missingDeps = <Identifier>[];
        final unnecessaryDeps = <Identifier>[];

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
          onMissingDepsReport(
            missingDeps,
            node,
          );
        }

        if (unnecessaryDeps.isNotEmpty) {
          onUnnecessaryDepsReport(
            unnecessaryDeps,
            node,
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

  final _Context context;

  final List<Identifier> _idents = [];

  @override
  R? visitIdentifier(Identifier node) {
    if (node.staticElement == null) return super.visitIdentifier(node);

    if (context.shouldIgnoreLibrary(node.staticElement!.library)) {
      return super.visitIdentifier(node);
    }

    if (context.shouldIgnore(node)) {
      return super.visitIdentifier(node);
    }

    _idents.add(node);
  }

  List<Identifier> get idents => _idents;
}
