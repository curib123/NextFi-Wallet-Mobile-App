import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:next_fi/core/models/asset_model.dart';
import 'package:next_fi/core/recipient_input/recipient_flow_controller.dart';
import 'package:next_fi/core/services/federation_address/models/federation_address_models.dart';
import 'package:next_fi/features/contact/data/models/recipient_address_model.dart';
import 'package:next_fi/features/send/presentation/viewmodels/send_state.dart';

void main() {
  group('RecipientFlowController', () {
    late RecipientInputState latestState;
    late RecipientFlowController controller;
    late Map<String, FederationResolveResponse> federationResponses;
    late List<String> federationRequests;

    RecipientAddressModel recipient({
      required String id,
      required String name,
      required String address,
    }) {
      final now = DateTime(2026, 3, 28);
      return RecipientAddressModel(
        id: id,
        name: name,
        address: address,
        color: 0xFF00A86B,
        createdAt: now,
        updatedAt: now,
      );
    }

    setUp(() {
      federationResponses = {
        'alice*nextfi.com': FederationResolveResponse(
          stellarAddress: 'alice*nextfi.com',
          accountId: 'GBRPYHIL2CI3L7VQCH3M2ZQF5JQXQ6N2YHFBT3A57L6H6X4M5O5JZQAF',
        ),
        'bob*nextfi.com': FederationResolveResponse(
          stellarAddress: 'bob*nextfi.com',
          accountId: 'GDQP2KPQGKIHYJGXNUIYOMHARUARCA6LK6P5N2YB4J3L4B25S5O7A7VN',
        ),
      };
      federationRequests = <String>[];
      latestState = RecipientInputState.initial(federationDomain: 'nextfi.com');
      controller = RecipientFlowController(
        initialState: latestState,
        lookupRecipient: (address) async {
          switch (address) {
            case 'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I':
              return recipient(
                id: 'saved-public',
                name: 'Alice',
                address: address,
              );
            case 'GBRPYHIL2CI3L7VQCH3M2ZQF5JQXQ6N2YHFBT3A57L6H6X4M5O5JZQAF':
              return recipient(
                id: 'resolved-alice',
                name: 'Alice Federation',
                address: address,
              );
            case 'GDQP2KPQGKIHYJGXNUIYOMHARUARCA6LK6P5N2YB4J3L4B25S5O7A7VN':
              return recipient(
                id: 'resolved-bob',
                name: 'Bob Federation',
                address: address,
              );
            default:
              return null;
          }
        },
        resolveFederation: (federationAddress, {required domain}) async {
          federationRequests.add('$federationAddress@$domain');
          final resolved = federationResponses[federationAddress];
          if (resolved == null) {
            throw StateError('Unknown federation address');
          }
          return resolved;
        },
        onStateChanged: (state) {
          latestState = state;
        },
      );
    });

    test('manual public address input does not show federation UI', () async {
      await controller.setManualPublicAddress(
        'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
      );

      expect(latestState.mode, RecipientInputMode.publicAddress);
      expect(latestState.shouldShowFederationUi, isFalse);
      expect(
        latestState.finalDestinationAddress,
        'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
      );
      expect(federationRequests, isEmpty);
    });

    test(
      'smart typed input auto-detects public address vs federation',
      () async {
        await controller.setTypedInput(
          'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        );
        expect(latestState.mode, RecipientInputMode.publicAddress);
        expect(latestState.shouldShowFederationUi, isFalse);

        await controller.setTypedInput('alice');
        expect(latestState.mode, RecipientInputMode.federation);
        expect(latestState.federationSuggestions, ['alice*nextfi.com']);

        await controller.setTypedInput('alice*nextfi.com');
        expect(latestState.mode, RecipientInputMode.federation);
        expect(
          latestState.finalDestinationAddress,
          'GBRPYHIL2CI3L7VQCH3M2ZQF5JQXQ6N2YHFBT3A57L6H6X4M5O5JZQAF',
        );
      },
    );

    test(
      'QR parsing only shows federation UI when the scanned value is federation',
      () async {
        await controller.setScannedValue(
          'stellar:GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        );
        expect(latestState.shouldShowFederationUi, isFalse);

        await controller.setScannedValue('stellar:alice*nextfi.com');
        expect(latestState.shouldShowFederationUi, isTrue);
        expect(
          latestState.finalDestinationAddress,
          'GBRPYHIL2CI3L7VQCH3M2ZQF5JQXQ6N2YHFBT3A57L6H6X4M5O5JZQAF',
        );
      },
    );

    test('saved public recipient does not show federation UI', () async {
      await controller.selectSavedRecipient(
        recipient(
          id: 'saved',
          name: 'Alice',
          address: 'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        ),
      );

      expect(latestState.mode, RecipientInputMode.savedRecipient);
      expect(latestState.shouldShowFederationUi, isFalse);
      expect(
        latestState.finalDestinationAddress,
        'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
      );
    });

    test('federation UI appears only in federation mode', () async {
      await controller.setFederationInput('alice*nextfi.com');
      expect(latestState.shouldShowFederationUi, isTrue);

      await controller.setManualPublicAddress(
        'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
      );
      expect(latestState.shouldShowFederationUi, isFalse);
    });

    test(
      'federation resolution does not run in non-federation flows',
      () async {
        await controller.setManualPublicAddress(
          'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        );
        await controller.selectSavedRecipient(
          recipient(
            id: 'saved',
            name: 'Alice',
            address: 'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
          ),
        );
        await controller.setScannedValue(
          'stellar:GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        );

        expect(federationRequests, isEmpty);
      },
    );

    test(
      'clearing a resolved federation resets the field and allows replacement',
      () async {
        await controller.setFederationInput('alice*nextfi.com');
        expect(latestState.resolvedFederation, isNotNull);

        await controller.clearFederationSelection();
        expect(latestState.federationInput, isEmpty);
        expect(latestState.resolvedFederation, isNull);
        expect(latestState.federationError, isNull);

        await controller.setFederationInput('bob*nextfi.com');
        expect(latestState.federationInput, 'bob*nextfi.com');
        expect(
          latestState.finalDestinationAddress,
          'GDQP2KPQGKIHYJGXNUIYOMHARUARCA6LK6P5N2YB4J3L4B25S5O7A7VN',
        );
      },
    );

    test(
      'switching recipient methods clears incompatible federation state',
      () async {
        await controller.setFederationInput('alice*nextfi.com');
        expect(latestState.resolvedFederation, isNotNull);

        await controller.setManualPublicAddress(
          'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        );

        expect(latestState.mode, RecipientInputMode.publicAddress);
        expect(latestState.resolvedFederation, isNull);
        expect(latestState.federationError, isNull);
        expect(latestState.shouldShowFederationUi, isFalse);
      },
    );

    test(
      'stale async federation resolution is ignored after a mode change',
      () async {
        final completer = Completer<FederationResolveResponse>();
        controller = RecipientFlowController(
          initialState: latestState,
          lookupRecipient: (address) async => null,
          resolveFederation: (federationAddress, {required domain}) {
            return completer.future;
          },
          onStateChanged: (state) {
            latestState = state;
          },
        );

        final pending = controller.setFederationInput('alice*nextfi.com');
        await controller.setManualPublicAddress(
          'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        );
        completer.complete(
          FederationResolveResponse(
            stellarAddress: 'alice*nextfi.com',
            accountId:
                'GBRPYHIL2CI3L7VQCH3M2ZQF5JQXQ6N2YHFBT3A57L6H6X4M5O5JZQAF',
          ),
        );
        await pending;

        expect(latestState.mode, RecipientInputMode.publicAddress);
        expect(latestState.resolvedFederation, isNull);
        expect(
          latestState.finalDestinationAddress,
          'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        );
      },
    );

    test(
      'send state derives destination only from the active recipient mode',
      () async {
        final args = SendControllerArgs(
          address: 'GAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWHF',
          assetId: 'stellar',
          balance: 50,
        );
        const asset = AssetModel(
          id: 'stellar',
          name: 'Stellar',
          symbol: 'XLM',
          isNative: true,
        );

        await controller.setFederationInput('alice*nextfi.com');
        final federationSendState = SendState.initial(
          args,
          'nextfi.com',
          asset,
        ).copyWith(recipient: latestState);
        expect(
          federationSendState.destinationAddress,
          'GBRPYHIL2CI3L7VQCH3M2ZQF5JQXQ6N2YHFBT3A57L6H6X4M5O5JZQAF',
        );

        await controller.setManualPublicAddress(
          'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        );
        final publicSendState = federationSendState.copyWith(
          recipient: latestState,
        );
        expect(
          publicSendState.destinationAddress,
          'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        );
      },
    );

    test(
      'claimable flow uses the same active destination derivation',
      () async {
        await controller.setScannedValue('stellar:alice*nextfi.com');
        expect(
          latestState.finalDestinationAddress,
          'GBRPYHIL2CI3L7VQCH3M2ZQF5JQXQ6N2YHFBT3A57L6H6X4M5O5JZQAF',
        );

        await controller.setScannedValue(
          'stellar:GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        );
        expect(
          latestState.finalDestinationAddress,
          'GA7QYNF7SOWQ3GLR6QJ3A7Z2FJY3J55L4L7K6U7V3ZAHVY2V7S3N7X6I',
        );
      },
    );
  });
}
