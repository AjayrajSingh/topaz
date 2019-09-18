import 'package:fuchsia_modular/module.dart';
import 'root_intent_handler.dart';

void main() {
  Module().registerIntentHandler(RootIntentHandler());
}
