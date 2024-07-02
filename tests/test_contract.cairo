use core::result::ResultTrait;
use core::num::traits::Zero;
use starknet::{ContractAddress, contract_address_const, get_caller_address, get_block_number};
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;

use snforge_std::{declare, ContractClassTrait};

use nftwrapper::NFTWrapper::INFTWrapperSafeDispatcher;
use nftwrapper::NFTWrapper::INFTWrapperSafeDispatcherTrait;
use nftwrapper::NFTWrapper::INFTWrapperDispatcher;
use nftwrapper::NFTWrapper::INFTWrapperDispatcherTrait;
use nftwrapper::testNFT::ITestNFTDispatcher;
use nftwrapper::testNFT::ITestNFTDispatcherTrait;

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
    // let nft_contract_dispatcher = ITestNFTDispatcher { contract_address: nft_contract_address };
    // let nft_name = nft_contract_dispatcher.name();

    let token_contract = declare("NFTWrappedToken").unwrap();
    wrapper_dispatcher.create_wrapped_token(nft_contract_address, token_contract.class_hash, 1);
    let conversion_rate = wrapper_dispatcher.get_conversion_rate(nft_contract_address);
    assert(conversion_rate == 1, 'Conversion rate should be 1');
}