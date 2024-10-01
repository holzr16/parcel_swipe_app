import 'dart:developer' as devtools show log;

void log(String message, {String? name}) {
  devtools.log(message, name: name ?? '');
  // ignore: avoid_print
  print('${name != null ? '$name: ' : ''}$message');
}

