// stellar_ramp_deeplink_service.dart
import 'package:url_launcher/url_launcher.dart';

/// Supported third-party ramp providers (no business registration required)
enum RampProvider {
  lobstr('Lobstr', 'https://lobstr.co', 'lobstr://'),
  stellarx('StellarX', 'https://www.stellarx.com', 'stellarx://'),
  stellarterm('StellarTerm', 'https://stellarterm.com', null),
  anchorUsd('AnchorUSD', 'https://www.anchorusd.com', null),
  coinsPh('Coins.ph', 'https://coins.ph', null),
  coinbase('Coinbase', 'https://www.coinbase.com', null),
  kraken('Kraken', 'https://www.kraken.com', null);

  final String name;
  final String webUrl;
  final String? deepLinkScheme;

  const RampProvider(this.name, this.webUrl, this.deepLinkScheme);
}

/// Transaction type for ramp operations
enum RampTransactionType {
  buy('Buy XLM', 'Purchase XLM with fiat currency'),
  sell('Sell XLM', 'Convert XLM to fiat currency'),
  swap('Swap Assets', 'Exchange between cryptocurrencies');

  final String displayName;
  final String description;

  const RampTransactionType(this.displayName, this.description);
}

/// Supported fiat currencies
enum FiatCurrency {
  usd('USD', '\$', 'US Dollar'),
  eur('EUR', '€', 'Euro'),
  gbp('GBP', '£', 'British Pound'),
  php('PHP', '₱', 'Philippine Peso'),
  jpy('JPY', '¥', 'Japanese Yen'),
  cad('CAD', 'C\$', 'Canadian Dollar');

  final String code;
  final String symbol;
  final String name;

  const FiatCurrency(this.code, this.symbol, this.name);
}

/// Provider availability info
class ProviderInfo {
  final RampProvider provider;
  final bool supportsBuy;
  final bool supportsSell;
  final bool supportsSwap;
  final List<FiatCurrency> supportedCurrencies;
  final List<String> supportedRegions;
  final String description;
  final bool kycRequired;
  final String? estimatedFees;

  const ProviderInfo({
    required this.provider,
    required this.supportsBuy,
    required this.supportsSell,
    required this.supportsSwap,
    required this.supportedCurrencies,
    required this.supportedRegions,
    required this.description,
    required this.kycRequired,
    this.estimatedFees,
  });
}

/// Deep link result
class DeepLinkResult {
  final bool success;
  final String? errorMessage;
  final RampProvider? provider;

  const DeepLinkResult({
    required this.success,
    this.errorMessage,
    this.provider,
  });

  factory DeepLinkResult.success(RampProvider provider) {
    return DeepLinkResult(
      success: true,
      provider: provider,
    );
  }

  factory DeepLinkResult.failure(String error) {
    return DeepLinkResult(
      success: false,
      errorMessage: error,
    );
  }
}

/// Service for deep linking to third-party ramp providers
/// No API keys, business registration, or KYB required
class StellarRampDeepLinkService {
  // ──────────────────────────────────────────────────────────────────────────
  // Provider Information
  // ──────────────────────────────────────────────────────────────────────────

  static final Map<RampProvider, ProviderInfo> _providerInfo = {
    RampProvider.lobstr: const ProviderInfo(
      provider: RampProvider.lobstr,
      supportsBuy: true,
      supportsSell: true,
      supportsSwap: true,
      supportedCurrencies: [
        FiatCurrency.usd,
        FiatCurrency.eur,
        FiatCurrency.gbp,
      ],
      supportedRegions: ['US', 'EU', 'UK', 'Global'],
      description: 'Popular Stellar wallet with built-in buy/sell',
      kycRequired: true,
      estimatedFees: '~4-5%',
    ),
    RampProvider.stellarx: const ProviderInfo(
      provider: RampProvider.stellarx,
      supportsBuy: true,
      supportsSell: true,
      supportsSwap: true,
      supportedCurrencies: [
        FiatCurrency.usd,
        FiatCurrency.eur,
      ],
      supportedRegions: ['Global'],
      description: 'Stellar DEX with on-ramp integration',
      kycRequired: false,
      estimatedFees: '~2-3%',
    ),
    RampProvider.stellarterm: const ProviderInfo(
      provider: RampProvider.stellarterm,
      supportsBuy: false,
      supportsSell: false,
      supportsSwap: true,
      supportedCurrencies: [],
      supportedRegions: ['Global'],
      description: 'Decentralized exchange for Stellar assets',
      kycRequired: false,
      estimatedFees: 'Network fees only',
    ),
    RampProvider.anchorUsd: const ProviderInfo(
      provider: RampProvider.anchorUsd,
      supportsBuy: true,
      supportsSell: true,
      supportsSwap: false,
      supportedCurrencies: [FiatCurrency.usd],
      supportedRegions: ['US', 'Select countries'],
      description: 'USD-backed stablecoin on Stellar',
      kycRequired: true,
      estimatedFees: '~1%',
    ),
    RampProvider.coinsPh: const ProviderInfo(
      provider: RampProvider.coinsPh,
      supportsBuy: true,
      supportsSell: true,
      supportsSwap: false,
      supportedCurrencies: [FiatCurrency.php],
      supportedRegions: ['Philippines'],
      description: 'Philippine crypto exchange with GCash/PayMaya',
      kycRequired: true,
      estimatedFees: '~2-3%',
    ),
    RampProvider.coinbase: const ProviderInfo(
      provider: RampProvider.coinbase,
      supportsBuy: true,
      supportsSell: true,
      supportsSwap: true,
      supportedCurrencies: [
        FiatCurrency.usd,
        FiatCurrency.eur,
        FiatCurrency.gbp,
      ],
      supportedRegions: ['US', 'EU', 'UK', '100+ countries'],
      description: 'Major exchange - buy crypto then send to Stellar',
      kycRequired: true,
      estimatedFees: '~1.5-3.5%',
    ),
    RampProvider.kraken: const ProviderInfo(
      provider: RampProvider.kraken,
      supportsBuy: true,
      supportsSell: true,
      supportsSwap: true,
      supportedCurrencies: [
        FiatCurrency.usd,
        FiatCurrency.eur,
        FiatCurrency.gbp,
        FiatCurrency.cad,
        FiatCurrency.jpy,
      ],
      supportedRegions: ['US', 'EU', 'UK', 'Canada', 'Japan'],
      description: 'Major exchange with XLM support',
      kycRequired: true,
      estimatedFees: '~1-2%',
    ),
  };

  /// Get information about a specific provider
  static ProviderInfo? getProviderInfo(RampProvider provider) {
    return _providerInfo[provider];
  }

  /// Get all available providers for a transaction type
  static List<ProviderInfo> getAvailableProviders({
    RampTransactionType? type,
    FiatCurrency? currency,
    String? region,
  }) {
    return _providerInfo.values.where((info) {
      // Filter by transaction type
      if (type == RampTransactionType.buy && !info.supportsBuy) return false;
      if (type == RampTransactionType.sell && !info.supportsSell) return false;
      if (type == RampTransactionType.swap && !info.supportsSwap) return false;

      // Filter by currency
      if (currency != null && info.supportedCurrencies.isNotEmpty) {
        if (!info.supportedCurrencies.contains(currency)) return false;
      }

      // Filter by region (basic check)
      if (region != null && info.supportedRegions.isNotEmpty) {
        final regionUpper = region.toUpperCase();
        if (!info.supportedRegions.any((r) =>
        r.toUpperCase() == regionUpper || r == 'Global')) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Deep Link Methods - Buy XLM
  // ──────────────────────────────────────────────────────────────────────────

  /// Open Lobstr to buy XLM
  static Future<DeepLinkResult> buyWithLobstr({
    required String stellarAddress,
    double? amount,
    FiatCurrency? currency,
  }) async {
    try {
      // Try deep link first (if Lobstr app is installed)
      final deepLinkUrl = Uri.parse(
        '${RampProvider.lobstr.deepLinkScheme}buy-xlm?'
            'address=$stellarAddress'
            '${amount != null ? '&amount=$amount' : ''}'
            '${currency != null ? '&currency=${currency.code}' : ''}',
      );

      if (await canLaunchUrl(deepLinkUrl)) {
        await launchUrl(deepLinkUrl, mode: LaunchMode.externalApplication);
        return DeepLinkResult.success(RampProvider.lobstr);
      }

      // Fallback to web URL
      final webUrl = Uri.parse(
        '${RampProvider.lobstr.webUrl}/buy-xlm?'
            'address=$stellarAddress'
            '${amount != null ? '&amount=$amount' : ''}'
            '${currency != null ? '&currency=${currency.code}' : ''}',
      );

      if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        return DeepLinkResult.success(RampProvider.lobstr);
      }

      return DeepLinkResult.failure('Unable to open Lobstr');
    } catch (e) {
      return DeepLinkResult.failure('Error opening Lobstr: $e');
    }
  }

  /// Open StellarX to buy XLM
  static Future<DeepLinkResult> buyWithStellarX({
    required String stellarAddress,
  }) async {
    try {
      final url = Uri.parse(
        '${RampProvider.stellarx.webUrl}/markets?'
            'destination=$stellarAddress',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return DeepLinkResult.success(RampProvider.stellarx);
      }

      return DeepLinkResult.failure('Unable to open StellarX');
    } catch (e) {
      return DeepLinkResult.failure('Error opening StellarX: $e');
    }
  }

  /// Open AnchorUSD
  static Future<DeepLinkResult> buyWithAnchorUSD({
    required String stellarAddress,
  }) async {
    try {
      final url = Uri.parse(
        '${RampProvider.anchorUsd.webUrl}/deposit?'
            'asset=USD&destination=$stellarAddress',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return DeepLinkResult.success(RampProvider.anchorUsd);
      }

      return DeepLinkResult.failure('Unable to open AnchorUSD');
    } catch (e) {
      return DeepLinkResult.failure('Error opening AnchorUSD: $e');
    }
  }

  /// Open Coins.ph (Philippine users)
  static Future<DeepLinkResult> buyWithCoinsPh() async {
    try {
      final url = Uri.parse(RampProvider.coinsPh.webUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return DeepLinkResult.success(RampProvider.coinsPh);
      }

      return DeepLinkResult.failure('Unable to open Coins.ph');
    } catch (e) {
      return DeepLinkResult.failure('Error opening Coins.ph: $e');
    }
  }

  /// Open Coinbase to buy crypto (then user manually sends to Stellar)
  static Future<DeepLinkResult> buyWithCoinbase() async {
    try {
      final url = Uri.parse('${RampProvider.coinbase.webUrl}/price/stellar');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return DeepLinkResult.success(RampProvider.coinbase);
      }

      return DeepLinkResult.failure('Unable to open Coinbase');
    } catch (e) {
      return DeepLinkResult.failure('Error opening Coinbase: $e');
    }
  }

  /// Open Kraken to buy XLM
  static Future<DeepLinkResult> buyWithKraken() async {
    try {
      final url = Uri.parse('${RampProvider.kraken.webUrl}/prices/stellar');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return DeepLinkResult.success(RampProvider.kraken);
      }

      return DeepLinkResult.failure('Unable to open Kraken');
    } catch (e) {
      return DeepLinkResult.failure('Error opening Kraken: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Deep Link Methods - Swap Assets
  // ──────────────────────────────────────────────────────────────────────────

  /// Open StellarTerm for swapping assets
  static Future<DeepLinkResult> swapOnStellarTerm({
    required String stellarAddress,
  }) async {
    try {
      final url = Uri.parse(
        '${RampProvider.stellarterm.webUrl}/exchange?'
            'account=$stellarAddress',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return DeepLinkResult.success(RampProvider.stellarterm);
      }

      return DeepLinkResult.failure('Unable to open StellarTerm');
    } catch (e) {
      return DeepLinkResult.failure('Error opening StellarTerm: $e');
    }
  }

  /// Open Lobstr for swapping
  static Future<DeepLinkResult> swapOnLobstr({
    required String stellarAddress,
  }) async {
    try {
      final url = Uri.parse(
        '${RampProvider.lobstr.webUrl}/trade?'
            'address=$stellarAddress',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return DeepLinkResult.success(RampProvider.lobstr);
      }

      return DeepLinkResult.failure('Unable to open Lobstr');
    } catch (e) {
      return DeepLinkResult.failure('Error opening Lobstr: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Generic Deep Link Method
  // ──────────────────────────────────────────────────────────────────────────

  /// Generic method to open any provider
  static Future<DeepLinkResult> openProvider({
    required RampProvider provider,
    required RampTransactionType type,
    required String stellarAddress,
    double? amount,
    FiatCurrency? currency,
  }) async {
    switch (provider) {
      case RampProvider.lobstr:
        if (type == RampTransactionType.buy) {
          return buyWithLobstr(
            stellarAddress: stellarAddress,
            amount: amount,
            currency: currency,
          );
        } else if (type == RampTransactionType.swap) {
          return swapOnLobstr(stellarAddress: stellarAddress);
        }
        break;

      case RampProvider.stellarx:
        return buyWithStellarX(stellarAddress: stellarAddress);

      case RampProvider.stellarterm:
        return swapOnStellarTerm(stellarAddress: stellarAddress);

      case RampProvider.anchorUsd:
        return buyWithAnchorUSD(stellarAddress: stellarAddress);

      case RampProvider.coinsPh:
        return buyWithCoinsPh();

      case RampProvider.coinbase:
        return buyWithCoinbase();

      case RampProvider.kraken:
        return buyWithKraken();
    }

    return DeepLinkResult.failure('Provider not supported for this action');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helper Methods
  // ──────────────────────────────────────────────────────────────────────────

  /// Check if a provider app is installed (deep link available)
  static Future<bool> isProviderInstalled(RampProvider provider) async {
    if (provider.deepLinkScheme == null) return false;

    try {
      final url = Uri.parse('${provider.deepLinkScheme}');
      return await canLaunchUrl(url);
    } catch (e) {
      return false;
    }
  }

  /// Get recommended provider based on user's region and needs
  static RampProvider getRecommendedProvider({
    required RampTransactionType type,
    FiatCurrency? currency,
    String? region,
  }) {
    // Philippine users
    if (region == 'PH' && currency == FiatCurrency.php) {
      return RampProvider.coinsPh;
    }

    // For buying/selling
    if (type == RampTransactionType.buy || type == RampTransactionType.sell) {
      return RampProvider.lobstr; // Most universal
    }

    // For swapping
    if (type == RampTransactionType.swap) {
      return RampProvider.stellarx; // Best DEX experience
    }

    return RampProvider.lobstr; // Default
  }
}