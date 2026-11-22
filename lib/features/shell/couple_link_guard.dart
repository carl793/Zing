import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/couple_model.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pixel_snack_bar.dart';

/// Sends this account back to pairing once its couple is unlinked, whether
/// from Settings on this phone or from the partner's phone.
///
/// Rules only let an account write its own profile, so when the partner
/// unlinks, this account's link is cleared here.
class CoupleLinkGuard extends StatefulWidget {
  final Widget child;
  const CoupleLinkGuard({super.key, required this.child});

  @override
  State<CoupleLinkGuard> createState() => _CoupleLinkGuardState();
}

class _CoupleLinkGuardState extends State<CoupleLinkGuard> {
  late final FirestoreService _fs = context.read<FirestoreService>();
  late final String _uid = context.read<AuthService>().currentUser!.uid;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _coupleSub;
  String? _coupleId;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _profileSub =
        _fs.streamDoc('users/$_uid').listen(_onProfile, onError: _logError);
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _coupleSub?.cancel();
    super.dispose();
  }

  void _onProfile(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (!snap.exists || data == null) return;
    final coupleId = data['coupleId'] as String?;
    if (coupleId == null || coupleId.isEmpty) {
      _leave(partnerUnlinked: false);
      return;
    }
    if (coupleId == _coupleId) return;
    _coupleId = coupleId;
    _coupleSub?.cancel();
    _coupleSub = _fs.streamDoc('couples/$coupleId').listen((couple) {
      final data = couple.data();
      if (data == null || data['status'] != CoupleStatus.unlinked.name) return;
      _leave(partnerUnlinked: data['unlinkedByUid'] != _uid);
    }, onError: _logError);
  }

  Future<void> _leave({required bool partnerUnlinked}) async {
    if (_leaving || !mounted) return;
    _leaving = true;
    if (partnerUnlinked) {
      showPixelSnackBar(
        context,
        'YOUR PARTNER UNLINKED THE ROOM.',
        color: AppColors.coral,
      );
      try {
        await _fs.claimCoupleId(uid: _uid, coupleId: null);
      } catch (e) {
        // recoverCoupleId clears it at the next launch instead.
        debugPrint('Clearing the unlinked couple failed: $e');
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.pairing, (_) => false);
  }

  void _logError(Object error) => debugPrint('Couple link guard: $error');

  @override
  Widget build(BuildContext context) => widget.child;
}
