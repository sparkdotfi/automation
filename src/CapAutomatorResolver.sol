// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

interface IPool {
    function getReservesList() external view returns (address[] memory);
    function getReserveConfiguration(address asset) external view returns (uint256);
}

interface ICapAutomator {
    function pool() external view returns (IPool pool);
    function supplyCapConfigs(address asset) external view returns (
        uint48 max,
        uint48 gap,
        uint48 increaseCooldown,
        uint48 lastUpdateBlock,
        uint48 lastIncreaseTime
    );
    function borrowCapConfigs(address asset) external view returns (
        uint48 max,
        uint48 gap,
        uint48 increaseCooldown,
        uint48 lastUpdateBlock,
        uint48 lastIncreaseTime
    );
    function exec(address asset) external returns (uint256 newSupplyCap, uint256 newBorrowCap);
    function execSupply(address asset) external returns (uint256 newSupplyCap);
    function execBorrow(address asset) external returns (uint256 newBorrowCap);
}

contract CapAutomatorResolver {

    uint256 internal constant BORROW_CAP_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFF;
    uint256 internal constant SUPPLY_CAP_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 internal constant BORROW_CAP_START_BIT_POSITION = 80;
    uint256 internal constant SUPPLY_CAP_START_BIT_POSITION = 116;

    ICapAutomator public immutable automator;
    IPool public immutable pool;
    uint256 public immutable threshold;

    constructor(address _automator, uint256 _threshold) {
        automator = ICapAutomator(_automator);
        pool = automator.pool();
        threshold = _threshold;
    }

    function checker()
        external
        returns (bool canExec, bytes memory execPayload)
    {
        address[] memory reserves = pool.getReservesList();
        for (uint256 i = 0; i < reserves.length; i++) {
            address reserve = reserves[i];

            (uint48 maxSupply, uint48 gapSupply,,,) = automator.supplyCapConfigs(reserve);
            (uint48 maxBorrow, uint48 gapBorrow,,,) = automator.borrowCapConfigs(reserve);

            uint256 config = pool.getReserveConfiguration(reserve);
            uint256 prevSupplyCap = getSupplyCap(config);
            uint256 prevBorrowCap = getBorrowCap(config);

            automator.exec(reserve);

            config = pool.getReserveConfiguration(reserve);
            uint256 nextSupplyCap = getSupplyCap(config);
            uint256 nextBorrowCap = getBorrowCap(config);

            bool supplyChanged = nextSupplyCap != prevSupplyCap &&
                (nextSupplyCap == maxSupply || absDiff(nextSupplyCap, prevSupplyCap) >= gapSupply * threshold / 1e4);
            bool borrowChanged = nextBorrowCap != prevBorrowCap &&
                (nextBorrowCap == maxBorrow || absDiff(nextBorrowCap, prevBorrowCap) >= gapBorrow * threshold / 1e4);

            // Good to adjust!
            if (supplyChanged && borrowChanged) {
                return (true, abi.encodeCall(ICapAutomator.exec, (reserve)));
            } else if (supplyChanged) {
                return (true, abi.encodeCall(ICapAutomator.execSupply, (reserve)));
            } else if (borrowChanged) {
                return (true, abi.encodeCall(ICapAutomator.execBorrow, (reserve)));
            }
        }

        return (false, "");
    }

    function getSupplyCap(
        uint256 configuration
    ) internal pure returns (uint256) {
        return (configuration & ~SUPPLY_CAP_MASK) >> SUPPLY_CAP_START_BIT_POSITION;
    }

    function getBorrowCap(
        uint256 configuration
    ) internal pure returns (uint256) {
        return (configuration & ~BORROW_CAP_MASK) >> BORROW_CAP_START_BIT_POSITION;
    }

    function absDiff(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

}
