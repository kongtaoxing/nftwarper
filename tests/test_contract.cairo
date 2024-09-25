use core::serde::Serde;
use core::result::ResultTrait;
use core::num::traits::Zero;
use core::integer::BoundedInt;
use starknet::{
    ContractAddress, contract_address_const, get_caller_address, get_block_number,
    get_contract_address
};
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;

use snforge_std::{
    declare, ContractClass, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address
};

use nftwrapper::NFTWrapper::INFTWrapperSafeDispatcher;
use nftwrapper::NFTWrapper::INFTWrapperSafeDispatcherTrait;
use nftwrapper::NFTWrapper::INFTWrapperDispatcher;
use nftwrapper::NFTWrapper::INFTWrapperDispatcherTrait;
use nftwrapper::testNFT::ITestNFTDispatcher;
use nftwrapper::testNFT::ITestNFTDispatcherTrait;
use nftwrapper::NFTWrappedToken::INFTWrappedTokenDispatcher;
use nftwrapper::NFTWrappedToken::INFTWrappedTokenDispatcherTrait;
use nftwrapper::NFTWrappedToken::INFTWrappedTokenSafeDispatcher;
use nftwrapper::NFTWrappedToken::INFTWrappedTokenSafeDispatcherTrait;
use nftwrapper::dex::IDexDispatcher;
use nftwrapper::dex::IDexDispatcherTrait;

const PUBLIC_KEY: felt252 = 0x49a1ecb78d4f98eea4c52f2709045d55b05b9c794f7423de504cc1d4f7303c3;
fn deploy_account(address: ContractAddress) {
    let contract = declare("Account").unwrap().contract_class();
    let args = array![PUBLIC_KEY];
    let _address = contract.deploy_at(@args, address);
}

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

fn deploy_wrapper_contract(default_admin: ContractAddress) -> (ContractClass, ContractAddress) {
    let contract = declare("NFTWrapper").unwrap().contract_class();
    let wrapped_token = declare("NFTWrappedToken").unwrap().contract_class();
    let args: Array<felt252> = array![default_admin.into(), (*wrapped_token.class_hash).into()];
    let (contract_address, _) = contract.deploy(@args).unwrap();
    (*wrapped_token, contract_address)
}

#[test]
fn test_get_default_admin() {
    let (_, contract_address) = deploy_wrapper_contract(contract_address_const::<1>());

    let dispatcher = INFTWrapperDispatcher { contract_address };
    let has_role = dispatcher.has_role(DEFAULT_ADMIN_ROLE, contract_address_const::<1>());
    assert(has_role == true, 'No admin role');
    let dont_have_role = dispatcher.has_role(DEFAULT_ADMIN_ROLE, contract_address_const::<2>());
    assert(dont_have_role == false, 'Should not have admin role');
}

#[test]
fn test_create_wrapped_token() {
    let default_admin = contract_address_const::<'default_admin'>();
    let (token_contract, wrapper_contract_address) = deploy_wrapper_contract(default_admin);
    let wrapper_dispatcher = INFTWrapperDispatcher { contract_address: wrapper_contract_address };

    let nft_contract_address = deploy_contract("TestNFT");

    wrapper_dispatcher.create_wrapped_token(nft_contract_address, token_contract.class_hash, 1);
    let conversion_rate = wrapper_dispatcher.get_conversion_rate(nft_contract_address);
    assert(conversion_rate == 1, 'Conversion rate should be 1');
}

#[test]
fn test_wrap_nft() {
    let default_admin = contract_address_const::<'default_admin'>();
    let (token_contract, wrapper_contract_address) = deploy_wrapper_contract(default_admin);
    let wrapper_dispatcher = INFTWrapperDispatcher { contract_address: wrapper_contract_address };

    let nft_contract_address = deploy_contract("TestNFT");
    let nft_contract_dispatcher = ITestNFTDispatcher { contract_address: nft_contract_address };

    // create wrapped token
    let wrapped_token_ca = wrapper_dispatcher
        .create_wrapped_token(nft_contract_address, token_contract.class_hash, 1);
    let wrapped_token_dispatcher = INFTWrappedTokenDispatcher {
        contract_address: wrapped_token_ca
    };
    assert(wrapped_token_dispatcher.name() == nft_contract_dispatcher.name(), 'name not set');
    assert(wrapped_token_dispatcher.symbol() == nft_contract_dispatcher.symbol(), 'symbol not set');

    let caller_address: ContractAddress = contract_address_const::<'caller_address'>();
    deploy_account(caller_address);

    start_cheat_caller_address(nft_contract_address, caller_address);
    // mint a test NFT
    let token_id: u256 = 1;
    let data: Array<felt252> = array![];
    nft_contract_dispatcher.safe_mint(caller_address, token_id, data.span());
    assert(nft_contract_dispatcher.owner_of(token_id) == caller_address, 'NFT not minted');

    // approve the NFT
    nft_contract_dispatcher.set_approval_for_all(wrapper_contract_address, true);
    stop_cheat_caller_address(nft_contract_address);
    // wrap the NFT
    start_cheat_caller_address(wrapper_contract_address, caller_address);
    wrapper_dispatcher.wrap(nft_contract_address, token_id);
    stop_cheat_caller_address(wrapper_contract_address);
    assert(
        nft_contract_dispatcher.owner_of(token_id) == wrapper_contract_address, 'NFT not wrapped'
    );
    assert(wrapped_token_dispatcher.balance_of(caller_address) == 1, 'Wrapped token not minted');

    let nft_pool = wrapper_dispatcher.get_nft_pool(nft_contract_address);
    assert(nft_pool.len() == 1, 'NFT not added to pool');
}

#[test]
fn test_unwrap_nft() {
    let default_admin = contract_address_const::<'default_admin'>();
    let (token_contract, wrapper_contract_address) = deploy_wrapper_contract(default_admin);
    let wrapper_dispatcher = INFTWrapperDispatcher { contract_address: wrapper_contract_address };

    let nft_contract_address = deploy_contract("TestNFT");
    let nft_contract_dispatcher = ITestNFTDispatcher { contract_address: nft_contract_address };

    // create wrapped token
    let wrapped_token_ca = wrapper_dispatcher
        .create_wrapped_token(nft_contract_address, token_contract.class_hash, 1);
    let wrapped_token_dispatcher = INFTWrappedTokenDispatcher {
        contract_address: wrapped_token_ca
    };
    assert(wrapped_token_dispatcher.name() == nft_contract_dispatcher.name(), 'name not set');
    assert(wrapped_token_dispatcher.symbol() == nft_contract_dispatcher.symbol(), 'symbol not set');

    let caller_address: ContractAddress = contract_address_const::<'caller_address'>();
    deploy_account(caller_address);

    start_cheat_caller_address(nft_contract_address, caller_address);
    // mint a test NFT
    let token_id: u256 = 1;
    let data: Array<felt252> = array![];
    nft_contract_dispatcher.safe_mint(caller_address, token_id, data.span());
    assert(nft_contract_dispatcher.owner_of(token_id) == caller_address, 'NFT not minted');

    // approve the NFT
    nft_contract_dispatcher.set_approval_for_all(wrapper_contract_address, true);
    stop_cheat_caller_address(nft_contract_address);
    // wrap the NFT
    start_cheat_caller_address(wrapper_contract_address, caller_address);
    wrapper_dispatcher.wrap(nft_contract_address, token_id);
    stop_cheat_caller_address(wrapper_contract_address);
    assert(
        nft_contract_dispatcher.owner_of(token_id) == wrapper_contract_address, 'NFT not wrapped'
    );
    assert(wrapped_token_dispatcher.balance_of(caller_address) == 1, 'Wrapped token not minted');

    // approve the wrapped token
    start_cheat_caller_address(wrapped_token_ca, caller_address);
    wrapped_token_dispatcher.approve(wrapper_contract_address, BoundedInt::max());
    stop_cheat_caller_address(wrapped_token_ca);
    // unwrap the NFT
    start_cheat_caller_address(wrapper_contract_address, caller_address);
    wrapper_dispatcher.unwrap(nft_contract_address);
    stop_cheat_caller_address(wrapper_contract_address);
    assert(nft_contract_dispatcher.owner_of(token_id) == caller_address, 'NFT not unwrapped');
    assert(wrapped_token_dispatcher.balance_of(caller_address) == 0, 'Wrapped token not burned');
    assert(
        wrapper_dispatcher.get_nft_pool(nft_contract_address).len() == 0,
        'NFT not removed from pool'
    );

    // mint three NFTs
    start_cheat_caller_address(nft_contract_address, caller_address);
    let token_id1: u256 = 2;
    nft_contract_dispatcher.safe_mint(caller_address, token_id1, data.span());
    let token_id2: u256 = 3;
    nft_contract_dispatcher.safe_mint(caller_address, token_id2, data.span());
    let token_id3: u256 = 4;
    nft_contract_dispatcher.safe_mint(caller_address, token_id3, data.span());
    stop_cheat_caller_address(nft_contract_address);
    // wrap the NFTs
    start_cheat_caller_address(wrapper_contract_address, caller_address);
    wrapper_dispatcher.wrap(nft_contract_address, token_id1);
    wrapper_dispatcher.wrap(nft_contract_address, token_id2);
    wrapper_dispatcher.wrap(nft_contract_address, token_id3);
    stop_cheat_caller_address(wrapper_contract_address);
    assert(wrapped_token_dispatcher.balance_of(caller_address) == 3, 'Wrapped tokens not minted');
    // remove the first NFT from the pool
    start_cheat_caller_address(wrapper_contract_address, caller_address);
    wrapper_dispatcher.unwrap(nft_contract_address);
    stop_cheat_caller_address(wrapper_contract_address);
    // println!("nft pool: {:?}", wrapper_dispatcher.get_nft_pool(nft_contract_address));
    assert(
        wrapper_dispatcher.get_nft_pool(nft_contract_address).len() == 2,
        'NFT not removed from pool'
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_mint_wrapped_token_without_permission() {
    let default_admin = contract_address_const::<'default_admin'>();
    let (token_contract, wrapper_contract_address) = deploy_wrapper_contract(default_admin);
    let wrapper_dispatcher = INFTWrapperDispatcher { contract_address: wrapper_contract_address };

    let nft_contract_address = deploy_contract("TestNFT");

    // create wrapped token
    let wrapped_token_ca = wrapper_dispatcher
        .create_wrapped_token(nft_contract_address, token_contract.class_hash, 1);
    let wrapped_token_safe_dispatcher = INFTWrappedTokenSafeDispatcher {
        contract_address: wrapped_token_ca
    };

    // test mint without permission
    let caller_address: ContractAddress = contract_address_const::<'caller_address'>();
    deploy_account(caller_address);
    start_cheat_caller_address(wrapped_token_ca, caller_address);
    match wrapped_token_safe_dispatcher.mint(caller_address, 1) {
        Result::Ok(_) => panic!("Minting wrapped token should fail without permission"),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Caller is missing role', *panic_data.at(0));
        }
    }
    stop_cheat_caller_address(wrapped_token_ca);
}

#[test]
#[feature("safe_dispatcher")]
fn test_create_unauthorized_wrapped_token() {
    let default_admin = contract_address_const::<'default_admin'>();
    let (_, wrapper_contract_address) = deploy_wrapper_contract(default_admin);
    let wrapper_safe_dispatcher = INFTWrapperSafeDispatcher {
        contract_address: wrapper_contract_address
    };
    let nft_contract_address = deploy_contract("TestNFT");
    match wrapper_safe_dispatcher
        .create_wrapped_token(
            nft_contract_address, *declare("MaliciousToken").unwrap().contract_class().class_hash, 1
        ) {
        Result::Ok(_) => panic!("Creating wrapped token should fail without permission"),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'invalid classhash', *panic_data.at(0));
        }
    }
}

#[test]
fn test_dex_pool() {
    let default_admin = contract_address_const::<'default_admin'>();
    let (token_contract, wrapper_contract_address) = deploy_wrapper_contract(default_admin);
    let wrapper_dispatcher = INFTWrapperDispatcher { contract_address: wrapper_contract_address };

    let nft_contract_address = deploy_contract("TestNFT");
    let nft_contract_dispatcher = ITestNFTDispatcher { contract_address: nft_contract_address };

    // create wrapped token
    let wrapped_token_ca = wrapper_dispatcher
        .create_wrapped_token(nft_contract_address, token_contract.class_hash, 1000);
    let wrapped_token_dispatcher = INFTWrappedTokenDispatcher {
        contract_address: wrapped_token_ca
    };
    assert(wrapped_token_dispatcher.name() == nft_contract_dispatcher.name(), 'name not set');
    assert(wrapped_token_dispatcher.symbol() == nft_contract_dispatcher.symbol(), 'symbol not set');

    let caller_address: ContractAddress = contract_address_const::<'caller_address'>();
    deploy_account(caller_address);

    start_cheat_caller_address(nft_contract_address, caller_address);
    // mint a test NFT
    let token_id: u256 = 1;
    let data: Array<felt252> = array![];
    nft_contract_dispatcher.safe_mint(caller_address, token_id, data.span());
    assert(nft_contract_dispatcher.owner_of(token_id) == caller_address, 'NFT not minted');

    // approve the NFT
    nft_contract_dispatcher.set_approval_for_all(wrapper_contract_address, true);
    stop_cheat_caller_address(nft_contract_address);
    // wrap the NFT
    start_cheat_caller_address(wrapper_contract_address, caller_address);
    wrapper_dispatcher.wrap(nft_contract_address, token_id);
    stop_cheat_caller_address(wrapper_contract_address);
    assert(
        nft_contract_dispatcher.owner_of(token_id) == wrapper_contract_address, 'NFT not wrapped'
    );
    assert(wrapped_token_dispatcher.balance_of(caller_address) == 1000, 'Wrapped token not minted');

    // deploy ether token
    let ether_ca = contract_address_const::<
        0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
    >();
    let mut args: Array<felt252> = array![default_admin.into(), caller_address.into(),];
    let name: ByteArray = "Ethereum";
    let symbol: ByteArray = "ETH";
    name.serialize(ref args);
    symbol.serialize(ref args);
    let _ = token_contract.deploy_at(@args, ether_ca);
    let ether_dispatcher = INFTWrappedTokenDispatcher { contract_address: ether_ca };
    // mint eth to caller
    start_cheat_caller_address(ether_ca, caller_address);
    ether_dispatcher.mint(caller_address, 1000);
    // println!("eth balance: {:?}", ether_dispatcher.balance_of(caller_address));
    stop_cheat_caller_address(ether_ca);

    // test dex function
    start_cheat_caller_address(wrapper_contract_address, caller_address);
    let dex_class = *declare("Dex").unwrap().contract_class();
    let dex_pool_ca = wrapper_dispatcher
        .create_dex_pool(nft_contract_address, dex_class.class_hash, 10);
    // println!("dex pool: {:?}", dex_pool_ca);
    stop_cheat_caller_address(wrapper_contract_address);
    let dex_dispatcher = IDexDispatcher { contract_address: dex_pool_ca };
    // approve token to dex pool
    start_cheat_caller_address(wrapped_token_ca, caller_address);
    wrapped_token_dispatcher.approve(dex_pool_ca, 1000);
    stop_cheat_caller_address(wrapped_token_ca);
    start_cheat_caller_address(ether_ca, caller_address);
    ether_dispatcher.approve(dex_pool_ca, 1000);
    stop_cheat_caller_address(ether_ca);
    // test add liquidity
    start_cheat_caller_address(dex_pool_ca, caller_address);
    let share = dex_dispatcher.add_liquidity(100, 100);
    // println!("share: {:?}", share);
    assert(share == 100, 'Liquidity not added');
    stop_cheat_caller_address(dex_pool_ca);
    assert(wrapped_token_dispatcher.balance_of(dex_pool_ca) == 100, 'Liquidity not added');
    assert(ether_dispatcher.balance_of(dex_pool_ca) == 100, 'Liquidity not added');
    // test swap
    start_cheat_caller_address(dex_pool_ca, caller_address);
    dex_dispatcher.swap(ether_ca, 10);
    // println!("token balance: {:?}", wrapped_token_dispatcher.balance_of(caller_address));
    // println!("eth balance: {:?}", ether_dispatcher.balance_of(caller_address));
    assert(wrapped_token_dispatcher.balance_of(caller_address) == 908, 'Token not swapped');
    assert(ether_dispatcher.balance_of(caller_address) == 890, 'Token not swapped');
    // // test remove liquidity
    dex_dispatcher.remove_liquidity(10_u256);
    // println!("token balance: {:?}", wrapped_token_dispatcher.balance_of(caller_address));
    // println!("eth balance: {:?}", ether_dispatcher.balance_of(caller_address));
    assert(wrapped_token_dispatcher.balance_of(caller_address) == 917, 'Liquidity not removed');
    assert(ether_dispatcher.balance_of(caller_address) == 901, 'Liquidity not removed');
    stop_cheat_caller_address(dex_pool_ca);
}
