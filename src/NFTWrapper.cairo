// SPDX-License-Identifier: GNU GPL
// Compatible with OpenZeppelin Contracts for Cairo ^0.14.0

use starknet::{ContractAddress, ClassHash};

// ERC20 token interface
#[starknet::interface]
pub trait INFTWarpedToken<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, account: ContractAddress, amount: u256);
    fn balance_of(self: @TContractState, owner: ContractAddress) -> felt252;
}

// ERC721 token interface
#[starknet::interface]
pub trait INFTContract<TContractState> {
    fn safe_mint(ref self: TContractState, recipient: ContractAddress, token_id: u256, data: Span<felt252>);
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
}

// NFTWrapper contract interface
#[starknet::interface]
pub trait INFTWrapper<TContractState> {
    fn create_wrapped_token(ref self: TContractState, nft_contract: ContractAddress, token_classhash: ClassHash, conversion_rate: felt252) -> ContractAddress;
    fn wrap(ref self: TContractState, nft_contract: ContractAddress, nft_token_id: u256);
    fn unwrap(ref self: TContractState, nft_contract: ContractAddress);
    fn has_role(self: @TContractState, role: felt252, account: ContractAddress) -> bool;
    fn get_conversion_rate(self: @TContractState, nft_contract: ContractAddress) -> felt252;
    fn get_nft_pool(self: @TContractState, nft_contract: ContractAddress) -> Array<u256>;
}

#[starknet::contract]
mod NFTWrapper {
    use openzeppelin::utils::serde::SerializedAppend;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{
        ContractAddress, 
        Store, 
        ClassHash,
        contract_address_const, 
        get_block_number, 
        get_contract_address, 
        get_caller_address,
        get_block_timestamp,
        syscalls::deploy_syscall,
        SyscallResultTrait,
    };
    use core::{
        pedersen::PedersenTrait,
        hash::{HashStateTrait, HashStateExTrait},
        num::traits::Zero,
        traits::TryInto,
        array::ArrayTrait,
        serde::Serde,
    };
    use nftwrapper::StoreU256ArrayTrait::StoreU256Array;
    use super::{
        INFTContractDispatcher,
        INFTContractDispatcherTrait,
        INFTWarpedTokenDispatcher,
        INFTWarpedTokenDispatcherTrait,
    };

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
        conversion_rate: LegacyMap::<ContractAddress, felt252>,  // NFT contract address -> conversion rate
        // nft_pools: LegacyMap::<ContractAddress, Array<u256>>,  // NFT contract address -> Array of NFT token ids
        nft_pools_value: LegacyMap::<(ContractAddress, u32), u256>,  // (NFT contract address, index) -> NFT token ids
        nft_pools_length: LegacyMap::<ContractAddress, u32>,  // NFT contract address -> Array length
        wrapped_token: LegacyMap::<ContractAddress, ContractAddress>,  // NFT contract address -> wrapped token contract address
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

    fn generate_random_number() -> felt252 {
        let block_number = get_block_number();
        let random = PedersenTrait::new(114514).update_with(block_number + 2048).finalize();
        let block_timestamp = get_block_timestamp();
        let random = PedersenTrait::new(random).update_with(block_timestamp + 65535).finalize();
        random
    }

    #[external(v0)]
    fn create_wrapped_token(ref self: ContractState, nft_contract: ContractAddress, token_classhash: ClassHash, conversion_rate: felt252) -> ContractAddress {
        assert(self.wrapped_token.read(nft_contract).is_zero(), 'already exist');
        let nft_dispatcher = INFTContractDispatcher { contract_address: nft_contract };
        let nft_name = nft_dispatcher.name();
        let nft_symbol = nft_dispatcher.symbol();
        let salt = generate_random_number();
        let mut constructor_args: Array<felt252> = array![
            get_contract_address().into(),
            get_contract_address().into(),
        ];
        // // use this
        // nft_name.serialize(ref constructor_args);
        // nft_symbol.serialize(ref constructor_args);
        // or this
        constructor_args.append_serde(nft_name);
        constructor_args.append_serde(nft_symbol);
        let (wrapped_token_contract_address, _) = deploy_syscall(token_classhash, salt, constructor_args.span(), false).unwrap_syscall();
        self.wrapped_token.write(nft_contract, wrapped_token_contract_address);
        // set conversion rate
        self.conversion_rate.write(nft_contract, conversion_rate);
        wrapped_token_contract_address
    }

    #[external(v0)]
    fn get_conversion_rate(self: @ContractState, nft_contract: ContractAddress) -> felt252 {
        self.conversion_rate.read(nft_contract)
    }

    #[external(v0)]
    fn wrap(ref self: ContractState, nft_contract: ContractAddress, nft_token_id: u256) {
        assert(self.wrapped_token.read(nft_contract).is_non_zero(), 'create first');
        let nft_dispatcher = INFTContractDispatcher { contract_address: nft_contract };
        // println!("address this: {:?}", get_contract_address());
        // println!("address caller: {:?}", get_caller_address());
        nft_dispatcher.transfer_from(get_caller_address(), get_contract_address(), nft_token_id);

        // // cairo native storage array
        // let mut nft_pool = self.nft_pools.read(nft_contract);
        // nft_pool.append(nft_token_id);
        // self.nft_pools.write(nft_contract, nft_pool);

        // cairo native array is not supported yet
        let nft_pool_length = self.nft_pools_length.read(nft_contract);
        self.nft_pools_value.write((nft_contract, nft_pool_length), nft_token_id);
        self.nft_pools_length.write(nft_contract, nft_pool_length + 1);
        let wrapped_token_dispatcher = INFTWarpedTokenDispatcher { contract_address: self.wrapped_token.read(nft_contract) };
        wrapped_token_dispatcher.mint(get_caller_address(), self.conversion_rate.read(nft_contract).into());
    }

    #[external(v0)]
    fn get_nft_pool(self: @ContractState, nft_contract: ContractAddress) -> Array<u256> {
        // self.nft_pools.read(nft_contract)
        // cairo native array is not supported yet
        let mut nft_pool: Array<u256> = array![];
        let nft_pool_length = self.nft_pools_length.read(nft_contract);
        let mut i = 0;
        loop {
            if i == nft_pool_length {
                break;
            }
            nft_pool.append(self.nft_pools_value.read((nft_contract, i)));
            i += 1;
        };
        nft_pool
    }

    fn remove_nft_from_pool(ref self: ContractState, nft_contract: ContractAddress, index: u32) {
        // // cairo native storage array
        // let last_index: u32 = self.nft_pools.read(nft_contract).len().into() - 1;
        // println!("pool length: {:?}", self.nft_pools.read(nft_contract).len());
        // let nft_pool_before = self.nft_pools.read(nft_contract);
        // let last_index_value = nft_pool_before.at(last_index);
        // let mut nft_pool_after: Array<u256> = array![];
        // let mut i = 0;
        // loop {
        //     if i == last_index {
        //         break;
        //     }
        //     if i == index {
        //         nft_pool_after.append(*last_index_value);
        //     } else {
        //         nft_pool_after.append(*nft_pool_before.at(i));
        //     }
        //     i += 1;
        // };
        // self.nft_pools.write(nft_contract, nft_pool_after);

        // cairo native array is not supported yet
        // to decrease gas cost, we just withdraw the last nft to the user
        // when cairo native storage array is implemented, we will use random index
        let last_index: u32 = self.nft_pools_length.read(nft_contract) - 1;
        self.nft_pools_length.write(nft_contract, last_index);
    }

    fn random_index(len: u32) -> u32 {
        let random = generate_random_number().try_into().unwrap() % 0xffffffff_u256;
        let index: u32 = random.try_into().unwrap() % len;
        index
    }

    #[external(v0)]
    fn unwrap(ref self: ContractState, nft_contract: ContractAddress) {
        // // cairo native storage array
        // assert(self.nft_pools.read(nft_contract).len() > 0, 'empty pool');
        // cairo native array is not supported yet
        assert(self.nft_pools_length.read(nft_contract) > 0, 'empty pool');

        let wrapped_token = INFTWarpedTokenDispatcher { contract_address: self.wrapped_token.read(nft_contract) };
        wrapped_token.burn(get_caller_address(), self.conversion_rate.read(nft_contract).into());
        // // cairo native storage array
        // let index = random_index(self.nft_pools.read(nft_contract).len());
        // cairo native array is not supported yet
        let index = random_index(self.nft_pools_length.read(nft_contract));

        // println!("index: {:?}", index);
        let nft_dispatcher = INFTContractDispatcher { contract_address: nft_contract };
        // // cairo native storage array
        // nft_dispatcher.transfer_from(get_contract_address(), get_caller_address(), *self.nft_pools.read(nft_contract).at(index));
        // cairo native array is not supported yet
        nft_dispatcher.transfer_from(get_contract_address(), get_caller_address(), self.nft_pools_value.read((nft_contract, index)));
        remove_nft_from_pool(ref self, nft_contract, index);
    }
}