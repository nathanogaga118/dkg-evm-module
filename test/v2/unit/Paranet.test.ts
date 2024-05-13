import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import hre from 'hardhat';

import {
  HubController,
  Paranet,
  ContentAssetStorageV2,
  ContentAssetV2,
  ParanetsRegistry,
  ParanetServicesRegistry,
  ParanetKnowledgeMinersRegistry,
  ParanetKnowledgeAssetsRegistry,
  HashingProxy,
  ServiceAgreementStorageProxy,
  ParanetIncentivesPool,
} from '../../../typechain';
import {} from '../../helpers/constants';

type deployParanetFixture = {
  accounts: SignerWithAddress[];
  Paranet: Paranet;
  HubController: HubController;
  ContentAssetV2: ContentAssetV2;
  ContentAssetStorageV2: ContentAssetStorageV2;
  ParanetsRegistry: ParanetsRegistry;
  ParanetServicesRegistry: ParanetServicesRegistry;
  ParanetKnowledgeMinersRegistry: ParanetKnowledgeMinersRegistry;
  ParanetKnowledgeAssetsRegistry: ParanetKnowledgeAssetsRegistry;
  HashingProxy: HashingProxy;
  ServiceAgreementStorageProxy: ServiceAgreementStorageProxy;
};

describe('@v2 @unit ParanetKnowledgeMinersRegistry contract', function () {
  let accounts: SignerWithAddress[];
  let Paranet: Paranet;
  let HubController: HubController;
  let ContentAssetV2: ContentAssetV2;
  let ContentAssetStorageV2: ContentAssetStorageV2;
  let ParanetsRegistry: ParanetsRegistry;
  let ParanetServicesRegistry: ParanetServicesRegistry;
  let ParanetKnowledgeMinersRegistry: ParanetKnowledgeMinersRegistry;
  let ParanetKnowledgeAssetsRegistry: ParanetKnowledgeAssetsRegistry;
  let HashingProxy: HashingProxy;
  let ServiceAgreementStorageProxy: ServiceAgreementStorageProxy;

  async function deployParanetFixture(): Promise<deployParanetFixture> {
    await hre.deployments.fixture(
      [
        'HubV2',
        'HubController',
        'Paranet',
        'ContentAssetStorageV2',
        'ContentAssetV2',
        'ParanetsRegistry',
        'ParanetServicesRegistry',
        'ParanetKnowledgeMinersRegistry',
        'ParanetKnowledgeAssetsRegistry',
        'HashingProxy',
        'ServiceAgreementStorageProxy',
      ],
      { keepExistingDeployments: false },
    );

    HubController = await hre.ethers.getContract<HubController>('HubController');
    Paranet = await hre.ethers.getContract<Paranet>('Paranet');
    ContentAssetV2 = await hre.ethers.getContract<ContentAssetV2>('ContentAsset');
    ContentAssetStorageV2 = await hre.ethers.getContract<ContentAssetStorageV2>('ContentAssetStorage');
    ParanetsRegistry = await hre.ethers.getContract<ParanetsRegistry>('ParanetsRegistry');
    ParanetServicesRegistry = await hre.ethers.getContract<ParanetServicesRegistry>('ParanetServicesRegistry');
    ParanetKnowledgeMinersRegistry = await hre.ethers.getContract<ParanetKnowledgeMinersRegistry>(
      'ParanetKnowledgeMinersRegistry',
    );
    ParanetKnowledgeAssetsRegistry = await hre.ethers.getContract<ParanetKnowledgeAssetsRegistry>(
      'ParanetKnowledgeAssetsRegistry',
    );
    ServiceAgreementStorageProxy = await hre.ethers.getContract<ServiceAgreementStorageProxy>(
      'ServiceAgreementStorageProxy',
    );
    HashingProxy = await hre.ethers.getContract<HashingProxy>('HashingProxy');

    accounts = await hre.ethers.getSigners();
    await HubController.setContractAddress('HubOwner', accounts[0].address);

    return {
      accounts,
      Paranet,
      HubController,
      ContentAssetV2,
      ContentAssetStorageV2,
      ParanetsRegistry,
      ParanetServicesRegistry,
      ParanetKnowledgeMinersRegistry,
      ParanetKnowledgeAssetsRegistry,
      HashingProxy,
      ServiceAgreementStorageProxy,
    };
  }

  beforeEach(async () => {
    hre.helpers.resetDeploymentsJson();
    ({ accounts, Paranet } = await loadFixture(deployParanetFixture));
  });

  it('The contract is named "Paranet"', async () => {
    expect(await Paranet.name()).to.equal('Paranet');
  });

  it('The contract is version "2.0.0"', async () => {
    expect(await Paranet.version()).to.equal('2.0.0');
  });

  it('should register paranet', async () => {
    const paranetId = await registerParanet(accounts, Paranet, 1);

    const paranetExists = await ParanetsRegistry.paranetExists(paranetId);

    expect(paranetExists).to.equal(true);
  });

  it('should not register paranet that is already registered', async () => {
    const paranetId = await registerParanet(accounts, Paranet, 1);

    const paranetExists = await ParanetsRegistry.paranetExists(paranetId);

    expect(paranetExists).to.equal(true);

    await expect(registerParanet(accounts, Paranet, 1)).to.be.revertedWithCustomError(
      Paranet,
      'ParanetHasAlreadyBeenRegistered',
    );
  });

  it('should register paranet emit ParanetRegistered event', async () => {
    expect(await registerParanet(accounts, Paranet, 1)).to.emit(Paranet, 'ParanetRegistered');
  });

  it('should register paranet will correctly intitalized incentives pool', async () => {
    const paranetId = await registerParanet(accounts, Paranet, 1);

    const incentivesPoolAddress = await ParanetsRegistry.getIncentivesPool(paranetId);
    const incentivesPoolABI = hre.helpers.getAbi('ParanetIncentivesPool');
    const incentivesPool = await hre.ethers.getContractAt<ParanetIncentivesPool>(
      incentivesPoolABI,
      incentivesPoolAddress,
    );

    expect(await incentivesPool.callStatic.parentParanetId()).to.be.equal(paranetId);
    expect(await incentivesPool.callStatic.tracToNeuroRatio()).to.be.equal(5);
    expect(await incentivesPool.callStatic.tracTarget()).to.be.equal(10_000);
    expect(await incentivesPool.callStatic.operatorRewardPercentage()).to.be.equal(5);
  });

  it('should update paranet name with opertor wallet', async () => {
    const paranetId1 = await registerParanet(accounts, Paranet, 1);

    await Paranet.connect(accounts[101]).updateParanetName(
      accounts[1].address,
      getHashFromNumber(1),
      'Net Test Paranet Name',
    );

    const newName = await ParanetsRegistry.getName(paranetId1);

    expect(newName).to.be.equal('Net Test Paranet Name');
  });

  it('should update paranet name emit event', async () => {
    const paranetId1 = await registerParanet(accounts, Paranet, 1);

    expect(
      await Paranet.connect(accounts[101]).updateParanetName(
        accounts[1].address,
        getHashFromNumber(1),
        'Net Test Paranet Name',
      ),
    ).to.emit(Paranet, 'ParanetNameUpdated');

    const newName = await ParanetsRegistry.getName(paranetId1);

    expect(newName).to.be.equal('Net Test Paranet Name');
  });

  it('should rewert update of paranet name with non opertor wallet', async () => {
    await registerParanet(accounts, Paranet, 1);

    await expect(
      Paranet.connect(accounts[201]).updateParanetDescription(
        accounts[1].address,
        getHashFromNumber(1),
        'Net Test Paranet Description',
      ),
    ).to.be.revertedWith('Fn can only be used by operator');
  });

  it('should update paranet description with opertor wallet', async () => {
    const paranetId1 = await registerParanet(accounts, Paranet, 1);

    await Paranet.connect(accounts[101]).updateParanetDescription(
      accounts[1].address,
      getHashFromNumber(1),
      'New Test Paranet Description',
    );

    const newDescription = await ParanetsRegistry.getDescription(paranetId1);

    expect(newDescription).to.be.equal('New Test Paranet Description');
  });

  it('should update paranet description emit event', async () => {
    await registerParanet(accounts, Paranet, 1);

    await expect(
      Paranet.connect(accounts[101]).updateParanetDescription(
        accounts[1].address,
        getHashFromNumber(1),
        'Net Test Paranet Description',
      ),
    ).to.emit(Paranet, 'ParanetDescriptionUpdated');
  });

  it('should rewert update of paranet description with non opertor wallet', async () => {
    await registerParanet(accounts, Paranet, 1);

    await expect(
      Paranet.connect(accounts[201]).updateParanetDescription(
        accounts[1].address,
        getHashFromNumber(1),
        'Net Test Paranet Description',
      ),
    ).to.be.revertedWith('Fn can only be used by operator');
  });
  it('should transfer paranet ownership with opertor wallet', async () => {
    const paranetId1 = await registerParanet(accounts, Paranet, 1);

    await Paranet.connect(accounts[101]).transferParanetOwnership(
      accounts[1].address,
      getHashFromNumber(1),
      accounts[102].address,
    );

    const newOperator = await ParanetsRegistry.getOperatorAddress(paranetId1);

    expect(newOperator).to.be.equal(accounts[102].address);
  });

  it('should transfer paranet ownership operator emit event', async () => {
    await registerParanet(accounts, Paranet, 1);

    await expect(
      Paranet.connect(accounts[101]).transferParanetOwnership(
        accounts[1].address,
        getHashFromNumber(1),
        accounts[102].address,
      ),
    ).to.emit(Paranet, 'ParanetOwnershipTransferred');
  });

  it('should rewert transfer of paranet ownership with non opertor wallet', async () => {
    await registerParanet(accounts, Paranet, 1);

    await expect(
      Paranet.connect(accounts[201]).updateParanetDescription(
        accounts[1].address,
        getHashFromNumber(1),
        accounts[102].address,
      ),
    ).to.be.revertedWith('Fn can only be used by operator');
  });

  it('should register paranet service', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );
    const paranetServiceId = getId(accounts[50].address, 50);
    const paranetServiceObject = await ParanetServicesRegistry.getParanetServiceObject(paranetServiceId);

    expect(paranetServiceObject.paranetServiceKAStorageContract).to.equal(accounts[50].address);
    expect(paranetServiceObject.paranetServiceKATokenId).to.equal(getHashFromNumber(50));
    expect(paranetServiceObject.operator).to.equal(accounts[5].address);
    expect(paranetServiceObject.worker).to.equal(accounts[51].address);
    expect(paranetServiceObject.name).to.equal('Test Paranet Servic Name');
    expect(paranetServiceObject.description).to.equal('Test Paranet Servic Description');
    expect(paranetServiceObject.metadata).to.equal(hre.ethers.utils.formatBytes32String('Metadata'));
  });

  it('should register paranet service emit event', async () => {
    await expect(
      Paranet.connect(accounts[5]).registerParanetService(
        accounts[50].address,
        getHashFromNumber(50),
        'Test Paranet Servic Name',
        'Test Paranet Servic Description',
        accounts[51].address,
        hre.ethers.utils.formatBytes32String('Metadata'),
      ),
    ).to.emit(Paranet, 'ParanetServiceRegistered');
  });

  it('should transfer paranet service ownership operator wiht operator wallet', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );

    Paranet.connect(accounts[5]).transferParanetServiceOwnership(
      accounts[50].address,
      getHashFromNumber(50),
      accounts[500].address,
    );

    const paranetServiceId = getId(accounts[50].address, 50);
    const newOperator = await ParanetServicesRegistry.getOperatorAddress(paranetServiceId);

    expect(newOperator).to.be.equal(accounts[500].address);
  });

  it('should transfer paranet service ownership operator emit event', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );
    await expect(
      Paranet.connect(accounts[5]).transferParanetServiceOwnership(
        accounts[50].address,
        getHashFromNumber(50),
        accounts[500].address,
      ),
    ).to.emit(Paranet, 'ParanetServiceOwnershipTransferred');
  });

  it('should revert transfer paranet service ownership operator with non operator wallet', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );

    await expect(
      Paranet.connect(accounts[6]).transferParanetServiceOwnership(
        accounts[50].address,
        getHashFromNumber(50),
        accounts[500].address,
      ),
    ).to.be.revertedWith('Fn can only be used by operator');
  });

  it('should update paranet service name operator wallet', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );
    await Paranet.connect(accounts[5]).updateParanetServiceName(
      accounts[50].address,
      getHashFromNumber(50),
      'New Test Paranet Servic Name',
    );
    const paranetServiceId = getId(accounts[50].address, 50);
    const newParanetServiceName = await ParanetServicesRegistry.getName(paranetServiceId);

    expect(newParanetServiceName).to.equal('New Test Paranet Servic Name');
  });
  it('should update paranet service name emit event', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );

    expect(
      await Paranet.connect(accounts[5]).updateParanetServiceName(
        accounts[50].address,
        getHashFromNumber(50),
        'New Test Paranet Servic Name',
      ),
    ).to.revertedWith('Fn can only be used by operator');
  });

  it('should revert update paranet name with non operator wallet', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );
    expect(
      await Paranet.connect(accounts[5]).updateParanetServiceName(
        accounts[50].address,
        getHashFromNumber(50),
        'New Test Paranet Servic Name',
      ),
    ).to.emit(Paranet, 'ParanetServiceNameUpdated');
  });

  it('should update paranet service description operator wallet', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );
    await Paranet.connect(accounts[5]).updateParanetServiceDescription(
      accounts[50].address,
      getHashFromNumber(50),
      'New Test Paranet Servic Description',
    );
    const paranetServiceId = getId(accounts[50].address, 50);
    const newParanetServiceDescription = await ParanetServicesRegistry.getDescription(paranetServiceId);

    expect(newParanetServiceDescription).to.equal('New Test Paranet Servic Description');
  });

  it('should update paranet service description emit event', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );

    expect(
      await Paranet.connect(accounts[5]).updateParanetServiceDescription(
        accounts[50].address,
        getHashFromNumber(50),
        'New Test Paranet Servic Description',
      ),
    ).to.revertedWith('Fn can only be used by operator');
  });

  it('should revert update paranet description with non operator wallet', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );
    expect(
      await Paranet.connect(accounts[5]).updateParanetServiceDescription(
        accounts[50].address,
        getHashFromNumber(50),
        'New Test Paranet Servic Description',
      ),
    ).to.emit(Paranet, 'ParanetServiceDescriptionUpdated');
  });

  it('should update paranet service worker operator wallet', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );
    await Paranet.connect(accounts[5]).updateParanetServiceWorker(
      accounts[50].address,
      getHashFromNumber(50),
      accounts[49].address,
    );
    const paranetServiceId = getId(accounts[50].address, 50);
    const newParanetServiceWorker = await ParanetServicesRegistry.getWorkerAddress(paranetServiceId);
    expect(newParanetServiceWorker).to.equal(accounts[49].address);
  });

  it('should update paranet service worker emit event', async () => {
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );

    expect(
      await Paranet.connect(accounts[5]).updateParanetServiceWorker(
        accounts[50].address,
        getHashFromNumber(50),
        accounts[49].address,
      ),
    ).to.revertedWith('Fn can only be used by operator');
  });

  it('should add paranet service to paranet with paranet operator wallet', async () => {
    const paranetId = await registerParanet(accounts, Paranet, 3);
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );
    const paranetServiceId = getId(accounts[50].address, 50);

    await Paranet.connect(accounts[103]).addParanetService(
      accounts[3].address,
      getHashFromNumber(3),
      accounts[50].address,
      getHashFromNumber(50),
    );

    const isServiceImplemented = await ParanetsRegistry.isServiceImplemented(paranetId, paranetServiceId);

    expect(isServiceImplemented).to.be.equal(true);

    const services = await ParanetsRegistry.getServices(paranetId);

    expect(services.length).to.be.equal(1);
    expect(services[0]).to.be.equal(paranetServiceId);
    expect(await ParanetsRegistry.getServicesCount(paranetId)).to.be.equal(1);
  });
  it('should revert on add paranet service to paranet with not paranet operator wallet', async () => {
    await registerParanet(accounts, Paranet, 3);
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );

    await expect(
      Paranet.connect(accounts[153]).addParanetService(
        accounts[3].address,
        getHashFromNumber(3),
        accounts[50].address,
        getHashFromNumber(50),
      ),
    ).to.be.revertedWith('Fn can only be used by operator');
  });
  it('should revert on add non existing paranet service to paranet with paranet operator wallet', async () => {
    await registerParanet(accounts, Paranet, 3);
    await expect(
      Paranet.connect(accounts[103]).addParanetService(
        accounts[3].address,
        getHashFromNumber(3),
        accounts[50].address,
        getHashFromNumber(50),
      ),
    ).to.be.revertedWithCustomError(Paranet, 'ParanetServiceDoesntExist');
  });
  it('should add paranet service to paranet emit event', async () => {
    await registerParanet(accounts, Paranet, 3);
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name',
      'Test Paranet Servic Description',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata'),
    );
    await expect(
      Paranet.connect(accounts[103]).addParanetService(
        accounts[3].address,
        getHashFromNumber(3),
        accounts[50].address,
        getHashFromNumber(50),
      ),
    ).to.emit(Paranet, 'ParanetServiceAdded');
  });

  it('should add paranet services to paranet with paranet operator wallet', async () => {
    const paranetId = await registerParanet(accounts, Paranet, 3);
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name 0',
      'Test Paranet Servic Description 0',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata 0'),
    );
    await Paranet.connect(accounts[6]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(56),
      'Test Paranet Servic Name 1',
      'Test Paranet Servic Description 1',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata 1'),
    );
    const paranetServiceId0 = getId(accounts[50].address, 50);
    const paranetServiceId1 = getId(accounts[50].address, 56);

    const servicesToBeAdded = [
      {
        knowledgeAssetStorageContract: accounts[50].address,
        tokenId: getHashFromNumber(50),
      },
      {
        knowledgeAssetStorageContract: accounts[50].address,
        tokenId: getHashFromNumber(56),
      },
    ];
    await Paranet.connect(accounts[103]).addParanetServices(
      accounts[3].address,
      getHashFromNumber(3),
      servicesToBeAdded,
    );

    const isService0Implemented = await ParanetsRegistry.isServiceImplemented(paranetId, paranetServiceId0);
    const isService1Implemented = await ParanetsRegistry.isServiceImplemented(paranetId, paranetServiceId1);

    expect(isService0Implemented).to.be.equal(true);
    expect(isService1Implemented).to.be.equal(true);

    const services = await ParanetsRegistry.getServices(paranetId);

    expect(services.length).to.be.equal(2);
    expect(services[0]).to.be.equal(paranetServiceId0);
    expect(services[1]).to.be.equal(paranetServiceId1);
    expect(await ParanetsRegistry.getServicesCount(paranetId)).to.be.equal(2);
  });
  it('should revert on add paranet services to paranet with not paranet operator wallet', async () => {
    const paranetId = await registerParanet(accounts, Paranet, 3);
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name 0',
      'Test Paranet Servic Description 0',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata 0'),
    );
    await Paranet.connect(accounts[6]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(56),
      'Test Paranet Servic Name 1',
      'Test Paranet Servic Description 1',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata 1'),
    );
    const paranetServiceId0 = getId(accounts[50].address, 50);
    const paranetServiceId1 = getId(accounts[50].address, 56);

    const servicesToBeAdded = [
      {
        knowledgeAssetStorageContract: accounts[50].address,
        tokenId: getHashFromNumber(50),
      },
      {
        knowledgeAssetStorageContract: accounts[50].address,
        tokenId: getHashFromNumber(56),
      },
    ];
    await expect(
      Paranet.connect(accounts[105]).addParanetServices(accounts[3].address, getHashFromNumber(3), servicesToBeAdded),
    ).to.revertedWith('Fn can only be used by operator');

    const isService0Implemented = await ParanetsRegistry.isServiceImplemented(paranetId, paranetServiceId0);
    const isService1Implemented = await ParanetsRegistry.isServiceImplemented(paranetId, paranetServiceId1);

    expect(isService0Implemented).to.be.equal(false);
    expect(isService1Implemented).to.be.equal(false);

    const services = await ParanetsRegistry.getServices(paranetId);

    expect(services.length).to.be.equal(0);
    expect(await ParanetsRegistry.getServicesCount(paranetId)).to.be.equal(0);
  });

  it('should revert on add non existing paranet services to paranet with paranet operator wallet', async () => {
    const paranetId = await registerParanet(accounts, Paranet, 3);
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name 0',
      'Test Paranet Servic Description 0',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata 0'),
    );

    const paranetServiceId0 = getId(accounts[50].address, 50);
    const paranetServiceId1 = getId(accounts[50].address, 56);

    const servicesToBeAdded = [
      {
        knowledgeAssetStorageContract: accounts[50].address,
        tokenId: getHashFromNumber(50),
      },
      {
        knowledgeAssetStorageContract: accounts[50].address,
        tokenId: getHashFromNumber(56),
      },
    ];
    await expect(
      Paranet.connect(accounts[103]).addParanetServices(accounts[3].address, getHashFromNumber(3), servicesToBeAdded),
    ).to.revertedWithCustomError(Paranet, 'ParanetServiceDoesntExist');

    const isService0Implemented = await ParanetsRegistry.isServiceImplemented(paranetId, paranetServiceId0);
    const isService1Implemented = await ParanetsRegistry.isServiceImplemented(paranetId, paranetServiceId1);

    expect(isService0Implemented).to.be.equal(false);
    expect(isService1Implemented).to.be.equal(false);

    const services = await ParanetsRegistry.getServices(paranetId);

    expect(services.length).to.be.equal(0);
    expect(await ParanetsRegistry.getServicesCount(paranetId)).to.be.equal(0);
  });
  it('should add paranet services to paranet emit event', async () => {
    await registerParanet(accounts, Paranet, 3);
    await Paranet.connect(accounts[5]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(50),
      'Test Paranet Servic Name 0',
      'Test Paranet Servic Description 0',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata 0'),
    );
    await Paranet.connect(accounts[6]).registerParanetService(
      accounts[50].address,
      getHashFromNumber(56),
      'Test Paranet Servic Name 1',
      'Test Paranet Servic Description 1',
      accounts[51].address,
      hre.ethers.utils.formatBytes32String('Metadata 1'),
    );

    const servicesToBeAdded = [
      {
        knowledgeAssetStorageContract: accounts[50].address,
        tokenId: getHashFromNumber(50),
      },
      {
        knowledgeAssetStorageContract: accounts[50].address,
        tokenId: getHashFromNumber(56),
      },
    ];
    await expect(
      Paranet.connect(accounts[103]).addParanetServices(accounts[3].address, getHashFromNumber(3), servicesToBeAdded),
    )
      .to.emit(Paranet, 'ParanetServiceAdded')
      .and.to.emit(Paranet, 'ParanetServiceAdded');
  });

  // mintKnowledgeAsset
  //  -ParanetDoesntExist
  //  -Create a profile, dosn't create multiple profiles for same miner
  //  -createAsset
  //  -addKnowledgeAsset
  //  -addCumulativeKnowledgeValue
  //  -addSubmittedKnowledgeAsset
  //  -addCumulativeTracSpent
  //  -addUnrewardedTracSpent
  //  -incrementTotalSubmittedKnowledgeAssetsCount
  //  -addTotalTracSpent
  //  -KnowledgeAssetSubmittedToParanet

  // it('should mint knowlidge asset & add it to paranet', async () => {});
  // it("should revert mint knowlidge asset & add it to paranet in paranet doesn't exist", async () => {});

  async function registerParanet(accounts: SignerWithAddress[], Paranet: Paranet, number: number) {
    const paranetKAStorageContract = accounts[number].address;
    const paranetKATokenId = getHashFromNumber(number);
    const paranetName = 'Test paranet 1';
    const paranetDescription = 'Description of Test Paranet';
    // Make test that test different values for this
    const tracToNeuroRatio = 5;
    const tracTarget = 10_000;
    const operatorRewardPercentage = 5;

    const accSignerParanet = Paranet.connect(accounts[100 + number]);

    await accSignerParanet.registerParanet(
      paranetKAStorageContract,
      paranetKATokenId,
      paranetName,
      paranetDescription,
      tracToNeuroRatio,
      tracTarget,
      operatorRewardPercentage,
    );

    return hre.ethers.utils.keccak256(
      hre.ethers.utils.solidityPack(['address', 'uint256'], [paranetKAStorageContract, paranetKATokenId]),
    );
  }

  function getHashFromNumber(number: number) {
    return hre.ethers.utils.keccak256(hre.ethers.utils.solidityPack(['uint256'], [number]));
  }

  function getId(address: string, number: number) {
    return hre.ethers.utils.keccak256(
      hre.ethers.utils.solidityPack(['address', 'uint256'], [address, getHashFromNumber(number)]),
    );
  }
});
