module dex::dex {
    use moveos_std::object::{Self, Object};
    use rooch_framework::coin::{Self, Coin};
    use rooch_framework::coin_store::{Self, CoinStore};
    use moveos_std::event;
    use rooch_framework::account;

    // Fee tier constants
    const FEE_TIER_LOW: u256 = 1;    // 0.1%
    const FEE_TIER_MEDIUM: u256 = 5;  // 0.5%
    const FEE_TIER_HIGH: u256 = 10;   // 1.0%
    const FEE_DENOMINATOR: u256 = 1000;
    
    const MINIMUM_LIQUIDITY: u256 = 1000;
    const BASIS_POINTS: u256 = 10000;

    // Error codes
    const ERROR_ZERO_AMOUNT: u64 = 1;
    const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 2;
    const ERROR_SLIPPAGE: u64 = 3;
    const ERROR_INVALID_RATIO: u64 = 4;
    const ERROR_EXCEEDS_TOTAL_SUPPLY: u64 = 5;
    const ERROR_INVALID_FEE_TIER: u64 = 6;

    // Events remain the same
    struct LiquidityAdded<phantom CoinTypeA, phantom CoinTypeB> has copy, drop, store {
        provider: address,
        amount_a: u256,
        amount_b: u256,
        total_supply: u256,
    }

    struct LiquidityRemoved<phantom CoinTypeA, phantom CoinTypeB> has copy, drop, store {
        provider: address,
        amount_a: u256,
        amount_b: u256,
        total_supply: u256,
    }

    struct Swap<phantom CoinTypeA, phantom CoinTypeB> has copy, drop, store {
        trader: address,
        amount_in: u256,
        amount_out: u256,
    }

    struct LiquidityPool<phantom CoinTypeA: key + store, phantom CoinTypeB: key + store> has key, store {
        coin_store_a: Object<CoinStore<CoinTypeA>>,
        coin_store_b: Object<CoinStore<CoinTypeB>>,
        total_supply: u256,
        minimum_liquidity: u256,
        fee_tier: u256,  // Added fee tier field
    }

    public fun create_pool<CoinTypeA: key + store, CoinTypeB: key + store>(
        fee_tier: u256
    ): Object<LiquidityPool<CoinTypeA, CoinTypeB>> {
        // Validate fee tier
        assert!(
            fee_tier == FEE_TIER_LOW || 
            fee_tier == FEE_TIER_MEDIUM || 
            fee_tier == FEE_TIER_HIGH,
            ERROR_INVALID_FEE_TIER
        );

        let coin_store_a = coin_store::create_coin_store<CoinTypeA>();
        let coin_store_b = coin_store::create_coin_store<CoinTypeB>();
        
        let pool = LiquidityPool {
            coin_store_a,
            coin_store_b,
            total_supply: 0,
            minimum_liquidity: MINIMUM_LIQUIDITY,
            fee_tier,
        };

        object::new(pool)
    }

    public fun add_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,
        min_a: u256,
        min_b: u256,
    ): bool {
        let amount_a = coin::value(&coin_a);
        let amount_b = coin::value(&coin_b);
        assert!(amount_a > 0 && amount_b > 0, ERROR_ZERO_AMOUNT);
        assert!(amount_a >= min_a && amount_b >= min_b, ERROR_SLIPPAGE);

        let pool_ref = object::borrow(pool);
        let reserve_a = coin_store::balance(&pool_ref.coin_store_a);
        let reserve_b = coin_store::balance(&pool_ref.coin_store_b);

        let pool_mut = object::borrow_mut(pool);
        if (pool_mut.total_supply == 0) {
            assert!(amount_a >= pool_mut.minimum_liquidity && amount_b >= pool_mut.minimum_liquidity, ERROR_INSUFFICIENT_LIQUIDITY);
            pool_mut.total_supply = amount_a;
        } else {
            let ratio_a = (amount_a * FEE_DENOMINATOR) / reserve_a;
            let ratio_b = (amount_b * FEE_DENOMINATOR) / reserve_b;
            assert!(ratio_a > 0 && ratio_b > 0 && (ratio_a * 99 <= ratio_b * 100) && (ratio_b * 99 <= ratio_a * 100), ERROR_INVALID_RATIO);
            
            pool_mut.total_supply = pool_mut.total_supply + ((amount_a * pool_mut.total_supply) / reserve_a);
        };

        coin_store::deposit(&mut pool_mut.coin_store_a, coin_a);
        coin_store::deposit(&mut pool_mut.coin_store_b, coin_b);

        // event::emit(LiquidityAdded<CoinTypeA, CoinTypeB> {
        //     provider: account::get_signer_address(),
        //     amount_a,
        //     amount_b,
        //     total_supply: pool_mut.total_supply,
        // });

        true
    }

    public fun remove_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        amount_a: u256,
        amount_b: u256
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let pool_ref = object::borrow(pool);
        let reserve_a = coin_store::balance(&pool_ref.coin_store_a);
        let reserve_b = coin_store::balance(&pool_ref.coin_store_b);
        
        assert!(amount_a > 0 && amount_b > 0, ERROR_ZERO_AMOUNT);
        assert!(amount_a <= reserve_a && amount_b <= reserve_b, ERROR_INSUFFICIENT_LIQUIDITY);
        assert!((amount_a * reserve_b) == (amount_b * reserve_a), ERROR_INVALID_RATIO);
    
        let pool_mut = object::borrow_mut(pool);
        let share = (amount_a * BASIS_POINTS) / reserve_a;
        
        // Add check for exceeding total supply
        let supply_to_remove = (pool_mut.total_supply * share) / BASIS_POINTS;
        assert!(supply_to_remove <= pool_mut.total_supply, ERROR_EXCEEDS_TOTAL_SUPPLY);
        
        pool_mut.total_supply = pool_mut.total_supply - supply_to_remove;
        
        let coin_a = coin_store::withdraw(&mut pool_mut.coin_store_a, amount_a);
        let coin_b = coin_store::withdraw(&mut pool_mut.coin_store_b, amount_b);
    
        (coin_a, coin_b)
    }

    public fun swap<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        coin_in: Coin<CoinTypeA>,
        min_out: u256,
    ): Coin<CoinTypeB> {
        let amount_in = coin::value(&coin_in);
        assert!(amount_in > 0, ERROR_ZERO_AMOUNT);

        let pool_ref = object::borrow(pool);
        let reserve_a = coin_store::balance(&pool_ref.coin_store_a);
        let reserve_b = coin_store::balance(&pool_ref.coin_store_b);
        assert!(reserve_a > 0 && reserve_b > 0, ERROR_INSUFFICIENT_LIQUIDITY);

        // Use pool's fee tier for calculation
        let amount_in_with_fee = amount_in * (FEE_DENOMINATOR - pool_ref.fee_tier);
        let numerator = amount_in_with_fee * reserve_b;
        let denominator = (reserve_a * FEE_DENOMINATOR) + amount_in_with_fee;
        
        assert!(denominator > 0, ERROR_INSUFFICIENT_LIQUIDITY);
        let amount_out = numerator / denominator;
        
        assert!(amount_out >= min_out, ERROR_SLIPPAGE);
        assert!(amount_out < reserve_b, ERROR_INSUFFICIENT_LIQUIDITY);

        let reserve_a_after = reserve_a + amount_in;
        let reserve_b_after = reserve_b - amount_out;
        assert!(reserve_a_after * reserve_b_after >= reserve_a * reserve_b, ERROR_INVALID_RATIO);

        let pool_mut = object::borrow_mut(pool);
        coin_store::deposit(&mut pool_mut.coin_store_a, coin_in);
        let coin_out = coin_store::withdraw(&mut pool_mut.coin_store_b, amount_out);

        // event::emit(Swap<CoinTypeA, CoinTypeB> {
        //     trader: account::get_signer_address(),
        //     amount_in,
        //     amount_out,
        // });

        coin_out
    }
}