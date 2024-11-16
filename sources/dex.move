module dex::dex {
    use moveos_std::object::{Self, Object};
    use rooch_framework::coin::{Self, Coin};
    use rooch_framework::coin_store::{Self, CoinStore};
    use moveos_std::event;
    use moveos_std::tx_context;

    // Essential constants
    const FEE_TIER_LOW: u256 = 1;    // 0.1%
    const FEE_TIER_MEDIUM: u256 = 5;  // 0.5%
    const FEE_TIER_HIGH: u256 = 10;   // 1.0%
    const FEE_DENOMINATOR: u256 = 1000;
    const MINIMUM_LIQUIDITY: u256 = 1000;

    // Core error codes
    const ERROR_ZERO_AMOUNT: u64 = 1;
    const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 2;
    const ERROR_INVALID_FEE_TIER: u64 = 3;
    const ERROR_UNAUTHORIZED: u64 = 4;

    // Core event
    struct SwapEvent<phantom CoinTypeA, phantom CoinTypeB> has copy, drop, store {
        amount_in: u256,
        amount_out: u256,
        trader: address
    }

    // Core pool state
    struct PoolState has store {
        paused: bool,
        admin: address,
    }

    // Simplified pool struct
    struct LiquidityPool<phantom CoinTypeA: key + store, phantom CoinTypeB: key + store> has key, store {
        coin_store_a: Object<CoinStore<CoinTypeA>>,
        coin_store_b: Object<CoinStore<CoinTypeB>>,
        total_supply: u256,
        fee_tier: u256,
        state: PoolState
    }

    // Create new pool
    public fun create_pool<CoinTypeA: key + store, CoinTypeB: key + store>(
        fee_tier: u256,
    ): Object<LiquidityPool<CoinTypeA, CoinTypeB>> {
        assert!(
            fee_tier == FEE_TIER_LOW || 
            fee_tier == FEE_TIER_MEDIUM || 
            fee_tier == FEE_TIER_HIGH,
            ERROR_INVALID_FEE_TIER
        );

        let pool = LiquidityPool {
            coin_store_a: coin_store::create_coin_store<CoinTypeA>(),
            coin_store_b: coin_store::create_coin_store<CoinTypeB>(),
            total_supply: 0,
            fee_tier,
            state: PoolState {
                paused: false,
                admin: tx_context::sender()
            }
        };

        object::new(pool)
    }

    // Add liquidity
    public fun add_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
    ) {
        let amount_a = coin::value(&coin_a);
        let amount_b = coin::value(&coin_b);
        assert!(amount_a > 0 && amount_b > 0, ERROR_ZERO_AMOUNT);

        let pool_mut = object::borrow_mut(pool);
        pool_mut.total_supply = pool_mut.total_supply + amount_a;

        coin_store::deposit(&mut pool_mut.coin_store_a, coin_a);
        coin_store::deposit(&mut pool_mut.coin_store_b, coin_b);
    }

    // Remove liquidity 
    public fun remove_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        amount_a: u256,
        amount_b: u256
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let pool_mut = object::borrow_mut(pool);
        assert!(amount_a > 0 && amount_b > 0, ERROR_ZERO_AMOUNT);
        
        pool_mut.total_supply = pool_mut.total_supply - amount_a;
        
        let coin_a = coin_store::withdraw(&mut pool_mut.coin_store_a, amount_a);
        let coin_b = coin_store::withdraw(&mut pool_mut.coin_store_b, amount_b);

        (coin_a, coin_b)
    }

    // Basic swap
    public fun swap<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        coin_in: Coin<CoinTypeA>,
        min_out: u256,
    ): Coin<CoinTypeB> {
        let pool_ref = object::borrow(pool);
        assert!(!pool_ref.state.paused, ERROR_UNAUTHORIZED);

        let amount_in = coin::value(&coin_in);
        assert!(amount_in > 0, ERROR_ZERO_AMOUNT);

        let pool_mut = object::borrow_mut(pool);
        coin_store::deposit(&mut pool_mut.coin_store_a, coin_in);
        
        let out_amount = amount_in * (FEE_DENOMINATOR - pool_mut.fee_tier) / FEE_DENOMINATOR;
        assert!(out_amount >= min_out, ERROR_INSUFFICIENT_LIQUIDITY);
        
        let coin_out = coin_store::withdraw(&mut pool_mut.coin_store_b, out_amount);

        event::emit(SwapEvent<CoinTypeA, CoinTypeB> {
            amount_in,
            amount_out: out_amount,
            trader: tx_context::sender()
        });

        coin_out
    }

    // Basic admin function
    public fun pause_pool<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
    ) {
        let pool_mut = object::borrow_mut(pool);
        assert!(pool_mut.state.admin == tx_context::sender(), ERROR_UNAUTHORIZED);
        pool_mut.state.paused = true;
    }
}