# Security Review

## Finding 1: `burnFrom` can desynchronize DSC supply and recorded debt

- **Severity:** Medium
- **Confidence:** 9/10
- **Affected code:** `src/DecentralizedStableCoin.sol:31,50-59`
- **Related code:** `src/DSCEngine.sol:169-171,216-220`

`DecentralizedStableCoin` inherits the public `ERC20Burnable.burnFrom` implementation but only restricts its `burn` function with `onlyOwner`. A token holder can approve a spender (including themselves) and call `burnFrom`, which spends the allowance and burns DSC without notifying `DSCEngine` or reducing the holder's recorded debt.

This can make the DSC total supply smaller than the debt recorded by the engine. The borrower remains accountable for that debt and may be unable to repay it or redeem collateral; a shortage of DSC in circulation can also prevent liquidators from covering stale debt.

The engine's `burnDsc` path updates the debt ledger as part of burning. The inherited `burnFrom` path does not call the engine.

**Recommended remediation:** Disable or restrict `burnFrom` so DSC can only be burned through a debt-aware engine path that updates the corresponding borrower's debt.
