// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@pythnetwork/pyth-sdk-solidity/AbstractPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@pythnetwork/pyth-sdk-solidity/PythErrors.sol";

contract MockPyth is AbstractPyth {
    mapping(bytes32 => PythStructs.PriceFeed) priceFeeds;

    uint256 singleUpdateFeeInWei;
    uint256 validTimePeriod;

    constructor(uint256 _validTimePeriod, uint256 _singleUpdateFeeInWei) {
        singleUpdateFeeInWei = _singleUpdateFeeInWei;
        validTimePeriod = _validTimePeriod;
    }

    function queryPriceFeed(bytes32 id) public view override returns (PythStructs.PriceFeed memory priceFeed) {
        if (priceFeeds[id].id == 0) revert PythErrors.PriceFeedNotFound();
        return priceFeeds[id];
    }

    function priceFeedExists(bytes32 id) public view override returns (bool) {
        return (priceFeeds[id].id != 0);
    }

    function getValidTimePeriod() public view override returns (uint256) {
        return validTimePeriod;
    }

    // Takes an array of encoded price feeds and stores them.
    // You can create this data either by calling createPriceFeedUpdateData or
    // by using web3.js or ethers abi utilities.
    // @note: The updateData expected here is different from the one used in the main contract.
    // In particular, the expected format is:
    // [
    //     abi.encode(
    //         PythStructs.PriceFeed(
    //             bytes32 id,
    //             PythStructs.Price price,
    //             PythStructs.Price emaPrice
    //         ),
    //         uint64 prevPublishTime
    //     )
    // ]
    function updatePriceFeeds(bytes[] calldata updateData) public payable override {
        uint256 requiredFee = getUpdateFee(updateData);
        if (msg.value < requiredFee) revert PythErrors.InsufficientFee();

        for (uint256 i = 0; i < updateData.length; i++) {
            PythStructs.PriceFeed memory priceFeed = abi.decode(updateData[i], (PythStructs.PriceFeed));

            uint256 lastPublishTime = priceFeeds[priceFeed.id].price.publishTime;

            if (lastPublishTime < priceFeed.price.publishTime) {
                // Price information is more recent than the existing price information.
                priceFeeds[priceFeed.id] = priceFeed;
                emit PriceFeedUpdate(
                    priceFeed.id, uint64(priceFeed.price.publishTime), priceFeed.price.price, priceFeed.price.conf
                );
            }
        }
    }

    function getUpdateFee(bytes[] calldata updateData) public view override returns (uint256 feeAmount) {
        return singleUpdateFeeInWei * updateData.length;
    }

    function parsePriceFeedUpdatesInternal(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime,
        bool unique
    ) internal returns (PythStructs.PriceFeed[] memory feeds) {
        uint256 requiredFee = getUpdateFee(updateData);
        if (msg.value < requiredFee) revert PythErrors.InsufficientFee();

        feeds = new PythStructs.PriceFeed[](priceIds.length);

        for (uint256 i = 0; i < priceIds.length; i++) {
            for (uint256 j = 0; j < updateData.length; j++) {
                uint64 prevPublishTime;
                (feeds[i], prevPublishTime) = abi.decode(updateData[j], (PythStructs.PriceFeed, uint64));

                uint256 publishTime = feeds[i].price.publishTime;
                if (priceFeeds[feeds[i].id].price.publishTime < publishTime) {
                    priceFeeds[feeds[i].id] = feeds[i];
                    emit PriceFeedUpdate(feeds[i].id, uint64(publishTime), feeds[i].price.price, feeds[i].price.conf);
                }

                if (feeds[i].id == priceIds[i]) {
                    if (
                        minPublishTime <= publishTime && publishTime <= maxPublishTime
                            && (!unique || prevPublishTime < minPublishTime)
                    ) {
                        break;
                    } else {
                        feeds[i].id = 0;
                    }
                }
            }

            if (feeds[i].id != priceIds[i]) {
                revert PythErrors.PriceFeedNotFoundWithinRange();
            }
        }
    }

    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable override returns (PythStructs.PriceFeed[] memory feeds) {
        return parsePriceFeedUpdatesInternal(updateData, priceIds, minPublishTime, maxPublishTime, false);
    }

    function parsePriceFeedUpdatesUnique(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable override returns (PythStructs.PriceFeed[] memory feeds) {
        return parsePriceFeedUpdatesInternal(updateData, priceIds, minPublishTime, maxPublishTime, true);
    }

    function createPriceFeedUpdateData(
        bytes32 id,
        int64 price,
        uint64 conf,
        int32 expo,
        int64 emaPrice,
        uint64 emaConf,
        uint64 publishTime,
        uint64 prevPublishTime
    ) public pure returns (bytes memory priceFeedData) {
        PythStructs.PriceFeed memory priceFeed;

        priceFeed.id = id;

        priceFeed.price.price = price;
        priceFeed.price.conf = conf;
        priceFeed.price.expo = expo;
        priceFeed.price.publishTime = publishTime;

        priceFeed.emaPrice.price = emaPrice;
        priceFeed.emaPrice.conf = emaConf;
        priceFeed.emaPrice.expo = expo;
        priceFeed.emaPrice.publishTime = publishTime;

        priceFeedData = abi.encode(priceFeed, prevPublishTime);
    }
}
