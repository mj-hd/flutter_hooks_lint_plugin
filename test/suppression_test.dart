// ignore_for_file: non_constant_identifier_names
import 'dart:async';

import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/test_utilities/mock_sdk.dart';
import 'package:analyzer_plugin/channel/channel.dart';
import 'package:analyzer_plugin/protocol/protocol.dart' as protocol;
import 'package:analyzer_plugin/protocol/protocol_constants.dart' as protocol;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as protocol;
import 'package:analyzer_plugin/src/protocol/protocol_internal.dart'
    as protocol;
import 'package:analysis_server_plugin/src/plugin_server.dart';
import 'package:analysis_server_plugin/src/correction/fix_generators.dart';
import 'package:analyzer_testing/resource_provider_mixin.dart';
import 'package:flutter_hooks_lint_plugin/main.dart';
import 'package:test/test.dart';
import 'package:async/async.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'utils.dart';

void main() {
  setUpLogging();
  defineReflectiveSuite(() {
    defineReflectiveTests(SuppressionTest);
  });
}

@reflectiveTest
class SuppressionTest extends PluginServerTestBase with PluginServerTestMixin {
  @override
  Future<void> setUp() async {
    await super.setUp();

    pluginServer = PluginServer.new2(
      resourceProvider: resourceProvider,
      plugins: {plugin.name: plugin},
    );
    await startPlugin();
  }

  Future<void> test_file_scoped_suppression() async {
    _writeAnalysisOptionsYamlFile();
    newFile(filePath, '''
        // ignore_for_file: ${plugin.name}/missing_key
        import 'package:flutter_hooks/flutter_hooks.dart';

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
    ''');
    await _setRoots();

    var paramsQueue = _analysisErrorsParams;
    var params = await paramsQueue.next;

    expect(params.errors, isEmpty);
  }

  Future<void> test_line_scoped_suppression() async {
    _writeAnalysisOptionsYamlFile();
    newFile(filePath, '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
              // ignore: ${plugin.name}/missing_key
            }, []);

            return Text('TestWidget');
          }
        }
    ''');
    await _setRoots();

    var paramsQueue = _analysisErrorsParams;
    var params = await paramsQueue.next;

    expect(params.errors, isEmpty);
  }

  Future<void> test_line_scoped_key_suppression() async {
    _writeAnalysisOptionsYamlFile();
    newFile(filePath, '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
              // ignore_keys: dep
            }, []);

            return Text('TestWidget');
          }
        }
    ''');
    await _setRoots();

    var paramsQueue = _analysisErrorsParams;
    var params = await paramsQueue.next;

    expect(params.errors, isEmpty);
  }

  void _writeAnalysisOptionsYamlFile() {
    newAnalysisOptionsYamlFile(packagePath, '''
plugins:
  ${plugin.name}:
    path: some/path
    diagnostics:
      exhaustive_keys: true
''');
  }
}

// copied and modified from https://github.com/dart-lang/sdk/blob/a750287f4433624cae5137a3a20dd47f90cafe04/pkg/analysis_server_plugin/test/src/plugin_server_test_base.dart
class FakeChannel implements PluginCommunicationChannel {
  final _completers = <String, Completer<protocol.Response>>{};

  final StreamController<protocol.Notification> _notificationsController =
      StreamController();

  void Function(protocol.Request)? _onRequest;

  int _idCounter = 0;

  Stream<protocol.Notification> get notifications =>
      _notificationsController.stream;

  @override
  void close() {}

  @override
  void listen(
    void Function(protocol.Request request)? onRequest, {
    void Function()? onDone,
    Function? onError,
    Function? onNotification,
  }) {
    _onRequest = onRequest;
  }

  @override
  void sendNotification(protocol.Notification notification) {
    _notificationsController.add(notification);
  }

  Future<protocol.Response> sendRequest(protocol.RequestParams params) {
    if (_onRequest == null) {
      fail(
        '_onReuest is null! `listen` has not yet been called on this channel.',
      );
    }
    var id = (_idCounter++).toString();
    var request = params.toRequest(id);
    var completer = Completer<protocol.Response>();
    _completers[request.id] = completer;
    _onRequest!(request);
    return completer.future;
  }

  @override
  void sendResponse(protocol.Response response) {
    var completer = _completers.remove(response.id);
    completer?.complete(response);
  }
}

mixin PluginServerTestMixin on PluginServerTestBase {
  protocol.ContextRoot get contextRoot => protocol.ContextRoot(packagePath, []);

  String get packagePath => convertPath('/package');
  String get filePath => join(packagePath, 'lib', 'test.dart');

  StreamQueue<protocol.AnalysisErrorsParams> get _analysisErrorsParams {
    return StreamQueue(
      channel.notifications
          .where((n) => n.event == protocol.ANALYSIS_NOTIFICATION_ERRORS)
          .map((n) => protocol.AnalysisErrorsParams.fromNotification(n))
          .where((p) => p.file == filePath),
    );
  }

  Future<void> _setRoots() async {
    var future1 = channel.sendRequest(
      protocol.AnalysisSetContextRootsParams([contextRoot]),
    );
    var future2 = channel.sendRequest(
      protocol.AnalysisSetAnalysisRootsParams([contextRoot.root], []),
    );
    await Future.wait([future1, future2]);
  }
}

class PluginServerTestBase with ResourceProviderMixin {
  final channel = FakeChannel();

  late final PluginServer pluginServer;

  Folder get byteStoreRoot => getFolder('/byteStore');

  Folder get sdkRoot => getFolder('/sdk');

  Future<void> setUp() async {
    createMockSdk(resourceProvider: resourceProvider, root: sdkRoot);
  }

  Future<void> startPlugin() async {
    await pluginServer.initialize();
    pluginServer.start(channel);

    await pluginServer.handlePluginVersionCheck(
      protocol.PluginVersionCheckParams(
        byteStoreRoot.path,
        sdkRoot.path,
        '0.0.1',
      ),
    );
  }

  void tearDown() {
    registeredFixGenerators.clearLintProducers();
    registeredFixGenerators.clearWarningProducers();
  }
}
