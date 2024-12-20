// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// 1. import
interface OpenOracle {
    function getPrice(uint256 feedID) external view returns (uint256);
}

contract NFT_with_OO_Price is ERC721, ERC721URIStorage, Ownable {

    // 2. variable
    OpenOracle public openoracle;
    // +
    address public OO_ADDRESS;
    uint256 public FEED_ID;

    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdCounter;
    uint256 MAX_SUPPLY = 10000;

    constructor(address _ooAddress, uint256 _feedId) Ownable(msg.sender) ERC721("MyToken", "MTK") {
        // 3. constructor
        openoracle = OpenOracle(OO_ADDRESS); // edit: address
        // +
        OO_ADDRESS = _ooAddress;
        FEED_ID = _feedId;
    }

    function mint() public payable {
        uint256 tokenId = _tokenIdCounter.current();
        require(tokenId < MAX_SUPPLY, "Sorry, all NFTs have been minted!");

        // 4. Use (build in your function (payable))
        uint256 price = openoracle.getPrice(FEED_ID); // edit: number
        require(msg.value >= price, "Insufficient funds");

        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }

    // + updateOracleAddress
    function updateOracleAddress(address _ooAddress) public onlyOwner {
        OO_ADDRESS = _ooAddress;
        openoracle = OpenOracle(OO_ADDRESS);
    }

    // + updateOracleFeedId
    function updateOracleFeedId(uint256 _feedId) public onlyOwner {
        FEED_ID = _feedId;
    }

    function safeMint(address to, uint256 tokenId, string memory uri)
        public
        onlyOwner
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://your-ipfs-metadata/";
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}