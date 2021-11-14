import 'package:analyzer/source/line_info.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/utils/lint_error.dart';

class Supression {
  static final _ignoreRegExp = RegExp('//[ ]*ignore:(.*)', multiLine: true);

  static final _ignoreForFileRegExp =
      RegExp('//[ ]*ignore_for_file:(.*)', multiLine: true);

  Supression({
    required String content,
    required this.lineInfo,
  }) {
    for (final match in _ignoreForFileRegExp.allMatches(content)) {
      final ids = match.group(1);

      if (ids == null) continue;

      fileScope.addAll(ids.split(',').map((s) => s.trim()));
    }

    for (final match in _ignoreRegExp.allMatches(content)) {
      final ids = match.group(1);
      if (ids == null) continue;

      final loc = lineInfo.getLocation(match.start);

      lineScope
          .putIfAbsent(loc.lineNumber, () => <String>{})
          .addAll(ids.split(',').map((s) => s.trim()));
    }
  }

  final LineInfo lineInfo;
  final Set<String> fileScope = {};
  final Map<int, Set<String>> lineScope = {};

  bool isSupressedLintError(LintError err) {
    final loc = lineInfo.getLocation(err.node.beginToken.charOffset);
    return isSupressed(err.code, loc.lineNumber);
  }

  bool isSupressed(String code, int line) {
    if (fileScope.contains(code)) {
      return true;
    }

    if (lineScope[line]?.contains(code) == true) {
      return true;
    }

    if (lineScope[line - 1]?.contains(code) == true) {
      return true;
    }

    return false;
  }
}
