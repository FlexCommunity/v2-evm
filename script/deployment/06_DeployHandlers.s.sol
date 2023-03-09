// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/utils/ConfigJsonRepo.s.sol";

import { Calculator } from "@hmx/contracts/Calculator.sol";
import { FeeCalculator } from "@hmx/contracts/FeeCalculator.sol";

contract DeployStorages is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address oracleMiddlewareAddress = getJsonAddress(".oracle.middleware");
    address vaultStorageAddress = getJsonAddress(".storages.vault");
    address perpStorageAddress = getJsonAddress(".storages.perp");
    address configStorageAddress = getJsonAddress(".storages.config");

    address calculatorAddress = address(
      new Calculator(oracleMiddlewareAddress, vaultStorageAddress, perpStorageAddress, configStorageAddress)
    );
    address feeCalculatorAddress = address(new FeeCalculator(vaultStorageAddress, configStorageAddress));

    vm.stopBroadcast();

    updateJson(".calculator", calculatorAddress);
    updateJson(".feeCalculator", feeCalculatorAddress);
  }
}
