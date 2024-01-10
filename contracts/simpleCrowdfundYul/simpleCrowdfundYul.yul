object "CrowdFunding" {
    code {
        // return the bytecode of the contract
        datacopy(0x00, dataoffset("runtime"), datasize("runtime"))
        return(0x00, datasize("runtime"))
    }

    object "runtime" {
        code {
            switch selector()
            case 0x22502268 /* createCampaign(uint256,uint256) target/duration */ {
                // require enough data is sent for params
                checkParamLenght(2)

                // get the campaign ID
                let id := sload(0x00)

                // store the ID to memory at 0x00
                mstore(0x00, id)

                // compute the storage slot of the campaing struct
                let structSlot := keccak256(0x00, 0x20)
                // store the campaign struct
                sstore(structSlot, caller())
                sstore(add(structSlot, 0x20), calldataload(4))
                sstore(add(structSlot, 0x40), add(timestamp() ,calldataload(36)))

                // increment the ID
                sstore(0x00, add(id, 1))
            }
            case 0xc1cbbca7 /* contribute(uint256) campaignId */ {
                // require enough data is sent for param
                checkParamLenght(1)
                // require value sent is more than 0
                require(lt(0, callvalue()))

                // get the id from calldata and store it in memory
                let id := calldataload(4)
                mstore(0x00, id)

                // require block timestamp lower than campaign end time
                let campaignStructSlot := keccak256(0x00, 0x20)
                let endTimestamp := sload(add(campaignStructSlot, 0x40))
                require(lt(timestamp(), endTimestamp))

                // sotre caller address to memory
                mstore(0x20, caller())

                // compute the storage slot of the invested value
                // of the user for this campaign
                let storageSlot := keccak256(0x00, 0x40)
                // get the already invested amount
                let alreadyInvested := sload(storageSlot)

                // store the new invested value
                sstore(storageSlot, add(alreadyInvested, callvalue()))

                // update total raised for campaign ID
                let totalStorageSlot := add(campaignStructSlot, 0x60)
                let previousTotal := sload(totalStorageSlot)
                sstore(totalStorageSlot, add(previousTotal, callvalue()))
            }
            case 0x6ef98b21 /* withdrawOwner(uint256) campaignId*/ {
                // require enough data is sent for params
                checkParamLenght(1)

                // store the campaing ID in memory
                mstore(0x00, calldataload(4))

                // get the storage slot of campaign struct
                let ownerStorageSlot := keccak256(0x00, 0x20)
                let targetAmountSlot := add(ownerStorageSlot, 0x20)
                let endTimestampSlot := add(ownerStorageSlot, 0x40)
                let amountRaisedSlot := add(ownerStorageSlot, 0x60)

                let amountRaised := sload(amountRaisedSlot)

                // require caller is the owner
                require(eq(caller(), sload(ownerStorageSlot)))
                // require minimum amount is raised
                require(lt(sload(targetAmountSlot), amountRaised))

                // delete the amount raised
                sstore(amountRaisedSlot, 0)

                // make end timestamp uint256.max so that
                // contributors can't withdraw
                sstore(endTimestampSlot, sub(0,1))

                // send value raised to owner
                if iszero(call(gas(), caller(), amountRaised, 0, 0, 0, 0)) {
                revert(0,0)
            }

            }
            case 0x152b58ab /* withdrawDonor(uint256) campaignId */{
                // require enough data is sent for params
                checkParamLenght(1)

                // store the campaing ID in memory
                mstore(0x00, calldataload(4))

                // get the storage slot of campaign struct
                let ownerStorageSlot := keccak256(0x00, 0x20)
                let targetAmountSlot := add(ownerStorageSlot, 0x20)
                let endTimestampSlot := add(ownerStorageSlot, 0x40)
                let amountRaisedSlot := add(ownerStorageSlot, 0x60)

                // require that the end timestamp has passed
                require(lt(sload(endTimestampSlot), timestamp()))
                // require that the target amount has not been raised
                require(lt(sload(amountRaisedSlot), sload(targetAmountSlot)))

                mstore(0x20, caller())

                // compute the storage slot of the invested value
                // of the user for this campaign
                let storageSlot := keccak256(0x00, 0x40)

                let amountToSend := sload(storageSlot)

                // require that the amount to send is bigger than 0
                require(lt(0, amountToSend))

                sstore(storageSlot, 0)

                // send back funds to doner
                transfer(amountToSend)
            }
            default {
                // if the function signature sent does not match any
                // of the contract functions, revert
                revert(0, 0)
            }

            // Return the function selector: the first 4 bytes of the call data
            function selector() -> s {
                s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
            }

            // Implementation of the require statement from Solidity
            function require(condition) {
                if iszero(condition) { revert(0, 0) }
            }

            // Check if the calldata has the correct number of params
            function checkParamLenght(len) {
                require(eq(calldatasize(), add(4, mul(32, len))))
            }

            // Transfer ether to the caller address
            function transfer(amount) {
                if iszero(call(gas(), caller(), amount, 0, 0, 0, 0)) {
                    revert(0,0)
                }
            }
        }
    }
}