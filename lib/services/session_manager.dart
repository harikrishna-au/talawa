import 'dart:async';
import 'dart:developer' as developer;

import 'package:talawa/locator.dart';

/// Manages user sessions and periodically refreshes access tokens.
class SessionManager {
  SessionManager() {
    initializeSessionRefresher();
  }

  /// Flag to prevent concurrent token refresh attempts.
  bool _refreshInProgress = false;

  /// Completer to handle multiple concurrent refresh requests.
  Completer<bool>? _refreshCompleter;

  /// returns refresh interval of Session Manager.
  int get refreshInterval => _refreshInterval;

  /// refresh interval in seconds.
  static const int _refreshInterval = 600;

  /// Initializes as session refresher.
  ///
  /// Invokes [refreshSession] periodically at regular
  /// refresh intervals.
  ///
  /// **params**:
  ///   None
  ///
  /// **returns**:
  /// * `Timer`: refresh timer.
  Timer initializeSessionRefresher() {
    return Timer.periodic(
      const Duration(seconds: _refreshInterval),
      (Timer timer) {
        refreshSession();
      },
    );
  }

  /// Asynchronously refreshes the user session.
  ///
  /// **params**:
  ///   None
  ///
  /// **returns**:
  /// * `Future<bool>`: indicates if session refresh was
  /// successful.
  Future<bool> refreshSession() async {
    if (!userConfig.loggedIn || userConfig.currentUser.refreshToken == null) {
      return false;
    }

    // Use retry logic with exponential backoff as specified in issue #3111
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final success = await _refreshToken();
        if (success) {
          return true;
        }
      } catch (e) {
        developer.log('Token refresh attempt ${attempt + 1} failed: $e');

        // Apply exponential backoff delay before next attempt
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 100 * (1 << attempt)));
        } else {
          // Final attempt failed, clear tokens and rethrow
          await _clearTokens();
          rethrow;
        }
      }
    }

    return false;
  }

  /// Refreshes the user session with concurrency protection.
  ///
  /// **params**:
  ///   None
  ///
  /// **returns**:
  /// * `Future<bool>`: indicates if session refresh was
  /// successful.
  Future<bool> refreshSessionWithGuard() async {
    if (!userConfig.loggedIn || userConfig.currentUser.refreshToken == null) {
      return false;
    }

    return await _refreshTokenGuarded();
  }

  /// Guards the refresh token operation to prevent concurrent attempts.
  ///
  /// **params**:
  ///   None
  ///
  /// **returns**:
  /// * `Future<bool>`: indicates if token refresh was successful.
  Future<bool> _refreshTokenGuarded() async {
    // If refresh is already in progress, wait for it to complete
    if (_refreshInProgress && _refreshCompleter != null) {
      try {
        return await _refreshCompleter!.future;
      } catch (e) {
        // If the previous refresh failed, we'll start a new one
        _refreshInProgress = false;
        _refreshCompleter = null;
      }
    }

    // Start a new refresh operation
    _refreshInProgress = true;
    _refreshCompleter = Completer<bool>();

    try {
      final success = await _refreshToken();
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(success);
      }
      return success;
    } catch (e) {
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.completeError(e);
      }
      rethrow;
    } finally {
      _refreshInProgress = false;
      _refreshCompleter = null;
    }
  }

  /// Performs the actual token refresh operation.
  ///
  /// **params**:
  ///   None
  ///
  /// **returns**:
  /// * `Future<bool>`: indicates if token refresh was successful.
  Future<bool> _refreshToken() async {
    final refreshToken = userConfig.currentUser.refreshToken;
    if (refreshToken == null) {
      throw Exception('Refresh token is null');
    }

    final refreshed = await databaseFunctions.refreshAccessToken(refreshToken);
    return refreshed;
  }

  /// Clears stored tokens on unrecoverable errors.
  ///
  /// **params**:
  ///   None
  ///
  /// **returns**:
  /// * `Future<void>`: completes when tokens are cleared.
  Future<void> _clearTokens() async {
    try {
      // Clear the user's tokens
      userConfig.currentUser.refreshToken = null;
      userConfig.currentUser.authToken = null;

      developer.log('Tokens cleared due to unrecoverable refresh error');
    } catch (e) {
      developer.log('Error clearing tokens: $e');
    }
  }
}
