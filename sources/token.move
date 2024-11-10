module dex::token {
    use moveos_std::event;
    use moveos_std::object::{Self, Object};
    use moveos_std::object::ObjectID;

    struct Token has key, store, drop, copy {
        value: u64,
        address: address,
    }

    public fun create_token(value: Token): Object<Token> {
        object::new(value)
    }

    public fun store_token(obj: Object<Token>) {
        object::transfer(obj, @0x1)
    }

    fun init() {
        let token = Token {
            value: 0,
            address: @0x0,
        };

        let obj = create_token(token);

        store_token(obj);
    }
}