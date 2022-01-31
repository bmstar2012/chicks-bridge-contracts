//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "..\libraries\external\BytesLib.sol";

contract WChicksBridge is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    address internal _serviceAddress = 0x0000000000000000000000000000000000000000;

    struct GuardianSet {
        address[] keys;
        uint32 expiration_time;
    }

    struct ParsedVAA {
        uint8 version;
        bytes32 hash;
        uint32 guardian_set_index;
        uint32 timestamp;
        uint8 action;
        bytes payload;
    }

    // Mapping of already consumedVAAs
    mapping(bytes32 => bool) public consumedVAAs;

    function submitVAA(bytes calldata vaa) public nonReentrant {
        ParsedVAA memory parsed_vaa = parseAndVerifyVAA(vaa);
        vaaTransfer(parsed_vaa.payload);
    }

    function parseAndVerify(bytes calldata vaa) public view returns (ParsedVAA memory parsed_vaa) {
        parsed_vaa.version = vaa.toUint8(0);
        require(parsed_vaa.version == 1, "VAA version incompatible");

        // Load 4 bytes starting from index 1
        parsed_vaa.guardian_set_index = vaa.toUint32(1);

        uint256 len_signers = vaa.toUint8(5);
        uint offset = 6 + 66 * len_signers;

        // Load 4 bytes timestamp
        parsed_vaa.timestamp = vaa.toUint32(offset);

        // Hash the body
        parsed_vaa.hash = keccak256(vaa.slice(offset, vaa.length - offset));
        require(!consumedVAAs[parsed_vaa.hash], "VAA was already executed");

        GuardianSet memory guardian_set = guardian_sets[parsed_vaa.guardian_set_index];
        require(guardian_set.keys.length > 0, "invalid guardian set");
        require(guardian_set.expiration_time == 0 || guardian_set.expiration_time > block.timestamp, "guardian set has expired");
        // We're using a fixed point number transformation with 1 decimal to deal with rounding.
        require(((guardian_set.keys.length * 10 / 3) * 2) / 10 + 1 <= len_signers, "no quorum");

        int16 last_index = - 1;
        for (uint i = 0; i < len_signers; i++) {
            uint8 index = vaa.toUint8(6 + i * 66);
            require(index > last_index, "signature indices must be ascending");
            last_index = int16(index);

            bytes32 r = vaa.toBytes32(7 + i * 66);
            bytes32 s = vaa.toBytes32(39 + i * 66);
            uint8 v = vaa.toUint8(71 + i * 66);
            v += 27;
            require(ecrecover(parsed_vaa.hash, v, r, s) == guardian_set.keys[index], "VAA signature invalid");
        }

        parsed_vaa.action = vaa.toUint8(offset + 4);
        parsed_vaa.payload = vaa.slice(offset + 5, vaa.length - (offset + 5));
    }

    function vaaTransfer(bytes memory data) private {
        //uint32 nonce = data.toUint64(0);
        uint8 source_chain = data.toUint8(4);

        uint8 target_chain = data.toUint8(5);
        //bytes32 source_address = data.toBytes32(6);
        //bytes32 target_address = data.toBytes32(38);
        address target_address = data.toAddress(38 + 12);

        uint8 token_chain = data.toUint8(70);
        //bytes32 token_address = data.toBytes32(71);
        uint256 amount = data.toUint256(104);

        require(source_chain != target_chain, "same chain transfers are not supported");
        require(target_chain == CHAIN_ID, "transfer must be incoming");

        address token_address = data.toAddress(71 + 12);


        IERC20(token_address).safeTransfer(target_address, amount);
    }

}
