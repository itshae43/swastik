import 'package:flutter/material.dart';

item(String name, String value) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
