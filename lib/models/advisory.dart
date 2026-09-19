import 'package:flutter/material.dart';

class Advisory {
  final int id;
  final String title;
  final String content;
  final String severity; // 'critical', 'warning', 'info'
  final String type;
  final String route;
  final String? effectiveFrom;
  final String? until;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  bool isRead;

  Advisory({
    required this.id,
    required this.title,
    required this.content,
    required this.severity,
    this.type = 'General Advisory',
    this.route = 'All Routes',
    this.effectiveFrom,
    this.until,
    this.publishedAt,
    this.createdAt,
    this.isRead = false,
  });

  factory Advisory.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    final rawSeverity = (json['severity'] ?? 'info').toString().toLowerCase();
    String normalizedSeverity = 'info';
    if (rawSeverity.contains('crit') || rawSeverity.contains('danger')) {
      normalizedSeverity = 'critical';
    } else if (rawSeverity.contains('warn') || rawSeverity.contains('adv')) {
      normalizedSeverity = 'warning';
    }

    return Advisory(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? 'Travel Advisory',
      content: json['content'] ?? '',
      severity: normalizedSeverity,
      type: json['type'] ?? 'General Advisory',
      route: json['route'] ?? json['affected_route'] ?? 'All Routes',
      effectiveFrom: json['effective_from']?.toString(),
      until: json['until']?.toString(),
      publishedAt: parseDate(json['published_at']),
      createdAt: parseDate(json['created_at']),
      isRead: json['is_read'] == true || json['is_read'] == 1,
    );
  }

  Color get severityColor {
    switch (severity) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'warning':
        return const Color(0xFFD97706);
      case 'info':
      default:
        return const Color(0xFF0284C7);
    }
  }

  Color get severityBgColor {
    switch (severity) {
      case 'critical':
        return const Color(0xFFFEF2F2);
      case 'warning':
        return const Color(0xFFFFFBEB);
      case 'info':
      default:
        return const Color(0xFFF0F9FF);
    }
  }

  String get severityLabel {
    switch (severity) {
      case 'critical':
        return 'Critical';
      case 'warning':
        return 'Warning';
      case 'info':
      default:
        return 'Notice';
    }
  }

  IconData get severityIcon {
    switch (severity) {
      case 'critical':
        return Icons.error_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'info':
      default:
        return Icons.info_outline_rounded;
    }
  }

  String get formattedDate {
    final date = publishedAt ?? createdAt;
    if (date == null) return '';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[date.month - 1];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month ${date.day}, ${date.year} · $hour:$minute $period';
  }
}
