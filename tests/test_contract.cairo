use core::result::ResultTrait;
use core::num::traits::Zero;
use starknet::{ContractAddress, contract_address_const, get_caller_address, get_block_number, get_contract_address};
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;

use snforge_std::{declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address};

use nftwrapper::NFTWrapper::INFTWrapperSafeDispatcher;
use nftwrapper::NFTWrapper::INFTWrapperSafeDispatcherTrait;
use nftwrapper::NFTWrapper::INFTWrapperDispatcher;
use nftwrapper::NFTWrapper::INFTWrapperDispatcherTrait;
use nftwrapper::testNFT::ITestNFTDispatcher;
use nftwrapper::testNFT::ITestNFTDispatcherTrait;
use nftwrapper::NFTWrappedToken::INFTWrappedTokenDispatcher;
use nftwrapper::NFTWrappedToken::INFTWrappedTokenDispatcherTrait;

const PUBLIC_KEY: felt252 = 0x49a1ecb78d4f98eea4c52f2709045d55b05b9c794f7423de504cc1d4f7303c3;
fn deploy_account(address: ContractAddress) {
    let contract = declare("Account").unwrap();
    let args = array![PUBLIC_KEY];
    let _address = contract.deploy_at(@args, address);
}

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

fn deploy_wrapper_contract(default_admin: ContractAddress) -> ContractAddress {
    let contract = declare("NFTWrapper").unwrap();
    let args: Array<felt252> = array![
        default_admin.into()
    ];
    let (contract_address, _) = contract.deploy(@args).unwrap();
    contract_address

}

#[test]
fn test_get_default_admin() {
    let contract_address = deploy_wrapper_contract(contract_address_const::<1>());

    let dispatcher = INFTWrapperDispatcher { contract_address };
    let has_role = dispatcher.has_role(DEFAULT_ADMIN_ROLE, contract_address_const::<1>());
    assert(has_role == true, 'No admin role');
    let dont_have_role = dispatcher.has_role(DEFAULT_ADMIN_ROLE, contract_address_const::<2>());
    assert(dont_have_role == false, 'Should not have admin role');
}

#[test]
fn test_create_wrapped_token() {
    let wrapper_contract_address = deploy_wrapper_contract(contract_address_const::<1>());
    let wrapper_dispatcher = INFTWrapperDispatcher { contract_address: wrapper_contract_address };

    let nft_contract_address = deploy_contract("TestNFT");

    let token_contract = declare("NFTWrappedToken").unwrap();
    wrapper_dispatcher.create_wrapped_token(nft_contract_address, token_contract.class_hash, 1);
    let conversion_rate = wrapper_dispatcher.get_conversion_rate(nft_contract_address);
    assert(conversion_rate == 1, 'Conversion rate should be 1');
}

#[test]
fn test_wrap_nft() {
    let default_admin = contract_address_const::<'default_admin'>();
    let wrapper_contract_address = deploy_wrapper_contract(default_admin);
    let wrapper_dispatcher = INFTWrapperDispatcher { contract_address: wrapper_contract_address };

    let nft_contract_address = deploy_contract("TestNFT");
    let nft_contract_dispatcher = ITestNFTDispatcher { contract_address: nft_contract_address };

    let token_contract = declare("NFTWrappedToken").unwrap();
    let wrapped_token_ca = wrapper_dispatcher.create_wrapped_token(nft_contract_address, token_contract.class_hash, 1);
    let wrapped_token_dispatcher = INFTWrappedTokenDispatcher { contract_address: wrapped_token_ca };

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
    assert(nft_contract_dispatcher.owner_of(token_id) == wrapper_contract_address, 'NFT not wrapped');
    assert(wrapped_token_dispatcher.balance_of(caller_address) == 1, 'Wrapped token not minted');

    let nft_pool = wrapper_dispatcher.get_nft_pool(nft_contract_address);
    assert(nft_pool.len() == 1, 'NFT not added to pool');
}