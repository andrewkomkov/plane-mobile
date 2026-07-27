import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/services/bulk_service.dart';

class _Recorder implements HttpClientAdapter {
  final List<RequestOptions> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    return ResponseBody.fromString(jsonEncode({'ok': true}), 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Recorder adapter;

  setUp(() {
    adapter = _Recorder();
    BulkService.debugClient = Dio(BaseOptions(baseUrl: 'https://plane.test'))
      ..httpClientAdapter = adapter;
  });

  tearDown(() => BulkService.debugClient = null);

  group('archiveIssues', () {
    test('posts the whole set in one request', () async {
      await BulkService.archiveIssues('acme', 'proj', ['a', 'b', 'c']);

      expect(adapter.calls, hasLength(1));
      final call = adapter.calls.single;
      expect(call.method, 'POST');
      expect(call.path, endsWith('/proj/bulk-archive-issues/'));
      expect(call.data, {
        'issue_ids': ['a', 'b', 'c']
      });
    });

    test('an empty set is not a request', () async {
      // The endpoint answers 400 for an empty list, and there is nothing to
      // ask it in the first place.
      await BulkService.archiveIssues('acme', 'proj', const []);
      expect(adapter.calls, isEmpty);
    });
  });

  group('deleteIssues', () {
    test('is a DELETE with the ids in the body', () async {
      await BulkService.deleteIssues('acme', 'proj', ['a']);

      final call = adapter.calls.single;
      // Not a POST, and not ids in the query: the endpoint reads
      // `issue_ids` out of request.data on a DELETE.
      expect(call.method, 'DELETE');
      expect(call.path, endsWith('/proj/bulk-delete-issues/'));
      expect(call.data, {
        'issue_ids': ['a']
      });
    });

    test('an empty set is not a request', () async {
      await BulkService.deleteIssues('acme', 'proj', const []);
      expect(adapter.calls, isEmpty);
    });
  });

  group('createLabels', () {
    test('sends label_data, not a bare list', () async {
      await BulkService.createLabels('acme', 'proj', [
        (name: 'bug', color: '#ef4444'),
        (name: 'chore', color: '#64748b'),
      ]);

      final call = adapter.calls.single;
      expect(call.path, endsWith('/proj/bulk-create-labels/'));
      expect(call.data, {
        'label_data': [
          {'name': 'bug', 'color': '#ef4444'},
          {'name': 'chore', 'color': '#64748b'},
        ]
      });
    });

    test('an empty set is not a request', () async {
      await BulkService.createLabels('acme', 'proj', const []);
      expect(adapter.calls, isEmpty);
    });
  });
}
