const { Account, constants, ec, json, stark, Provider, hash, CallData, shortString, RpcProvider, typedData, Contract, uint256, encode } = require('starknet');
require('dotenv').config()

const main = async ({ token_id }) => {
  const typedDataValidate = {
    types: {
      StarkNetDomain: [
        { name: 'name', type: 'felt' },
        { name: 'version', type: 'felt' },
        { name: 'chainId', type: 'felt' },
      ],
      Unwrap: [
        { name: 'user_address', type: 'felt' },
        { name: 'nft_contract_address', type: 'felt' },
        { name: 'token_id', type: 'u256' },
      ],
      u256: [
        { name: 'low', type: 'felt' },
        { name: 'high', type: 'felt' },
      ]
    },
    primaryType: 'Unwrap',
    domain: {
      name: 'NFTWrapper', // put the name of your dapp to ensure that the signatures will not be used by other DAPP
      version: '1',
      chainId: shortString.encodeShortString('SN_SEPOLIA'), // shortString of 'SN_GOERLI' (or 'SN_MAIN'), to be sure that signature can't be used by other network.
    },
    message: {
      user_address: '0x63616c6c65725f61646472657373',
      nft_contract_address: '0x6e8522a2b09895f76bae60aee06349eb1acc4590760453ddb8d56e85c89ca76',
      token_id: uint256.bnToUint256(token_id),
    },
  };
  
  const provider = new RpcProvider({ nodeUrl: process.env.SEPOLIA_NODE_URL });
  const account = new Account(provider, process.env.ADDRESS, process.env.PRIVATE_KEY);
  console.log('public key:', ec.starkCurve.getStarkKey(process.env.PRIVATE_KEY));
  const signature = (await account.signMessage(typedDataValidate));
  console.log('Sinature:', signature);

  const messageHash = typedData.getMessageHash(typedDataValidate, process.env.ADDRESS);
  console.log('Message Hash:', messageHash);    //0x11357f6641ca52050112c85804ea8f59a98be12c5296af634ad4fef0d9af0f1

  const addressAbi = (await provider.getClassAt(process.env.ADDRESS)).abi;
  const addressContract = new Contract(addressAbi, process.env.ADDRESS, provider);
  try {
    const isValidSignature = await addressContract.is_valid_signature(messageHash, [signature.r, signature.s],);
    console.log('Signature is:', shortString.decodeShortString(isValidSignature));
  }
  catch (error) {
    console.log('Error:', error);
  }
}

const runMain = async () => {
  try {
    await main({token_id: 1});
    await main({ token_id: 3 });
  } catch (error) {
    console.error(error)
  }
}

runMain();