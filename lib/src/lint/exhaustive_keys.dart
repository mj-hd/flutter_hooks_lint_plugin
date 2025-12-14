import 'dart:async';

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:flutter_hooks_lint_plugin/main.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/config.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/hook_widget_visitor.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/lint_error.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/supression.dart';
import 'package:logging/logging.dart';

final log = Logger('exhaustive_keys');

const exhaustiveKeysName = 'exhaustive_keys';

const _missingKeyCode = 'missing_key';
const _unnecessaryKeyCode = 'unnecessary_key';
const _functionKeyCode = 'function_key';

class ExhaustiveKeysRule extends MultiAnalysisRule {
  static const codeForMissingKey = LintCode(
    _missingKeyCode,
    "Missing key '{0}' ({1}) found. Add the key, or ignore this line.",
  );
  static const codeForUnnecessaryKey = LintCode(
    _unnecessaryKeyCode,
    "Unnecessary key '{0}' ({1}) found. Remove the key, or ignore this line.",
  );
  static const codeForFunctionKey = LintCode(
    _functionKeyCode,
    "'{0}' ({1}) changes on every re-build. Move its definition inside the hook, or wrap with useCallback.",
  );

  ExhaustiveKeysRule(this.pluginContext)
    : super(
        name: exhaustiveKeysName,
        description: 'Rule for maintaining flutter_hooks keys',
      );

  final FlutterHooksLintPluginContext pluginContext;

  @override
  List<DiagnosticCode> get diagnosticCodes => const [
    codeForMissingKey,
    codeForUnnecessaryKey,
    codeForFunctionKey,
  ];

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final options = pluginContext
        .optionsForPackage(context.package)
        .flutterHooksLintPlugin
        .exhaustiveKeys;

    // TODO: should be cleared before searching build blocks?
    final bucket = ElementBucket();
    final validator = _ExhaustiveKeysValidator(
      bucket: bucket,
      options: options,
      onReport: (error) {
        final suppression = Suppression.fromCache(context.currentUnit!.content);
        if (suppression.isSuppressedLintError(error)) return;
        reportAtNode(
          error.errNode,
          diagnosticCode: error.code,
          arguments: [
            if (error.key != null) error.key!.toString(),
            if (error.key?.kind.toReadableString() != null)
              error.key!.kind.toReadableString()!,
          ],
        );
      },
    );
    final visitor = HookBlockVisitor(
      onClassDeclaration: (node) {
        bucket.addClassFields(node);
      },
      onFormalParametersList: (node) {
        bucket.addFunctionParams(node);
      },
      onBuildBlock: (node) {
        validator.validate(node);
      },
    );

    registry.addClassDeclaration(this, visitor);
    registry.addFunctionDeclaration(this, visitor);
  }
}

class _ExhaustiveKeysCommonFix extends ResolvedCorrectionProducer {
  _ExhaustiveKeysCommonFix({
    required super.context,
    required this.pluginContext,
  });

  final FlutterHooksLintPluginContext pluginContext;

  @override
  final applicability = CorrectionApplicability.singleLocation;

  @override
  List<String>? fixArguments;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final options = pluginContext
        .optionsForPackage(
          sessionHelper.session.analysisContext.contextRoot.workspace
              .findPackageFor(file),
        )
        .flutterHooksLintPlugin
        .exhaustiveKeys;

    final edits = <Future<void>>[];

    // TODO: should be cleared before searching build blocks?
    final bucket = ElementBucket();
    final validator = _ExhaustiveKeysValidator(
      bucket: bucket,
      options: options,
      onReport: (error) {
        if (error.isSame(diagnostic)) {
          fixArguments = [error.key!.toString()];
          edits.addAll(
            error.fixes.map(
              (f) => f.addDartFileEdit(builder, file, error.ctxNode),
            ),
          );
        }
      },
    );
    final visitor = HookBlockVisitor(
      onClassDeclaration: (node) {
        bucket.addClassFields(node);
      },
      onFormalParametersList: (node) {
        bucket.addFunctionParams(node);
      },
      onBuildBlock: (node) {
        validator.validate(node);
      },
    );

    unit.visitChildren(visitor);

    await Future.wait(edits);
  }
}

class MissingKeyFix extends _ExhaustiveKeysCommonFix {
  static const _fixKindForMissingKey = FixKind(
    'dart.fix.$exhaustiveKeysName.missing_key',
    DartFixKindPriority.standard,
    "Add missing '{0}' key",
  );

  MissingKeyFix({required super.context, required super.pluginContext});

  @override
  final fixKind = _fixKindForMissingKey;
}

class UnnecessaryKeyFix extends _ExhaustiveKeysCommonFix {
  static const _fixKindForUnnecessaryKey = FixKind(
    'dart.fix.$exhaustiveKeysName.unnecessary_key',
    DartFixKindPriority.standard,
    "Remove unnecessary '{0}' key",
  );

  UnnecessaryKeyFix({required super.context, required super.pluginContext});

  @override
  final fixKind = _fixKindForUnnecessaryKey;
}

class _ExhaustiveKeysValidator {
  _ExhaustiveKeysValidator({
    required this.bucket,
    required this.options,
    required this.onReport,
  });

  final ExhaustiveKeysOptions options;
  final ElementBucket bucket;
  final void Function(LintError) onReport;

  void validate(Block node) {
    final localFunctionVisitor = _LocalFunctionVisitor(bucket: bucket);

    node.visitChildren(localFunctionVisitor);

    final localVariableVisitor = _LocalVariableVisitor(
      bucket: bucket,
      constantHooks: options.constantHooks,
    );

    node.visitChildren(localVariableVisitor);

    final hooksVisitor = _HooksVisitor(bucket: bucket, onReport: onReport);

    node.visitChildren(hooksVisitor);
  }
}

class _LocalVariableVisitor extends SimpleAstVisitor<void> {
  _LocalVariableVisitor({required this.bucket, required this.constantHooks});

  final ElementBucket bucket;
  final List<String> constantHooks;

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    log.finer('_VariableDeclarationVisitor: visit($node)');

    final decl = node
        .findChild<VariableDeclarationList>()
        ?.findChild<VariableDeclaration>();

    if (decl == null) {
      log.finest(
        '_VariableDeclarationVisitor: visit($node) => variable declaration not found',
      );
      return;
    }
    if (decl.isConst) {
      log.finest(
        '_VariableDeclarationVisitor: visit($node) => variable is const',
      );
      return;
    }

    final elem = decl.declaredFragment?.element;

    if (elem is! LocalVariableElement) {
      log.finest(
        '_VariableDeclarationVisitor: visit($node) => variable is not LocalVariableElement',
      );
      return;
    }

    // ignore values generated by useState
    final initializer = decl.initializer;
    if (initializer is! MethodInvocation) {
      bucket.addLocalVariable(elem);
      return;
    }

    final methodName = initializer.methodName.name;

    if (methodName == 'useState') {
      log.finest(
        '_VariableDeclarationVisitor: visit($node) => variable is useState',
      );

      bucket.addStateVariable(elem);
      return;
    }

    // ignore values generated by constantHooks (default: useRef, useIsMounted, ...etc)
    if (constantHooks.contains(methodName)) {
      log.finest(
        '_VariableDeclarationVisitor: visit($node) => variable is ${initializer.methodName.name}',
      );
      return;
    }

    // ignore hooks which do not have keys parameter
    switch (methodName) {
      // named parameter
      case 'useAnimationController':
      case 'usePageController':
      case 'useScrollController':
      case 'useSingleTickerProvider':
      case 'useStreamController':
      case 'useTabController':
      case 'useTransformationController':
        final keys = initializer.argumentList.arguments
            .whereType<NamedExpression>()
            .where((arg) => arg.name.label.name == 'keys');

        if (keys.isEmpty) return;

        final key = keys.first;

        final value = key.expression;

        if (value is ListLiteral && value.elements.isEmpty) {
          return;
        }

        break;

      // 2nd parameter
      case 'useMemoized':
      case 'useValueNotifier':
        if (initializer.argumentList.arguments.length <= 1) {
          return;
        }

        final key = initializer.argumentList.arguments[1];
        if (key is ListLiteral && key.elements.isEmpty) {
          return;
        }

        break;
    }

    bucket.addLocalVariable(elem);
  }
}

class _LocalFunctionVisitor extends SimpleAstVisitor<void> {
  _LocalFunctionVisitor({required this.bucket});

  final ElementBucket bucket;

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    log.finer('_LocalFunctionVisitor: visit($node)');

    final element = node.functionDeclaration.declaredFragment?.element;

    if (element != null) {
      bucket.addFunctionDeclaration(element);
    }
  }
}

enum _HookType {
  unknown,
  omittedPositionalKeys,
  positionalKeysExpression,
  positionalKeysLiteral,
  // omittedNamedKeys,
  // namedKeys,
}

class _HooksVisitor extends RecursiveAstVisitor<void> {
  _HooksVisitor({required this.bucket, required this.onReport});

  final ElementBucket bucket;

  final void Function(LintError) onReport;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    log.finer('_HooksVisitor: visitMethodInvocation($node)');

    final arguments = node.argumentList.arguments;

    _HookType type = _HookType.unknown;

    switch (node.methodName.name) {
      case 'useEffect':
      case 'useMemoized':
      case 'useCallback':
        if (arguments.isNotEmpty) {
          // useMemoized(() { ... });
          if (arguments.length == 1) {
            log.finest('_HooksVisitor: hooks with omitted positional keys');
            type = _HookType.omittedPositionalKeys;

            // useEffect(() { ... });
            if (node.methodName.name == 'useEffect') {
              log.finest(
                '_HooksVisitor: useEffect with omitted positional keys',
              );
              return;
            }
          }

          // useEffect(() { ... }, ...);
          if (arguments.length == 2) {
            log.finest('_HooksVisitor: hooks with positional keys');
            type = _HookType.positionalKeysExpression;

            final keys = arguments[1];

            // useEffect(() { ... }, [...]);
            if (keys is ListLiteral) {
              log.finest('_HooksVisitor: hooks with positional keys literal');
              type = _HookType.positionalKeysLiteral;
            }
          }
        }
    }

    if (type == _HookType.unknown) return;

    log.finest('_HooksVisitor: hooks found');

    final actualKeys = <Key>[];
    final expectedKeys = <Key>[];

    // find identifiers in the hook's keys
    switch (type) {
      case _HookType.positionalKeysLiteral:
        final keys = arguments[1];

        log.finest(
          '_HooksVisitor: find identifiers in the positional keys literal',
        );

        final visitor = _KeysIdentifierVisitor(context: bucket);

        keys.visitChildren(visitor);

        actualKeys.addAll(visitor.keys);

        log.finest('_HooksVisitor: actual keys $actualKeys');
        break;

      default:
    }

    if (bucket.isNotEmpty) {
      // find identifiers in the hook body
      final visitor = _KeysIdentifierVisitor(
        context: bucket,
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

    for (final key in missingKeys) {
      final fixes = <LintFix>[];
      late AstNode errNode;

      switch (type) {
        case _HookType.omittedPositionalKeys:
          fixes.add(
            LintFix.appendFunctionParam(
              message: 'Add missing "[$key]" parameter',
              literal: node,
              param: '[$key]',
            ),
          );
          errNode = node.methodName;
          break;

        case _HookType.positionalKeysExpression:
          errNode = arguments[1];
          break;

        case _HookType.positionalKeysLiteral:
          final keys = arguments[1] as ListLiteral;
          fixes.add(
            LintFix.appendListElement(
              message: 'Add missing "$key" key',
              literal: keys,
              element: key.toString(),
            ),
          );
          errNode = keys;
          break;

        default:
          throw StateError('unexpected hook type $type');
      }

      onReport(
        LintError(
          code: ExhaustiveKeysRule.codeForMissingKey,
          key: key,
          ctxNode: node,
          errNode: errNode,
          fixes: fixes,
        ),
      );
    }

    for (final key in unnecessaryKeys) {
      late AstNode errNode;
      final fixes = <LintFix>[];

      switch (type) {
        case _HookType.positionalKeysLiteral:
          final keys = arguments[1] as ListLiteral;
          final index = keys.elements.indexWhere(
            (e) => e.toSource() == key.toString(),
          );
          if (index != -1) {
            fixes.add(
              LintFix.removeListElement(
                message: 'Remove unnecessary "$key" key',
                literal: keys,
                element: keys.elements[index],
              ),
            );
          }
          errNode = keys;
          break;

        default:
          throw StateError('unexpected hook type $type');
      }

      onReport(
        LintError(
          code: ExhaustiveKeysRule.codeForUnnecessaryKey,
          key: key,
          ctxNode: node,
          errNode: errNode,
          fixes: fixes,
        ),
      );
    }

    for (final key in actualKeys) {
      if (key.kind == KeyKind.localFunction) {
        switch (type) {
          case _HookType.positionalKeysLiteral:
            final keys = arguments[1] as ListLiteral;
            onReport(
              LintError(
                code: ExhaustiveKeysRule.codeForFunctionKey,
                key: key,
                ctxNode: node,
                errNode: keys,
              ),
            );
            break;

          default:
            throw StateError('unexpected hook type $type');
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

  final ElementBucket context;
  final bool onlyBuildVaribles;

  final List<Key> _keys = [];

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    log.finer('_KeysIdentifierVisitor: visitPrefixedIdentifier($node)');

    final idents = [node.prefix, node.identifier];

    _visitKey(Key.withElementBucket(context, idents));
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    log.finer('_KeysIdentifierVisitor: visitPropertyAccess($node)');

    final visitor = _PropertyAccessVisitor();

    node.visitChildren(visitor);

    final idents = visitor.idents;

    _visitKey(Key.withElementBucket(context, idents));
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    log.finer('_KeysIdentifierVisitor: visitSimpleIdentifier($node)');

    _visitKey(Key.withElementBucket(context, [node]));

    return super.visitSimpleIdentifier(node);
  }

  void _visitKey(Key? key) {
    log.finer('_KeysIdentifierVisitor: _visitKey($key)');

    if (key == null) {
      log.finest(
        '_KeysIdentifierVisitor: _visitKey($key) => keyent is not resolved',
      );
      return;
    }

    if (onlyBuildVaribles) {
      if (!key.isBuildVariable) {
        log.finest(
          '_KeysIdentifierVisitor: _visitKey($key) => is build variable',
        );
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
