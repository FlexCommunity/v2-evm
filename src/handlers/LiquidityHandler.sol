// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// interfaces
import { ILiquidityHandler } from "./interfaces/ILiquidityHandler.sol";
import { ILiquidityService } from "../services/interfaces/ILiquidityService.sol";
import { IConfigStorage } from "../storages/interfaces/IConfigStorage.sol";
import { IVaultStorage } from "../storages/interfaces/IVaultStorage.sol";
import { IPerpStorage } from "../storages/interfaces/IPerpStorage.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ICalculator } from "../contracts/interfaces/ICalculator.sol";
import { PLPv2 } from "../contracts/PLPv2.sol";
import { IOracleMiddleware } from "../oracle/interfaces/IOracleMiddleware.sol";
import { AddressUtils } from "../libraries/AddressUtils.sol";
import { IWNative } from "../interfaces/IWNative.sol";
import { IPyth } from "../../lib/pyth-sdk-solidity/IPyth.sol";
import { console } from "../../lib/forge-std/src/console.sol";

import { Owned } from "../base/Owned.sol";

/// @title LiquidityService
contract LiquidityHandler is Owned, ILiquidityHandler {
  event LogSetLiquidityService(address oldValue, address newValue);
  event LogSetMinExecutionFee(uint256 oldValue, uint256 newValue);
  event LogSetOrderExecutor(address executor, bool isAllow);
  event CreateAddLiquidityOrder(
    address indexed account,
    address token,
    uint256 amountIn,
    uint256 minOut,
    uint256 executionFee
  );
  event CreateRemoveLiquidityOrder(
    address indexed account,
    address token,
    uint256 amountIn,
    uint256 minOut,
    uint256 executionFee
  );
  event ExecuteLiquidityOrder(
    address payable account,
    address token,
    uint256 amount,
    uint256 minOut,
    bool isAdd,
    uint256 actualOut
  );
  event CancelOrder(address payable account, address token, uint256 amount, uint256 minOut, bool isAdd);

  mapping(address => LiquidityOrder[]) public liquidityOrders; // user address => all liquidityOrder
  mapping(address => bool) public orderExecutors;

  address public weth;
  address liquidityService;
  address pyth;

  uint256 public minExecutionFee;

  constructor(address _weth, address _liquidityService, address _pyth, uint256 _minExecutionFee) {
    weth = _weth;
    liquidityService = _liquidityService;
    pyth = _pyth;
    minExecutionFee = _minExecutionFee;
  }

  receive() external payable {
    if (msg.sender != weth) revert ILiquidityHandler_InvalidSender();
  }

  /**
   * MODIFIER
   */

  modifier onlyAcceptedToken(address _token) {
    IConfigStorage(ILiquidityService(liquidityService).configStorage()).validateAcceptedLiquidityToken(_token);
    _;
  }

  // Only whitelisted addresses can be able to execute limit orders
  modifier onlyOrderExecutor() {
    if (!orderExecutors[msg.sender]) revert ILiquidityHandler_NotWhitelisted();
    _;
  }

  /**
   * GETTER
   */

  function getLiquidityOrders(address _account) external view returns (LiquidityOrder[] memory) {
    return liquidityOrders[_account];
  }

  /**
   * SETTER
   */
  function setLiquidityService(address _newLiquidityService) external onlyOwner {
    if (_newLiquidityService == address(0)) revert ILiquidityHandler_InvalidAddress();
    emit LogSetLiquidityService(liquidityService, _newLiquidityService);
    liquidityService = _newLiquidityService;
  }

  function setMinExecutionFee(uint256 _newMinExecutionFee) external onlyOwner {
    emit LogSetMinExecutionFee(minExecutionFee, _newMinExecutionFee);
    minExecutionFee = _newMinExecutionFee;
  }

  function setOrderExecutor(address _executor, bool _isAllow) external onlyOwner {
    orderExecutors[_executor] = _isAllow;
    emit LogSetOrderExecutor(_executor, _isAllow);
  }

  /**
   * Core Function
   */

  function createAddLiquidityOrder(
    address _tokenBuy,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldWrap
  ) external payable {
    console.log("createAddLiquidityOrder_msgsender", msg.sender);
    //1. convert native to WNative (including executionFee)
    _transferInETH();

    if (_executionFee < minExecutionFee) revert ILiquidityHandler_InsufficientExecutionFee();

    if (_shouldWrap) {
      if (msg.value != _amountIn + minExecutionFee) {
        revert ILiquidityHandler_InCorrectValueTransfer();
      }
    } else {
      if (msg.value != minExecutionFee) revert ILiquidityHandler_InCorrectValueTransfer();
      ERC20(_tokenBuy).transferFrom(msg.sender, address(this), _amountIn);
    }

    LiquidityOrder[] storage _orders = liquidityOrders[msg.sender];
    _orders.push(
      LiquidityOrder({
        account: payable(msg.sender),
        token: _tokenBuy,
        amount: _amountIn,
        minOut: _minOut,
        isAdd: true,
        shouldUnwrap: false
      })
    );

    emit CreateAddLiquidityOrder(msg.sender, _tokenBuy, _amountIn, _minOut, _executionFee);
  }

  /// @notice createOrder for removeLiquidity
  function createRemoveLiquidityOrder(
    address _tokenSell,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldUnwrap
  ) external payable onlyAcceptedToken(_tokenSell) {
    //convert native to WNative (including executionFee)
    _transferInETH();

    if (_executionFee < minExecutionFee) revert ILiquidityHandler_InsufficientExecutionFee();

    if (msg.value != minExecutionFee) revert ILiquidityHandler_InCorrectValueTransfer();

    LiquidityOrder[] storage _orders = liquidityOrders[msg.sender];
    _orders.push(
      LiquidityOrder({
        account: payable(msg.sender),
        token: _tokenSell,
        amount: _amountIn,
        minOut: _minOut,
        isAdd: false,
        shouldUnwrap: _shouldUnwrap
      })
    );

    emit CreateRemoveLiquidityOrder(msg.sender, _tokenSell, _amountIn, _minOut, _executionFee);
  }

  /// @notice if user deposit native and failed, it will return to wrappedToken
  function cancelLiquidityOrder(LiquidityOrder[] memory _orders) external {
    for (uint256 i = 0; i < _orders.length; ) {
      LiquidityOrder memory _order = _orders[i];

      if (liquidityOrders[_order.account].length > 0) {
        userRefund(_order);
        emit CancelOrder(payable(_order.account), _order.token, _order.amount, _order.minOut, _order.isAdd);
      }

      unchecked {
        ++i;
      }
    }
  }

  // @todo onlyRefunder
  function userRefund(LiquidityOrder memory _order) internal {
    console.log("userRefund_msg.sender", msg.sender);
    try this.refund(_order) {} catch Error(string memory reason) {
      revert ILiquidityHandler_InsufficientRefund();
    }
  }

  // @todo onlyRefunder
  function refund(LiquidityOrder memory _order) external {
    console.log("refund.sender", msg.sender);
    if (_order.token == weth) {
      _transferOutETHWithGasLimitIgnoreFail(_order.amount, _order.account);
    } else {
      ERC20(_order.token).transfer(_order.account, _order.amount);
    }
  }

  function executeOrders(LiquidityOrder[] memory _orders, bytes[] memory _priceData) external onlyOrderExecutor {
    IPyth(pyth).updatePriceFeeds{ value: IPyth(pyth).getUpdateFee(_priceData) }(_priceData);

    for (uint256 i = 0; i < _orders.length; ) {
      LiquidityOrder memory _order = _orders[i];
      if (liquidityOrders[_order.account].length > 0) {
        try this.executeLiquidity(_order) returns (uint256 result) {
          emit ExecuteLiquidityOrder(_order.account, _order.token, _order.amount, _order.minOut, _order.isAdd, result);
        } catch Error(string memory reason) {
          userRefund(_order);
        }
        delete liquidityOrders[_order.account][0];
      }

      unchecked {
        ++i;
      }
    }
  }

  // @todo try can be used only external need whitelisted
  function executeLiquidity(LiquidityOrder memory _order) external returns (uint256) {
    console.log("executeLiquidity.sender", msg.sender);
    if (_order.isAdd) {
      ERC20(_order.token).transfer(ILiquidityService(liquidityService).vaultStorage(), _order.amount);
      return
        ILiquidityService(liquidityService).addLiquidity(_order.account, _order.token, _order.amount, _order.minOut);
    } else {
      uint256 amountOut = ILiquidityService(liquidityService).removeLiquidity(
        _order.account,
        _order.token,
        _order.amount,
        _order.minOut
      );
      if (_order.shouldUnwrap) {
        _transferOutETHWithGasLimitIgnoreFail(amountOut, payable(_order.account));
      }
    }
  }

  function _transferInETH() private {
    console.log("msg.value__transferInETH", msg.value);
    if (msg.value != 0) {
      IWNative(weth).deposit{ value: msg.value }();
    }
  }

  function _transferOutETHWithGasLimitIgnoreFail(uint256 _amountOut, address payable _receiver) internal {
    IWNative(weth).withdraw(_amountOut);

    // use `send` instead of `transfer` to not revert whole transaction in case ETH transfer was failed
    // it has limit of 2300 gas
    // this is to avoid front-running
    _receiver.send(_amountOut);
  }
}
