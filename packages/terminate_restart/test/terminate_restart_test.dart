// // import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:terminate_restart/terminate_restart.dart';
// // import 'package:terminate_restart/terminate_restart_platform_interface.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';
//
// class MockTerminateRestartPlatform
//     with MockPlatformInterfaceMixin
//     implements TerminateRestartPlatform {
//   bool wasRestartCalled = false;
//   bool shouldSucceed = true;
//   Map<String, dynamic>? lastRestartArguments;
//
//   @override
//   Future<bool> restartApp({
//     bool clearData = false,
//     bool preserveKeychain = false,
//     bool preserveUserDefaults = false,
//     bool terminate = true,
//   }) async {
//     if (!shouldSucceed) {
//       throw Exception('Mock platform error');
//     }
//
//     wasRestartCalled = true;
//     lastRestartArguments = {
//       'clearData': clearData,
//       'preserveKeychain': preserveKeychain,
//       'preserveUserDefaults': preserveUserDefaults,
//       'terminate': terminate,
//     };
//     return shouldSucceed;
//   }
// }
//
// void main() {
//   TestWidgetsFlutterBinding.ensureInitialized();
//   late MockTerminateRestartPlatform mockPlatform;
//
//   setUp(() {
//     mockPlatform = MockTerminateRestartPlatform();
//     TerminateRestartPlatform.instance = mockPlatform;
//     TerminateRestart.instance.initialize();
//   });
//
//   group('TerminateRestart', () {
//     testWidgets('restartApp with default values', (tester) async {
//       final success = await TerminateRestart.instance.restartApp(
//         options: const TerminateRestartOptions(),
//       );
//
//       expect(mockPlatform.wasRestartCalled, true);
//       expect(mockPlatform.lastRestartArguments, {
//         'clearData': false,
//         'preserveKeychain': false,
//         'preserveUserDefaults': false,
//         'terminate': true,
//       });
//       expect(success, true);
//     });
//
//     testWidgets('restartApp with custom values', (tester) async {
//       final success = await TerminateRestart.instance.restartApp(
//         options: const TerminateRestartOptions(
//           clearData: true,
//           preserveKeychain: true,
//           preserveUserDefaults: true,
//           terminate: false,
//         ),
//       );
//
//       expect(mockPlatform.wasRestartCalled, true);
//       expect(mockPlatform.lastRestartArguments, {
//         'clearData': true,
//         'preserveKeychain': true,
//         'preserveUserDefaults': true,
//         'terminate': false,
//       });
//       expect(success, true);
//     });
//
//     testWidgets('restartApp handles failure', (tester) async {
//       mockPlatform.shouldSucceed = false;
//
//       expect(
//         () => TerminateRestart.instance.restartApp(
//           options: const TerminateRestartOptions(),
//         ),
//         throwsException,
//       );
//     });
//   });
// }
