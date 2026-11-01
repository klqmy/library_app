import 'package:flutter/material.dart';

class RequestState extends StatelessWidget {
  final Object? error;
  final VoidCallback? retry;
  const RequestState({super.key, this.error, this.retry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
    child: Column(
      children: [
        if (error == null) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 18),
          const Text('Загрузка данных с сервера…'),
        ] else ...[
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: 16),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      ],
    ),
  );
}
