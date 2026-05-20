import '../entities/greeting.dart';
import '../repositories/greeting_repository.dart';

class GetGreetingUseCase {
  final GreetingRepository repository;

  GetGreetingUseCase(this.repository);

  Future<Greeting> call() async {
    return await repository.getGreeting();
  }
}
