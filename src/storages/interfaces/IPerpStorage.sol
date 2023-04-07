// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPerpStorage {
  /**
   * Errors
   */
  error IPerpStorage_NotWhiteListed();

  /**
   * Structs
   */
  struct GlobalState {
    uint256 reserveValueE30; // accumulative of reserve value from all opening positions
  }

  struct AssetClass {
    uint256 reserveValueE30; // accumulative of reserve value from all opening positions
    uint256 sumBorrowingRate;
    uint256 lastBorrowingTime;
    uint256 sumBorrowingFeeE30;
    uint256 sumSettledBorrowingFeeE30;
  }

  // mapping _marketIndex => globalPosition;
  struct Market {
    // LONG position
    uint256 longPositionSize;
    uint256 longAvgPrice;
    // SHORT position
    uint256 shortPositionSize;
    uint256 shortAvgPrice;
    // funding rate
    int256 currentFundingRate;
    uint256 lastFundingTime;
    int256 accumFundingLong; // accumulative of funding fee value on LONG positions using for calculating surplus
    int256 accumFundingShort; // accumulative of funding fee value on SHORT positions using for calculating surplus
  }

  // Trade position
  struct Position {
    address primaryAccount;
    uint256 marketIndex;
    uint256 avgEntryPriceE30;
    uint256 entryBorrowingRate;
    uint256 reserveValueE30; // Max Profit reserved in USD (9X of position collateral)
    uint256 lastIncreaseTimestamp; // To validate position lifetime
    int256 positionSizeE30; // LONG (+), SHORT(-) Position Size
    int256 realizedPnl;
    int256 entryFundingRate;
    uint8 subAccountId;
  }

  /**
   * Functions
   */
  function getPositionBySubAccount(address _trader) external view returns (Position[] memory traderPositions);

  function getPositionById(bytes32 _positionId) external view returns (Position memory);

  function getMarketByIndex(uint256 _marketIndex) external view returns (Market memory);

  function getAssetClassByIndex(uint256 _assetClassIndex) external view returns (AssetClass memory);

  function getGlobalState() external view returns (GlobalState memory);

  function getNumberOfSubAccountPosition(address _subAccount) external view returns (uint256);

  function updateGlobalLongMarketById(uint256 _marketIndex, uint256 _newPositionSize, uint256 _newAvgPrice) external;

  function updateGlobalShortMarketById(uint256 _marketIndex, uint256 _newPositionSize, uint256 _newAvgPrice) external;

  function updateGlobalState(GlobalState memory _newGlobalState) external;

  function savePosition(address _subAccount, bytes32 _positionId, Position calldata position) external;

  function removePositionFromSubAccount(address _subAccount, bytes32 _positionId) external;

  function updateAssetClass(uint8 _assetClassIndex, AssetClass memory _newAssetClass) external;

  function updateMarket(uint256 _marketIndex, Market memory _market) external;

  function getPositionIds(address _subAccount) external returns (bytes32[] memory _positionIds);

  function setServiceExecutors(address _executorAddress, bool _isServiceExecutor) external;

  function increaseReserved(uint8 _assetClassIndex, uint256 _reserve) external;

  function decreaseReserved(uint8 _assetClassIndex, uint256 _reserve) external;
}
