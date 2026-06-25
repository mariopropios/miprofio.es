import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'loading_indicator.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.loadingMessage,
    this.empty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final String? loadingMessage;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => LoadingIndicator(message: loadingMessage),
      error: (error, _) => _ErrorMessage(error: error.toString()),
      data: (result) {
        if (result is Iterable && (result as Iterable).isEmpty && empty != null) {
          return empty!;
        }
        return data(result);
      },
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Error al cargar datos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
