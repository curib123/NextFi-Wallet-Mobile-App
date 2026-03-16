import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:next_fi/app/theme/app_color.dart';
import 'package:next_fi/core/widgets/button/app_buttons.dart';
import 'package:next_fi/core/widgets/modal/base/app_modal_base.dart';
import 'package:next_fi/core/widgets/snackbar/snack_bar.dart';
import 'package:next_fi/features/receive/presentation/viewmodels/receive_controller.dart';
import 'package:next_fi/core/services/federation_address/federation_address_core_service.dart';
import 'package:next_fi/core/services/federation_address/models/federation_address_models.dart';

Future<void> showEditFederationModal(
  BuildContext context, {
  required ReceiveControllerArgs args,
  required FederationAddressModel item,
}) async {
  final c = AppColor.of(context);
  final aliasCtrl = TextEditingController(text: item.alias);

  await showAppModalBottomSheet<void>(
    context,
    builder: (sheetContext) {
      return Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(receiveControllerProvider(args));
          final controller = ref.read(receiveControllerProvider(args).notifier);

          return StatefulBuilder(
            builder: (context, setState) {
              final fixedDomain = state.federationDomain.trim().isNotEmpty
                  ? state.federationDomain.trim()
                  : FederationAddressCoreService.defaultDomain;
              final rawAlias = aliasCtrl.text.trim();
              final normalizedAlias = rawAlias.toLowerCase().replaceAll(
                RegExp(r'[^a-z0-9._-]'),
                '',
              );
              final canSave =
                  normalizedAlias.isNotEmpty &&
                  state.editingFederationId != item.id;

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
                  color: AppColor.of(context).surface,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: c.border.withValues(alpha: 0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColor.of(
                            context,
                          ).textPrimary.withValues(alpha: 0.12),
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
                                  color: c.border.withValues(alpha: 0.9),
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
                                    color: c.primary.withValues(alpha: 0.12),
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
                                suffixText: '*$fixedDomain',
                                isDense: true,
                                filled: true,
                                fillColor: c.background.withValues(alpha: 0.55),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: c.border.withValues(alpha: 0.5),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: c.border.withValues(alpha: 0.5),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: c.primary.withValues(alpha: 0.65),
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
                                color: c.primary.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                normalizedAlias.isEmpty
                                    ? 'Preview unavailable'
                                    : '$normalizedAlias*$fixedDomain',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            if (state.editFederationError != null &&
                                state.editingFederationId == null) ...[
                              const SizedBox(height: 8),
                              Text(
                                state.editFederationError!,
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
                                    onPressed:
                                        state.editingFederationId == item.id
                                        ? null
                                        : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: c.textPrimary,
                                      side: BorderSide(
                                        color: c.border.withValues(alpha: 0.65),
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
                                            final ok = await controller
                                                .updateFederationAddress(
                                                  id: item.id,
                                                  alias: normalizedAlias,
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
                                      foregroundColor: AppColor.of(
                                        context,
                                      ).onPrimary,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: state.editingFederationId == item.id
                                        ? SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColor.of(
                                                context,
                                              ).onPrimary,
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
    },
  );
}
