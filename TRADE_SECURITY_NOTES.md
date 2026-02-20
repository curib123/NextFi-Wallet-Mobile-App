# Trade P2P Security & Claimable Balance – Backend Notes

> Written for backend developer reference. Apply these to harden the P2P escrow flow
> and prevent scams, fraudulent releases, and asset theft.

---

## 1. Claimable Balance Escrow Lifecycle

### Current Flow
```
Seller funds escrow → Claimable Balance ID assigned to trade
Buyer pays fiat → Marks trade as "paid"
Seller verifies fiat received → Releases escrow to buyer wallet
```

### Backend Must Enforce
- **Escrow state machine**: Only allow state transitions in order:
  `unfunded → funded → released | refunded`
  Reject any out-of-order transition (e.g., cannot release an unfunded escrow).

- **Claimable balance ownership**: The backend must record which Stellar
  claimable balance ID belongs to which trade. Never accept a `releaseEscrow`
  request that references a different balance ID than the one on record.

- **Atomic assignment**: When the seller submits the funding transaction hash,
  the backend must verify the actual Stellar claimable balance on-chain before
  marking escrow as `funded`. Do NOT trust the client's word alone.

---

## 2. Release Authorization

### Required Checks Before Releasing
1. **Trade status must be `paid`** — only release after buyer confirms payment.
2. **Caller must be the authenticated seller** — validate JWT identity matches `sellerId`.
3. **Idempotency key** — enforce server-side idempotency on release endpoint.
   Store the key and return the same result for duplicate requests.
4. **Release tx hash on-chain verification (recommended)** — verify the release
   transaction hash exists on Stellar before marking `escrowState = released`.
5. **Rate limiting** — limit release attempts per trade to prevent timing attacks.

### Reject If
- Caller is not the seller of that specific trade.
- Trade is already in a final state (`released`, `refunded`, `cancelled`).
- Claimable balance ID on the trade does not match the one in the release tx.

---

## 3. Scam Prevention

### Common P2P Scam Vectors
| Vector | Backend Mitigation |
|---|---|
| Seller releases before payment confirmed | Enforce `status = paid` check before any release |
| Buyer fakes "paid" status via API | Require payment proof upload; add manual admin override for disputes |
| Seller cancels after receiving fiat | Block cancel if trade is in `paid` status unless buyer also confirms |
| Replay attacks on release endpoint | Enforce idempotency keys tied to `tradeId + action + userId` |
| Man-in-middle wallet swap | Lock buyer wallet address at trade creation; do not allow post-creation edits |
| Dispute stall tactics | Auto-escalate to admin if dispute not resolved within 48h |

---

## 4. Claimable Balance ID Integrity

### On Trade Creation
- The backend should **generate** or **verify** the claimable balance ID
  by querying Stellar Horizon, not by trusting client input.
- Store `claimableBalanceId`, `fundedTxHash`, `escrowFundedAt` atomically.

### On Dispute
- Freeze the claimable balance from release/refund during active dispute.
- Only admin/arbitrator can trigger release or refund during dispute.

### Expiry
- Set `escrowExpiryAt` = trade creation time + max allowed payment window (e.g., 24h).
- If expiry passes without `paid` status, auto-trigger refund to seller.
- The backend job should run every 5 minutes to check expired trades.

---

## 5. API Endpoint Hardening

### Recommended Headers & Middleware
```
POST /api/v1/trades/:id/release
POST /api/v1/trades/:id/cancel
POST /api/v1/trades/:id/mark-paid
```
All mutating endpoints must:
- Require `Authorization: Bearer <jwt>` with valid, non-expired token.
- Validate `Idempotency-Key` header (UUID, store for 24h, reject duplicates).
- Return `409 Conflict` for duplicate idempotency keys.
- Log all state transitions with `userId`, `timestamp`, `ipAddress`, `userAgent`.

### Rate Limits (suggested)
| Endpoint | Limit |
|---|---|
| `mark-paid` | 3 per trade |
| `release` | 2 per trade |
| `cancel` | 2 per trade |
| `open-dispute` | 1 per trade |
| `upload-proof` | 5 per trade |

---

## 6. Payment Proof Validation

- Store proof images server-side (S3/GCS); never serve raw user-uploaded paths.
- Validate MIME type and file size on upload (max 10MB, images only).
- Add a `proofVerified` flag that admin/seller can set after manual verification.
- Block auto-release if `proofVerified = false` (optional, adds friction but safety).

---

## 7. Wallet Address Lock

- **Lock buyer wallet at trade creation** — store `buyerPublicAddress` in the trade record.
- **Never allow the buyer to change their receiving address** after trade creation.
- Verify the `buyerPublicAddress` matches the claimable balance claimant on Stellar.

---

## 8. Audit Trail

All the following events must be stored in a `trade_events` table:
```
trade_created | escrow_funded | buyer_marked_paid | proof_uploaded
seller_released | trade_cancelled | dispute_opened | dispute_resolved
escrow_expired | escrow_refunded
```
Each event: `{ tradeId, eventType, actorId, actorRole, metadata, createdAt }`

---

## 9. Suggested Backend TODO List

- [ ] Add server-side Stellar claimable balance verification on fund/release
- [ ] Add idempotency key enforcement on all mutating endpoints
- [ ] Add trade event audit table
- [ ] Add auto-expiry cron job for unfunded/timed-out trades
- [ ] Add `proofVerified` field to payment proof model
- [ ] Lock buyer wallet address post-creation (no edits allowed)
- [ ] Add dispute auto-escalation timer (48h)
- [ ] Enforce `escrow_state` transitions via state machine in backend service
- [ ] Rate limit sensitive endpoints per trade
- [ ] Add admin arbitration endpoint for dispute resolution
