// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

interface IVester {
  // ---------------------
  //       Errors
  // ---------------------
  error BadArgument();
  error ExceedMaxDuration();
  error Unauthorized();
  error Claimed();
  error Aborted();
  error HasCompleted();

  // ---------------------
  //       Structs
  // ---------------------
  struct Item {
    address owner;
    bool hasClaimed;
    bool hasAborted;
    uint256 amount;
    uint256 startTime;
    uint256 endTime;
    uint256 lastClaimTime;
    uint256 totalUnlockedAmount;
  }

  function vestFor(address account, uint256 amount, uint256 duration) external;

  function claimFor(address account, uint256 itemIndex) external;

  function claimFor(address account, uint256[] memory itemIndexes) external;

  function abort(uint256 itemIndex) external;

  function getUnlockAmount(uint256 amount, uint256 duration) external returns (uint256);

  function nextItemId() external view returns (uint256);

  function items(
    uint256 index
  )
    external
    view
    returns (
      address owner,
      bool hasClaimed,
      bool hasAborted,
      uint256 amount,
      uint256 startTime,
      uint256 endTime,
      uint256 lastClaimTime,
      uint256 totalUnlockedAmount
    );
}
