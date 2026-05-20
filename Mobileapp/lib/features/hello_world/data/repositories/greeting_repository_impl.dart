import '../../domain/entities/greeting.dart';
import '../../domain/repositories/greeting_repository.dart';
import '../datasources/greeting_local_data_source.dart';

class GreetingRepositoryImpl implements GreetingRepository {
  final GreetingLocalDataSource localDataSource;

  GreetingRepositoryImpl({required this.localDataSource});

  @override
  Future<Greeting> getGreeting() async {
    return await localDataSource.getLastGreeting();
  }
}
