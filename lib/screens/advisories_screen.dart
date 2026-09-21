import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';

import '../models/advisory.dart';
import '../providers/advisory_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_palette.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';

/// Maps the advisory severity onto the design-system semantic tones.
StatusTone _severityTone(Advisory advisory) {
  switch (advisory.severity) {
    case 'critical':
      return StatusTone.danger;
    case 'warning':
      return StatusTone.warning;
    default:
      return StatusTone.info;
  }
}

class AdvisoriesScreen extends StatefulWidget {
  const AdvisoriesScreen({super.key});

  static const String routeName = '/advisories';

  @override
  State<AdvisoriesScreen> createState() => _AdvisoriesScreenState();
}

class _AdvisoriesScreenState extends State<AdvisoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdvisoryProvider>().fetchAdvisories();
      }
    });
  }

  void _openAdvisoryDetail(Advisory advisory) {
    // 1. Instantly mark as read locally and dispatch API sync via provider
    if (!advisory.isRead) {
      context.read<AdvisoryProvider>().markAsRead(advisory);
    }

    // 2. Open full details view
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdvisoryDetailScreen(advisory: advisory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final advisoryProvider = context.watch<AdvisoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.of(context).canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<AdvisoryProvider>().fetchAdvisories(showLoading: false),
          color: AppColors.of(context).accent,
          child: _buildBody(advisoryProvider),
        ),
      ),
    );
  }

  Widget _buildBody(AdvisoryProvider provider) {
    if (provider.isLoading && provider.advisories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(AppPalette.space24, AppPalette.space20,
            AppPalette.space24, 0),
        child: AppSkeletonList(),
      );
    }

    if (provider.errorMessage != null && provider.advisories.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: AppPalette.space40),
          AppEmptyState(
            icon: Icons.wifi_off_rounded,
            tone: AppPalette.danger,
            title: 'Cannot reach the port',
            caption: provider.errorMessage!,
            actionLabel: 'Try again',
            onAction: () => context.read<AdvisoryProvider>().fetchAdvisories(),
          ),
        ],
      );
    }

    final advisories = provider.advisories;

    if (advisories.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppPalette.space24,
            AppPalette.space20, AppPalette.space24, AppPalette.space32),
        children: [
          _buildHeader(0),
          const SizedBox(height: AppPalette.space32),
          AppEmptyState(
            icon: Icons.campaign_outlined,
            title: 'No active advisories',
            caption:
                'Port operations and schedules are running normally. Fair seas ahead.',
            actionLabel: 'Refresh',
            onAction: () => context.read<AdvisoryProvider>().fetchAdvisories(),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppPalette.space24,
          AppPalette.space20, AppPalette.space24, AppPalette.space32),
      itemCount: advisories.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(advisories.length);
        }
        final advisoryIndex = index - 1;
        final advisory = advisories[advisoryIndex];
        return Dismissible(
          key: ValueKey('advisory_${advisory.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: AppPalette.space16),
            padding: const EdgeInsets.symmetric(horizontal: AppPalette.space20),
            decoration: BoxDecoration(
              color: AppPalette.danger,
              borderRadius: BorderRadius.circular(AppPalette.radiusLg),
            ),
            alignment: Alignment.centerRight,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Delete',
                  style: TextStyle(
                    color: AppPalette.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.delete_outline_rounded, color: AppPalette.white, size: 22),
              ],
            ),
          ),
          onDismissed: (_) {
            context.read<AdvisoryProvider>().deleteAdvisory(advisory);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Advisory deleted'),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Undo',
                  textColor: AppPalette.teal300,
                  onPressed: () {
                    context.read<AdvisoryProvider>().restoreAdvisory(advisory, advisoryIndex);
                  },
                ),
              ),
            );
          },
          child: _buildAdvisoryCard(advisory, advisoryIndex),
        );
      },
    );
  }

  Future<void> _confirmDeleteAdvisory(Advisory advisory, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete advisory'),
        content: const Text(
          'Are you sure you want to remove this notice? It will no longer appear on your page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.danger,
              foregroundColor: AppPalette.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<AdvisoryProvider>().deleteAdvisory(advisory);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Advisory deleted'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppPalette.teal300,
            onPressed: () {
              context.read<AdvisoryProvider>().restoreAdvisory(advisory, index);
            },
          ),
        ),
      );
    }
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all advisories'),
        content: const Text(
          'Are you sure you want to delete all travel advisories from your inbox?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.danger,
              foregroundColor: AppPalette.white,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AdvisoryProvider>().clearAllAdvisories();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All advisories cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildHeader(int count) {
    return SectionHeader(
      'Travel advisories',
      caption: 'Live notices, weather reports and maritime alerts.',
      action: count > 0
          ? IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, size: 22),
              tooltip: 'Clear all advisories',
              onPressed: () => _confirmClearAll(context),
            )
          : null,
    );
  }

  Widget _buildAdvisoryCard(Advisory advisory, int index) {
    final bool isUnread = !advisory.isRead;
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppPalette.space16),
      padding: const EdgeInsets.all(AppPalette.space20),
      onTap: () => _openAdvisoryDetail(advisory),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: severity chip + unread marker + delete action
          Row(
            children: [
              Flexible(
                child: StatusChip(
                  label: advisory.severityLabel,
                  tone: _severityTone(advisory),
                  icon: advisory.severityIcon,
                ),
              ),
              if (isUnread) ...[
                const SizedBox(width: AppPalette.space8),
                const StatusChip(label: 'New', tone: StatusTone.danger),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Delete notice',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _confirmDeleteAdvisory(advisory, index),
              ),
            ],
          ),
          const SizedBox(height: AppPalette.space12),

          // Title
          Text(
            advisory.title,
            style: isUnread
                ? text.titleLarge
                : text.titleLarge?.copyWith(color: colors.text2),
          ),
          const SizedBox(height: AppPalette.space8),

          // Affected route
          Row(
            children: [
              Icon(Icons.alt_route_rounded, size: 15, color: colors.text3),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  advisory.route,
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppPalette.space12),

          // Date and read-more affordance
          Row(
            children: [
              Expanded(
                child: Text(
                  advisory.formattedDate,
                  style: text.bodySmall?.copyWith(color: colors.text3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppPalette.space8),
              Text('View notice',
                  style: text.labelMedium?.copyWith(color: colors.accent)),
              Icon(Icons.chevron_right_rounded, size: 18, color: colors.accent),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dedicated Screen rendering the exact HTML template with email layout synchronization
class AdvisoryDetailScreen extends StatelessWidget {
  final Advisory advisory;

  const AdvisoryDetailScreen({super.key, required this.advisory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).canvas,
      appBar: AppBar(
        title: Text(advisory.severityLabel),
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
            tooltip: 'Delete notice',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete advisory'),
                  content: const Text(
                    'Are you sure you want to remove this notice? It will no longer appear on your page.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.danger,
                        foregroundColor: AppPalette.white,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                context.read<AdvisoryProvider>().deleteAdvisory(advisory);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Advisory deleted'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppPalette.space20,
              AppPalette.space16, AppPalette.space20, AppPalette.space32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusChipRow(advisory: advisory),
              const SizedBox(height: AppPalette.space16),
              // Rich Email-Matching HTML Container
              AppCard(
                padding: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: advisory.content.isNotEmpty
                    ? HtmlWidget(
                        advisory.content,
                        textStyle: Theme.of(context).textTheme.bodyMedium ??
                            const TextStyle(fontSize: 15, height: 1.5),
                      )
                    : _buildFallbackContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackContent(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppPalette.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(advisory.title, style: text.headlineMedium),
          const SizedBox(height: AppPalette.space8),
          Text(advisory.formattedDate,
              style: text.bodySmall?.copyWith(color: colors.text3)),
          const Divider(),
          Row(
            children: [
              Icon(Icons.alt_route_rounded, size: 15, color: colors.text3),
              const SizedBox(width: 6),
              Expanded(child: Text(advisory.route, style: text.bodyMedium)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Severity + publish date line above the advisory body.
class StatusChipRow extends StatelessWidget {
  const StatusChipRow({super.key, required this.advisory});
  final Advisory advisory;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        StatusChip(
          label: advisory.severityLabel,
          tone: _severityTone(advisory),
          icon: advisory.severityIcon,
        ),
        const SizedBox(width: AppPalette.space12),
        Expanded(
          child: Text(
            advisory.formattedDate,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.text3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
