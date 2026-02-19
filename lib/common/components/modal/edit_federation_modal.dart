import 'package:flutter/material.dart';
import 'package:next_fi/common/components/button/app_buttons.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/Helper/colors/AppColor.dart';
import 'package:next_fi/common/components/snackbar/SnackBar.dart';
import 'package:next_fi/features/receive/view_model/receive_vm.dart';
import 'package:next_fi/services/federation_address/models/federation_address_models.dart';

Future<void> showEditFederationModal(
  BuildContext context, {
  required ReceiveVM vm,
  required FederationAddressModel item,
}) async {
  final c = AppColor.of(context);
  final aliasCtrl = TextEditingController(text: item.alias);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final rawAlias = aliasCtrl.text.trim();
          final normalizedAlias = rawAlias.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9._-]'),
            '',
          );
          final canSave =
              normalizedAlias.isNotEmpty && vm.editingFederationId != item.id;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              top: 12,
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border.withOpacity(0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: c.border.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                LucideIcons.edit2,
                                size: 17,
                                color: c.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Edit Federation Address',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Alias',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: aliasCtrl,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9._-]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Enter alias',
                            suffixText: '*${item.domain}',
                            isDense: true,
                            filled: true,
                            fillColor: c.background.withOpacity(0.55),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: c.border.withOpacity(0.5),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: c.border.withOpacity(0.5),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: c.primary.withOpacity(0.65),
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: c.primary.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            normalizedAlias.isEmpty
                                ? 'Preview unavailable'
                                : '$normalizedAlias*${item.domain}',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        if (vm.editFederationError != null &&
                            vm.editingFederationId == null) ...[
                          const SizedBox(height: 8),
                          Text(
                            vm.editFederationError!,
                            style: TextStyle(
                              color: c.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: AppOutlinedButton(
                                onPressed: vm.editingFederationId == item.id
                                    ? null
                                    : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: c.textPrimary,
                                  side: BorderSide(
                                    color: c.border.withOpacity(0.65),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppElevatedButton(
                                onPressed: canSave
                                    ? () async {
                                        final ok = await vm
                                            .updateFederationAddress(
                                              id: item.id,
                                              alias: normalizedAlias,
                                              domain: item.domain,
                                            );
                                        if (!context.mounted) return;
                                        if (ok) {
                                          Navigator.pop(context);
                                          showFloatingSnackBar(
                                            context,
                                            message:
                                                'Federation address updated',
                                            type: SnackBarType.success,
                                          );
                                        } else {
                                          setState(() {});
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: vm.editingFederationId == item.id
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Save',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  aliasCtrl.dispose();
}
