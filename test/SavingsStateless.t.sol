// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Savings} from "../src/Savings.sol";
import {Token} from "../test/mock/Token.sol";

contract SavingsTest is Test {
    Savings public savings;
    Token public token;
    address public user = makeAddr("user");

    uint256 constant MIN_DEPOSIT_AMOUNT = 1e18;
    uint256 constant MAX_DEPOSIT_AMOUNT = 1_000_000e18;

    function setUp() public {
        token = new Token();
        savings = new Savings(address(token));
        address fakeUser1 = vm.addr(1); 

        // Mint tokens to the user for testing
        token.mint(user, type(uint256).max);

        // Approve the Savings contract to spend tokens on behalf of the user
        vm.prank(user);
        token.approve(address(savings), type(uint256).max);
    }

    function testStatelessDepositLessThanMinimumAmount(uint256 amount) public {
        amount = bound(amount, 0, 1e18);

        vm.startPrank(user);
        vm.expectRevert();
        savings.deposit(amount);
        vm.stopPrank();

        // Check if the balance updated correctly
        assertEq(savings.balances(user), 0, "User balance should match deposited amount");
        // Check if total deposited updated correctly
        assertEq(savings.totalDeposited(), 0, "Total deposited should equal the amount deposited in stateless test");

        // Check if tokens were transferred from the user to the contract
        assertEq(token.balanceOf(user), type(uint256).max - 0, "User should have reduced token balance");
        assertEq(token.balanceOf(address(savings)), 0, "Contract should hold the deposited tokens");
}
  function testStatelessDepositMoreThanMinimumAmount(uint256 amount) public {
        amount = bound(amount, 1000_000e18, 10_000_000e18);

        vm.startPrank(user);
        savings.deposit(amount);
        vm.stopPrank();

        // Check if the balance updated correctly
        assertEq(savings.balances(user), amount, "User balance should match deposited amount");
        // Check if total deposited updated correctly
        assertEq(
            savings.totalDeposited(), amount, "Total deposited should equal the amount deposited in stateless test"
        );

        // Check if tokens were transferred from the user to the contract
        assertEq(token.balanceOf(user), type(uint256).max - amount, "User should have reduced token balance");
    assertEq(token.balanceOf(address(savings)), amount, "Contract should hold the deposited tokens");
}
}