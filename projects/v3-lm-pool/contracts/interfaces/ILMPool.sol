// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

interface ILMPool {
    function lmTicks(int24) external view returns (uint128, int128, uint256);

    function rewardGrowthGlobalX128() external view returns (uint256);

    function lmLiquidity() external view returns (uint128);

    function lastRewardTimestamp() external view returns (uint32);

    function getRewardGrowthInside(
        int24 tickLower,
        int24 tickUpper
    ) external view returns (uint256);
}