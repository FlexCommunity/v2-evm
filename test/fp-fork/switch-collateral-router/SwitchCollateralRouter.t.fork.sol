// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Forge
import { TestBase } from "forge-std/Base.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { console2 } from "forge-std/console2.sol";
import { console } from "forge-std/console.sol";
import { stdJson } from "forge-std/StdJson.sol";

/// HMX tests
import { DynamicForkBaseTest } from "@hmx-test/fp-fork/bases/DynamicForkBaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

/// HMX
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IExt01Handler } from "@hmx/handlers/interfaces/IExt01Handler.sol";
import { SwitchCollateralRouter } from "@hmx/extensions/switch-collateral/SwitchCollateralRouter.sol";
import { UniswapDexter } from "@hmx/extensions/dexters/UniswapDexter.sol";
import { AerodromeDexter } from "@hmx/extensions/dexters/AerodromeDexter.sol";
import { IRouter } from "@hmx/interfaces/aerodrome/IRouter.sol";
import { ICrossMarginHandler02 } from "@hmx/handlers/interfaces/ICrossMarginHandler02.sol";
import { MockAccountAbstraction } from "../../mocks/MockAccountAbstraction.sol";
import { MockEntryPoint } from "../../mocks/MockEntryPoint.sol";

contract SwitchCollateralRouter_ForkTest is DynamicForkBaseTest {
  uint256 constant V3_SWAP_EXACT_IN = 0x00;

  address internal constant EXT01_EXECUTOR = 0x7FDD623c90a0097465170EdD352Be27A9f3ad817;
  address internal constant USER = 0x10C69D9d8AE54FD1Ab12A4beC82c2695b977bcEC;
  uint8 internal constant SUB_ACCOUNT_ID = 0;

  IExt01Handler internal ext01Handler;
  SwitchCollateralRouter internal _switchCollateralRouter;
  UniswapDexter internal _uniswapDexter;
  AerodromeDexter internal aerodromeDexter;

  MockEntryPoint internal entryPoint;

  ICrossMarginHandler02 internal crossMarginHandler02;

  uint256 internal constant executionOrderFee = 0.1 * 1e9;

  function setUp() public override {
    super.setUp();
    if (!isForkSupported) return;

    vm.startPrank(DynamicForkBaseTest.multiSig);
    Deployer.upgrade("ConfigStorage", address(DynamicForkBaseTest.proxyAdmin), address(DynamicForkBaseTest.configStorage));
    Deployer.upgrade("CrossMarginService", address(DynamicForkBaseTest.proxyAdmin), address(DynamicForkBaseTest.crossMarginService));
    vm.stopPrank();

    vm.startPrank(DynamicForkBaseTest.deployer);
    // Add DAI as collateral
    DynamicForkBaseTest.configStorage.setAssetConfig(
      "DAI",
      IConfigStorage.AssetConfig({
        assetId: "DAI",
        tokenAddress: address(DynamicForkBaseTest.dai),
        decimals: 18,
        isStableCoin: false
      })
    );
    DynamicForkBaseTest.configStorage.setCollateralTokenConfig(
      "DAI",
      IConfigStorage.CollateralTokenConfig({
        collateralFactorBPS: 0.6 * 100_00,
        accepted: true,
        settleStrategy: address(0)
      })
    );
    // Add wstETH as collateral
    DynamicForkBaseTest.ecoPyth2.insertAssetId("wstETH");
    DynamicForkBaseTest.pythAdapter.setConfig("wstETH", "wstETH", false);
    DynamicForkBaseTest.oracleMiddleware.setAssetPriceConfig("wstETH", 0, 60 * 5, address(DynamicForkBaseTest.pythAdapter));
    DynamicForkBaseTest.configStorage.setAssetConfig(
      "wstETH",
      IConfigStorage.AssetConfig({
        assetId: "wstETH",
        tokenAddress: address(DynamicForkBaseTest.wstEth),
        decimals: 18,
        isStableCoin: false
      })
    );
    DynamicForkBaseTest.configStorage.setCollateralTokenConfig(
      "wstETH",
      IConfigStorage.CollateralTokenConfig({
        collateralFactorBPS: 0.8 * 100_00,
        accepted: true,
        settleStrategy: address(0)
      })
    );
    // Deploy UniswapDexter
    _uniswapDexter = UniswapDexter(
      address(Deployer.deployUniswapDexter(address(DynamicForkBaseTest.uniswapPermit2), address(DynamicForkBaseTest.uniswapUniversalRouter)))
    );
    _uniswapDexter.setPathOf(
      address(DynamicForkBaseTest.dai),
      address(DynamicForkBaseTest.weth),
      abi.encodePacked(DynamicForkBaseTest.dai, uint24(500), DynamicForkBaseTest.weth)
    );
    _uniswapDexter.setPathOf(
      address(DynamicForkBaseTest.weth),
      address(DynamicForkBaseTest.dai),
      abi.encodePacked(DynamicForkBaseTest.weth, uint24(500), DynamicForkBaseTest.dai)
    );
    // Deploy AerodromeDexter
    aerodromeDexter = AerodromeDexter(
      address(
        Deployer.deployAerodromeDexter(DynamicForkBaseTest.aerodromeRouter)
      )
    );
    IRouter.Route[] memory route = new IRouter.Route[](2);
    route[0] = IRouter.Route(
      address(DynamicForkBaseTest.wbtc),
      address(DynamicForkBaseTest.weth),
      false,
      DynamicForkBaseTest.aerodromePoolFactory
    );
    route[1] = IRouter.Route(
      address(DynamicForkBaseTest.weth),
      address(DynamicForkBaseTest.dai),
      false,
      DynamicForkBaseTest.aerodromePoolFactory
    );
    aerodromeDexter.setRouteOf(
      address(DynamicForkBaseTest.wbtc),
      address(DynamicForkBaseTest.dai),
      route
    );

    IRouter.Route[] memory route1 = new IRouter.Route[](1);
    route1[0] = IRouter.Route(
      address(DynamicForkBaseTest.wbtc),
      address(DynamicForkBaseTest.weth),
      false,
      DynamicForkBaseTest.aerodromePoolFactory
    );
    aerodromeDexter.setRouteOf(
      address(DynamicForkBaseTest.wbtc),
      address(DynamicForkBaseTest.weth),
      route1
    );

    IRouter.Route[] memory route2 = new IRouter.Route[](1);
    route2[0] = IRouter.Route(
      address(DynamicForkBaseTest.weth),
      address(DynamicForkBaseTest.dai),
      false,
      DynamicForkBaseTest.aerodromePoolFactory
    );
    aerodromeDexter.setRouteOf(
      address(DynamicForkBaseTest.weth),
      address(DynamicForkBaseTest.dai),
      route2
    );


    IRouter.Route[] memory route3 = new IRouter.Route[](1);
    route3[0] = IRouter.Route(
      address(DynamicForkBaseTest.weth),
      address(DynamicForkBaseTest.usdc),
      false,
      DynamicForkBaseTest.aerodromePoolFactory
    );
    aerodromeDexter.setRouteOf(
      address(DynamicForkBaseTest.weth),
      address(DynamicForkBaseTest.usdc),
      route3
    );
    // Deploy SwitchCollateralRouter
    _switchCollateralRouter = SwitchCollateralRouter(address(Deployer.deploySwitchCollateralRouter()));
    // Deploy Ext01Handler
    ext01Handler = Deployer.deployExt01Handler(
      address(DynamicForkBaseTest.proxyAdmin),
      address(DynamicForkBaseTest.crossMarginService),
      address(DynamicForkBaseTest.liquidationService),
      address(DynamicForkBaseTest.liquidityService),
      address(DynamicForkBaseTest.tradeService),
      address(DynamicForkBaseTest.ecoPyth2)
    );
    // Deploy CrossMarginHandler02
    crossMarginHandler02 = Deployer.deployCrossMarginHandler02(
      address(DynamicForkBaseTest.proxyAdmin),
      address(DynamicForkBaseTest.crossMarginService),
      address(DynamicForkBaseTest.ecoPyth2),
      executionOrderFee
    );
    DynamicForkBaseTest.configStorage.setServiceExecutor(address(DynamicForkBaseTest.crossMarginService), address(crossMarginHandler02), true);
    crossMarginHandler02.setOrderExecutor(address(this), true);
    // Settings
    ext01Handler.setOrderExecutor(EXT01_EXECUTOR, true);
    ext01Handler.setMinExecutionFee(1, uint128(executionOrderFee));
    DynamicForkBaseTest.ecoPyth2.setUpdater(address(ext01Handler), true);
    address[] memory _handlers = new address[](1);
    _handlers[0] = address(ext01Handler);
    address[] memory _services = new address[](1);
    _services[0] = address(DynamicForkBaseTest.crossMarginService);
    bool[] memory _isAllows = new bool[](1);
    _isAllows[0] = true;
    DynamicForkBaseTest.configStorage.setServiceExecutors(_services, _handlers, _isAllows);
    DynamicForkBaseTest.configStorage.setSwitchCollateralRouter(address(_switchCollateralRouter));
    // _switchCollateralRouter.setDexterOf(address(DynamicForkBaseTest.sglp), address(DynamicForkBaseTest.weth), address(glpDexter));
    // _switchCollateralRouter.setDexterOf(address(DynamicForkBaseTest.weth), address(DynamicForkBaseTest.sglp), address(glpDexter));
    _switchCollateralRouter.setDexterOf(address(DynamicForkBaseTest.dai), address(DynamicForkBaseTest.weth), address(_uniswapDexter));
    _switchCollateralRouter.setDexterOf(address(DynamicForkBaseTest.weth), address(DynamicForkBaseTest.dai), address(_uniswapDexter));
    // _switchCollateralRouter.setDexterOf(address(DynamicForkBaseTest.weth), address(DynamicForkBaseTest.wstEth), address(curveDexter));
    // _switchCollateralRouter.setDexterOf(address(DynamicForkBaseTest.wstEth), address(DynamicForkBaseTest.weth), address(curveDexter));
    _switchCollateralRouter.setDexterOf(address(DynamicForkBaseTest.wbtc), address(DynamicForkBaseTest.dai), address(aerodromeDexter));
    _switchCollateralRouter.setDexterOf(address(DynamicForkBaseTest.wbtc), address(DynamicForkBaseTest.weth), address(aerodromeDexter));
    _switchCollateralRouter.setDexterOf(address(DynamicForkBaseTest.weth), address(DynamicForkBaseTest.dai), address(aerodromeDexter));
    _switchCollateralRouter.setDexterOf(address(DynamicForkBaseTest.weth), address(DynamicForkBaseTest.usdc), address(aerodromeDexter));
    vm.stopPrank();

    entryPoint = new MockEntryPoint();

    // Mock gas for handler used for update Pyth's prices
    vm.deal(address(crossMarginHandler02), 1 ether);

    vm.deal(USER, 10 ether);

    // Deposit Collateral
    vm.startPrank(USER);
    deal(address(wbtc), USER, (10 ** 6));
    wbtc.approve(address(crossMarginHandler), type(uint256).max);
    crossMarginHandler.depositCollateral(
      SUB_ACCOUNT_ID,
      address(wbtc),
      (10 ** 6),
      false
    );

    deal(address(usdc), USER, 10000 * (10 ** 6));
    usdc.approve(address(crossMarginHandler), type(uint256).max);
    crossMarginHandler.depositCollateral(
      SUB_ACCOUNT_ID,
      address(usdc),
      10000 * (10 ** 6),
      false
    );
    vm.stopPrank();

    vm.label(address(ext01Handler), "ext01Handler");
    vm.label(address(DynamicForkBaseTest.crossMarginService), "crossMarginService");
  }

  function testRevert_WhenFromTokenNotCollateral()  external onlyFork {
    vm.startPrank(USER);
    address[] memory _path = new address[](2);
    _path[0] = address(DynamicForkBaseTest.hlp);
    _path[1] = address(DynamicForkBaseTest.dai);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedCollateral()"));
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        mainAccount: USER,
        subAccountId: SUB_ACCOUNT_ID,
        data: abi.encode(0, 79115385, _path, 41433673370671066)
      })
    );
    vm.stopPrank();
  }

  function testRevert_WhenToTokenNotCollateral()  external onlyFork {
    vm.startPrank(USER);
    address[] memory _path = new address[](2);
    _path[0] = address(DynamicForkBaseTest.wbtc);
    _path[1] = address(DynamicForkBaseTest.hlp);
    vm.expectRevert(abi.encodeWithSignature("IConfigStorage_NotAcceptedCollateral()"));
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        mainAccount: USER,
        subAccountId: SUB_ACCOUNT_ID,
        data: abi.encode(0, 79115385, _path, 41433673370671066)
      })
    );
    vm.stopPrank();
  }

  function testRevert_WhenFromAndToTokenAreSame()  external onlyFork {
    vm.startPrank(USER);
    address[] memory _path = new address[](2);
    _path[0] = address(DynamicForkBaseTest.wbtc);
    _path[1] = address(DynamicForkBaseTest.wbtc);
    vm.expectRevert(abi.encodeWithSignature("IExt01Handler_SameFromToToken()"));
    ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        mainAccount: USER,
        subAccountId: SUB_ACCOUNT_ID,
        data: abi.encode(0, 79115385, _path, 41433673370671066)
      })
    );
    vm.stopPrank();
  }

  function testRevert_WhenSlippage()  external onlyFork {
    vm.startPrank(USER);
    address[] memory _path = new address[](2);
    _path[0] = address(DynamicForkBaseTest.dai);
    _path[1] = address(DynamicForkBaseTest.weth);
    uint256 _orderIndex = ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        mainAccount: USER,
        subAccountId: SUB_ACCOUNT_ID,
        data: abi.encode(SUB_ACCOUNT_ID, 1000000, _path, 2652487522183761)
      })
    );
    vm.stopPrank();

    vm.startPrank(EXT01_EXECUTOR);
    // but change ETH to tick 0 which equals to 1 USD.
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    address[] memory accounts = new address[](1);
    accounts[0] = USER;
    uint8[] memory subAccountIds = new uint8[](1);
    subAccountIds[0] = SUB_ACCOUNT_ID;
    uint256[] memory orderIndexes = new uint256[](1);
    orderIndexes[0] = _orderIndex;
    vm.expectRevert();
    ext01Handler.executeOrders(
      accounts,
      subAccountIds,
      orderIndexes,
      payable(EXT01_EXECUTOR),
      _priceData,
      _publishTimeData,
      block.timestamp,
      "",
      true
    );
    vm.stopPrank();
    // order has not been executed, still in the active.
    assertEq(ext01Handler.getAllActiveOrders(10, 0).length, 1);
    assertEq(ext01Handler.getAllExecutedOrders(10, 0).length, 0);

    // Trader balance should be the same
    assertEq(DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.wbtc)), 1000000);
  }

  function testRevert_WhenSwitchCollateralMakesEquityBelowIMR()  external onlyFork {
    vm.startPrank(USER);
    address[] memory _path = new address[](2);
    _path[0] = address(DynamicForkBaseTest.dai);
    _path[1] = address(DynamicForkBaseTest.weth);
    uint256 _orderIndex = ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        mainAccount: USER,
        subAccountId: SUB_ACCOUNT_ID,
        data: abi.encode(SUB_ACCOUNT_ID, 1000000, _path, 0)
      })
    );
    vm.stopPrank();

    vm.startPrank(EXT01_EXECUTOR);
    // but change ETH to tick 0 which equals to 1 USD.
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0007130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    address[] memory accounts = new address[](1);
    accounts[0] = USER;
    uint8[] memory subAccountIds = new uint8[](1);
    subAccountIds[0] = SUB_ACCOUNT_ID;
    uint256[] memory orderIndexes = new uint256[](1);
    orderIndexes[0] = _orderIndex;
    vm.expectRevert();
    ext01Handler.executeOrders(
      accounts,
      subAccountIds,
      orderIndexes,
      payable(EXT01_EXECUTOR),
      _priceData,
      _publishTimeData,
      block.timestamp,
      "",
      true
    );
    vm.stopPrank();

    assertEq(ext01Handler.getAllActiveOrders(10, 0).length, 1);
    assertEq(ext01Handler.getAllExecutedOrders(10, 0).length, 0);

    // Trader balance should be the same
    assertEq(DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.wbtc)), 1000000);
  }

//   function testCorrectness_WhenSwitchCollateralFromsglpToBareErc20()  external onlyFork {
//     vm.startPrank(USER);
//     // Create switch collateral order from sglp -> DAI
//     address[] memory _path = new address[](3);
//     _path[0] = address(DynamicForkBaseTest.sglp);
//     _path[1] = address(DynamicForkBaseTest.weth);
//     _path[2] = address(DynamicForkBaseTest.dai);
//     uint256 _orderIndex = ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
//       IExt01Handler.CreateExtOrderParams({
//         orderType: 1,
//         executionFee: 0.1 * 1e9,
//         mainAccount: USER,
//         subAccountId: SUB_ACCOUNT_ID,
//         data: abi.encode(SUB_ACCOUNT_ID, DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.sglp)), _path, 0)
//       })
//     );
//     vm.stopPrank();

//     assertEq(ext01Handler.getAllActiveOrders(10, 0).length, 1);

//     vm.startPrank(EXT01_EXECUTOR);
//     // Taken price data from https://arbiscan.io/tx/0x2a1bea44f6b1858aef7661b19cec49a4d74e3c9fd1fedb7ab26b09ac712cc0ad
//     uint256 _daiBefore = DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.dai));
//     bytes32[] memory _priceData = new bytes32[](3);
//     _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
//     _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
//     _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
//     bytes32[] memory _publishTimeData = new bytes32[](3);
//     _publishTimeData[0] = bytes32(0);
//     _publishTimeData[1] = bytes32(0);
//     _publishTimeData[2] = bytes32(0);
//     address[] memory accounts = new address[](1);
//     accounts[0] = USER;
//     uint8[] memory subAccountIds = new uint8[](1);
//     subAccountIds[0] = SUB_ACCOUNT_ID;
//     uint256[] memory orderIndexes = new uint256[](1);
//     orderIndexes[0] = _orderIndex;

//     uint48 expectExecutedTime = uint48(block.timestamp);

//     ext01Handler.executeOrders(
//       accounts,
//       subAccountIds,
//       orderIndexes,
//       payable(EXT01_EXECUTOR),
//       _priceData,
//       _publishTimeData,
//       block.timestamp,
//       "",
//       false
//     );
//     vm.stopPrank();

//     uint256 _daiAfter = DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.dai));
//     IExt01Handler.GenericOrder[] memory orders = ext01Handler.getAllExecutedOrders(10, 0);

//     assertEq(orders[0].executedTimestamp, expectExecutedTime);
//     assertEq(ext01Handler.getAllActiveOrders(10, 0).length, 0);
//     assertEq(ext01Handler.getAllExecutedOrders(10, 0).length, 1);
//     // Trader balance should be the same
//     assertEq(DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.sglp)), 0);
//     assertEq(_daiAfter - _daiBefore, 3970232321595248857);
//   }

//   function testCorrectness_WhenSwitchCollateralFromBareErc20Tosglp()  external onlyFork {
//     // Motherload DAI for USER
//     motherload(address(DynamicForkBaseTest.dai), USER, 1000 * 1e18);

//     vm.startPrank(USER);
//     // Deposit DAI to the cross margin account
//     DynamicForkBaseTest.dai.approve(address(DynamicForkBaseTest.crossMarginHandler), 1000 * 1e18);
//     DynamicForkBaseTest.crossMarginHandler.depositCollateral(SUB_ACCOUNT_ID, address(DynamicForkBaseTest.dai), 1000 * 1e18, false);
//     // Create switch collateral order from DAI -> sglp
//     address[] memory _path = new address[](3);
//     _path[0] = address(DynamicForkBaseTest.dai);
//     _path[1] = address(DynamicForkBaseTest.weth);
//     _path[2] = address(DynamicForkBaseTest.sglp);
//     uint256 _orderIndex = ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
//       IExt01Handler.CreateExtOrderParams({
//         orderType: 1,
//         executionFee: 0.1 * 1e9,
//         mainAccount: USER,
//         subAccountId: SUB_ACCOUNT_ID,
//         data: abi.encode(SUB_ACCOUNT_ID, DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.dai)), _path, 0)
//       })
//     );
//     vm.stopPrank();

//     vm.startPrank(EXT01_EXECUTOR);
//     // Taken price data from https://arbiscan.io/tx/0x2a1bea44f6b1858aef7661b19cec49a4d74e3c9fd1fedb7ab26b09ac712cc0ad
//     uint256 _sglpBefore = DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.sglp));
//     bytes32[] memory _priceData = new bytes32[](3);
//     _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
//     _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
//     _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f720000000000000000000000000000;
//     bytes32[] memory _publishTimeData = new bytes32[](3);
//     _publishTimeData[0] = bytes32(0);
//     _publishTimeData[1] = bytes32(0);
//     _publishTimeData[2] = bytes32(0);
//     address[] memory accounts = new address[](1);
//     accounts[0] = USER;
//     uint8[] memory subAccountIds = new uint8[](1);
//     subAccountIds[0] = SUB_ACCOUNT_ID;
//     uint256[] memory orderIndexes = new uint256[](1);
//     orderIndexes[0] = _orderIndex;
//     uint48 expectExecutedTime = uint48(block.timestamp);

//     ext01Handler.executeOrders(
//       accounts,
//       subAccountIds,
//       orderIndexes,
//       payable(EXT01_EXECUTOR),
//       _priceData,
//       _publishTimeData,
//       block.timestamp,
//       "",
//       false
//     );
//     vm.stopPrank();
//     uint256 _sglpAfter = DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.sglp));
//     IExt01Handler.GenericOrder[] memory orders = ext01Handler.getAllExecutedOrders(10, 0);

//     assertEq(orders[0].executedTimestamp, expectExecutedTime);
//     assertEq(ext01Handler.getAllActiveOrders(10, 0).length, 0);
//     assertEq(ext01Handler.getAllExecutedOrders(10, 0).length, 1);

//     // Trader balance should be the same
//     assertEq(DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.dai)), 0);
//     assertEq(_sglpAfter - _sglpBefore, 1251816487838549309485);
//   }

  function testCorrectness_WhenSwitchCollateralFromWbtcToUsdc()  external onlyFork {
    vm.startPrank(USER);
    // Create switch collateral order from wbtc -> usdc
    address[] memory _path = new address[](3);
    _path[0] = address(DynamicForkBaseTest.wbtc);
    _path[1] = address(DynamicForkBaseTest.weth);
    _path[2] = address(DynamicForkBaseTest.usdc);
    uint256 _orderIndex = ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        mainAccount: USER,
        subAccountId: SUB_ACCOUNT_ID,
        data: abi.encode(SUB_ACCOUNT_ID, DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.wbtc)), _path, 0)
      })
    );
    vm.stopPrank();

    vm.startPrank(EXT01_EXECUTOR);
    // Add 012bb4 => 76724 tick for DAI price
    uint256 _usdcBefore = DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.usdc));
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f72012bb40000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    address[] memory accounts = new address[](1);
    accounts[0] = USER;
    uint8[] memory subAccountIds = new uint8[](1);
    subAccountIds[0] = SUB_ACCOUNT_ID;
    uint256[] memory orderIndexes = new uint256[](1);
    orderIndexes[0] = _orderIndex;
    uint48 expectExecutedTime = uint48(block.timestamp);
    ext01Handler.executeOrders(
      accounts,
      subAccountIds,
      orderIndexes,
      payable(EXT01_EXECUTOR),
      _priceData,
      _publishTimeData,
      block.timestamp,
      "",
      false
    );
    vm.stopPrank();
    uint256 _usdcAfter = DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.usdc));
    IExt01Handler.GenericOrder[] memory orders = ext01Handler.getAllExecutedOrders(10, 0);

    assertEq(orders[0].executedTimestamp, expectExecutedTime);
    assertEq(ext01Handler.getAllActiveOrders(10, 0).length, 0);
    assertEq(ext01Handler.getAllExecutedOrders(10, 0).length, 1);

    assertEq(DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.wbtc)), 0);
    // assertEq(_usdcAfter - _usdcBefore, 1004842469);
    assertGt(_usdcAfter, _usdcBefore);
  }

  function testCorrectness_ExecuteViaDelegate()  external onlyFork {
    // Motherload wbtc for USER
    motherload(address(DynamicForkBaseTest.wbtc), USER, 10 * 1e18);

    MockAccountAbstraction DELEGATE = new MockAccountAbstraction(address(entryPoint));
    vm.deal(address(DELEGATE), 0.1 * 1e9);

    vm.startPrank(USER);
    ext01Handler.setDelegate(address(DELEGATE));
    crossMarginHandler02.setDelegate(address(DELEGATE));
    DynamicForkBaseTest.wbtc.approve(address(crossMarginHandler02), 10 * 1e18);
    vm.stopPrank();
    // Deposit wbtc to the cross margin account
    vm.startPrank(address(DELEGATE));
    crossMarginHandler02.depositCollateral(USER, SUB_ACCOUNT_ID, address(DynamicForkBaseTest.wbtc), 10 * 1e18, false);
    address[] memory _path = new address[](3);
    _path[0] = address(DynamicForkBaseTest.wbtc);
    _path[1] = address(DynamicForkBaseTest.weth);
    _path[2] = address(DynamicForkBaseTest.usdc);
    uint256 _orderIndex = ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        mainAccount: USER,
        subAccountId: SUB_ACCOUNT_ID,
        data: abi.encode(SUB_ACCOUNT_ID, DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.wbtc)), _path, 0)
      })
    );
    vm.stopPrank();

    vm.startPrank(EXT01_EXECUTOR);
    uint256 _usdcBefore = DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.usdc));
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f72012bb40000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    address[] memory accounts = new address[](1);
    accounts[0] = USER;
    uint8[] memory subAccountIds = new uint8[](1);
    subAccountIds[0] = SUB_ACCOUNT_ID;
    uint256[] memory orderIndexes = new uint256[](1);
    orderIndexes[0] = _orderIndex;
    uint48 expectExecutedTime = uint48(block.timestamp);
    ext01Handler.executeOrders(
      accounts,
      subAccountIds,
      orderIndexes,
      payable(EXT01_EXECUTOR),
      _priceData,
      _publishTimeData,
      block.timestamp,
      "",
      false
    );
    vm.stopPrank();
    uint256 _usdcAfter = DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.usdc));
    IExt01Handler.GenericOrder[] memory orders = ext01Handler.getAllExecutedOrders(10, 0);

    assertEq(orders[0].executedTimestamp, expectExecutedTime);
    assertEq(ext01Handler.getAllActiveOrders(10, 0).length, 0);
    assertEq(ext01Handler.getAllExecutedOrders(10, 0).length, 1);

    assertEq(DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.wbtc)), 0);
    // assertEq(_usdcAfter - _usdcBefore, 78527217122);
    assertGt(_usdcAfter, _usdcBefore);
  }

  function testCorrectness_CancelSwitchCollateralOrder()  external onlyFork {
    // Create switch collateral order from wbtc -> usdc
    address[] memory _path = new address[](3);
    _path[0] = address(DynamicForkBaseTest.wbtc);
    _path[1] = address(DynamicForkBaseTest.weth);
    _path[2] = address(DynamicForkBaseTest.usdc);
    vm.startPrank(USER);
    uint256 _orderIndex = ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        mainAccount: USER,
        subAccountId: SUB_ACCOUNT_ID,
        data: abi.encode(SUB_ACCOUNT_ID, DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.wbtc)), _path, 0)
      })
    );
    vm.stopPrank();

    assertEq(ext01Handler.getAllActiveOrders(3, 0).length, 1);
    // cancel order, should have 0 active, 0 execute.
    uint256 balanceBefore = USER.balance;

    vm.prank(USER);
    ext01Handler.cancelOrder(USER, SUB_ACCOUNT_ID, _orderIndex);

    assertEq(USER.balance - balanceBefore, 0.1 * 1e9);
    assertEq(ext01Handler.getAllActiveOrders(3, 0).length, 0);
    assertEq(ext01Handler.getAllExecutedOrders(3, 0).length, 0);
  }

  function testRevert_ExecuteCanceledOrder()  external onlyFork {
    vm.startPrank(USER);
    // Create switch collateral order from wbtc -> usdc
    address[] memory _path = new address[](3);
    _path[0] = address(DynamicForkBaseTest.wbtc);
    _path[1] = address(DynamicForkBaseTest.weth);
    _path[2] = address(DynamicForkBaseTest.usdc);
    uint256 _orderIndex = ext01Handler.createExtOrder{ value: 0.1 * 1e9 }(
      IExt01Handler.CreateExtOrderParams({
        orderType: 1,
        executionFee: 0.1 * 1e9,
        mainAccount: USER,
        subAccountId: SUB_ACCOUNT_ID,
        data: abi.encode(SUB_ACCOUNT_ID, DynamicForkBaseTest.vaultStorage.traderBalances(USER, address(DynamicForkBaseTest.wbtc)), _path, 0)
      })
    );
    vm.stopPrank();

    vm.prank(USER);
    ext01Handler.cancelOrder(USER, SUB_ACCOUNT_ID, _orderIndex);

    vm.startPrank(EXT01_EXECUTOR);
    // Taken price data from https://arbiscan.io/tx/0x2a1bea44f6b1858aef7661b19cec49a4d74e3c9fd1fedb7ab26b09ac712cc0ad
    // Add 012bb4 => 76724 tick for wstETH price
    bytes32[] memory _priceData = new bytes32[](3);
    _priceData[0] = 0x0127130192adfffffe000001ffffff00cdac00c0fd01288100bef300e5df0000;
    _priceData[1] = 0x00ddd500048e007ddd000094fff0c8000a18ffd2e7fff436fff3560008be0000;
    _priceData[2] = 0x000f9e00b0e500b5af00bc5300d656007f72012bb40000000000000000000000;
    bytes32[] memory _publishTimeData = new bytes32[](3);
    _publishTimeData[0] = bytes32(0);
    _publishTimeData[1] = bytes32(0);
    _publishTimeData[2] = bytes32(0);
    address[] memory accounts = new address[](1);
    accounts[0] = USER;
    uint8[] memory subAccountIds = new uint8[](1);
    subAccountIds[0] = SUB_ACCOUNT_ID;
    uint256[] memory orderIndexes = new uint256[](1);
    orderIndexes[0] = _orderIndex;

    vm.expectRevert(abi.encodeWithSignature("IExt01Handler_NonExistentOrder()"));
    ext01Handler.executeOrders(
      accounts,
      subAccountIds,
      orderIndexes,
      payable(EXT01_EXECUTOR),
      _priceData,
      _publishTimeData,
      block.timestamp,
      "",
      false
    );
    vm.stopPrank();
  }
}
