import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/utils/safe_notifier.dart';

enum VoiceStatus { idle, recording, recorded }

/// Records one voice note for a chest form. Owned by the form: closing it stops
/// the microphone and deletes the temporary file.
class VoiceRecorder extends SafeNotifier {
  static const maxLength = Duration(seconds: 60);

  final AudioRecorder _recorder = AudioRecorder();
  late final AppLifecycleListener _lifecycle;
  Timer? _ticker;
  bool _holdingMusic = false;

  VoiceStatus status = VoiceStatus.idle;
  Duration elapsed = Duration.zero;

  /// The recorded file, once [status] is recorded.
  String? path;

  VoiceRecorder() {
    // Never keep recording after the app leaves the screen.
    _lifecycle = AppLifecycleListener(onHide: () {
      if (status == VoiceStatus.recording) stop();
    });
  }

  Future<bool> hasPermission({required bool request}) async {
    try {
      return await _recorder.hasPermission(request: request);
    } catch (e) {
      debugPrint('Checking the microphone failed: $e');
      return false;
    }
  }

  /// Starts recording. False when the microphone couldn't be used.
  Future<bool> start() async {
    if (status == VoiceStatus.recording) return true;
    await discard();
    try {
      final dir = await getTemporaryDirectory();
      final file =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _holdMusic();
      await _recorder.start(
        // Plenty for speech, and a quarter of the default upload size.
        const RecordConfig(bitRate: 48000, sampleRate: 22050, numChannels: 1),
        path: file,
      );
      if (isDisposed) {
        await _shutDown();
        return false;
      }
      status = VoiceStatus.recording;
      elapsed = Duration.zero;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        elapsed += const Duration(seconds: 1);
        if (elapsed >= maxLength) {
          stop();
        } else {
          notifyListeners();
        }
      });
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Recording failed to start: $e');
      _releaseMusic();
      return false;
    }
  }

  bool _stopping = false;

  Future<void> stop() async {
    // The timer, a tap and leaving the app can all ask at once.
    if (status != VoiceStatus.recording || _stopping) return;
    _stopping = true;
    _ticker?.cancel();
    try {
      path = await _recorder.stop();
    } catch (e) {
      debugPrint('Recording failed to stop: $e');
      path = null;
    }
    _releaseMusic();
    _stopping = false;
    status = path == null ? VoiceStatus.idle : VoiceStatus.recorded;
    notifyListeners();
  }

  /// Throws the recording away.
  Future<void> discard() async {
    final file = path;
    path = null;
    elapsed = Duration.zero;
    status = VoiceStatus.idle;
    notifyListeners();
    if (file != null) await _delete(file);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle.dispose();
    super.dispose();
    _shutDown();
  }

  Future<void> _shutDown() async {
    var file = path;
    try {
      file = await _recorder.stop() ?? file;
    } catch (_) {
      // Nothing was recording.
    }
    _releaseMusic();
    if (file != null) await _delete(file);
    try {
      await _recorder.dispose();
    } catch (_) {
      // Already released.
    }
  }

  void _holdMusic() {
    if (_holdingMusic) return;
    _holdingMusic = true;
    AudioService.instance.holdMusic();
  }

  void _releaseMusic() {
    if (!_holdingMusic) return;
    _holdingMusic = false;
    AudioService.instance.releaseMusic();
  }

  static Future<void> _delete(String file) async {
    try {
      await File(file).delete();
    } catch (_) {
      // The system clears temporary files anyway.
    }
  }
}
