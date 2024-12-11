// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.20;

import {ShardingTable} from "./ShardingTable.sol";
import {Shares} from "./Shares.sol";
import {IdentityStorage} from "./storage/IdentityStorage.sol";
import {ParametersStorage} from "./storage/ParametersStorage.sol";
import {ProfileStorage} from "./storage/ProfileStorage.sol";
import {ShardingTableStorage} from "./storage/ShardingTableStorage.sol";
import {StakingStorage} from "./storage/StakingStorage.sol";
import {ContractStatus} from "./abstract/ContractStatus.sol";
import {IInitializable} from "./interfaces/IInitializable.sol";
import {INamed} from "./interfaces/INamed.sol";
import {IVersioned} from "./interfaces/IVersioned.sol";
import {ProfileLib} from "./libraries/ProfileLib.sol";
import {ShardingTableLib} from "./libraries/ShardingTableLib.sol";
import {StakingLib} from "./libraries/StakingLib.sol";
import {TokenLib} from "./libraries/TokenLib.sol";
import {IdentityLib} from "./libraries/IdentityLib.sol";
import {Permissions} from "./libraries/Permissions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking is INamed, IVersioned, ContractStatus, IInitializable {
    string private constant _NAME = "Staking";
    string private constant _VERSION = "1.0.0";

    ShardingTableStorage public shardingTableStorage;
    ShardingTable public shardingTableContract;
    IdentityStorage public identityStorage;
    ParametersStorage public parametersStorage;
    ProfileStorage public profileStorage;
    StakingStorage public stakingStorage;
    IERC20 public tokenContract;

    // solhint-disable-next-line no-empty-blocks
    constructor(address hubAddress) ContractStatus(hubAddress) {}

    modifier onlyAdmin(uint72 identityId) {
        _checkAdmin(identityId);
        _;
    }

    modifier profileExists(uint72 identityId) {
        _checkProfileExists(identityId);
        _;
    }

    function initialize() public onlyHub {
        shardingTableStorage = ShardingTableStorage(hub.getContractAddress("ShardingTableStorage"));
        shardingTableContract = ShardingTable(hub.getContractAddress("ShardingTable"));
        identityStorage = IdentityStorage(hub.getContractAddress("IdentityStorage"));
        parametersStorage = ParametersStorage(hub.getContractAddress("ParametersStorage"));
        profileStorage = ProfileStorage(hub.getContractAddress("ProfileStorage"));
        stakingStorage = StakingStorage(hub.getContractAddress("StakingStorage"));
        tokenContract = IERC20(hub.getContractAddress("Token"));
    }

    function name() external pure virtual override returns (string memory) {
        return _NAME;
    }

    function version() external pure virtual override returns (string memory) {
        return _VERSION;
    }

    function stake(uint72 identityId, uint96 addedStake) external profileExists(identityId) {
        IERC20 token = tokenContract;
        StakingStorage ss = stakingStorage;

        if (addedStake == 0) {
            revert TokenLib.ZeroTokenAmount();
        }
        if (token.allowance(msg.sender, address(this)) < addedStake) {
            revert TokenLib.TooLowAllowance(address(token), token.allowance(msg.sender, address(this)), addedStake);
        }

        bytes32 delegatorKey = keccak256(abi.encodePacked(msg.sender));
        _updateStakeInfo(identityId, delegatorKey);

        (uint96 delegatorStakeBase, uint96 delegatorStakeIndexed, ) = ss.getDelegatorStakeInfo(
            identityId,
            delegatorKey
        );
        uint96 totalNodeStakeBefore = ss.getNodeStake(identityId);
        uint96 totalNodeStakeAfter = totalNodeStakeBefore + addedStake;
        if (totalNodeStakeAfter > parametersStorage.maximumStake()) {
            revert IdentityLib.MaximumStakeExceeded(parametersStorage.maximumStake());
        }

        ss.setDelegatorStakeInfo(identityId, delegatorKey, delegatorStakeBase + addedStake, delegatorStakeIndexed);
        ss.setNodeStake(identityId, totalNodeStakeAfter);
        ss.increaseTotalStake(addedStake);

        _addNodeToShardingTable(identityId, totalNodeStakeAfter);

        token.transferFrom(msg.sender, address(ss), addedStake);
    }

    function requestWithdrawal(uint72 identityId, uint96 removedStake) external profileExists(identityId) {
        StakingStorage ss = stakingStorage;

        if (removedStake == 0) {
            revert TokenLib.ZeroTokenAmount();
        }

        bytes32 delegatorKey = keccak256(abi.encodePacked(msg.sender));
        _updateStakeInfo(identityId, delegatorKey);

        (uint96 delegatorStakeBase, uint96 delegatorStakeIndexed, ) = ss.getDelegatorStakeInfo(
            identityId,
            delegatorKey
        );
        uint96 currentDelegatorStake = delegatorStakeBase + delegatorStakeIndexed;
        if (removedStake > currentDelegatorStake) {
            revert StakingLib.WithdrawalExceedsStake(currentDelegatorStake, removedStake);
        }

        uint96 newDelegatorStakeBase = delegatorStakeBase;
        uint96 newDelegatorStakeIndexed = delegatorStakeIndexed;

        if (removedStake > delegatorStakeIndexed) {
            newDelegatorStakeBase = delegatorStakeBase - (removedStake - delegatorStakeIndexed);
            newDelegatorStakeIndexed = 0;
        } else {
            newDelegatorStakeIndexed = delegatorStakeIndexed - removedStake;
        }

        uint96 totalNodeStakeBefore = ss.getNodeStake(identityId);
        uint96 totalNodeStakeAfter = totalNodeStakeBefore - removedStake;

        ss.setDelegatorStakeInfo(identityId, delegatorKey, newDelegatorStakeBase, newDelegatorStakeIndexed);
        ss.setNodeStake(identityId, totalNodeStakeAfter);
        ss.decreaseTotalStake(removedStake);

        _removeNodeFromShardingTable(identityId, totalNodeStakeAfter);

        if (totalNodeStakeAfter >= parametersStorage.maximumStake()) {
            ss.transferStake(msg.sender, removedStake);
        } else {
            ss.createDelegatorWithdrawalRequest(
                identityId,
                delegatorKey,
                removedStake,
                delegatorStakeIndexed - newDelegatorStakeIndexed,
                block.timestamp + parametersStorage.stakeWithdrawalDelay()
            );
        }
    }

    function finalizeWithdrawal(uint72 identityId) external profileExists(identityId) {
        StakingStorage ss = stakingStorage;

        bytes32 delegatorKey = keccak256(abi.encodePacked(msg.sender));
        (uint96 delegatorWithdrawalAmount, uint96 delegatorIndexedOutRewardAmount, uint256 timestamp) = ss
            .getDelegatorWithdrawalRequest(identityId, delegatorKey);

        if (delegatorWithdrawalAmount == 0) {
            revert IdentityLib.WithdrawalWasntInitiated();
        }
        if (block.timestamp < timestamp) {
            revert IdentityLib.WithdrawalPeriodPending(block.timestamp, timestamp);
        }

        ss.deleteDelegatorWithdrawalRequest(identityId, delegatorKey);
        ss.addDelegatorCumulativePaidOutRewards(identityId, delegatorKey, delegatorIndexedOutRewardAmount);
        ss.transferStake(msg.sender, delegatorWithdrawalAmount);
    }

    function cancelWithdrawal(uint72 identityId) external profileExists(identityId) {
        StakingStorage ss = stakingStorage;

        bytes32 delegatorKey = keccak256(abi.encodePacked(msg.sender));
        uint96 delegatorWithdrawalAmount = ss.getDelegatorWithdrawalRequestAmount(identityId, delegatorKey);
        if (delegatorWithdrawalAmount == 0) {
            revert IdentityLib.WithdrawalWasntInitiated();
        }

        _updateStakeInfo(identityId, delegatorKey);
        (uint96 delegatorStakeBase, uint96 delegatorStakeIndexed, ) = ss.getDelegatorStakeInfo(
            identityId,
            delegatorKey
        );

        uint96 totalNodeStakeBefore = ss.getNodeStake(identityId);
        uint96 totalNodeStakeAfter = totalNodeStakeBefore + delegatorWithdrawalAmount;

        ss.deleteDelegatorWithdrawalRequest(identityId, delegatorKey);
        ss.setDelegatorStakeInfo(
            identityId,
            delegatorKey,
            delegatorStakeBase + delegatorWithdrawalAmount,
            delegatorStakeIndexed
        );
        ss.setNodeStake(identityId, totalNodeStakeAfter);
        ss.increaseTotalStake(delegatorWithdrawalAmount);

        _addNodeToShardingTable(identityId, totalNodeStakeAfter);
    }

    function distributeRewards(
        uint72 identityId,
        uint96 rewardAmount
    ) external onlyContracts profileExists(identityId) {
        StakingStorage ss = stakingStorage;

        if (rewardAmount == 0) {
            revert TokenLib.ZeroTokenAmount();
        }

        ProfileLib.OperatorFee memory operatorFee = profileStorage.getActiveOperatorFee(identityId);

        uint96 delegatorsReward = rewardAmount;
        if (operatorFee.feePercentage != 0) {
            uint96 operatorFeeAmount = uint96((uint256(rewardAmount) * operatorFee.feePercentage) / 100);
            delegatorsReward -= operatorFeeAmount;

            ss.increaseOperatorFeeBalance(identityId, operatorFeeAmount);
            ss.addOperatorFeeCumulativeEarnedRewards(identityId, operatorFeeAmount);
        }

        if (delegatorsReward == 0) {
            return;
        }

        uint96 totalNodeStakeBefore = ss.getNodeStake(identityId);
        uint96 totalNodeStakeAfter = totalNodeStakeBefore + delegatorsReward;

        uint256 nodeRewardIndex = ss.getNodeRewardIndex(identityId);
        uint256 nodeRewardIndexIncrement = (uint256(delegatorsReward) * 1e18) / totalNodeStakeBefore;

        ss.setNodeRewardIndex(identityId, nodeRewardIndex + nodeRewardIndexIncrement);
        ss.setNodeStake(identityId, totalNodeStakeAfter);
        ss.increaseTotalStake(delegatorsReward);

        _addNodeToShardingTable(identityId, totalNodeStakeAfter);
    }

    function restakeOperatorFee(uint72 identityId, uint96 addedStake) external onlyAdmin(identityId) {
        StakingStorage ss = stakingStorage;

        if (addedStake == 0) {
            revert TokenLib.ZeroTokenAmount();
        }

        uint96 oldOperatorFeeBalance = ss.getOperatorFeeBalance(identityId);
        if (addedStake > oldOperatorFeeBalance) {
            revert StakingLib.AmountExceedsOperatorFeeBalance(oldOperatorFeeBalance, addedStake);
        }

        uint96 newOperatorFeeBalance = oldOperatorFeeBalance - addedStake;
        ss.setOperatorFeeBalance(identityId, newOperatorFeeBalance);

        bytes32 operatorKey = keccak256(abi.encodePacked(msg.sender));
        _updateStakeInfo(identityId, operatorKey);

        (uint96 delegatorStakeBase, uint96 delegatorStakeIndexed, ) = ss.getDelegatorStakeInfo(identityId, operatorKey);
        uint96 totalNodeStakeBefore = ss.getNodeStake(identityId);
        uint96 totalNodeStakeAfter = totalNodeStakeBefore + addedStake;

        if (totalNodeStakeAfter > parametersStorage.maximumStake()) {
            revert IdentityLib.MaximumStakeExceeded(parametersStorage.maximumStake());
        }

        ss.setDelegatorStakeInfo(identityId, operatorKey, delegatorStakeBase + addedStake, delegatorStakeIndexed);
        ss.setNodeStake(identityId, totalNodeStakeAfter);
        ss.addOperatorFeeCumulativePaidOutRewards(identityId, addedStake);
        ss.increaseTotalStake(addedStake);

        _addNodeToShardingTable(identityId, totalNodeStakeAfter);
    }

    function requestOperatorFeeWithdrawal(uint72 identityId, uint96 withdrawalAmount) external onlyAdmin(identityId) {
        StakingStorage ss = stakingStorage;

        if (withdrawalAmount == 0) {
            revert TokenLib.ZeroTokenAmount();
        }

        uint96 oldOperatorFeeBalance = ss.getOperatorFeeBalance(identityId);
        if (withdrawalAmount > oldOperatorFeeBalance) {
            revert StakingLib.AmountExceedsOperatorFeeBalance(oldOperatorFeeBalance, withdrawalAmount);
        }

        uint256 releaseTime = block.timestamp + parametersStorage.stakeWithdrawalDelay();

        ss.setOperatorFeeBalance(identityId, oldOperatorFeeBalance - withdrawalAmount);
        ss.createOperatorFeeWithdrawalRequest(identityId, withdrawalAmount, releaseTime);
    }

    function finalizeOperatorFeeWithdrawal(uint72 identityId) external onlyAdmin(identityId) {
        StakingStorage ss = stakingStorage;

        (uint96 operatorFeeWithdrawalAmount, uint256 timestamp) = ss.getOperatorFeeWithdrawalRequest(identityId);
        if (operatorFeeWithdrawalAmount == 0) {
            revert IdentityLib.WithdrawalWasntInitiated();
        }
        if (block.timestamp < timestamp) {
            revert IdentityLib.WithdrawalPeriodPending(block.timestamp, timestamp);
        }

        ss.deleteOperatorFeeWithdrawalRequest(identityId);
        ss.addOperatorFeeCumulativePaidOutRewards(identityId, operatorFeeWithdrawalAmount);
        ss.transferStake(msg.sender, operatorFeeWithdrawalAmount);
    }

    function simulateStakeInfoUpdate(
        uint72 identityId,
        bytes32 delegatorKey
    ) public view returns (uint96, uint96, uint96) {
        uint256 nodeRewardIndex = stakingStorage.getNodeRewardIndex(identityId);

        (uint96 delegatorStakeBase, uint96 delegatorStakeIndexed, uint256 delegatorLastRewardIndex) = stakingStorage
            .getDelegatorStakeInfo(identityId, delegatorKey);

        if (nodeRewardIndex <= delegatorLastRewardIndex) {
            return (delegatorStakeBase, delegatorStakeIndexed, 0);
        }

        uint256 diff = nodeRewardIndex - delegatorLastRewardIndex;
        uint256 currentStake = uint256(delegatorStakeBase) + uint256(delegatorStakeIndexed);
        uint96 additionalReward = uint96((currentStake * diff) / 1e18);

        return (delegatorStakeBase, delegatorStakeIndexed + additionalReward, additionalReward);
    }

    function getOperatorStats(uint72 identityId) external view returns (uint96, uint96, uint96) {
        StakingStorage ss = stakingStorage;

        bytes32[] memory adminKeys = identityStorage.getKeysByPurpose(identityId, IdentityLib.ADMIN_KEY);

        uint96 totalSimBase;
        uint96 totalSimIndexed;
        uint96 totalUnrealized;
        uint96 totalEarned;
        uint96 totalPaidOut;
        for (uint256 i; i < adminKeys.length; i++) {
            (uint96 simBase, uint96 simIndexed, uint96 unrealized) = simulateStakeInfoUpdate(identityId, adminKeys[i]);

            (uint96 operatorEarned, uint96 operatorPaidOut) = ss.getDelegatorRewardsInfo(identityId, adminKeys[i]);

            totalSimBase += simBase;
            totalSimIndexed += simIndexed;
            totalUnrealized += unrealized;
            totalEarned += operatorEarned;
            totalPaidOut += operatorPaidOut;
        }

        return (totalSimBase + totalSimIndexed, totalEarned - totalPaidOut, totalUnrealized);
    }

    function getOperatorFeeStats(uint72 identityId) external view returns (uint96, uint96, uint96) {
        return stakingStorage.getNodeOperatorFeesInfo(identityId);
    }

    function getDelegatorStats(uint72 identityId, address delegator) external view returns (uint96, uint96, uint96) {
        bytes32 delegatorKey = keccak256(abi.encodePacked(delegator));
        (uint96 simBase, uint96 simIndexed, uint96 unrealized) = simulateStakeInfoUpdate(identityId, delegatorKey);

        (uint96 delegatorEarned, uint96 delegatorPaidOut) = stakingStorage.getDelegatorRewardsInfo(
            identityId,
            delegatorKey
        );

        return (simBase + simIndexed, delegatorEarned - delegatorPaidOut, unrealized);
    }

    function _updateStakeInfo(uint72 identityId, bytes32 delegatorKey) internal {
        StakingStorage ss = stakingStorage;

        (uint96 delegatorStakeBase, uint96 delegatorStakeIndexed, uint256 delegatorLastRewardIndex) = ss
            .getDelegatorStakeInfo(identityId, delegatorKey);
        uint256 nodeRewardIndex = ss.getNodeRewardIndex(identityId);

        if (nodeRewardIndex > delegatorLastRewardIndex) {
            uint256 diff = nodeRewardIndex - delegatorLastRewardIndex;
            uint256 currentStake = uint256(delegatorStakeBase) + uint256(delegatorStakeIndexed);
            uint96 additional = uint96((currentStake * diff) / 1e18);
            delegatorStakeIndexed += additional;
            ss.setDelegatorStakeInfo(identityId, delegatorKey, delegatorStakeBase, delegatorStakeIndexed);
            ss.addDelegatorCumulativeEarnedRewards(identityId, delegatorKey, additional);
        }
    }

    function _addNodeToShardingTable(uint72 identityId, uint96 newStake) internal {
        ShardingTableStorage sts = shardingTableStorage;
        ParametersStorage params = parametersStorage;

        if (!sts.nodeExists(identityId) && newStake >= params.minimumStake()) {
            if (sts.nodesCount() >= params.shardingTableSizeLimit()) {
                revert ShardingTableLib.ShardingTableIsFull();
            }
            shardingTableContract.insertNode(identityId);
        }
    }

    function _removeNodeFromShardingTable(uint72 identityId, uint96 newStake) internal {
        if (shardingTableStorage.nodeExists(identityId) && newStake < parametersStorage.minimumStake()) {
            shardingTableContract.removeNode(identityId);
        }
    }

    function _checkAdmin(uint72 identityId) internal view virtual {
        if (
            !identityStorage.keyHasPurpose(identityId, keccak256(abi.encodePacked(msg.sender)), IdentityLib.ADMIN_KEY)
        ) {
            revert Permissions.OnlyProfileAdminFunction(msg.sender);
        }
    }

    function _checkProfileExists(uint72 identityId) internal view virtual {
        if (!profileStorage.profileExists(identityId)) {
            revert ProfileLib.ProfileDoesntExist(identityId);
        }
    }
}
