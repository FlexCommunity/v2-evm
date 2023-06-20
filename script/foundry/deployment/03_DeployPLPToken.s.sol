// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { ConfigJsonRepo } from "@hmx-script/foundry/utils/ConfigJsonRepo.s.sol";
import { HLP } from "@hmx/contracts/HLP.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

contract DeployHLPToken is ConfigJsonRepo {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address proxyAdmin = getJsonAddress(".proxyAdmin");

    vm.startBroadcast(deployerPrivateKey);

    address hlpAddress = address(Deployer.deployHLP(address(proxyAdmin)));

    vm.stopBroadcast();

    updateJson(".tokens.hlp", hlpAddress);
  }
}
