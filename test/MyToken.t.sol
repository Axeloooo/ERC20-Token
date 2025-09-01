// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MyTokenScript} from "../script/MyToken.s.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public token;
    MyTokenScript public deployer;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    uint256 public constant STARTING_BALANCE = 100 ether;

    function setUp() public {
        deployer = new MyTokenScript();
        token = deployer.run();

        vm.prank(msg.sender);
        token.transfer(bob, STARTING_BALANCE);
    }

    function testBobBalance() public view {
        assertEq(STARTING_BALANCE, token.balanceOf(bob));
    }

    function testAllowancesWorks() public {
        uint256 initialAllowance = 1000;

        vm.prank(bob);
        token.approve(alice, initialAllowance);

        uint256 transferAmount = 500;
        vm.prank(alice);
        token.transferFrom(bob, alice, transferAmount);

        assertEq(token.balanceOf(alice), transferAmount);
        assertEq(token.balanceOf(bob), STARTING_BALANCE - transferAmount);
    }
}
