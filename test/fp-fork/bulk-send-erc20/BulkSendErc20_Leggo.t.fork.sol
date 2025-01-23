// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// OZ
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// HMX Tests
import { DynamicForkBaseTest } from "@hmx-test/fp-fork/bases/DynamicForkBaseTest.sol";

/// HMX
import { BulkSendErc20 } from "@hmx/tokens/BulkSendErc20.sol";

contract BulkSendErc20_LeggoForkTest is DynamicForkBaseTest {
  BulkSendErc20 internal bulkSendErc20;

  function setUp() public override {
    super.setUp();
    if (!isForkSupported) {
      return;
    }

    bulkSendErc20 = new BulkSendErc20();
  }

  function testCorrectness_WhenLeggo() external onlyFork {
    motherload(address(usdc_e), address(this), 10_000_00 * 1e6);
    motherload(address(weth), address(this), 10_000_00 * 1e18);

    usdc_e.approve(address(bulkSendErc20), type(uint256).max);
    weth.approve(address(bulkSendErc20), type(uint256).max);

    IERC20[] memory tokens = new IERC20[](2);
    tokens[0] = usdc_e;
    tokens[1] = weth;

    address[] memory recipients = new address[](2);
    recipients[0] = ALICE;
    recipients[1] = BOB;

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = 10_000 * 1e6;
    amounts[1] = 10_000 * 1e18;

    bulkSendErc20.leggo(tokens, recipients, amounts);

    assertEq(usdc_e.balanceOf(ALICE), 10_000 * 1e6);
    assertEq(weth.balanceOf(BOB), 10_000 * 1e18);

    vm.startPrank(ALICE);
    // vm.expectRevert("ERC20: insufficient allowance"); // Testnet
    vm.expectRevert("ERC20: transfer amount exceeds allowance");
    bulkSendErc20.leggo(tokens, recipients, amounts);
  }
}
