import 'package:analyzer/source/line_info.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/lint_error.dart';

class Suppression {
  static final _ignoreRegExp = RegExp(
    '//[ ]*ignore:(.*)',
    multiLine: true,
  );

  static final _ignoreForFileRegExp = RegExp(
    '//[ ]*ignore_for_file:(.*)',
    multiLine: true,
  );

  static final _ignoreForKeysRegExp = RegExp(
    '//[ ]*ignore_keys:(.*)',
    multiLine: true,
  );

  Suppression({
    required String content,
    required this.lineInfo,
  }) {
    for (final match in _ignoreForFileRegExp.allMatches(content)) {
      final ids = match.group(1);

      if (ids == null) continue;

      fileScope.addAll(ids.split(',').map((s) => s.trim()).toList());
    }

    for (final match in _ignoreRegExp.allMatches(content)) {
      final ids = match.group(1);
      if (ids == null) continue;

      final loc = lineInfo.getLocation(match.start);

      lineScope
          .putIfAbsent(loc.lineNumber, () => LineScopeSuppressions())
          .addIdsAll(ids.split(',').map((s) => s.trim()).toList());
    }

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
  final IdSuppression fileScope = IdSuppression();
  final Map<int, LineScopeSuppressions> lineScope = {};

  bool isSuppressedLintError(LintError err) {
    final loc = lineInfo.getLocation(err.errNode.beginToken.charOffset);
    return isSuppressed(err.code, loc.lineNumber, err.key);
  }

  bool isSuppressed(String code, int line, [String? key]) {
    if (fileScope.ids.contains(code)) {
      return true;
    }

    final lineScopeSuppressions = [lineScope[line], lineScope[line - 1]];

    if (lineScopeSuppressions.any((sup) => sup?.containsId(code) == true)) {
      return true;
    }

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

  IdSuppression? id;
  KeySuppression? key;

  void addIdsAll(List<String> vals) {
    id ??= IdSuppression();

    id!.addAll(vals);
  }

  void addKeysAll(List<String> vals) {
    key ??= KeySuppression();

    key!.addAll(vals);
  }

  bool containsId(String target) {
    return id?.ids.contains(target) == true;
  }

  bool containsKey(String target) {
    return key?.keys.contains(target) == true;
  }
}

class IdSuppression {
  IdSuppression();

  Set<String> ids = {};

  void addAll(List<String> vals) {
    ids.addAll(vals);
  }
}

class KeySuppression {
  KeySuppression();

  Set<String> keys = {};

  void addAll(List<String> vals) {
    keys.addAll(vals);
  }
}
