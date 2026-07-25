import 'package:flutter/material.dart';
import '../config/theme.dart';

class BottomSheetPicker<T> extends StatelessWidget {
  final String? title;
  final List<BottomSheetPickerItem<T>> items;
  final T? selectedValue;
  final ValueChanged<T> onSelected;

  const BottomSheetPicker({
    super.key,
    this.title,
    required this.items,
    this.selectedValue,
    required this.onSelected,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    required List<BottomSheetPickerItem<T>> items,
    T? selectedValue,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (ctx) => SafeArea(
        child: BottomSheetPicker<T>(
          title: title,
          items: items,
          selectedValue: selectedValue,
          onSelected: (value) => Navigator.pop(ctx, value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title!, style: textTheme.titleMedium),
          ),
        ...items.map((item) => ListTile(
              leading: item.leading,
              title: Text(item.label, style: textTheme.bodyLarge),
              trailing: item.value == selectedValue
                  ? const Icon(Icons.check, size: PlaneTheme.iconLarge)
                  : null,
              onTap: () => onSelected(item.value),
            )),
      ],
    );
  }
}

class BottomSheetPickerItem<T> {
  final T value;
  final String label;
  final Widget? leading;

  const BottomSheetPickerItem({
    required this.value,
    required this.label,
    this.leading,
  });
}
