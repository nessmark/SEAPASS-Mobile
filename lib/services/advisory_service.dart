import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/advisory.dart';
import 'api_service.dart';
import 'passenger_session.dart';

class AdvisoryService {
  AdvisoryService._();

  /// Reactive notifier providing instant real-time badge updates across the app
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  static String get _deletedStorageKey {
    final pId = PassengerSession.passengerId;
    if (pId > 0) return 'deleted_advisories_id_$pId';
    final email = PassengerSession.email.trim().toLowerCase();
    if (email.isNotEmpty) return 'deleted_advisories_email_$email';
    return 'deleted_advisories_guest';
  }

  /// Get set of dismissed/deleted advisory IDs for current passenger
  static Future<Set<int>> getDeletedAdvisoryIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_deletedStorageKey) ?? [];
      return list.map((e) => int.tryParse(e)).whereType<int>().toSet();
    } catch (_) {
      return {};
    }
  }

  /// Mark advisory as deleted locally and dispatch delete to backend
  static Future<void> deleteAdvisory(int advisoryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _deletedStorageKey;
      final list = prefs.getStringList(key) ?? [];
      final idStr = advisoryId.toString();
      if (!list.contains(idStr)) {
        list.add(idStr);
        await prefs.setStringList(key, list);
      }
    } catch (_) {}

    // Dispatch dismiss to backend
    try {
      await ApiService.delete('/api/advisories/$advisoryId');
    } catch (_) {}
  }

  /// Restore an advisory locally (e.g. Undo delete action)
  static Future<void> restoreAdvisory(int advisoryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _deletedStorageKey;
      final list = prefs.getStringList(key) ?? [];
      final idStr = advisoryId.toString();
      if (list.contains(idStr)) {
        list.remove(idStr);
        await prefs.setStringList(key, list);
      }
    } catch (_) {}
  }

  /// Clear all advisories for the current user
  static Future<void> clearAllAdvisories(List<int> advisoryIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _deletedStorageKey;
      final list = prefs.getStringList(key) ?? [];
      for (final id in advisoryIds) {
        final idStr = id.toString();
        if (!list.contains(idStr)) {
          list.add(idStr);
        }
      }
      await prefs.setStringList(key, list);
    } catch (_) {}

    for (final id in advisoryIds) {
      try {
        await ApiService.delete('/api/advisories/$id');
      } catch (_) {}
    }
  }

  /// Fetch total unread advisories count from backend
  static Future<int> fetchUnreadCount() async {
    try {
      final response = await ApiService.get('/api/advisories/unread-count');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final count = (data['unread_count'] as num?)?.toInt() ?? 0;
        unreadCountNotifier.value = count;
        return count;
      }
    } catch (e) {
      debugPrint('[AdvisoryService] fetchUnreadCount error: $e');
    }
    return unreadCountNotifier.value;
  }

  /// Fetch list of published advisories with user's read state
  static Future<List<Advisory>> fetchAdvisories() async {
    try {
      final response = await ApiService.get('/api/advisories');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final List list = decoded['data'] ?? (decoded is List ? decoded : []);
        final allAdvisories = list.map((item) => Advisory.fromJson(item)).toList();

        // Exclude user-deleted/dismissed advisories
        final deletedIds = await getDeletedAdvisoryIds();
        final advisories = allAdvisories.where((a) => !deletedIds.contains(a.id)).toList();

        // Synchronize local unread counter
        final unreadCount = advisories.where((a) => !a.isRead).length;
        unreadCountNotifier.value = unreadCount;

        return advisories;
      }
    } catch (e) {
      debugPrint('[AdvisoryService] fetchAdvisories error: $e');
      rethrow;
    }
    return [];
  }

  /// Mark an advisory as read by the passenger
  static Future<bool> markAsRead(int advisoryId) async {
    try {
      final response = await ApiService.post('/api/advisories/$advisoryId/read');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data['unread_count'] != null) {
          unreadCountNotifier.value = (data['unread_count'] as num).toInt();
        } else if (unreadCountNotifier.value > 0) {
          unreadCountNotifier.value -= 1;
        }
        return true;
      }
    } catch (e) {
      debugPrint('[AdvisoryService] markAsRead error: $e');
    }

    // Optimistic fallback decrement
    if (unreadCountNotifier.value > 0) {
      unreadCountNotifier.value -= 1;
    }
    return false;
  }
}
