import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/config.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/utils/cache.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/hook_widget_visitor.dart';
import 'package:logging/logging.dart';

final log = Logger('exhaustive_keys');

typedef ExhaustiveKeysReportCallback = void Function(
  String keyName,
  String? kind,
  AstNode errNode,
);

void findExhaustiveKeys(
  CompilationUnit unit, {
  required ExhaustiveKeysOptions options,
  required ExhaustiveKeysReportCallback onMissingKeyReport,
  required ExhaustiveKeysReportCallback onUnnecessaryKeyReport,
  required ExhaustiveKeysReportCallback onFunctionKeyReport,
}) {
  log.finer('findExhaustiveKeys');

  void onBuildBlock(_Context context, node) {
    final localFunctionVisitor = _LocalFunctionVisitor(context: context);

    node.visitChildren(localFunctionVisitor);

    final localVariableVisitor = _LocalVariableVisitor(
      context: context,
      constantHooks: options.constantHooks,
    );

    node.visitChildren(localVariableVisitor);

    final hooksVisitor = _HooksVisitor(
      context: context,
      onMissingKeyReport: onMissingKeyReport,
      onUnnecessaryKeyReport: onUnnecessaryKeyReport,
      onFunctionKeyReport: onFunctionKeyReport,
    );

    node.visitChildren(hooksVisitor);
  }

  unit.visitChildren(
    HookWidgetVisitor(
      contextBuilder: () => _Context(),
      onClassDeclaration: (_Context context, node) {
        context.addClassFields(node);
      },
      onBuildBlock: (_Context context, node, _) => onBuildBlock(context, node),
    ),
  );

  unit.visitChildren(
    CustomHookFunctionVisitor(
      contextBuilder: () => _Context(),
      onBuildBlock: (_Context context, node, params) {
        if (params != null) {
          context.addFunctionParams(params);
        }

        onBuildBlock(context, node);
      },
    ),
  );
}

enum KeyKind {
  unknown,
  classField,
  functionParam,
  localVariable,
  localFunction,
  stateVariable,
  stateValue,
}

extension KeyKindExt on KeyKind {
  String? toReadableString() {
    switch (this) {
      case KeyKind.unknown:
        return null;
      case KeyKind.classField:
        return 'class field';
      case KeyKind.functionParam:
        return 'function parameter';
      case KeyKind.localVariable:
        return 'local variable';
      case KeyKind.localFunction:
        return 'local function';
      case KeyKind.stateVariable:
        return 'state variable';
      case KeyKind.stateValue:
        return 'state value';
    }
  }
}

/// Key represents complex identifier like 'hoge.foo.bar'
class Key {
  Key(List<SimpleIdentifier> idents, KeyKind kind)
      : _idents = idents,
        _kind = kind,
        assert(idents.isNotEmpty);

  factory Key.withContext(
    _Context context,
    List<SimpleIdentifier> idents,
  ) =>
      Key(idents, context.inferKind(idents));

  final List<SimpleIdentifier> _idents;
  List<SimpleIdentifier> get idents => _idents;

  final KeyKind _kind;
  KeyKind get kind => _kind;

  Element? get rootElement => _idents.first.staticElement;

  /// returns whether the variable is a build-related variable (class fields, local variables, ...)
  bool get isBuildVariable =>
      kind != KeyKind.stateVariable && kind != KeyKind.unknown;

  Iterable<Element> get _staticElements =>
      _idents.map((i) => i.staticElement).whereType<Element>();

  bool _hasElement(Element other) {
    return _staticElements.any(
      (l) => l.id == other.id,
    );
  }

  final _acceptCache = Cache<int, bool>(1000);

  /// check whether the other Key is subset of this Key
  bool accepts(Key other) =>
      _acceptCache.doCache(hashCode ^ other.hashCode, () {
        if (rootElement == null) return false;

        if (rootElement?.id != other.rootElement?.id) {
          return false;
        }

        if (idents.length < other.idents.length) {
          return false;
        }

        // FIXME: In some cases, the same two identifiers return null or element by context.
        //   To handle this, here compares identifier's name only.
        for (var i = 1; i < other.idents.length; i++) {
          final l = idents[i];
          final r = other.idents[i];

          if (l.name != r.name) return false;
        }

        return true;
      });

  /// shorten the Key
  Key toBaseKey() {
    // if the Key is a state value, keep first 2 identifiers (e.g. state.value.foo => state.value)
    if (kind == KeyKind.stateValue) {
      return Key(
        idents.sublist(0, 2),
        kind,
      );
    }

    return Key(
      [idents.first],
      kind,
    );
  }

  @override
  String toString() {
    return idents.map((i) => i.name).join('.');
  }

  @override
  bool operator ==(Object other) =>
      other is Key &&
      kind == other.kind &&
      idents.length == other.idents.length &&
      _staticElements.every(other._hasElement);

  @override
  int get hashCode => _staticElements.fold(0, (prev, e) => prev ^ e.hashCode);
}

class _Context {
  final List<FieldElement> _classFields = [];
  final List<PropertyAccessorElement> _classGetterFields = [];
  final List<VariableElement> _localVariables = [];
  final List<Element> _localFunctions = [];
  final List<VariableElement> _stateVariables = [];
  final List<ParameterElement> _params = [];

  bool get isEmpty =>
      _classFields.isEmpty &&
      _classGetterFields.isEmpty &&
      _localVariables.isEmpty &&
      _localFunctions.isEmpty &&
      _stateVariables.isEmpty &&
      _params.isEmpty;

  bool get isNotEmpty => !isEmpty;

  void addLocalVariable(VariableElement variable) {
    log.finer('_Context: addLocalVariable($variable)');

    _localVariables.add(variable);
  }

  void addFunctionDeclaration(Element func) {
    log.finer('_Context: addLocalFunction($func)');

    _localFunctions.add(func);
  }

  void addStateVariable(VariableElement variable) {
    log.finer('_Context: addStateVariable($variable)');

    _stateVariables.add(variable);
  }

  void addClassFields(ClassDeclaration klass) {
    log.finer('_Context: addClassFields($klass)');

    if (klass.declaredElement == null) {
      log.finer('_Context: class element is not resolved');
      return;
    }

    final fields = klass.declaredElement!.fields.where(
      (elem) => !elem.isConst,
    );

    _classFields.addAll(fields);
    _classGetterFields.addAll(
      fields.map((e) => e.getter).whereType<PropertyAccessorElement>().toList(),
    );
  }

  void addFunctionParams(FormalParameterList params) {
    log.finer('_Context: addFunctionParams($params)');

    _params.addAll(
      params.parameters
          .map(
            (param) => param.declaredElement,
          )
          .whereType<ParameterElement>(),
    );
  }

  final _kindCache = Cache<int, KeyKind>(1000);

  KeyKind inferKind(List<SimpleIdentifier> idents) {
    final staticElements =
        idents.map((i) => i.staticElement).whereType<Element>();

    final hashCode =
        staticElements.fold<int>(0, (prev, e) => prev ^ e.hashCode);

    return _kindCache.doCache(hashCode, () {
      log.finer('_Context: inferKind($idents)');

      if (staticElements.isEmpty) return KeyKind.unknown;

      if (_elementContains(_stateVariables, staticElements.first)) {
        // consider reference like 'state.value' as a build variable ('state' is not)
        if (staticElements.length >= 2) {
          log.finest('_Context: inferKind($idents) => state value');
          return KeyKind.stateValue;
        } else {
          log.finest('_Context: inferKind($idents) => state variable');
          return KeyKind.stateVariable;
        }
      }

      for (final element in staticElements) {
        if (_elementContains(_localVariables, element)) {
          log.finest('_Context: inferKind($idents) => local variable');
          return KeyKind.localVariable;
        }

        if (_elementContains(_localFunctions, element)) {
          log.finest('_Context: inferKind($idents) => local function');
          return KeyKind.localFunction;
        }

        if (_elementContains(_params, element)) {
          log.finest('_Context: inferKind($idents) => function param');
          return KeyKind.functionParam;
        }

        if (_elementContains(_classFields, element)) {
          log.finest('_Context: inferKind($idents) => class field');
          return KeyKind.classField;
        }

        if (_elementContains(_classGetterFields, element)) {
          log.finest('_Context: inferKind($idents) => class getter field');
          return KeyKind.classField;
        }
      }

      log.finest('_Context: inferKind($idents) => unknown');
      return KeyKind.unknown;
    });
  }

  bool _elementContains(List<Element> list, Element target) {
    return list.any((e) => e.id == target.id);
  }
}

class _LocalVariableVisitor extends SimpleAstVisitor<void> {
  _LocalVariableVisitor({
    required this.context,
    required this.constantHooks,
  });

  final _Context context;
  final List<String> constantHooks;

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    log.finer('_VariableDeclarationVisitor: visit($node)');

    final decl = node
        .findChild<VariableDeclarationList>()
        ?.findChild<VariableDeclaration>();

    if (decl == null) {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable declaration not found');
      return;
    }
    if (decl.isConst) {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable is const');
      return;
    }

    final elem = decl.name.staticElement;

    if (elem is! LocalVariableElement) {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable is not LocalVariableElement');
      return;
    }

    // ignore values generated by useState
    final initializer = decl.initializer;

    if (initializer is MethodInvocation &&
        initializer.methodName.name == 'useState') {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable is useState');

      context.addStateVariable(elem);
      return;
    }

    // ignore values generated by constantHooks (default: useRef, useIsMounted, ...etc)
    if (initializer is MethodInvocation &&
        constantHooks.contains(initializer.methodName.name)) {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable is ${initializer.methodName.name}');
      return;
    }

    context.addLocalVariable(elem);
  }
}

class _LocalFunctionVisitor extends SimpleAstVisitor<void> {
  _LocalFunctionVisitor({
    required this.context,
  });

  final _Context context;

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    log.finer('_LocalFunctionVisitor: visit($node)');

    final element = node.functionDeclaration.declaredElement;

    if (element != null) {
      context.addFunctionDeclaration(element);
    }
  }
}

class _HooksVisitor extends RecursiveAstVisitor<void> {
  _HooksVisitor({
    required this.context,
    required this.onMissingKeyReport,
    required this.onUnnecessaryKeyReport,
    required this.onFunctionKeyReport,
  });

  final _Context context;

  final ExhaustiveKeysReportCallback onMissingKeyReport;
  final ExhaustiveKeysReportCallback onUnnecessaryKeyReport;
  final ExhaustiveKeysReportCallback onFunctionKeyReport;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    log.finer('_HooksVisitor: visitMethodInvocation($node)');

    switch (node.methodName.name) {
      case 'useEffect':
      case 'useMemoized':
      case 'useCallback':
        log.finest('_HooksVisitor: hooks found');

        final actualKeys = <Key>[];
        final expectedKeys = <Key>[];

        final arguments = node.argumentList.arguments;

        // find identifiers in the hook's keys
        if (arguments.isNotEmpty) {
          // useMemoized(() => ...);
          if (arguments.length == 1) {
            log.finest('_HooksVisitor: hooks without keys');

            // useEffect(() { ... });
            if (node.methodName.name == 'useEffect') {
              log.finest('_HooksVisitor: useEffect without keys');
              return;
            }
          }

          // useEffect(() { ... }, ...);
          if (arguments.length == 2) {
            log.finest('_HooksVisitor: hooks with keys');

            final keys = arguments[1];

            // useEffect(() { ... }, [...]);
            if (keys is ListLiteral) {
              log.finest('_HooksVisitor: hooks with list keys');

              final visitor = _KeysIdentifierVisitor(
                context: context,
              );

              keys.visitChildren(visitor);

              actualKeys.addAll(visitor.keys);

              log.finest('_HooksVisitor: actual keys $actualKeys');
            }
          }

          if (context.isNotEmpty) {
            // find identifiers in the hook body
            final visitor = _KeysIdentifierVisitor(
              context: context,
              onlyBuildVaribles: true,
            );

            final body = arguments[0];
            body.visitChildren(visitor);

            expectedKeys.addAll(visitor.keys);
          }

          log.finest('_HooksVisitor: expected keys $expectedKeys');

          final missingKeys = <Key>{};
          final unnecessaryKeys = <Key>{};

          for (final key in expectedKeys) {
            if (!actualKeys.any(key.accepts)) {
              missingKeys.add(key.toBaseKey());
            }
          }

          log.finest('_HooksVisitor: missing keys $missingKeys');

          // consider the Keys which is not accepted by every expectedKeys as 'unnecessary'
          for (final key in actualKeys) {
            if (!expectedKeys.any((expected) => expected.accepts(key))) {
              unnecessaryKeys.add(key);
            }
          }

          log.finest('_HooksVisitor: unnecessary keys $unnecessaryKeys');

          final errNode =
              arguments.length == 2 ? arguments[1] : node.methodName;

          for (final key in missingKeys) {
            onMissingKeyReport(
              key.toString(),
              key.kind.toReadableString(),
              errNode,
            );
          }

          for (final key in unnecessaryKeys) {
            onUnnecessaryKeyReport(
              key.toString(),
              key.kind.toReadableString(),
              errNode,
            );
          }

          for (final key in actualKeys) {
            if (key.kind == KeyKind.localFunction) {
              onFunctionKeyReport(
                key.toString(),
                key.kind.toReadableString(),
                errNode,
              );
            }
          }
        }
    }
  }
}

// find complex identifier like 'hoge.foo.bar' consisting of PropertyAccess, PrefixedIdentifier, SimpleIdentifier
class _KeysIdentifierVisitor extends RecursiveAstVisitor<void> {
  _KeysIdentifierVisitor({
    required this.context,
    this.onlyBuildVaribles = false,
  });

  final _Context context;
  final bool onlyBuildVaribles;

  final List<Key> _keys = [];

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    log.finer('_KeysIdentifierVisitor: visitPrefixedIdentifier($node)');

    final idents = [node.prefix, node.identifier];

    _visitKey(Key.withContext(context, idents));
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    log.finer('_KeysIdentifierVisitor: visitPropertyAccess($node)');

    final visitor = _PropertyAccessVisitor();

    node.visitChildren(visitor);

    final idents = visitor.idents;

    _visitKey(Key.withContext(context, idents));
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    log.finer('_KeysIdentifierVisitor: visitSimpleIdentifier($node)');

    _visitKey(Key.withContext(context, [node]));

    return super.visitSimpleIdentifier(node);
  }

  void _visitKey(Key? key) {
    log.finer('_KeysIdentifierVisitor: _visitKey($key)');

    if (key == null) {
      log.finest(
          '_KeysIdentifierVisitor: _visitKey($key) => keyent is not resolved');
      return;
    }

    if (onlyBuildVaribles) {
      if (!key.isBuildVariable) {
        log.finest(
            '_KeysIdentifierVisitor: _visitKey($key) => is build variable');
        return;
      }
    }

    if (!_keys.contains(key)) {
      log.finest('_KeysIdentifierVisitor: _visitKey($key) => add');
      _keys.add(key);
    } else {
      log.finest('_KeysIdentifierVisitor: _visitKey($key) => already added');
    }
  }

  List<Key> get keys => _keys;
}

class _PropertyAccessVisitor extends RecursiveAstVisitor<void> {
  _PropertyAccessVisitor();

  List<SimpleIdentifier> idents = [];

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    idents.insertAll(0, [node.prefix, node.identifier]);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    idents.add(node);

    return super.visitSimpleIdentifier(node);
  }
}
