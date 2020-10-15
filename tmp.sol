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
    event ExecutedOrder(
        uint256 indexed orderId,
        address indexed executor,
        uint256[] amounts,
        uint256 uniLayerFee
    );
    event UpdatedStaker(address newStaker);

    modifier exists(uint256 orderId) {
        require(orders[orderId].maker != address(0), "This order doent exists");
        _;
    }

    constructor(IUniswapV2Router02 _uniswapV2Router,UniTradeIncinerator _incinerator,IUniTradeStaker _staker) public {
        uniswapRouterV2 = _uniswapV2Router;
        uniswapFactoryV2 = IUniswapV2Factory(_uniswapV2Router.factory());
        staker = _staker;
    }

    function updateStaker(IUniTradeStaker newStaker) external onlyOwner {
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

    function updateOrder(
        uint256 orderId,
        uint256 amountInOffered,
        uint256 amountOutExpected,
        uint256 executorFee
    ) external payable exists(orderId) nonReentrant returns (bool) {
        Order memory _updatingOrder = orders[orderId];
        require(msg.sender == _updatingOrder.maker, "Not Permitted");
        require(
            _updatingOrder.orderState == OrderStateData.Placed,
            "Order cannt be updated"
        );
        require(amountInOffered > 0, "Amount Offered is Invalid");
        require(amountOutExpected > 0, "Expected Amount is Invalid");
        require(executorFee > 0, "Executor Fees is Invalid");

        if (_updatingOrder.orderType == OrderTypeData.EthForTokens) {
            uint256 newTotal = amountInOffered.add(executorFee);
            if (newTotal > _updatingOrder.totalEthDeposited) {
                require(
                    msg.value == newTotal.sub(_updatingOrder.totalEthDeposited),
                    "Additional deposit must match"
                );
            } else if (newTotal < _updatingOrder.totalEthDeposited) {
                TransferHelper.safeTransferETH(
                    _updatingOrder.maker,
                    _updatingOrder.totalEthDeposited.sub(newTotal)
                );
            }
            _updatingOrder.totalEthDeposited = newTotal;
        } else {
            if (executorFee > _updatingOrder.executorFee) {
                require(
                    msg.value == executorFee.sub(_updatingOrder.executorFee),
                    "Additional fee must match"
                );
            } else if (executorFee < _updatingOrder.executorFee) {
                TransferHelper.safeTransferETH(
                    _updatingOrder.maker,
                    _updatingOrder.executorFee.sub(executorFee)
                );
            }
            _updatingOrder.totalEthDeposited = executorFee;
            if (amountInOffered > _updatingOrder.amountInOffered) {
                TransferHelper.safeTransferFrom(
                    _updatingOrder.tokenIn,
                    msg.sender,
                    address(this),
                    amountInOffered.sub(_updatingOrder.amountInOffered)
                );
            } else if (amountInOffered < _updatingOrder.amountInOffered) {
                TransferHelper.safeTransfer(
                    _updatingOrder.tokenIn,
                    _updatingOrder.maker,
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
            TransferHelper.safeTransfer(
                _cancellingOrder.tokenIn,
                _cancellingOrder.maker,
                _cancellingOrder.amountInOffered
            );
        }
        TransferHelper.safeTransferETH(
            _cancellingOrder.maker,
            _cancellingOrder.totalEthDeposited
        );

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

        address[] memory _addressPair = createPair(
            _executingOrder.tokenIn,
            _executingOrder.tokenOut
        );
        uint256[] memory _swapResult;
        uint256 uniLayerFee = 0;

        if (_executingOrder.orderType == OrderTypeData.TokensForTokens) {
            TransferHelper.safeApprove(
                _executingOrder.tokenIn,
                address(uniswapRouterV2),
                _executingOrder.amountInOffered
            );
            uint256 _tokenFee = _executingOrder.amountInOffered.div(100);
            _swapResult = uniswapRouterV2.swapExactTokensForTokens(
                _executingOrder.amountInOffered.sub(_tokenFee),
                _executingOrder.amountOutExpected,
                _addressPair,
                _executingOrder.maker,
                UINT256_MAX
            );
            if (_tokenFee > 0) {
                address[] memory _wethPair = createPair(
                    _executingOrder.tokenIn,
                    uniswapRouterV2.WETH()
                );
                uint256[] memory _ethSwapResult = uniswapRouterV2
                    .swapExactTokensForETH(
                    _tokenFee,
                    0,
                    _wethPair,
                    address(this),
                    UINT256_MAX
                );
                uniLayerFee = _ethSwapResult[1];
            }
        } else if (_executingOrder.orderType == OrderTypeData.TokensForEth) {
            TransferHelper.safeApprove(
                _executingOrder.tokenIn,
                address(uniswapRouterV2),
                _executingOrder.amountInOffered
            );
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