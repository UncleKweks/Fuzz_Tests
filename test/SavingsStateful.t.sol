
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Savings} from "../src/Savings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 100_000_000_000); // Mint 1 million tokens to the deployer
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StatefulFuzzSavingsTest is StdInvariant, Test {
    Savings public saving;
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    MockToken public token;

    function setUp() public {
        token = new MockToken();
        saving = new Savings(address(token));

        // token.mint(address(this), 100_000_000_000);

        token.transfer(user1, 10_000_000);

        // Transfer tokens to users
        token.transfer(user2, 10_000_000);

        vm.prank(user1);
        token.approve(address(saving), type(uint256).max);

        vm.prank(user2);
        token.approve(address(saving), type(uint256).max);

        targetContract(address(saving));
    }

    function testFuzz_userDeposit(uint256 _amount) public {
        uint256 minDeposit = saving.MIN_DEPOSIT_AMOUNT();
        uint256 maxDeposit = saving.MAX_DEPOSIT_AMOUNT();
        _amount = bound(_amount, minDeposit, maxDeposit);

        address user = _amount % 2 == 0 ? user1 : user2;

        token.mint(user, _amount);

        vm.prank(user);
        saving.deposit(_amount);

        uint256 totalDeposited = saving.totalDeposited();
        assertEq(
            totalDeposited,
            saving.balances(user1) + saving.balances(user2),
            "Total deposited does not match sum of user balances"
        );
    }

    function testFuzz_userDepositWithdrawalCycle(
        uint256 _amount,
        uint256 _withdrawAmt
    ) public {
        // Ensure amount is within a valid range
        uint256 minDeposit = saving.MIN_DEPOSIT_AMOUNT();
        uint256 maxDeposit = saving.MAX_DEPOSIT_AMOUNT();

        // Bound the deposit amount
        _amount = bound(_amount, minDeposit, maxDeposit);
        address user = _amount % 2 == 0 ? user1 : user2;
        token.mint(address(this), _amount);
        token.transfer(user, _amount);

        vm.prank(user);
        token.approve(address(saving), _amount);

        // Deposit the amount
        vm.prank(user);
        saving.deposit(_amount);

        // Log user's balance in the Savings contract
        uint256 userBalance = saving.balances(user);

        // Bound the withdrawal amount to be less than or equal to user's balance
        _withdrawAmt = bound(_withdrawAmt, minDeposit, userBalance);

        // Withdraw the amount
        vm.prank(user);
        saving.withdraw(_withdrawAmt, address(user));

        // Check balances and totalDeposited
        uint256 totalDeposited = saving.totalDeposited();
        assertEq(
            totalDeposited,
            saving.balances(user1) + saving.balances(user2),
            "Total deposited does not match sum of user balances"
        );
    }

    // Test if deposits exceeding the limit are rejected.
    function testFuzz_MAX_DEPOSIT_AMOUNT(uint256 _amount) public {
        // Choose a predefined user
        address user = _amount % 2 == 0 ? user1 : user2;

        vm.prank(user);
        vm.expectRevert();
        saving.deposit(_amount);
    }

    function testFuzz_MIN_DEPOSIT_AMOUNT(uint256 _amount) public {
        // Choose a predefined user
        address user = _amount % 2 == 0 ? user1 : user2;

        vm.prank(user);
        vm.expectRevert(); //Expect Revert if deposit is less than MIN DEPOSIT
        saving.deposit(_amount);
    }

    function testFuzz_userPartialWithdrawal(
        uint256 _amount,
        uint256 _withdrawAmt
    ) public {
        uint256 minDeposit = saving.MIN_DEPOSIT_AMOUNT();
        uint256 maxDeposit = saving.MAX_DEPOSIT_AMOUNT();
        _amount = bound(_amount, minDeposit, maxDeposit);

        address user = _amount % 2 == 0 ? user1 : user2;
        token.mint(address(this), _amount);
        token.transfer(user, _amount);

        vm.prank(user);
        token.approve(address(saving), _amount);

        vm.prank(user);
        saving.deposit(_amount);

        uint256 userBalance = saving.balances(user);
        _withdrawAmt = bound(_withdrawAmt, minDeposit, userBalance);

        vm.prank(user);
        saving.withdraw(_withdrawAmt, user);

        uint256 remainingBalance = saving.balances(user);
        assertEq(
            remainingBalance,
            userBalance - _withdrawAmt,
            "Incorrect remaining balance"
        );

        // Verify total deposited updated
        uint256 totalDeposited = saving.totalDeposited();
        assertEq(
            totalDeposited,
            saving.balances(user1) + saving.balances(user2),
            "Total deposited mismatch"
        );
    }

    function testFhouldFail_Withdraw_without_deposit(
        uint256 _withdrawAmt
    ) public {
        address user = _withdrawAmt % 2 == 0 ? user1 : user2;

        vm.expectRevert();
        vm.prank(user);
        saving.withdraw(_withdrawAmt, user);
    }

    function testFuzzshould_check_increase_per_annum(uint256 _amount) public {
        uint256 minDeposit = saving.MIN_DEPOSIT_AMOUNT();
        uint256 maxDeposit = saving.MAX_DEPOSIT_AMOUNT();
        _amount = bound(_amount, minDeposit, maxDeposit);

        address user = _amount % 2 == 0 ? user1 : user2;

        token.mint(address(this), _amount);
        token.transfer(user, _amount);

        vm.prank(user);
        token.approve(address(saving), _amount);

        // Deposit the amount
        vm.prank(user);
        saving.deposit(_amount);

        uint256 userTokenBalance = token.balanceOf(user);

        vm.warp(366 days);

        vm.prank(user);
        saving.getInterestPerAnnum();

        uint256 interest = (saving.balances(user) * 100) / 1000;

        assertEq(token.balanceOf(user), userTokenBalance + interest);
    }

    function testFuzzshould_check_reset_timestamp_after_interest(
        uint256 _amount
    ) public {
        uint256 minDeposit = saving.MIN_DEPOSIT_AMOUNT();
        uint256 maxDeposit = saving.MAX_DEPOSIT_AMOUNT();
        _amount = bound(_amount, minDeposit, maxDeposit);

        address user = _amount % 2 == 0 ? user1 : user2;

        token.mint(address(this), _amount);
        token.transfer(user, _amount);

        vm.prank(user);
        token.approve(address(saving), _amount);

        // Deposit the amount
        vm.prank(user);
        saving.deposit(_amount);

        uint256 userTokenBalance = token.balanceOf(user);

        vm.warp(366 days);

        vm.prank(user);
        saving.getInterestPerAnnum();

        uint256 timestamp = saving.timestamps(user);

        uint256 interest = (saving.balances(user) * 100) / 1000;

        assertEq(token.balanceOf(user), userTokenBalance + interest); //This should pass

        assert(timestamp >= block.timestamp); //This should fail cos timestamp is not adding 365 days.
    }

    // function testFuzz_Should_Fail_Withdraw_without_deposit(
    //     uint256 _withdrawAmt
    // ) public {
    //     uint256 minDeposit = saving.MIN_DEPOSIT_AMOUNT();
    //     uint256 maxDeposit = saving.MAX_DEPOSIT_AMOUNT();

    //     address user = _withdrawAmt % 2 == 0 ? user1 : user2;

    //     // Deposit funds
    //     token.mint(address(this), _withdrawAmt);
    //     token.transfer(user, _withdrawAmt);

    //     vm.prank(user);
    //     token.approve(address(saving), _withdrawAmt);

    //     // vm.prank(user);
    //     // saving.deposit(_amount);

    //     uint256 userBalance = saving.balances(user);
    //     vm.prank(user);
    //     vm.expectRevert();
    //     saving.withdraw(_withdrawAmt, user);

    //     // uint256 remainingBalance = saving.balances(user);
    //     // assertEq(
    //     //     remainingBalance,
    //     //     userBalance - _withdrawAmt,
    //     //     "Incorrect remaining balance"
    //     // );

    //     // // Verify total deposited updated
    //     // uint256 totalDeposited = saving.totalDeposited();
    //     // assertEq(
    //     //     totalDeposited,
    //     //     saving.balances(user1) + saving.balances(user2),
    //     //     "Total deposited mismatch"
    //     // );
    // }
}
