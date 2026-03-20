import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_fi/app/viewmodels/seed_keypair_vm.dart';
import 'package:next_fi/core/services/secure_storage/seed_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;

  setUp(() async {
    storage = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args =
              (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return key == null ? null : storage[key];
            case 'write':
              if (key != null) {
                storage[key] = (args['value'] ?? '').toString();
              }
              return null;
            case 'delete':
              if (key != null) {
                storage.remove(key);
              }
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('addWallet deduplicates repeated mnemonic or address imports', () async {
    final id1 = await SeedStorage.addWallet(
      'alpha beta gamma',
      name: 'Primary',
      publicAddress: 'GPRIMARY',
    );
    final id2 = await SeedStorage.addWallet(
      ' alpha   beta gamma ',
      name: 'Renamed',
      publicAddress: 'GPRIMARY',
    );

    final wallets = await SeedStorage.listWallets();
    final active = await SeedStorage.getActiveWalletId();

    expect(id2, id1);
    expect(wallets, hasLength(1));
    expect(wallets.single.name, 'Renamed');
    expect(wallets.single.publicAddress, 'GPRIMARY');
    expect(active, id1);
  });

  test('SeedKeypairVM refreshes itself after external wallet switch', () async {
    final firstId = await SeedStorage.addWallet(
      'wallet one words',
      name: 'Wallet 1',
      publicAddress: 'GFIRST',
    );
    final secondId = await SeedStorage.addWallet(
      'wallet two words',
      name: 'Wallet 2',
      publicAddress: 'GSECOND',
      makeActive: false,
    );

    final vm = SeedKeypairVM();
    addTearDown(vm.dispose);

    await vm.init();
    expect(vm.activeWalletId, firstId);
    expect(vm.accountId, 'GFIRST');

    await SeedStorage.setActiveWallet(secondId);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(vm.activeWalletId, secondId);
    expect(vm.accountId, 'GSECOND');
    expect(vm.meta?.name, 'Wallet 2');
  });
}
