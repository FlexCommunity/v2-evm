// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Test } from "lib/forge-std/src/Test.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeTransferLib } from "lib/solmate/src/utils/SafeTransferLib.sol";

import { IERC20Rebasing, YieldMode } from "src/interfaces/blast/IERC20Rebasing.sol";

/// @title MockErc20Rebasing - Mock contract for ERC20 rebasing contract. Testing only.
/// @dev On Blast, MockWethRebasing is also WETH.
contract MockErc20Rebasing is ERC20, IERC20Rebasing, Test {
  using SafeTransferLib for address;

  YieldMode public yieldMode;
  uint256 public nextYield;

  constructor() ERC20("ERC20r", "ERC20r") {}

  function configure(YieldMode _yieldMode) external override returns (uint256) {
    yieldMode = _yieldMode;
    return 1;
  }

  function setNextYield(uint256 _yield) external {
    nextYield = _yield;
  }

  function getClaimableAmount(address) external view override returns (uint256) {
    return nextYield;
  }

  function claim(address _to, uint256 _amount) external override returns (uint256) {
    require(_amount <= nextYield, "not enough yield");
    uint256 _yield = nextYield;
    nextYield = 0;
    // In case of WETH, we need to mint ETH to WETH so that the contract has enough balance to transfer.
    vm.deal(address(this), address(this).balance + _yield);
    _mint(_to, _yield);
    return _yield;
  }

  function mint(address _to, uint256 _amount) external {
    _mint(_to, _amount);
  }

  /// @notice WETH compatible deposit function.
  function deposit() external payable {
    _mint(msg.sender, msg.value);
  }

  /// @notice WETH compatible withdraw function.
  function withdraw(uint256 _amount) external {
    _burn(msg.sender, _amount);
    msg.sender.safeTransferETH(_amount);
  }

  /// @notice WETH compatible deposit via fallback function.
  receive() external payable {
    _mint(msg.sender, msg.value);
  }
}
