module dex::dex {
    use moveos_std::event;
    use moveos_std::object::{Self, Object};
    use moveos_std::object::ObjectID;
    
    struct SwapA has key, store, drop, copy {
        A: u64,
        value: u64,
        address: address,
    }


    // Specific functions for each type instead of generic
    struct SwapB has key, store, drop, copy {
        B: u64,
        value: u64,
        address: address,
    }

    // Specific functions for each type instead of generic
    public fun create_swap_a(value: SwapA): Object<SwapA> {
        object::new(value)
    }

    // Specific functions for each type instead of generic
    public fun create_swap_b(value: SwapB): Object<SwapB> {
        object::new(value)
    }

    // End of specific functions
    public fun store_swap_a(obj: Object<SwapA>) {
        object::transfer(obj, @0x1)
    }

    // Specific functions for each type instead of generic
    public fun store_swap_b(obj: Object<SwapB>) {
        object::transfer(obj, @0x1)
    }

    // End of specific functions
    fun init() {
        let swapA = SwapA {
            A: 0,
            value: 0,
            address: @0x0,
        };
        
        let swapB = SwapB {
            B: 0,
            value: 0,
            address: @0x0,
        };

        // Create and store objects using type-specific functions
        let obj_a = create_swap_a(swapA);
        let obj_b = create_swap_b(swapB);

        store_swap_a(obj_a);
        store_swap_b(obj_b);
    }
}