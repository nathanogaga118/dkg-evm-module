// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

library ContentAssetStructs {

    struct AssetInputArgs {
        bytes32 assertionId;
        uint128 size;
        uint32 triplesNumber;
        uint96 chunksNumber;
        uint16 epochsNumber;
        uint96 tokenAmount;
        uint8 scoreFunctionId;
    }

    struct Asset {
        bytes32[] assertionIds;
    }

}