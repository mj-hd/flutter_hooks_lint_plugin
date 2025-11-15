import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/cache.dart';
import 'package:logging/logging.dart';

final log = Logger('lint_error');

class LintError {
  const LintError({
    required this.code,
    this.key,
    this.ctxNode,
    required this.errNode,
    this.fixes = const [],
  });

  final LintCode code;
  final Key? key;
  final AstNode? ctxNode;
  final AstNode errNode;
  final List<LintFix> fixes;

  @override
  String toString() {
    return [
      'code: $code',
      if (key != null) 'key: $key',
      if (ctxNode != null) 'ctxNode: ${ctxNode!.toSource()}',
      'errNode: ${errNode.toSource()}',
      if (fixes.isNotEmpty)
        'fixes: ${fixes.map((e) => '"${e.value}"').join(', ')}',
    ].join(', ');
  }

  bool isSame(Diagnostic? diagnostic) {
    return errNode.offset == diagnostic?.offset;
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
  }) : start = node.beginToken.charOffset,
       length = node.length;

  LintFix.insert({
    required this.message,
    required this.start,
    required this.value,
  }) : length = 0;

  LintFix.removeNode({required this.message, required AstNode node})
    : start = node.beginToken.charOffset,
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

    return LintFix.removeNode(message: message, node: element);
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

  Future<void> addDartFileEdit(
    ChangeBuilder builder,
    String file,
    AstNode? ctxNode,
  ) {
    return builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(SourceRange(start, length), value);
      if (ctxNode != null) {
        builder.format(SourceRange(ctxNode.offset, ctxNode.length));
      }
    });
  }
}

int? _findNearestComma(
  Token beginToken,
  Token endToken,
  Token? Function(Token?) next,
) {
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

  factory Key.withElementBucket(
    ElementBucket bucket,
    List<SimpleIdentifier> idents,
  ) => Key(idents, bucket.inferKind(idents));

  final List<SimpleIdentifier> _idents;
  List<SimpleIdentifier> get idents => _idents;

  final KeyKind _kind;
  KeyKind get kind => _kind;

  Element? get rootElement => _idents.first.element;

  /// returns whether the variable is a build-related variable (class fields, local variables, ...)
  bool get isBuildVariable =>
      kind != KeyKind.stateVariable && kind != KeyKind.unknown;

  Iterable<Element> get _staticElements =>
      _idents.map((i) => i.element).whereType<Element>();

  bool _hasElement(Element other) {
    return _staticElements.any((l) => l.id == other.id);
  }

  final _acceptCache = Cache<int, bool>(1000);

  /// check whether the other Key is subset of this Key
  bool accepts(
    Key other,
  ) => _acceptCache.doCache(hashCode ^ other.hashCode, () {
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
      return Key(idents.sublist(0, 2), kind);
    }

    return Key([idents.first], kind);
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

class ElementBucket {
  final List<FieldElement> _classFields = [];
  final List<PropertyAccessorElement> _classGetterFields = [];
  final List<VariableElement> _localVariables = [];
  final List<Element> _localFunctions = [];
  final List<VariableElement> _stateVariables = [];
  final List<FormalParameterElement> _params = [];

  bool get isEmpty =>
      _classFields.isEmpty &&
      _classGetterFields.isEmpty &&
      _localVariables.isEmpty &&
      _localFunctions.isEmpty &&
      _stateVariables.isEmpty &&
      _params.isEmpty;

  bool get isNotEmpty => !isEmpty;

  void addLocalVariable(VariableElement variable) {
    log.finer('_ElementBucket: addLocalVariable($variable)');

    _localVariables.add(variable);
  }

  void addFunctionDeclaration(Element func) {
    log.finer('_ElementBucket: addLocalFunction($func)');

    _localFunctions.add(func);
  }

  void addStateVariable(VariableElement variable) {
    log.finer('_ElementBucket: addStateVariable($variable)');

    _stateVariables.add(variable);
  }

  void addClassFields(ClassDeclaration klass) {
    log.finer('_ElementBucket: addClassFields($klass)');

    if (klass.declaredFragment == null) {
      log.finer('_ElementBucket: class element is not resolved');
      return;
    }

    final fields = klass.declaredFragment!.fields
        .where((frag) => !frag.element.isConst)
        .map((frag) => frag.element);

    _classFields.addAll(fields);
    _classGetterFields.addAll(
      fields.map((e) => e.getter).whereType<PropertyAccessorElement>().toList(),
    );
  }

  void addFunctionParams(FormalParameterList params) {
    log.finer('_ElementBucket: addFunctionParams($params)');

    _params.addAll(
      params.parameters
          .map((param) => param.declaredFragment?.element)
          .whereType<FormalParameterElement>(),
    );
  }

  final _kindCache = Cache<int, KeyKind>(1000);

  KeyKind inferKind(List<SimpleIdentifier> idents) {
    final staticElements = idents.map((i) => i.element).whereType<Element>();

    final hashCode = staticElements.fold<int>(
      0,
      (prev, e) => prev ^ e.hashCode,
    );

    return _kindCache.doCache(hashCode, () {
      log.finer('_ElementBucket: inferKind($idents)');

      if (staticElements.isEmpty) return KeyKind.unknown;

      if (_elementContains(_stateVariables, staticElements.first)) {
        // consider reference like 'state.value' as a build variable ('state' is not)
        if (staticElements.length >= 2) {
          log.finest('_ElementBucket: inferKind($idents) => state value');
          return KeyKind.stateValue;
        } else {
          log.finest('_ElementBucket: inferKind($idents) => state variable');
          return KeyKind.stateVariable;
        }
      }

      for (final element in staticElements) {
        if (_elementContains(_localVariables, element)) {
          log.finest('_ElementBucket: inferKind($idents) => local variable');
          return KeyKind.localVariable;
        }

        if (_elementContains(_localFunctions, element)) {
          log.finest('_ElementBucket: inferKind($idents) => local function');
          return KeyKind.localFunction;
        }

        if (_elementContains(_params, element)) {
          log.finest('_ElementBucket: inferKind($idents) => function param');
          return KeyKind.functionParam;
        }

        if (_elementContains(_classFields, element)) {
          log.finest('_ElementBucket: inferKind($idents) => class field');
          return KeyKind.classField;
        }

        if (_elementContains(_classGetterFields, element)) {
          log.finest(
            '_ElementBucket: inferKind($idents) => class getter field',
          );
          return KeyKind.classField;
        }
      }

      log.finest('_ElementBucket: inferKind($idents) => unknown');
      return KeyKind.unknown;
    });
  }

  bool _elementContains(List<Element> list, Element target) {
    return list.any((e) => e.id == target.id);
  }
}
