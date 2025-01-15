// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { Smoke_Base } from "./Smoke_Base.t.sol";
import { DynamicForkBaseTest } from "@hmx-test/fp-fork/bases/DynamicForkBaseTest.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";

import "forge-std/console.sol";

contract Smoke_Collateral is DynamicForkBaseTest {
  uint8 internal SUB_ACCOUNT_NO = 1;
  IERC20[] private collateralToken = new IERC20[](3);

  constructor() {
    super.setUp();
    if (!isForkSupported) {
      return;
    }
    collateralToken[0] = IERC20(address(usdc_e));
    collateralToken[1] = IERC20(address(weth));
    collateralToken[2] = IERC20(address(wbtc));
  }

  function depositCollateral()  external onlyFork {
    _depositCollateral();
  }

  function withdrawCollateral()  external onlyFork {
    _depositCollateral();
    _withdrawCollateral();
  }

  function _depositCollateral() internal {
    address subAccount = _getSubAccount(ALICE, SUB_ACCOUNT_NO);
    for (uint8 i = 0; i < collateralToken.length; i++) {
      uint8 tokenDecimal = collateralToken[i].decimals();

      deal(address(collateralToken[i]), ALICE, 10 * (10 ** tokenDecimal));

      vm.startPrank(ALICE);
      collateralToken[i].approve(address(crossMarginHandler), type(uint256).max);
      crossMarginHandler.depositCollateral(
        SUB_ACCOUNT_NO,
        address(collateralToken[i]),
        10 * (10 ** tokenDecimal),
        false
      );
      vm.stopPrank();
      assertEq(10 * (10 ** tokenDecimal), vaultStorage.traderBalances(subAccount, address(collateralToken[i])));
    }
  }

  function _withdrawCollateral() internal {
    uint256 minExecutionFee = crossMarginHandler.minExecutionOrderFee();
    IEcoPythCalldataBuilder3.BuildData[] memory data = _buildDataForPrice();
    (
      uint256 _minPublishTime,
      bytes32[] memory _priceUpdateCalldata,
      bytes32[] memory _publishTimeUpdateCalldata,
    ) = ecoPythBuilder.build(data);
    for (uint8 i = 0; i < collateralToken.length; i++) {
      uint8 tokenDecimal = collateralToken[i].decimals();
      deal(ALICE, minExecutionFee);
      vm.prank(ALICE);
      uint256 _latestOrderIndex = crossMarginHandler.createWithdrawCollateralOrder{ value: minExecutionFee }(
        SUB_ACCOUNT_NO,
        address(collateralToken[i]),
        10 * (10 ** tokenDecimal),
        minExecutionFee,
        false
      );

      vm.warp(block.timestamp + 30);
      vm.roll(block.number + 30);

      vm.prank(liquidityOrderExecutor);
      crossMarginHandler.executeOrder(
        _latestOrderIndex,
        payable(ALICE),
        _priceUpdateCalldata,
        _publishTimeUpdateCalldata,
        _minPublishTime,
        keccak256("someEncodedVaas")
      );
      assertEq(10 * (10 ** tokenDecimal), collateralToken[i].balanceOf(ALICE));
    }
  }
}
