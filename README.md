# NFT Wrapper

Warp ERC721 NFT into ERC20 token to increace liquidity of NFT in Starknet.

## install dependency

This repository requires cairo v2.8.2, [scarb v2.8.3](https://docs.swmansion.com/scarb/), [starknet foundry v0.31.0](https://foundry-rs.github.io/starknet-foundry/) and [universal-sierra-compiler v2.3.0](https://github.com/software-mansion/universal-sierra-compiler). Check the project page to install the right version of tools on your system. Try the following command to verify installation:
```shell
scarb -V
# expected output: scarb 2.8.3 (54938ce3b 2024-09-26)
snforge -V
# expected output: snforge 0.31.0
universal-sierra-compiler -V
#expected output: universal-sierra-compiler 2.3.0
```

## run test

Open this project in VSCode or other IDE, run the following code in terminal:
```shell
snforge test
```
Then you can see the result.

## TODO
- [x] Fix U256 `Store` trait (waiting for cairo 2.7.0)

  (Fixed using maintain a `(contract_address, index) -> value` mapping and `(contract_address -> array_length)` mapping. Still waing for cairo native array storage.)

  update: cairo 2.8.3 still not suitable for dynamic array, so use backend+signature instead.

- [x] Add more tests for access control
- [x] Create a dex for the wrapped token.
- [ ] Add more function to the pool.
- [ ] Add signature verification to `unwrap` function.

You are welcomed to contribute!