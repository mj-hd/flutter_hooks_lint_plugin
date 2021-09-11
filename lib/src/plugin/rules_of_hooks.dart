import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;

class RulesOfHooksVisitor<R> extends GeneralizingAstVisitor<R> {
  RulesOfHooksVisitor({
    required this.file,
    required this.unit,
    required this.onReport,
  });

  final String file;
  final CompilationUnit unit;
  final Function(String, String, plugin.Location) onReport;
}
