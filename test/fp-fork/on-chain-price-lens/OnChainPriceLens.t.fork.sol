// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

/// Forge
import { TestBase } from "forge-std/Base.sol";
import { StdCheatsSafe } from "forge-std/StdCheats.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { console2 } from "forge-std/console2.sol";
import { stdJson } from "forge-std/StdJson.sol";

/// HMX tests
import { DynamicForkBaseTest } from "@hmx-test/fp-fork/bases/DynamicForkBaseTest.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";

/// HMX
import { WstEthUsdPriceAdapter } from "@hmx/oracles/adapters/WstEthUsdPriceAdapter.sol";
import { GlpPriceAdapter } from "src/oracles/adapters/GlpPriceAdapter.sol";
import { HlpPriceAdapter } from "src/oracles/adapters/HlpPriceAdapter.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";
import { IPriceAdapter } from "@hmx/oracles/interfaces/IPriceAdapter.sol";
import { OnChainPriceLens } from "@hmx/oracles/OnChainPriceLens.sol";
import { EcoPythCalldataBuilder2 } from "@hmx/oracles/EcoPythCalldataBuilder2.sol";
import { UnsafeEcoPythCalldataBuilder2 } from "@hmx/oracles/UnsafeEcoPythCalldataBuilder2.sol";
import { IEcoPythCalldataBuilder2 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder2.sol";

contract OnChainPriceLens_ForkTest is DynamicForkBaseTest {
  WstEthUsdPriceAdapter internal wstEthUsdPriceAdapter;
  HlpPriceAdapter internal hlpPriceAdapter;
  OnChainPriceLens internal _onChainPriceLens;
  EcoPythCalldataBuilder2 internal ecoPythCalldataBuilder;
  UnsafeEcoPythCalldataBuilder2 internal unsafeEcoPythCalldataBuilder;
  // TODO: These feeds  are for Base mainnet.
  address constant wstEthPriceFeed = 0x43a5C292A453A3bF3606fa856197f09D7B74251a;
  address constant ethUsdPriceFeed = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;

  function setUp() public override {
    // mainnet roll fork
    super.setUp();
    if (!isForkSupported) return;
    
    vm.rollFork(25383400);

    wstEthUsdPriceAdapter = new WstEthUsdPriceAdapter(
      AggregatorV3Interface(wstEthPriceFeed),
      AggregatorV3Interface(ethUsdPriceFeed)
    );

    hlpPriceAdapter = new HlpPriceAdapter(hlp, calculator);

    _onChainPriceLens = new OnChainPriceLens();

    bytes32[] memory priceIds = new bytes32[](1);
    priceIds[0] = "wstETH";
    IPriceAdapter[] memory priceAdapters = new IPriceAdapter[](1);
    priceAdapters[0] = wstEthUsdPriceAdapter;
    _onChainPriceLens.setPriceAdapters(priceIds, priceAdapters);

    ecoPythCalldataBuilder = new EcoPythCalldataBuilder2(ecoPyth2, _onChainPriceLens, false);
    unsafeEcoPythCalldataBuilder = new UnsafeEcoPythCalldataBuilder2(ecoPyth2, _onChainPriceLens, false);

    vm.startPrank(multiSig);
    ecoPyth2.insertAssetId("wstETH");
    vm.stopPrank();
  }

  // Need a specific block fork
  function testCorrectness_WstEthUsdPriceAdapter() external onlyFork {
    uint256 wstEthUsdPrice = wstEthUsdPriceAdapter.getPrice();
    assertEq(wstEthUsdPrice, 3926.563446389720618119 ether);
  }

  // Division by zero because hlp supply is zero for now
  function testCorrectness_HlpPriceAdapter() external onlyFork {
    uint256 hlpPrice = hlpPriceAdapter.getPrice();
    // assertEq(hlpPrice, 0.934904146758552845 ether);
  }

  // Need a specific block fork
  function testCorrectness_OnChainPriceLens_getPrice()  external onlyFork {
    uint256 wstEthUsdPrice = _onChainPriceLens.getPrice("wstETH");
    assertEq(wstEthUsdPrice, 3926.563446389720618119 ether);
  }

  // Need a specific block fork
  function testCorrectness_EcoPythCalldataBuilder_build() external onlyFork {
    IEcoPythCalldataBuilder2.BuildData[] memory _data = new IEcoPythCalldataBuilder2.BuildData[](3);
    _data[0] = IEcoPythCalldataBuilder2.BuildData({
      assetId: "ETH",
      priceE8: 3633.61 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[1] = IEcoPythCalldataBuilder2.BuildData({
      assetId: "BTC",
      priceE8: 95794.75 * 1e8,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });
    _data[2] = IEcoPythCalldataBuilder2.BuildData({
      assetId: "wstETH",
      priceE8: 0,
      publishTime: uint160(block.timestamp),
      maxDiffBps: 15000
    });

    ecoPythCalldataBuilder.build(_data);
    unsafeEcoPythCalldataBuilder.build(_data);
  }
}
