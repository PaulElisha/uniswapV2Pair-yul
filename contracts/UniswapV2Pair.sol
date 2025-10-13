// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./UniswapV2ERC20.sol";

contract UniswapV2Pair is UniswapV2ERC20 {
    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR =
        bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast;

    uint private unlocked = 1;

    modifier lock() {
        assembly {
            if iszero(eq(sload(unlocked.slot), 1)) {
                mstore(0x00, 0x556e697377617056323a204c4f434b4544)
                revert(0x00, 0x20)
            }

            sstore(unlocked.slot, 0)
        }

        _;

        assembly {
            sstore(unlocked.slot, 1)
        }
    }

    constructor() {
        assembly {
            sstore(factory.slot, caller())
        }
    }

    function getReserves()
        external
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        )
    {
        assembly {
            blockTimestampLast_offset := blockTimestampLast.offset
            reserve1_offset := reserve1.offset

            let val := sload(reserve0.slot)

            _reserve0 := and(val, 0xffffffffffffffffffffffffffff)
            _reserve1 := and(
                shr(mul(reserve1_offset, 8), val),
                0xffffffffffffffffffffffffffff
            )
            _blockTimestampLast := and(
                shr(mul(blockTimestampLast_offset, 8), val),
                0xffffffff
            )
        }
    }

    function initialize(address _token0, address _token1) external {
        assembly {
            if iszero(eq(sload(factory.slot), caller())) {
                mstore(0x00, 0x556e697377617056323a20464f5242494444454e)
                revert(0x00, 0x20)
            }

            sstore(token0.slot, _token0)
            sstore(token1.slot, _token1)
            return(0, 0)
        }
    }

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        assembly {
            let price0CumulativeLastSlot := price0CumulativeLast.slot
            let price1CumulativeLastSlot := price1CumulativeLast.slot
            let blockTimestampLastSlot := blockTimestampLast.slot
            let reserve0Slot := _reserve0.slot
            let reserve1Slot := _reserve1.slot

            let maxUint112 := sub(shl(112, 1), 1) // 2^112 - 1

            if or(gt(maxUint112, balance0), gt(maxUint112, balance1)) {
                mstore(0x00, 0x08c379a0)
                revert(0x00, 0x20)
            }

            let blockTimestamp := mod(timestamp(), exp(2, 32))
            let blockTimestampLast := sload(blockTimestampLastSlot)
            let timeElapsed := sub(blockTimestamp, blockTimestampLast)

            if and(gt(timeElapsed, 0), and(iszero(iszero(_reserve0)), iszero(iszero(_reserve1)))) {
                let price0Cumulative := sload(price0CumulativeLastSlot)
                let price0Increment := div(mul(shl(112, _reserve1), timeElapsed), _reserve0)
                sstore(price0CumulativeLastSlot, add(price0Cumulative, price0Increment))

                let price1Cumulative := sload(price1CumulativeLastSlot)
                let price1Increment := div(mul(shl(112, _reserve0), timeElapsed), _reserve1)
                sstore(price1CumulativeLastSlot, add(price1Cumulative, price1Increment))
            }

            sstore(reserve0Slot, balance0)
            sstore(reserve1Slot, balance1)
            sstore(blockTimestampLastSlot, blockTimestamp)
        }
    }


    function getBalance(address token) public view returns (uint256 balance) {
        
        assembly{
            let _token := token

            let ptr := mload(0x40)
            mstore(ptr, 0x70a08231)
            mstore(add(ptr, 0x20), address())
            mstore(0x40, add(ptr, 0x40))

            let ok := staticcall(
                gas(),
                _token,
                add(ptr, 28),
                mload(0x40),
                0x00,
                0x20
            )

            if iszero(ok) {
                revert(0, 0)
            }

            balance := mload(0x00)
        }
    }

    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        address _token0 = token0;
        address _token1 = token1;

        uint _balance0 = getBalance(_token0);
        uint _balance1 = getBalance(_token1);

        bool feeOn;
        uint _kLast;

        assembly {
            let amount0 := sub(_balance0, _reserve0)
            let amount1 := sub(_balance1, _reserve1)
            _kLast := sload(kLast.slot)
            let _totalSupply := sload(totalSupply.slot)

            let fmptr := mload(0x40)
            mstore(fmptr, 0xf65d5f86)
            mstore(add(fmptr, 0x20), _reserve0)
            mstore(add(fmptr, 0x40), _reserve1)
            mstore(0x40, add(fmptr, 0x60))

            feeOn := call(
                gas(),
                address(),
                0,
                add(fmptr, 28),
                mload(0x40),
                0x00,
                0x20
            )

            if iszero(feeOn) {
                revert(0, 0)
            }

            switch _totalSupply
            case 0 {
                liquidity := sub(sqrt(mul(amount0, amount1)), MINIMUM_LIQUIDITY)

                if iszero(gt(liquidity, 0)) {
                    mstore(0x00, 0x556e697377617056323a3a494e53554646494349454e54)
                    revert(0x00, 0x20)
                }

                let fmptr := mload(0x40)
                mstore(fmptr, 0x40c10f19)
                mstore(add(fmptr, 0x20), 0x00)
                mstore(add(fmptr, 0x40), MINIMUM_LIQUIDITY)
                mstore(0x40, add(fmptr, 0x60))

                let ok := call(
                    gas(),
                    address(),
                    0,
                    add(fmptr, 28),
                    0x40,
                    0x00,
                    0x20
                )

                if iszero(ok) {
                    revert(0, 0)
                }
            }
            default {
                liquidity := min(
                    div(mul(amount0, _totalSupply), _reserve0),
                    div(mul(amount1, _totalSupply), _reserve1)
                )

                if iszero(gt(liquidity, 0)) {
                    mstore(0x00, 0x556e697377617056323a3a494e53554646494349454e54)
                    revert(0x00, 0x20)
                }
    
                let ptr := mload(0x40)
                mstore(ptr, 0x40c10f19)
                mstore(add(ptr, 0x20), to)
                mstore(add(ptr, 0x40), liquidity)
                mstore(0x40, add(ptr, 0x60))

                let ok := call(
                    gas(),
                    address(),
                    0,
                    add(ptr, 28),
                    mload(0x40),
                    0x00,
                    0x20
                )

                if iszero(ok) {
                    revert(0, 0)
                }
            }
        }

        _update(_balance0, _balance1, _reserve0, _reserve1);

        assembly {
            if iszero(iszero(feeOn)) {
                _kLast := mul(_reserve0, _reserve1)
                sstore(kLast.slot, _kLast)
            }
        }
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        
        assembly {
            let _factory := sload(factory.slot)
            let _kLast := sload(kLast.slot)

            let ptr := mload(0x40)
            mstore(ptr, 0x017e7e58)
            mstore(0x40, add(ptr, 0x20))

            let ok := staticcall(
                gas(),
                _factory,
                0,
                add(ptr, 28),
                mload(0x40),
                0x00,
                0x20
            )

            if iszero(ok) {
                revert(0, 0)
            }

            let feeTo := mload(0x00)

            {
                feeOn := iszero(iszero(feeTo))

                if iszero(feeOn) {
                    leave
                }

                if iszero(iszero(_kLast)) {
                    let rootK := sqrt(mul(_reserve0, _reserve1))
                    let rootKLast := sqrt(_kLast)

                if iszero(iszero(gt(rootK, rootKLast)) ) {
                
                    let _totalSupply := sload(totalSupply.slot)
                    let numerator := mul(_totalSupply, sub(rootK, rootKLast))
                    let denominator := add(mul(rootK, 5), rootKLast)
                    let liquidity := div(numerator, denominator)

                    if iszero(iszero(gt(liquidity, 0))) {

                        let fmptr := mload(0x40)
                        mstore(fmptr, 0x40c10f19)
                        mstore(add(fmptr, 0x20), feeTo)
                        mstore(add(fmptr, 0x40), liquidity)
                        mstore(0x40, add(fmptr, 0x60))

                        let ok := call(
                            gas(),
                            address(),
                            0,
                            add(fmptr, 28),
                            mload(0x40),
                            0x00,
                            0x20
                        )

                        if iszero(ok) {
                            revert(0, 0)
                        }
                    }
                }   

                if iszero(iszero(_kLast)) {
                    _kLast := 0
                    sstore(kLast.slot, _kLast)
                }
            }
        }
    }

    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        address _token0 = token0;
        address _token1 = token1;

        uint _balance0 = getBalance(_token0);
        uint _balance1 = getBalance(_token1);

        assembly {
            let _kLast := sload(kLast.slot)
            let _totalSupply := sload(totalSupply.slot)
            
            let fmptr := mload(0x40)
            mstore(fmptr, 0xf65d5f86)
            mstore(add(fmptr, 0x20), _reserve0)
            mstore(add(fmptr, 0x40), _reserve1)
            mstore(0x40, add(fmptr, 0x60))

            let feeOn := call(
                gas(),
                address(),
                0,
                add(fmptr, 28),
                mload(0x40),
                0x00,
                0x20
            )


            let liquidity := sload(balanceOf.slot)
            liquidity := and(
                shr(mul(balanceOf.offset, 8), liquidity),
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            )

            let amount0 := div(mul(liquidity, _balance0), _totalSupply)
            let amount1 := div(mul(liquidity, _balance1), _totalSupply)

            if iszero(gt(amount0, 0)) {
                mstore(0x00, 0x556e697377617056323a3a494e53554646494349454e54)
                revert(0x00, 0x20)
            }

            if iszero(gt(amount1, 0)) {
                mstore(0x00, 0x556e697377617056323a3a494e53554646494349454e54)
                revert(0x00, 0x20)
            }

            let ptr := mload(0x40)
            mstore(ptr, 0x6161eb18)
            mstore(add(ptr, 0x20), address())
            mstore(add(ptr, 0x40), liquidity)
            mstore(0x40, add(ptr, 0x60))

            let ok := call(
                gas(),
                address(),
                0,
                add(ptr, 28),
                mload(0x40),
                0
            )

            if iszero(ok) {
                revert(0, 0)
            }

            let fmptr := mload(0x40)
            mstore(fmptr, 0xa9059cbb)
            mstore(add(fmptr, 0x20), to)
            mstore(add(fmptr, 0x40), amount0)
            mstore(0x40, add(fmptr, 0x60))

            let ok := call(
                gas(),
                _token0,
                0,
                add(fmptr, 28),
                mload(0x40),
                0x00,
                0x20
            )

            if iszero(ok) {
                revert(0, 0)
            }

            let fmptr := mload(0x40)
            mstore(fmptr, 0xa9059cbb)
            mstore(add(fmptr, 0x20), to)
            mstore(add(fmptr, 0x40), amount1)
            mstore(0x40, add(fmptr, 0x60))

            let ok := call(
                gas(),
                _token1,
                0,
                add(fmptr, 28),
                mload(0x40),
                0x00,
                0x20
            )

            if iszero(ok) {
                revert(0, 0)
            }

            if iszero(feeOn) {
                leave
            }
            let _kLast := mul(_reserve0, _reserve1)
            sstore(kLast.slot, _kLast)
        }
    }
    
    function skim(address to) external lock {

        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        address _token0 = token0;
        address _token1 = token1;

        uint _balance0 = getBalance(_token0);
        uint _balance1 = getBalance(_token1);

        assembly {
            let amount0 := sub(_balance0, _reserve0)
            let amount1 := sub(_balance1, _reserve1)

            let fmptr := mload(0x40)
            mstore(fmptr, 0xa9059cbb)
            mstore(add(fmptr, 0x20), to)
            mstore(add(fmptr, 0x40), amount0)
            mstore(0x40, add(fmptr, 0x60))

            let ok := call(
                gas(),
                _token0,
                0,
                add(fmptr, 28),
                mload(0x40),
                0x00,
                0x20
            )

            if iszero(ok) {
                revert(0, 0)
            }

            let fmptr1 := mload(0x40)
            mstore(fmptr1, 0xa9059cbb)
            mstore(add(fmptr1, 0x20), to)
            mstore(add(fmptr1, 0x40), amount1)
            mstore(0x40, add(fmptr1, 0x60))

            let ok := call(
                gas(),
                _token1,
                0,
                add(fmptr1, 28),
                mload(0x40),
                0x00,
                0x20
            )

            if iszero(ok) {
                revert(0, 0)
            }
        }
    }
}