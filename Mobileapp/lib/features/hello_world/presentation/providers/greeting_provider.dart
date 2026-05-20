import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/greeting_local_data_source.dart';
import '../../data/repositories/greeting_repository_impl.dart';
import '../../domain/entities/greeting.dart';
import '../../domain/repositories/greeting_repository.dart';
import '../../domain/usecases/get_greeting_usecase.dart';

// Dependency Injection Providers
final greetingLocalDataSourceProvider = Provider<GreetingLocalDataSource>((ref) {
  return GreetingLocalDataSourceImpl();
});

final greetingRepositoryProvider = Provider<GreetingRepository>((ref) {
  final localDataSource = ref.watch(greetingLocalDataSourceProvider);
  return GreetingRepositoryImpl(localDataSource: localDataSource);
});

final getGreetingUseCaseProvider = Provider<GetGreetingUseCase>((ref) {
  final repository = ref.watch(greetingRepositoryProvider);
  return GetGreetingUseCase(repository);
});

// State Provider to expose Greeting loading state to UI
final greetingFutureProvider = FutureProvider<Greeting>((ref) async {
  final getGreetingUseCase = ref.watch(getGreetingUseCaseProvider);
  return await getGreetingUseCase();
});
