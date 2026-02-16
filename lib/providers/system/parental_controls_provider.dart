/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/database/adapters/time_of_day_adapter.dart';
import 'package:mindful/core/database/app_database.dart';
import 'package:mindful/core/services/drift_db_service.dart';
import 'package:mindful/core/services/method_channel_service.dart';
import 'package:mindful/core/utils/default_models_utils.dart';

/// A Riverpod state notifier provider that manages [ParentalControls]
final parentalControlsProvider =
    StateNotifierProvider<ParentalControlsNotifier, ParentalControls>(
  (ref) => ParentalControlsNotifier(),
);

class ParentalControlsNotifier extends StateNotifier<ParentalControls> {
  ParentalControlsNotifier() : super(defaultParentalControlsModel) {
    init();
  }

  /// Initializes the settings state by loading from the database and setting up a listener for saving changes.
  Future<ParentalControls> init() async {
    final dao = DriftDbService.instance.driftDb.uniqueRecordsDao;
    state = await dao.loadParentalControls();

    /// Listen to provider and save changes to Isar database
    addListener(
      fireImmediately: false,
      (state) => dao.saveParentalControls(state),
    );

    /// If invincible mode is already enabled (e.g. app restart / upgrade),
    /// ensure we have anchors + timezone to prevent wall-clock bypass.
    if (state.isInvincibleModeOn) {
      await ensureInvincibleWindowAnchors(force: false);
    }

    return state;
  }

  /// Switch protected access
  void switchProtectedAccess() =>
      state = state.copyWith(protectedAccess: !state.protectedAccess);

  /// Sets the timezone ID used to evaluate the uninstall window.
  void setUninstallWindowTimeZoneId(String tzId) =>
      state = state.copyWith(uninstallWindowTimeZoneId: tzId);

  /// Changes the time of day when uninstall widow starts for 5 minutes.
  void changeUninstallWindowTime(TimeOfDayAdapter time) =>
      state = state.copyWith(uninstallWindowTime: time);

  /// Ensures timezone + anchors exist for uninstall window checks.
  ///
  /// Anchors are used to derive a "trusted now" from monotonic time so users
  /// can't bypass by changing system wall clock.
  Future<void> ensureUninstallWindowAnchors({bool force = false}) async {
    final tz = state.uninstallWindowTimeZoneId.isNotEmpty
        ? state.uninstallWindowTimeZoneId
        : await MethodChannelService.instance.getSystemTimeZoneId();

    final shouldSetTz = state.uninstallWindowTimeZoneId.isEmpty;
    final shouldSetAnchors = force ||
        state.uninstallAnchorEpochMs <= 0 ||
        state.uninstallAnchorElapsedMs <= 0;

    if (!shouldSetTz && !shouldSetAnchors) return;

    final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
    final nowElapsedMs = await MethodChannelService.instance.getElapsedRealtimeMs();

    state = state.copyWith(
      uninstallWindowTimeZoneId: shouldSetTz ? tz : state.uninstallWindowTimeZoneId,
      uninstallAnchorEpochMs:
          shouldSetAnchors ? nowEpochMs : state.uninstallAnchorEpochMs,
      uninstallAnchorElapsedMs:
          shouldSetAnchors ? nowElapsedMs : state.uninstallAnchorElapsedMs,
    );
  }

  /// Sets the timezone ID used to evaluate the invincible window.
  void setInvincibleWindowTimeZoneId(String tzId) =>
      state = state.copyWith(invincibleWindowTimeZoneId: tzId);

  /// Changes the time of day when invincible widow starts for 5 minutes.
  void changeInvincibleWindowTime(TimeOfDayAdapter time) =>
      state = state.copyWith(invincibleWindowTime: time);

  /// Ensures timezone + anchors exist for invincible window checks.
  Future<void> ensureInvincibleWindowAnchors({bool force = false}) async {
    final tz = state.invincibleWindowTimeZoneId.isNotEmpty
        ? state.invincibleWindowTimeZoneId
        : await MethodChannelService.instance.getSystemTimeZoneId();

    final shouldSetTz = state.invincibleWindowTimeZoneId.isEmpty;
    final shouldSetAnchors = force ||
        state.invincibleAnchorEpochMs <= 0 ||
        state.invincibleAnchorElapsedMs <= 0;

    if (!shouldSetTz && !shouldSetAnchors) return;

    final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
    final nowElapsedMs = await MethodChannelService.instance.getElapsedRealtimeMs();

    state = state.copyWith(
      invincibleWindowTimeZoneId:
          shouldSetTz ? tz : state.invincibleWindowTimeZoneId,
      invincibleAnchorEpochMs:
          shouldSetAnchors ? nowEpochMs : state.invincibleAnchorEpochMs,
      invincibleAnchorElapsedMs:
          shouldSetAnchors ? nowElapsedMs : state.invincibleAnchorElapsedMs,
    );
  }

  /// Enables invincible mode and (re-)anchors trusted time.
  Future<void> enableInvincibleMode() async {
    await ensureInvincibleWindowAnchors(force: true);
    state = state.copyWith(isInvincibleModeOn: true);
  }

  /// Disables invincible mode and clears anchors.
  Future<void> disableInvincibleMode() async {
    state = state.copyWith(
      isInvincibleModeOn: false,
      invincibleAnchorEpochMs: 0,
      invincibleAnchorElapsedMs: 0,
    );
  }

  void toggleIncludeAppsTimer() =>
      state = state.copyWith(includeAppsTimer: !state.includeAppsTimer);

  void toggleIncludeAppsLaunchLimit() => state =
      state.copyWith(includeAppsLaunchLimit: !state.includeAppsLaunchLimit);

  void toggleIncludeAppsActivePeriod() => state =
      state.copyWith(includeAppsActivePeriod: !state.includeAppsActivePeriod);

  void toggleIncludeGroupsTimer() =>
      state = state.copyWith(includeGroupsTimer: !state.includeGroupsTimer);

  void toggleIncludeGroupsActivePeriod() => state = state.copyWith(
      includeGroupsActivePeriod: !state.includeGroupsActivePeriod);

  void toggleIncludeShortsTimer() =>
      state = state.copyWith(includeShortsTimer: !state.includeShortsTimer);

  void toggleIncludeBedtimeSchedule() => state =
      state.copyWith(includeBedtimeSchedule: !state.includeBedtimeSchedule);
}
