import 'dart:async';

/// macOS e Android não avisam a mudança de entradas pelo plugin `record`.
Stream<void>? deviceChangeEvents() => null;
