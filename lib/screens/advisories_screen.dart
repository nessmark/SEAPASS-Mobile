import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';

import '../models/advisory.dart';
import '../providers/advisory_provider.dart';
import '../widgets/app_palette.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<AdvisoryProvider>().fetchAdvisories(showLoading: false),
          color: AppPalette.mintGreen,
          child: _buildBody(advisoryProvider),
        ),
      ),
    );
  }

  Widget _buildBody(AdvisoryProvider provider) {
    if (provider.isLoading && provider.advisories.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppPalette.mintGreen),
        ),
      );
    }

    if (provider.errorMessage != null && provider.advisories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.read<AdvisoryProvider>().fetchAdvisories(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.mintGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final advisories = provider.advisories;

    if (advisories.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppPalette.mintGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    size: 48,
                    color: AppPalette.mintGreen,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Active Travel Advisories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.darkText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Port operations and schedules are currently normal.\nFair seas ahead! ⛵',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: advisories.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeaderBanner(advisories.length);
        }
        final advisoryIndex = index - 1;
        final advisory = advisories[advisoryIndex];
        return Dismissible(
          key: ValueKey('advisory_${advisory.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerRight,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
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
                  label: 'UNDO',
                  textColor: AppPalette.mintGreen,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Advisory'),
        content: const Text(
          'Are you sure you want to remove this notice? It will no longer appear on your page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            label: 'UNDO',
            textColor: AppPalette.mintGreen,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Advisories'),
        content: const Text(
          'Are you sure you want to delete all travel advisories from your inbox?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear All'),
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

  Widget _buildHeaderBanner(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppPalette.mintGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: AppPalette.mintGreen,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Port Travel Advisories',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Live notices, weather reports, and maritime alerts.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70, size: 22),
              tooltip: 'Clear All Advisories',
              onPressed: () => _confirmClearAll(context),
            ),
        ],
      ),
    );
  }

  Widget _buildAdvisoryCard(Advisory advisory, int index) {
    final bool isUnread = !advisory.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFFFFFFFF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnread
              ? AppPalette.mintGreen.withValues(alpha: 0.6)
              : Colors.grey.shade200,
          width: isUnread ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnread
                ? AppPalette.mintGreen.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openAdvisoryDetail(advisory),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Severity Badge + Unread Indicator + Delete Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: advisory.severityBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: advisory.severityColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(advisory.severityIcon, size: 13, color: advisory.severityColor),
                          const SizedBox(width: 5),
                          Text(
                            advisory.severityLabel.toUpperCase(),
                            style: TextStyle(
                              color: advisory.severityColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUnread) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Colors.grey.shade400,
                          ),
                          tooltip: 'Delete Notice',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _confirmDeleteAdvisory(advisory, index),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  advisory.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                    color: AppPalette.darkText,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Affected Route Badge
                Row(
                  children: [
                    Icon(Icons.alt_route_rounded, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        advisory.route,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Date and Read More Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      advisory.formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Row(
                      children: [
                        Text(
                          'View Full Notice',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.mintGreen,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppPalette.mintGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(
          advisory.severityLabel.toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
            tooltip: 'Delete Notice',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Delete Advisory'),
                  content: const Text(
                    'Are you sure you want to remove this notice? It will no longer appear on your page.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.grey.shade700)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rich Email-Matching HTML Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: advisory.content.isNotEmpty
                    ? HtmlWidget(
                        advisory.content,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontFamily: 'Roboto',
                        ),
                      )
                    : _buildFallbackContent(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            advisory.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppPalette.darkText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            advisory.formattedDate,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const Divider(height: 24),
          Text(
            'Route: ${advisory.route}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
