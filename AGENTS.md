# Repository Guide

This is a Dart Analyzer plugin for flutter_hooks.

## Development

Run `dart pub get`, `dart format .`, `dart analyze .`, and `dart test` from the repository root.

## macOS plugin cache failures

On macOS, an Analysis Server crash after a harmless plugin source edit may be an SDK/plugin AOT cache or code-signing problem rather than a plugin bug.

Before changing plugin logic, retry after deleting ~/.dartServer/.plugin_manager.

See: https://github.com/dart-lang/sdk/issues/63813
