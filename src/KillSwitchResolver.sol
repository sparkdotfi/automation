// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

interface IKillSwitchOracle {
    function triggered() external view returns (bool);
    function oracles() external view returns (address[] memory);
    function oracleThresholds(address) external view returns (uint256);
    function trigger(address) external;
}

interface IOracle {
    function latestAnswer() external view returns (int256);
}

contract KillSwitchResolver {

    IKillSwitchOracle public immutable killSwitchOracle;

    constructor(address _killSwitchOracle) {
        killSwitchOracle = IKillSwitchOracle(_killSwitchOracle);
    }

    function checker()
        external view
        returns (bool canExec, bytes memory execPayload)
    {
        address[] memory oracles = killSwitchOracle.oracles();
        for (uint256 i = 0; i < oracles.length; i++) {
            address oracle = oracles[i];
            int256 price = IOracle(oracle).latestAnswer();
            uint256 threshold = killSwitchOracle.oracleThresholds(oracle);
            if (!killSwitchOracle.triggered() && price > 0 && uint256(price) <= threshold) {
                return (true, abi.encodeCall(IKillSwitchOracle.trigger, (oracle)));
            }
        }
    }

}
