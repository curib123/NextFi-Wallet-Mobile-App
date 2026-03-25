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

              return AppModalBase(
                backgroundColor: c.surface,
                maxHeightFactor: 0.6,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            LucideIcons.edit2,
                            size: 18,
                            color: c.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Federation Address',
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Update the alias linked to this wallet.',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
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
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(height: 10),
                      Text(
                        state.editFederationError!,
                        style: TextStyle(
                          color: c.error,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: AppOutlinedButton(
                            onPressed: state.editingFederationId == item.id
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: c.textPrimary,
                              side: BorderSide(
                                color: c.border.withValues(alpha: 0.65),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                        message: 'Federation address updated',
                                        type: SnackBarType.success,
                                      );
                                    } else {
                                      setState(() {});
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                              foregroundColor: AppColor.of(context).onPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
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
                                      color: AppColor.of(context).onPrimary,
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
              );
            },
          );
        },
      );
    },
  );
}
