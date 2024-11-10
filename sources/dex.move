module dex::dex {

    use moveos_std::object::{Self, Object};
    use rooch_framework::coin::{Self, Coin};
    use rooch_framework::coin_store::{Self, CoinStore};


    // Constants
    const FEE_NUMERATOR: u256 = 3; 
    const FEE_DENOMINATOR: u256 = 1000;
    const MINIMUM_LIQUIDITY: u256 = 1000;

    // Error codes  
    const ERROR_ZERO_AMOUNT: u64 = 1;
    const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 2;
    const ERROR_SLIPPAGE: u64 = 3;
    const ERROR_INVALID_RATIO: u64 = 4;

    struct LiquidityPool<phantom CoinTypeA: key + store, phantom CoinTypeB: key + store> has key, store {
        coin_store_a: Object<CoinStore<CoinTypeA>>,
        coin_store_b: Object<CoinStore<CoinTypeB>>, 
        total_supply: u256,
        minimum_liquidity: u256,
    }

    public fun create_pool<CoinTypeA: key + store, CoinTypeB: key + store>(): Object<LiquidityPool<CoinTypeA, CoinTypeB>> {
        let coin_store_a = coin_store::create_coin_store<CoinTypeA>();
        let coin_store_b = coin_store::create_coin_store<CoinTypeB>();
        
        let pool = LiquidityPool {
            coin_store_a,
            coin_store_b,
            total_supply: 0,
            minimum_liquidity: MINIMUM_LIQUIDITY,
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
        // Input validation
        let amount_a = coin::value(&coin_a);
        let amount_b = coin::value(&coin_b);
        assert!(amount_a > 0 && amount_b > 0, ERROR_ZERO_AMOUNT);
        assert!(amount_a >= min_a && amount_b >= min_b, ERROR_SLIPPAGE);

        let pool_mut = object::borrow_mut(pool);
        let reserve_a = coin_store::balance(&pool_mut.coin_store_a);
        let reserve_b = coin_store::balance(&pool_mut.coin_store_b);

        // First liquidity provision
        if (pool_mut.total_supply == 0) {
            assert!(amount_a >= pool_mut.minimum_liquidity && amount_b >= pool_mut.minimum_liquidity, ERROR_INSUFFICIENT_LIQUIDITY);
            pool_mut.total_supply = amount_a;
        } else {
            // Check ratio for subsequent deposits
            let ratio_a = (amount_a * FEE_DENOMINATOR) / reserve_a;
            let ratio_b = (amount_b * FEE_DENOMINATOR) / reserve_b;
            assert!(ratio_a > 0 && ratio_b > 0 && (ratio_a * 99 <= ratio_b * 100) && (ratio_b * 99 <= ratio_a * 100), ERROR_INVALID_RATIO);
            
            pool_mut.total_supply = pool_mut.total_supply + ((amount_a * pool_mut.total_supply) / reserve_a);
        };

        coin_store::deposit(&mut pool_mut.coin_store_a, coin_a);
        coin_store::deposit(&mut pool_mut.coin_store_b, coin_b);

        true
    }

     public fun swap<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        coin_in: Coin<CoinTypeA>,
        min_out: u256,
    ): Coin<CoinTypeB> {
        // Input validation
        let amount_in = coin::value(&coin_in);
        assert!(amount_in > 0, ERROR_ZERO_AMOUNT);

        let pool_mut = object::borrow_mut(pool);
        
        // Get reserves
        let reserve_a = coin_store::balance(&pool_mut.coin_store_a);
        let reserve_b = coin_store::balance(&pool_mut.coin_store_b);
        assert!(reserve_a > 0 && reserve_b > 0, ERROR_INSUFFICIENT_LIQUIDITY);

        // Calculate output amount with fee
        let amount_in_with_fee = amount_in * (FEE_DENOMINATOR - FEE_NUMERATOR);
        let numerator = amount_in_with_fee * reserve_b;
        let denominator = (reserve_a * FEE_DENOMINATOR) + amount_in_with_fee;
        
        // Safe math checks
        assert!(denominator > 0, ERROR_INSUFFICIENT_LIQUIDITY);
        let amount_out = numerator / denominator;
        
        // Check minimum output
        assert!(amount_out >= min_out, ERROR_SLIPPAGE);
        assert!(amount_out < reserve_b, ERROR_INSUFFICIENT_LIQUIDITY);

        // Constant product check
        let reserve_a_after = reserve_a + amount_in;
        let reserve_b_after = reserve_b - amount_out;
        assert!(
            reserve_a_after * reserve_b_after >= reserve_a * reserve_b,
            ERROR_INVALID_RATIO
        );

        // Execute swap
        coin_store::deposit(&mut pool_mut.coin_store_a, coin_in);
        coin_store::withdraw(&mut pool_mut.coin_store_b, amount_out)
    }

    public fun remove_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        amount_a: u256,
        amount_b: u256
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let pool_mut = object::borrow_mut(pool);
        let coin_a = coin_store::withdraw(&mut pool_mut.coin_store_a, amount_a);
        let coin_b = coin_store::withdraw(&mut pool_mut.coin_store_b, amount_b);
        (coin_a, coin_b)
    }

    public fun get_balances<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &Object<LiquidityPool<CoinTypeA, CoinTypeB>>
    ): (u256, u256) {
        let pool_ref = object::borrow(pool);
        (
            coin_store::balance(&pool_ref.coin_store_a),
            coin_store::balance(&pool_ref.coin_store_b)
        )
    }
}