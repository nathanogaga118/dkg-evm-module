// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.20;

import {HubDependent} from "../../abstract/HubDependent.sol";
import {INamed} from "../../interfaces/INamed.sol";
import {IVersioned} from "../../interfaces/IVersioned.sol";
import {ParanetLib} from "../../libraries/ParanetLib.sol";
import {UnorderedNamedContractDynamicSet} from "../../libraries/UnorderedNamedContractDynamicSet.sol";

contract ParanetsRegistry is INamed, IVersioned, HubDependent {
    using UnorderedNamedContractDynamicSet for UnorderedNamedContractDynamicSet.Set;

    string private constant _NAME = "ParanetsRegistry";
    string private constant _VERSION = "1.0.0";

    // Paranet ID => Paranet Object
    mapping(bytes32 => ParanetLib.Paranet) internal paranets;

    // solhint-disable-next-line no-empty-blocks
    constructor(address hubAddress) HubDependent(hubAddress) {}

    function name() external pure virtual override returns (string memory) {
        return _NAME;
    }

    function version() external pure virtual override returns (string memory) {
        return _VERSION;
    }

    function registerParanet(
        address knowledgeAssetStorageContract,
        uint256 tokenId,
        string calldata paranetName,
        string calldata paranetDescription,
        ParanetLib.NodesAccessPolicy nodesAccessPolicy,
        ParanetLib.MinersAccessPolicy minersAccessPolicy,
        ParanetLib.KnowledgeAssetsAccessPolicy knowledgeAssetsAccessPolicy
    ) external onlyContracts returns (bytes32) {
        ParanetLib.Paranet storage paranet = paranets[
            keccak256(abi.encodePacked(knowledgeAssetStorageContract, tokenId))
        ];

        paranet.paranetKAStorageContract = knowledgeAssetStorageContract;
        paranet.paranetKATokenId = tokenId;
        paranet.name = paranetName;
        paranet.description = paranetDescription;
        paranet.nodesAccessPolicy = nodesAccessPolicy;
        paranet.minersAccessPolicy = minersAccessPolicy;
        paranet.knowledgeAssetsAccessPolicy = knowledgeAssetsAccessPolicy;

        return keccak256(abi.encodePacked(knowledgeAssetStorageContract, tokenId));
    }

    function deleteParanet(bytes32 paranetId) external onlyContracts {
        delete paranets[paranetId];
    }

    function paranetExists(bytes32 paranetId) external view returns (bool) {
        return
            keccak256(
                abi.encodePacked(paranets[paranetId].paranetKAStorageContract, paranets[paranetId].paranetKATokenId)
            ) == paranetId;
    }

    function getParanetMetadata(bytes32 paranetId) external view returns (ParanetLib.ParanetMetadata memory) {
        ParanetLib.Paranet storage paranet = paranets[paranetId];

        return
            ParanetLib.ParanetMetadata({
                paranetKAStorageContract: paranet.paranetKAStorageContract,
                paranetKATokenId: paranet.paranetKATokenId,
                name: paranet.name,
                description: paranet.description,
                nodesAccessPolicy: paranet.nodesAccessPolicy,
                minersAccessPolicy: paranet.minersAccessPolicy,
                knowledgeAssetsAccessPolicy: paranet.knowledgeAssetsAccessPolicy,
                cumulativeKnowledgeValue: paranet.cumulativeKnowledgeValue
            });
    }

    function getParanetKnowledgeAssetLocator(bytes32 paranetId) external view returns (address, uint256) {
        return (paranets[paranetId].paranetKAStorageContract, paranets[paranetId].paranetKATokenId);
    }

    function getName(bytes32 paranetId) external view returns (string memory) {
        return paranets[paranetId].name;
    }

    function setName(bytes32 paranetId, string calldata name_) external onlyContracts {
        paranets[paranetId].name = name_;
    }

    function getDescription(bytes32 paranetId) external view returns (string memory) {
        return paranets[paranetId].description;
    }

    function setDescription(bytes32 paranetId, string calldata description) external onlyContracts {
        paranets[paranetId].description = description;
    }

    function getNodesAccessPolicy(bytes32 paranetId) external view returns (ParanetLib.NodesAccessPolicy) {
        return paranets[paranetId].nodesAccessPolicy;
    }

    function setNodesAccessPolicy(
        bytes32 paranetId,
        ParanetLib.NodesAccessPolicy nodesAccessPolicy
    ) external onlyContracts {
        paranets[paranetId].nodesAccessPolicy = nodesAccessPolicy;
    }

    function getMinersAccessPolicy(bytes32 paranetId) external view returns (ParanetLib.MinersAccessPolicy) {
        return paranets[paranetId].minersAccessPolicy;
    }

    function setMinersAccessPolicy(
        bytes32 paranetId,
        ParanetLib.MinersAccessPolicy minersAccessPolicy
    ) external onlyContracts {
        paranets[paranetId].minersAccessPolicy = minersAccessPolicy;
    }

    function getKnowledgeAssetsAccessPolicy(
        bytes32 paranetId
    ) external view returns (ParanetLib.KnowledgeAssetsAccessPolicy) {
        return paranets[paranetId].knowledgeAssetsAccessPolicy;
    }

    function setKnowledgeAssetsAccessPolicy(
        bytes32 paranetId,
        ParanetLib.KnowledgeAssetsAccessPolicy knowledgeAssetsAccessPolicy
    ) external onlyContracts {
        paranets[paranetId].knowledgeAssetsAccessPolicy = knowledgeAssetsAccessPolicy;
    }

    function addNodeJoinRequest(
        bytes32 paranetId,
        uint72 identityId,
        ParanetLib.RequestStatus status
    ) external onlyContracts {
        paranets[paranetId].paranetNodeJoinRequests[identityId].push(
            ParanetLib.ParanetNodeJoinRequest({
                createdAt: block.timestamp,
                updatedAt: block.timestamp,
                identityId: identityId,
                status: status
            })
        );
    }

    function updateNodeJoinRequestStatus(
        bytes32 paranetId,
        uint72 identityId,
        uint256 index,
        ParanetLib.RequestStatus status
    ) external onlyContracts {
        paranets[paranetId].paranetNodeJoinRequests[identityId][index].status = status;
        paranets[paranetId].paranetNodeJoinRequests[identityId][index].updatedAt = block.timestamp;
    }

    function removeNodeJoinRequest(bytes32 paranetId, uint72 identityId, uint256 index) external onlyContracts {
        delete paranets[paranetId].paranetNodeJoinRequests[identityId][index];
    }

    function getNodeJoinRequest(
        bytes32 paranetId,
        uint72 identityId,
        uint256 index
    ) external view returns (ParanetLib.ParanetNodeJoinRequest memory) {
        return paranets[paranetId].paranetNodeJoinRequests[identityId][index];
    }

    function getLatestNodeJoinRequest(
        bytes32 paranetId,
        uint72 identityId
    ) external view returns (ParanetLib.ParanetNodeJoinRequest memory) {
        return
            paranets[paranetId].paranetNodeJoinRequests[identityId][
                paranets[paranetId].paranetNodeJoinRequests[identityId].length - 1
            ];
    }

    function getNodeJoinRequests(
        bytes32 paranetId,
        uint72 identityId
    ) external view returns (ParanetLib.ParanetNodeJoinRequest[] memory) {
        return paranets[paranetId].paranetNodeJoinRequests[identityId];
    }

    function getNodeJoinRequestsCount(bytes32 paranetId, uint72 identityId) external view returns (uint256) {
        return paranets[paranetId].paranetNodeJoinRequests[identityId].length;
    }

    function addCuratedNode(bytes32 paranetId, uint72 identityId, bytes calldata nodeId) external onlyContracts {
        paranets[paranetId].curatedNodesIndexes[identityId] = paranets[paranetId].curatedNodes.length;
        paranets[paranetId].curatedNodes.push(ParanetLib.Node({identityId: identityId, nodeId: nodeId}));
    }

    function removeCuratedNode(bytes32 paranetId, uint72 identityId) external onlyContracts {
        paranets[paranetId].curatedNodes[paranets[paranetId].curatedNodesIndexes[identityId]] = paranets[paranetId]
            .curatedNodes[paranets[paranetId].curatedNodes.length - 1];
        paranets[paranetId].curatedNodesIndexes[
            paranets[paranetId].curatedNodes[paranets[paranetId].curatedNodes.length - 1].identityId
        ] = paranets[paranetId].curatedNodesIndexes[identityId];

        delete paranets[paranetId].curatedNodesIndexes[identityId];
        paranets[paranetId].curatedNodes.pop();
    }

    function getCuratedNodes(bytes32 paranetId) external view returns (ParanetLib.Node[] memory) {
        return paranets[paranetId].curatedNodes;
    }

    function getCuratedNodesCount(bytes32 paranetId) external view returns (uint256) {
        return paranets[paranetId].curatedNodes.length;
    }

    function isCuratedNode(bytes32 paranetId, uint72 identityId) external view returns (bool) {
        return (paranets[paranetId].curatedNodes.length != 0 &&
            paranets[paranetId].curatedNodes[paranets[paranetId].curatedNodesIndexes[identityId]].identityId ==
            identityId);
    }

    function getIncentivesPoolAddress(
        bytes32 paranetId,
        string calldata incentivesPoolType
    ) external view returns (address) {
        return paranets[paranetId].incentivesPools.get(incentivesPoolType).addr;
    }

    function setIncentivesPoolAddress(
        bytes32 paranetId,
        string calldata incentivesPoolType,
        address incentivesPoolAddress
    ) external onlyContracts {
        paranets[paranetId].incentivesPools.append(incentivesPoolType, incentivesPoolAddress);
    }

    function updateIncentivesPoolAddress(
        bytes32 paranetId,
        string calldata incentivesPoolType,
        address incentivesPoolAddress
    ) external onlyContracts {
        paranets[paranetId].incentivesPools.update(incentivesPoolType, incentivesPoolAddress);
    }

    function removeIncentivesPool(bytes32 paranetId, string calldata incentivesPoolType) external onlyContracts {
        paranets[paranetId].incentivesPools.remove(incentivesPoolType);
    }

    function removeIncentivesPool(bytes32 paranetId, address incentivesPoolAddress) external onlyContracts {
        paranets[paranetId].incentivesPools.remove(incentivesPoolAddress);
    }

    function getAllIncentivesPools(
        bytes32 paranetId
    ) external view returns (UnorderedNamedContractDynamicSet.Contract[] memory) {
        return paranets[paranetId].incentivesPools.getAll();
    }

    function hasIncentivesPoolByType(
        bytes32 paranetId,
        string calldata incentivesPoolType
    ) external view returns (bool) {
        return paranets[paranetId].incentivesPools.exists(incentivesPoolType);
    }

    function hasIncentivesPoolByAddress(bytes32 paranetId, address incentivesPoolAddress) external view returns (bool) {
        return paranets[paranetId].incentivesPools.exists(incentivesPoolAddress);
    }

    function getCumulativeKnowledgeValue(bytes32 paranetId) external view returns (uint96) {
        return paranets[paranetId].cumulativeKnowledgeValue;
    }

    function setCumulativeKnowledgeValue(bytes32 paranetId, uint96 cumulativeKnowledgeValue) external onlyContracts {
        paranets[paranetId].cumulativeKnowledgeValue = cumulativeKnowledgeValue;
    }

    function addCumulativeKnowledgeValue(bytes32 paranetId, uint96 addedKnowledgeValue) external onlyContracts {
        paranets[paranetId].cumulativeKnowledgeValue += addedKnowledgeValue;
    }

    function subCumulativeKnowledgeValue(bytes32 paranetId, uint96 subtractedKnowledgeValue) external onlyContracts {
        paranets[paranetId].cumulativeKnowledgeValue -= subtractedKnowledgeValue;
    }

    function addService(bytes32 paranetId, bytes32 serviceId) external onlyContracts {
        paranets[paranetId].implementedServicesIndexes[serviceId] = paranets[paranetId].services.length;
        paranets[paranetId].services.push(serviceId);
    }

    function removeService(bytes32 paranetId, bytes32 serviceId) external onlyContracts {
        paranets[paranetId].services[paranets[paranetId].implementedServicesIndexes[serviceId]] = paranets[paranetId]
            .services[paranets[paranetId].services.length - 1];
        paranets[paranetId].implementedServicesIndexes[
            paranets[paranetId].services[paranets[paranetId].services.length - 1]
        ] = paranets[paranetId].implementedServicesIndexes[serviceId];

        delete paranets[paranetId].implementedServicesIndexes[serviceId];
        paranets[paranetId].services.pop();
    }

    function getServices(bytes32 paranetId) external view returns (bytes32[] memory) {
        return paranets[paranetId].services;
    }

    function getServicesCount(bytes32 paranetId) external view returns (uint256) {
        return paranets[paranetId].services.length;
    }

    function isServiceImplemented(bytes32 paranetId, bytes32 serviceId) external view returns (bool) {
        return (paranets[paranetId].services.length != 0 &&
            paranets[paranetId].services[paranets[paranetId].implementedServicesIndexes[serviceId]] == serviceId);
    }

    function addKnowledgeMiner(bytes32 paranetId, address knowledgeMinerAddress) external onlyContracts {
        paranets[paranetId].registeredKnowledgeMinersIndexes[knowledgeMinerAddress] = paranets[paranetId]
            .knowledgeMiners
            .length;
        paranets[paranetId].knowledgeMiners.push(knowledgeMinerAddress);
    }

    function removeKnowledgeMiner(bytes32 paranetId, address knowledgeMinerAddress) external onlyContracts {
        paranets[paranetId].knowledgeMiners[
            paranets[paranetId].registeredKnowledgeMinersIndexes[knowledgeMinerAddress]
        ] = paranets[paranetId].knowledgeMiners[paranets[paranetId].knowledgeMiners.length - 1];
        paranets[paranetId].registeredKnowledgeMinersIndexes[
            paranets[paranetId].knowledgeMiners[paranets[paranetId].knowledgeMiners.length - 1]
        ] = paranets[paranetId].registeredKnowledgeMinersIndexes[knowledgeMinerAddress];

        delete paranets[paranetId].registeredKnowledgeMinersIndexes[knowledgeMinerAddress];
        paranets[paranetId].knowledgeMiners.pop();
    }

    function getKnowledgeMiners(bytes32 paranetId) external view returns (address[] memory) {
        return paranets[paranetId].knowledgeMiners;
    }

    function getKnowledgeMinersCount(bytes32 paranetId) external view returns (uint256) {
        return paranets[paranetId].knowledgeMiners.length;
    }

    function isKnowledgeMinerRegistered(bytes32 paranetId, address knowledgeMinerAddress) external view returns (bool) {
        return (paranets[paranetId].knowledgeMiners.length != 0 &&
            paranets[paranetId].knowledgeMiners[
                paranets[paranetId].registeredKnowledgeMinersIndexes[knowledgeMinerAddress]
            ] ==
            knowledgeMinerAddress);
    }

    function addKnowledgeMinerAccessRequest(
        bytes32 paranetId,
        address miner,
        ParanetLib.RequestStatus status
    ) external onlyContracts {
        paranets[paranetId].paranetKnowledgeMinerAccessRequests[miner].push(
            ParanetLib.ParanetKnowledgeMinerAccessRequest({
                createdAt: block.timestamp,
                updatedAt: block.timestamp,
                miner: miner,
                status: status
            })
        );
    }

    function updateKnowledgeMinerAccessRequestStatus(
        bytes32 paranetId,
        address miner,
        uint256 index,
        ParanetLib.RequestStatus status
    ) external onlyContracts {
        paranets[paranetId].paranetKnowledgeMinerAccessRequests[miner][index].status = status;
        paranets[paranetId].paranetKnowledgeMinerAccessRequests[miner][index].updatedAt = block.timestamp;
    }

    function removeKnowledgeMinerAccessRequest(bytes32 paranetId, address miner, uint256 index) external onlyContracts {
        delete paranets[paranetId].paranetKnowledgeMinerAccessRequests[miner][index];
    }

    function getKnowledgeMinerAccessRequest(
        bytes32 paranetId,
        address miner,
        uint256 index
    ) external view returns (ParanetLib.ParanetKnowledgeMinerAccessRequest memory) {
        return paranets[paranetId].paranetKnowledgeMinerAccessRequests[miner][index];
    }

    function getLatestKnowledgeMinerAccessRequest(
        bytes32 paranetId,
        address miner
    ) external view returns (ParanetLib.ParanetKnowledgeMinerAccessRequest memory) {
        return
            paranets[paranetId].paranetKnowledgeMinerAccessRequests[miner][
                paranets[paranetId].paranetKnowledgeMinerAccessRequests[miner].length - 1
            ];
    }

    function getKnowledgeMinerAccessRequests(
        bytes32 paranetId,
        address miner
    ) external view returns (ParanetLib.ParanetKnowledgeMinerAccessRequest[] memory) {
        return paranets[paranetId].paranetKnowledgeMinerAccessRequests[miner];
    }

    function getKnowledgeMinerAccessRequestsCount(bytes32 paranetId, address miner) external view returns (uint256) {
        return paranets[paranetId].paranetKnowledgeMinerAccessRequests[miner].length;
    }

    function addKnowledgeAsset(bytes32 paranetId, bytes32 knowledgeAssetId) external onlyContracts {
        paranets[paranetId].registeredKnowledgeAssetsIndexes[knowledgeAssetId] = paranets[paranetId]
            .knowledgeAssets
            .length;
        paranets[paranetId].knowledgeAssets.push(knowledgeAssetId);
    }

    function removeKnowledgeAsset(bytes32 paranetId, bytes32 knowledgeAssetId) external onlyContracts {
        paranets[paranetId].knowledgeAssets[
            paranets[paranetId].registeredKnowledgeAssetsIndexes[knowledgeAssetId]
        ] = paranets[paranetId].knowledgeAssets[paranets[paranetId].knowledgeAssets.length - 1];
        paranets[paranetId].registeredKnowledgeAssetsIndexes[
            paranets[paranetId].knowledgeAssets[paranets[paranetId].knowledgeAssets.length - 1]
        ] = paranets[paranetId].registeredKnowledgeAssetsIndexes[knowledgeAssetId];

        delete paranets[paranetId].registeredKnowledgeAssetsIndexes[knowledgeAssetId];
        paranets[paranetId].knowledgeAssets.pop();
    }

    function getKnowledgeAssets(bytes32 paranetId) external view returns (bytes32[] memory) {
        return paranets[paranetId].knowledgeAssets;
    }

    function getKnowledgeAssetsWithPagination(
        bytes32 paranetId,
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory) {
        if (offset >= paranets[paranetId].knowledgeAssets.length) {
            return new bytes32[](0);
        }

        uint256 fetchCount = (offset + limit > paranets[paranetId].knowledgeAssets.length)
            ? paranets[paranetId].knowledgeAssets.length - offset
            : limit;
        bytes32[] memory knowledgeAssets = new bytes32[](fetchCount);

        for (uint256 i = 0; i < fetchCount; i++) {
            knowledgeAssets[i] = paranets[paranetId].knowledgeAssets[offset + i];
        }

        return knowledgeAssets;
    }

    function getKnowledgeAssetsStartingFromKnowledgeAssetId(
        bytes32 paranetId,
        bytes32 knowledgeAssetId,
        uint256 limit
    ) external view returns (bytes32[] memory) {
        if (
            paranets[paranetId].knowledgeAssets[
                paranets[paranetId].registeredKnowledgeAssetsIndexes[knowledgeAssetId]
            ] != knowledgeAssetId
        ) {
            revert("Invalid starting KA");
        }

        if (
            paranets[paranetId].registeredKnowledgeAssetsIndexes[knowledgeAssetId] >=
            paranets[paranetId].knowledgeAssets.length
        ) {
            return new bytes32[](0);
        }

        uint256 fetchCount = (paranets[paranetId].registeredKnowledgeAssetsIndexes[knowledgeAssetId] + limit >
            paranets[paranetId].knowledgeAssets.length)
            ? paranets[paranetId].knowledgeAssets.length -
                paranets[paranetId].registeredKnowledgeAssetsIndexes[knowledgeAssetId]
            : limit;
        bytes32[] memory knowledgeAssets = new bytes32[](fetchCount);

        for (uint256 i = 0; i < fetchCount; i++) {
            knowledgeAssets[i] = paranets[paranetId].knowledgeAssets[
                paranets[paranetId].registeredKnowledgeAssetsIndexes[knowledgeAssetId] + i
            ];
        }

        return knowledgeAssets;
    }

    function getKnowledgeAssetsCount(bytes32 paranetId) external view returns (uint256) {
        return paranets[paranetId].knowledgeAssets.length;
    }

    function isKnowledgeAssetRegistered(bytes32 paranetId, bytes32 knowledgeAssetId) external view returns (bool) {
        return (paranets[paranetId].knowledgeAssets.length != 0 &&
            paranets[paranetId].knowledgeAssets[
                paranets[paranetId].registeredKnowledgeAssetsIndexes[knowledgeAssetId]
            ] ==
            knowledgeAssetId);
    }
}
