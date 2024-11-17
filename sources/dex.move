// /// This module implements a decentralized exchange (DEX) with liquidity pools and swap functionality.
// /// It allows users to create liquidity pools, add liquidity, remove liquidity, and perform token swaps.
// ///
// /// # Constants
// /// - `FEE_TIER_LOW`: Low fee tier (0.1%)
// /// - `FEE_TIER_MEDIUM`: Medium fee tier (0.5%)
// /// - `FEE_TIER_HIGH`: High fee tier (1.0%)
// /// - `FEE_DENOMINATOR`: Denominator for fee calculation
// /// - `MINIMUM_LIQUIDITY`: Minimum liquidity required for a pool
// /// - `BASIS_POINTS`: Basis points for calculations
// ///
// /// # Error Codes
// /// - `ERROR_ZERO_AMOUNT`: Error code for zero amount
// /// - `ERROR_INSUFFICIENT_LIQUIDITY`: Error code for insufficient liquidity
// /// - `ERROR_SLIPPAGE`: Error code for slippage
// /// - `ERROR_INVALID_RATIO`: Error code for invalid ratio
// /// - `ERROR_EXCEEDS_TOTAL_SUPPLY`: Error code for exceeding total supply
// /// - `ERROR_INVALID_FEE_TIER`: Error code for invalid fee tier
// /// - `ERROR_INVALID_FEE`: Error code for invalid fee
// /// - `ERROR_SWAP_CALCULATION`: Error code for swap calculation error
// ///
// /// # Events
// /// - `LiquidityAdded`: Event emitted when liquidity is added
// /// - `LiquidityRemoved`: Event emitted when liquidity is removed
// /// - `Swap`: Event emitted when a swap is performed
// ///
// /// # Structs
// /// - `LiquidityPool`: Represents a liquidity pool with two coin types
// /// - `TokenA`: Represents a concrete token type A
// /// - `TokenB`: Represents a concrete token type B
// /// - `SwapEvent`: Represents a swap event with details of the swap
// ///
// /// # Functions
// /// - `create_pool`: Creates a new liquidity pool with a specified fee tier
// /// - `add_liquidity`: Adds liquidity to a specified pool
// /// - `remove_liquidity`: Removes liquidity from a specified pool
// /// - `swap`: Performs a token swap in a specified pool
// /// - `init`: Initializes the module with default values

// module dex::dex {
//     use moveos_std::object::{Self, Object};  // Updated import
//     // use moveos_std::address;
//     use rooch_framework::coin::{Self, Coin};
//     use rooch_framework::coin_store::{Self, CoinStore};
//     use moveos_std::event;
//     use moveos_std::tx_context::{Self};
//     // use std::option;
//     // use std::string;

//     // Fee tier constants
//     const FEE_TIER_LOW: u256 = 1;    // 0.1%
//     const FEE_TIER_MEDIUM: u256 = 5;  // 0.5%
//     const FEE_TIER_HIGH: u256 = 10;   // 1.0%
//     const FEE_DENOMINATOR: u256 = 1000;
    
//     const MINIMUM_LIQUIDITY: u256 = 1000;
//     const BASIS_POINTS: u256 = 10000;
//     const MAX_TRANSACTION_SIZE: u256 = 1000000; // 1M tokens
//     const MAX_PRICE_IMPACT: u256 = 300; // 3%

//     // Error codes
//     const ERROR_ZERO_AMOUNT: u64 = 1;
//     const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 2;
//     const ERROR_SLIPPAGE: u64 = 3;
//     const ERROR_INVALID_RATIO: u64 = 4;
//     const ERROR_EXCEEDS_TOTAL_SUPPLY: u64 = 5;
//     const ERROR_INVALID_FEE_TIER: u64 = 6;
//     const ERROR_INVALID_FEE: u64 = 7;
//     const ERROR_SWAP_CALCULATION: u64 = 8;
//     // const ERROR_MATH: u64 = 9;
//     const ERROR_UNAUTHORIZED: u64 = 10;
//     const ERROR_PAUSED: u64 = 11;
//     const ERROR_MAX_IMPACT: u64 = 12;
    
//     // Events remain the same
//     struct LiquidityAdded<phantom CoinTypeA, phantom CoinTypeB> has copy, drop, store {
//         provider: address,
//         amount_a: u256,
//         amount_b: u256,
//         total_supply: u256,
//     }

//     // New event for liquidity removal
//     struct LiquidityRemoved<phantom CoinTypeA, phantom CoinTypeB> has copy, drop, store {
//         provider: address,
//         amount_a: u256,
//         amount_b: u256,
//         total_supply: u256,
//     }

//     // Swap event remains the same
//     struct Swap<phantom CoinTypeA, phantom CoinTypeB> has copy, drop, store {
//         trader: address,
//         amount_in: u256,
//         amount_out: u256,
//     }

//     // Pool state tracking
//     struct PoolState has store {
//         paused: bool,
//         admin: address,
//         last_price: u256,
//     }

//     // Liquidity pool struct remains the same
//     struct LiquidityPool<phantom CoinTypeA: key + store, phantom CoinTypeB: key + store> has key, store {
//         coin_store_a: Object<CoinStore<CoinTypeA>>,
//         coin_store_b: Object<CoinStore<CoinTypeB>>,
//         total_supply: u256,
//         minimum_liquidity: u256,  
//         fee_tier: u256,
//         state: PoolState
//     }

//     // Constants for u256 limits
//     const U256_MAX: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

//     // Additional error codes
//     const ERROR_OVERFLOW: u64 = 13;
//     const ERROR_UNDERFLOW: u64 = 14;
//     const ERROR_DIVIDE_BY_ZERO: u64 = 15;
  
//     // Safe math functions
//     public fun add(a: u256, b: u256): u256 {
//         // Check for overflow before addition
//         assert!(a <= U256_MAX - b, ERROR_OVERFLOW);
//         let result = a + b;
//         // Verify the result
//         assert!(result >= a && result >= b, ERROR_OVERFLOW);
//         result
//     }
    

//     public fun sub(a: u256, b: u256): u256 {
//         // Check for underflow
//         assert!(a >= b, ERROR_UNDERFLOW);
//         let result = a - b;
//         // Verify the result
//         assert!(result <= a, ERROR_UNDERFLOW);
//         result
//     }

//     public fun mul(a: u256, b: u256): u256 {
//         if (a == 0 || b == 0) return 0;
//         // Check for overflow before multiplication
//         assert!(a <= U256_MAX / b, ERROR_OVERFLOW);
//         let result = a * b;
//         // Verify the result
//         assert!(result / a == b, ERROR_OVERFLOW);
//         result
//     }

//     public fun div(a: u256, b: u256): u256 {
//         // Check for divide by zero
//         assert!(b > 0, ERROR_DIVIDE_BY_ZERO);
//         a / b
//     }


//     // Define concrete types for initialization
//     struct TokenA has key, store, drop {}
//     struct TokenB has key, store, drop {}

//     // Swap event structure
//     struct SwapEvent<phantom CoinTypeA, phantom CoinTypeB> has copy, drop, store {
//         amount_in: u256,
//         amount_out: u256,
//         fee_amount: u256,
//         trader: address
//     }

//     // Create pool function remains the same
//     public fun create_pool<CoinTypeA: key + store, CoinTypeB: key + store>(
//         fee_tier: u256,
//     ): Object<LiquidityPool<CoinTypeA, CoinTypeB>> {
//         assert!(
//             fee_tier == FEE_TIER_LOW || 
//             fee_tier == FEE_TIER_MEDIUM || 
//             fee_tier == FEE_TIER_HIGH,
//             ERROR_INVALID_FEE_TIER
//         );

//         let pool = LiquidityPool {
//             coin_store_a: coin_store::create_coin_store<CoinTypeA>(),
//             coin_store_b: coin_store::create_coin_store<CoinTypeB>(),
//             total_supply: 0,
//             minimum_liquidity: MINIMUM_LIQUIDITY,
//             fee_tier,
//             state: PoolState {
//                 paused: false,
//                 admin: tx_context::sender(),
//                 last_price: 0
//             }
//         };

//         object::new(pool)
//     }

//     // Add this at the top of the module with other struct definitions
//     struct LiquidityAddedEvent<phantom CoinTypeA, phantom CoinTypeB> has copy, drop {
//         amount_a: u256,
//         amount_b: u256,
//         liquidity_minted: u256,
//         provider: address
//     }

//     // Helper function to calculate initial liquidity
//     fun calculate_initial_liquidity(
//         amount_a: u256,
//         amount_b: u256,
//         minimum_liquidity: u256
//     ): u256 {
//         assert!(
//             amount_a >= minimum_liquidity && amount_b >= minimum_liquidity,
//             ERROR_INSUFFICIENT_LIQUIDITY
//         );
//         amount_a // Using amount_a as initial liquidity
//     }
    
//     // Helper function to calculate additional liquidity
//     fun calculate_additional_liquidity(
//         amount_a: u256,
//         reserve_a: u256,
//         total_supply: u256
//     ): u256 {
//         (amount_a * total_supply) / reserve_a
//     }
    
//     // Helper function to validate ratios
//     fun validate_ratios(
//         amount_a: u256,
//         amount_b: u256,
//         reserve_a: u256,
//         reserve_b: u256
//     ) {
//         let ratio_a = (amount_a * FEE_DENOMINATOR) / reserve_a;
//         let ratio_b = (amount_b * FEE_DENOMINATOR) / reserve_b;
//         assert!(
//             ratio_a > 0 && ratio_b > 0 &&
//             (ratio_a * 99 <= ratio_b * 100) &&
//             (ratio_b * 99 <= ratio_a * 100),
//             ERROR_INVALID_RATIO
//         );
//     }
    
//     // Updated add_liquidity function
//     public fun add_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
//         pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
//         coin_a: Coin<CoinTypeA>,
//         coin_b: Coin<CoinTypeB>,
//         min_a: u256,
//         min_b: u256,
//     ): u256 {  // Return actual liquidity added
//         let amount_a = coin::value(&coin_a);
//         let amount_b = coin::value(&coin_b);
//         assert!(amount_a > 0 && amount_b > 0, ERROR_ZERO_AMOUNT);
//         assert!(amount_a >= min_a && amount_b >= min_b, ERROR_SLIPPAGE);
    
//         let pool_ref = object::borrow(pool);
//         let reserve_a = coin_store::balance(&pool_ref.coin_store_a);
//         let reserve_b = coin_store::balance(&pool_ref.coin_store_b);
    
//         let pool_mut = object::borrow_mut(pool);
//         let liquidity_added: u256;
    
//         if (pool_mut.total_supply == 0) {
//             liquidity_added = calculate_initial_liquidity(
//                 amount_a,
//                 amount_b,
//                 pool_mut.minimum_liquidity
//             );
//             pool_mut.total_supply = liquidity_added;
//         } else {
//             validate_ratios(amount_a, amount_b, reserve_a, reserve_b);
//             liquidity_added = calculate_additional_liquidity(
//                 amount_a,
//                 reserve_a,
//                 pool_mut.total_supply
//             );
//             pool_mut.total_supply = pool_mut.total_supply + liquidity_added;
//         };
    
//         coin_store::deposit(&mut pool_mut.coin_store_a, coin_a);
//         coin_store::deposit(&mut pool_mut.coin_store_b, coin_b);
    
//         // Emit liquidity added event
//         event::emit(LiquidityAddedEvent<CoinTypeA, CoinTypeB> {
//             amount_a,
//             amount_b,
//             liquidity_minted: liquidity_added,
//             provider: tx_context::sender()
//         });
    
//         liquidity_added
//     }

//     // Remove liquidity function remains the same
//     public fun remove_liquidity<CoinTypeA: key + store, CoinTypeB: key + store>(
//         pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
//         amount_a: u256,
//         amount_b: u256
//     ): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
//         let pool_ref = object::borrow(pool);
//         let reserve_a = coin_store::balance(&pool_ref.coin_store_a);
//         let reserve_b = coin_store::balance(&pool_ref.coin_store_b);
        
//         assert!(amount_a > 0 && amount_b > 0, ERROR_ZERO_AMOUNT);
//         assert!(amount_a <= reserve_a && amount_b <= reserve_b, ERROR_INSUFFICIENT_LIQUIDITY);
//         assert!((amount_a * reserve_b) == (amount_b * reserve_a), ERROR_INVALID_RATIO);
    
//         let pool_mut = object::borrow_mut(pool);
//         let share = (amount_a * BASIS_POINTS) / reserve_a;
        
//         // Add check for exceeding total supply
//         let supply_to_remove = (pool_mut.total_supply * share) / BASIS_POINTS;
//         assert!(supply_to_remove <= pool_mut.total_supply, ERROR_EXCEEDS_TOTAL_SUPPLY);
        
//         pool_mut.total_supply = pool_mut.total_supply - supply_to_remove;
        
//         let coin_a = coin_store::withdraw(&mut pool_mut.coin_store_a, amount_a);
//         let coin_b = coin_store::withdraw(&mut pool_mut.coin_store_b, amount_b);

//         (coin_a, coin_b)
//     }

//     // Helper function to calculate swap amounts
//     fun calculate_swap_amounts<CoinTypeA, CoinTypeB>(
//         amount_in: u256,
//         reserve_a: u256,
//         reserve_b: u256,
//         fee_tier: u256
//     ): (u256, u256) {
//         let amount_in_with_fee = amount_in * (FEE_DENOMINATOR - fee_tier);
//         let fee_amount = amount_in * fee_tier / FEE_DENOMINATOR;
        
//         let numerator = amount_in_with_fee * reserve_b;
//         let denominator = (reserve_a * FEE_DENOMINATOR) + amount_in_with_fee;
//         assert!(denominator > 0, ERROR_SWAP_CALCULATION);
        
//         let amount_out = numerator / denominator;
//         (amount_out, fee_amount)
//     }
    
//     // Helper function to verify constant product formula
//     fun verify_constant_product(
//         reserve_a: u256,
//         reserve_b: u256,
//         reserve_a_after: u256,
//         reserve_b_after: u256
//     ) {
//         assert!(reserve_a_after * reserve_b_after >= reserve_a * reserve_b, ERROR_INVALID_RATIO);
//     }
//     // Swap function remains the same
//     public fun swap<CoinTypeA: key + store, CoinTypeB: key + store>(
//         pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
//         coin_in: Coin<CoinTypeA>,
//         min_out: u256,

//     ): Coin<CoinTypeB> {
//         let pool_ref = object::borrow(pool);
//         // Check if pool is not paused
//         assert!(!pool_ref.state.paused, ERROR_PAUSED);
    
//         let amount_in = coin::value(&coin_in);
//         // Basic checks
//         assert!(amount_in > 0, ERROR_ZERO_AMOUNT);
//         assert!(amount_in <= MAX_TRANSACTION_SIZE, ERROR_MAX_IMPACT);
    
//         let reserve_a = coin_store::balance(&pool_ref.coin_store_a);
//         let reserve_b = coin_store::balance(&pool_ref.coin_store_b);
//         assert!(reserve_a > 0 && reserve_b > 0, ERROR_INSUFFICIENT_LIQUIDITY);
//         assert!(pool_ref.fee_tier <= FEE_DENOMINATOR, ERROR_INVALID_FEE);
    
//         // Price impact check
//         let price_impact = mul(amount_in, BASIS_POINTS) / reserve_a;
//         assert!(price_impact <= MAX_PRICE_IMPACT, ERROR_MAX_IMPACT);
    
//         // Calculate swap amounts using safe math
//         let (amount_out, fee_amount) = calculate_swap_amounts<CoinTypeA, CoinTypeB>(
//             amount_in,
//             reserve_a,
//             reserve_b,
//             pool_ref.fee_tier
//         );
    
//         assert!(amount_out >= min_out, ERROR_SLIPPAGE);
//         assert!(amount_out < reserve_b, ERROR_INSUFFICIENT_LIQUIDITY);
    
//         // Verify constant product using safe math
//         verify_constant_product(
//             reserve_a,
//             reserve_b,
//             add(reserve_a, amount_in),
//             sub(reserve_b, amount_out)
//         );
    
//         let pool_mut = object::borrow_mut(pool);
        
//         // Update pool state
//         pool_mut.state.last_price = div(
//             mul(amount_in, BASIS_POINTS),
//             amount_out
//         );
    
//         let pool_mut = object::borrow_mut(pool);
//         coin_store::deposit(&mut pool_mut.coin_store_a, coin_in);
//         let coin_out = coin_store::withdraw(&mut pool_mut.coin_store_b, amount_out);

//         event::emit(SwapEvent<CoinTypeA, CoinTypeB> {
//             amount_in,
//             amount_out,
//             fee_amount,
//             trader: tx_context::sender()
//         });


//         coin_out
//     }

//     // Admin functions
//     public fun pause_pool<CoinTypeA: key + store, CoinTypeB: key + store>(
//         pool: &mut Object<LiquidityPool<CoinTypeA, CoinTypeB>>,
//     ) {
//         let pool_mut = object::borrow_mut(pool);
//         assert!(pool_mut.state.admin == tx_context::sender(), ERROR_UNAUTHORIZED);
//         pool_mut.state.paused = true;
//     }

//     fun init() {
//         let default_fee_tier = FEE_TIER_LOW;
//         let default_min_liquidity = MINIMUM_LIQUIDITY;
        
//         let pool = LiquidityPool<TokenA, TokenB> {
//             coin_store_a: coin_store::create_coin_store<TokenA>(),
//             coin_store_b: coin_store::create_coin_store<TokenB>(),
//             total_supply: 0,
//             minimum_liquidity: default_min_liquidity,
//             fee_tier: default_fee_tier,
//             state: PoolState { // Add missing state field
//                 paused: false,
//                 admin: tx_context::sender(),
//                 last_price: 0
//             }
//         };

//         let pool_obj = object::new(pool);
//         object::transfer(pool_obj, tx_context::sender());
//     }
    
//     public fun get_fee_tier<CoinTypeA: key + store, CoinTypeB: key + store>(
//         pool: &Object<LiquidityPool<CoinTypeA, CoinTypeB>>
//     ): u256 {
//         let pool_ref = object::borrow(pool);
//         pool_ref.fee_tier
//     }

//     public fun get_total_supply<CoinTypeA: key + store, CoinTypeB: key + store>(
//         pool: &Object<LiquidityPool<CoinTypeA, CoinTypeB>>
//     ): u256 {
//         let pool_ref = object::borrow(pool);
//         pool_ref.total_supply
//     }

//     #[test]
//     fun test_math_operations() {
//         assert!(add(1, 2) == 3, 1);
//         assert!(sub(5, 3) == 2, 2);
//         assert!(mul(4, 3) == 12, 3);
//         assert!(div(8, 2) == 4, 4);
//     }

//     #[test]
//     #[expected_failure(abort_code = ERROR_OVERFLOW)]
//     fun test_add_overflow() {
//         add(U256_MAX, 1);
//     }

//     #[test]
//     #[expected_failure(abort_code = ERROR_UNDERFLOW)]
//     fun test_sub_underflow() {
//         sub(1, 2);
//     }
// }