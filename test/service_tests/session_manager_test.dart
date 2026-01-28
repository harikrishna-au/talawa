import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:talawa/locator.dart';
import 'package:talawa/models/user/user_info.dart';
import 'package:talawa/services/session_manager.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupLocator();
  });

  group('Test Session Manager', () {
    setUpAll(() {
      getAndRegisterDatabaseMutationFunctions();
    });

    setUp(() {
      reset(databaseFunctions);
      userConfig.currentUser = User(
        id: "99",
        name: 'Harry',
        refreshToken: 'refreshToken',
        authToken: 'authToken',
      );
    });

    test('Test Session Manager Constructor', () {
      SessionManager();
    });

    test('initialize refresh interval', () {
      fakeAsync((async) {
        sessionManager.initializeSessionRefresher();
        async.elapse(const Duration(seconds: 600));
      });
    });

    test('Refresh Interval is set.', () {
      expect(sessionManager.refreshInterval, 600);
    });

    test('Refresh Token Method - Success', () async {
      when(databaseFunctions.refreshAccessToken("refreshToken"))
          .thenAnswer((_) async => true);

      final result = await sessionManager.refreshSession();

      expect(result, true);
      verify(databaseFunctions.refreshAccessToken("refreshToken"));
    });

    test('Refresh Token Method - User not logged in', () async {
      userConfig.currentUser = User(id: 'null');

      final result = await sessionManager.refreshSession();

      expect(result, false);
    });

    test('Refresh Token Method - No refresh token', () async {
      userConfig.currentUser.refreshToken = null;

      final result = await sessionManager.refreshSession();

      expect(result, false);
    });

    test('Refresh Token Method - Retry on failure', () async {
      when(databaseFunctions.refreshAccessToken("refreshToken"))
          .thenThrow(Exception('Network error'));

      bool exceptionThrown = false;
      try {
        await sessionManager.refreshSession();
      } catch (e) {
        exceptionThrown = true;
        expect(e.toString(), contains('Network error'));
      }

      expect(exceptionThrown, isTrue,
          reason: 'Exception should have been thrown');

      // Should attempt 3 times
      verify(databaseFunctions.refreshAccessToken("refreshToken")).called(3);

      // Tokens should be cleared after all retries fail
      expect(userConfig.currentUser.refreshToken, isNull);
      expect(userConfig.currentUser.authToken, isNull);
    });

    test('Refresh Token Method - Concurrent calls', () async {
      when(databaseFunctions.refreshAccessToken("refreshToken"))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return true;
      });

      // Start multiple concurrent refresh attempts using the guarded method
      final futures = [
        sessionManager.refreshSessionWithGuard(),
        sessionManager.refreshSessionWithGuard(),
        sessionManager.refreshSessionWithGuard(),
      ];

      final results = await Future.wait(futures);

      // All should succeed
      expect(results, [true, true, true]);

      // But the actual refresh should only be called once due to guarding
      verify(databaseFunctions.refreshAccessToken("refreshToken")).called(1);
    });

    test('Refresh Token Method - Exponential backoff timing', () async {
      final stopwatch = Stopwatch()..start();

      when(databaseFunctions.refreshAccessToken("refreshToken"))
          .thenThrow(Exception('Network error'));

      bool exceptionCaught = false;
      try {
        await sessionManager.refreshSession();
      } catch (e) {
        exceptionCaught = true;
      }

      stopwatch.stop();

      expect(exceptionCaught, isTrue,
          reason: 'Exception should have been caught');
      // Should have waited at least 100ms + 200ms = 300ms for backoff
      // (allowing some tolerance for test execution time)
      expect(stopwatch.elapsedMilliseconds, greaterThan(250));
    });

    test('Clear tokens on unrecoverable error', () async {
      userConfig.currentUser = User(
        id: "99",
        name: 'Harry',
        refreshToken: 'refreshToken',
        authToken: 'authToken',
      );

      when(databaseFunctions.refreshAccessToken("refreshToken"))
          .thenThrow(Exception('Unrecoverable error'));

      bool exceptionCaught = false;
      try {
        await sessionManager.refreshSession();
      } catch (e) {
        exceptionCaught = true;
        expect(e.toString(), contains('Unrecoverable error'));
      }

      expect(exceptionCaught, isTrue,
          reason: 'Exception should have been caught');
      // Tokens should be cleared
      expect(userConfig.currentUser.refreshToken, isNull);
      expect(userConfig.currentUser.authToken, isNull);
    });
  });
}
