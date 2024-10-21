# NFT Wrapper

Warp ERC721 NFT into ERC20 token to increace liquidity of NFT in Starknet.

## install dependency

This repository requires cairo v2.8.2, [scarb v2.8.3](https://docs.swmansion.com/scarb/), [starknet foundry v0.31.0](https://foundry-rs.github.io/starknet-foundry/), [universal-sierra-compiler v2.3.0](https://github.com/software-mansion/universal-sierra-compiler) and [node.js](https://nodejs.org/zh-cn) (suitable for any version). Check the project page to install the right version of tools on your system. Try the following command to verify installation:
```shell
scarb -V
# expected output: scarb 2.8.3 (54938ce3b 2024-09-26)
snforge -V
# expected output: snforge 0.31.0
universal-sierra-compiler -V
# expected output: universal-sierra-compiler 2.3.0
node -v
# expected output: v20.18.0 (or other version)
```

## run test

Open this project in VSCode or other IDE, run the following code in terminal:
```sh
cp .env.example .env
```

Copy your wallet address and private key from [Argent](https://www.argent.xyz/zh) or [Braavos](https://braavos.app/), starknet sepolia node URL from node provider (eg. https://free-rpc.nethermind.io/mainnet-juno) and then paste them into `.env` file from last step. 

Paste your wallet address into line 32 of `tests/test_contract.cairo` file.

Run `node ./sign.js` in terminal to get the signature of the message. Then you can see the result in terminal like this:
```log
public key: 0x3b1da8fc90ccc7a3e1fa0e37d944e89ed0a7cc4f835b92fd66d1b961f8a281c
Sinature: Signature {
  r: 2479229890571049757771221125485093698165615065327125975668284125076583573395n,
  s: 2924437662358750303384066777155159318451460232048465929672386149883562254625n,
  recovery: 1
}
Message Hash: 0xae9f26b07112cc2e6d0ef7d3dcdb3774af5cdbd360eff07524ffedcf560f87
Signature is: VALID
public key: 0x3b1da8fc90ccc7a3e1fa0e37d944e89ed0a7cc4f835b92fd66d1b961f8a281c
Sinature: Signature {
  r: 3096176884457270719896988959615693620522280543358448574913427925219174206027n,
  s: 513552116542419899666536541217298201189204773780395282218396620602724490941n,
  recovery: 1
}
Message Hash: 0x22b75efdfe5aa90224a4a3f1e6205e467a37d5b156c43f62c00ea383ba4519c
Signature is: VALID
```

Copy public key, message hash, signature r, signature s and paste them into line 33-41 of `tests/test_contract.cairo` file.

Run the following command to test:
```sh
snforge test
```
Expected output like this:
```log
Collected 7 test(s) from nftwrapper package
Running 7 test(s) from tests/
[PASS] nftwrapper_integrationtest::test_contract::test_get_default_admin (gas: ~364)
[PASS] nftwrapper_integrationtest::test_contract::test_create_wrapped_token (gas: ~1539)
[PASS] nftwrapper_integrationtest::test_contract::test_create_unauthorized_wrapped_token (gas: ~849)
[PASS] nftwrapper_integrationtest::test_contract::test_wrap_nft (gas: ~2148)
[PASS] nftwrapper_integrationtest::test_contract::test_mint_wrapped_token_without_permission (gas: ~1772)
[PASS] nftwrapper_integrationtest::test_contract::test_unwrap_nft (gas: ~2959)
[PASS] nftwrapper_integrationtest::test_contract::test_dex_pool (gas: ~3846)
Running 0 test(s) from src/
Tests: 7 passed, 0 failed, 0 skipped, 0 ignored, 0 filtered out
```

## TODO
- [x] Fix U256 `Store` trait (waiting for cairo 2.7.0)

  (Fixed using maintain a `(contract_address, index) -> value` mapping and `(contract_address -> array_length)` mapping. Still waing for cairo native array storage.)

  update: cairo 2.8.3 still not suitable for dynamic array, so use backend+signature instead.

- [x] Add more tests for access control
- [x] Create a dex for the wrapped token.
<!-- - [ ] Add more function to the pool. -->
- [x] Add signature verification to `unwrap` function.

You are welcomed to contribute!