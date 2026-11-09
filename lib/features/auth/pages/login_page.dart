import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/try_demo_button.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/language.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../widgets/login_form.dart';

/// Gradient welcome header with the app's name, and the sign-in form
/// in a card that overlaps it.
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final language = ref.watch(languageProvider);
    // The other language, offered at the top (before sign-in, Settings
    // can't be reached).
    final other = language == AppLanguage.ar ? AppLanguage.en : AppLanguage.ar;

    return Scaffold(
      // The gradient header goes behind the language button.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(languageProvider.notifier).set(other),
            icon: const Icon(Icons.language, size: 18),
            label: Text(other.nativeName),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ---------- Header ----------
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                MediaQuery.paddingOf(context).top + AppSpacing.xxxl,
                AppSpacing.xl,
                AppSpacing.xxxl + AppSpacing.xxl,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette.hero,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.xl * 2),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: const Icon(
                      Icons.auto_stories_outlined,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.appName,
                    style: context.text.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.tagline,
                    style: context.text.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // ---------- Form card, pulled up over the header ----------
            Transform.translate(
              offset: const Offset(0, -AppSpacing.xxxl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            tr('Welcome back'),
                            style: context.text.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: AppSizes.iconSm,
                                color: palette.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  tr('Use the ID your school gave you.'),
                                  style: context.text.bodySmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const LoginForm(),
                          const TryDemoButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
