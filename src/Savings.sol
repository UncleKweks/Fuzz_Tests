// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../test/mock/Token.sol";
import {Test, console} from "forge-std/Test.sol";

contract Savings {
    Token public token;

    // @notice MAX_DEPOSIT_AMOUNT is the maximum amount that can be deposited into this contract
    uint256 public constant MAX_DEPOSIT_AMOUNT = 1_000_000e18;
    // @notice MIN_DEPOSIT_AMOUNT is the minimum amount that can be deposited into this contract
    uint256 public constant MIN_DEPOSIT_AMOUNT = 1e18;

    // @notice balances holds user balances
    mapping(address => uint256) public balances;

    // @notice timestamp tracks user deposit time;
    mapping(address => uint256) public timestamps;

    // @notice totalDeposited represents the current deposited amount across all users
    uint256 public totalDeposited;

    // @notice Deposit event is emitted after a deposit occurs
    event Deposit(address depositor, uint256 amount, uint256 totalDeposited);

    // @notice Withdraw event is emitted after a withdraw occurs
    event Withdraw(address user, uint256 amount);

    constructor(address tokenAddress) {
        token = Token(tokenAddress);
    }

    // @notice deposit allows user to deposit into the systemsrc/Savings.sol
    function deposit(uint256 amount) public {
        require(amount >= MIN_DEPOSIT_AMOUNT);

        // Update the user balance and total deposited
        balances[msg.sender] += amount;

        if (timestamps[msg.sender] == 0) {
            timestamps[msg.sender] = block.timestamp;
        }

        totalDeposited += amount;

        token.transferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, totalDeposited);
    }

// Invariant: totalDeposited = sum of all user balances)
    function withdraw(uint256 amount, address _addr) public {
        require(balances[msg.sender] > amount, "insufficient balance");
        balances[msg.sender] -= amount;
        totalDeposited -= amount;
        token.transfer(_addr, amount);
        emit Withdraw(msg.sender, amount);                                         
    }

    function getInterestPerAnnum() public {
        require(block.timestamp >= timestamps[msg.sender] + 365 days, "can only get interest after 1 year");
        require(balances[msg.sender] > 0, "not made deposits");
        uint256 interest = (balances[msg.sender] * 100) / 1000;
        console.log(interest);
        token.transfer(msg.sender, interest);
    }
}
