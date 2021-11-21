import 'package:analyzer/dart/ast/ast.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/option.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/exhaustive_keys.dart';

import '../test/utils.dart';

late final CompilationUnit unit;

class ExhaustiveKeysBenchmark extends BenchmarkBase {
  ExhaustiveKeysBenchmark() : super('ExhaustiveKeys');

  static void main() {
    ExhaustiveKeysBenchmark().report();
  }

  @override
  void run() {
    findExhaustiveKeys(
      unit,
      options: ExhaustiveKeysOptions(),
      onMissingKeyReport: (_, __, ___, ____) {},
      onUnnecessaryKeyReport: (_, __, ___, ____) {},
      onFunctionKeyReport: (_, __, ___, ____) {},
    );
  }

  @override
  void setup() {}

  @override
  void teardown() {}
}

void main() async {
  const code = '''
    class TestWidget extends HookWidget {
      const TestWidget({
        Key? key,
        required this.dep,
      }): super(key: key);

      final String dep;

      @override
      Widget build(BuildContext context) {
        useEffect(() {
          print(dep);
        }, []);

        return Text('TestWidget');
      }
    }
  ''';

  unit = await compileCode(code);

  ExhaustiveKeysBenchmark.main();
}
