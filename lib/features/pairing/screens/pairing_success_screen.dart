import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_page.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/router/app_router.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/sprite_options.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/sprite_avatar.dart';

class PairingSuccessScreen extends StatefulWidget {
  const PairingSuccessScreen({super.key});

  @override
  State<PairingSuccessScreen> createState() => _PairingSuccessScreenState();
}

class _PairingSuccessScreenState extends State<PairingSuccessScreen> {
  String _mySprite = SpriteOptions.fallback;
  String _partnerSprite = SpriteOptions.fallback;
  String _myName = '';
  String _partnerName = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AudioService.instance
      ..playSfx(AppSfx.unlock)
      ..knock(strong: true);
    _loadNames();
  }

  Future<void> _loadNames() async {
    final auth = context.read<AuthService>();
    final users = context.read<UserRepository>();
    final couples = context.read<CoupleRepository>();
    final uid = auth.currentUser!.uid;

    UserModel? me;
    UserModel? partner;
    try {
      me = await users.fetch(uid);
      final coupleId = me?.coupleId ?? '';
      final couple = coupleId.isEmpty ? null : await couples.fetch(coupleId);
      final partnerUid = couple?.partnerUid(uid) ?? '';
      if (partnerUid.isNotEmpty) partner = await users.fetch(partnerUid);
    } catch (e) {
      // The celebration still shows; only the names and sprites are missing.
      debugPrint('Loading the paired profiles failed: $e');
    }
    if (!mounted) return;
    final (loadedMe, loadedPartner) = (me, partner);
    setState(() {
      if (loadedMe != null) {
        _myName = loadedMe.displayName;
        if (loadedMe.avatarSpriteId.isNotEmpty) _mySprite = loadedMe.avatarSpriteId;
      }
      if (loadedPartner != null) {
        _partnerName = loadedPartner.displayName;
        if (loadedPartner.avatarSpriteId.isNotEmpty) {
          _partnerSprite = loadedPartner.avatarSpriteId;
        }
      }
      _loaded = true;
    });
  }

  // Blank until loaded, so the default sprite doesn't flash first.
  Widget _sprite(String spriteId, {bool offBeat = false}) => _loaded
      ? SpriteIdle(
          offBeat: offBeat,
          child: SpriteAvatar(spriteId: spriteId, size: 96),
        )
      : const SizedBox.square(dimension: 96);

  @override
  Widget build(BuildContext context) {
    final named = _loaded && _partnerName.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.night,
      body: PixelBackdrop(
        child: SafeArea(
          child: PixelColumn(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _sprite(_mySprite),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: PixelIcon(
                                  PixelIcons.heart,
                                  size: 36,
                                  color: AppColors.coral,
                                  shadow: true,
                                ),
                              ),
                              _sprite(_partnerSprite, offBeat: true),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "YOU'RE LINKED!",
                              style: AppTextStyles.display,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            named
                                ? '$_myName and $_partnerName are now in the '
                                    'same world.'
                                : 'You are now in the same world.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                PixelActionBar(
                  child: PixelButton(
                    label: 'ENTER THE OVERWORLD',
                    icon: PixelIcons.play,
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed(AppRoutes.shell),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
