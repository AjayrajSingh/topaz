// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

typedef _CallbackSetter = void Function(void Function());
typedef _DefinitionBlock = void Function(
    _CallbackSetter run, _CallbackSetter teardown);

class _Definition {
  final String name;
  final _DefinitionBlock block;

  void Function() _run;
  void Function() _teardown;

  _Definition(this.name, this.block);

  void execute() {
    this.block((void Function() run) => _run = run,
        (void Function() teardown) => _teardown = teardown);
    if (_run == null) {
      throw Exception("Benchmark $name doesn't declare what to run.");
    }

    // Warmup for at least 100ms. Discard result.
    _measure(100);

    // Run the benchmark for at least 2000ms.
    double result = _measure(2000);

    if (_teardown != null) {
      _teardown();
    }

    print('$name: ${result}us');
  }

  // Measures the score for this benchmark by executing it repeately until
  // time minimum has been reached.
  double _measure(int minimumMillis) {
    int minimumMicros = minimumMillis * 1000;
    int iter = 0;
    Stopwatch watch = Stopwatch()..start();
    int elapsed = 0;
    while (elapsed < minimumMicros) {
      _run();
      elapsed = watch.elapsedMicroseconds;
      iter++;
    }
    return elapsed / iter;
  }
}

final List<_Definition> _definitions = [];

void benchmark(final String name, final _DefinitionBlock block) {
  _definitions.add(_Definition(name, block));
}

void runBenchmarks() {
  for (final def in _definitions) {
    try {
      def.execute();
    } on dynamic catch (exception, stack) {
      print("Exception running benchmark '${def.name}': $exception");
      print(stack.toString());
    }
  }
}
