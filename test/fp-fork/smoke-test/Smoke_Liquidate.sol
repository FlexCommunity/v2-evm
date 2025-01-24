// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { DynamicForkBaseTest } from "@hmx-test/fp-fork/bases/DynamicForkBaseTest.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";

import "forge-std/console.sol";

contract Smoke_Liquidate is DynamicForkBaseTest {
  address[] internal activeSubAccounts;

  constructor() {
    super.setUp();
  }

  // for shorter time
  function liquidate()  external onlyFork {
    (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts) = _setPriceDataForReader(1);
    (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData) = _setTickPriceZero();
    address[] memory liqSubAccounts = new address[](10);

    // NOTE: MUST ignore when it's address(0), filtering is needed.
    liqSubAccounts = liquidationReader.getLiquidatableSubAccount(10, 0, assetIds, prices, shouldInverts);

    vm.startPrank(positionManager);
    botHandler.updateLiquidityEnabled(false);
    for (uint i = 0; i < liqSubAccounts.length; i++) {
      if (liqSubAccounts[i] == address(0)) continue;
      botHandler.liquidate(
        liqSubAccounts[i],
        priceUpdateData,
        publishTimeUpdateData,
        block.timestamp,
        keccak256("someEncodedVaas")
      );
      // Liquidated, no pos left.
      assertEq(perpStorage.getNumberOfSubAccountPosition(liqSubAccounts[i]), 0);
    }
    botHandler.updateLiquidityEnabled(true);
    vm.stopPrank();
  }

  function liquidateWithAdaptiveFee()  external onlyFork {
    _setUpOrderbookOracle();

    // Set SOLUSD trade limit
    uint256[] memory _marketIndexes = new uint256[](1);
    _marketIndexes[0] = 21;
    uint256[] memory _positionSizeLimits = new uint256[](1);
    _positionSizeLimits[0] = 1_000_000 * 1e30;
    uint256[] memory _tradeSizeLimits = new uint256[](1);
    _tradeSizeLimits[0] = 1_000_000 * 1e30;
    vm.prank(limitTradeHelper.owner());
    limitTradeHelper.setLimit(_marketIndexes, _positionSizeLimits, _tradeSizeLimits);

    // Mint tokens for Alice and Bob
    deal(address(usdc_e), ALICE, 100_000 * 1e6);
    deal(ALICE, 10 ether);

    deal(address(usdc_e), BOB, 100_000 * 1e6);
    deal(BOB, 10 ether);

    // Alice open $100,000 SOLUSD long position
    vm.startPrank(ALICE);
    usdc_e.approve(address(crossMarginHandler), type(uint256).max);

    uint256 usdcCollateralAmount = 1355 * 1e6;

    crossMarginHandler.depositCollateral(0, address(usdc_e), usdcCollateralAmount, false);
    assertEq(vaultStorage.traderBalances(ALICE, address(usdc_e)), usdcCollateralAmount);
    // console.logInt(calculator.getEquity(ALICE, 0, ""));

    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 21,
      _sizeDelta: 100_000 * 1e30,
      _triggerPrice: 0,
      _acceptablePrice: type(uint256).max,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(usdc_e)
    });
    vm.stopPrank();

    IEcoPythCalldataBuilder3.BuildData[] memory data = _buildDataForPrice();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,
    ) = ecoPythBuilder.build(data);

    vm.warp(block.timestamp + 30);
    vm.roll(block.number + 30);

    // Execute Alice Order
    uint256[] memory orderIndexes = new uint256[](1);
    orderIndexes[0] = 0;
    address[] memory accounts = new address[](1);
    accounts[0] = ALICE;
    uint8[] memory subAccountIds = new uint8[](1);
    subAccountIds[0] = 0;

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

    assertEq(perpStorage.getNumberOfSubAccountPosition(ALICE), 1);
    // console.logInt(calculator.getEquity(ALICE, 0, ""));

    vm.warp(block.timestamp + 30);
    vm.roll(block.number + 30);

    // Bob open $300,000 SOLUSD short position to drive the adaptive fee up
    vm.startPrank(BOB);
    usdc_e.approve(address(crossMarginHandler), type(uint256).max);

    crossMarginHandler.depositCollateral(0, address(usdc_e), 100_000 * 1e6, false);
    assertEq(vaultStorage.traderBalances(BOB, address(usdc_e)), 100_000 * 1e6);
    // console.logInt(calculator.getEquity(BOB, 0, ""));

    limitTradeHandler.createOrder{ value: 0.1 ether }({
      _subAccountId: 0,
      _marketIndex: 21,
      _sizeDelta: -300_000 * 1e30,
      _triggerPrice: 0,
      _acceptablePrice: 0,
      _triggerAboveThreshold: false,
      _executionFee: 0.1 ether,
      _reduceOnly: false,
      _tpToken: address(usdc_e)
    });
    vm.stopPrank();

    // Execute Bob Order
    orderIndexes[0] = 0;
    accounts[0] = BOB;
    subAccountIds[0] = 0;

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

    assertEq(perpStorage.getNumberOfSubAccountPosition(BOB), 1);

    // Try to liquidate Alice, because Bob should drive the Adaptive Fee up to the point that Alice should be liquidated
    vm.startPrank(positionManager);
    botHandler.liquidate(
      ALICE,
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      block.timestamp,
      keccak256("someEncodedVaas")
    );

    assertEq(perpStorage.getNumberOfSubAccountPosition(ALICE), 0);
    assertEq(vaultStorage.traderBalances(ALICE, address(usdc_e)), 0);
  }

  function _setUpOrderbookOracle() internal {
    uint256[] memory marketIndexes = orderbookOracle.getMarketIndexes();

    int24[] memory askDepthTicks = new int24[](marketIndexes.length);
    askDepthTicks[0] = 149149;
    askDepthTicks[1] = 149150;
    askDepthTicks[2] = 149151;
    askDepthTicks[3] = 149152;
    askDepthTicks[4] = 149153;
    askDepthTicks[5] = 149154;
    askDepthTicks[6] = 149155;
    askDepthTicks[7] = 124915; // 265899.97059219
    askDepthTicks[8] = 149157;
    askDepthTicks[9] = 218230;
    askDepthTicks[10] = 149159;
    askDepthTicks[11] = 149160;

    int24[] memory bidDepthTicks = new int24[](marketIndexes.length);
    bidDepthTicks[0] = 149149;
    bidDepthTicks[1] = 149150;
    bidDepthTicks[2] = 149151;
    bidDepthTicks[3] = 149152;
    bidDepthTicks[4] = 149153;
    bidDepthTicks[5] = 149154;
    bidDepthTicks[6] = 149155;
    bidDepthTicks[7] = 124915; // 265899.97059219
    bidDepthTicks[8] = 149157;
    bidDepthTicks[9] = 218230;
    bidDepthTicks[10] = 149159;
    bidDepthTicks[11] = 149160;

    int24[] memory coeffVariantTicks = new int24[](marketIndexes.length);
    coeffVariantTicks[0] = -60708;
    coeffVariantTicks[1] = -60709;
    coeffVariantTicks[2] = -60710;
    coeffVariantTicks[3] = -60711;
    coeffVariantTicks[4] = -60712;
    coeffVariantTicks[5] = -60713;
    coeffVariantTicks[6] = -60714;
    coeffVariantTicks[7] = -60715;
    coeffVariantTicks[8] = -60716;
    coeffVariantTicks[9] = -60717;
    coeffVariantTicks[10] = -60718;
    coeffVariantTicks[11] = -60719;

    bytes32[] memory askDepths = orderbookOracle.buildUpdateData(askDepthTicks);
    bytes32[] memory bidDepths = orderbookOracle.buildUpdateData(bidDepthTicks);
    bytes32[] memory coeffVariants = orderbookOracle.buildUpdateData(coeffVariantTicks);

    vm.startPrank(orderbookOracle.owner());
    orderbookOracle.setUpdater(address(this), true);
    vm.stopPrank();

    orderbookOracle.updateData(askDepths, bidDepths, coeffVariants);
  }
}
