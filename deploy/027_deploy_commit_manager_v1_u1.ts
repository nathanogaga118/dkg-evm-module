import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  await hre.helpers.deploy({
    newContractName: 'CommitManagerV1U1',
  });
};

export default func;
func.tags = ['CommitManagerV1U1'];
func.dependencies = [
  'Hub',
  'ScoringProxy',
  'ServiceAgreementV1',
  'Staking',
  'ContentAssetStorage',
  'IdentityStorage',
  'ParametersStorage',
  'ProfileStorage',
  'ServiceAgreementStorageProxy',
  'ShardingTableStorage',
  'StakingStorage',
  'UnfinalizedStateStorage',
];
