// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { BaseTest } from "@hmx-test/base/BaseTest.sol";
import { CIXPriceAdapter } from "@hmx/oracles/CIXPriceAdapter.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IWethWithdrawProxy } from "@hmx/extensions/IWethWithdrawProxy.sol";

contract WethWithdrawProxy_BaseTest is BaseTest {

  address internal EXECUTOR;

  function setUp() public virtual {
    EXECUTOR = makeAddr("Executor");

    address[] memory executors = new address[](1);
    bool[] memory isExecutor = new bool[](1);
    executors[0] = address(EXECUTOR);
    isExecutor[0] = true;

    wethWithdrawProxy.setIsExecutors( executors, isExecutor);
  }

  function testCorrectness_Config() external {
    assertEq(address(weth), address(wethWithdrawProxy.weth()));
  }

  function testCorrectness_OwnerAccess() external {
    vm.startPrank(ALICE);

    vm.expectRevert("Ownable: caller is not the owner");
    wethWithdrawProxy.setWeth(address(usdc));
    assertEq(address(weth), address(wethWithdrawProxy.weth()), "Value should not change");

    vm.expectRevert("Ownable: caller is not the owner");
    address[] memory executors = new address[](1);
    bool[] memory isExecutor = new bool[](1);
    executors[0] = address(DAVE);
    isExecutor[0] = true;
    wethWithdrawProxy.setIsExecutors(executors, isExecutor);
    assertEq(false, wethWithdrawProxy.isExecutor(DAVE), "Value should not change");

    vm.stopPrank();

    wethWithdrawProxy.setWeth(address(usdc));
    assertEq(address(usdc), address(wethWithdrawProxy.weth()));

    wethWithdrawProxy.setIsExecutors(executors, isExecutor);
    assertEq(true, wethWithdrawProxy.isExecutor(DAVE));
  }

  function testRevert_ExecutorAccess() external {
    vm.startPrank(ALICE);

    vm.expectRevert(abi.encodeWithSignature("WethWithdrawProxy_NotExecutor()"));
    wethWithdrawProxy.transferEth(ALICE, 1);

    vm.expectRevert(abi.encodeWithSignature("WethWithdrawProxy_NotExecutor()"));
    wethWithdrawProxy.transferErc20(address(usdc), ALICE, 1);

    vm.expectRevert(abi.encodeWithSignature("WethWithdrawProxy_NotExecutor()"));
    wethWithdrawProxy.withdrawEth( payable(ALICE), 1);

    vm.expectRevert(abi.encodeWithSignature("WethWithdrawProxy_NotExecutor()"));
    wethWithdrawProxy.swapWethToEth(address(this), payable(ALICE), 1);

    vm.stopPrank();
  }

  function testRevert_transferEth_WithoutEthers() external {
    vm.startPrank(EXECUTOR);
    vm.expectRevert("Forwarding failed");
    wethWithdrawProxy.transferEth(ALICE, 1 ether);
    vm.stopPrank();
  }

  function test_transferEth() external {
    vm.deal(address(wethWithdrawProxy), 1 ether);

    assertEq(ALICE.balance, 0);
    assertEq(address(wethWithdrawProxy).balance, 1 ether);

    vm.startPrank(EXECUTOR);
    wethWithdrawProxy.transferEth(ALICE, 1 ether);
    vm.stopPrank();

    assertEq(ALICE.balance, 1 ether, "User must receive the funds");
    assertEq(address(wethWithdrawProxy).balance, 0, "Contract must send the funds");
  }

  function testRevert_transferErc20_WithoutTokens() external {
    vm.startPrank(EXECUTOR);
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    wethWithdrawProxy.transferErc20(address(usdc), ALICE, 1 ether);
    vm.stopPrank();
  }

  function test_transferErc20() external {
    deal(address(usdc), address(wethWithdrawProxy), 100 ether);

    assertEq(usdc.balanceOf(ALICE), 0);
    assertEq(usdc.balanceOf(address(wethWithdrawProxy)), 100 ether);

    vm.startPrank(EXECUTOR);
    wethWithdrawProxy.transferErc20(address(usdc), ALICE, 25 ether);
    vm.stopPrank();

    assertEq(usdc.balanceOf(ALICE), 25 ether, "User must receive usdc");
    assertEq(usdc.balanceOf(address(wethWithdrawProxy)), 75 ether, "Contract must send usdc");
  }

  function test_withdrawEth() external {
    deal(address(weth), 500 ether);
    deal(address(weth), address(ALICE), 5 ether);

    vm.prank(ALICE);
    weth.transfer(address(wethWithdrawProxy), 5 ether);

    assertEq(ALICE.balance, 0);
    assertEq(address(wethWithdrawProxy).balance, 0);
    assertEq(weth.balanceOf(address(wethWithdrawProxy)), 5 ether);

    vm.startPrank(EXECUTOR);
    vm.expectRevert();
    wethWithdrawProxy.withdrawEth( payable(ALICE), 15 ether);
    //Success
    wethWithdrawProxy.withdrawEth( payable(ALICE), 5 ether);
    vm.stopPrank();

    assertEq(weth.balanceOf(address(wethWithdrawProxy)), 0, "Contract must convert weth");
    assertEq(ALICE.balance, 5 ether, "User must receive Ethers");
    assertEq(address(wethWithdrawProxy).balance, 0, "Contract must send Ethers");
  }

  function test_swapWethToEth() external {
    deal(address(weth), 500 ether);
    deal(address(weth), address(ALICE), 7 ether);

//    vm.prank(ALICE);
//    weth.transfer(address(wethWithdrawProxy), 5 ether);

    assertEq(weth.balanceOf(ALICE), 7 ether);
    assertEq(ALICE.balance, 0);
    assertEq(address(wethWithdrawProxy).balance, 0);
    assertEq(weth.balanceOf(address(wethWithdrawProxy)), 0);

    // Check allowance not enough
    vm.expectRevert(abi.encodeWithSignature("WethWithdrawProxy_AllowanceNotEnough()"));
    vm.prank(EXECUTOR);
    wethWithdrawProxy.swapWethToEth( ALICE, payable(ALICE), 1 ether);

    vm.prank(ALICE);
    weth.approve(address(wethWithdrawProxy), 15 ether);

    vm.startPrank(EXECUTOR);
    vm.expectRevert();
    wethWithdrawProxy.swapWethToEth( ALICE, payable(ALICE), 14 ether);
    //Success
    wethWithdrawProxy.swapWethToEth( ALICE, payable(ALICE), 7 ether);
    vm.stopPrank();

    assertEq(weth.balanceOf(address(wethWithdrawProxy)), 0, "Contract must convert weth");
    assertEq(address(wethWithdrawProxy).balance, 0, "Contract must send Ethers");
    assertEq(ALICE.balance, 7 ether, "User must receive Ethers");
  }



}
