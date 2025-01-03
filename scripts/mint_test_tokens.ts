import hre from 'hardhat';

async function main() {
  const accounts = await hre.ethers.getSigners();
  const { minter } = await hre.getNamedAccounts();

  const tokenContract = await hre.ethers.getContractAt(
    'Token',
    hre.helpers.contractDeployments.contracts['Token'].evmAddress,
  );
  const amountToMint = hre.ethers.parseEther(`${5_000_000}`);

  for (const acc of accounts) {
    await tokenContract.mint(acc.address, amountToMint, {
      from: minter,
      gasLimit: 80_000,
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
