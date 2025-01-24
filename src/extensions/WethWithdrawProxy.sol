import { IWethWithdrawProxy } from "./IWethWithdrawProxy.sol";
import { IWETH } from  "@hmx/interfaces/aerodrome/IWETH.sol";
import { Ownable } from  "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WethWithdrawProxy is Ownable, IWethWithdrawProxy {
    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;

    IWETH public weth;
    mapping(address => bool) public isExecutor;

    modifier onlyExecutor() {
        if (!isExecutor[msg.sender]) revert WethWithdrawProxy_NotExecutor();
        _;
    }

    receive() external payable {}

    function transferEth(address to, uint256 amount) external onlyExecutor {
        (bool success,) = to.call{value: amount}("");
        require(success, "Forwarding failed");
    }

    function transferErc20(address token, address to, uint256 amount) external onlyExecutor {
        IERC20(token).safeTransfer(to, amount);
    }

    function withdrawEth(address payable to, uint256 amount) external onlyExecutor {
        weth.withdraw(amount);
        (bool success,) = to.call{value: amount}("");
        require(success, "Forwarding failed");
    }

    function swapWethToEth(address from, address payable to, uint256 amount) external onlyExecutor {
        if (weth.allowance(from, address(this)) < amount) {
            revert WethWithdrawProxy_AllowanceNotEnough();
        }
        weth.safeTransferFrom(from, address(this), amount);
        weth.withdraw(amount);
        (bool success,) = to.call{value: amount}("");
        require(success, "Forwarding failed");
    }

    function setWeth(address _weth) external onlyOwner {
        weth = IWETH(_weth);
    }

    function setIsExecutors(
        address[] memory executors,
        bool[] memory _isExecutor
    ) external onlyOwner {
        uint256 length = executors.length;
        if (length != _isExecutor.length) revert WethWithdrawProxy_InconsistentLength();

        for (uint256 i; i < length;) {
            if (executors[i] == address(0)) revert WethWithdrawProxy_InvalidAddress();

            isExecutor[executors[i]] = _isExecutor[i];
            emit LogSetExecutor(executors[i], _isExecutor[i]);
            unchecked {
                ++i;
            }
        }
    }

}