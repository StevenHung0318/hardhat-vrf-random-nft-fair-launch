// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

// error
error RandomNFT__ETH_not_enough();

contract RandomNFT is ERC721Enumerable, Ownable, VRFConsumerBaseV2 {
    using Strings for uint256;

    bool public _isSaleActive = false;
    bool public _revealed = false;

    // Constants
    uint256 public constant MAX_SUPPLY = 5;
    uint256 public mintPrice = 0.001 ether;
    uint256 public maxBalance = 5;
    uint256 public maxMint = 5;

    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // VRF Helpers
    mapping(uint256 => address) public s_requestIdToSender;

    // record minted tokenid
    mapping(uint256 => bool) public isTokenMinted;

    // Events
    event NftRequested(uint256 indexed requestId, address requester);
    event NftMinted(uint256 randomTokenId, address minter);

    string baseURI;
    string public notRevealedUri;

    mapping(uint256 => string) private _tokenURIs;

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint32 callbackGasLimit,
        string memory initBaseURI,
        string memory initNotRevealedUri
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721("RandomNFT", "R-NFT") {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        setBaseURI(initBaseURI);
        setNotRevealedURI(initNotRevealedUri);
    }

    // Users can query all tokenIDs that have not been mint yet
    function getAvailableTokens() public view returns (uint256[] memory) {
        uint256[] memory availableTokens = new uint256[](MAX_SUPPLY);
        uint256 count = 0;

        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            if (!isTokenMinted[i]) {
                availableTokens[count] = i;
                count++;
            }
        }

        // Reduce array size to exclude possible empty portions
        // EX: 1.3.5 has been minted -> availableTokens = [0,2,4,6,7,8,9] -> size = count = 7
        assembly {
            mstore(availableTokens, count)
        }

        return availableTokens;
    }

    //--------------------------------------------------------------------------------------------------//
    //---------------------- Use chainlinkVRF to get random tokenID to mint ----------------------------//
    //--------------------------------------------------------------------------------------------------//

    // 1. get a randomword
    function requestNft() public payable returns (uint256 requestId) {
        if (msg.value < mintPrice) {
            revert RandomNFT__ETH_not_enough();
        }
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        s_requestIdToSender[requestId] = msg.sender; // store the msg.sender, let function fulfillRandomWords can get the address of minter
        emit NftRequested(requestId, msg.sender);
    }

    // 2. get the random tokenid from chainlinkVRF & availableTokens to mint NFT
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        // Ensure randomWords is not empty
        require(randomWords.length > 0, "No random words provided");

        // Get the available tokens
        uint256[] memory availableTokens = getAvailableTokens();

        // Ensure availableTokens is not empty
        require(availableTokens.length > 0, "No available tokens");

        // Use the first random word to determine the index
        uint256 randomIndex = randomWords[0] % availableTokens.length;

        // Choose the tokenID from available tokens
        uint256 randomTokenId = availableTokens[randomIndex];

        // Perform the minting
        address minter = s_requestIdToSender[requestId];
        _safeMint(minter, randomTokenId);
        isTokenMinted[randomTokenId] = true; // Mark the tokenID as minted
        emit NftMinted(randomTokenId, minter);
    }

    //--------------------------------------------------------------------------------------------------//
    //--------------------------------------------- Other ----------------------------------------------//
    //--------------------------------------------------------------------------------------------------//

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (_revealed == false) {
            return notRevealedUri;
        }

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, "/", tokenId.toString()));
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    //only owner
    function flipSaleActive() public onlyOwner {
        _isSaleActive = !_isSaleActive; //change true/false
    }

    function flipReveal() public onlyOwner {
        _revealed = !_revealed; //change true/false
    }

    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setMaxBalance(uint256 _maxBalance) public onlyOwner {
        maxBalance = _maxBalance;
    }

    function setMaxMint(uint256 _maxMint) public onlyOwner {
        maxMint = _maxMint;
    }

    function withdraw(address to) public onlyOwner {
        uint256 balance = address(this).balance;
        payable(to).transfer(balance);
    }
}
