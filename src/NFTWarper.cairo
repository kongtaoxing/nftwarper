// SPDX-License-Identifier: GNU GPL
// Compatible with OpenZeppelin Contracts for Cairo ^0.14.0

use starknet::ContractAddress;

// ERC20 token interface
#[starknet::interface]
pub trait INFTWarpedToken<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, amount: felt252);
    fn burn(ref self: TContractState, from: ContractAddress, amount: felt252);
    fn balance_of(self: @TContractState, owner: ContractAddress) -> felt252;
}

// ERC721 token interface
#[starknet::interface]
pub trait INFTContract<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, token_id: felt252);
    fn burn(ref self: TContractState, from: ContractAddress, token_id: felt252);
    fn owner_of(self: @TContractState, token_id: felt252) -> ContractAddress;
}

// NFTWarper contract interface
#[starknet::interface]
pub trait INFTWarper<TContractState> {
    fn wrap(ref self: TContractState, nft_contract: ContractAddress, nft_token_id: felt252, amount: felt252);
    fn unwrap(ref self: TContractState, nft_contract: ContractAddress, nft_token_id: felt252, amount: felt252);
    fn balance_of(self: @TContractState, nft_contract: ContractAddress, nft_token_id: felt252) -> felt252;
    fn has_role(self: @TContractState, role: felt252, account: ContractAddress) -> bool;
}

#[starknet::contract]
mod NFTWarper {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        conversion_rate: LegacyMap::<ContractAddress, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, default_admin: ContractAddress) {
        self.accesscontrol.initializer();

        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, default_admin);
    }
}