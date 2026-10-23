import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nh_reader/api/network_trace.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.gate});

  /// When set, responses wait until it completes so requests can overlap.
  final Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await gate?.future;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('trace logs responses and flags duplicate requests in flight', () async {
    final lines = <String>[];
    final gate = Completer<void>();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = _FakeAdapter(gate: gate)
      ..interceptors.add(NetworkTraceInterceptor(log: lines.add));

    final requests = [
      dio.get<dynamic>('/galleries'),
      dio.get<dynamic>('/galleries'),
    ];
    await pumpEventQueue();

    expect(lines.where((line) => line.contains('DUPLICATE')), hasLength(1));

    gate.complete();
    await Future.wait(requests);

    expect(lines.where((line) => line.startsWith('→')), hasLength(2));
    expect(lines.where((line) => line.startsWith('←')), hasLength(2));
    expect(lines.where((line) => line.contains('DUPLICATE')), hasLength(1));
  });

  test('trace never logs request bodies', () async {
    final lines = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = _FakeAdapter()
      ..interceptors.add(NetworkTraceInterceptor(log: lines.add));

    await dio.post<dynamic>('/auth/login', data: {'password': 'hunter2'});

    expect(lines.join('\n'), isNot(contains('hunter2')));
  });
}
