import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Stream<String> watchWebRealtimeEvents(Uri uri) async* {
  final eventSource = web.EventSource(
    uri.toString(),
    web.EventSourceInit(withCredentials: true),
  );
  final events = StreamController<String>();
  final onOpen = ((web.Event _) {
    events.add('connected');
  }).toJS;
  final onMessage = ((web.Event _) {
    events.add('update');
  }).toJS;
  final onError = ((web.Event _) {
    events.add('disconnected');
  }).toJS;
  eventSource.addEventListener('open', onOpen);
  eventSource.addEventListener('message', onMessage);
  eventSource.addEventListener('error', onError);

  try {
    yield* events.stream;
  } finally {
    eventSource.close();
    eventSource.removeEventListener('open', onOpen);
    eventSource.removeEventListener('message', onMessage);
    eventSource.removeEventListener('error', onError);
    await events.close();
  }
}
