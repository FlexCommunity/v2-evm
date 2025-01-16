// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";

import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";
import { ILimitTradeHandler } from "@hmx/handlers/interfaces/ILimitTradeHandler.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { DynamicForkBaseTest } from "@hmx-test/fp-fork/bases/DynamicForkBaseTest.sol";

import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";
import { IOrderReader } from "@hmx/readers/interfaces/IOrderReader.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract Smoke_TriggerOrder is DynamicForkBaseTest {
  error Smoke_TriggerOrder_NoOrder();

  address[] internal accounts;
  uint8[] internal subAccountIds;
  uint256[] internal orderIndexes;

  address[] internal executeAccounts;
  uint8[] internal executeSubAccountIds;
  uint256[] internal executeOrderIndexes;
  IOrderReader newOrderReader;

  constructor() {
    super.setUp();

    newOrderReader = Deployer.deployOrderReader(
      address(configStorage),
      address(perpStorage),
      address(oracleMiddleware),
      address(limitTradeHandler)
    );
  }

  function executeTriggerOrder()  external onlyFork {
    (, , bool[] memory shouldInverts) = _setPriceData(1);

    ILimitTradeHandler.LimitOrder memory _order;

    ILimitTradeHandler.LimitOrder[] memory activeOrders = limitTradeHandler.getAllActiveOrders(10, 0);

    for (uint i = 0; i < activeOrders.length; i++) {
      if (
        activeOrders[i].account != address(0) &&
        activeOrders[i].marketIndex != 3 && // Ignore JPY, too complicated with invert
        (activeOrders[i].sizeDelta == type(int256).max || // focus only TP
          activeOrders[i].sizeDelta == type(int256).min) // focus only SL
      ) {
        accounts.push(activeOrders[i].account);
        subAccountIds.push(activeOrders[i].subAccountId);
        orderIndexes.push(activeOrders[i].orderIndex);
        _order = activeOrders[i];
      }
      if (accounts.length > 0) break;
    }

    if (accounts.length == 0) {
      revert Smoke_TriggerOrder_NoOrder();
    }

    uint64[] memory prices = new uint64[](30);
    prices = _buildPrice_Trigger(_order.marketIndex, _order.triggerPrice, _order.triggerAboveThreshold);
    ILimitTradeHandler.LimitOrder[] memory readerOrders = newOrderReader.getExecutableOrders(
      10,
      0,
      prices,
      shouldInverts
    );

    IEcoPythCalldataBuilder3.BuildData[] memory data = _buildDataForPrice_Trigger(
      _order.marketIndex,
      _order.triggerPrice,
      _order.triggerAboveThreshold
    );

    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,
    ) = ecoPythBuilder.build(data);

    for (uint i = 0; i < readerOrders.length; i++) {
      if (readerOrders[i].account == address(0)) continue;
      executeAccounts.push(readerOrders[i].account);
      executeSubAccountIds.push(readerOrders[i].subAccountId);
      executeOrderIndexes.push(readerOrders[i].orderIndex);
    }

    vm.prank(address(botHandler));
    ecoPyth2.updatePriceFeeds(
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      block.timestamp,
      keccak256("someEncodedVaas")
    );

    vm.prank(limitOrderExecutor);
    limitTradeHandler.executeOrders(
      executeAccounts,
      executeSubAccountIds,
      executeOrderIndexes,
      payable(limitOrderExecutor),
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("someEncodedVaas"),
      true
    );

    _validateExecutedOrder(executeAccounts, executeSubAccountIds, executeOrderIndexes);
  }

  function _validateExecutedOrder(
    address[] memory _accounts,
    uint8[] memory _subAccountIds,
    uint256[] memory _orderIndexes
  ) internal {
    for (uint i = 0; i < _accounts.length; i++) {
      address subAccount = HMXLib.getSubAccount(accounts[i], _subAccountIds[i]);

      // order should be deleted
      (address account, , , , , , , , , , , ) = limitTradeHandler.limitOrders(subAccount, _orderIndexes[i]);
      assertEq(account, address(0));
    }
  }

  function _buildDataForPrice_Trigger(
    uint256 _marketIndex,
    uint256 _triggerPrice,
    bool _above
  ) internal view returns (IEcoPythCalldataBuilder3.BuildData[] memory data) {
    bytes32[] memory pythRes = ecoPyth2.getAssetIds();

    uint256 len = pythRes.length; // 35 - 1(index 0) = 34

    data = new IEcoPythCalldataBuilder3.BuildData[](len - 1);

    for (uint i = 1; i < len; i++) {
      PythStructs.Price memory _ecoPythPrice = ecoPyth2.getPriceUnsafe(pythRes[i]);
      IConfigStorage.MarketConfig memory marketConfig = configStorage.getMarketConfigByIndex(_marketIndex);

      if (marketConfig.assetId == pythRes[i]) {
        if (_above) {
          data[i - 1].priceE8 = int64(int256(((_triggerPrice * 10001) / 10000) / 1e22)); // 105% of trigger
        } else {
          data[i - 1].priceE8 = int64(int256(((_triggerPrice * 9999) / 10000) / 1e22)); // 95% of trigger
        }
      } else data[i - 1].priceE8 = _ecoPythPrice.price;
      data[i - 1].assetId = pythRes[i];
      data[i - 1].publishTime = uint160(block.timestamp);
      data[i - 1].maxDiffBps = 15_000;
    }
  }

  function _buildPrice_Trigger(
    uint256 _marketIndex,
    uint256 _triggerPrice,
    bool _above
  ) internal view returns (uint64[] memory prices) {
    IConfigStorage.MarketConfig[] memory marketConfigs = configStorage.getMarketConfigs();
    prices = new uint64[](marketConfigs.length);

    for (uint i = 0; i < marketConfigs.length; i++) {
      if (_marketIndex == i) {
        if (_above) {
          prices[i] = uint64(((_triggerPrice * 10001) / 10000) / 1e22); // 100.01% of trigger
        } else {
          prices[i] = uint64(((_triggerPrice * 9999) / 10000) / 1e22); // 99.99% of trigger
        }
      } else {
        PythStructs.Price memory _ecoPythPrice = ecoPyth2.getPriceUnsafe(marketConfigs[i].assetId);
        prices[i] = uint64(_ecoPythPrice.price);
      }
    }
  }
}
