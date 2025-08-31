// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ManualToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Axel Token", "AXL") {
        _mint(msg.sender, initialSupply);
    }
}
