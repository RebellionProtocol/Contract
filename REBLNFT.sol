// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721Tradable.sol";
import "./interfaces/IREBLNFT.sol";

contract REBLNFT is ERC721Tradable, IREBLNFT {

    modifier onlyStaking() {
        require(msg.sender == stakingContractAddress, "Only staking contract can invoke this function");
        _;
    }

    uint256 currentTokenId;

    enum Level {Common, Special, Rare, Epic, Legendary}

    struct LevelInfo {
        Level level;
        uint256 votingPower;
        uint256 usdtValue;
    }

    address public stakingContractAddress;
    LevelInfo[] public levelsInfo;
//         token id => level index
    mapping(uint256 => uint256) public tokenLevels;
    mapping(uint256 => uint256[]) tokenIdsByLevel;
//          address =>   token level => amount of tokens
    mapping(address => mapping (uint256 => uint256)) ownerTokensByLevel;

    uint256 constant USDT_DECIMAL = 10 ** 18;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721Tradable(_name, _symbol, 0xF57B2c51dED3A29e6891aba85459d600256Cf317) {
        //init levels info
        levelsInfo.push(LevelInfo(Level.Common, 3, 100 * USDT_DECIMAL));
        levelsInfo.push(LevelInfo(Level.Special, 15, 1000 * USDT_DECIMAL));
        levelsInfo.push(LevelInfo(Level.Rare, 50, 5000 * USDT_DECIMAL));
        levelsInfo.push(LevelInfo(Level.Epic, 250, 25000 * USDT_DECIMAL));
        levelsInfo.push(LevelInfo(Level.Legendary, 1000, 100000 * USDT_DECIMAL));
    }

    //todo don't forget to change it!
    function baseTokenURI() override public pure returns (string memory) {
        return "https://romanow.xyz/api/stars/tokens/";
    }

    //todo don't forget to change it!
    function contractURI() public pure returns (string memory) {
        return "https://romanow.xyz/api/stars/tokens/";
    }

    function mintToByAmount(address to, uint256 usdtAmount) public override onlyStaking {
        uint256 lowestNftUsdtValue = levelsInfo[0].usdtValue;
        while (usdtAmount >= lowestNftUsdtValue) {
            for (uint256 i = levelsInfo.length; i > 0; i--) {
                if (usdtAmount >= levelsInfo[i - 1].usdtValue) {
                    mintToByLevel(to,i-1);
                    usdtAmount -= levelsInfo[i - 1].usdtValue;
                    break;
                }
            }
        }
    }

    function mintToByOwner(address to, uint256 level) public override onlyOwner {
        mintToByLevel(to, level);
    }

    function mintToByLevel(address to, uint256 levelIndex) internal {
        uint256 newTokenId = currentTokenId++;
        mintTo(to);
        tokenLevels[newTokenId] = levelIndex;
        tokenIdsByLevel[levelIndex].push(newTokenId);
        ownerTokensByLevel[to][levelIndex] += 1;
    }

    function setStakingContractAddress(address _stakingContractAddress) external onlyOwner {
        stakingContractAddress = _stakingContractAddress;
    }

    function getLowestLevelUsdtValue() public view override returns (uint256) {
        return levelsInfo[0].usdtValue;
    }

    function getLevelsUsdtValues() public view override returns (uint256[] memory) {
        uint256[] memory result = new uint256[](levelsInfo.length);
        for (uint256 i = 0; i < levelsInfo.length; i++) {
            result[i] = levelsInfo[i].usdtValue;
        }
        return result;
    }

    function levelInfoByTokenId(uint256 tokenId) public view returns(LevelInfo memory) {
        return levelsInfo[tokenLevels[tokenId]];
    }

    function _transfer(address from, address to, uint256 tokenId) internal override {
        uint256 levelIndex = tokenLevels[tokenId];
        require(ownerTokensByLevel[from][levelIndex] > 0);
        ownerTokensByLevel[from][levelIndex] -= 1;
        ownerTokensByLevel[to][levelIndex] += 1;
        super._transfer(from, to, tokenId);
    }

}
