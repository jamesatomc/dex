module dex::token {
    use std::string;
    use std::option;
    use moveos_std::object::{Self, Object};
    use rooch_framework::coin::{Self, CoinInfo};

    // Error codes
    const ERR_NOT_INITIALIZED: u64 = 1;
    const ERR_ALREADY_INITIALIZED: u64 = 2;
    const ERR_INVALID_AMOUNT: u64 = 3;
    const ERR_SUPPLY_EXCEEDED: u64 = 4;

    // Token configuration
    const NAME: vector<u8> = b"MyToken";
    const SYMBOL: vector<u8> = b"MTK";
    const DECIMALS: u8 = 9;
    const MAX_SUPPLY: u256 = 100_000_000_000; // 100 billion

    struct Token has key, store, drop {
        name: string::String,
        symbol: string::String,
        decimals: u8,
        total_supply: u256,
    }

    /// Initialize token
    fun init() {
        // Check if already initialized
        assert!(!coin::is_registered<Token>(), ERR_ALREADY_INITIALIZED);

        // Register token with metadata
        let coin_info = coin::register_extend<Token>(
            string::utf8(NAME),
            string::utf8(SYMBOL),
            option::some(string::utf8(b"https://example.com/token-icon.png")),
            DECIMALS
        );

        // Create token object
        let token = Token {
            name: string::utf8(NAME),
            symbol: string::utf8(SYMBOL),
            decimals: DECIMALS,
            total_supply: 0
        };

        // Store token info
        let token_obj = object::new(token);
        object::transfer(coin_info, @0x0);
        object::transfer(token_obj, @0x0);
    }

    /// Mint new tokens
    public fun mint(coin_info: &mut Object<CoinInfo<Token>>, amount: u256): coin::Coin<Token> {
        // Validate amount
        assert!(amount > 0, ERR_INVALID_AMOUNT);
        
        // Check max supply
        let supply = coin::supply(object::borrow(coin_info));
        assert!(supply + amount <= MAX_SUPPLY, ERR_SUPPLY_EXCEEDED);

        coin::mint(coin_info, amount)
    }

    /// Burn tokens
    public fun burn(coin_info: &mut Object<CoinInfo<Token>>, coin: coin::Coin<Token>) {
        coin::burn(coin_info, coin);
    }

    #[test_only]
    public fun setup_test(): Object<CoinInfo<Token>> {
        coin::register_extend<Token>(
            string::utf8(NAME),
            string::utf8(SYMBOL),
            option::none(),
            DECIMALS
        )
    }
}