import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/advisory.dart';
import '../services/advisory_service.dart';
import '../services/api_service.dart';

/// Provider managing reactive state for travel advisories and unread counter.
class AdvisoryProvider extends ChangeNotifier {
  int _unreadCount = 0;
  List<Advisory> _advisories = [];
  bool _isLoading = false;
  String? _errorMessage;

  int get unreadCount => _unreadCount;
  List<Advisory> get advisories => _advisories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetch total unread advisories count from backend
  Future<int> fetchUnreadCount() async {
    try {
      final response = await ApiService.get('/api/advisories/unread-count');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final count = (data['unread_count'] as num?)?.toInt() ?? 0;
        _unreadCount = count;
        // Keep legacy ValueNotifier in sync
        AdvisoryService.unreadCountNotifier.value = count;
        notifyListeners();
        return count;
      }
    } catch (e) {
      debugPrint('[AdvisoryProvider] fetchUnreadCount error: $e');
    }
    return _unreadCount;
  }

  /// Fetch list of published advisories with user's read state
  Future<void> fetchAdvisories({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final list = await AdvisoryService.fetchAdvisories();
      _advisories = list;
      // Derive active unread count from loaded list
      _unreadCount = _advisories.where((a) => !a.isRead).length;
      AdvisoryService.unreadCountNotifier.value = _unreadCount;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[AdvisoryProvider] fetchAdvisories error: $e');
      _errorMessage = 'Failed to load advisories. Pull down to refresh.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark an advisory as read instantly and sync with backend
  Future<void> markAsRead(Advisory advisory) async {
    if (advisory.isRead) {
      return; // Already read, nothing to do
    }

    // 1. Instant Optimistic UI Update: Mark advisory as read
    advisory.isRead = true;

    // 2. Decrement unread counter (ensuring it never goes below 0)
    if (_unreadCount > 0) {
      _unreadCount -= 1;
    }
    AdvisoryService.unreadCountNotifier.value = _unreadCount;

    // 3. Instantly notify listeners so the bottom navigation badge reacts in real time
    notifyListeners();

    // 4. Asynchronously persist read state on backend
    try {
      final response = await ApiService.post('/api/advisories/${advisory.id}/read');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data['unread_count'] != null) {
          final serverCount = (data['unread_count'] as num).toInt();
          if (_unreadCount != serverCount) {
            _unreadCount = serverCount;
            AdvisoryService.unreadCountNotifier.value = _unreadCount;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('[AdvisoryProvider] markAsRead sync error: $e');
    }
  }

  /// Delete an advisory locally and sync with backend
  Future<void> deleteAdvisory(Advisory advisory) async {
    final bool wasUnread = !advisory.isRead;
    _advisories.removeWhere((a) => a.id == advisory.id);
    if (wasUnread && _unreadCount > 0) {
      _unreadCount -= 1;
      AdvisoryService.unreadCountNotifier.value = _unreadCount;
    }
    notifyListeners();

    await AdvisoryService.deleteAdvisory(advisory.id);
  }

  /// Restore an advisory (e.g. from Undo action)
  Future<void> restoreAdvisory(Advisory advisory, int originalIndex) async {
    final index = (originalIndex >= 0 && originalIndex <= _advisories.length)
        ? originalIndex
        : 0;
    _advisories.insert(index, advisory);
    if (!advisory.isRead) {
      _unreadCount += 1;
      AdvisoryService.unreadCountNotifier.value = _unreadCount;
    }
    notifyListeners();

    await AdvisoryService.restoreAdvisory(advisory.id);
  }

  /// Clear all advisories
  Future<void> clearAllAdvisories() async {
    final ids = _advisories.map((a) => a.id).toList();
    _advisories.clear();
    _unreadCount = 0;
    AdvisoryService.unreadCountNotifier.value = 0;
    notifyListeners();

    await AdvisoryService.clearAllAdvisories(ids);
  }

  /// Set count manually (e.g. on logout or reset)
  void resetUnreadCount() {
    _unreadCount = 0;
    AdvisoryService.unreadCountNotifier.value = 0;
    notifyListeners();
  }
}
