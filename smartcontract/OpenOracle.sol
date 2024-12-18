// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OpenOracle is Ownable {
    // using Openzeppelin contracts for SafeMath and Address
    using SafeMath for uint256;
    using Address for address;

    // number of signers
    uint256 public signerLength;

    // addresses of the signers
    address[] public signers;

    // threshold which has to be reached
    uint256 public signerThreshold;

    // struct to keep the values for each individual round
    struct feedRoundStruct {
        uint256 value;
        uint256 timestamp;
    }

    // stores historical values of feeds
    mapping(uint256 => mapping(uint256 => uint256)) private historyFeeds;

    // indicates if sender is a signer
    mapping(address => bool) public isSigner;

    // mapping to store the actual submitted values per FeedId, per round number
    mapping(uint256 => mapping(uint256 => mapping(address => feedRoundStruct))) private feedRoundNumberToStructMapping;

    struct oracleStruct {
        string feedName;
        uint256 feedDecimals;
        uint256 feedTimeslot;
        uint256 latestPrice;
        uint256 latestPriceUpdate;
    }

    oracleStruct[] private feedList;

    event contractSetup(address[] signers, uint256 signerThreshold);
    event feedAdded(string name, string description, uint256 decimal, uint256 timeslot, uint256 feedId);
    event feedSigned(uint256 feedId, uint256 roundId, uint256 value, uint256 timestamp, address signer);
    event newThreshold(uint256 value);
    event newSigner(address signer);
    event signerRemoved(address signer);

    // only Signer modifier
    modifier onlySigner {
        _onlySigner();
        _;
    }

    // only Signer view
    function _onlySigner() private view {
        require(isSigner[msg.sender], "Only a signer can perform this action");
    }

    constructor() Ownable(msg.sender) {}

    function initialize(address[] memory signers_, uint256 signerThreshold_) onlyOwner external {
        require(signerThreshold_ != 0, "Threshold cant be 0");
        require(signerThreshold_ <= signers_.length, "Threshold cant be more then signer count");

        signerThreshold = signerThreshold_;
        signers = signers_;

        for(uint i=0; i< signers.length; i++) {
            require(signers[i] != address(0), "Not zero address");
            isSigner[signers[i]] = true;
        }

        signerLength = signers_.length;

        emit contractSetup(signers_, signerThreshold);
    }

    //---------------------------helper functions---------------------------

    /**
    * @dev implementation of a quicksort algorithm
    *
    * @param arr the array to be sorted
    * @param left the left outer bound element to start the sort
    * @param right the right outer bound element to stop the sort
    */
    function quickSort(uint[] memory arr, int left, int right) private pure {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = arr[uint(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint(i)] < pivot) i++;
            while (pivot < arr[uint(j)]) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }

    /**
    * @dev sort implementation which calls the quickSort function
    *
    * @param data the array to be sorted
    * @return the sorted array
    */
    function sort(uint[] memory data) private pure returns (uint[] memory) {
        quickSort(data, int(0), int(data.length - 1));
        return data;
    }

    //---------------------------view functions ---------------------------

    function getHistoryFeeds(uint256[] memory feedIDs, uint256[] memory timestamps) external view returns (uint256[] memory) {

        uint256 feedLen = feedIDs.length;
        uint256[] memory returnPrices = new uint256[](feedLen);
        require(feedIDs.length == timestamps.length, "Feeds and Timestamps must match");

        for (uint i = 0; i < feedIDs.length; i++) {

            uint256 roundNumber = timestamps[i] / feedList[feedIDs[i]].feedTimeslot;
            returnPrices[i] =  historyFeeds[feedIDs[i]][roundNumber];
        }

        return (returnPrices);
    }

    /**
    * @dev getFeeds function lets anyone call the oracle to receive data
    *
    * @param feedIDs the array of feedIds
    */
    function getFeeds(uint256[] memory feedIDs) external view returns (uint256[] memory, uint256[] memory, uint256[] memory) {

        uint256 feedLen = feedIDs.length;
        uint256[] memory returnPrices = new uint256[](feedLen);
        uint256[] memory returnTimestamps = new uint256[](feedLen);
        uint256[] memory returnDecimals = new uint256[](feedLen);

        for (uint i = 0; i < feedIDs.length; i++) {
            (returnPrices[i] ,returnTimestamps[i], returnDecimals[i]) = getFeed(feedIDs[i]);
        }

        return (returnPrices, returnTimestamps, returnDecimals);
    }

    /**
    * @dev getFeed function lets anyone call the oracle to receive data
    *
    * @param feedID the array of feedId
    */
    function getFeed(uint256 feedID) public view returns (uint256, uint256, uint256) {

        uint256 returnPrice;
        uint256 returnTimestamp;
        uint256 returnDecimals;

        returnPrice = feedList[feedID].latestPrice;
        returnTimestamp = feedList[feedID].latestPriceUpdate;
        returnDecimals = feedList[feedID].feedDecimals;

        return (returnPrice, returnTimestamp, returnDecimals);
    }

    /**
    * @dev getPrice Usecase: function is put the contract to pull dynamic prices.
    *
    * example: v.beta
    * // 1. import
    * interface OpenOracle {
            function getPrice(uint256 feedID) external view returns (uint256);
        }
    *
    * // 2. variable
    *   OpenOracle public openoracle;
    * 
    * // 3. constructor
    *   openoracle = OpenOracle(OO_ADDRESS); // edit: OO_ADDRESS
    *
    * // 4. Use (build in your function (payable))
    *   uint256 price = openoracle.getPrice(FEED_ID); // edit: REQUIRED_FEED_ID
    *   require(msg.value >= price, "Insufficient payment");
    *
    * **Note: This v.beta should not be embedded in a long-term function. 
        + And the function of updating the OO_ADDRESS, FEED_ID should also be added.**
    * 
    * @param feedID the ID of the feed to fetch the value
    * @return the latest price value of the feed
    */
    function getPrice(uint256 feedID) external view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 latestUpdateTime = feedList[feedID].latestPriceUpdate;
        // recheck latestPrice & Node! (No more than 5 minutes)
        require(currentTime - latestUpdateTime <= 300, "Price not available: Feed is outdated & No feed submitted yet");
    
        uint256 returnPrice;
        returnPrice = feedList[feedID].latestPrice;

        return returnPrice;
    }

    function getCheckPrice(uint256 feedID) external view returns (uint256, uint256) {

        uint256 returnPrice;
        uint256 returnTimestamp;

        returnPrice = feedList[feedID].latestPrice;
        returnTimestamp = feedList[feedID].latestPriceUpdate;

        return (returnPrice, returnTimestamp);
    }

    function feedLength() external view returns(uint256) {
        return feedList.length;
    }

    function getFeedList(uint256[] memory feedIDs) external view returns(string[] memory, uint256[] memory, uint256[] memory, uint256[] memory, uint256[] memory) {

        uint256 feedLen = feedIDs.length;
        string[] memory returnNames = new string[](feedLen);
        uint256[] memory returnDecimals = new uint256[](feedLen);
        uint256[] memory returnTimeslot = new uint256[](feedLen);
        uint256[] memory returnRevenueMode = new uint256[](feedLen);
        uint256[] memory returnCost = new uint256[](feedLen);

        for (uint i = 0; i < feedIDs.length; i++) {
            returnNames[i] = feedList[feedIDs[i]].feedName;
            returnDecimals[i] = feedList[feedIDs[i]].feedDecimals;
            returnTimeslot[i] = feedList[feedIDs[i]].feedTimeslot;
        }

        return (returnNames, returnDecimals, returnTimeslot, returnRevenueMode, returnCost);
    }

    //---------------------------oracle management functions ---------------------------

    function createNewFeeds(string[] memory names, string[] memory descriptions, uint256[] memory decimals, uint256[] memory timeslots) onlySigner external {
        require(names.length == descriptions.length, "Length mismatch");
        require(descriptions.length == decimals.length, "Length mismatch");
        require(decimals.length == timeslots.length, "Length mismatch");


        for(uint i = 0; i < names.length; i++) {
            require(decimals[i] <= 18, "Decimal places too high");
            require(timeslots[i] > 0, "Timeslot cannot be 0");


            feedList.push(oracleStruct({
            feedName: names[i],
            feedDecimals: decimals[i],
            feedTimeslot: timeslots[i],
            latestPrice: 0,
            latestPriceUpdate: 0
            }));

            emit feedAdded(names[i], descriptions[i], decimals[i], timeslots[i], feedList.length - 1);
        }
    }

    /**
    * @dev submitFeed function lets a signer submit as many feeds as they want to
    *
    * @param values the array of values
    * @param feedIDs the array of feedIds
    */
    function submitFeed(uint256[] memory feedIDs, uint256[] memory values) onlySigner external {
        require(values.length == feedIDs.length, "Value length and feedID length do not match");

        // process feeds
        for (uint i = 0; i < values.length; i++) {
            // get current round number for feed
            uint256 roundNumber = block.timestamp / feedList[feedIDs[i]].feedTimeslot;

            // check if the signer already pushed an update for the given period
            if (feedRoundNumberToStructMapping[feedIDs[i]][roundNumber][msg.sender].timestamp != 0) {
                delete feedRoundNumberToStructMapping[feedIDs[i]][roundNumber][msg.sender];
            }

            // feed - number and push value
            feedRoundNumberToStructMapping[feedIDs[i]][roundNumber][msg.sender] = feedRoundStruct({
            value: values[i],
            timestamp: block.timestamp
            });

            emit feedSigned(feedIDs[i], roundNumber, values[i], block.timestamp, msg.sender);

            // check if threshold was met
            uint256 signedFeedsLen;
            uint256[] memory prices = new uint256[](signers.length);
            uint256 k;

            for (uint j = 0; j < signers.length; j++) {
                if (feedRoundNumberToStructMapping[feedIDs[i]][roundNumber][signers[j]].timestamp != 0) {
                    signedFeedsLen++;
                    prices[k++] = feedRoundNumberToStructMapping[feedIDs[i]][roundNumber][signers[j]].value;
                }
            }

            // Change the list size of the array in place
            assembly {
                mstore(prices, k)
            }

            // if threshold is met process price
            if (signedFeedsLen >= signerThreshold) {

                uint[] memory sorted = sort(prices);
                uint returnPrice;

                // uneven so we can take the middle
                if (sorted.length % 2 == 1) {
                    uint sizer = (sorted.length + 1) / 2;
                    returnPrice = sorted[sizer-1];
                    // take average of the 2 most inner numbers
                } else {
                    uint size1 = (sorted.length) / 2;
                    returnPrice =  (sorted[size1-1]+sorted[size1])/2;
                }

                // process the struct for storing
                if (block.timestamp / feedList[feedIDs[i]].feedTimeslot > feedList[feedIDs[i]].latestPriceUpdate / feedList[feedIDs[i]].feedTimeslot) {
                    historyFeeds[feedIDs[i]][feedList[feedIDs[i]].latestPriceUpdate / feedList[feedIDs[i]].feedTimeslot] = feedList[feedIDs[i]].latestPrice;
                }
                feedList[feedIDs[i]].latestPriceUpdate = block.timestamp;
                feedList[feedIDs[i]].latestPrice = returnPrice;
            }
        }
    }

    function updateThreshold(uint256 newThresholdValue) onlyOwner external {
        require(newThresholdValue != 0, "Threshold cant be 0");
        require(newThresholdValue <= signerLength, "Threshold cant be bigger then length of signers");

        signerThreshold = newThresholdValue;
        emit newThreshold(newThresholdValue);
    }

    function addSigners(address newSignerValue) onlyOwner external {
        for (uint i=0; i < signers.length; i++) {
            if (signers[i] == newSignerValue) {
                revert("Signer already exists");
            }
        }

        signers.push(newSignerValue);
        signerLength++;
        isSigner[newSignerValue] = true;
        emit newSigner(newSignerValue);
    }

    function removeSigner(address toRemove) onlyOwner external {
        require(isSigner[toRemove], "Address to remove has to be a signer");
        require(signers.length -1 >= signerThreshold, "Less signers than threshold");

        for (uint i = 0; i < signers.length; i++) {
            if (signers[i] == toRemove) {
                delete signers[i];
                signerLength --;
                isSigner[toRemove] = false;
                emit signerRemoved(toRemove);
            }
        }
    }

}