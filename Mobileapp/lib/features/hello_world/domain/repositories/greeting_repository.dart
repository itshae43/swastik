import '../entities/greeting.dart';

abstract class GreetingRepository {
  Future<Greeting> getGreeting();
}
