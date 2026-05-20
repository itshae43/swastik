import '../../domain/entities/greeting.dart';

class GreetingModel extends Greeting {
  const GreetingModel({required super.message});

  factory GreetingModel.fromJson(Map<String, dynamic> json) {
    return GreetingModel(
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
    };
  }
}
