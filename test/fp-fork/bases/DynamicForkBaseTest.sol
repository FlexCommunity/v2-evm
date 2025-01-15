pragma solidity ^0.8.18;


import { Chains } from "@hmx-test/base/Chains.sol";
import { ConfigEnv } from "./ConfigEnv.sol";
import { console } from "forge-std/console.sol";
import { console2 } from "forge-std/console2.sol";
import { Deployer } from "@hmx-test/libs/Deployer.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StdStorage , stdStorage} from "forge-std/StdStorage.sol";
import { Test } from "forge-std/Test.sol";
import { Uint2str } from "@hmx-test/libs/Uint2str.sol";

import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
/// Helpers
import { ITradeHelper } from "@hmx/helpers/interfaces/ITradeHelper.sol";
import { ICalculator } from "@hmx/contracts/interfaces/ICalculator.sol";

import { OrderbookOracle } from "@hmx/oracles/OrderbookOracle.sol";

/// Oracles
import { IEcoPyth } from "@hmx/oracles/interfaces/IEcoPyth.sol";
import { IPerpStorage } from "@hmx/storages/interfaces/IPerpStorage.sol";
import { IConfigStorage } from "@hmx/storages/interfaces/IConfigStorage.sol";
import { IPythAdapter } from "@hmx/oracles/interfaces/IPythAdapter.sol";
import { IOracleMiddleware } from "@hmx/oracles/interfaces/IOracleMiddleware.sol";
import { PythStructs } from "pyth-sdk-solidity/IPyth.sol";
import { IEcoPythCalldataBuilder3 } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder3.sol";
import { IEcoPythCalldataBuilder } from "@hmx/oracles/interfaces/IEcoPythCalldataBuilder.sol";
import { OnChainPriceLens } from "@hmx/oracles/OnChainPriceLens.sol";

/// Services
import { CrossMarginService } from "@hmx/services/CrossMarginService.sol";
import { LiquidationService } from "@hmx/services/LiquidationService.sol";
import { LiquidityService } from "@hmx/services/LiquidityService.sol";
import { TradeService } from "@hmx/services/TradeService.sol";
import { RebalanceHLPService } from "@hmx/services/RebalanceHLPService.sol";

/// Storages
import { ConfigStorage } from "@hmx/storages/ConfigStorage.sol";
import { PerpStorage } from "@hmx/storages/PerpStorage.sol";
import { VaultStorage } from "@hmx/storages/VaultStorage.sol";

/// Staking
import { IHLPStaking } from "@hmx/staking/interfaces/IHLPStaking.sol";
import { ITradingStaking } from "@hmx/staking/interfaces/ITradingStaking.sol";

/// Readers
import { IOrderReader } from "@hmx/readers/interfaces/IOrderReader.sol";
import { ILiquidationReader } from "@hmx/readers/interfaces/ILiquidationReader.sol";
import { IPositionReader } from "@hmx/readers/interfaces/IPositionReader.sol";

/// Handlers
import { CrossMarginHandler } from "@hmx/handlers/CrossMarginHandler.sol";
import { LimitTradeHandler } from "@hmx/handlers/LimitTradeHandler.sol";
import { LiquidityHandler } from "@hmx/handlers/LiquidityHandler.sol";
import { IBotHandler } from "@hmx/handlers/interfaces/IBotHandler.sol";
import { RebalanceHLPHandler } from "@hmx/handlers/RebalanceHLPHandler.sol";

/// Vendors
/// Uniswap
import { IPermit2 } from "@hmx/interfaces/uniswap/IPermit2.sol";
import { IUniversalRouter } from "@hmx/interfaces/uniswap/IUniversalRouter.sol";

import { HMXLib } from "@hmx/libraries/HMXLib.sol";
import { LimitTradeHelper } from "@hmx/helpers/LimitTradeHelper.sol";


contract DynamicForkBaseTest is Test {
    using stdStorage for StdStorage;
    using Uint2str for uint256;

    StdStorage stdStore;

    address internal constant REWARD_DISTRIBUTOR_FEEDER = 0xddfb5a5D0eF7311E1D706912C38C809Ac1e469d0; // Bot address, hardcoded to check that it's not changed

    address internal ALICE;
    address internal BOB;
    address internal CAROL;
    address internal DAVE;
    address internal FEEVER;
    address internal FEEDER;
    address internal BOT;
    address internal multiSig;
    address internal deployer;
    address internal testUser1;

    ProxyAdmin internal proxyAdmin;

    ConfigEnv internal config;

    /// Account, These are for sepolia
    address internal constant liquidityOrderExecutor = 0xddfb5a5D0eF7311E1D706912C38C809Ac1e469d0;
    address internal constant crossMarginOrderExecutor = 0xddfb5a5D0eF7311E1D706912C38C809Ac1e469d0;
    address internal constant positionManager = 0xddfb5a5D0eF7311E1D706912C38C809Ac1e469d0;
    address internal constant limitOrderExecutor = 0xddfb5a5D0eF7311E1D706912C38C809Ac1e469d0;

    bool internal isForkSupported = true;

    /// Oracles
    IEcoPyth internal ecoPyth2;
    IEcoPythCalldataBuilder3 internal ecoPythBuilder;
    IPythAdapter internal pythAdapter;
    IOracleMiddleware internal oracleMiddleware;
    OnChainPriceLens internal onChainPriceLens;
    /// Helpers
    LimitTradeHelper internal limitTradeHelper;
    ICalculator internal calculator;
    /// Services
    CrossMarginService internal crossMarginService;
    LiquidationService internal liquidationService;
    LiquidityService internal liquidityService;
    TradeService internal tradeService;
    RebalanceHLPService internal rebalanceHLPService;
    /// Storages
    ConfigStorage internal configStorage;
    PerpStorage internal perpStorage;
    VaultStorage internal vaultStorage;
    /// Staking
    IHLPStaking internal hlpStaking;
    // Readers
    ILiquidationReader internal liquidationReader;
    IPositionReader internal positionReader;
    IOrderReader internal orderReader;
    /// Handlers
    CrossMarginHandler internal crossMarginHandler;
    LimitTradeHandler internal limitTradeHandler;
    LiquidityHandler internal liquidityHandler;
    IBotHandler internal botHandler;
    RebalanceHLPHandler internal rebalanceHLPHandler;
    /// Vendors
    /// Uniswap
    IUniversalRouter internal uniswapUniversalRouter;
    IPermit2 internal uniswapPermit2;
    /// OneInch
    address internal oneInchRouter;

    ITradeHelper internal tradeHelper;

    /// Tokens
    IERC20 internal usdc_e;
    IERC20 internal usdc;
    IERC20 internal weth;
    IERC20 internal wbtc;
    // IERC20 internal usdt;
    IERC20 internal dai;
    // IERC20 internal arb;
    IERC20 internal wstEth;
    IERC20 internal hlp;

    OrderbookOracle orderbookOracle;

    modifier onlyBaseMainnetChain() {
        vm.skip(block.chainid != Chains.BASE_MAINNET_CHAIN_ID);
        _;
    }

    modifier onlyFork() {
        vm.skip(!isForkSupported);
        _;
    }

    function setUp() public virtual {
        ALICE = makeAddr("Alice");
        BOB = makeAddr("BOB");
        CAROL = makeAddr("CAROL");
        DAVE = makeAddr("DAVE");
        FEEVER = makeAddr("FEEVER");
        FEEDER = makeAddr("FEEDER");

        config = new ConfigEnv(block.chainid, vm);

        if (block.chainid == Chains.BASE_MAINNET_CHAIN_ID) {
            _setupBaseCommonChain();
            _setUpBaseMainnetChain();
        } else if (block.chainid == Chains.BASE_SEPOLIA_CHAIN_ID) {
            _setupBaseCommonChain();
            _setUpBaseSepoliaChain();
        } else {
            isForkSupported = false;
        }

    }

    function _setupBaseCommonChain() private {
        multiSig = config.getAddress(".safe");
        proxyAdmin = ProxyAdmin(config.getAddress(".proxyAdmin"));

        configStorage = ConfigStorage(config.getAddress(".storages.config"));
        perpStorage = PerpStorage(config.getAddress(".storages.perp"));
        vaultStorage = VaultStorage(config.getAddress(".storages.vault"));

        limitTradeHelper = LimitTradeHelper(config.getAddress(".helpers.limitTrade"));
        calculator = ICalculator(config.getAddress(".calculator"));

        hlpStaking = IHLPStaking(config.getAddress(".staking.hlp"));

        crossMarginHandler = CrossMarginHandler(payable(config.getAddress(".handlers.crossMargin")));
        limitTradeHandler = LimitTradeHandler(payable(config.getAddress(".handlers.limitTrade")));
        liquidityHandler = LiquidityHandler(payable(config.getAddress(".handlers.liquidity")));
        botHandler = IBotHandler(config.getAddress(".handlers.bot"));
        rebalanceHLPHandler = RebalanceHLPHandler(config.getAddress(".handlers.rebalanceHLP"));
    
        ecoPyth2 = IEcoPyth(config.getAddress(".oracles.ecoPyth2"));
        ecoPythBuilder =
            IEcoPythCalldataBuilder3(config.getAddress(".oracles.unsafeEcoPythCalldataBuilder3")); // UnsafeEcoPythCalldataBuilder
        pythAdapter = IPythAdapter(config.getAddress(".oracles.pythAdapter"));
        oracleMiddleware = IOracleMiddleware(config.getAddress(".oracles.middleware"));
        onChainPriceLens = OnChainPriceLens(config.getAddress(".oracles.onChainPriceLens"));
    
        crossMarginService = CrossMarginService(config.getAddress(".services.crossMargin"));
        liquidationService = LiquidationService(config.getAddress(".services.liquidation"));
        liquidityService = LiquidityService(config.getAddress(".services.liquidity"));
        tradeService = TradeService(config.getAddress(".services.trade"));
        rebalanceHLPService = RebalanceHLPService(config.getAddress(".services.rebalanceHLP"));
    
        // oneInchRouter = config.getAddress(".vendors.oneInch.router");

        tradeHelper = ITradeHelper(config.getAddress(".helpers.trade"));

        orderbookOracle = OrderbookOracle(config.getAddress(".oracles.orderbook"));

        liquidationReader = ILiquidationReader(config.getAddress(".reader.liquidation"));
        positionReader = IPositionReader(config.getAddress(".reader.position"));
        orderReader = IOrderReader(config.getAddress(".reader.order"));

        uniswapUniversalRouter = IUniversalRouter(config.getAddress(".vendors.uniswap.universalRouter"));
        uniswapPermit2 = IPermit2(config.getAddress(".vendors.uniswap.permit2"));

        usdc_e = IERC20(config.getAddress(".tokens.usdc"));
        usdc = IERC20(config.getAddress(".tokens.usdc"));
        weth = IERC20(config.getAddress(".tokens.weth"));
        wbtc = IERC20(config.getAddress(".tokens.wbtc"));
        // usdt = IERC20(config.getAddress(".tokens.usdt"));
        dai = IERC20(config.getAddress(".tokens.dai"));
        wstEth = IERC20(config.getAddress(".tokens.wstEth"));
        hlp = IERC20(config.getAddress(".tokens.hlp"));
    }

    function _setUpBaseSepoliaChain() private {
        deployer = 0xf0d00E8435E71df33bdA19951B433B509A315aee;
        testUser1 = 0xddf12401Eeb58b76b9158429132183B1ed21A602;
    }

    function _setUpBaseMainnetChain() private {

    }

    function motherload(address token, address user, uint256 amount) internal {
        stdStore.target(token).sig(IERC20.balanceOf.selector).with_key(user).checked_write(amount);
    }

    function _buildDataForPrice() public view returns (IEcoPythCalldataBuilder3.BuildData[] memory data) {
        bytes32[] memory pythRes = ecoPyth2.getAssetIds();
    
        uint256 len = pythRes.length; // 35 - 1(index 0) = 34
    
        data = new IEcoPythCalldataBuilder3.BuildData[](len - 1);
    
        for (uint i = 1; i < len; i++) {
          PythStructs.Price memory _ecoPythPrice = ecoPyth2.getPriceUnsafe(pythRes[i]);
          data[i - 1].assetId = pythRes[i];
          data[i - 1].priceE8 = _ecoPythPrice.price;
          data[i - 1].publishTime = uint160(block.timestamp);
          data[i - 1].maxDiffBps = 15_000;
        }
      }

    function _getSubAccount(address primary, uint8 subAccountId) public pure returns (address) {
        return address(uint160(primary) ^ uint160(subAccountId));
    }

    function _setPriceData(
        uint64 _priceE8
    ) public view returns (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts) {
        bytes32[] memory pythRes = DynamicForkBaseTest.ecoPyth2.getAssetIds();
        uint256 len = pythRes.length; // 35 - 1(index 0) = 34
        assetIds = new bytes32[](len - 1);
        prices = new uint64[](len - 1);
        shouldInverts = new bool[](len - 1);
    
        for (uint i = 1; i < len; i++) {
          assetIds[i - 1] = pythRes[i];
          prices[i - 1] = _priceE8 * 1e8;
          if (i == 4) {
            shouldInverts[i - 1] = true; // JPY
          } else {
            shouldInverts[i - 1] = false;
          }
        }
    }
    
    function _setPriceDataForReader(
        uint64 _priceE8
    ) public view returns (bytes32[] memory assetIds, uint64[] memory prices, bool[] memory shouldInverts) {
        bytes32[] memory pythRes = DynamicForkBaseTest.ecoPyth2.getAssetIds();
        uint256 len = pythRes.length; // 35 - 1(index 0) = 34
        assetIds = new bytes32[](len);
        prices = new uint64[](len);
        shouldInverts = new bool[](len);
    
        for (uint i = 1; i < len; i++) {
          assetIds[i - 1] = pythRes[i];
          prices[i - 1] = _priceE8 * 1e8;
          if (i == 4) {
            shouldInverts[i - 1] = true; // JPY
          } else {
            shouldInverts[i - 1] = false;
          }
        }
    
        assetIds[len - 1] = 0x555344432d4e4154495645000000000000000000000000000000000000000000; // USDC-NATIVE
        prices[len - 1] = _priceE8 * 1e8;
        shouldInverts[len - 1] = false;
    }
    
    function _setTickPriceZero()
        public
        view
        returns (bytes32[] memory priceUpdateData, bytes32[] memory publishTimeUpdateData)
    {
        bytes32[] memory pythRes = DynamicForkBaseTest.ecoPyth2.getAssetIds();
        uint256 len = pythRes.length; // 35 - 1(index 0) = 34
        int24[] memory tickPrices = new int24[](len - 1);
        uint24[] memory publishTimeDiffs = new uint24[](len - 1);
        for (uint i = 1; i < len; i++) {
          tickPrices[i - 1] = 0;
          publishTimeDiffs[i - 1] = 0;
        }
    
        priceUpdateData = DynamicForkBaseTest.ecoPyth2.buildPriceUpdateData(tickPrices);
        publishTimeUpdateData = DynamicForkBaseTest.ecoPyth2.buildPublishTimeUpdateData(publishTimeDiffs);
    }
    
    function _buildDataForPriceWithSpecificPrice(
        bytes32 assetId,
        int64 priceE8
    ) public view returns (IEcoPythCalldataBuilder.BuildData[] memory data) {
        bytes32[] memory assetIds = DynamicForkBaseTest.ecoPyth2.getAssetIds();
    
        uint256 len = assetIds.length; // 35 - 1(index 0) = 34
    
        data = new IEcoPythCalldataBuilder.BuildData[](len - 1);
    
        for (uint i = 1; i < len; i++) {
          data[i - 1].assetId = assetIds[i];
          if (assetId == assetIds[i]) {
            data[i - 1].priceE8 = priceE8;
          } else {
            data[i - 1].priceE8 = DynamicForkBaseTest.ecoPyth2.getPriceUnsafe(assetIds[i]).price;
          }
          data[i - 1].publishTime = uint160(block.timestamp);
          data[i - 1].maxDiffBps = 15_000;
        }
    }
    
    function _validateClosedPosition(bytes32 _id) public {
        IPerpStorage.Position memory _position = DynamicForkBaseTest.perpStorage.getPositionById(_id);
        // As the position has been closed, the gotten one should be empty stuct
        assertEq(_position.primaryAccount, address(0));
        assertEq(_position.marketIndex, 0);
        assertEq(_position.avgEntryPriceE30, 0);
        assertEq(_position.entryBorrowingRate, 0);
        assertEq(_position.reserveValueE30, 0);
        assertEq(_position.lastIncreaseTimestamp, 0);
        assertEq(_position.positionSizeE30, 0);
        assertEq(_position.realizedPnl, 0);
        assertEq(_position.lastFundingAccrued, 0);
        assertEq(_position.subAccountId, 0);
    }
    
    function _checkIsUnderMMR(
        address _primaryAccount,
        uint8 _subAccountId,
        uint256 _marketIndex,
        uint256
    ) public view returns (bool) {
        address _subAccount = HMXLib.getSubAccount(_primaryAccount, _subAccountId);
        IConfigStorage.MarketConfig memory config = DynamicForkBaseTest.configStorage.getMarketConfigByIndex(_marketIndex);
    
        int256 _subAccountEquity = DynamicForkBaseTest.calculator.getEquity(_subAccount, 0, config.assetId);
        uint256 _mmr = DynamicForkBaseTest.calculator.getMMR(_subAccount);
        if (_subAccountEquity < 0 || uint256(_subAccountEquity) < _mmr) return true;
        return false;
    }
}
