import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/verification_repository_impl.dart';
import '../../domain/repositories/verification_repository.dart';

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  return VerificationRepositoryImpl();
});
