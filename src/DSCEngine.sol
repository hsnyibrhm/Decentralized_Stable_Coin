// Layout of Contract:
// license
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title DSCEngine
 * @author hsnyibrhm
 * the system is designed to be as minimal as possible, & have the tokens maintain a 1 token == $1 peg.
 * this stable coin has properties
 * - exogenous collateral
 * - dollar pegged
 * - algorithmically stable
 *
 * it is similar to DAI is DAI had no governance, no fees, and was backed by eth and btc only.
 *
 * this dsc system sould always be overcollateralized. at no point, should the value of the collateral <= the $ backed avalue of all the dsc.
 *
 * @notice this contract is the core of the dsc system. it handles all the logic for mining and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice this contract is veri loosely based on the makerdao DSS(DAI) system
 *
 */

contract DSCEngine {
    function depositCollateralAndMintDsc() external payable {}

    function depositCollateral() external payable {}

    function redeemCollateralForDsc() external payable {}

    function redeemCollateral() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view returns (uint256) {}
}
