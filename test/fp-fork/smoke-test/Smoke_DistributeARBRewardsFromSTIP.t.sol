// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

// import { Smoke_Base } from "./Smoke_Base.t.sol";
// import { DynamicForkBaseTest } from "@hmx-test/fp-fork/bases/DynamicForkBaseTest.sol";
// import { IRewarder } from "@hmx/staking/interfaces/IRewarder.sol";
// import { Deployer } from "@hmx-test/libs/Deployer.sol";
// import { console2 } from "forge-std/console2.sol";
// import { IERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
// import { IDistributeSTIPARBStrategy } from "@hmx/strategies/interfaces/IDistributeSTIPARBStrategy.sol";
// import { IERC20ApproveStrategy } from "@hmx/strategies/interfaces/IERC20ApproveStrategy.sol";

// contract Smoke_DistributeARBRewardsFromSTIP is DynamicForkBaseTest {
//   constructor() {
//     super.setUp();
//   }

//   function distributeARBRewardsFromSTIP()  external onlyFork {
//     IRewarder arbRewarderForHlp = Deployer.deployFeedableRewarder(
//       address(proxyAdmin),
//       "HLP Staking ARB Rewards",
//       address(arb),
//       address(hlpStaking)
//     );
//     arbRewarderForHlp.setFeeder(address(vaultStorage));

//     address[] memory rewarders = new address[](1);
//     rewarders[0] = address(hlpStaking);
//     vm.startPrank(hlpStaking.owner());
//     hlpStaking.addRewarders(rewarders);
//     vm.stopPrank();

//     IERC20ApproveStrategy approveStrat = Deployer.deployERC20ApproveStrategy(
//       address(proxyAdmin),
//       address(vaultStorage)
//     );
//     IDistributeSTIPARBStrategy distributeStrat = Deployer.deployDistributeSTIPARBStrategy(
//       address(proxyAdmin),
//       address(vaultStorage),
//       address(arbRewarderForHlp),
//       address(arb),
//       500, // 5% dev fee
//       0x6a5D2BF8ba767f7763cd342Cb62C5076f9924872,
//       address(approveStrat)
//     );

//     approveStrat.setWhitelistedExecutor(address(distributeStrat), true);
//     distributeStrat.setWhitelistedExecutor(address(this), true);

//     vm.startPrank(vaultStorage.owner());
//     vaultStorage.setStrategyAllowance(address(arb), address(approveStrat), address(arb));
//     vaultStorage.setStrategyFunctionSigAllowance(
//       address(arb),
//       address(approveStrat),
//       IERC20Upgradeable.approve.selector
//     );
//     vaultStorage.setStrategyAllowance(address(arb), address(distributeStrat), address(arbRewarderForHlp));
//     vaultStorage.setStrategyFunctionSigAllowance(
//       address(arb),
//       address(distributeStrat),
//       IRewarder.feedWithExpiredAt.selector
//     );
//     vaultStorage.setServiceExecutors(address(distributeStrat), true);
//     vm.stopPrank();

//     uint256 aumBefore = calculator.getAUME30(false);

//     // console2.log(abi.encodeWithSignature("IBotHandler_UnauthorizedSender()"));
//     distributeStrat.execute(30289413075306806328952, block.timestamp + 7 days);

//     // distributedAmount = (30289413075306806328952 * (10000 - 500)) / 10000
//     // distributedAmount = 28774942421541466012505
//     assertEq(arb.balanceOf(address(arbRewarderForHlp)), 28774942421541466012505);

//     assertEq(aumBefore, calculator.getAUME30(false));
//   }
// }
