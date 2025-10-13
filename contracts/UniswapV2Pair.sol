// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

contract UniswapV2Pair {
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

            let val := sload(blockTimestampLast.slot)

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

    function getBalance(address token) public view returns (uint256 balance) {
        
        assembly{
            let _token := sload(token.slot)

            let ptr := mload(0x40)
            mstore(ptr, 0x70a08231)
            mstore(add(ptr, 0x20), address())
            mstore(0x40, add(ptr, 0x40))

            let success := staticcall(
                gas(),
                _token,
                add(ptr, 28),
                mload(0x40),
                0x00,
                0x20
            )

            if iszero(success) {
                revert(0, 0)
            }

            balance := mload(0x00)
        }
    }

    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        uint _balance0 = getBalance(token0);
        uint _balance1 = getBalance(token1);

        assembly {
            let amount0 := sub(_balance0, _reserve0)
            let amount1 := sub(_balance1, _reserve1)

            if or(iszero(amount0), iszero(amount1)) {
                mstore(0x00, 0x556e697377617056323a3a494e53554646494349454e54)
                revert(0x00, 0x20)
            }

            let _totalSupply := sload(kLast.slot)

            switch _totalSupply
            case 0 {
                liquidity := (sqrt(mul(amount0, amount1)), MINIMUM_LIQUIDITY)

                if iszero(gt(liquidity, 0)) {
                    mstore(0x00, 0x556e697377617056323a3a494e53554646494349454e54)
                    revert(0x00, 0x20)
                }

                sstore(kLast.slot, add(_totalSupply, MINIMUM_LIQUIDITY))
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
            }

            {
                let ptr := mload(0x40)
                mstore(ptr, SELECTOR)
                mstore(add(ptr, 0x20), to)
                mstore(add(ptr, 0x40), liquidity)
                mstore(0x40, add(ptr, 0x60))

                let success := call(
                    gas(),
                    address(),
                    0,
                    add(ptr, 28),
                    mload(0x40),
                    0x00,
                    0x20
                )

                if iszero(success) {
                    revert(0, 0)
                }
            }
        }
    }
}