// First add these to token.move


// Then update token_tests.move
#[test_only]
module dex::token_tests {
    use dex::token::{Self, Token};
    use moveos_std::object::{Self, Object};
    
    #[test]
    fun test_create_token() {
        let test_token = token::create_test_token();
        let obj = token::create_token(test_token);
        // Store object to prevent drop constraint error
        token::store_token(obj);
    }

    #[test]
    fun test_mint() {
        let amount = 1000000;
        let recipient = @0x2;
        
        let obj = token::mint(amount, recipient);
        // Store object to prevent drop constraint error
        token::store_token(obj);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_mint_exceeds_supply() {
        let amount = 100000000000001; // Exceeds total supply
        let recipient = @0x2;
        
        let obj = token::mint(amount, recipient);
        token::store_token(obj);
    }

    #[test]
    fun test_store_token() {
        let test_token = token::create_test_token();
        let obj = token::create_token(test_token);
        token::store_token(obj);
    }
}