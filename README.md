# DEX (Decentralized Exchange)

A Move implementation of an Automated Market Maker (AMM) DEX on Rooch blockchain.

## Features

- Liquidity pool creation
- Adding liquidity
- Token swapping
- Constant product formula (x*y=k)
- 0.3% swap fee
- Slippage protection

## Technical Details

### Constants

```move
   const FEE_TIER_LOW: u256 = 1;    // 0.1% fee
    const FEE_TIER_MEDIUM: u256 = 5;  // 0.5% fee
    const FEE_TIER_HIGH: u256 = 10;   // 1.0% fee
    const FEE_DENOMINATOR: u256 = 1000;
```

### Error Codes

```move
const ERROR_ZERO_AMOUNT: u64 = 1;
const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 2;
const ERROR_SLIPPAGE: u64 = 3;
const ERROR_INVALID_RATIO: u64 = 4;
```

### Core Functions

#### create_pool
Creates new liquidity pool for token pair
```move
public fun create_pool<CoinTypeA: key + store, CoinTypeB: key + store>(
    fee_tier: u256
): Object<LiquidityPool<CoinTypeA, CoinTypeB>>
```

#### add_liquidity
Add liquidity to pool with slippage protection
```move
public fun add_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
    pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
    coin_a: Coin<CoinTypeA>,
    coin_b: Coin<CoinTypeB>,
    min_a: u256,
    min_b: u256,
): bool
```

#### remove_liquidity
Remove liquidity to pool with slippage protection
```move
public fun remove_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
    pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
    amount_a: u256,
    amount_b: u256
): bool
```


#### swap
Swap tokens with slippage protection
```move
public fun swap<CoinTypeA: key + store, CoinTypeB: key + store>(
    pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
    coin_in: Coin<CoinTypeA>,
    min_out: u256,
): Coin<CoinTypeB>
```

## Safety Features

- **Minimum Liquidity Lock**: Initial liquidity providers must provide minimum amounts to prevent manipulation
- **Slippage Protection**: Users can specify minimum output amounts for swaps
- **Overflow Protection**: Safe math operations to prevent numeric overflow/underflow
- **Constant Product Invariant**: Ensures k = x * y is maintained after each trade
- **Input Validation**: 
  - Non-zero amounts
  - Valid fee tiers
  - Sufficient balances
- **Balance Verification**: Pre and post-trade balance checks
- **Front-running Mitigation**: Time-weighted price calculations (planned)

## Usage

1. Create pool for token pair
2. Add initial liquidity
3. Users can:
   - Add liquidity
   - Swap tokens
   - Remove liquidity (to be implemented)

## Formula

- Swap fee: 0.3%
- Constant product: k = x * y
- Output amount: (y * Δx) / (x + Δx)
- Price impact increases with larger swaps

## License

Apache-2.0