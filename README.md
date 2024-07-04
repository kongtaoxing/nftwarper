# NFT Wrapper

Warp ERC721 NFT into ERC20 token to increace liquidity of NFT in Starknet.

## install dependency

This repository requires cairo v2.6.5, [scarb v2.6.5](https://docs.swmansion.com/scarb/), [starknet foundry v0.25.0](https://foundry-rs.github.io/starknet-foundry/) and [universal-sierra-compiler v2.1.0](https://github.com/software-mansion/universal-sierra-compiler). Check the project page to install the right version of tools on your system. Try the following command to verify installation:
```shell
scarb -V
# expected output: scarb 2.6.5 (d49f54394 2024-06-11)
snforge -V
# expected output: snforge 0.25.0
universal-sierra-compiler -V
#expected output: universal-sierra-compiler 2.1.0
```

## run test

Open this project in VSCode or other IDE, run the following code in terminal:
```shell
snforge test
```
Then you can see the result.

## TODO
- [ ] Fix U256 `Store` trait (waiting for cairo 2.7.0)
- [ ] add more tests for access control

You are welcomed to contribute!