// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

interface IExecutor {
    enum ActionsSetState {
        Queued,
        Executed,
        Canceled,
        Expired
    }
    struct ActionsSet {
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        bool[] withDelegatecalls;
        uint256 executionTime;
        bool executed;
        bool canceled;
    }
    function execute(uint256 actionsetId) external payable;
    function getActionsSetCount() external view returns (uint256);
    function getActionsSetById(uint256 actionsSetId) external view returns (ActionsSet memory);
    function getGracePeriod() external view returns (uint256);
    function getCurrentState(uint256 actionsetId) external view returns (ActionsSetState);
}

contract GovernanceExecutorResolver {

    IExecutor public immutable executor;

    constructor(address _executor) {
        executor = IExecutor(_executor);
    }

    function checker()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        uint256 length = executor.getActionsSetCount();
        for (uint256 i = 0; i < length; i++) {
            IExecutor.ActionsSetState state = executor.getCurrentState(i);
            if (
                state == IExecutor.ActionsSetState.Queued &&
                block.timestamp >= executor.getActionsSetById(i).executionTime
                ) {
                canExec = true;
                execPayload = abi.encodeCall(IExecutor.execute, (i));
                return (canExec, execPayload);
            }
        }
    }

}
