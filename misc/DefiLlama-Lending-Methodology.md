# AF LST Lending TVL Methodology

## Overview of AF LST Lending

Accumulated Finance LST Lending is a protocol comprising isolated lending markets designed to facilitate borrowing of base tokens (e.g., VLX/ROSE/ZETA) against liquid staking token (LST) collateral (e.g. wstVLX/wstROSE/wstZETA). Each market operates independently, allowing lenders to supply base tokens (VLX) and earn interest, while borrowers deposit collateral (wstVLX) to borrow these base tokens. The protocol leverages the unique properties of LST collateral, an ERC-4626 vault, to manage collateral value accrual through liquid staking rewards.

- **ERC-4626 Collateral**: E.g. **wstVLX** is an ERC-4626 vault wrapping **stVLX**, a liquid staking token pegged 1:1 to **VLX** (1 stVLX = 1 VLX). The wstVLX vault accumulates staking rewards over time, increasing its value relative to stVLX and VLX via the vault’s `pricePerShare` mechanism (e.g., `pricePerShare = 1.05*10^18` indicates 5% accumulated rewards).
- **Base Tokens**: Lenders supply base tokens (**VLX**), which are borrowed by users depositing wstVLX collateral, subject to loan-to-value (LTV) ratios and liquidation mechanisms.

## TVL Calculation Methodology

The Total Value Locked (TVL) for AF LST Lending is calculated as the sum of two components:

1. **Supplied Assets TVL**: The value of base tokens supplied by lenders.
2. **Collateral TVL**: The value of collateral deposited by borrowers.

**Formula**:
```
TVL = Supplied Assets TVL + Collateral TVL
```

### 1. Supplied Assets TVL

Supplied Assets TVL represents the total value of base tokens (e.g., VLX) deposited by lenders into the lending markets, including accrued interest.

**Formula**:
```
{Supplied Assets TVL} = totalAssets * {Base Token Price}
```
- `totalAssets`: The total amount of base tokens supplied, as reported by the lending contract’s `totalAssets` function (sum of lender deposits plus accrued lender interest, in token units).
- `Base Token Price`: The market price of the base token (e.g., VLX).


### 2. Collateral TVL

Collateral TVL represents the value of ERC-4626 collateral deposited by borrowers to secure loans of base tokens.

**Formula**:
```
{Collateral TVL} = totalCollateral * erc4626.pricePerShare * 10^-18 * {Base Token Price}
```
- `totalCollateral`: The total amount of deposited collateral tokens, as reported by the lending contract’s.
- `pricePerShare`: The ERC4626 vault’s price per share scaled up by `10^18`.
- `Base Token Price`: The same VLX price in USD used for Supplied Assets TVL.

**Rationale**:
- **Collateral Pricing**: wstVLX lacks a direct price feed on CoinGecko or DeFiLlama because its value derives from stVLX and accumulated staking rewards. Since stVLX is pegged 1:1 to VLX, we use the VLX price as the base value and adjust it by `pricePerShare` to account for staking rewards (e.g., 1 wstVLX = 1.05 VLX if `pricePerShare = 1.05*10^18`).
- **Accuracy**: The `pricePerShare` from the ERC-4626 vault accurately reflects the wstVLX value in terms of VLX, ensuring the collateral’s USD value is correctly calculated using the VLX price feed.
- **Consistency**: Multiplying by `Base Token Price` aligns Collateral TVL with Supplied Assets TVL, maintaining a unified pricing framework.

**Collateral Price Formula Example**
```
1 wstVLX = 1 stVLX * wstVLX.pricePerShare() * 10^-18 (erc4626 vault)
1 stVLX = 1 VLX (pegged assets)
=> 1 wstVLX = 1 VLX * wstVLX.pricePerShare() * 10^-18
```

### Total TVL

**Formula**:
```
{Total TVL} = (totalAssets * {Base Token Price}) + (totalCollateral * pricePerShare * 10^-18 * {Base Token Price})
=>
{Total TVL} = (totalAssets + totalCollateral * pricePerShare * 10^-18) * {Base Token Price}
```

## Why This Methodology?

- **Transparency**: All inputs (`totalAssets`, `totalCollateral`, `pricePerShare`) are on-chain, ensuring verifiable calculations.
- **Accuracy**: Using `pricePerShare` for collateral captures its dynamic value, avoiding assumptions about staking rewards.
- **Simplicity**: Avoids complex pricing for collateral by leveraging base token price using the ERC-4626 vault’s `pricePerShare`.

## Addressing Potential Concerns

- **Collateral Price Feed Absence**:
  - We use `pricePerShare * {Base Token Price}` to derive wstVLX’s value, leveraging VLX’s established price feed and the ERC-4626 vault’s on-chain data. This is equivalent to pricing a wrapped asset (e.g., wstETH) using the underlying asset’s price adjusted by a conversion rate.
- **Double-Counting Risk**:
  - Supplied Assets TVL and Collateral TVL are distinct: `totalAssets` reflects lender deposits, while `totalCollateral` reflects borrower-deposited wstVLX. No assets are counted twice.