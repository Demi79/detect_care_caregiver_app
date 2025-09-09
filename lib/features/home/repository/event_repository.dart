import 'package:detect_care_caregiver_app/features/home/service/event_service.dart';
import '../models/event_log.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as dev;

class EventRepository {
  final EventService _service;
  EventRepository(this._service);

  Future<List<EventLog>> getEvents({
    int page = 1,
    int limit = 50,
    String? status,
    DateTimeRange? dayRange,
    String? period,
    String? search,
  }) async {
    try {
      return await _service.fetchLogs(
        page: page,
        limit: limit,
        status: status,
        dayRange: dayRange,
        period: period,
        search: search,
      );
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
}
