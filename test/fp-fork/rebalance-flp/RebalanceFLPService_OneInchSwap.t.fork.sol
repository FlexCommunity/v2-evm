// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// HMX
import { IRebalanceHLPService } from "@hmx/services/interfaces/IRebalanceHLPService.sol";

/// HMX Tests
import { DynamicForkBaseTestWithActions } from "@hmx-test/fp-fork/bases/DynamicForkBaseTestWithActions.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { MockEcoPyth } from "@hmx-test/mocks/MockEcoPyth.sol";
import { Uint2str } from "@hmx-test/libs/Uint2str.sol";

import { console } from "forge-std/console.sol";

contract RebalanceFLPService_OneInchSwapForkTest is DynamicForkBaseTestWithActions {
  using Uint2str for uint256;

  address sglp = address(0);

  function setUp() public override {
    super.setUp();
    if (!isFork()) return;

    // Mock EcoPyth
    makeEcoPythMockable();
  }

  function testCorrectness_WhenSwap() external onlyFork {
    address[] memory pricePath = new address[](2);
    pricePath[0] = address(wbtc);
    pricePath[1] = address(usdc);

    // Calculate BTC price
    uint256 testAmountIn = 1 * 10**wbtcDec / 100;
    vm.startPrank(ALICE);
    deal(address(wbtc), address(ALICE), testAmountIn);
    wbtc.approve(address(switchCollateralRouter), testAmountIn);
    wbtc.transfer(address(switchCollateralRouter), testAmountIn);
    uint256 btcToUsd = switchCollateralRouter.execute(testAmountIn, pricePath) * 100;

    // Recheck price to see price change affected by first swap
    deal(address(wbtc), address(ALICE), testAmountIn);
    wbtc.approve(address(switchCollateralRouter), testAmountIn);
    wbtc.transfer(address(switchCollateralRouter), testAmountIn);
    uint256 btcToUsd2 = switchCollateralRouter.execute(testAmountIn, pricePath) * 100;


    // Get lastest price data
    MockEcoPyth(address(ecoPyth2)).overridePrice(bytes32("BTC"), btcToUsd);
    (
      bytes32[] memory priceData,
      bytes32[] memory publishedTimeData,
      uint256 minPublishedTime,
      bytes32 encodedVaas
    ) = MockEcoPyth(address(ecoPyth2)).getLastestPriceUpdateData();

    // Start a session as deployer
    vm.startPrank(deployer);
    // Swap from sGLP to USDC_e so we have >5m USDC_e
    address[] memory path = new address[](2);
    path[0] = address(usdc);
    path[1] = address(wbtc);

    uint256 wbtcFlp0 = vaultStorage.hlpLiquidity(address(wbtc));
    uint256 usdcFlp0 = vaultStorage.hlpLiquidity(address(usdc));

    console.log("wbtcFlp0: ", wbtcFlp0.uint2str(wbtcDec));
    console.log("usdcFlp0: ", usdcFlp0.uint2str(usdcDec));

    rebalanceHLPHandler.swap(
      IRebalanceHLPService.SwapParams({ amountIn: 100 * 10**usdcDec, minAmountOut: 1, path: path }),
      priceData,
      publishedTimeData,
      minPublishedTime,
      encodedVaas
    );

    uint256 wbtcFlp1 = vaultStorage.hlpLiquidity(address(wbtc));
    uint256 usdcFlp1 = vaultStorage.hlpLiquidity(address(usdc));

//    console.log("wbtcFlp1: ", wbtcFlp1.uint2str(wbtcDec));
//    console.log("usdcFlp1: ", usdcFlp1.uint2str(usdcDec));

    vm.stopPrank();

    // As price is variable we assume that BTC price is $5k minimum
//    console.log("usdcToBtc: ", btcToUsd.uint2str(usdcDec));
//    console.log("usdcToBtc2: ", btcToUsd2.uint2str(usdcDec));
    uint256 wbtcExpectedMin = 100 * 10**usdcDec * 10**wbtcDec  / btcToUsd;

    assertEq(usdc.balanceOf(address(rebalanceHLPService)), 0, "should not has any USDC in RebalanceHLPService");
    assertEq(usdcFlp0 - usdcFlp1, 100 * 10**usdcDec, "USDC liquidity should be swapped");
//    console.log("wbtcExpected: ", wbtcExpectedMin.uint2str(wbtcDec));
//    console.log("wbtc received: ", (wbtcFlp1 - wbtcFlp0).uint2str(wbtcDec));
    assertApproxEqAbs(wbtcFlp1 - wbtcFlp0, wbtcExpectedMin, 1000, "BTC liquidity should be received");
  }

}
