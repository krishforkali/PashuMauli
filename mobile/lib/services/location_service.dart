import 'package:geolocator/geolocator.dart';

/// Location permission states
enum LocationPermissionState {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unknown,
}

/// Location result — position or error state.
sealed class LocationResult {
  const LocationResult();
}

class LocationSuccess extends LocationResult {
  final double latitude;
  final double longitude;
  final double? accuracy;
  const LocationSuccess(
      {required this.latitude, required this.longitude, this.accuracy});
}

class LocationFailure extends LocationResult {
  final LocationPermissionState state;
  final String message;
  const LocationFailure({required this.state, required this.message});
}

/// Location service abstraction.
/// Records can exist without GPS when permission is unavailable — OFFLINE_SYNC.md rule.
/// Never generates fake coordinates.
class LocationService {
  /// Request permission and get current position.
  /// Returns null if permission is denied or service is disabled.
  Future<LocationResult> getCurrentLocation() async {
    // Check if service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationFailure(
        state: LocationPermissionState.serviceDisabled,
        message: 'Location services are disabled on this device',
      );
    }

    // Check current permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationFailure(
          state: LocationPermissionState.denied,
          message: 'Location permission denied',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationFailure(
        state: LocationPermissionState.deniedForever,
        message: 'Location permission permanently denied. Enable in settings.',
      );
    }

    // Permission granted — get position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationSuccess(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (e) {
      return LocationFailure(
        state: LocationPermissionState.unknown,
        message: 'Failed to get location: $e',
      );
    }
  }

  /// Check permission state without requesting.
  Future<LocationPermissionState> checkPermissionState() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionState.serviceDisabled;

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionState.granted;
      case LocationPermission.denied:
        return LocationPermissionState.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionState.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionState.unknown;
    }
  }

  /// Open device location settings.
  Future<bool> openSettings() => Geolocator.openLocationSettings();
}
