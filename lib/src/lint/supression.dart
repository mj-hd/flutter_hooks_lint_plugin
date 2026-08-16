import 'package:analyzer/source/line_info.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/cache.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/lint_error.dart';

class Suppression {
  static final _ignoreForKeysRegExp = RegExp(
    '//[ ]*ignore_keys:(.*)',
    multiLine: true,
  );

  static final _cache = Cache<int, Suppression>(1);

  static Suppression fromCache(String content) =>
      _cache.doCache(content.hashCode, () => Suppression(content));

  Suppression(String content) : lineInfo = LineInfo.fromContent(content) {
    log.finer('Suppression ${content.hashCode}');

    for (final match in _ignoreForKeysRegExp.allMatches(content)) {
      final keys = match.group(1);
      if (keys == null) continue;

      final loc = lineInfo.getLocation(match.start);

      lineScope
          .putIfAbsent(loc.lineNumber, () => LineScopeSuppressions())
          .addKeysAll(keys.split(',').map((s) => s.trim()).toList());
    }
  }

  final LineInfo lineInfo;
  final Map<int, LineScopeSuppressions> lineScope = {};

  bool isSuppressedLintError(LintError err) {
    final loc = lineInfo.getLocation(err.errNode.beginToken.charOffset);
    return isSuppressed(
      err.code.lowerCaseName,
      loc.lineNumber,
      err.key.toString(),
    );
  }

  bool isSuppressed(String code, int line, [String? key]) {
    final lineScopeSuppressions = [lineScope[line], lineScope[line - 1]];

    if (key != null) {
      if (lineScopeSuppressions.any((sup) => sup?.containsKey(key) == true)) {
        return true;
      }
    }

    return false;
  }
}

class LineScopeSuppressions {
  LineScopeSuppressions();

  KeySuppression? key;

  void addKeysAll(List<String> vals) {
    key ??= KeySuppression();

    key!.addAll(vals);
  }

  bool containsKey(String target) {
    return key?.keys.contains(target) == true;
  }
}

class KeySuppression {
  KeySuppression();

  Set<String> keys = {};

  void addAll(List<String> vals) {
    keys.addAll(vals);
  }
}
