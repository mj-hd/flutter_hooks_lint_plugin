# Repository Guidelines

## Project Structure & Module Organization
- `lib/` hosts the analyzer plugin logic, with rule implementations and shared utilities; `bin/flutter_hooks_lint.dart` exposes the CLI entry point.  
- `test/` mirrors the rule surface through Dart test suites (`*_test.dart`) plus helpers in `matcher.dart` and `utils.dart`.  
- `benchmark/`, `example/`, and `go_game_app/` provide performance scripts and fixture apps for manual validation.  
- `tools/analyzer_plugin/` is the embeddable plugin skeleton; point its `pubspec.yaml` dependency to your absolute clone when iterating locally.

## Build, Test, and Development Commands
```sh
dart pub get                    # install/update dependencies
dart analyze .                  # static checks using package:lints
dart run flutter_hooks_lint_plugin:flutter_hooks_lint analyze ./
                                 # exercise the CLI against a project
dart test                       # run all rule + suppression specs
dart run benchmark/exhaustive_keys.dart
                                 # optional: check lint performance
```
Run commands from the repo root; keep IDEs in sync by restarting after dependency bumps.

## Coding Style & Naming Conventions
- Follow the Dart style enforced by `analysis_options.yaml` (inherits `package:lints/recommended` with `implementation_imports` allowed).  
- Always run `dart format .` (2-space indent, 80-col guidance) before sending a PR.  
- Use `lowerCamelCase` for variables/functions, `UpperCamelCase` for classes and visitors, and `snake_case.dart` filenames matching the rule they host.  
- Prefer small analyzer visitors per rule and keep diagnostics/messages alongside the rule to simplify localization.

## Testing Guidelines
- All rule changes require corresponding cases under `test/`, using `expectLint` helpers from `matcher.dart`.  
- Name specs `<feature>_test.dart` and mirror new fixtures with positive/negative examples.  
- Run the full `dart test` suite; when touching performance-sensitive logic, also run the benchmark script and note results in the PR.  
- For manual plugin verification, temporarily wire `tools/analyzer_plugin` into a sample app and confirm issues in the IDE Problems panel.

## Commit & Pull Request Guidelines
- Commits in history are short, imperative summaries (e.g., `prepare for 0.6.1 release`, `Bump analyzer ... (#27)`), optionally referencing PR numbers; follow the same pattern.  
- Each PR should describe motivation, outline key files touched, link related issues, and include `dart analyze`, `dart test`, and (if relevant) benchmark output.  
- Attach repro snippets or screenshots when a change affects diagnostics surfaced to users.  
- Keep PRs focused on one feature/fix; split refactors from behavior changes to ease review.
