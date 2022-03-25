import 'package:mason/mason.dart' hide packageVersion;
import 'package:bloc_tools/src/command_runner.dart';
import 'package:bloc_tools/src/version.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

class MockLogger extends Mock implements Logger {}

class MockPubUpdater extends Mock implements PubUpdater {}

class FakeProcessResult extends Fake implements ProcessResult {}

void main() {
  const latestVersion = '0.0.0';

  group('bloc update', () {
    late Logger logger;
    late PubUpdater pubUpdater;
    late BlocToolsCommandRunner commandRunner;

    setUp(() {
      logger = MockLogger();
      pubUpdater = MockPubUpdater();

      when(() => logger.progress(any())).thenReturn(([String? _]) {});
      when(
        () => pubUpdater.getLatestVersion(any()),
      ).thenAnswer((_) async => packageVersion);
      when(
        () => pubUpdater.update(packageName: packageName),
      ).thenAnswer((_) => Future.value(FakeProcessResult()));

      commandRunner = BlocToolsCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
      );
    });

    test('handles pub latest version query errors', () async {
      when(
        () => pubUpdater.getLatestVersion(any()),
      ).thenThrow(Exception('oops'));
      final result = await commandRunner.run(['update']);
      expect(result, equals(ExitCode.software.code));
      verify(() => logger.progress('Checking for updates')).called(1);
      verify(() => logger.err('Exception: oops'));
      verifyNever(
        () => pubUpdater.update(packageName: any(named: 'packageName')),
      );
    });

    test('handles pub update errors', () async {
      when(
        () => pubUpdater.getLatestVersion(any()),
      ).thenAnswer((_) async => latestVersion);
      when(
        () => pubUpdater.update(packageName: any(named: 'packageName')),
      ).thenThrow(Exception('oops'));
      final result = await commandRunner.run(['update']);
      expect(result, equals(ExitCode.software.code));
      verify(() => logger.progress('Checking for updates')).called(1);
      verify(() => logger.err('Exception: oops'));
      verify(
        () => pubUpdater.update(packageName: any(named: 'packageName')),
      ).called(1);
    });

    test('updates when newer version exists', () async {
      when(
        () => pubUpdater.getLatestVersion(any()),
      ).thenAnswer((_) async => latestVersion);
      when(() => logger.progress(any())).thenReturn(([String? message]) {});
      final result = await commandRunner.run(['update']);
      expect(result, equals(ExitCode.success.code));
      verify(() => logger.progress('Checking for updates')).called(1);
      verify(() => logger.progress('Updating to $latestVersion')).called(1);
      verify(() => pubUpdater.update(packageName: packageName)).called(1);
    });

    test('does not update when already on latest version', () async {
      when(
        () => pubUpdater.getLatestVersion(any()),
      ).thenAnswer((_) async => packageVersion);
      when(() => logger.progress(any())).thenReturn(([String? message]) {});
      final result = await commandRunner.run(['update']);
      expect(result, equals(ExitCode.success.code));
      verify(
        () => logger.info('bloc is already at the latest version.'),
      ).called(1);
      verifyNever(() => logger.progress('Updating to $latestVersion'));
      verifyNever(() => pubUpdater.update(packageName: packageName));
    });
  });
}