import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/menu_group.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../data/faq_data.dart';
import '../../../core/l10n/language.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  /// The Student Affairs chat in the mock data.
  static const _supportConversationId = 'c5';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Help and support'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          SectionHeader(title: tr('Common questions')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final faq in FaqData.items)
                  Theme(
                    // Removes ExpansionTile's default top/bottom lines.
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(faq.question, style: context.text.titleSmall),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      expandedAlignment: AlignmentDirectional.centerStart
                          .resolve(Directionality.of(context)),
                      children: [
                        Text(faq.answer, style: context.text.bodyMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          MenuGroup(
            title: tr('Still need help?'),
            children: [
              MenuTile(
                icon: Icons.chat_bubble_outline,
                iconColor: AppColors.subjectPurple,
                title: tr('Message Student Affairs'),
                subtitle: tr('Usually replies within a school day'),
                onTap: () =>
                    context.push(AppRoutes.chat(_supportConversationId)),
              ),
              MenuTile(
                icon: Icons.phone_outlined,
                iconColor: AppColors.success,
                title: tr('Call the school office'),
                subtitle: tr('Sun – Thu, 7:30 am – 2:30 pm'),
                onTap: () =>
                    context.showMessage(tr('Calling the school office…')),
              ),
              MenuTile(
                icon: Icons.mail_outline,
                iconColor: AppColors.info,
                title: tr('Email support'),
                subtitle: tr('support@school.edu'),
                onTap: () => context.showMessage(tr('Opening email…')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
