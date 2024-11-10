#[test_only]
module dex::dex_tests {
    use moveos_std::object;
    use dex::dex::{Self, TokenA, TokenB};


    #[test]
    fun test_create_pool_with_valid_fee_tiers() {
        // Test low fee tier
        let pool_low = dex::create_pool<TokenA, TokenB>(1);
        assert!(dex::get_fee_tier(&pool_low) == 1, 0);
        assert!(dex::get_total_supply(&pool_low) == 0, 1);
        object::transfer(pool_low, @0x1);

        // Test medium fee tier 
        let pool_med = dex::create_pool<TokenA, TokenB>(5);
        assert!(dex::get_fee_tier(&pool_med) == 5, 2);
        assert!(dex::get_total_supply(&pool_med) == 0, 3);
        object::transfer(pool_med, @0x1);

        // Test high fee tier
        let pool_high = dex::create_pool<TokenA, TokenB>(10);
        assert!(dex::get_fee_tier(&pool_high) == 10, 4);
        assert!(dex::get_total_supply(&pool_high) == 0, 5);
        object::transfer(pool_high, @0x1);
    }

    #[test]
    #[expected_failure(abort_code = 6)] // ERROR_INVALID_FEE_TIER
    fun test_create_pool_with_invalid_fee_tier() {
        let pool = dex::create_pool<TokenA, TokenB>(2); // Invalid fee tier
        object::transfer(pool, @0x1);
    }
}