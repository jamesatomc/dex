module dex::dex {
    use moveos_std::object::{Self, Object};
    use rooch_framework::coin::{Self as coin, Coin};
    use rooch_framework::timestamp;
    use rooch_framework::account;
    use rooch_framework::coin_store::{Self, CoinStore};
    use moveos_std::event;
    use moveos_std::tx_context;

    // Essential constants
    const FEE_TIER_LOW: u256 = 1;    // 0.1%
    const FEE_TIER_MEDIUM: u256 = 5;  // 0.5%
    const FEE_TIER_HIGH: u256 = 10;   // 1.0%
    const FEE_DENOMINATOR: u256 = 1000;

    // Core error codes
    const ERROR_ZERO_AMOUNT: u64 = 1;
    const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 2;
    const ERROR_INVALID_FEE_TIER: u64 = 3;
    const ERROR_UNAUTHORIZED: u64 = 4;



    // Core event with proper fields
    struct SwapEvent<phantom CoinTypeA, phantom CoinTypeB> has copy, drop, store {
        amount_in: u256,
        amount_out: u256,
        trader: address,
        fee_amount: u256
    }

    // Safe pool state
    struct PoolState has store {
        paused: bool,
        admin: address,
        last_updated: u256
    }

    // Initialize module
    fun init() { }

    // Helper function with proper validation
    fun validate_fee_tier(fee_tier: u256): bool {
        if (fee_tier == FEE_TIER_LOW || 
            fee_tier == FEE_TIER_MEDIUM || 
            fee_tier == FEE_TIER_HIGH) {
            true
        } else {
            false
        }
    }

    // Fee tier validation with assertion
    public entry fun assert_fee_tier(fee_tier: u256) {
        assert!(validate_fee_tier(fee_tier), ERROR_INVALID_FEE_TIER);
    }

    // Simplified pool struct
    struct LiquidityPool<phantom CoinTypeA: key + store, phantom CoinTypeB: key + store> has key, store {
        coin_store_a: Object<CoinStore<CoinTypeA>>,
        coin_store_b: Object<CoinStore<CoinTypeB>>,
        total_supply: u256,
        fee_tier: u256,
        state: PoolState
    }

    struct LiquidityEvent<phantom CoinTypeA, phantom CoinTypeB> has copy, drop, store {
        provider: address,
        amount_a: u256,
        amount_b: u256
    }

    // Pool creation function
    public entry fun create_pool<CoinTypeA: key + store, CoinTypeB: key + store>(
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
                admin: tx_context::sender(),
                last_updated: 0
            }
        };

        object::new(pool)
    }

    // Add events
    struct LiquidityAddedEvent<phantom CoinTypeA, phantom CoinTypeB> has copy, drop, store {
        provider: address,
        amount_a: u256,
        amount_b: u256
    }

    // Fixed add_liquidity function
    public entry fun add_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>
    ): u256 {
        let amount_a = coin::value(&coin_a);
        let amount_b = coin::value(&coin_b);
        assert!(amount_a > 0 && amount_b > 0, ERROR_ZERO_AMOUNT);

        let pool_mut = object::borrow_mut(pool);
        assert!(!pool_mut.state.paused, ERROR_UNAUTHORIZED);

        // Update supply
        pool_mut.total_supply = pool_mut.total_supply + amount_a;

        // Deposit tokens
        coin_store::deposit(&mut pool_mut.coin_store_a, coin_a);
        coin_store::deposit(&mut pool_mut.coin_store_b, coin_b);

        // Emit event
        event::emit(LiquidityEvent<CoinTypeA, CoinTypeB> {
            provider: tx_context::sender(),
            amount_a,
            amount_b
        });

        amount_a
    }

    // Updated internal_remove_liquidity function
    fun internal_remove_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        amount_a: u256,
        amount_b: u256
    ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let pool_mut = object::borrow_mut(pool);
        assert!(!pool_mut.state.paused, ERROR_UNAUTHORIZED);
        assert!(amount_a > 0 && amount_b > 0, ERROR_ZERO_AMOUNT);
        
        pool_mut.total_supply = pool_mut.total_supply - amount_a;
        
        let coin_a = coin_store::withdraw(&mut pool_mut.coin_store_a, amount_a);
        let coin_b = coin_store::withdraw(&mut pool_mut.coin_store_b, amount_b);

        event::emit(LiquidityEvent<CoinTypeA, CoinTypeB> {
            provider: account::get_signer_address(),
            amount_a,
            amount_b
        });

        (coin_a, coin_b)
    }

    // Updated remove_liquidity entry function
    public entry fun remove_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        amount_a: u256,
        amount_b: u256
    ) {
        let (coin_a, coin_b) = internal_remove_liquidity(pool, amount_a, amount_b);
        let sender = account::get_signer_address();
        coin::deposit(sender, coin_a);
        coin::deposit(sender, coin_b);
    }

    // Internal swap function
    fun internal_swap<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        amount_in: u256,
        min_out: u256
    ): u256 {
        let pool_mut = object::borrow_mut(pool);
        assert!(!pool_mut.state.paused, ERROR_UNAUTHORIZED);
        assert!(amount_in > 0, ERROR_ZERO_AMOUNT);

        let out_amount = amount_in * (FEE_DENOMINATOR - pool_mut.fee_tier) / FEE_DENOMINATOR;
        assert!(out_amount >= min_out, ERROR_INSUFFICIENT_LIQUIDITY);

        let fee_amount = amount_in * pool_mut.fee_tier / FEE_DENOMINATOR;

        event::emit(SwapEvent<CoinTypeA, CoinTypeB> {
            amount_in,
            amount_out: out_amount,
            trader: tx_context::sender(),
            fee_amount
        });

        out_amount
    }

    // Updated swap function
    public entry fun swap<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
        amount_in: u256,
        min_out: u256
    ) {
        let sender = account::get_signer_address();
        let coin_in = coin::withdraw_from_sender<CoinTypeA>(amount_in);
        
        let pool_mut = object::borrow_mut(pool);
        coin_store::deposit(&mut pool_mut.coin_store_a, coin_in);
        
        let out_amount = internal_swap<CoinTypeA, CoinTypeB>(pool, amount_in, min_out);
        let coin_out = coin_store::withdraw(&mut pool_mut.coin_store_b, out_amount);
        
        coin::deposit(sender, coin_out);
    }

    // Updated admin functions
    public entry fun pause_pool<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>
    ) {
        let pool_mut = object::borrow_mut(pool);
        assert!(pool_mut.state.admin == account::get_signer_address(), ERROR_UNAUTHORIZED);
        pool_mut.state.paused = true;
        pool_mut.state.last_updated = timestamp::now_seconds();
    }

    public entry fun unpause_pool<CoinTypeA: key + store, CoinTypeB: key + store>(
        pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>
    ) {
        let pool_mut = object::borrow_mut(pool);
        assert!(pool_mut.state.admin == account::get_signer_address(), ERROR_UNAUTHORIZED);
        pool_mut.state.paused = false;
        pool_mut.state.last_updated = timestamp::now_seconds();
    }
}