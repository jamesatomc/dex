module dex::token {
    use moveos_std::event;
    use moveos_std::object::{Self, Object};
    use moveos_std::object::ObjectID;
    use moveos_std::address;
    use rooch_framework::coin_store::CoinStore;
    use rooch_framework::coin::{Self, Coin};

    // Constants
    const TOTAL_SUPPLY: u64 = 100000000000000; // 100 billion
    const DECIMALS: u8 = 9;
    
    struct Token has key, store, drop, copy {
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        total_supply: u64,
        value: u64,
        address: address,
    }

    // Events
    struct MintEvent has drop, store, copy {
        amount: u64,
        recipient: address
    }

    public fun create_token(value: Token): Object<Token> {
        object::new(value)
    }

    public fun mint(amount: u64, recipient: address): Object<Token> {
        assert!(amount <= TOTAL_SUPPLY, 1); // Check supply limit
        
        let token = Token {
            name: b"MyToken",
            symbol: b"MTK",
            decimals: DECIMALS,
            total_supply: TOTAL_SUPPLY,
            value: amount,
            address: recipient
        };

        event::emit(MintEvent {
            amount,
            recipient
        });

        create_token(token)
    }

    public fun store_token(obj: Object<Token>) {
        object::transfer(obj, @0x1)
    }

    fun init() {
        let token = Token {
            name: b"MyToken",
            symbol: b"MTK", 
            decimals: DECIMALS,
            total_supply: TOTAL_SUPPLY,
            value: 0,
            address: @0x0,
        };

        let obj = create_token(token);
        store_token(obj);
    }

    #[test_only]
    public fun create_test_token(): Token {
        Token {
            name: b"MyToken",
            symbol: b"MTK",
            decimals: DECIMALS,
            total_supply: TOTAL_SUPPLY,
            value: 0,
            address: @0x1,
        }
    }
}


