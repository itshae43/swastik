import '../models/greeting_model.dart';

abstract class GreetingLocalDataSource {
  Future<GreetingModel> getLastGreeting();
}

class GreetingLocalDataSourceImpl implements GreetingLocalDataSource {
  @override
  Future<GreetingModel> getLastGreeting() async {
    // Simulating database or network call with a brief delay
    await Future.delayed(const Duration(milliseconds: 500));
    return const GreetingModel(message: "Hello World");
  }
}
