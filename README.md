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
const FEE_NUMERATOR: u256 = 3;      // 0.3% fee
const FEE_DENOMINATOR: u256 = 1000;
const MINIMUM_LIQUIDITY: u256 = 1000;
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
public fun create_pool<CoinTypeA: key + store, CoinTypeB: key + store>(): Object<LiquidityPool<CoinTypeA, CoinTypeB>>
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

- Minimum liquidity requirement
- Slippage protection
- Safe math checks
- Constant product verification
- Input validation
- Balance checks

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