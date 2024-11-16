#[test_only]
module dex::dex_tests {
    use dex::dex::{Self, TokenA, TokenB};
    use moveos_std::object;
    use rooch_framework::coin;
    use moveos_std::tx_context;
    use rooch_framework::account_coin_store;

    #[test]
    fun test_create_pool() {
        let (coin_a_info, coin_b_info) = setup_coins();
        let pool = dex::create_pool<TokenA, TokenB>(1);
        assert!(dex::get_fee_tier(&pool) == 1, 0);
        
        // Transfer objects to avoid unused value errors
        object::transfer(coin_a_info, tx_context::sender());
        object::transfer(coin_b_info, tx_context::sender());
        object::transfer(pool, tx_context::sender());
    }

    #[test]
    fun test_add_liquidity() {
        let (coin_a_info, coin_b_info) = setup_coins();
        let pool = dex::create_pool<TokenA, TokenB>(1);
        
        let coin_a = coin::mint(&mut coin_a_info, 2000);
        let coin_b = coin::mint(&mut coin_b_info, 2000);

        let liquidity = dex::add_liquidity(
            &mut pool,
            coin_a,
            coin_b,
            1000,
            1000
        );
        assert!(liquidity > 0, 0);

        // Transfer objects
        object::transfer(coin_a_info, tx_context::sender());
        object::transfer(coin_b_info, tx_context::sender());
        object::transfer(pool, tx_context::sender());
    }

    #[test]
    fun test_swap() {
        let (coin_a_info, coin_b_info) = setup_coins();
        let pool = dex::create_pool<TokenA, TokenB>(1);
        
        // Add initial liquidity
        let coin_a = coin::mint(&mut coin_a_info, 10000);
        let coin_b = coin::mint(&mut coin_b_info, 10000);
        
        let _ = dex::add_liquidity(
            &mut pool,
            coin_a,
            coin_b,
            9000,
            9000
        );

        // Perform swap
        let swap_amount = coin::mint(&mut coin_a_info, 1000);
        let coin_out = dex::swap(
            &mut pool,
            swap_amount,
            900
        );

        // Verify swap result
        let amount_out = coin::value(&coin_out);
        assert!(amount_out > 0, 0);

        // Clean up resources
        let recipient = tx_context::sender();
        account_coin_store::deposit(recipient, coin_out); // Deposit coin_out to recipient's account
        object::transfer(coin_a_info, recipient);
        object::transfer(coin_b_info, recipient);
        object::transfer(pool, recipient);
    }

    fun setup_coins(): (object::Object<coin::CoinInfo<TokenA>>, object::Object<coin::CoinInfo<TokenB>>) {
        let coin_a_info = coin::register_extend<TokenA>(
            std::string::utf8(b"Token A"),
            std::string::utf8(b"TOKA"),
            std::option::none(),
            8
        );
        
        let coin_b_info = coin::register_extend<TokenB>(
            std::string::utf8(b"Token B"),
            std::string::utf8(b"TOKB"),
            std::option::none(),
            8
        );

        (coin_a_info, coin_b_info)
    }
}