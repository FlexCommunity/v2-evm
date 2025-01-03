# Flex Perpetuals 🐉🔥
Flex Perpetuals is HMXv2 fork. HMXv2 is an innovative pool-based perpetual DEX protocol designed to offer a range of advanced features. It introduces multi-asset collateral support and cross-margin flexibility, providing traders with enhanced options and opportunities.

The protocol incorporates secured measurements, including virtual price impact and funding fees, to ensure the protection of liquidity providers (LPs) from being overly exposed to a single direction. By implementing these measures, HMXv2 aims to create a more resilient and balanced trading environment.

## Architecture
`v2-evm` uses handler-service-storage pattern, this pattern ensures a clear separation of concerns and promotes modularity.

Handlers serve as entry points to the protocol, allowing for interaction with EOA or contracts. They facilitate the flow of data and call between internal protocol and outside world.

Services form the core business logic of the protocol. They handle the processing and execution of various operations, such as trading, liquidating, adding or removing liquidity.

Storages are responsible for storing critical states and data of the protocol.

## License
The primary license for current source code is the Business Source License 1.1 (`BUSL-1.1`), see [https://github.com/Flex-Community/v2-evm/blob/main/LICENSE](LICENSE). Minus the following exceptions:
- `Interfaces` are published under MIT
- Any files state `MIT`
Each of these contracts states their license type.