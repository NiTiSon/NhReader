import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug trace of every API request.
///
/// Each line carries an id, so a request can be followed to its response, and
/// a request that starts while an identical one is still in flight is flagged:
/// that overlapping pair is what a "network leak" on a screen rebuild looks
/// like. Bodies are never logged — they carry passwords and tokens.
class NetworkTraceInterceptor extends Interceptor {
  NetworkTraceInterceptor({void Function(String)? log})
    : _log = log ?? debugPrint;

  final void Function(String) _log;
  final Map<String, int> _inFlight = {};
  final Stopwatch _clock = Stopwatch()..start();
  int _nextId = 0;

  static const _idKey = 'trace_id';
  static const _startKey = 'trace_start_us';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = '${options.method} ${options.uri}';
    final concurrent = _inFlight[key] = (_inFlight[key] ?? 0) + 1;
    final id = _nextId++;
    options.extra[_idKey] = id;
    options.extra[_startKey] = _clock.elapsedMicroseconds;
    _log(
      '→ #$id ${options.method} ${options.uri}'
      '${concurrent > 1 ? '  DUPLICATE x$concurrent in flight' : ''}',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log(
      '← #${response.requestOptions.extra[_idKey]} ${response.statusCode} '
      '${response.requestOptions.method} ${response.requestOptions.uri} '
      '${_elapsedMs(response.requestOptions)}',
    );
    _finish(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    _log(
      '✕ #${options.extra[_idKey]} '
      '${err.response?.statusCode ?? err.type.name} '
      '${options.method} ${options.uri} ${_elapsedMs(options)}',
    );
    _finish(options);
    handler.next(err);
  }

  String _elapsedMs(RequestOptions options) {
    final start = options.extra[_startKey] as int?;
    if (start == null) return '';
    return '${((_clock.elapsedMicroseconds - start) / 1000).round()}ms';
  }

  void _finish(RequestOptions options) {
    final key = '${options.method} ${options.uri}';
    final remaining = (_inFlight[key] ?? 1) - 1;
    if (remaining <= 0) {
      _inFlight.remove(key);
    } else {
      _inFlight[key] = remaining;
    }
  }
}
