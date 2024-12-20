// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// 1. Import interface for Oracle
interface OpenOracle {
    function getPrice(uint256 feedID) external view returns (uint256);
}

contract Token_with_OO_Price is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    // 2. Oracle variables
    OpenOracle public openoracle;
    // +
    address public OO_ADDRESS;
    uint256 public FEED_ID;

    uint256 public constant MAX_SUPPLY = 1_000_000 * 10 ** 18;

    constructor(address _ooAddress, uint256 _feedId)
        Ownable(msg.sender)
        ERC20("MyToken", "MTK")
        ERC20Permit("MyToken")
    {
        // 3. constructor
        openoracle = OpenOracle(OO_ADDRESS); // edit: address
        // +
        OO_ADDRESS = _ooAddress;
        FEED_ID = _feedId;
    }

    function mint(uint256 amount) public payable {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");

        // 4. Get the price of 1 token from the oracle
        uint256 price = openoracle.getPrice(FEED_ID); // edit: number
        require(price > 0, "Invalid price from Oracle");
        // Calculate required ETH for minting `amount` tokens
        uint256 requiredPayment = price * amount;
        require(msg.value >= requiredPayment, "Insufficient funds");

        _mint(msg.sender, amount);
    }

    // + Update Oracle address
    function updateOracleAddress(address _ooAddress) public onlyOwner {
        OO_ADDRESS = _ooAddress;
        openoracle = OpenOracle(OO_ADDRESS);
    }

    // + Update Oracle Feed ID
    function updateOracleFeedId(uint256 _feedId) public onlyOwner {
        FEED_ID = _feedId;
    }

    function safeMint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(to, amount);
    }
}