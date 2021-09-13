import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/utils.dart';

class RulesOfHooksVisitor<R> extends GeneralizingAstVisitor<R> {
  RulesOfHooksVisitor({
    required this.onReport,
  });

  final Function(LintError) onReport;
}
