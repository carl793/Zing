import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pixel_toast.dart';
import 'permission_sheets.dart';

/// Explains, asks for location, and handles every way it can be refused. True
/// only when Zing may read the position now.
Future<bool> ensureLocationAccess(
  BuildContext context,
  LocationService location,
) async {
  var access = await location.access();
  if (access == LocationAccess.denied) {
    if (!context.mounted) return false;
    if (!await showPermissionPrimer(context, PermissionKind.location)) {
      return false;
    }
    access = await location.access(request: true);
  }
  if (access == LocationAccess.granted) return true;
  if (!context.mounted) return false;

  switch (access) {
    case LocationAccess.serviceOff:
      final open = await showPermissionBlocked(
        context,
        PermissionKind.location,
        title: "PHONE LOCATION IS OFF",
        how: "Turn on your phone's location, then come back to Zing.",
      );
      if (open) await location.openLocationSettings();
    case LocationAccess.blocked:
      if (await showPermissionBlocked(context, PermissionKind.location)) {
        await location.openAppSettings();
      }
    case LocationAccess.denied:
      showPixelToast(context, 'NO PROBLEM. YOUR HOME CITY IS USED INSTEAD.');
    case LocationAccess.granted:
      break;
  }
  return false;
}

/// Explains and asks for the microphone. [hasPermission] checks it, showing
/// the system prompt when asked to request it.
Future<bool> ensureMicrophoneAccess(
  BuildContext context, {
  required Future<bool> Function({required bool request}) hasPermission,
  required LocationService settings,
}) async {
  if (await hasPermission(request: false)) return true;
  if (!context.mounted) return false;
  if (!await showPermissionPrimer(context, PermissionKind.microphone)) {
    return false;
  }
  if (await hasPermission(request: true)) return true;
  if (!context.mounted) return false;
  if (await showPermissionBlocked(context, PermissionKind.microphone)) {
    await settings.openAppSettings();
  }
  return false;
}

const _photosExplained = 'explained_photos';
const _quality = 70;
const double _maxWidth = 1600;

/// Lets the user pick up to [limit] photos, explaining it the first time. Empty
/// when they cancel, or when it fails (which is reported).
Future<List<Uint8List>> pickPhotos(
  BuildContext context, {
  required LocationService settings,
  int limit = 1,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool(_photosExplained) ?? false)) {
    if (!context.mounted) return const [];
    if (!await showPermissionPrimer(context, PermissionKind.photos)) {
      return const [];
    }
    await prefs.setBool(_photosExplained, true);
  }
  try {
    final files = limit > 1
        ? await ImagePicker().pickMultiImage(
            imageQuality: _quality,
            maxWidth: _maxWidth,
            limit: limit,
          )
        : [
            ?await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: _quality,
              maxWidth: _maxWidth,
            ),
          ];
    // Some galleries ignore the limit.
    if (files.length > limit && context.mounted) {
      showPixelToast(
        context,
        'ONLY THE FIRST $limit FIT.',
        color: AppColors.amber,
      );
    }
    return [for (final file in files.take(limit)) await file.readAsBytes()];
  } on PlatformException catch (e) {
    debugPrint('Picking photos failed: ${e.code} ${e.message}');
    // A second tap while the gallery is already opening.
    if (e.code == 'already_active' || !context.mounted) return const [];
    if (e.code.contains('denied')) {
      if (await showPermissionBlocked(context, PermissionKind.photos)) {
        await settings.openAppSettings();
      }
      return const [];
    }
  } catch (e) {
    debugPrint('Picking photos failed: $e');
  }
  if (context.mounted) {
    showPixelToast(
      context,
      "COULDN'T OPEN THAT PHOTO. TRY ANOTHER ONE.",
      color: AppColors.coral,
    );
  }
  return const [];
}
