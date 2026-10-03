import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/room_model.dart';

enum PairingTab { create, join }

enum CreateState { idle, loading, waiting }

enum JoinError { none, notFound, expired, alreadyLinked, selfJoin, network }

class PairingController extends ChangeNotifier {
  final FirestoreService _fs;
  final String currentUid;

  PairingController(this._fs, {required this.currentUid});

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
  String? partnerDisplayName;

  Future<void> generateCode() async {
    createState = CreateState.loading;
    notifyListeners();
    try {
      generatedCode = await _fs.createRoom(currentUid);
      createState = CreateState.waiting;
      _startCountdown();
      _listenForPartner();
      notifyListeners();
    } catch (_) {
      createState = CreateState.idle;
      notifyListeners();
    }
  }

  void _startCountdown() {
    _remaining = const Duration(hours: 24);
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
    _roomSub = _fs.streamRoom(generatedCode!).listen((room) {
      if (room?.status == RoomStatus.linked) {
        linked = true;
        _countdownTimer?.cancel();
        notifyListeners();
      }
    });
  }

  Future<void> regenerateCode() async {
    await cancelRoom();
    await generateCode();
  }

  Future<void> cancelRoom() async {
    if (generatedCode != null) await _fs.cancelRoom(generatedCode!);
    _roomSub?.cancel();
    _countdownTimer?.cancel();
    generatedCode = null;
    createState = CreateState.idle;
    notifyListeners();
  }

  void copyCode(BuildContext context) {
    if (generatedCode == null) return;
    Clipboard.setData(ClipboardData(text: generatedCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2D2B55),
        content: Text('CODE COPIED!',
            style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: Color(0xFFFFE600))),
        duration: const Duration(seconds: 2),
      ),
    );
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

    final result = await _fs.joinRoom(code: code, joinerUid: currentUid);

    joinLoading = false;
    switch (result) {
      case JoinRoomResult.success:
        linked = true;
      case JoinRoomResult.notFound:
        joinError = JoinError.notFound;
      case JoinRoomResult.expired:
        joinError = JoinError.expired;
      case JoinRoomResult.alreadyLinked:
        joinError = JoinError.alreadyLinked;
      case JoinRoomResult.selfJoin:
        joinError = JoinError.selfJoin;
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