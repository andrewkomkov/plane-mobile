import 'package:dio/dio.dart';

/// The most useful sentence available about a failed API call.
///
/// Plane's member and invitation endpoints refuse things with a 400 and a
/// `{"error": "..."}` body written for a human — "You cannot leave the project
/// as you are the only admin", "Some users are already member of workspace".
/// Those refusals are the ones a client cannot always predict (whether someone
/// is the sole admin of *another* project, for instance, is not knowable from
/// the screen they are on), so when one arrives it is worth far more than the
/// status code. Everything else falls back to naming the code, which at least
/// distinguishes a permission problem from an outage.
String describeApiError(Object error,
    {String fallback = 'Something went wrong'}) {
  if (error is! DioException) return fallback;

  final data = error.response?.data;
  if (data is Map) {
    for (final key in const ['error', 'detail', 'message']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
      // DRF field errors arrive as {"role": ["..."]}.
      if (value is List && value.isNotEmpty) return '${value.first}';
    }
    // A serializer rejection names the field it rejected.
    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return '${value.first}';
    }
  }

  final status = error.response?.statusCode;
  if (status == 403) return 'You do not have permission to do that';
  if (status != null) return 'Server returned $status';
  return 'Could not reach the server (${error.type.name})';
}
