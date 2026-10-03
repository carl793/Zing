import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/onboarding_progress_bar.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';

const kPresetSprites = ['🐇', '👻', '🦊', '🐍', '🦄', '🐢', '🌞', '🌡️'];

class SpriteSelectScreen extends StatefulWidget {
  const SpriteSelectScreen({super.key});
  @override
  State<SpriteSelectScreen> createState() => _SpriteSelectScreenState();
}

class _SpriteSelectScreenState extends State<SpriteSelectScreen> {
  int _selected = 0;
  final _name = TextEditingController();
  bool _saving = false;
  String? _googleEmail;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _name.text = user.displayName!.toUpperCase();
    }
    _googleEmail = user?.providerData.any((p) => p.providerId == 'google.com') == true
        ? user?.email
        : null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final authService = context.read<AuthService>();
    await authService.saveProfile(
      uid: authService.currentUser!.uid,
      displayName: name,
      avatarSpriteId: kPresetSprites[_selected],
    );
    if (!mounted) return;
    // pushReplacementNamed so back button cannot return here
    Navigator.of(context).pushReplacementNamed(AppRoutes.pairing);
  }

  @override
  Widget build(BuildContext context) {
    // PopScope blocks the system back button on this screen
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                const OnboardingProgressBar(currentStep: 2),
                const SizedBox(height: AppSpacing.xl),

                Text('CHOOSE YOUR\nHERO SPRITE',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.header.copyWith(
                      fontSize: 18, color: AppColors.cyan, height: 1.6,
                      shadows: [const Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)],
                    )),
                const SizedBox(height: AppSpacing.md),

                Text('PICK AN AVATAR TO REPRESENT\nYOU IN THE OVERWORLD.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(height: 1.8)),
                const SizedBox(height: AppSpacing.xl),

                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  children: List.generate(kPresetSprites.length, (i) {
                    final selected = i == _selected;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          border: Border.all(
                              color: selected ? AppColors.yellow : Colors.black,
                              width: selected ? 3 : 2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black,
                                offset: Offset(selected ? 3 : 2, selected ? 3 : 2),
                                blurRadius: 0)
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(kPresetSprites[i],
                            style: TextStyle(fontSize: selected ? 28 : 24)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.xl),

                Text('DISPLAY NAME', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(0, 3), blurRadius: 0)],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.characters,
                    style: AppTextStyles.body.copyWith(color: AppColors.yellow, fontSize: 9),
                    cursorColor: AppColors.cyan,
                    decoration: InputDecoration(
                      hintText: 'YOUR NAME..',
                      hintStyle: AppTextStyles.body.copyWith(color: const Color(0xFF555577), fontSize: 8),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                PixelButton(
                    label: _saving ? '...' : '[ CONTINUE ]',
                    onPressed: _saving ? null : _continue,
                    style: PixelButtonStyle.coral),

                if (_googleEmail != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('SIGNED IN AS $_googleEmail — VIA GOOGLE',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(color: Colors.white38)),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}