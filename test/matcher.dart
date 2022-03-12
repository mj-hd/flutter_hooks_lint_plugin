import 'package:flutter_hooks_lint_plugin/src/lint/exhaustive_keys.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/rules_of_hooks.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/lint_error.dart';
import 'package:test/test.dart';

class LintErrorMatcher extends Matcher {
  LintErrorMatcher([
    this.key,
    this.message,
    this.fixValues,
  ]);

  // TODO(mj-hd): create an another custom matcher for the fixes to test removing, replacing, ...
  LintErrorMatcher.fixes(
    this.fixValues,
  )   : key = null,
        message = null;

  final String? key;
  final RegExp? message;
  final List<String>? fixValues;

  @override
  Description describe(Description description) {
    final fields = <String>[];

    if (key != null) {
      fields.add('key: $key');
    }

    if (message != null) {
      fields.add('message(RegExp): $message');
    }

    if (fixValues != null) {
      final values = fixValues!.map((e) => '"${e.toString()}"').join(',');
      fields.add('fixValues: [$values]');
    }

    description.addAll('', ',', '', fields);

    return description;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! LintError) {
      mismatchDescription.add('mismatch type ${item.runtimeType}');
      return mismatchDescription;
    }

    final fields = <String>[];

    if (key != null) {
      fields.add('key: $key');
    }

    if (message != null) {
      fields.add('message(RegExp): $message');
    }

    final values = item.fixes.map((e) => '"${e.toString()}"').join(',');
    fields.add('fixValues: [$values]');

    mismatchDescription.addAll('', ',', '', fields);

    return mismatchDescription;
  }

  @override
  bool matches(dynamic item, Map matchState) {
    return item is LintError &&
        (key == null || item.key == key) &&
        (message == null || message!.hasMatch(item.message)) &&
        (fixValues == null || _matchesFixes(item.fixes));
  }

  bool _matchesFixes(List<LintFix>? actual) {
    if (actual == null) return false;
    return fixValues!.every(
      (expected) => actual.any(
        (fix) => expected == fix.value,
      ),
    );
  }
}

class LintErrorMissingKeyMatcher extends LintErrorMatcher {
  LintErrorMissingKeyMatcher(
    String key,
    this.kindStr,
  ) : super(key, null);

  final String? kindStr;

  @override
  Description describe(Description description) {
    final result = super.describe(description);

    result.add(', kindStr: $kindStr');

    return result;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final result =
        super.describeMismatch(item, mismatchDescription, matchState, verbose);

    if (item is! LintErrorMissingKey) {
      result.add('mismatch type ${item.runtimeType}');
      return result;
    }

    result.add(', kindStr: ${item.kindStr}');

    return result;
  }

  @override
  bool matches(dynamic item, Map matchState) {
    return super.matches(item, matchState) &&
        item is LintErrorMissingKey &&
        item.kindStr == kindStr;
  }
}

class LintErrorUnnecessaryKeyMatcher extends LintErrorMatcher {
  LintErrorUnnecessaryKeyMatcher(
    String key,
    this.kindStr,
  ) : super(key);

  final String? kindStr;

  @override
  Description describe(Description description) {
    final result = super.describe(description);

    result.add(', kindStr: $kindStr');

    return result;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final result =
        super.describeMismatch(item, mismatchDescription, matchState, verbose);

    if (item is! LintErrorUnnecessaryKey) {
      result.add('mismatch type ${item.runtimeType}');
      return result;
    }

    result.add(', kindStr: ${item.kindStr}');

    return result;
  }

  @override
  bool matches(dynamic item, Map matchState) {
    return super.matches(item, matchState) &&
        item is LintErrorUnnecessaryKey &&
        item.kindStr == kindStr;
  }
}

class LintErrorFunctionKeyMatcher extends LintErrorMatcher {
  LintErrorFunctionKeyMatcher(String key) : super(key);

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final result =
        super.describeMismatch(item, mismatchDescription, matchState, verbose);

    if (item is! LintErrorFunctionKey) {
      result.add('mismatch type ${item.runtimeType}');
      return result;
    }

    return result;
  }

  @override
  bool matches(dynamic item, Map matchState) {
    return super.matches(item, matchState) && item is LintErrorFunctionKey;
  }
}

class LintErrorNestedHooksMatcher extends LintErrorMatcher {
  LintErrorNestedHooksMatcher(this.hookName) : super();

  final String hookName;

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    final result =
        super.describeMismatch(item, mismatchDescription, matchState, verbose);

    if (item is! LintErrorNestedHooks) {
      result.add('mismatch type ${item.runtimeType}');
      return result;
    }

    result.add(', hookName: $hookName');

    return result;
  }

  @override
  bool matches(dynamic item, Map matchState) {
    return super.matches(item, matchState) &&
        item is LintErrorNestedHooks &&
        item.hookName == hookName;
  }
}
