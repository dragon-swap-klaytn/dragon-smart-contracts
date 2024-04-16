// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@pancakeswap/v2-core/contracts/interfaces/IPancakeFactory.sol";
import "@pancakeswap/v2-core/contracts/interfaces/IPancakePair.sol";
import "@pancakeswap/v2-core/contracts/interfaces/IPancakeRouter02.sol";
import "@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Factory.sol";

/// @title Distribute
contract FactoryOwner is Ownable {

    IPancakeFactory public v2Factory;
    IPancakeRouter02 public v2Router;
    IPancakeV3Factory public v3Factory;
    uint256 public totalWeight;

    mapping (address => bool) public operator;

    struct FeeReceiver {
        address receiver;
        uint256 weight;
    }
    FeeReceiver[] public feeReceiver;

    constructor(
        address _v2Factory,
        address _v2Router,
        address _v3Factory
    ) {
        v2Factory = IPancakeFactory(_v2Factory);
        v3Factory = IPancakeV3Factory(_v3Factory);
        v2Router = IPancakeRouter02(_v2Router);
    }

    modifier onlyOperator() {
        require(operator[_msgSender()], "Not operator");
        _;
    }

    /// @dev V2는 pool 저장하는데, V3는 pool index 별로 저장하지 않음
    function getV2Length() public view returns (uint256) {
        return v2Factory.allPairsLength();
    }

    function _removeLiqV2(address v2Pool) internal {
        uint256 lp = IERC20(v2Pool).balanceOf(address(this));

        if (lp != 0) {
            if (IERC20(v2Pool).allowance(address(this), address(v2Router)) == 0) {
                IERC20(v2Pool).approve(address(v2Router), type(uint256).max);
            }
            address token0 = IPancakePair(v2Pool).token0();
            address token1 = IPancakePair(v2Pool).token1();
            v2Router.removeLiquidity(
                token0,
                token1,
                lp,
                1,
                1,
                address(this),
                block.timestamp
            );
        }
    }

    /// @dev token 주소 받는거
    function withdrawV2ByAddress(address[] memory pools) external onlyOperator {
        uint256 len = pools.length;
        for (uint256 i = 0; i < len; i++) {
            _removeLiqV2(pools[i]);
        }
    }

    function withdrawV2ByIndex(uint256 s, uint256 e) external onlyOperator {
        require(s < e && e <= getV2Length());
        for (uint256 i = s; i < e; i++) {
            _removeLiqV2(v2Factory.allPairs(i));
        }
    }

    function collectV3(address[] memory pools) external onlyOperator {
        uint256 len = pools.length;

        for (uint256 i = 0; i < len; i++) {
            v3Factory.collectProtocol(
                pools[i],
                address(this),
                type(uint128).max,
                type(uint128).max
            );
        }
    }

    function distribute(address[] memory tokens) external onlyOperator {
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            if (tokens[i] == address(0)) {
                uint256 bal = address(this).balance;
                if (bal != 0) {
                    uint256 feeReceiverLen = feeReceiverLength();
                    for (uint256 j = 0; j < feeReceiverLen; j++) {
                        (bool result, ) = feeReceiver[j].receiver.call{
                            value: bal * feeReceiver[j].weight / totalWeight
                        }("");
                        require(result);
                    }
                }
            } else {
                uint256 bal = IERC20(tokens[i]).balanceOf(address(this));
                if (bal != 0) {
                    uint256 feeReceiverLen = feeReceiverLength();
                    for (uint256 j = 0; j < feeReceiverLen; j++) {
                        IERC20(tokens[i]).transfer(feeReceiver[j].receiver, bal * feeReceiver[j].weight / totalWeight);
                    }
                }
            }
        }
    }

    function execute(address _to, uint256 _value, bytes memory _data) external onlyOwner {
        (bool result,) = _to.call{value: _value}(_data);
        if (!result) {
            revert();
        }
    }

    function setOperator(address _operator, bool _b) external onlyOwner {
        operator[_operator] = _b;

        emit SetOperator(_operator, _b);
    }

    event SetOperator(address operator, bool b);
    event AddFeeReceiver(address feeReceiver, uint256 weight, uint256 totalWeight);
    event RemoveFeeReceiver(address feeReceiver, uint256 totalWeight);

    function addFeeReceiver(address _receiver, uint256 _weight) external onlyOwner {
        require(_weight <= 10000);

        feeReceiver.push(
            FeeReceiver({
                receiver: _receiver,
                weight: _weight
            })
        );
        totalWeight += _weight;

        emit AddFeeReceiver(_receiver, _weight, totalWeight);
    }

    function removeFeeReceiver(address _receiver) external onlyOwner {
        uint256 len = feeReceiverLength();
        uint256 index = type(uint256).max;
        for (uint256 i = 0; i < len; i++) {
            if (feeReceiver[i].receiver == _receiver) {
                index = i;
                break;
            }
        }

        if (index != type(uint256).max) {
            totalWeight = totalWeight - feeReceiver[index].weight;
            feeReceiver[index] = feeReceiver[len - 1];
            feeReceiver.pop();

            emit RemoveFeeReceiver(_receiver, totalWeight);
        }
    }

    function feeReceiverLength() public view returns (uint256) {
        return feeReceiver.length;
    }

    receive() external payable {

    }
}
