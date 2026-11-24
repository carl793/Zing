import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/models/room_model.dart';
import '../../../core/utils/safe_notifier.dart';
import '../../../data/repositories/pairing_repository.dart';
import '../../../data/repositories/user_repository.dart';

enum PairingTab { create, join }

enum CreateState { idle, loading, waiting }

enum JoinError { none, notFound, expired, alreadyLinked, selfJoin, network }

class PairingController extends SafeNotifier {
  final PairingRepository _pairing;
  final UserRepository _users;
  final String currentUid;

  PairingController(this._pairing, this._users, {required this.currentUid});

  // --- Tab ---
  PairingTab tab = PairingTab.create;

  void switchTab(PairingTab t) {
    tab = t;
    joinError = JoinError.none;
    notifyListeners();
  }

  // --- Create Room state ---
  CreateState createState = CreateState.idle;
  String? generatedCode;
  StreamSubscription<RoomModel?>? _roomSub;
  Duration _remaining = const Duration(hours: 24);
  Timer? _countdownTimer;
  bool linked = false;

  Future<void> generateCode() async {
    createState = CreateState.loading;
    notifyListeners();
    try {
      createFailed = false;
      generatedCode = await _pairing.createRoom(currentUid);
      createState = CreateState.waiting;
      _startCountdown();
      _listenForPartner();
      notifyListeners();
    } catch (e) {
      debugPrint('Creating a room failed: $e');
      createFailed = true;
      createState = CreateState.idle;
      notifyListeners();
    }
  }

  /// True when the last attempt to create a code failed.
  bool createFailed = false;

  void _startCountdown() {
    _remaining = PairingRepository.codeLifetime;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds <= 0) {
        _countdownTimer?.cancel();
      } else {
        _remaining -= const Duration(seconds: 1);
        notifyListeners();
      }
    });
  }

  String get countdownDisplay {
    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _listenForPartner() {
    _roomSub?.cancel();
    _roomSub = _pairing.watchRoom(generatedCode!).listen((room) async {
      if (room?.status != RoomStatus.linked || linked || _claiming) return;
      _claiming = true;
      _countdownTimer?.cancel();
      // Finish claiming before moving on: the next screens read the
      // partner's profile, which the rules only allow once this account's
      // own profile points at the couple.
      await _claimCouple(room!.coupleId);
      _claiming = false;
      linked = true;
      notifyListeners();
    }, onError: (Object e) => debugPrint('Room stream error: $e'));
  }

  bool _claiming = false;

  /// Writes the room's couple id to this account's own document. Joining never
  /// touches the creator's document, so the creator claims it here instead.
  Future<void> _claimCouple(String? coupleId) async {
    if (coupleId == null || coupleId.isEmpty) return;
    try {
      await _users.setCoupleId(currentUid, coupleId);
    } catch (e) {
      debugPrint('claimCoupleId failed: $e');
    }
  }

  Future<void> regenerateCode() async {
    await cancelRoom();
    await generateCode();
  }

  Future<void> cancelRoom() async {
    final code = generatedCode;
    _roomSub?.cancel();
    if (code != null) {
      try {
        await _pairing.cancelRoom(code);
      } catch (e) {
        // It expires on its own; don't trap the player on this code.
        debugPrint('Cancelling the room failed: $e');
      }
    }
    _countdownTimer?.cancel();
    generatedCode = null;
    createState = CreateState.idle;
    notifyListeners();
  }

  /// Copies the code to the clipboard. False when there is nothing to copy.
  bool copyCode() {
    final code = generatedCode;
    if (code == null) return false;
    Clipboard.setData(ClipboardData(text: code));
    return true;
  }

  // --- Join Room state ---
  bool joinLoading = false;
  JoinError joinError = JoinError.none;
  bool joinSuccess = false;

  Future<void> joinRoom(String rawCode) async {
    final code = rawCode.replaceAll('-', '').trim();
    if (code.isEmpty) return;

    joinLoading = true;
    joinError = JoinError.none;
    notifyListeners();

    final result =
        await _pairing.joinRoom(code: code, joinerUid: currentUid);

    joinLoading = false;
    switch (result) {
      case JoinRoomResult.success:
        linked = true;
        break;
      case JoinRoomResult.notFound:
        joinError = JoinError.notFound;
        break;
      case JoinRoomResult.expired:
        joinError = JoinError.expired;
        break;
      case JoinRoomResult.alreadyLinked:
        joinError = JoinError.alreadyLinked;
        break;
      case JoinRoomResult.selfJoin:
        joinError = JoinError.selfJoin;
        break;
      case JoinRoomResult.error:
        joinError = JoinError.network;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}