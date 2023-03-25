// Sources flattened with hardhat v2.11.2 https://hardhat.org

// File contracts/Constants.sol

pragma solidity ^0.8.0;

abstract contract Constants {
    // Universal

    uint internal constant SECONDS_PER_YEAR = 365.2425 * 86400; // Gregorian calendar

    // Protocol parameters

    uint internal constant MAX_SANE_AMOUNT = type(uint112).max;
    uint internal constant MAX_SANE_SMALL_AMOUNT = type(uint96).max;
    uint internal constant MAX_SANE_DEBT_AMOUNT = type(uint144).max;
    uint internal constant INTERNAL_DEBT_PRECISION = 1e9;
    uint internal constant MAX_ENTERED_MARKETS = 10; // per sub-account
    uint internal constant MAX_POSSIBLE_ENTERED_MARKETS = 2 ** 32; // limited by size of AccountStorage.numMarketsEntered
    uint internal constant CONFIG_FACTOR_SCALE = 4_000_000_000; // must fit into a uint32
    uint internal constant RESERVE_FEE_SCALE = 4_000_000_000; // must fit into a uint32
    uint32 internal constant DEFAULT_RESERVE_FEE = uint32(0.23 * 4_000_000_000);
    uint internal constant INITIAL_RESERVES = 1e6;
    uint internal constant INITIAL_INTEREST_ACCUMULATOR = 1e27;
    uint internal constant AVERAGE_LIQUIDITY_PERIOD = 24 * 60 * 60;
    uint16 internal constant MIN_UNISWAP3_OBSERVATION_CARDINALITY = 144;
    uint24 internal constant DEFAULT_TWAP_WINDOW_SECONDS = 30 * 60;
    uint32 internal constant DEFAULT_BORROW_FACTOR = uint32(0.28 * 4_000_000_000);
    uint32 internal constant SELF_COLLATERAL_FACTOR = uint32(0.95 * 4_000_000_000);

    // Implementation internals

    uint internal constant REENTRANCYLOCK__UNLOCKED = 1;
    uint internal constant REENTRANCYLOCK__LOCKED = 2;

    uint8 internal constant DEFERLIQUIDITY__NONE = 0;
    uint8 internal constant DEFERLIQUIDITY__CLEAN = 1;
    uint8 internal constant DEFERLIQUIDITY__DIRTY = 2;

    // Pricing types

    uint16 internal constant PRICINGTYPE__PEGGED = 1;
    uint16 internal constant PRICINGTYPE__UNISWAP3_TWAP = 2;
    uint16 internal constant PRICINGTYPE__FORWARDED = 3;
    uint16 internal constant PRICINGTYPE__CHAINLINK = 4;

    // Correct pricing types are always less than this value
    uint16 internal constant PRICINGTYPE__OUT_OF_BOUNDS = 5;

    // Modules

    // Public single-proxy modules
    uint internal constant MODULEID__INSTALLER = 1;
    uint internal constant MODULEID__MARKETS = 2;
    uint internal constant MODULEID__LIQUIDATION = 3;
    uint internal constant MODULEID__GOVERNANCE = 4;
    uint internal constant MODULEID__EXEC = 5;
    uint internal constant MODULEID__SWAP = 6;
    uint internal constant MODULEID__SWAPHUB = 7;

    uint internal constant MAX_EXTERNAL_SINGLE_PROXY_MODULEID = 499_999;

    // Public multi-proxy modules
    uint internal constant MODULEID__ETOKEN = 500_000;
    uint internal constant MODULEID__DTOKEN = 500_001;

    uint internal constant MAX_EXTERNAL_MODULEID = 999_999;

    // Internal modules
    uint internal constant MODULEID__RISK_MANAGER = 1_000_000;

    // Interest rate models
    //   Default for new markets
    uint internal constant MODULEID__IRM_DEFAULT = 2_000_000;
    //   Testing-only
    uint internal constant MODULEID__IRM_ZERO = 2_000_001;
    uint internal constant MODULEID__IRM_FIXED = 2_000_002;
    uint internal constant MODULEID__IRM_LINEAR = 2_000_100;
    //   Classes
    uint internal constant MODULEID__IRM_CLASS__STABLE = 2_000_500;
    uint internal constant MODULEID__IRM_CLASS__MAJOR = 2_000_501;
    uint internal constant MODULEID__IRM_CLASS__MIDCAP = 2_000_502;
    uint internal constant MODULEID__IRM_CLASS__MEGA = 2_000_503;
    uint internal constant MODULEID__IRM_CLASS__LIDO = 2_000_504;
    uint internal constant MODULEID__IRM_CLASS__USDT = 2_000_505;
    uint internal constant MODULEID__IRM_CLASS__OHM = 2_000_506;

    // Swap types
    uint internal constant SWAP_TYPE__UNI_EXACT_INPUT_SINGLE = 1;
    uint internal constant SWAP_TYPE__UNI_EXACT_INPUT = 2;
    uint internal constant SWAP_TYPE__UNI_EXACT_OUTPUT_SINGLE = 3;
    uint internal constant SWAP_TYPE__UNI_EXACT_OUTPUT = 4;
    uint internal constant SWAP_TYPE__1INCH = 5;

    uint internal constant SWAP_TYPE__UNI_EXACT_OUTPUT_SINGLE_REPAY = 6;
    uint internal constant SWAP_TYPE__UNI_EXACT_OUTPUT_REPAY = 7;
}

// File contracts/Storage.sol

pragma solidity ^0.8.0;

abstract contract Storage is Constants {
    // Dispatcher and upgrades

    uint internal reentrancyLock;

    address upgradeAdmin;
    address governorAdmin;

    mapping(uint => address) moduleLookup; // moduleId => module implementation
    mapping(uint => address) proxyLookup; // moduleId => proxy address (only for single-proxy modules)

    struct TrustedSenderInfo {
        uint32 moduleId; // 0 = un-trusted
        address moduleImpl; // only non-zero for external single-proxy modules
    }

    mapping(address => TrustedSenderInfo) trustedSenders; // sender address => moduleId (0 = un-trusted)

    // Account-level state
    // Sub-accounts are considered distinct accounts

    struct AccountStorage {
        // Packed slot: 1 + 5 + 4 + 20 = 30
        uint8 deferLiquidityStatus;
        uint40 lastAverageLiquidityUpdate;
        uint32 numMarketsEntered;
        address firstMarketEntered;
        uint averageLiquidity;
        address averageLiquidityDelegate;
    }

    mapping(address => AccountStorage) accountLookup;
    mapping(address => address[MAX_POSSIBLE_ENTERED_MARKETS]) marketsEntered;

    // Markets and assets

    struct AssetConfig {
        // Packed slot: 20 + 1 + 4 + 4 + 3 = 32
        address eTokenAddress;
        bool borrowIsolated;
        uint32 collateralFactor;
        uint32 borrowFactor;
        uint24 twapWindow;
    }

    struct UserAsset {
        uint112 balance;
        uint144 owed;
        uint interestAccumulator;
    }

    struct AssetStorage {
        // Packed slot: 5 + 1 + 4 + 12 + 4 + 2 + 4 = 32
        uint40 lastInterestAccumulatorUpdate;
        uint8 underlyingDecimals; // Not dynamic, but put here to live in same storage slot
        uint32 interestRateModel;
        int96 interestRate;
        uint32 reserveFee;
        uint16 pricingType;
        uint32 pricingParameters;
        address underlying;
        uint96 reserveBalance;
        address dTokenAddress;
        uint112 totalBalances;
        uint144 totalBorrows;
        uint interestAccumulator;
        mapping(address => UserAsset) users;
        mapping(address => mapping(address => uint)) eTokenAllowance;
        mapping(address => mapping(address => uint)) dTokenAllowance;
    }

    mapping(address => AssetConfig) internal underlyingLookup; // underlying => AssetConfig
    mapping(address => AssetStorage) internal eTokenLookup; // EToken => AssetStorage
    mapping(address => address) internal dTokenLookup; // DToken => EToken
    mapping(address => address) internal pTokenLookup; // PToken => underlying
    mapping(address => address) internal reversePTokenLookup; // underlying => PToken
    mapping(address => address) internal chainlinkPriceFeedLookup; // underlying => chainlinkAggregator
}

// File contracts/Events.sol

pragma solidity ^0.8.0;

abstract contract Events {
    event Genesis();

    event ProxyCreated(address indexed proxy, uint moduleId);
    event MarketActivated(
        address indexed underlying,
        address indexed eToken,
        address indexed dToken
    );
    event PTokenActivated(address indexed underlying, address indexed pToken);

    event EnterMarket(address indexed underlying, address indexed account);
    event ExitMarket(address indexed underlying, address indexed account);

    event Deposit(address indexed underlying, address indexed account, uint amount);
    event Withdraw(address indexed underlying, address indexed account, uint amount);
    event Borrow(address indexed underlying, address indexed account, uint amount);
    event Repay(address indexed underlying, address indexed account, uint amount);

    event Liquidation(
        address indexed liquidator,
        address indexed violator,
        address indexed underlying,
        address collateral,
        uint repay,
        uint yield,
        uint healthScore,
        uint baseDiscount,
        uint discount
    );

    event TrackAverageLiquidity(address indexed account);
    event UnTrackAverageLiquidity(address indexed account);
    event DelegateAverageLiquidity(address indexed account, address indexed delegate);

    event PTokenWrap(address indexed underlying, address indexed account, uint amount);
    event PTokenUnWrap(address indexed underlying, address indexed account, uint amount);

    event AssetStatus(
        address indexed underlying,
        uint totalBalances,
        uint totalBorrows,
        uint96 reserveBalance,
        uint poolSize,
        uint interestAccumulator,
        int96 interestRate,
        uint timestamp
    );

    event RequestDeposit(address indexed account, uint amount);
    event RequestWithdraw(address indexed account, uint amount);
    event RequestMint(address indexed account, uint amount);
    event RequestBurn(address indexed account, uint amount);
    event RequestTransferEToken(address indexed from, address indexed to, uint amount);
    event RequestDonate(address indexed account, uint amount);

    event RequestBorrow(address indexed account, uint amount);
    event RequestRepay(address indexed account, uint amount);
    event RequestTransferDToken(address indexed from, address indexed to, uint amount);

    event RequestLiquidate(
        address indexed liquidator,
        address indexed violator,
        address indexed underlying,
        address collateral,
        uint repay,
        uint minYield
    );

    event InstallerSetUpgradeAdmin(address indexed newUpgradeAdmin);
    event InstallerSetGovernorAdmin(address indexed newGovernorAdmin);
    event InstallerInstallModule(
        uint indexed moduleId,
        address indexed moduleImpl,
        bytes32 moduleGitCommit
    );

    event GovSetAssetConfig(address indexed underlying, Storage.AssetConfig newConfig);
    event GovSetIRM(address indexed underlying, uint interestRateModel, bytes resetParams);
    event GovSetPricingConfig(
        address indexed underlying,
        uint16 newPricingType,
        uint32 newPricingParameter
    );
    event GovSetReserveFee(address indexed underlying, uint32 newReserveFee);
    event GovConvertReserves(address indexed underlying, address indexed recipient, uint amount);
    event GovSetChainlinkPriceFeed(address indexed underlying, address chainlinkAggregator);

    event RequestSwap(
        address indexed accountIn,
        address indexed accountOut,
        address indexed underlyingIn,
        address underlyingOut,
        uint amount,
        uint swapType
    );
    event RequestSwapHub(
        address indexed accountIn,
        address indexed accountOut,
        address indexed underlyingIn,
        address underlyingOut,
        uint amountIn,
        uint amountOut,
        uint mode,
        address swapHandler
    );
    event RequestSwapHubRepay(
        address indexed accountIn,
        address indexed accountOut,
        address indexed underlyingIn,
        address underlyingOut,
        uint targetDebt,
        address swapHandler
    );
}

// File contracts/Proxy.sol

pragma solidity ^0.8.0;

contract Proxy {
    address immutable creator;

    constructor() {
        creator = msg.sender;
    }

    // External interface

    fallback() external {
        address creator_ = creator;

        if (msg.sender == creator_) {
            assembly {
                mstore(0, 0)
                calldatacopy(31, 0, calldatasize())

                switch mload(0) // numTopics
                case 0 {
                    log0(32, sub(calldatasize(), 1))
                }
                case 1 {
                    log1(64, sub(calldatasize(), 33), mload(32))
                }
                case 2 {
                    log2(96, sub(calldatasize(), 65), mload(32), mload(64))
                }
                case 3 {
                    log3(128, sub(calldatasize(), 97), mload(32), mload(64), mload(96))
                }
                case 4 {
                    log4(160, sub(calldatasize(), 129), mload(32), mload(64), mload(96), mload(128))
                }
                default {
                    revert(0, 0)
                }

                return(0, 0)
            }
        } else {
            assembly {
                mstore(0, 0xe9c4a3ac00000000000000000000000000000000000000000000000000000000) // dispatch() selector
                calldatacopy(4, 0, calldatasize())
                mstore(add(4, calldatasize()), shl(96, caller()))

                let result := call(gas(), creator_, 0, 0, add(24, calldatasize()), 0, 0)
                returndatacopy(0, 0, returndatasize())

                switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
            }
        }
    }
}

// File contracts/Base.sol

pragma solidity ^0.8.0;

//import "hardhat/console.sol"; // DEV_MODE

abstract contract Base is Storage, Events {
    // Modules

    function _createProxy(uint proxyModuleId) internal returns (address) {
        require(proxyModuleId != 0, "e/create-proxy/invalid-module");
        require(proxyModuleId <= MAX_EXTERNAL_MODULEID, "e/create-proxy/internal-module");

        // If we've already created a proxy for a single-proxy module, just return it:

        if (proxyLookup[proxyModuleId] != address(0)) return proxyLookup[proxyModuleId];

        // Otherwise create a proxy:

        address proxyAddr = address(new Proxy());

        if (proxyModuleId <= MAX_EXTERNAL_SINGLE_PROXY_MODULEID)
            proxyLookup[proxyModuleId] = proxyAddr;

        trustedSenders[proxyAddr] = TrustedSenderInfo({
            moduleId: uint32(proxyModuleId),
            moduleImpl: address(0)
        });

        emit ProxyCreated(proxyAddr, proxyModuleId);

        return proxyAddr;
    }

    function callInternalModule(uint moduleId, bytes memory input) internal returns (bytes memory) {
        (bool success, bytes memory result) = moduleLookup[moduleId].delegatecall(input);
        if (!success) revertBytes(result);
        return result;
    }

    // Modifiers

    modifier nonReentrant() {
        require(reentrancyLock == REENTRANCYLOCK__UNLOCKED, "e/reentrancy");

        reentrancyLock = REENTRANCYLOCK__LOCKED;
        _;
        reentrancyLock = REENTRANCYLOCK__UNLOCKED;
    }

    modifier reentrantOK() {
        // documentation only
        _;
    }

    // Used to flag functions which do not modify storage, but do perform a delegate call
    // to a view function, which prohibits a standard view modifier. The flag is used to
    // patch state mutability in compiled ABIs and interfaces.
    modifier staticDelegate() {
        _;
    }

    // WARNING: Must be very careful with this modifier. It resets the free memory pointer
    // to the value it was when the function started. This saves gas if more memory will
    // be allocated in the future. However, if the memory will be later referenced
    // (for example because the function has returned a pointer to it) then you cannot
    // use this modifier.

    modifier FREEMEM() {
        uint origFreeMemPtr;

        assembly {
            origFreeMemPtr := mload(0x40)
        }

        _;

        /*
        assembly { // DEV_MODE: overwrite the freed memory with garbage to detect bugs
            let garbage := 0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF
            for { let i := origFreeMemPtr } lt(i, mload(0x40)) { i := add(i, 32) } { mstore(i, garbage) }
        }
        */

        assembly {
            mstore(0x40, origFreeMemPtr)
        }
    }

    // Error handling

    function revertBytes(bytes memory errMsg) internal pure {
        if (errMsg.length > 0) {
            assembly {
                revert(add(32, errMsg), mload(errMsg))
            }
        }

        revert("e/empty-error");
    }
}

// File contracts/Euler.sol

pragma solidity ^0.8.0;

/// @notice Main storage contract for the Euler system
contract Euler is Base {
    constructor(address admin, address installerModule) {
        emit Genesis();

        reentrancyLock = REENTRANCYLOCK__UNLOCKED;
        upgradeAdmin = admin;
        governorAdmin = admin;

        moduleLookup[MODULEID__INSTALLER] = installerModule;
        address installerProxy = _createProxy(MODULEID__INSTALLER);
        trustedSenders[installerProxy].moduleImpl = installerModule;
    }

    string public constant name = "Euler Protocol";

    /// @notice Lookup the current implementation contract for a module
    /// @param moduleId Fixed constant that refers to a module type (ie MODULEID__ETOKEN)
    /// @return An internal address specifies the module's implementation code
    function moduleIdToImplementation(uint moduleId) external view returns (address) {
        return moduleLookup[moduleId];
    }

    /// @notice Lookup a proxy that can be used to interact with a module (only valid for single-proxy modules)
    /// @param moduleId Fixed constant that refers to a module type (ie MODULEID__MARKETS)
    /// @return An address that should be cast to the appropriate module interface, ie IEulerMarkets(moduleIdToProxy(2))
    function moduleIdToProxy(uint moduleId) external view returns (address) {
        return proxyLookup[moduleId];
    }

    function dispatch() external reentrantOK {
        uint32 moduleId = trustedSenders[msg.sender].moduleId;
        address moduleImpl = trustedSenders[msg.sender].moduleImpl;

        require(moduleId != 0, "e/sender-not-trusted");

        if (moduleImpl == address(0)) moduleImpl = moduleLookup[moduleId];

        uint msgDataLength = msg.data.length;
        require(msgDataLength >= (4 + 4 + 20), "e/input-too-short");

        assembly {
            let payloadSize := sub(calldatasize(), 4)
            calldatacopy(0, 4, payloadSize)
            mstore(payloadSize, shl(96, caller()))

            let result := delegatecall(gas(), moduleImpl, 0, add(payloadSize, 20), 0, 0)

            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}

// File contracts/BaseModule.sol

pragma solidity ^0.8.0;

abstract contract BaseModule is Base {
    // Construction

    // public accessors common to all modules

    uint public immutable moduleId;
    bytes32 public immutable moduleGitCommit;

    constructor(uint moduleId_, bytes32 moduleGitCommit_) {
        moduleId = moduleId_;
        moduleGitCommit = moduleGitCommit_;
    }

    // Accessing parameters

    function unpackTrailingParamMsgSender() internal pure returns (address msgSender) {
        assembly {
            msgSender := shr(96, calldataload(sub(calldatasize(), 40)))
        }
    }

    function unpackTrailingParams() internal pure returns (address msgSender, address proxyAddr) {
        assembly {
            msgSender := shr(96, calldataload(sub(calldatasize(), 40)))
            proxyAddr := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    // Emit logs via proxies

    function emitViaProxy_Transfer(
        address proxyAddr,
        address from,
        address to,
        uint value
    ) internal FREEMEM {
        (bool success, ) = proxyAddr.call(
            abi.encodePacked(
                uint8(3),
                keccak256(bytes("Transfer(address,address,uint256)")),
                bytes32(uint(uint160(from))),
                bytes32(uint(uint160(to))),
                value
            )
        );
        require(success, "e/log-proxy-fail");
    }

    function emitViaProxy_Approval(
        address proxyAddr,
        address owner,
        address spender,
        uint value
    ) internal FREEMEM {
        (bool success, ) = proxyAddr.call(
            abi.encodePacked(
                uint8(3),
                keccak256(bytes("Approval(address,address,uint256)")),
                bytes32(uint(uint160(owner))),
                bytes32(uint(uint160(spender))),
                value
            )
        );
        require(success, "e/log-proxy-fail");
    }
}

// File contracts/BaseIRM.sol

pragma solidity ^0.8.0;

abstract contract BaseIRM is BaseModule {
    constructor(uint moduleId_, bytes32 moduleGitCommit_) BaseModule(moduleId_, moduleGitCommit_) {}

    int96 internal constant MAX_ALLOWED_INTEREST_RATE =
        int96(int(uint(5 * 1e27) / SECONDS_PER_YEAR)); // 500% APR
    int96 internal constant MIN_ALLOWED_INTEREST_RATE = 0;

    function computeInterestRateImpl(address, uint32) internal virtual returns (int96);

    function computeInterestRate(address underlying, uint32 utilisation) external returns (int96) {
        int96 rate = computeInterestRateImpl(underlying, utilisation);

        if (rate > MAX_ALLOWED_INTEREST_RATE) rate = MAX_ALLOWED_INTEREST_RATE;
        else if (rate < MIN_ALLOWED_INTEREST_RATE) rate = MIN_ALLOWED_INTEREST_RATE;

        return rate;
    }

    function reset(address underlying, bytes calldata resetParams) external virtual {}
}

// File contracts/BaseIRMLinearKink.sol

pragma solidity ^0.8.0;

contract BaseIRMLinearKink is BaseIRM {
    uint public immutable baseRate;
    uint public immutable slope1;
    uint public immutable slope2;
    uint public immutable kink;

    constructor(
        uint moduleId_,
        bytes32 moduleGitCommit_,
        uint baseRate_,
        uint slope1_,
        uint slope2_,
        uint kink_
    ) BaseIRM(moduleId_, moduleGitCommit_) {
        baseRate = baseRate_;
        slope1 = slope1_;
        slope2 = slope2_;
        kink = kink_;
    }

    function computeInterestRateImpl(
        address,
        uint32 utilisation
    ) internal view override returns (int96) {
        uint ir = baseRate;

        if (utilisation <= kink) {
            ir += utilisation * slope1;
        } else {
            ir += kink * slope1;
            ir += slope2 * (utilisation - kink);
        }

        return int96(int(ir));
    }
}

// File contracts/vendor/RPow.sol

// From MakerDAO DSS

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;

library RPow {
    function rpow(uint x, uint n, uint base) internal pure returns (uint z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    z := base
                }
                default {
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    z := base
                }
                default {
                    z := x
                }
                let half := div(base, 2) // for rounding.
                for {
                    n := div(n, 2)
                } n {
                    n := div(n, 2)
                } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) {
                        revert(0, 0)
                    }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }
                    x := div(xxRound, base)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
                            revert(0, 0)
                        }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }
                        z := div(zxRound, base)
                    }
                }
            }
        }
    }
}

// File contracts/IRiskManager.sol

pragma solidity ^0.8.0;

// This interface is used to avoid a circular dependency between BaseLogic and RiskManager

interface IRiskManager {
    struct NewMarketParameters {
        uint16 pricingType;
        uint32 pricingParameters;
        Storage.AssetConfig config;
    }

    struct LiquidityStatus {
        uint collateralValue;
        uint liabilityValue;
        uint numBorrows;
        bool borrowIsolated;
    }

    struct AssetLiquidity {
        address underlying;
        LiquidityStatus status;
    }

    function getNewMarketParameters(
        address underlying
    ) external returns (NewMarketParameters memory);

    function requireLiquidity(address account) external view;

    function computeLiquidity(
        address account
    ) external view returns (LiquidityStatus memory status);

    function computeAssetLiquidities(
        address account
    ) external view returns (AssetLiquidity[] memory assets);

    function getPrice(address underlying) external view returns (uint twap, uint twapPeriod);

    function getPriceFull(
        address underlying
    ) external view returns (uint twap, uint twapPeriod, uint currPrice);
}

// File contracts/Interfaces.sol

pragma solidity ^0.8.0;

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        bytes calldata signature
    ) external;
}

interface IERC3156FlashBorrower {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

interface IERC3156FlashLender {
    function maxFlashLoan(address token) external view returns (uint256);

    function flashFee(address token, uint256 amount) external view returns (uint256);

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

// File contracts/Utils.sol

pragma solidity ^0.8.0;

library Utils {
    function safeTransferFrom(address token, address from, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), string(data));
    }

    function safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), string(data));
    }

    function safeApprove(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), string(data));
    }
}

// File contracts/BaseLogic.sol

pragma solidity ^0.8.0;

abstract contract BaseLogic is BaseModule {
    constructor(uint moduleId_, bytes32 moduleGitCommit_) BaseModule(moduleId_, moduleGitCommit_) {}

    // Account auth

    function getSubAccount(address primary, uint subAccountId) internal pure returns (address) {
        require(subAccountId < 256, "e/sub-account-id-too-big");
        return address(uint160(primary) ^ uint160(subAccountId));
    }

    function isSubAccountOf(address primary, address subAccount) internal pure returns (bool) {
        return (uint160(primary) | 0xFF) == (uint160(subAccount) | 0xFF);
    }

    // Entered markets array

    function getEnteredMarketsArray(address account) internal view returns (address[] memory) {
        uint32 numMarketsEntered = accountLookup[account].numMarketsEntered;
        address firstMarketEntered = accountLookup[account].firstMarketEntered;

        address[] memory output = new address[](numMarketsEntered);
        if (numMarketsEntered == 0) return output;

        address[MAX_POSSIBLE_ENTERED_MARKETS] storage markets = marketsEntered[account];

        output[0] = firstMarketEntered;

        for (uint i = 1; i < numMarketsEntered; ++i) {
            output[i] = markets[i];
        }

        return output;
    }

    function isEnteredInMarket(address account, address underlying) internal view returns (bool) {
        uint32 numMarketsEntered = accountLookup[account].numMarketsEntered;
        address firstMarketEntered = accountLookup[account].firstMarketEntered;

        if (numMarketsEntered == 0) return false;
        if (firstMarketEntered == underlying) return true;

        address[MAX_POSSIBLE_ENTERED_MARKETS] storage markets = marketsEntered[account];

        for (uint i = 1; i < numMarketsEntered; ++i) {
            if (markets[i] == underlying) return true;
        }

        return false;
    }

    function doEnterMarket(address account, address underlying) internal {
        AccountStorage storage accountStorage = accountLookup[account];

        uint32 numMarketsEntered = accountStorage.numMarketsEntered;
        address[MAX_POSSIBLE_ENTERED_MARKETS] storage markets = marketsEntered[account];

        if (numMarketsEntered != 0) {
            if (accountStorage.firstMarketEntered == underlying) return; // already entered
            for (uint i = 1; i < numMarketsEntered; i++) {
                if (markets[i] == underlying) return; // already entered
            }
        }

        require(numMarketsEntered < MAX_ENTERED_MARKETS, "e/too-many-entered-markets");

        if (numMarketsEntered == 0) accountStorage.firstMarketEntered = underlying;
        else markets[numMarketsEntered] = underlying;

        accountStorage.numMarketsEntered = numMarketsEntered + 1;

        emit EnterMarket(underlying, account);
    }

    // Liquidity check must be done by caller after calling this

    function doExitMarket(address account, address underlying) internal {
        AccountStorage storage accountStorage = accountLookup[account];

        uint32 numMarketsEntered = accountStorage.numMarketsEntered;
        address[MAX_POSSIBLE_ENTERED_MARKETS] storage markets = marketsEntered[account];
        uint searchIndex = type(uint).max;

        if (numMarketsEntered == 0) return; // already exited

        if (accountStorage.firstMarketEntered == underlying) {
            searchIndex = 0;
        } else {
            for (uint i = 1; i < numMarketsEntered; i++) {
                if (markets[i] == underlying) {
                    searchIndex = i;
                    break;
                }
            }

            if (searchIndex == type(uint).max) return; // already exited
        }

        uint lastMarketIndex = numMarketsEntered - 1;

        if (searchIndex != lastMarketIndex) {
            if (searchIndex == 0) accountStorage.firstMarketEntered = markets[lastMarketIndex];
            else markets[searchIndex] = markets[lastMarketIndex];
        }

        accountStorage.numMarketsEntered = uint32(lastMarketIndex);

        if (lastMarketIndex != 0) markets[lastMarketIndex] = address(0); // zero out for storage refund

        emit ExitMarket(underlying, account);
    }

    // AssetConfig

    function resolveAssetConfig(address underlying) internal view returns (AssetConfig memory) {
        AssetConfig memory config = underlyingLookup[underlying];
        require(config.eTokenAddress != address(0), "e/market-not-activated");

        if (config.borrowFactor == type(uint32).max) config.borrowFactor = DEFAULT_BORROW_FACTOR;
        if (config.twapWindow == type(uint24).max) config.twapWindow = DEFAULT_TWAP_WINDOW_SECONDS;

        return config;
    }

    // AssetCache

    struct AssetCache {
        address underlying;
        uint112 totalBalances;
        uint144 totalBorrows;
        uint96 reserveBalance;
        uint interestAccumulator;
        uint40 lastInterestAccumulatorUpdate;
        uint8 underlyingDecimals;
        uint32 interestRateModel;
        int96 interestRate;
        uint32 reserveFee;
        uint16 pricingType;
        uint32 pricingParameters;
        uint poolSize; // result of calling balanceOf on underlying (in external units)
        uint underlyingDecimalsScaler;
        uint maxExternalAmount;
    }

    function initAssetCache(
        address underlying,
        AssetStorage storage assetStorage,
        AssetCache memory assetCache
    ) internal view returns (bool dirty) {
        dirty = false;

        assetCache.underlying = underlying;

        // Storage loads

        assetCache.lastInterestAccumulatorUpdate = assetStorage.lastInterestAccumulatorUpdate;
        uint8 underlyingDecimals = assetCache.underlyingDecimals = assetStorage.underlyingDecimals;
        assetCache.interestRateModel = assetStorage.interestRateModel;
        assetCache.interestRate = assetStorage.interestRate;
        assetCache.reserveFee = assetStorage.reserveFee;
        assetCache.pricingType = assetStorage.pricingType;
        assetCache.pricingParameters = assetStorage.pricingParameters;

        assetCache.reserveBalance = assetStorage.reserveBalance;

        assetCache.totalBalances = assetStorage.totalBalances;
        assetCache.totalBorrows = assetStorage.totalBorrows;

        assetCache.interestAccumulator = assetStorage.interestAccumulator;

        // Derived state

        unchecked {
            assetCache.underlyingDecimalsScaler = 10 ** (18 - underlyingDecimals);
            assetCache.maxExternalAmount = MAX_SANE_AMOUNT / assetCache.underlyingDecimalsScaler;
        }

        uint poolSize = callBalanceOf(assetCache, address(this));
        if (poolSize <= assetCache.maxExternalAmount) {
            unchecked {
                assetCache.poolSize = poolSize * assetCache.underlyingDecimalsScaler;
            }
        } else {
            assetCache.poolSize = 0;
        }

        // Update interest accumulator and reserves

        if (block.timestamp != assetCache.lastInterestAccumulatorUpdate) {
            dirty = true;

            uint deltaT = block.timestamp - assetCache.lastInterestAccumulatorUpdate;

            // Compute new values

            uint newInterestAccumulator = (RPow.rpow(
                uint(int(assetCache.interestRate) + 1e27),
                deltaT,
                1e27
            ) * assetCache.interestAccumulator) / 1e27;

            uint newTotalBorrows = (assetCache.totalBorrows * newInterestAccumulator) /
                assetCache.interestAccumulator;

            uint newReserveBalance = assetCache.reserveBalance;
            uint newTotalBalances = assetCache.totalBalances;

            uint feeAmount = ((newTotalBorrows - assetCache.totalBorrows) *
                (
                    assetCache.reserveFee == type(uint32).max
                        ? DEFAULT_RESERVE_FEE
                        : assetCache.reserveFee
                )) / (RESERVE_FEE_SCALE * INTERNAL_DEBT_PRECISION);

            if (feeAmount != 0) {
                uint poolAssets = assetCache.poolSize + (newTotalBorrows / INTERNAL_DEBT_PRECISION);
                newTotalBalances = (poolAssets * newTotalBalances) / (poolAssets - feeAmount);
                newReserveBalance += newTotalBalances - assetCache.totalBalances;
            }

            // Store new values in assetCache, only if no overflows will occur

            if (
                newTotalBalances <= MAX_SANE_AMOUNT &&
                newTotalBorrows <= MAX_SANE_DEBT_AMOUNT &&
                newReserveBalance <= MAX_SANE_SMALL_AMOUNT
            ) {
                assetCache.totalBorrows = encodeDebtAmount(newTotalBorrows);
                assetCache.interestAccumulator = newInterestAccumulator;
                assetCache.lastInterestAccumulatorUpdate = uint40(block.timestamp);

                if (newTotalBalances != assetCache.totalBalances) {
                    assetCache.reserveBalance = encodeSmallAmount(newReserveBalance);
                    assetCache.totalBalances = encodeAmount(newTotalBalances);
                }
            }
        }
    }

    function loadAssetCache(
        address underlying,
        AssetStorage storage assetStorage
    ) internal returns (AssetCache memory assetCache) {
        if (initAssetCache(underlying, assetStorage, assetCache)) {
            assetStorage.lastInterestAccumulatorUpdate = assetCache.lastInterestAccumulatorUpdate;

            assetStorage.underlying = assetCache.underlying; // avoid an SLOAD of this slot
            assetStorage.reserveBalance = assetCache.reserveBalance;

            assetStorage.totalBalances = assetCache.totalBalances;
            assetStorage.totalBorrows = assetCache.totalBorrows;

            assetStorage.interestAccumulator = assetCache.interestAccumulator;
        }
    }

    function loadAssetCacheRO(
        address underlying,
        AssetStorage storage assetStorage
    ) internal view returns (AssetCache memory assetCache) {
        require(reentrancyLock == REENTRANCYLOCK__UNLOCKED, "e/ro-reentrancy");
        initAssetCache(underlying, assetStorage, assetCache);
    }

    function internalLoadAssetCacheRO(
        address underlying,
        AssetStorage storage assetStorage
    ) internal view returns (AssetCache memory assetCache) {
        initAssetCache(underlying, assetStorage, assetCache);
    }

    // Utils

    function decodeExternalAmount(
        AssetCache memory assetCache,
        uint externalAmount
    ) internal pure returns (uint scaledAmount) {
        require(externalAmount <= assetCache.maxExternalAmount, "e/amount-too-large");
        unchecked {
            scaledAmount = externalAmount * assetCache.underlyingDecimalsScaler;
        }
    }

    function encodeAmount(uint amount) internal pure returns (uint112) {
        require(amount <= MAX_SANE_AMOUNT, "e/amount-too-large-to-encode");
        return uint112(amount);
    }

    function encodeSmallAmount(uint amount) internal pure returns (uint96) {
        require(amount <= MAX_SANE_SMALL_AMOUNT, "e/small-amount-too-large-to-encode");
        return uint96(amount);
    }

    function encodeDebtAmount(uint amount) internal pure returns (uint144) {
        require(amount <= MAX_SANE_DEBT_AMOUNT, "e/debt-amount-too-large-to-encode");
        return uint144(amount);
    }

    function computeExchangeRate(AssetCache memory assetCache) private pure returns (uint) {
        uint totalAssets = assetCache.poolSize +
            (assetCache.totalBorrows / INTERNAL_DEBT_PRECISION);
        if (totalAssets == 0 || assetCache.totalBalances == 0) return 1e18;
        return (totalAssets * 1e18) / assetCache.totalBalances;
    }

    function underlyingAmountToBalance(
        AssetCache memory assetCache,
        uint amount
    ) internal pure returns (uint) {
        uint exchangeRate = computeExchangeRate(assetCache);
        return (amount * 1e18) / exchangeRate;
    }

    function underlyingAmountToBalanceRoundUp(
        AssetCache memory assetCache,
        uint amount
    ) internal pure returns (uint) {
        uint exchangeRate = computeExchangeRate(assetCache);
        return (amount * 1e18 + (exchangeRate - 1)) / exchangeRate;
    }

    function balanceToUnderlyingAmount(
        AssetCache memory assetCache,
        uint amount
    ) internal pure returns (uint) {
        uint exchangeRate = computeExchangeRate(assetCache);
        return (amount * exchangeRate) / 1e18;
    }

    function callBalanceOf(
        AssetCache memory assetCache,
        address account
    ) internal view FREEMEM returns (uint) {
        // We set a gas limit so that a malicious token can't eat up all gas and cause a liquidity check to fail.

        (bool success, bytes memory data) = assetCache.underlying.staticcall{gas: 200000}(
            abi.encodeWithSelector(IERC20.balanceOf.selector, account)
        );

        // If token's balanceOf() call fails for any reason, return 0. This prevents malicious tokens from causing liquidity checks to fail.
        // If the contract doesn't exist (maybe because selfdestructed), then data.length will be 0 and we will return 0.
        // Data length > 32 is allowed because some legitimate tokens append extra data that can be safely ignored.

        if (!success || data.length < 32) return 0;

        return abi.decode(data, (uint256));
    }

    function updateInterestRate(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache
    ) internal {
        uint32 utilisation;

        {
            uint totalBorrows = assetCache.totalBorrows / INTERNAL_DEBT_PRECISION;
            uint poolAssets = assetCache.poolSize + totalBorrows;
            if (poolAssets == 0)
                utilisation = 0; // empty pool arbitrarily given utilisation of 0
            else
                utilisation = uint32(
                    (totalBorrows * (uint(type(uint32).max) * 1e18)) / poolAssets / 1e18
                );
        }

        bytes memory result = callInternalModule(
            assetCache.interestRateModel,
            abi.encodeWithSelector(
                BaseIRM.computeInterestRate.selector,
                assetCache.underlying,
                utilisation
            )
        );

        int96 newInterestRate = abi.decode(result, (int96));

        assetStorage.interestRate = assetCache.interestRate = newInterestRate;
    }

    function logAssetStatus(AssetCache memory a) internal {
        emit AssetStatus(
            a.underlying,
            a.totalBalances,
            a.totalBorrows / INTERNAL_DEBT_PRECISION,
            a.reserveBalance,
            a.poolSize,
            a.interestAccumulator,
            a.interestRate,
            block.timestamp
        );
    }

    // Balances

    function increaseBalance(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache,
        address eTokenAddress,
        address account,
        uint amount
    ) internal {
        assetStorage.users[account].balance = encodeAmount(
            assetStorage.users[account].balance + amount
        );

        assetStorage.totalBalances = assetCache.totalBalances = encodeAmount(
            uint(assetCache.totalBalances) + amount
        );

        updateInterestRate(assetStorage, assetCache);

        emit Deposit(assetCache.underlying, account, amount);
        emitViaProxy_Transfer(eTokenAddress, address(0), account, amount);
    }

    function decreaseBalance(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache,
        address eTokenAddress,
        address account,
        uint amount
    ) internal {
        uint origBalance = assetStorage.users[account].balance;
        require(origBalance >= amount, "e/insufficient-balance");
        assetStorage.users[account].balance = encodeAmount(origBalance - amount);

        assetStorage.totalBalances = assetCache.totalBalances = encodeAmount(
            assetCache.totalBalances - amount
        );

        updateInterestRate(assetStorage, assetCache);

        emit Withdraw(assetCache.underlying, account, amount);
        emitViaProxy_Transfer(eTokenAddress, account, address(0), amount);
    }

    function transferBalance(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache,
        address eTokenAddress,
        address from,
        address to,
        uint amount
    ) internal {
        uint origFromBalance = assetStorage.users[from].balance;
        require(origFromBalance >= amount, "e/insufficient-balance");
        uint newFromBalance;
        unchecked {
            newFromBalance = origFromBalance - amount;
        }

        assetStorage.users[from].balance = encodeAmount(newFromBalance);
        assetStorage.users[to].balance = encodeAmount(assetStorage.users[to].balance + amount);

        emit Withdraw(assetCache.underlying, from, amount);
        emit Deposit(assetCache.underlying, to, amount);
        emitViaProxy_Transfer(eTokenAddress, from, to, amount);
    }

    function withdrawAmounts(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache,
        address account,
        uint amount
    ) internal view returns (uint, uint) {
        uint amountInternal;
        if (amount == type(uint).max) {
            amountInternal = assetStorage.users[account].balance;
            amount = balanceToUnderlyingAmount(assetCache, amountInternal);
        } else {
            amount = decodeExternalAmount(assetCache, amount);
            amountInternal = underlyingAmountToBalanceRoundUp(assetCache, amount);
        }

        return (amount, amountInternal);
    }

    // Borrows

    // Returns internal precision

    function getCurrentOwedExact(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache,
        address account,
        uint owed
    ) internal view returns (uint) {
        // Don't bother loading the user's accumulator
        if (owed == 0) return 0;

        // Can't divide by 0 here: If owed is non-zero, we must've initialised the user's interestAccumulator
        return
            (owed * assetCache.interestAccumulator) /
            assetStorage.users[account].interestAccumulator;
    }

    // When non-zero, we round *up* to the smallest external unit so that outstanding dust in a loan can be repaid.
    // unchecked is OK here since owed is always loaded from storage, so we know it fits into a uint144 (pre-interest accural)
    // Takes and returns 27 decimals precision.

    function roundUpOwed(AssetCache memory assetCache, uint owed) private pure returns (uint) {
        if (owed == 0) return 0;

        unchecked {
            uint scale = INTERNAL_DEBT_PRECISION * assetCache.underlyingDecimalsScaler;
            return ((owed + scale - 1) / scale) * scale;
        }
    }

    // Returns 18-decimals precision (debt amount is rounded up)

    function getCurrentOwed(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache,
        address account
    ) internal view returns (uint) {
        return
            roundUpOwed(
                assetCache,
                getCurrentOwedExact(
                    assetStorage,
                    assetCache,
                    account,
                    assetStorage.users[account].owed
                )
            ) / INTERNAL_DEBT_PRECISION;
    }

    function updateUserBorrow(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache,
        address account
    ) private returns (uint newOwedExact, uint prevOwedExact) {
        prevOwedExact = assetStorage.users[account].owed;

        newOwedExact = getCurrentOwedExact(assetStorage, assetCache, account, prevOwedExact);

        assetStorage.users[account].owed = encodeDebtAmount(newOwedExact);
        assetStorage.users[account].interestAccumulator = assetCache.interestAccumulator;
    }

    function logBorrowChange(
        AssetCache memory assetCache,
        address dTokenAddress,
        address account,
        uint prevOwed,
        uint owed
    ) private {
        prevOwed = roundUpOwed(assetCache, prevOwed) / INTERNAL_DEBT_PRECISION;
        owed = roundUpOwed(assetCache, owed) / INTERNAL_DEBT_PRECISION;

        if (owed > prevOwed) {
            uint change = owed - prevOwed;
            emit Borrow(assetCache.underlying, account, change);
            emitViaProxy_Transfer(
                dTokenAddress,
                address(0),
                account,
                change / assetCache.underlyingDecimalsScaler
            );
        } else if (prevOwed > owed) {
            uint change = prevOwed - owed;
            emit Repay(assetCache.underlying, account, change);
            emitViaProxy_Transfer(
                dTokenAddress,
                account,
                address(0),
                change / assetCache.underlyingDecimalsScaler
            );
        }
    }

    function increaseBorrow(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache,
        address dTokenAddress,
        address account,
        uint amount
    ) internal {
        amount *= INTERNAL_DEBT_PRECISION;

        require(
            assetCache.pricingType != PRICINGTYPE__FORWARDED ||
                pTokenLookup[assetCache.underlying] == address(0),
            "e/borrow-not-supported"
        );

        (uint owed, uint prevOwed) = updateUserBorrow(assetStorage, assetCache, account);

        if (owed == 0) doEnterMarket(account, assetCache.underlying);

        owed += amount;

        assetStorage.users[account].owed = encodeDebtAmount(owed);
        assetStorage.totalBorrows = assetCache.totalBorrows = encodeDebtAmount(
            assetCache.totalBorrows + amount
        );

        updateInterestRate(assetStorage, assetCache);

        logBorrowChange(assetCache, dTokenAddress, account, prevOwed, owed);
    }

    function decreaseBorrow(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache,
        address dTokenAddress,
        address account,
        uint origAmount
    ) internal {
        uint amount = origAmount * INTERNAL_DEBT_PRECISION;

        (uint owed, uint prevOwed) = updateUserBorrow(assetStorage, assetCache, account);
        uint owedRoundedUp = roundUpOwed(assetCache, owed);

        require(amount <= owedRoundedUp, "e/repay-too-much");
        uint owedRemaining;
        unchecked {
            owedRemaining = owedRoundedUp - amount;
        }

        if (owed > assetCache.totalBorrows) owed = assetCache.totalBorrows;

        assetStorage.users[account].owed = encodeDebtAmount(owedRemaining);
        assetStorage.totalBorrows = assetCache.totalBorrows = encodeDebtAmount(
            assetCache.totalBorrows - owed + owedRemaining
        );

        updateInterestRate(assetStorage, assetCache);

        logBorrowChange(assetCache, dTokenAddress, account, prevOwed, owedRemaining);
    }

    function transferBorrow(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache,
        address dTokenAddress,
        address from,
        address to,
        uint origAmount
    ) internal {
        uint amount = origAmount * INTERNAL_DEBT_PRECISION;

        (uint fromOwed, uint fromOwedPrev) = updateUserBorrow(assetStorage, assetCache, from);
        (uint toOwed, uint toOwedPrev) = updateUserBorrow(assetStorage, assetCache, to);

        if (toOwed == 0) doEnterMarket(to, assetCache.underlying);

        // If amount was rounded up, transfer exact amount owed
        if (
            amount > fromOwed &&
            amount - fromOwed < INTERNAL_DEBT_PRECISION * assetCache.underlyingDecimalsScaler
        ) amount = fromOwed;

        require(fromOwed >= amount, "e/insufficient-balance");
        unchecked {
            fromOwed -= amount;
        }

        // Transfer any residual dust
        if (fromOwed < INTERNAL_DEBT_PRECISION) {
            amount += fromOwed;
            fromOwed = 0;
        }

        toOwed += amount;

        assetStorage.users[from].owed = encodeDebtAmount(fromOwed);
        assetStorage.users[to].owed = encodeDebtAmount(toOwed);

        logBorrowChange(assetCache, dTokenAddress, from, fromOwedPrev, fromOwed);
        logBorrowChange(assetCache, dTokenAddress, to, toOwedPrev, toOwed);
    }

    // Reserves

    function increaseReserves(
        AssetStorage storage assetStorage,
        AssetCache memory assetCache,
        uint amount
    ) internal {
        uint newReserveBalance = assetCache.reserveBalance + amount;
        uint newTotalBalances = assetCache.totalBalances + amount;

        if (newReserveBalance <= MAX_SANE_SMALL_AMOUNT && newTotalBalances <= MAX_SANE_AMOUNT) {
            assetStorage.reserveBalance = assetCache.reserveBalance = encodeSmallAmount(
                newReserveBalance
            );
            assetStorage.totalBalances = assetCache.totalBalances = encodeAmount(newTotalBalances);
        }
    }

    // Token asset transfers

    // amounts are in underlying units

    function pullTokens(
        AssetCache memory assetCache,
        address from,
        uint amount
    ) internal returns (uint amountTransferred) {
        uint poolSizeBefore = assetCache.poolSize;

        Utils.safeTransferFrom(
            assetCache.underlying,
            from,
            address(this),
            amount / assetCache.underlyingDecimalsScaler
        );
        uint poolSizeAfter = assetCache.poolSize = decodeExternalAmount(
            assetCache,
            callBalanceOf(assetCache, address(this))
        );

        require(poolSizeAfter >= poolSizeBefore, "e/negative-transfer-amount");
        unchecked {
            amountTransferred = poolSizeAfter - poolSizeBefore;
        }
    }

    function pushTokens(
        AssetCache memory assetCache,
        address to,
        uint amount
    ) internal returns (uint amountTransferred) {
        uint poolSizeBefore = assetCache.poolSize;

        Utils.safeTransfer(assetCache.underlying, to, amount / assetCache.underlyingDecimalsScaler);
        uint poolSizeAfter = assetCache.poolSize = decodeExternalAmount(
            assetCache,
            callBalanceOf(assetCache, address(this))
        );

        require(poolSizeBefore >= poolSizeAfter, "e/negative-transfer-amount");
        unchecked {
            amountTransferred = poolSizeBefore - poolSizeAfter;
        }
    }

    // Liquidity

    function getAssetPrice(address asset) internal returns (uint) {
        bytes memory result = callInternalModule(
            MODULEID__RISK_MANAGER,
            abi.encodeWithSelector(IRiskManager.getPrice.selector, asset)
        );
        return abi.decode(result, (uint));
    }

    function getAccountLiquidity(
        address account
    ) internal returns (uint collateralValue, uint liabilityValue) {
        bytes memory result = callInternalModule(
            MODULEID__RISK_MANAGER,
            abi.encodeWithSelector(IRiskManager.computeLiquidity.selector, account)
        );
        IRiskManager.LiquidityStatus memory status = abi.decode(
            result,
            (IRiskManager.LiquidityStatus)
        );

        collateralValue = status.collateralValue;
        liabilityValue = status.liabilityValue;
    }

    function checkLiquidity(address account) internal {
        uint8 status = accountLookup[account].deferLiquidityStatus;

        if (status == DEFERLIQUIDITY__NONE) {
            callInternalModule(
                MODULEID__RISK_MANAGER,
                abi.encodeWithSelector(IRiskManager.requireLiquidity.selector, account)
            );
        } else if (status == DEFERLIQUIDITY__CLEAN) {
            accountLookup[account].deferLiquidityStatus = DEFERLIQUIDITY__DIRTY;
        }
    }

    // Optional average liquidity tracking

    function computeNewAverageLiquidity(address account, uint deltaT) private returns (uint) {
        uint currDuration = deltaT >= AVERAGE_LIQUIDITY_PERIOD ? AVERAGE_LIQUIDITY_PERIOD : deltaT;
        uint prevDuration = AVERAGE_LIQUIDITY_PERIOD - currDuration;

        uint currAverageLiquidity;

        {
            (uint collateralValue, uint liabilityValue) = getAccountLiquidity(account);
            currAverageLiquidity = collateralValue > liabilityValue
                ? collateralValue - liabilityValue
                : 0;
        }

        return
            ((accountLookup[account].averageLiquidity * prevDuration) / AVERAGE_LIQUIDITY_PERIOD) +
            ((currAverageLiquidity * currDuration) / AVERAGE_LIQUIDITY_PERIOD);
    }

    function getUpdatedAverageLiquidity(address account) internal returns (uint) {
        uint lastAverageLiquidityUpdate = accountLookup[account].lastAverageLiquidityUpdate;
        if (lastAverageLiquidityUpdate == 0) return 0;

        uint deltaT = block.timestamp - lastAverageLiquidityUpdate;
        if (deltaT == 0) return accountLookup[account].averageLiquidity;

        return computeNewAverageLiquidity(account, deltaT);
    }

    function getUpdatedAverageLiquidityWithDelegate(address account) internal returns (uint) {
        address delegate = accountLookup[account].averageLiquidityDelegate;

        return
            delegate != address(0) && accountLookup[delegate].averageLiquidityDelegate == account
                ? getUpdatedAverageLiquidity(delegate)
                : getUpdatedAverageLiquidity(account);
    }

    function updateAverageLiquidity(address account) internal {
        uint lastAverageLiquidityUpdate = accountLookup[account].lastAverageLiquidityUpdate;
        if (lastAverageLiquidityUpdate == 0) return;

        uint deltaT = block.timestamp - lastAverageLiquidityUpdate;
        if (deltaT == 0) return;

        accountLookup[account].lastAverageLiquidityUpdate = uint40(block.timestamp);
        accountLookup[account].averageLiquidity = computeNewAverageLiquidity(account, deltaT);
    }
}

// File contracts/modules/EToken.sol

pragma solidity ^0.8.0;

/// @notice Tokenised representation of assets
contract EToken is BaseLogic {
    constructor(bytes32 moduleGitCommit_) BaseLogic(MODULEID__ETOKEN, moduleGitCommit_) {}

    function CALLER()
        private
        view
        returns (
            address underlying,
            AssetStorage storage assetStorage,
            address proxyAddr,
            address msgSender
        )
    {
        (msgSender, proxyAddr) = unpackTrailingParams();
        assetStorage = eTokenLookup[proxyAddr];
        underlying = assetStorage.underlying;
        require(underlying != address(0), "e/unrecognized-etoken-caller");
    }

    // Events

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // External methods

    /// @notice Pool name, ie "Euler Pool: DAI"
    function name() external view returns (string memory) {
        (address underlying, , , ) = CALLER();
        return string(abi.encodePacked("Euler Pool: ", IERC20(underlying).name()));
    }

    /// @notice Pool symbol, ie "eDAI"
    function symbol() external view returns (string memory) {
        (address underlying, , , ) = CALLER();
        return string(abi.encodePacked("e", IERC20(underlying).symbol()));
    }

    /// @notice Decimals, always normalised to 18.
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @notice Address of underlying asset
    function underlyingAsset() external view returns (address) {
        (address underlying, , , ) = CALLER();
        return underlying;
    }

    /// @notice Sum of all balances, in internal book-keeping units (non-increasing)
    function totalSupply() external view returns (uint) {
        (address underlying, AssetStorage storage assetStorage, , ) = CALLER();
        AssetCache memory assetCache = loadAssetCacheRO(underlying, assetStorage);

        return assetCache.totalBalances;
    }

    /// @notice Sum of all balances, in underlying units (increases as interest is earned)
    function totalSupplyUnderlying() external view returns (uint) {
        (address underlying, AssetStorage storage assetStorage, , ) = CALLER();
        AssetCache memory assetCache = loadAssetCacheRO(underlying, assetStorage);

        return
            balanceToUnderlyingAmount(assetCache, assetCache.totalBalances) /
            assetCache.underlyingDecimalsScaler;
    }

    /// @notice Balance of a particular account, in internal book-keeping units (non-increasing)
    function balanceOf(address account) external view returns (uint) {
        (, AssetStorage storage assetStorage, , ) = CALLER();

        return assetStorage.users[account].balance;
    }

    /// @notice Balance of a particular account, in underlying units (increases as interest is earned)
    function balanceOfUnderlying(address account) external view returns (uint) {
        (address underlying, AssetStorage storage assetStorage, , ) = CALLER();
        AssetCache memory assetCache = loadAssetCacheRO(underlying, assetStorage);

        return
            balanceToUnderlyingAmount(assetCache, assetStorage.users[account].balance) /
            assetCache.underlyingDecimalsScaler;
    }

    /// @notice Balance of the reserves, in internal book-keeping units (non-increasing)
    function reserveBalance() external view returns (uint) {
        (address underlying, AssetStorage storage assetStorage, , ) = CALLER();
        AssetCache memory assetCache = loadAssetCacheRO(underlying, assetStorage);

        return assetCache.reserveBalance;
    }

    /// @notice Balance of the reserves, in underlying units (increases as interest is earned)
    function reserveBalanceUnderlying() external view returns (uint) {
        (address underlying, AssetStorage storage assetStorage, , ) = CALLER();
        AssetCache memory assetCache = loadAssetCacheRO(underlying, assetStorage);

        return
            balanceToUnderlyingAmount(assetCache, assetCache.reserveBalance) /
            assetCache.underlyingDecimalsScaler;
    }

    /// @notice Convert an eToken balance to an underlying amount, taking into account current exchange rate
    /// @param balance eToken balance, in internal book-keeping units (18 decimals)
    /// @return Amount in underlying units, (same decimals as underlying token)
    function convertBalanceToUnderlying(uint balance) external view returns (uint) {
        (address underlying, AssetStorage storage assetStorage, , ) = CALLER();
        AssetCache memory assetCache = loadAssetCacheRO(underlying, assetStorage);

        return balanceToUnderlyingAmount(assetCache, balance) / assetCache.underlyingDecimalsScaler;
    }

    /// @notice Convert an underlying amount to an eToken balance, taking into account current exchange rate
    /// @param underlyingAmount Amount in underlying units (same decimals as underlying token)
    /// @return eToken balance, in internal book-keeping units (18 decimals)
    function convertUnderlyingToBalance(uint underlyingAmount) external view returns (uint) {
        (address underlying, AssetStorage storage assetStorage, , ) = CALLER();
        AssetCache memory assetCache = loadAssetCacheRO(underlying, assetStorage);

        return
            underlyingAmountToBalance(
                assetCache,
                decodeExternalAmount(assetCache, underlyingAmount)
            );
    }

    /// @notice Updates interest accumulator and totalBorrows, credits reserves, re-targets interest rate, and logs asset status
    function touch() external nonReentrant {
        (address underlying, AssetStorage storage assetStorage, , ) = CALLER();
        AssetCache memory assetCache = loadAssetCache(underlying, assetStorage);

        updateInterestRate(assetStorage, assetCache);

        logAssetStatus(assetCache);
    }

    /// @notice Transfer underlying tokens from sender to the Euler pool, and increase account's eTokens
    /// @param subAccountId 0 for primary, 1-255 for a sub-account
    /// @param amount In underlying units (use max uint256 for full underlying token balance)
    function deposit(uint subAccountId, uint amount) external nonReentrant {
        (
            address underlying,
            AssetStorage storage assetStorage,
            address proxyAddr,
            address msgSender
        ) = CALLER();
        address account = getSubAccount(msgSender, subAccountId);

        updateAverageLiquidity(account);
        emit RequestDeposit(account, amount);

        AssetCache memory assetCache = loadAssetCache(underlying, assetStorage);

        if (amount == type(uint).max) {
            amount = callBalanceOf(assetCache, msgSender);
        }

        amount = decodeExternalAmount(assetCache, amount);

        uint amountTransferred = pullTokens(assetCache, msgSender, amount);
        uint amountInternal;

        // pullTokens() updates poolSize in the cache, but we need the poolSize before the deposit to determine
        // the internal amount so temporarily reduce it by the amountTransferred (which is size checked within
        // pullTokens()). We can't compute this value before the pull because we don't know how much we'll
        // actually receive (the token might be deflationary).

        unchecked {
            assetCache.poolSize -= amountTransferred;
            amountInternal = underlyingAmountToBalance(assetCache, amountTransferred);
            assetCache.poolSize += amountTransferred;
        }

        increaseBalance(assetStorage, assetCache, proxyAddr, account, amountInternal);

        // Depositing a token to an account with pre-existing debt in that token creates a self-collateralized loan
        // which may result in borrow isolation violation if other tokens are also borrowed on the account
        if (assetStorage.users[account].owed != 0) checkLiquidity(account);

        logAssetStatus(assetCache);
    }

    /// @notice Transfer underlying tokens from Euler pool to sender, and decrease account's eTokens
    /// @param subAccountId 0 for primary, 1-255 for a sub-account
    /// @param amount In underlying units (use max uint256 for full pool balance)
    function withdraw(uint subAccountId, uint amount) external nonReentrant {
        (
            address underlying,
            AssetStorage storage assetStorage,
            address proxyAddr,
            address msgSender
        ) = CALLER();
        address account = getSubAccount(msgSender, subAccountId);

        updateAverageLiquidity(account);
        emit RequestWithdraw(account, amount);

        AssetCache memory assetCache = loadAssetCache(underlying, assetStorage);

        uint amountInternal;
        (amount, amountInternal) = withdrawAmounts(assetStorage, assetCache, account, amount);
        require(assetCache.poolSize >= amount, "e/insufficient-pool-size");

        pushTokens(assetCache, msgSender, amount);

        decreaseBalance(assetStorage, assetCache, proxyAddr, account, amountInternal);

        checkLiquidity(account);

        logAssetStatus(assetCache);
    }

    /// @notice Mint eTokens and a corresponding amount of dTokens ("self-borrow")
    /// @param subAccountId 0 for primary, 1-255 for a sub-account
    /// @param amount In underlying units
    function mint(uint subAccountId, uint amount) external nonReentrant {
        (
            address underlying,
            AssetStorage storage assetStorage,
            address proxyAddr,
            address msgSender
        ) = CALLER();
        address account = getSubAccount(msgSender, subAccountId);

        updateAverageLiquidity(account);
        emit RequestMint(account, amount);

        AssetCache memory assetCache = loadAssetCache(underlying, assetStorage);

        amount = decodeExternalAmount(assetCache, amount);
        uint amountInternal = underlyingAmountToBalanceRoundUp(assetCache, amount);
        amount = balanceToUnderlyingAmount(assetCache, amountInternal);

        // Mint ETokens

        increaseBalance(assetStorage, assetCache, proxyAddr, account, amountInternal);

        // Mint DTokens

        increaseBorrow(assetStorage, assetCache, assetStorage.dTokenAddress, account, amount);

        checkLiquidity(account);
        logAssetStatus(assetCache);
    }

    /// @notice Pay off dToken liability with eTokens ("self-repay")
    /// @param subAccountId 0 for primary, 1-255 for a sub-account
    /// @param amount In underlying units (use max uint256 to repay the debt in full or up to the available underlying balance)
    function burn(uint subAccountId, uint amount) external nonReentrant {
        (
            address underlying,
            AssetStorage storage assetStorage,
            address proxyAddr,
            address msgSender
        ) = CALLER();
        address account = getSubAccount(msgSender, subAccountId);

        updateAverageLiquidity(account);
        emit RequestBurn(account, amount);

        AssetCache memory assetCache = loadAssetCache(underlying, assetStorage);

        uint owed = getCurrentOwed(assetStorage, assetCache, account);
        if (owed == 0) return;

        uint amountInternal;
        (amount, amountInternal) = withdrawAmounts(assetStorage, assetCache, account, amount);

        if (amount > owed) {
            amount = owed;
            amountInternal = underlyingAmountToBalanceRoundUp(assetCache, amount);
        }

        // Burn ETokens

        decreaseBalance(assetStorage, assetCache, proxyAddr, account, amountInternal);

        // Burn DTokens

        decreaseBorrow(assetStorage, assetCache, assetStorage.dTokenAddress, account, amount);

        checkLiquidity(account);
        logAssetStatus(assetCache);
    }

    /// @notice Allow spender to access an amount of your eTokens in sub-account 0
    /// @param spender Trusted address
    /// @param amount Use max uint256 for "infinite" allowance
    function approve(address spender, uint amount) external reentrantOK returns (bool) {
        return approveSubAccount(0, spender, amount);
    }

    /// @notice Allow spender to access an amount of your eTokens in a particular sub-account
    /// @param subAccountId 0 for primary, 1-255 for a sub-account
    /// @param spender Trusted address
    /// @param amount Use max uint256 for "infinite" allowance
    function approveSubAccount(
        uint subAccountId,
        address spender,
        uint amount
    ) public nonReentrant returns (bool) {
        (, AssetStorage storage assetStorage, address proxyAddr, address msgSender) = CALLER();
        address account = getSubAccount(msgSender, subAccountId);

        require(!isSubAccountOf(spender, account), "e/self-approval");

        assetStorage.eTokenAllowance[account][spender] = amount;
        emitViaProxy_Approval(proxyAddr, account, spender, amount);

        return true;
    }

    /// @notice Retrieve the current allowance
    /// @param holder Xor with the desired sub-account ID (if applicable)
    /// @param spender Trusted address
    function allowance(address holder, address spender) external view returns (uint) {
        (, AssetStorage storage assetStorage, , ) = CALLER();

        return assetStorage.eTokenAllowance[holder][spender];
    }

    /// @notice Transfer eTokens to another address (from sub-account 0)
    /// @param to Xor with the desired sub-account ID (if applicable)
    /// @param amount In internal book-keeping units (as returned from balanceOf).
    function transfer(address to, uint amount) external reentrantOK returns (bool) {
        return transferFrom(address(0), to, amount);
    }

    /// @notice Transfer the full eToken balance of an address to another
    /// @param from This address must've approved the to address, or be a sub-account of msg.sender
    /// @param to Xor with the desired sub-account ID (if applicable)
    function transferFromMax(address from, address to) external reentrantOK returns (bool) {
        (, AssetStorage storage assetStorage, , ) = CALLER();

        return transferFrom(from, to, assetStorage.users[from].balance);
    }

    /// @notice Transfer eTokens from one address to another
    /// @param from This address must've approved the to address, or be a sub-account of msg.sender
    /// @param to Xor with the desired sub-account ID (if applicable)
    /// @param amount In internal book-keeping units (as returned from balanceOf).
    function transferFrom(
        address from,
        address to,
        uint amount
    ) public nonReentrant returns (bool) {
        (
            address underlying,
            AssetStorage storage assetStorage,
            address proxyAddr,
            address msgSender
        ) = CALLER();

        AssetCache memory assetCache = loadAssetCache(underlying, assetStorage);

        if (from == address(0)) from = msgSender;
        require(from != to, "e/self-transfer");

        updateAverageLiquidity(from);
        updateAverageLiquidity(to);
        emit RequestTransferEToken(from, to, amount);

        if (amount == 0) return true;

        if (
            !isSubAccountOf(msgSender, from) &&
            assetStorage.eTokenAllowance[from][msgSender] != type(uint).max
        ) {
            require(
                assetStorage.eTokenAllowance[from][msgSender] >= amount,
                "e/insufficient-allowance"
            );
            unchecked {
                assetStorage.eTokenAllowance[from][msgSender] -= amount;
            }
            emitViaProxy_Approval(
                proxyAddr,
                from,
                msgSender,
                assetStorage.eTokenAllowance[from][msgSender]
            );
        }

        transferBalance(assetStorage, assetCache, proxyAddr, from, to, amount);

        checkLiquidity(from);

        // Depositing a token to an account with pre-existing debt in that token creates a self-collateralized loan
        // which may result in borrow isolation violation if other tokens are also borrowed on the account
        if (assetStorage.users[to].owed != 0) checkLiquidity(to);

        logAssetStatus(assetCache);

        return true;
    }

    /// @notice Donate eTokens to the reserves
    /// @param subAccountId 0 for primary, 1-255 for a sub-account
    /// @param amount In internal book-keeping units (as returned from balanceOf).
    function donateToReserves(uint subAccountId, uint amount) external nonReentrant {
        (
            address underlying,
            AssetStorage storage assetStorage,
            address proxyAddr,
            address msgSender
        ) = CALLER();
        address account = getSubAccount(msgSender, subAccountId);

        updateAverageLiquidity(account);
        emit RequestDonate(account, amount);

        AssetCache memory assetCache = loadAssetCache(underlying, assetStorage);

        uint origBalance = assetStorage.users[account].balance;
        uint newBalance;

        if (amount == type(uint).max) {
            amount = origBalance;
            newBalance = 0;
        } else {
            require(origBalance >= amount, "e/insufficient-balance");
            unchecked {
                newBalance = origBalance - amount;
            }
        }

        assetStorage.users[account].balance = encodeAmount(newBalance);
        assetStorage.reserveBalance = assetCache.reserveBalance = encodeSmallAmount(
            assetCache.reserveBalance + amount
        );

        emit Withdraw(assetCache.underlying, account, amount);
        emitViaProxy_Transfer(proxyAddr, account, address(0), amount);

        logAssetStatus(assetCache);
    }
}

// File contracts/PToken.sol

pragma solidity ^0.8.0;

/// @notice Protected Tokens are simple wrappers for tokens, allowing you to use tokens as collateral without permitting borrowing
contract PToken {
    address immutable euler;
    address immutable underlyingToken;

    constructor(address euler_, address underlying_) {
        euler = euler_;
        underlyingToken = underlying_;
    }

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowances;
    uint totalBalances;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    /// @notice PToken name, ie "Euler Protected DAI"
    function name() external view returns (string memory) {
        return string(abi.encodePacked("Euler Protected ", IERC20(underlyingToken).name()));
    }

    /// @notice PToken symbol, ie "pDAI"
    function symbol() external view returns (string memory) {
        return string(abi.encodePacked("p", IERC20(underlyingToken).symbol()));
    }

    /// @notice Number of decimals, which is same as the underlying's
    function decimals() external view returns (uint8) {
        return IERC20(underlyingToken).decimals();
    }

    /// @notice Address of the underlying asset
    function underlying() external view returns (address) {
        return underlyingToken;
    }

    /// @notice Balance of an account's wrapped tokens
    function balanceOf(address who) external view returns (uint) {
        return balances[who];
    }

    /// @notice Sum of all wrapped token balances
    function totalSupply() external view returns (uint) {
        return totalBalances;
    }

    /// @notice Retrieve the current allowance
    /// @param holder Address giving permission to access tokens
    /// @param spender Trusted address
    function allowance(address holder, address spender) external view returns (uint) {
        return allowances[holder][spender];
    }

    /// @notice Transfer your own pTokens to another address
    /// @param recipient Recipient address
    /// @param amount Amount of wrapped token to transfer
    function transfer(address recipient, uint amount) external returns (bool) {
        return transferFrom(msg.sender, recipient, amount);
    }

    /// @notice Transfer pTokens from one address to another. The euler address is automatically granted approval.
    /// @param from This address must've approved the to address
    /// @param recipient Recipient address
    /// @param amount Amount to transfer
    function transferFrom(address from, address recipient, uint amount) public returns (bool) {
        require(balances[from] >= amount, "insufficient balance");
        if (
            from != msg.sender &&
            msg.sender != euler &&
            allowances[from][msg.sender] != type(uint).max
        ) {
            require(allowances[from][msg.sender] >= amount, "insufficient allowance");
            allowances[from][msg.sender] -= amount;
            emit Approval(from, msg.sender, allowances[from][msg.sender]);
        }
        balances[from] -= amount;
        balances[recipient] += amount;
        emit Transfer(from, recipient, amount);
        return true;
    }

    /// @notice Allow spender to access an amount of your pTokens. It is not necessary to approve the euler address.
    /// @param spender Trusted address
    /// @param amount Use max uint256 for "infinite" allowance
    function approve(address spender, uint amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Convert underlying tokens to pTokens
    /// @param amount In underlying units (which are equivalent to pToken units)
    function wrap(uint amount) external {
        Utils.safeTransferFrom(underlyingToken, msg.sender, address(this), amount);
        claimSurplus(msg.sender);
    }

    /// @notice Convert pTokens to underlying tokens
    /// @param amount In pToken units (which are equivalent to underlying units)
    function unwrap(uint amount) external {
        doUnwrap(msg.sender, amount);
    }

    // Only callable by the euler contract:
    function forceUnwrap(address who, uint amount) external {
        require(msg.sender == euler, "permission denied");
        doUnwrap(who, amount);
    }

    /// @notice Claim any surplus tokens held by the PToken contract. This should only be used by contracts.
    /// @param who Beneficiary to be credited for the surplus token amount
    function claimSurplus(address who) public {
        uint currBalance = IERC20(underlyingToken).balanceOf(address(this));
        require(currBalance > totalBalances, "no surplus balance to claim");

        uint amount = currBalance - totalBalances;

        totalBalances += amount;
        balances[who] += amount;
        emit Transfer(address(0), who, amount);
    }

    // Internal shared:

    function doUnwrap(address who, uint amount) private {
        require(balances[who] >= amount, "insufficient balance");

        totalBalances -= amount;
        balances[who] -= amount;

        Utils.safeTransfer(underlyingToken, who, amount);
        emit Transfer(who, address(0), amount);
    }
}

// File contracts/modules/Markets.sol

pragma solidity ^0.8.0;

/// @notice Activating and querying markets, and maintaining entered markets lists
contract Markets is BaseLogic {
    constructor(bytes32 moduleGitCommit_) BaseLogic(MODULEID__MARKETS, moduleGitCommit_) {}

    /// @notice Create an Euler pool and associated EToken and DToken addresses.
    /// @param underlying The address of an ERC20-compliant token. There must be an initialised uniswap3 pool for the underlying/reference asset pair.
    /// @return The created EToken, or the existing EToken if already activated.
    function activateMarket(address underlying) external nonReentrant returns (address) {
        require(pTokenLookup[underlying] == address(0), "e/markets/invalid-token");
        return doActivateMarket(underlying);
    }

    function doActivateMarket(address underlying) private returns (address) {
        // Pre-existing

        if (underlyingLookup[underlying].eTokenAddress != address(0))
            return underlyingLookup[underlying].eTokenAddress;

        // Validation

        require(
            trustedSenders[underlying].moduleId == 0 && underlying != address(this),
            "e/markets/invalid-token"
        );

        uint8 decimals = IERC20(underlying).decimals();
        require(decimals <= 18, "e/too-many-decimals");

        // Get risk manager parameters

        IRiskManager.NewMarketParameters memory params;

        {
            bytes memory result = callInternalModule(
                MODULEID__RISK_MANAGER,
                abi.encodeWithSelector(IRiskManager.getNewMarketParameters.selector, underlying)
            );
            (params) = abi.decode(result, (IRiskManager.NewMarketParameters));
        }

        // Create proxies

        address childEToken = params.config.eTokenAddress = _createProxy(MODULEID__ETOKEN);
        address childDToken = _createProxy(MODULEID__DTOKEN);

        // Setup storage

        underlyingLookup[underlying] = params.config;

        dTokenLookup[childDToken] = childEToken;

        AssetStorage storage assetStorage = eTokenLookup[childEToken];

        assetStorage.underlying = underlying;
        assetStorage.pricingType = params.pricingType;
        assetStorage.pricingParameters = params.pricingParameters;

        assetStorage.dTokenAddress = childDToken;

        assetStorage.lastInterestAccumulatorUpdate = uint40(block.timestamp);
        assetStorage.underlyingDecimals = decimals;
        assetStorage.interestRateModel = uint32(MODULEID__IRM_DEFAULT);
        assetStorage.reserveFee = type(uint32).max; // default

        {
            assetStorage.reserveBalance = encodeSmallAmount(INITIAL_RESERVES);
            assetStorage.totalBalances = encodeAmount(INITIAL_RESERVES);
        }

        assetStorage.interestAccumulator = INITIAL_INTEREST_ACCUMULATOR;

        emit MarketActivated(underlying, childEToken, childDToken);

        return childEToken;
    }

    /// @notice Create a pToken and activate it on Euler. pTokens are protected wrappers around assets that prevent borrowing.
    /// @param underlying The address of an ERC20-compliant token. There must already be an activated market on Euler for this underlying, and it must have a non-zero collateral factor.
    /// @return The created pToken, or an existing one if already activated.
    function activatePToken(address underlying) external nonReentrant returns (address) {
        require(pTokenLookup[underlying] == address(0), "e/nested-ptoken");

        if (reversePTokenLookup[underlying] != address(0)) return reversePTokenLookup[underlying];

        {
            AssetConfig memory config = resolveAssetConfig(underlying);
            require(config.collateralFactor != 0, "e/ptoken/not-collateral");
        }

        address pTokenAddr = address(new PToken(address(this), underlying));

        pTokenLookup[pTokenAddr] = underlying;
        reversePTokenLookup[underlying] = pTokenAddr;

        emit PTokenActivated(underlying, pTokenAddr);

        doActivateMarket(pTokenAddr);

        return pTokenAddr;
    }

    // General market accessors

    /// @notice Given an underlying, lookup the associated EToken
    /// @param underlying Token address
    /// @return EToken address, or address(0) if not activated
    function underlyingToEToken(address underlying) external view returns (address) {
        return underlyingLookup[underlying].eTokenAddress;
    }

    /// @notice Given an underlying, lookup the associated DToken
    /// @param underlying Token address
    /// @return DToken address, or address(0) if not activated
    function underlyingToDToken(address underlying) external view returns (address) {
        return eTokenLookup[underlyingLookup[underlying].eTokenAddress].dTokenAddress;
    }

    /// @notice Given an underlying, lookup the associated PToken
    /// @param underlying Token address
    /// @return PToken address, or address(0) if it doesn't exist
    function underlyingToPToken(address underlying) external view returns (address) {
        return reversePTokenLookup[underlying];
    }

    /// @notice Looks up the Euler-related configuration for a token, and resolves all default-value placeholders to their currently configured values.
    /// @param underlying Token address
    /// @return Configuration struct
    function underlyingToAssetConfig(
        address underlying
    ) external view returns (AssetConfig memory) {
        return resolveAssetConfig(underlying);
    }

    /// @notice Looks up the Euler-related configuration for a token, and returns it unresolved (with default-value placeholders)
    /// @param underlying Token address
    /// @return config Configuration struct
    function underlyingToAssetConfigUnresolved(
        address underlying
    ) external view returns (AssetConfig memory config) {
        config = underlyingLookup[underlying];
        require(config.eTokenAddress != address(0), "e/market-not-activated");
    }

    /// @notice Given an EToken address, looks up the associated underlying
    /// @param eToken EToken address
    /// @return underlying Token address
    function eTokenToUnderlying(address eToken) external view returns (address underlying) {
        underlying = eTokenLookup[eToken].underlying;
        require(underlying != address(0), "e/invalid-etoken");
    }

    /// @notice Given a DToken address, looks up the associated underlying
    /// @param dToken DToken address
    /// @return underlying Token address
    function dTokenToUnderlying(address dToken) external view returns (address underlying) {
        address eToken = dTokenLookup[dToken];
        require(eToken != address(0), "e/invalid-dtoken");
        return eTokenLookup[eToken].underlying;
    }

    /// @notice Given an EToken address, looks up the associated DToken
    /// @param eToken EToken address
    /// @return dTokenAddr DToken address
    function eTokenToDToken(address eToken) external view returns (address dTokenAddr) {
        dTokenAddr = eTokenLookup[eToken].dTokenAddress;
        require(dTokenAddr != address(0), "e/invalid-etoken");
    }

    function getAssetStorage(address underlying) private view returns (AssetStorage storage) {
        address eTokenAddr = underlyingLookup[underlying].eTokenAddress;
        require(eTokenAddr != address(0), "e/market-not-activated");
        return eTokenLookup[eTokenAddr];
    }

    /// @notice Looks up an asset's currently configured interest rate model
    /// @param underlying Token address
    /// @return Module ID that represents the interest rate model (IRM)
    function interestRateModel(address underlying) external view returns (uint) {
        AssetStorage storage assetStorage = getAssetStorage(underlying);

        return assetStorage.interestRateModel;
    }

    /// @notice Retrieves the current interest rate for an asset
    /// @param underlying Token address
    /// @return The interest rate in yield-per-second, scaled by 10**27
    function interestRate(address underlying) external view returns (int96) {
        AssetStorage storage assetStorage = getAssetStorage(underlying);

        return assetStorage.interestRate;
    }

    /// @notice Retrieves the current interest rate accumulator for an asset
    /// @param underlying Token address
    /// @return An opaque accumulator that increases as interest is accrued
    function interestAccumulator(address underlying) external view returns (uint) {
        AssetStorage storage assetStorage = getAssetStorage(underlying);
        AssetCache memory assetCache = loadAssetCacheRO(underlying, assetStorage);

        return assetCache.interestAccumulator;
    }

    /// @notice Retrieves the reserve fee in effect for an asset
    /// @param underlying Token address
    /// @return Amount of interest that is redirected to the reserves, as a fraction scaled by RESERVE_FEE_SCALE (4e9)
    function reserveFee(address underlying) external view returns (uint32) {
        AssetStorage storage assetStorage = getAssetStorage(underlying);

        return
            assetStorage.reserveFee == type(uint32).max
                ? uint32(DEFAULT_RESERVE_FEE)
                : assetStorage.reserveFee;
    }

    /// @notice Retrieves the pricing config for an asset
    /// @param underlying Token address
    /// @return pricingType (1=pegged, 2=uniswap3, 3=forwarded, 4=chainlink)
    /// @return pricingParameters If uniswap3 pricingType then this represents the uniswap pool fee used, if chainlink pricing type this represents the fallback uniswap pool fee or 0 if none
    /// @return pricingForwarded If forwarded pricingType then this is the address prices are forwarded to, otherwise address(0)
    function getPricingConfig(
        address underlying
    )
        external
        view
        returns (uint16 pricingType, uint32 pricingParameters, address pricingForwarded)
    {
        AssetStorage storage assetStorage = getAssetStorage(underlying);

        pricingType = assetStorage.pricingType;
        pricingParameters = assetStorage.pricingParameters;

        pricingForwarded = pricingType == PRICINGTYPE__FORWARDED
            ? pTokenLookup[underlying]
            : address(0);
    }

    /// @notice Retrieves the Chainlink price feed config for an asset
    /// @param underlying Token address
    /// @return chainlinkAggregator Chainlink aggregator proxy address
    function getChainlinkPriceFeedConfig(
        address underlying
    ) external view returns (address chainlinkAggregator) {
        chainlinkAggregator = chainlinkPriceFeedLookup[underlying];
    }

    // Enter/exit markets

    /// @notice Retrieves the list of entered markets for an account (assets enabled for collateral or borrowing)
    /// @param account User account
    /// @return List of underlying token addresses
    function getEnteredMarkets(address account) external view returns (address[] memory) {
        return getEnteredMarketsArray(account);
    }

    /// @notice Add an asset to the entered market list, or do nothing if already entered
    /// @param subAccountId 0 for primary, 1-255 for a sub-account
    /// @param newMarket Underlying token address
    function enterMarket(uint subAccountId, address newMarket) external nonReentrant {
        address msgSender = unpackTrailingParamMsgSender();
        address account = getSubAccount(msgSender, subAccountId);

        require(underlyingLookup[newMarket].eTokenAddress != address(0), "e/market-not-activated");

        doEnterMarket(account, newMarket);
    }

    /// @notice Remove an asset from the entered market list, or do nothing if not already present
    /// @param subAccountId 0 for primary, 1-255 for a sub-account
    /// @param oldMarket Underlying token address
    function exitMarket(uint subAccountId, address oldMarket) external nonReentrant {
        address msgSender = unpackTrailingParamMsgSender();
        address account = getSubAccount(msgSender, subAccountId);

        AssetConfig memory config = resolveAssetConfig(oldMarket);
        AssetStorage storage assetStorage = eTokenLookup[config.eTokenAddress];

        uint balance = assetStorage.users[account].balance;
        uint owed = assetStorage.users[account].owed;

        require(owed == 0, "e/outstanding-borrow");

        doExitMarket(account, oldMarket);

        if (config.collateralFactor != 0 && balance != 0) {
            checkLiquidity(account);
        }
    }
}

// File contracts/views/EulerGeneralView.sol

pragma solidity ^0.8.0;

interface IExec {
    function getPriceFull(
        address underlying
    ) external view returns (uint twap, uint twapPeriod, uint currPrice);

    function getPrice(address underlying) external view returns (uint twap, uint twapPeriod);

    function detailedLiquidity(
        address account
    ) external view returns (IRiskManager.AssetLiquidity[] memory assets);

    function liquidity(
        address account
    ) external view returns (IRiskManager.LiquidityStatus memory status);
}

// SPDX-License-Identifier: GPL-2.0-or-later

contract EulerGeneralView is Constants {
    bytes32 public immutable moduleGitCommit;

    constructor(bytes32 moduleGitCommit_) {
        moduleGitCommit = moduleGitCommit_;
    }

    // Query

    struct Query {
        address eulerContract;
        address account;
        address[] markets;
    }

    // Response

    struct ResponseMarket {
        // Universal

        address underlying;
        string name;
        string symbol;
        uint8 decimals;
        address eTokenAddr;
        address dTokenAddr;
        address pTokenAddr;
        Storage.AssetConfig config;
        uint poolSize;
        uint totalBalances;
        uint totalBorrows;
        uint reserveBalance;
        uint32 reserveFee;
        uint borrowAPY;
        uint supplyAPY;
        // Pricing

        uint twap;
        uint twapPeriod;
        uint currPrice;
        uint16 pricingType;
        uint32 pricingParameters;
        address pricingForwarded;
        // Account specific

        uint underlyingBalance;
        uint eulerAllowance;
        uint eTokenBalance;
        uint eTokenBalanceUnderlying;
        uint dTokenBalance;
        IRiskManager.LiquidityStatus liquidityStatus;
    }

    struct Response {
        uint timestamp;
        uint blockNumber;
        ResponseMarket[] markets;
        address[] enteredMarkets;
    }

    // Implementation

    function doQueryBatch(Query[] memory qs) external view returns (Response[] memory r) {
        r = new Response[](qs.length);

        for (uint i = 0; i < qs.length; ++i) {
            r[i] = doQuery(qs[i]);
        }
    }

    function doQuery(Query memory q) public view returns (Response memory r) {
        r.timestamp = block.timestamp;
        r.blockNumber = block.number;

        Euler eulerProxy = Euler(q.eulerContract);

        Markets marketsProxy = Markets(eulerProxy.moduleIdToProxy(MODULEID__MARKETS));
        IExec execProxy = IExec(eulerProxy.moduleIdToProxy(MODULEID__EXEC));

        IRiskManager.AssetLiquidity[] memory liqs;

        if (q.account != address(0)) {
            liqs = execProxy.detailedLiquidity(q.account);
        }

        r.markets = new ResponseMarket[](liqs.length + q.markets.length);

        for (uint i = 0; i < liqs.length; ++i) {
            ResponseMarket memory m = r.markets[i];

            m.underlying = liqs[i].underlying;
            m.liquidityStatus = liqs[i].status;

            populateResponseMarket(q, m, marketsProxy, execProxy);
        }

        for (uint j = liqs.length; j < liqs.length + q.markets.length; ++j) {
            uint i = j - liqs.length;
            ResponseMarket memory m = r.markets[j];

            m.underlying = q.markets[i];

            populateResponseMarket(q, m, marketsProxy, execProxy);
        }

        if (q.account != address(0)) {
            r.enteredMarkets = marketsProxy.getEnteredMarkets(q.account);
        }
    }

    function populateResponseMarket(
        Query memory q,
        ResponseMarket memory m,
        Markets marketsProxy,
        IExec execProxy
    ) private view {
        m.name = getStringOrBytes32(m.underlying, IERC20.name.selector);
        m.symbol = getStringOrBytes32(m.underlying, IERC20.symbol.selector);

        m.decimals = IERC20(m.underlying).decimals();

        m.eTokenAddr = marketsProxy.underlyingToEToken(m.underlying);
        if (m.eTokenAddr == address(0)) return; // not activated

        m.dTokenAddr = marketsProxy.eTokenToDToken(m.eTokenAddr);
        m.pTokenAddr = marketsProxy.underlyingToPToken(m.underlying);

        {
            Storage.AssetConfig memory c = marketsProxy.underlyingToAssetConfig(m.underlying);
            m.config = c;
        }

        m.poolSize = IERC20(m.underlying).balanceOf(q.eulerContract);
        m.totalBalances = EToken(m.eTokenAddr).totalSupplyUnderlying();
        m.totalBorrows = IERC20(m.dTokenAddr).totalSupply();
        m.reserveBalance = EToken(m.eTokenAddr).reserveBalanceUnderlying();

        m.reserveFee = marketsProxy.reserveFee(m.underlying);

        {
            uint borrowSPY = uint(int(marketsProxy.interestRate(m.underlying)));
            (m.borrowAPY, m.supplyAPY) = computeAPYs(
                borrowSPY,
                m.totalBorrows,
                m.totalBalances,
                m.reserveFee
            );
        }

        (m.twap, m.twapPeriod, m.currPrice) = execProxy.getPriceFull(m.underlying);
        (m.pricingType, m.pricingParameters, m.pricingForwarded) = marketsProxy.getPricingConfig(
            m.underlying
        );

        if (q.account == address(0)) return;

        m.underlyingBalance = IERC20(m.underlying).balanceOf(q.account);
        m.eTokenBalance = IERC20(m.eTokenAddr).balanceOf(q.account);
        m.eTokenBalanceUnderlying = EToken(m.eTokenAddr).balanceOfUnderlying(q.account);
        m.dTokenBalance = IERC20(m.dTokenAddr).balanceOf(q.account);
        m.eulerAllowance = IERC20(m.underlying).allowance(q.account, q.eulerContract);
    }

    function computeAPYs(
        uint borrowSPY,
        uint totalBorrows,
        uint totalBalancesUnderlying,
        uint32 reserveFee
    ) public pure returns (uint borrowAPY, uint supplyAPY) {
        borrowAPY = RPow.rpow(borrowSPY + 1e27, SECONDS_PER_YEAR, 10 ** 27) - 1e27;

        uint supplySPY = totalBalancesUnderlying == 0
            ? 0
            : (borrowSPY * totalBorrows) / totalBalancesUnderlying;
        supplySPY = (supplySPY * (RESERVE_FEE_SCALE - reserveFee)) / RESERVE_FEE_SCALE;
        supplyAPY = RPow.rpow(supplySPY + 1e27, SECONDS_PER_YEAR, 10 ** 27) - 1e27;
    }

    // Interest rate model queries

    struct QueryIRM {
        address eulerContract;
        address underlying;
    }

    struct ResponseIRM {
        uint kink;
        uint baseAPY;
        uint kinkAPY;
        uint maxAPY;
        uint baseSupplyAPY;
        uint kinkSupplyAPY;
        uint maxSupplyAPY;
    }

    function doQueryIRM(QueryIRM memory q) external view returns (ResponseIRM memory r) {
        Euler eulerProxy = Euler(q.eulerContract);
        Markets marketsProxy = Markets(eulerProxy.moduleIdToProxy(MODULEID__MARKETS));

        uint moduleId = marketsProxy.interestRateModel(q.underlying);
        address moduleImpl = eulerProxy.moduleIdToImplementation(moduleId);

        BaseIRMLinearKink irm = BaseIRMLinearKink(moduleImpl);

        uint kink = r.kink = irm.kink();
        uint32 reserveFee = marketsProxy.reserveFee(q.underlying);

        uint baseSPY = irm.baseRate();
        uint kinkSPY = baseSPY + (kink * irm.slope1());
        uint maxSPY = kinkSPY + ((type(uint32).max - kink) * irm.slope2());

        (r.baseAPY, r.baseSupplyAPY) = computeAPYs(baseSPY, 0, type(uint32).max, reserveFee);
        (r.kinkAPY, r.kinkSupplyAPY) = computeAPYs(kinkSPY, kink, type(uint32).max, reserveFee);
        (r.maxAPY, r.maxSupplyAPY) = computeAPYs(
            maxSPY,
            type(uint32).max,
            type(uint32).max,
            reserveFee
        );
    }

    // AccountLiquidity queries

    struct ResponseAccountLiquidity {
        IRiskManager.AssetLiquidity[] markets;
    }

    function doQueryAccountLiquidity(
        address eulerContract,
        address[] memory addrs
    ) external view returns (ResponseAccountLiquidity[] memory r) {
        Euler eulerProxy = Euler(eulerContract);
        IExec execProxy = IExec(eulerProxy.moduleIdToProxy(MODULEID__EXEC));

        r = new ResponseAccountLiquidity[](addrs.length);

        for (uint i = 0; i < addrs.length; ++i) {
            r[i].markets = execProxy.detailedLiquidity(addrs[i]);
        }
    }

    // For tokens like MKR which return bytes32 on name() or symbol()

    function getStringOrBytes32(
        address contractAddress,
        bytes4 selector
    ) private view returns (string memory) {
        (bool success, bytes memory result) = contractAddress.staticcall(
            abi.encodeWithSelector(selector)
        );
        if (!success) return "";

        return
            result.length == 32 ? string(abi.encodePacked(result)) : abi.decode(result, (string));
    }
}
