use starknet::account::Call;

#[starknet::interface]
trait IAccount<T> {
    fn public_key(self: @T) -> felt252;
    fn supports_interface(self: @T, interface_id: felt252) -> bool;
    fn is_valid_signature(self: @T, hash: felt252, signature: Array<felt252>) -> felt252;
    fn __execute__(self: @T, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @T, calls: Array<Call>) -> felt252;
    fn __validate_declare__(self: @T, class_hash: felt252) -> felt252;
    fn __validate_deploy__(self: @T, class_hash: felt252, salt: felt252, public_key: felt252) -> felt252;
}

#[starknet::contract(account)]
mod Account {
    use openzeppelin::account::AccountComponent;
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: AccountComponent, storage: account, event: AccountEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Account Mixin
    #[abi(embed_v0)]
    impl AccountMixinImpl = AccountComponent::AccountMixinImpl<ContractState>;
    impl AccountInternalImpl = AccountComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        account: AccountComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccountEvent: AccountComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, public_key: felt252) {
        self.account.initializer(public_key);
    }
}