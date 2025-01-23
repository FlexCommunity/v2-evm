import  { Ownable } from  "@openzeppelin/contracts/access/Ownable.sol";
import { IWETH } from  "@hmx/interfaces/aerodrome/IWETH.sol";

interface IWethWithdrawProxy {
    event LogSetExecutor(address indexed executor, bool isExecutor);

    error WethWithdrawProxy_NotExecutor();
    error WethWithdrawProxy_InconsistentLength();
    error WethWithdrawProxy_InvalidAddress();
    error WethWithdrawProxy_AllowanceNotEnough();

    function weth() external view returns (IWETH weth);
    function withdrawEth(address payable to, uint256 amount) external;

}