import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import '../models/event_log.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev;

class EventRepository {
  final EventService _service;
  EventRepository(this._service);

  Future<List<EventLog>> getEvents({
    int page = 1,
    int limit = 100,
    String? status,
    DateTimeRange? dayRange,
    String? period,
    String? search,
    String? lifecycleState,
  }) async {
    try {
      final events = await _service.fetchLogs(
        page: page,
        limit: limit,
        status: status,
        dayRange: dayRange,
        period: period,
        search: search,
        lifecycleState: lifecycleState,
      );
      try {
        final sample = events.take(5).map((e) => e.eventId).toList();
        print(
          '[Repository] getEvents returned=${events.length} sampleIds=$sample',
        );
      } catch (_) {}
      return events;
    } catch (e) {
      dev.log('Repository error - getEvents: $e');
      rethrow;
    }
  }

  Future<EventLog> getEventDetails(String id) async {
    try {
      return await _service.fetchLogDetail(id);
    } catch (e) {
      dev.log('Repository error - getEventDetails: $e');
      rethrow;
    }
  }

  Future<EventLog> createEvent(Map<String, dynamic> data) async {
    try {
      return await _service.createLog(data);
    } catch (e) {
      dev.log('Repository error - createEvent: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await _service.deleteLog(id);
    } catch (e) {
      dev.log('Repository error - deleteEvent: $e');
      rethrow;
    }
  }

  Future<EventLog> proposeEvent({
    required String eventId,
    required String proposedStatus,
    String? proposedEventType,
    String? reason,
    DateTime? pendingUntil,
  }) async {
    try {
      dev.log('🔧 [Repository] proposeEvent');
      if (eventId.trim().isEmpty) {
        throw Exception('Không tìm thấy ID sự kiện. Không thể gửi đề xuất.');
      }

      return await _service.proposeEventStatus(
        eventId: eventId,
        proposedStatus: proposedStatus,
        proposedEventType: proposedEventType,
        reason: reason,
        pendingUntil: pendingUntil,
      );
    } catch (e) {
      dev.log('❌ Repository proposeEvent error: $e');
      rethrow;
    }
  }

  Future<bool> confirmEvent(String eventId) async {
    try {
      dev.log('✅ confirmEvent: $eventId');
      await Future.delayed(const Duration(milliseconds: 600));
      return true;
    } catch (e) {
      dev.log('❌ Repository error - confirmEvent: $e');
      return false;
    }
  }

  Future<bool> rejectEvent(String eventId) async {
    try {
      dev.log('🚫 rejectEvent: $eventId');
      await Future.delayed(const Duration(milliseconds: 600));
      return true;
    } catch (e) {
      dev.log('❌ Repository error - rejectEvent: $e');
      return false;
    }
  }
}
