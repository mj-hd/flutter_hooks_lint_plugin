import 'package:analyzer/source/line_info.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/suppression.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

void main() {
  group('suppression', () {
    test('file scoped lint id suppression', () {
      final source = '''
        line1 // ignore_for_file: lint_id1, lint_id2
      ''';

      final suppression = Suppression(
        content: source,
        lineInfo: LineInfo.fromContent(source),
      );

      expect(suppression.isSuppressed('lint_id1', 1), true);
      expect(suppression.isSuppressed('lint_id2', 1), true);
      expect(suppression.isSuppressed('lint_id3', 1), false);
    });

    test('line scoped lint id suppression', () {
      final source = '''
        line1 // ignore: lint_id1, lint_id2
      ''';

      final suppression = Suppression(
        content: source,
        lineInfo: LineInfo.fromContent(source),
      );

      expect(suppression.isSuppressed('lint_id1', 1), true);
      expect(suppression.isSuppressed('lint_id2', 1), true);
      expect(suppression.isSuppressed('lint_id3', 1), false);

      // next line
      expect(suppression.isSuppressed('lint_id1', 2), true);
      expect(suppression.isSuppressed('lint_id2', 2), true);
      expect(suppression.isSuppressed('lint_id3', 2), false);

      // other lines
      expect(suppression.isSuppressed('lint_id1', 3), false);
      expect(suppression.isSuppressed('lint_id2', 3), false);
      expect(suppression.isSuppressed('lint_id3', 3), false);
    });

    test('line scoped key suppression', () {
      final source = '''
        line1 // ignore_keys: key1, key2
      ''';

      final suppression = Suppression(
        content: source,
        lineInfo: LineInfo.fromContent(source),
      );

      expect(suppression.isSuppressed('lint_id', 1, 'key1'), true);
      expect(suppression.isSuppressed('lint_id', 1, 'key2'), true);
      expect(suppression.isSuppressed('lint_id', 1, 'key3'), false);

      // next line
      expect(suppression.isSuppressed('lint_id', 2, 'key1'), true);
      expect(suppression.isSuppressed('lint_id', 2, 'key2'), true);
      expect(suppression.isSuppressed('lint_id', 2, 'key3'), false);

      // other lines
      expect(suppression.isSuppressed('lint_id', 3, 'key1'), false);
      expect(suppression.isSuppressed('lint_id', 3, 'key2'), false);
      expect(suppression.isSuppressed('lint_id', 3, 'key3'), false);
    });
  });
}
