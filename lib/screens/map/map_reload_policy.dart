import 'dart:ui';

enum MapReloadReason {
  none,
  initial,
  apiZoomChanged,
  viewportMoved,
  stale,
  appResumed,
  manual,
}

class MapReloadPolicy {
  const MapReloadPolicy._();

  static const double viewportMovementFraction = 0.30;
  static const Duration freshnessInterval = Duration(seconds: 30);
  static const Duration failureRetryInterval = Duration(seconds: 15);
  static const Duration cameraDebounce = Duration(milliseconds: 300);

  static double movementThresholdMeters({
    required Size viewportSize,
    required double meterPerDp,
  }) {
    final shortestSide = viewportSize.shortestSide;
    return shortestSide * meterPerDp * viewportMovementFraction;
  }

  static MapReloadReason spatialReason({
    required bool initialized,
    required int currentApiZoom,
    required int lastApiZoom,
    required double movedMeters,
    required double movementThresholdMeters,
  }) {
    if (!initialized) return MapReloadReason.initial;
    if (currentApiZoom != lastApiZoom) {
      return MapReloadReason.apiZoomChanged;
    }
    if (movedMeters >= movementThresholdMeters) {
      return MapReloadReason.viewportMoved;
    }
    return MapReloadReason.none;
  }

  static bool isFreshnessDue({
    required DateTime? lastSuccessfulAt,
    required DateTime now,
  }) {
    if (lastSuccessfulAt == null) return true;
    return now.difference(lastSuccessfulAt) >= freshnessInterval;
  }

  static bool canAutoRefresh({
    required bool isAppResumed,
    required bool isMapTabActive,
    required bool isInteractionOpen,
    required bool isLoading,
  }) => isAppResumed && isMapTabActive && !isInteractionOpen && !isLoading;
}
