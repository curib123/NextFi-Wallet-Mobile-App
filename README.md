# NextFi Wallet (Private)

> **A non‑custodial XLM/USDC wallet for fast, low‑cost remittances & everyday payments on Stellar.**

NextFi focuses on clarity, speed, and safety. It is a private project (not for public distribution).

---

## Highlights

* **Non‑custodial:** keys live only on the user’s device.
* **Stellar‑native:** XLM and USDC only.
* **Fast payments:** simple send/receive with clear fees and memos.
* **Built‑in Swap (XLM ⇄ USDC):** live quote, slippage control, and **MAX that keeps 1.0 XLM** for fees/account reserve.
* **Clean, mobile‑first UI:** minimal screens and confirmations.

---

## MVVM Architecture (Flutter)

**Pattern:** Model–View–ViewModel

* **View (Widgets/Screens):**

  * Stateless/Stateful Widgets render the UI.
  * Subscribes to ViewModels via `Provider` and rebuilds reactively.
* **ViewModel (ChangeNotifier):**

  * Holds screen state (amounts, quotes, balances, loading/errors).
  * Business rules: slippage, min‑receive, **1 XLM reserve**, input clamping, debounced quoting, and can‑execute guards.
  * Exposes intent methods (e.g., `flipDirectionAndRequote`, `executeSwap`).
* **Model/Services:**

  * Stellar SDK integration (balances, trustlines, quotes, fees, transactions).
  * Secure persistence (seed phrase, PIN/biometrics) via platform key stores.

**Data flow:** User Action → ViewModel Method → Service Call → ViewModel State Update → View Rebuild.

This isolates UI from chain/network details and keeps state predictable and testable.

---

## Tech Stack

* **Framework:** Flutter (Dart)
* **State & DI:** Provider, ChangeNotifier
* **Crypto/Chain:** `stellar_flutter_sdk`
* **Secure Storage:** Android EncryptedSharedPreferences, iOS Keychain (`first_unlock`)
* **UX Utilities:** `intl` (formatting), lightweight animations/icons as needed
* **Testing:** `flutter_test`

---

## Security (Summary)

* **Seed phrase** stored only in secure device storage; never uploaded.
* **PIN** is salted+hashed with exponential lockouts; **biometrics** optional.
* **Fee safety:** XLM actions and swaps always leave **≥ 1.0 XLM** on the account to avoid lockouts and cover network fees.
* **No custodial servers:** transactions sign locally; you remain in control.

> 🔐 Never share your seed phrase. Avoid screenshots/cloud copies.

---

## Getting Started

```bash
flutter pub get
flutter run
```

For iOS the first time:

```bash
cd ios && pod install && cd -
```

### Minimal Configuration (Stellar)

* Choose **testnet** or **mainnet** in your build defines/environment.
* Ensure USDC asset trustline is created on first use (the app prompts/handles this with clear UX).

Example (optional) dart‑defines:

```bash
flutter run \
  --dart-define=USE_TESTNET=true \
  --dart-define=HORIZON_URL=https:
```

---

## Build

* **Android (APK):** `flutter build apk --release`
* **Android (AAB):** `flutter build appbundle --release`
* **iOS (Release):** `flutter build ios --release` (use Xcode for signing)

---

## Usage Notes

* **Swap:** 100%/MAX on XLM automatically sets `amount = balance − 1.0 XLM`.
* **Slippage:** adjustable (e.g., 0.1–5.0%) with visible min‑receive before submit.
* **Send/Receive:** clear memos/tags and upfront fee preview.

---

## License

**Proprietary — Private Project.** Not for redistribution.
