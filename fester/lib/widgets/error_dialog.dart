// lib/widgets/error_dialog.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? technicalDetails;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.technicalDetails,
  });

  static Future<void> show(
    BuildContext context, {
    String? title,
    required String message,
    String? technicalDetails,
  }) {
    return showDialog(
      context: context,
      builder:
          (context) => ErrorDialog(
            title: title ?? 'common.error_title'.tr(),
            message: message,
            technicalDetails: technicalDetails,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (technicalDetails != null) ...[
              const SizedBox(height: 16),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    'common.technical_details'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        technicalDetails!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.close'.tr()),
        ),
      ],
    );
  }
}
