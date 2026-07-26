import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/utils/api_error.dart';

void main() {
  DioException withBody(dynamic body, {int status = 400}) => DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: status,
          data: body,
        ),
      );

  group('describeApiError', () {
    test('passes through the refusal Plane wrote for a human', () {
      // The member endpoints explain themselves, and several of their
      // refusals are things a client cannot predict — whether somebody is the
      // sole admin of a *different* project, for one.
      expect(
        describeApiError(withBody({
          'error': 'You cannot remove a user having role higher than you',
        })),
        'You cannot remove a user having role higher than you',
      );
    });

    test('reads a DRF field error', () {
      expect(
        describeApiError(withBody({
          'role': ['"30" is not a valid choice.'],
        })),
        '"30" is not a valid choice.',
      );
    });

    test('names a permission failure that carried no body', () {
      expect(
        describeApiError(withBody(null, status: 403)),
        'You do not have permission to do that',
      );
    });

    test('falls back to the status code', () {
      expect(
          describeApiError(withBody(null, status: 500)), 'Server returned 500');
    });

    test('names a transport failure', () {
      expect(
        describeApiError(DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionTimeout,
        )),
        contains('connectionTimeout'),
      );
    });

    test('uses the caller fallback for a non-Dio throw', () {
      expect(
        describeApiError(StateError('bad'), fallback: 'Could not add member'),
        'Could not add member',
      );
    });
  });
}
