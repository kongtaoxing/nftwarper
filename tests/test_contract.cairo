use core::result::ResultTrait;
use starknet::{ContractAddress, contract_address_const, get_caller_address, get_block_number};
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;

use snforge_std::{declare, ContractClassTrait};

use nftwarper::NFTWarper::INFTWarperSafeDispatcher;
use nftwarper::NFTWarper::INFTWarperSafeDispatcherTrait;
use nftwarper::NFTWarper::INFTWarperDispatcher;
use nftwarper::NFTWarper::INFTWarperDispatcherTrait;

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

fn deploy_warper_contract(default_admin: ContractAddress) -> ContractAddress {
    let contract = declare("NFTWarper").unwrap();
    let args: Array<felt252> = array![
        default_admin.into()
    ];
    let (contract_address, _) = contract.deploy(@args).unwrap();
    contract_address

}

#[test]
fn test_get_default_admin() {
    let contract_address = deploy_warper_contract(contract_address_const::<1>());

    let dispatcher = INFTWarperDispatcher { contract_address };
    let has_role = dispatcher.has_role(DEFAULT_ADMIN_ROLE, contract_address_const::<1>());
    assert(has_role == true, 'No admin role');
    let dont_have_role = dispatcher.has_role(DEFAULT_ADMIN_ROLE, contract_address_const::<2>());
    assert(dont_have_role == false, 'Should not have admin role');
}
