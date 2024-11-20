module kanari_network::kari_token {
    use std::option;
    use std::string;
    use moveos_std::signer;
    use moveos_std::object::{Self, Object};
    use rooch_framework::coin;
    use rooch_framework::account_coin_store;
    use moveos_std::event;

    const ADMIN_ADDRESS: address = @kanari_network;
    
    // Error codes
    const ERROR_NOT_ADMIN: u64 = 1;
    const ERROR_ZERO_AMOUNT: u64 = 2;
    const ERROR_EMPTY_STRING: u64 = 3;

    // Add constants for validation
    const MAX_NAME_LENGTH: u64 = 32;
    const MAX_SYMBOL_LENGTH: u64 = 10;

    // Token details
    const DECIMALS: u8 = 8u8;
    const INITIAL_SUPPLY: u256 = 1_100_000_000_000_000u256; // 11 million tokens
    const KARI_ICON_URL: vector<u8> = b"";

    // Define the KARI token
    struct KARI has key, store {}

    // Define the token admin
    struct TokenAdmin has key, store {
        coin_info: Object<coin::CoinInfo<KARI>>,
    }

    // Define events
    struct NameUpdateEvent has copy, drop, store {
        old_name: string::String,
        new_name: string::String,
    }

    struct SymbolUpdateEvent has copy, drop, store {
        old_symbol: string::String,
        new_symbol: string::String,
    }

    struct IconUpdateEvent has copy, drop, store {
        old_icon_url: option::Option<string::String>,
        new_icon_url: option::Option<string::String>,
    }


    // Initialize the token
    fun init() {
        let coin_info_obj = coin::register_extend<KARI>(
            string::utf8(b"KARI Token"),
            string::utf8(b"KARI"),
            option::some(string::utf8(KARI_ICON_URL)), // Add icon URL
            DECIMALS,
        );

        // Mint initial supply
        let initial_coins = coin::mint_extend<KARI>(&mut coin_info_obj, INITIAL_SUPPLY);
        
        let token_admin = TokenAdmin {
            coin_info: coin_info_obj,
        };
        
        let admin_obj = object::new_named_object(token_admin);
        object::transfer(admin_obj, ADMIN_ADDRESS);

        // Transfer initial supply to admin
        account_coin_store::deposit_extend(ADMIN_ADDRESS, initial_coins);
    }

    // Mint new tokens
    public entry fun mint(admin: &signer, to: address, amount: u256) {
        assert!(signer::address_of(admin) == ADMIN_ADDRESS, ERROR_NOT_ADMIN);
        assert!(amount > 0, ERROR_ZERO_AMOUNT);

        let admin_obj_id = object::named_object_id<TokenAdmin>();
        let admin_obj = object::borrow_mut_object<TokenAdmin>(admin, admin_obj_id);
        let token_admin = object::borrow_mut(admin_obj);
        let coin = coin::mint_extend<KARI>(&mut token_admin.coin_info, amount);
        account_coin_store::deposit_extend(to, coin);
    }

    // Burn tokens
    public entry fun burn(account: &signer, amount: u256) {
        assert!(amount > 0, ERROR_ZERO_AMOUNT);
        
        let admin_obj_id = object::named_object_id<TokenAdmin>();
        let admin_obj = object::borrow_mut_object_extend<TokenAdmin>(admin_obj_id);
        let token_admin = object::borrow_mut(admin_obj);
        let coin = account_coin_store::withdraw_extend<KARI>(signer::address_of(account), amount);
        coin::burn_extend<KARI>(&mut token_admin.coin_info, coin);
    }

    // Transfer tokens
    public entry fun transfer(from: &signer, to: address, amount: u256) {
        assert!(amount > 0, ERROR_ZERO_AMOUNT);
        account_coin_store::transfer_extend<KARI>(signer::address_of(from), to, amount);
    }

    // Update token details
    public entry fun update_name(admin: &signer, new_name: vector<u8>) {
        assert!(signer::address_of(admin) == ADMIN_ADDRESS, ERROR_NOT_ADMIN);
        assert!(!std::vector::is_empty(&new_name), ERROR_EMPTY_STRING);
        
        let name = string::utf8(new_name);
        assert!(string::length(&name) <= MAX_NAME_LENGTH, ERROR_EMPTY_STRING);
        
        let admin_obj_id = object::named_object_id<TokenAdmin>();
        let _admin_obj = object::borrow_mut_object<TokenAdmin>(admin, admin_obj_id);
        
        let old_name = coin::name<KARI>(coin::coin_info<KARI>());
        event::emit(NameUpdateEvent {
            old_name,
            new_name: name,
        });
    }
    
    // Update token symbol
    public entry fun update_symbol(admin: &signer, new_symbol: vector<u8>) {
        assert!(signer::address_of(admin) == ADMIN_ADDRESS, ERROR_NOT_ADMIN);
        assert!(!std::vector::is_empty(&new_symbol), ERROR_EMPTY_STRING);
        
        let symbol = string::utf8(new_symbol);
        assert!(string::length(&symbol) <= MAX_SYMBOL_LENGTH, ERROR_EMPTY_STRING);
    
        let admin_obj_id = object::named_object_id<TokenAdmin>();
        let _admin_obj = object::borrow_mut_object<TokenAdmin>(admin, admin_obj_id);
        
        let old_symbol = coin::symbol<KARI>(coin::coin_info<KARI>());
        event::emit(SymbolUpdateEvent {
            old_symbol,
            new_symbol: symbol,
        });
    }
    
    // Update token icon
    public entry fun update_icon(admin: &signer, new_icon_url: vector<u8>) {
        assert!(signer::address_of(admin) == ADMIN_ADDRESS, ERROR_NOT_ADMIN);
        
        let admin_obj_id = object::named_object_id<TokenAdmin>();
        let _admin_obj = object::borrow_mut_object<TokenAdmin>(admin, admin_obj_id);
    
        let old_icon_url = coin::icon_url<KARI>(coin::coin_info<KARI>());
        let new_icon = if (std::vector::is_empty(&new_icon_url)) {
            option::none()
        } else {
            option::some(string::utf8(new_icon_url))
        };
    
        event::emit(IconUpdateEvent {
            old_icon_url,
            new_icon_url: new_icon,
        });
    }

    // Get token info
    public fun get_info(): &coin::CoinInfo<KARI> {
        coin::coin_info<KARI>()
    }
    
    // Get token balance
    public fun get_balance(account: address): u256 {
        account_coin_store::balance<KARI>(account)
    }
}