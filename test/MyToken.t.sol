// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MyTokenScript} from "../script/MyToken.s.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    MyToken public token;
    MyTokenScript public deployer;

    address public bob = makeAddr("bob");
    address public alice = makeAddr("alice");
    address public charlie = makeAddr("charlie");

    uint256 public constant STARTING_BALANCE = 100 ether;

    function setUp() public {
        deployer = new MyTokenScript();
        token = deployer.run();

        vm.prank(msg.sender);
        token.transfer(bob, STARTING_BALANCE);
    }

    // --- Basic metadata & decimals ---

    function testNameSymbolDecimals() public view {
        assertEq(token.name(), "Axel Token");
        assertEq(token.symbol(), "AXL");
        assertEq(token.decimals(), 18);
    }

    function testTotalSupplyPositive() public view {
        assertGt(token.totalSupply(), 0);
    }

    // --- Balances & transfers ---

    function testBobBalance() public view {
        assertEq(STARTING_BALANCE, token.balanceOf(bob));
    }

    function testTransferUpdatesBalances() public {
        uint256 amount = 1 ether;

        vm.prank(bob);
        bool ok = token.transfer(alice, amount);
        assertTrue(ok);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(bob), STARTING_BALANCE - amount);
    }

    function testTransferEmitsEvent() public {
        uint256 amount = 2 ether;

        vm.expectEmit(true, true, false, true);
        emit Transfer(bob, alice, amount);

        vm.prank(bob);
        token.transfer(alice, amount);
    }

    function testTransferToZeroAddressReverts() public {
        vm.prank(bob);
        vm.expectRevert();
        token.transfer(address(0), 1);
    }

    function testTransferInsufficientBalanceReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1);
    }

    function testZeroAmountTransferAllowed() public {
        vm.prank(bob);
        bool ok = token.transfer(alice, 0);
        assertTrue(ok);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), STARTING_BALANCE);
    }

    // --- Approvals & allowances ---

    function testApproveSetsAllowanceAndEmits() public {
        uint256 allowanceAmount = 1000;

        vm.expectEmit(true, true, false, true);
        emit Approval(bob, alice, allowanceAmount);

        vm.prank(bob);
        bool ok = token.approve(alice, allowanceAmount);
        assertTrue(ok);
        assertEq(token.allowance(bob, alice), allowanceAmount);
    }

    function testApproveOverwritesPreviousAllowance() public {
        vm.startPrank(bob);
        token.approve(alice, 10);
        token.approve(alice, 25);
        vm.stopPrank();

        assertEq(token.allowance(bob, alice), 25);
    }

    function testMultipleSpendersHaveIndependentAllowances() public {
        address spender1 = alice;
        address spender2 = charlie;

        vm.startPrank(bob);
        token.approve(spender1, 40);
        token.approve(spender2, 70);
        vm.stopPrank();

        assertEq(token.allowance(bob, spender1), 40);
        assertEq(token.allowance(bob, spender2), 70);
    }

    // --- transferFrom behavior ---

    function testTransferFromRespectsAllowanceAndBalances() public {
        uint256 initialAllowance = 1000;

        vm.prank(bob);
        token.approve(alice, initialAllowance);

        uint256 transferAmount = 500;
        vm.prank(alice);
        bool ok = token.transferFrom(bob, alice, transferAmount);
        assertTrue(ok);

        assertEq(token.balanceOf(alice), transferAmount);
        assertEq(token.balanceOf(bob), STARTING_BALANCE - transferAmount);
        assertEq(
            token.allowance(bob, alice),
            initialAllowance - transferAmount
        );
    }

    function testTransferFromInsufficientAllowanceReverts() public {
        vm.prank(bob);
        token.approve(alice, 5);

        vm.prank(alice);
        vm.expectRevert();
        token.transferFrom(bob, alice, 6);
    }

    function testTransferFromCannotExceedOwnersBalanceEvenIfAllowanceHigh()
        public
    {
        uint256 charlieBal = 10;
        deal(address(token), charlie, charlieBal);
        vm.prank(charlie);
        token.approve(alice, type(uint256).max);

        vm.prank(alice);
        vm.expectRevert();
        token.transferFrom(charlie, alice, charlieBal + 1);
    }

    function testTransferFromEmitsTransferEvent() public {
        uint256 amount = 7;

        vm.prank(bob);
        token.approve(alice, amount);

        vm.expectEmit(true, true, false, true);
        emit Transfer(bob, alice, amount);

        vm.prank(alice);
        token.transferFrom(bob, alice, amount);
    }

    // --- Fuzz / property-style checks ---

    function testFuzz_ApproveSetsAllowance(
        address owner,
        address spender,
        uint256 amt
    ) public {
        vm.assume(owner != address(0) && spender != address(0));
        vm.assume(owner != spender);

        deal(address(token), owner, amt);

        vm.prank(owner);
        bool ok = token.approve(spender, amt);
        assertTrue(ok);
        assertEq(token.allowance(owner, spender), amt);
    }

    function testFuzz_TransferKeepsTotalSupply(
        address from,
        address to,
        uint128 amt
    ) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);

        deal(address(token), from, amt);

        uint256 supplyBefore = token.totalSupply();

        vm.prank(from);
        bool ok = token.transfer(to, amt);
        assertTrue(ok);

        assertEq(token.totalSupply(), supplyBefore);
        assertEq(token.balanceOf(to), amt);
        assertEq(token.balanceOf(from), 0);
    }

    function testFuzz_TransferFromReducesAllowance(
        address owner,
        address spender,
        address to,
        uint128 amt
    ) public {
        vm.assume(
            owner != address(0) && spender != address(0) && to != address(0)
        );
        vm.assume(owner != spender && owner != to);

        deal(address(token), owner, amt);

        vm.prank(owner);
        token.approve(spender, amt);

        vm.prank(spender);
        bool ok = token.transferFrom(owner, to, amt);
        assertTrue(ok);

        assertEq(token.allowance(owner, spender), 0);
        assertEq(token.balanceOf(to), amt);
        assertEq(token.balanceOf(owner), 0);
    }
}
