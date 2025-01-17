// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { DynamicForkBaseTest } from "@hmx-test/fp-fork/bases/DynamicForkBaseTest.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { ITradeService } from "@hmx/services/interfaces/ITradeService.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { PythStructs } from "pyth-sdk-solidity/PythStructs.sol";
import { SafeCastUpgradeable } from "@openzeppelin-upgradeable/contracts/utils/math/SafeCastUpgradeable.sol";

contract Smoke_Trade is DynamicForkBaseTest {
  using SafeCastUpgradeable for int64;
  uint8 internal constant SUB_ACCOUNT_NO = 0;
  uint256 internal constant MARKET_INDEX = 1;
  // eth | btc
  uint256[] internal ARRAY_MARKET_INDEX = [0, 1];

  constructor() {
    super.setUp();
  }

  function openClosePosition()  external onlyFork {
    _depositCollateral();
    _createAndExecuteMarketBuyOrder();
    _createAndExecuteMarketSellOrder();
  }

  function _depositCollateral() internal {
    uint8 tokenDecimal = IERC20(address(usdc_e)).decimals();
    deal(address(usdc_e), ALICE, 1000 * (10 ** tokenDecimal));
    vm.startPrank(ALICE);
    usdc_e.approve(address(crossMarginHandler), type(uint256).max);
    crossMarginHandler.depositCollateral(SUB_ACCOUNT_NO, address(usdc_e), 1000 * (10 ** tokenDecimal), false);
    vm.stopPrank();
  }

  function _createAndExecuteMarketBuyOrder() internal {
    address subAccount = _getSubAccount(ALICE, SUB_ACCOUNT_NO);
    deal(ALICE, 10 ether);

    uint256 _orderIndex = limitTradeHandler.limitOrdersIndex(subAccount);
    uint256[] memory orderIndexes = new uint256[](ARRAY_MARKET_INDEX.length);
    address[] memory accounts = new address[](ARRAY_MARKET_INDEX.length);
    uint8[] memory subAccountIds = new uint8[](ARRAY_MARKET_INDEX.length);
    for (uint i = 0; i < ARRAY_MARKET_INDEX.length; i++) {
      orderIndexes[i] = _orderIndex;
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      vm.prank(ALICE);
      limitTradeHandler.createOrder{ value: 0.1 ether }({
        _subAccountId: SUB_ACCOUNT_NO,
        _marketIndex: ARRAY_MARKET_INDEX[i],
        _sizeDelta: 100 * 1e30,
        _triggerPrice: 0,
        _acceptablePrice: type(uint256).max,
        _triggerAboveThreshold: false,
        _executionFee: 0.1 ether,
        _reduceOnly: false,
        _tpToken: address(usdc_e)
      });
      _orderIndex = limitTradeHandler.limitOrdersIndex(subAccount);
    }

    IEcoPythCalldataBuilder3.BuildData[] memory data = _buildDataForPrice();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,
    ) = ecoPythBuilder.build(data);

    vm.warp(block.timestamp + 30);
    vm.roll(block.number + 30);

    // Execute Long Increase Order
    vm.prank(limitOrderExecutor);
    limitTradeHandler.executeOrders({
      _accounts: accounts,
      _subAccountIds: subAccountIds,
      _orderIndexes: orderIndexes,
      _feeReceiver: payable(BOB),
      _priceData: _priceUpdateCalldata,
      _publishTimeData: _publishTimeUpdateCalldata,
      _minPublishTime: _minPublishTime,
      _encodedVaas: keccak256("someEncodedVaas"),
      _isRevert: true
    });

    assertEq(perpStorage.getNumberOfSubAccountPosition(subAccount), ARRAY_MARKET_INDEX.length, "User must have 2 Long position");

    for (uint i = 0; i < ARRAY_MARKET_INDEX.length; i++) {
      orderIndexes[i] = _orderIndex;
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      vm.prank(ALICE);
      limitTradeHandler.createOrder{ value: 0.1 ether }({
        _subAccountId: SUB_ACCOUNT_NO,
        _marketIndex: ARRAY_MARKET_INDEX[i],
        _sizeDelta: -100 * 1e30,
        _triggerPrice: 0,
        _acceptablePrice: 0,
        _triggerAboveThreshold: false,
        _executionFee: 0.1 ether,
        _reduceOnly: true,
        _tpToken: address(usdc_e)
      });
      _orderIndex = limitTradeHandler.limitOrdersIndex(subAccount);
    }

    vm.warp(block.timestamp + 30);
    vm.roll(block.number + 30);

    // Execute Close Long position
    vm.prank(limitOrderExecutor);
    limitTradeHandler.executeOrders({
      _accounts: accounts,
      _subAccountIds: subAccountIds,
      _orderIndexes: orderIndexes,
      _feeReceiver: payable(BOB),
      _priceData: _priceUpdateCalldata,
      _publishTimeData: _publishTimeUpdateCalldata,
      _minPublishTime: _minPublishTime,
      _encodedVaas: keccak256("someEncodedVaas"),
      _isRevert: true
    });

    assertEq(perpStorage.getNumberOfSubAccountPosition(subAccount), 0, "User must have no position");
  }

  function _createAndExecuteMarketSellOrder() internal {
    address subAccount = _getSubAccount(ALICE, SUB_ACCOUNT_NO);
    deal(ALICE, 10 ether);

    uint256 _orderIndex = limitTradeHandler.limitOrdersIndex(subAccount);
    uint256[] memory orderIndexes = new uint256[](ARRAY_MARKET_INDEX.length);
    address[] memory accounts = new address[](ARRAY_MARKET_INDEX.length);
    uint8[] memory subAccountIds = new uint8[](ARRAY_MARKET_INDEX.length);
    for (uint i = 0; i < ARRAY_MARKET_INDEX.length; i++) {
      orderIndexes[i] = _orderIndex;
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      vm.prank(ALICE);
      limitTradeHandler.createOrder{ value: 0.1 ether }({
        _subAccountId: SUB_ACCOUNT_NO,
        _marketIndex: ARRAY_MARKET_INDEX[i],
        _sizeDelta: -100 * 1e30,
        _triggerPrice: 0,
        _acceptablePrice: 0,
        _triggerAboveThreshold: false,
        _executionFee: 0.1 ether,
        _reduceOnly: false,
        _tpToken: address(usdc_e)
      });
      _orderIndex = limitTradeHandler.limitOrdersIndex(subAccount);
    }

    IEcoPythCalldataBuilder3.BuildData[] memory data = _buildDataForPrice();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,
    ) = ecoPythBuilder.build(data);

    vm.warp(block.timestamp + 30);
    vm.roll(block.number + 30);

    // Execute Short Increase Order
    vm.prank(limitOrderExecutor);
    limitTradeHandler.executeOrders({
      _accounts: accounts,
      _subAccountIds: subAccountIds,
      _orderIndexes: orderIndexes,
      _feeReceiver: payable(BOB),
      _priceData: _priceUpdateCalldata,
      _publishTimeData: _publishTimeUpdateCalldata,
      _minPublishTime: _minPublishTime,
      _encodedVaas: keccak256("someEncodedVaas"),
      _isRevert: true
    });

    assertEq(perpStorage.getNumberOfSubAccountPosition(subAccount), ARRAY_MARKET_INDEX.length, "User must have 2 Long position");

    for (uint i = 0; i < ARRAY_MARKET_INDEX.length; i++) {
      orderIndexes[i] = _orderIndex;
      accounts[i] = ALICE;
      subAccountIds[i] = SUB_ACCOUNT_NO;
      vm.prank(ALICE);
      limitTradeHandler.createOrder{ value: 0.1 ether }({
        _subAccountId: SUB_ACCOUNT_NO,
        _marketIndex: ARRAY_MARKET_INDEX[i],
        _sizeDelta: 100 * 1e30,
        _triggerPrice: 0,
        _acceptablePrice: type(uint256).max,
        _triggerAboveThreshold: false,
        _executionFee: 0.1 ether,
        _reduceOnly: true,
        _tpToken: address(usdc_e)
      });
      _orderIndex = limitTradeHandler.limitOrdersIndex(subAccount);
    }

    vm.warp(block.timestamp + 30);
    vm.roll(block.number + 30);

    // Execute Close Short position
    vm.prank(limitOrderExecutor);
    limitTradeHandler.executeOrders({
      _accounts: accounts,
      _subAccountIds: subAccountIds,
      _orderIndexes: orderIndexes,
      _feeReceiver: payable(BOB),
      _priceData: _priceUpdateCalldata,
      _publishTimeData: _publishTimeUpdateCalldata,
      _minPublishTime: _minPublishTime,
      _encodedVaas: keccak256("someEncodedVaas"),
      _isRevert: true
    });

    assertEq(perpStorage.getNumberOfSubAccountPosition(subAccount), 0, "User must have no position");
  }
}
