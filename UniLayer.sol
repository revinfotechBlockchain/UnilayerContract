pragma solidity ^0.6.6;

//////////////////////////////////////////////////////////////////////////////////
//                       UNILAYER ORDER MANAGEMENT CONTRACT                     //
//                   Description : Managing orders with uniswap                 //
//                   Order Book, Order Processing, Order Status                 //
//////////////////////////////////////////////////////////////////////////////////


////////////////////////// Safe maths /////////////////////////////////////////////

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error.
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b,"Invalid values");
        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0,"Invalid values");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a,"Invalid values");
        uint256 c = a - b;
        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a,"Invalid values");
        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0,"Invalid values");
        return a % b;
    }
}


/////////////////Uniswap factor functions as interface for working managing order with uniswap /////////////////

// Dependency file: @uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

//---------------------------------Interface for the v2 Router1 functions for uniswap-----------------//

// Dependency file: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol
interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

//------------------------------------- Helper Library For Transfers------------------------------------//

// Dependency file: @uniswap/lib/contracts/libraries/TransferHelper.sol

library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }
    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

//---------------------------------Interface for the v2 Router2 functions for uniswap-----------------//

//Dependency file: uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol
interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


// Dependency file: @openzeppelin/contracts/utils/ReentrancyGuard.sol
/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}


abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

//Functions for only owner 

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


//-------------------------------------Order Management Using Unilayer Order Manager----------------------------------//

// Dependency file: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol
// Dependency file: @openzeppelin/contracts/math/SafeMath.sol
// Dependency file: @openzeppelin/contracts/access/Ownable.sol
// Dependency file: @uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol
// Dependency file: @openzeppelin/contracts/utils/ReentrancyGuard.sol
// Dependency file: @uniswap/lib/contracts/libraries/TransferHelper.sol

contract UniLayerOrderManager is ReentrancyGuard, Ownable{
    using SafeMath for uint256;

    IUniStaker public staker;
    IUniswapV2Factory public immutable uniswapFactoryV2;
    IUniswapV2Router02 public immutable uniswapRouterV2;
    uint256 constant UINT256_MAX = ~uint256(0);
    
    enum OrderStateData {Placed, Cancelled, Executed}
    enum OrderTypeData {TokensForTokens, EthForTokens, TokensForEth}
    

    struct Order {
        OrderTypeData orderType;
        address payable maker;
        address tokenIn;
        address tokenOut;
        uint256 amountInOffered;
        uint256 amountOutExpected;
        uint256 executorFee;
        uint256 totalEthDeposited;
        uint256 activeOrderIndex;
        OrderStateData orderState;
    }

    uint256 private orderNumber;
    uint256[] private activeOrders;
    mapping(uint256 => Order) private orders;
    mapping(address => uint256[]) private ordersForAddress;

    event PlacedOrder(
        uint256 indexed orderId,
        OrderTypeData orderType,
        address payable indexed maker,
        address tokenIn,
        address tokenOut,
        uint256 amountInOffered,
        uint256 amountOutExpected,
        uint256 executorFee,
        uint256 totalEthDeposited
    );
    event CancelledOrder(uint256 indexed orderId);
    event ExecutedOrder(uint256 indexed orderId,address indexed executor,uint256[] amounts,uint256 uniLayerFee);
    event UpdatedStaker(address newStaker);

    modifier exists(uint256 orderId) {
        require(orders[orderId].maker != address(0), "This order doent exists");
        _;
    }

    constructor(IUniswapV2Router02 _uniswapV2Router,IUniLayerStaker _staker) public {
        uniswapRouterV2 = _uniswapV2Router;
        uniswapFactoryV2 = IUniswapV2Factory(_uniswapV2Router.factory());
        staker = _staker;
    }

    function updateStaker(IUniLayerStaker newStaker) external onlyOwner {
        staker = newStaker;
        emit UpdatedStaker(address(newStaker));
    }

    function createPair(address tokenA, address tokenB)internal pure returns (address[] memory){
        address[] memory _addressPair = new address[](2);
        _addressPair[0] = tokenA;
        _addressPair[1] = tokenB;
        return _addressPair;
    }

    function getActiveOrdersLength() external view returns(uint256){
        return activeOrders.length;
    }

    function getActiveOrderIdNumber(uint256 index) external view returns(uint256){
        return activeOrders[index];
    }

    function getOrdersByAddressLength(address _address)external view returns(uint256){
        return ordersForAddress[_address].length;
    }

    function getOrderIdByAddress(address _address, uint256 index) external view returns (uint256){
        return ordersForAddress[_address][index];
    }

    function updateOrder(uint256 orderId,uint256 amountInOffered,uint256 amountOutExpected,uint256 executorFee) external payable exists(orderId) nonReentrant returns (bool) {
        Order memory _updatingOrder = orders[orderId];
        require(msg.sender == _updatingOrder.maker, "Not Permitted");
        require(_updatingOrder.orderState == OrderStateData.Placed,"Order cannt be updated");
        require(amountInOffered > 0, "Amount Offered is Invalid");
        require(amountOutExpected > 0, "Expected Amount is Invalid");
        require(executorFee > 0, "Executor Fees is Invalid");

        if (_updatingOrder.orderType == OrderTypeData.EthForTokens) {
            uint256 newTotal = amountInOffered.add(executorFee);
            if (newTotal > _updatingOrder.totalEthDeposited) {
                require(msg.value == newTotal.sub(_updatingOrder.totalEthDeposited),"Additional deposit must match");
            } else if (newTotal < _updatingOrder.totalEthDeposited) {
                TransferHelper.safeTransferETH(
                    _updatingOrder.maker,
                    _updatingOrder.totalEthDeposited.sub(newTotal)
                );
            }
            _updatingOrder.totalEthDeposited = newTotal;
        } else {
            if (executorFee > _updatingOrder.executorFee) {
                require(msg.value == executorFee.sub(_updatingOrder.executorFee),"Additional fee must match");
            } else if (executorFee < _updatingOrder.executorFee) {
                TransferHelper.safeTransferETH(_updatingOrder.maker,
                    _updatingOrder.executorFee.sub(executorFee)
                );
            }
            _updatingOrder.totalEthDeposited = executorFee;
            if (amountInOffered > _updatingOrder.amountInOffered) {
                TransferHelper.safeTransferFrom(_updatingOrder.tokenIn,msg.sender,address(this),
                    amountInOffered.sub(_updatingOrder.amountInOffered)
                );
            } else if (amountInOffered < _updatingOrder.amountInOffered) {
                TransferHelper.safeTransfer(_updatingOrder.tokenIn,_updatingOrder.maker,
                    _updatingOrder.amountInOffered.sub(amountInOffered)
                );
            }
        }
        _updatingOrder.amountInOffered = amountInOffered;
        _updatingOrder.amountOutExpected = amountOutExpected;
        _updatingOrder.executorFee = executorFee;
        orders[orderId] = _updatingOrder;

        return true;
    }

    function cancelOrder(uint256 orderId)external exists(orderId) nonReentrant returns (bool) {
        Order memory _cancellingOrder = orders[orderId];
        require(msg.sender == _cancellingOrder.maker, "Permission denied");
        require(_cancellingOrder.orderState == OrderStateData.Placed,"Cannot cancel order");
        proceedOrder(orderId, OrderStateData.Cancelled);
        if (_cancellingOrder.orderType != OrderTypeData.EthForTokens) {
            TransferHelper.safeTransfer(_cancellingOrder.tokenIn,_cancellingOrder.maker,_cancellingOrder.amountInOffered);
        }
        TransferHelper.safeTransferETH(_cancellingOrder.maker,_cancellingOrder.totalEthDeposited);
        emit CancelledOrder(orderId);
        return true;
    }

    function executeOrder(uint256 orderId)
        external
        exists(orderId)
        nonReentrant
        returns (uint256[] memory)
    {
        Order memory _executingOrder = orders[orderId];
        require(_executingOrder.orderState == OrderStateData.Placed,"Cannot execute order");

        proceedOrder(orderId, OrderStateData.Executed);

        address[] memory _addressPair = createPair(_executingOrder.tokenIn,_executingOrder.tokenOut);
        uint256[] memory _swapResult;
        uint256 uniLayerFee = 0;

        if (_executingOrder.orderType == OrderTypeData.TokensForTokens) {
            TransferHelper.safeApprove(_executingOrder.tokenIn,address(uniswapRouterV2),_executingOrder.amountInOffered);
            uint256 _tokenFee = _executingOrder.amountInOffered.div(100);
            _swapResult = uniswapRouterV2.swapExactTokensForTokens(
                _executingOrder.amountInOffered.sub(_tokenFee),
                _executingOrder.amountOutExpected,
                _addressPair,
                _executingOrder.maker,
                UINT256_MAX
            );
            if (_tokenFee > 0) {
                address[] memory _wethPair = createPair(_executingOrder.tokenIn,uniswapRouterV2.WETH());
                uint256[] memory _ethSwapResult = uniswapRouterV2
                    .swapExactTokensForETH(_tokenFee,0,_wethPair,address(this),UINT256_MAX);
                uniLayerFee = _ethSwapResult[1];
            }
        } else if (_executingOrder.orderType == OrderTypeData.TokensForEth) {
            TransferHelper.safeApprove(_executingOrder.tokenIn,address(uniswapRouterV2),_executingOrder.amountInOffered);
            _swapResult = uniswapRouterV2.swapExactTokensForETH(
                _executingOrder.amountInOffered,
                _executingOrder.amountOutExpected,
                _addressPair,
                address(this),
                UINT256_MAX
            );
            uniLayerFee = _swapResult[1].div(100);
            TransferHelper.safeTransferETH(
                _executingOrder.maker,
                _swapResult[1].sub(uniLayerFee)
            );
        } else if (_executingOrder.orderType == OrderTypeData.EthForTokens) {
            uint256 amountEthOffered = _executingOrder.totalEthDeposited.sub(
                _executingOrder.executorFee
            );
            uniLayerFee = amountEthOffered.div(100);
            _swapResult = uniswapRouterV2.swapExactETHForTokens{
                value: amountEthOffered.sub(uniLayerFee)
            }(
                _executingOrder.amountOutExpected,
                _addressPair,
                _executingOrder.maker,
                UINT256_MAX
            );
        }

        if (uniLayerFee > 0) {
            uint256 burnAmount = uniLayerFee.mul(6).div(10);
            staker.deposit{value: uniLayerFee.sub(burnAmount)}();
        }

        TransferHelper.safeTransferETH(msg.sender, _executingOrder.executorFee);

        emit ExecutedOrder(orderId, msg.sender, _swapResult, uniLayerFee);

        return _swapResult;
    }

    function placeOrder(
        OrderTypeData orderType,
        address tokenIn,
        address tokenOut,
        uint256 amountInOffered,
        uint256 amountOutExpected,
        uint256 executorFee
    ) external payable nonReentrant returns (uint256) {
        require(amountInOffered > 0, "In Amount is Invalid");
        require(amountOutExpected > 0, "Expexted Amount is Invalid");
        require(executorFee > 0, "Executor Fees is anvalid");

        address _wethAddress = uniswapRouterV2.WETH();

        if (orderType != OrderTypeData.EthForTokens) {
            require(msg.value == executorFee,"Transaction value and executor fee are not matching");
            if (orderType == OrderTypeData.TokensForEth) {
                require(tokenOut == _wethAddress, "Token out must be WETH");
            } else {
                getPair(tokenIn, _wethAddress);
            }

            TransferHelper.safeTransferFrom(tokenIn,msg.sender,address(this),amountInOffered);
        } else {
            require(tokenIn == _wethAddress, "Token in must be WETH");
            require(msg.value == amountInOffered.add(executorFee),"Transaction value must match offer and fee");
        }

        address _pairAddress = getPair(tokenIn, tokenOut);

        (uint256 _orderId, Order memory _order) = registerOrder(
            orderType,
            msg.sender,
            tokenIn,
            tokenOut,
            _pairAddress,
            amountInOffered,
            amountOutExpected,
            executorFee,
            msg.value
        );

        emit PlacedOrder(
            _orderId,
            _order.orderType,
            _order.maker,
            _order.tokenIn,
            _order.tokenOut,
            _order.amountInOffered,
            _order.amountOutExpected,
            _order.executorFee,
            _order.totalEthDeposited
        );
        return _orderId;
    }


    function registerOrder(
        OrderTypeData orderType,
        address payable maker,
        address tokenIn,
        address tokenOut,
        address pairAddress,
        uint256 amountInOffered,
        uint256 amountOutExpected,
        uint256 executorFee,
        uint256 totalEthDeposited
    ) internal returns (uint256 orderId, Order memory) {
        uint256 _orderId = orderNumber;
        orderNumber++;

        Order memory _order = Order({
            orderType: orderType,
            maker: maker,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountInOffered: amountInOffered,
            amountOutExpected: amountOutExpected,
            executorFee: executorFee,
            totalEthDeposited: totalEthDeposited,
            activeOrderIndex: activeOrders.length,
            orderState: OrderStateData.Placed
        });

        activeOrders.push(_orderId);
        orders[_orderId] = _order;
        ordersForAddress[maker].push(_orderId);
        ordersForAddress[pairAddress].push(_orderId);
        return (_orderId, _order);
    }

    function proceedOrder(uint256 orderId, OrderStateData nextState)
        internal
        returns (bool)
    {
        Order memory _proceedingOrder = orders[orderId];
        require(_proceedingOrder.orderState == OrderStateData.Placed,"Cannot proceed order");

        if (activeOrders.length > 1) {
            uint256 _availableIndex = _proceedingOrder.activeOrderIndex;
            uint256 _lastOrderId = activeOrders[activeOrders.length - 1];
            Order memory _lastOrder = orders[_lastOrderId];
            _lastOrder.activeOrderIndex = _availableIndex;
            orders[_lastOrderId] = _lastOrder;
            activeOrders[_availableIndex] = _lastOrderId;
        }

        activeOrders.pop();
        _proceedingOrder.orderState = nextState;
        orders[orderId] = _proceedingOrder;

        return true;
    }

    function getPair(address tokenA, address tokenB)
        internal
        view
        returns (address)
    {
        address _pairAddress = uniswapFactoryV2.getPair(tokenA, tokenB);
        require(_pairAddress != address(0), "Unavailable pair address");
        return _pairAddress;
    }

    function getOrder(uint256 orderId)
        external
        view
        exists(orderId)
        returns (
            OrderTypeData orderType,
            address payable maker,
            address tokenIn,
            address tokenOut,
            uint256 amountInOffered,
            uint256 amountOutExpected,
            uint256 executorFee,
            uint256 totalEthDeposited,
            OrderStateData orderState
        )
    {
        Order memory _order = orders[orderId];
        return (
            _order.orderType,
            _order.maker,
            _order.tokenIn,
            _order.tokenOut,
            _order.amountInOffered,
            _order.amountOutExpected,
            _order.executorFee,
            _order.totalEthDeposited,
            _order.orderState
        );
    }

    receive() external payable {}
}