// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { DynamicForkBaseTest } from "@hmx-test/fp-fork/bases/DynamicForkBaseTest.sol";

import { ILiquidityHandler } from "@hmx/handlers/interfaces/ILiquidityHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Smoke_Liquidity is DynamicForkBaseTest {
  constructor() {
    super.setUp();
  }

  function addLiquidity(uint256 amountIn)  external onlyFork {
    vm.pauseGasMetering();
    _createAndExecuteAddLiquidityOrder(amountIn);
    vm.resumeGasMetering();
  }

  function addLiquidity()  external onlyFork {
    vm.pauseGasMetering();
    _createAndExecuteAddLiquidityOrder(10 * 1e6);
    vm.resumeGasMetering();
  }

  function removeLiquidity()  external onlyFork {
    vm.pauseGasMetering();
    _createAndExecuteRemoveLiquidityOrder(10 * 1e18);
    vm.resumeGasMetering();
  }

  function removeLiquidity(uint256 amountOut)  external onlyFork {
    vm.pauseGasMetering();
    _createAndExecuteRemoveLiquidityOrder(amountOut);
    vm.resumeGasMetering();
  }

  function _createAndExecuteAddLiquidityOrder(uint256 amountIn) internal {
    deal(address(usdc_e), ALICE, amountIn);
    deal(ALICE, 10 ether);
    deal(address(liquidityHandler), 100 ether);

    vm.startPrank(ALICE);

    usdc_e.approve(address(liquidityHandler), type(uint256).max);

    uint256 minExecutionFee = liquidityHandler.minExecutionOrderFee();

    uint256 _latestOrderIndex = liquidityHandler.createAddLiquidityOrder{ value: minExecutionFee }(
      address(usdc_e),
      amountIn,
      0 ether,
      minExecutionFee,
      false
    );
    vm.stopPrank();

    IEcoPythCalldataBuilder3.BuildData[] memory data = _buildDataForPrice();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,
    ) = ecoPythBuilder.build(data);

    // hlp price = aum / total supply
    uint256 _hlpPriceE30 = 1 * 1e30;
    if (hlp.totalSupply() > 0) {
      _hlpPriceE30 = (calculator.getAUME30(false) * 1e18) / hlp.totalSupply();
    }
    uint256 _estimatedHlpReceived = (amountIn / 1e6 * 1e18 * 1e30) / _hlpPriceE30;

    vm.prank(positionManager);
    botHandler.updateLiquidityEnabled(true);

    vm.warp(block.timestamp + 30);
    vm.roll(block.number + 30);

    vm.prank(liquidityOrderExecutor);
    liquidityHandler.executeOrder(
      _latestOrderIndex,
      payable(ALICE),
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("someEncodedVaas")
    );

    assertApproxEqRel(
      hlpStaking.calculateShare(address(this), address(ALICE)),
      _estimatedHlpReceived,
      0.01 ether,
      "User HLP Balance in Staking"
    );
    assertEq(usdc_e.balanceOf(ALICE), 0, "User USDC.e Balance");
  }

  function _createAndExecuteRemoveLiquidityOrder(uint256 amountOut) internal {
    deal(address(hlp), ALICE, amountOut);
    deal(ALICE, 10 ether);
    deal(address(liquidityHandler), 100 ether);

    vm.startPrank(ALICE);
    hlp.approve(address(liquidityHandler), type(uint256).max);

    uint256 minExecutionFee = liquidityHandler.minExecutionOrderFee();

    uint256 _latestOrderIndex = liquidityHandler.createRemoveLiquidityOrder{ value: minExecutionFee }(
      address(usdc_e),
      amountOut,
      0 ether,
      minExecutionFee,
      false
    );
    vm.stopPrank();

    IEcoPythCalldataBuilder3.BuildData[] memory data = _buildDataForPrice();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,
    ) = ecoPythBuilder.build(data);

    // hlpPrice = aumE30 / totalSupply
    uint256 _hlpPriceE30 = (calculator.getAUME30(false) * 1e18) / hlp.totalSupply();
    // convert hlp e30 to usdc e6
    uint256 _estimatedUsdcReceivedE6 = (amountOut / 1e18 * 1e6 * _hlpPriceE30) / 1e30;

    vm.prank(positionManager);
    botHandler.updateLiquidityEnabled(true);

    vm.warp(block.timestamp + 30);
    vm.roll(block.number + 30);

    vm.prank(liquidityOrderExecutor);
    liquidityHandler.executeOrder(
      _latestOrderIndex,
      payable(ALICE),
      _priceUpdateCalldata,
      _publishTimeUpdateCalldata,
      _minPublishTime,
      keccak256("someEncodedVaas")
    );

    assertApproxEqRel(usdc_e.balanceOf(ALICE), _estimatedUsdcReceivedE6, 0.01 ether, "User USDC.e Balance");
    assertEq(hlp.balanceOf(ALICE), 0, "User HLP Balance");
  }
}
