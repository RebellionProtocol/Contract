//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IREBLNFT.sol";
import "./libs/IterableMapping.sol";

interface IPancakeSwap {
    function WETH() external pure returns (address);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IPancakePair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IREBLStaking {
    struct UserStakingInfo {
        uint256 rewardUnblockTimestamp;
        uint256 usdtAmountForReward;
        uint256 tokenAmount;
        uint256 periodInWeeks;
    }

    function stake(uint256 amount, uint256 periodInWeeks) external;

    function unstakeWithReward() external;

    function unstakeWithoutReward() external;

    function getPotentialNftReward(uint256 tokenAmount, uint256 periodInWeeks, address account) view external returns (uint256[] memory, uint256, uint256);

    function changeMultiplier(uint256 periodInWeeks, uint256 value) external;

    function getMinAmountToStake() external view returns (uint256);

    function getActualNftReward(uint256 calculatedUsdtAmountForReward) view external returns (uint256[] memory);
}

contract REBLStaking is IREBLStaking, Ownable {
    IREBLNFT nftContract;
    using IterableMapping for IterableMapping.Map;
    IterableMapping.Map internal investors;

    struct Rank {
        address account;
        uint256 multipliedValue;
    }
    IPancakeSwap public router;
    IPancakePair bnbTokenPair;
    IPancakePair bnbUsdtPair;
    //    address usdtAddress = 0x55d398326f99059fF775485246999027B3197955; //mainnet
    //    address reblAddress = 0xbB8b7E9A870FbC22ce4b543fc3A43445Fbf9097f; //mainnet
    address usdtAddress = 0x40D7c8F55C25f448204a140b5a6B0bD8C1E48b13; //testnet
    address reblAddress = 0x2ea8c131b84a11f8CCC7bfdC6abE6A96341b8673;   //testnet
    address wbnbAddress = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;   //testnet

    mapping(uint256 => uint256) multiplierByWeekAmount;
    mapping(address => UserStakingInfo) public usersStaking;
    uint256 constant MULTIPLIER_DENOMINATOR = 100;
    // uint256 constant SECONDS_IN_WEEK = 1 weeks; //main
    // todo don't forget to change
    uint256 constant SECONDS_IN_WEEK = 60; //for test

    constructor(
        address _nftContractAddress,
        address _bnbTokenPairAddress
    ) {
        //        initDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E); //mainnet
        initDEXRouter(0x14e9203E14EF89AB284b8e9EecC787B1743AD285);
        //testnet

        bnbTokenPair = IPancakePair(_bnbTokenPairAddress);
        //        bnbUsdtPair = IPancakePair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE); //mainnet
        bnbUsdtPair = IPancakePair(0x804710fb401e9A4c11cF13A8399c49bDf14A49B8); //testnet
        // mainnet bsc
        nftContract = IREBLNFT(_nftContractAddress);
        multiplierByWeekAmount[2] = 100;
        multiplierByWeekAmount[4] = 120;
        multiplierByWeekAmount[6] = 130;
        multiplierByWeekAmount[8] = 140;
        multiplierByWeekAmount[10] = 150;
        multiplierByWeekAmount[12] = 160;
        multiplierByWeekAmount[14] = 170;
        multiplierByWeekAmount[16] = 180;
        multiplierByWeekAmount[18] = 190;
        multiplierByWeekAmount[20] = 200;
    }

    function getAllInvestors() external view returns(Rank[] memory) {
        Rank[] memory rank = new Rank[](investors.size());
        address user;
        for(uint256 index = 0; index < investors.size(); index++) {
            user = investors.keys[index];
            rank[index] = Rank(user, investors.values[user]);
        }
        return rank;
    }

    function stake(uint256 amount, uint256 periodInWeeks) public override {
        require(periodInWeeks >= 2, "Min period for staking is 2 weeks");
        require(isEvenNumber(periodInWeeks), "Period in weeks should be even number");

        uint256 calculatedUsdtAmountForReward = calculateUsdtAmountForReward(amount, periodInWeeks);
        uint256 calculatedUSDT = usersStaking[msg.sender].usdtAmountForReward + calculatedUsdtAmountForReward;
        uint256 tokenAmount = usersStaking[msg.sender].tokenAmount + amount;
        uint256 unstakeTimestamp = calculateUnstakeTimestamp(periodInWeeks);
        if (unstakeTimestamp < usersStaking[msg.sender].rewardUnblockTimestamp) {
            unstakeTimestamp = usersStaking[msg.sender].rewardUnblockTimestamp;
        }
        IERC20(reblAddress).transferFrom(msg.sender, address(this), amount);
        investors.set(msg.sender, calculatedUSDT);
        usersStaking[msg.sender] = UserStakingInfo(unstakeTimestamp, calculatedUSDT, tokenAmount, periodInWeeks);
    }

    function unstakeWithReward() public override {
        require(block.timestamp >= usersStaking[msg.sender].rewardUnblockTimestamp, "Reward is not available yet");
        nftContract.mintToByAmount(msg.sender, usersStaking[msg.sender].usdtAmountForReward);
        IERC20(reblAddress).transfer(msg.sender, usersStaking[msg.sender].tokenAmount);
        _clearUserStaking(msg.sender);
    }

    function unstakeWithoutReward() public override {
        IERC20(reblAddress).transfer(msg.sender, usersStaking[msg.sender].tokenAmount);
        _clearUserStaking(msg.sender);
    }

    function getPotentialNftReward(uint256 tokenAmount, uint256 periodInWeeks, address account) view public override returns (uint256[] memory, uint256, uint256) {
        uint256 calculatedUsdtAmountForReward = calculateUsdtAmountForReward(tokenAmount, periodInWeeks);
        uint256 unlockTimestamp = block.timestamp + periodInWeeks * SECONDS_IN_WEEK;
        if (usersStaking[account].usdtAmountForReward > 0) {
            calculatedUsdtAmountForReward += usersStaking[account].usdtAmountForReward;
            if (usersStaking[account].rewardUnblockTimestamp > unlockTimestamp) {
                unlockTimestamp = usersStaking[account].rewardUnblockTimestamp;
            }
        }
        return (getNftReward(calculatedUsdtAmountForReward), calculatedUsdtAmountForReward, unlockTimestamp);
    }

    function getActualNftReward(uint256 calculatedUsdtAmountForReward) view public override returns (uint256[] memory) {
        uint256[] memory nftReward = getNftReward(calculatedUsdtAmountForReward);
        return nftReward;
    }

    function getNftReward(uint256 calculatedUsdtAmountForReward) view internal returns (uint256[] memory) {
        uint256[] memory levelsUsdtValues = nftContract.getLevelsUsdtValues();
        uint256 lowestNftUsdtValue = nftContract.getLowestLevelUsdtValue();
        uint256[] memory levelsCount = new uint256[](levelsUsdtValues.length);
        while (calculatedUsdtAmountForReward >= lowestNftUsdtValue) {
            for (uint256 i = levelsUsdtValues.length; i > 0; i--) {
                if (calculatedUsdtAmountForReward >= levelsUsdtValues[i - 1]) {
                    levelsCount[i - 1]++;
                    calculatedUsdtAmountForReward -= levelsUsdtValues[i - 1];
                    break;
                }
            }
        }
        return levelsCount;
    }

    function changeMultiplier(uint256 periodInWeeks, uint256 value) public override onlyOwner {
        multiplierByWeekAmount[periodInWeeks] = value;
    }

    function _clearUserStaking(address userAddress) internal {
        usersStaking[userAddress].usdtAmountForReward = 0;
        usersStaking[userAddress].tokenAmount = 0;
        usersStaking[userAddress].rewardUnblockTimestamp = 0;
        investors.remove(userAddress);
    }

    function calculateMultiplier(uint256 periodInWeeks) view internal returns (uint256) {
        if (periodInWeeks > 18) {
            return multiplierByWeekAmount[20];
        }
        return multiplierByWeekAmount[periodInWeeks];
    }

    function isEvenNumber(uint256 number) internal pure returns (bool) {
        uint256 div = number / 2;
        return div * 2 == number;
    }

    function calculateUnstakeTimestamp(uint256 periodInWeeks) internal view returns (uint256) {
        return block.timestamp + periodInWeeks * SECONDS_IN_WEEK;
    }

    function calculateUsdtAmountForReward(uint256 amount, uint256 periodInWeeks) public view returns (uint256) {
        uint256 multiplier = calculateMultiplier(periodInWeeks);
        return calculateTokensPriceInUSDT(amount) * multiplier * (periodInWeeks / 2) / MULTIPLIER_DENOMINATOR;
    }
    // (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    //todo check order of tokens in pair
    //    function calculateTokensPriceInUSDT(uint256 tokenAmount) public view returns (uint256) {
    //        (uint256 tokenReserveForBnbPair, uint256 bnbReserve, ) = bnbTokenPair.getReserves();
    //        (uint256 usdtReserve, uint256 bnbReserveForUsdtPair, ) = bnbUsdtPair.getReserves();
    //        return tokenAmount * bnbReserve * usdtReserve / bnbReserveForUsdtPair / tokenReserveForBnbPair;
    //    }

    function calculateTokensPriceInUSDT(uint256 tokenAmount) public view returns (uint256) {
        (uint256 token1Amount, uint256 token2Amount, ) = bnbTokenPair.getReserves();
        (uint256 tokenReserveForBnbPair, uint256 bnbReserve) = reblAddress < wbnbAddress ? (token1Amount, token2Amount) : (token2Amount, token1Amount);
        (uint256 token3Amount, uint256 token4Amount, ) = bnbUsdtPair.getReserves();
        (uint256 usdtReserve, uint256 bnbReserveForUsdtPair) = usdtAddress < wbnbAddress ? (token3Amount, token4Amount) : (token4Amount, token3Amount);
        return tokenAmount * bnbReserve / bnbReserveForUsdtPair * usdtReserve / tokenReserveForBnbPair;
    }

    //todo check order of tokens in pair
    //    function calculateTokensAmountForUsdt(uint256 usdtAmount) public view returns (uint256) {
    //        ( uint256 usdtReserve, uint256 bnbReserveForUsdtPair, ) = bnbUsdtPair.getReserves();
    //        (uint256 tokenReserveForBnbPair, uint256 bnbReserve, ) = bnbTokenPair.getReserves();
    //        return usdtAmount * bnbReserveForUsdtPair * tokenReserveForBnbPair / usdtReserve / bnbReserve;
    //    }

    function calculateTokensAmountForUsdt(uint256 usdtAmount) public view returns (uint256) {
        (uint256 token1Amount, uint256 token2Amount, ) = bnbUsdtPair.getReserves();
        (uint256 usdtReserve, uint256 bnbReserveForUsdtPair) = usdtAddress < wbnbAddress ? (token1Amount, token2Amount) : (token2Amount, token1Amount);
        (uint256 token3Amount, uint256 token4Amount, ) = bnbTokenPair.getReserves();
        (uint256 tokenReserveForBnbPair, uint256 bnbReserve) = reblAddress < wbnbAddress ? (token3Amount, token4Amount) : (token4Amount, token3Amount);
        return usdtAmount * bnbReserveForUsdtPair / usdtReserve * tokenReserveForBnbPair / bnbReserve;
    }

    function initDEXRouter(address _router) public onlyOwner {
        IPancakeSwap _pancakeV2Router = IPancakeSwap(_router);
        router = _pancakeV2Router;
    }

    function getMinAmountToStake() public view override returns (uint256) {
        return calculateTokensAmountForUsdt(nftContract.getLowestLevelUsdtValue());
    }
}
