// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
    * @title RebaseToken
    * @author MRAlirad
    * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
    * @notice The interest rate in the smart contract can only decrease.
    * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit.
*/
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private sInterestRate = 5e10;

    mapping (address => uint256) private sUserInterestRate;
    mapping (address => uint256) private sUserLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("MRAlirad", "MRA") {}

    /**
        * @notice Set the global interest rate for the contract.
        * @param _newInterestRate The new interest rate to set (scaled by PRECISION_FACTOR basis points per second).
        * @dev The interest rate can only decrease. Access control (e.g., onlyOwner) should be added.
    */
    function setInerestRate(uint256 _newInterestRate) external {
        if(_newInterestRate > sInterestRate)
            revert RebaseToken__InterestRateCanOnlyDecrease(sInterestRate, _newInterestRate);

        sInterestRate = _newInterestRate;

        emit InterestRateSet(_newInterestRate);
    }

    /**
        * @notice Mints tokens to a user, typically upon deposit.
        * @dev Also mints accrued interest and locks in the current global rate for the user.
        * @param _to The address to mint tokens to.
        * @param _amount The principal amount of tokens to mint.
    */
    function mint(address _to, uint256 _amount) external {
        // TODO: Add access control (e.g., onlyVault)

        // Step 1: Mint any existing accrued interest for the user
        _mintAccruedInterest(_to);

        // Step 2: Update the user's interest rate for future calculations if necessary
        // This assumes sInterestRate is the current global interest rate.
        // If the user already has a deposit, their rate might be updated.
        sUserInterestRate[_to] = sInterestRate;

        // Step 3: Mint the newly deposited amount
        _mint(_to, _amount);
    }

    /**
        * @notice Burn the user tokens, e.g., when they withdraw from a vault or for cross-chain transfers.
        * Handles burning the entire balance if _amount is type(uint256).max.
        * @param _from The user address from which to burn tokens.
        * @param _amount The amount of tokens to burn. Use type(uint256).max to burn all tokens.
    */
    function burn(address _from, uint256 _amount) external { // Access control to be added as needed
        uint256 currentTotalBalance = balanceOf(_from); // Calculate this once for efficiency if needed for checks

        if (_amount == type(uint256).max) {
            _amount = currentTotalBalance; // Set amount to full current balance
        }

        // Ensure _amount does not exceed actual balance after potential interest accrual
        // This check is important especially if _amount wasn't type(uint256).max
        // _mintAccruedInterest will update the super.balanceOf(_from)
        // So, after _mintAccruedInterest, super.balanceOf(_from) should be currentTotalBalance.
        // The ERC20 _burn function will typically revert if _amount > super.balanceOf(_from)

        _mintAccruedInterest(_from); // Mint any accrued interest first

        // At this point, super.balanceOf(_from) reflects the balance including all interest up to now.
        // If _amount was type(uint256).max, then _amount == super.balanceOf(_from)
        // If _amount was specific, super.balanceOf(_from) must be >= _amount for _burn to succeed.

        _burn(_from, _amount);
    }

    /**
        * @notice Returns the current balance of an account, including accrued interest.
        * @param _user The address of the account.
        * @return The total balance including interest.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // Get the user's stored principal balance (tokens actually minted to them).
        uint256 principalBalance = super.balanceOf(_user);

        // Calculate the growth factor based on accrued interest.
        uint256 growthFactor = _calculateUserAccumulatedInterestSinceLastUpdate(_user);

        // Apply the growth factor to the principal balance.
        // Remember PRECISION_FACTOR is used for scaling, so we divide by it here.
        return principalBalance * growthFactor / PRECISION_FACTOR;
    }

    /**
        * @notice Gets the locked-in interest rate for a specific user.
        * @param _user The address of the user.
        * @return The user's specific interest rate.
    */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return sUserInterestRate[_user];
    }

    /**
        * @notice Mint the accrued interest to the user since the last time they interacted with the protocol (e.g. burn, mint, transfer)
        * @param _user The user to mint the accrued interest to
    */
    function _mintAccruedInterest(address _user) internal {
        // (1) find their current balance of rebase tokens that have been minted to the user -> principle balance
        uint256 previousPrincipleBalance = super.balanceOf(_user);

        // (2) calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);

        // calculate the number of tokens that need to be minted to the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;

        // set the users last updated timestamp
        sUserLastUpdatedTimestamp[_user] = block.timestamp;

        if (balanceIncrease > 0) _mint(_user, balanceIncrease);
    }

    /**
        * @dev Calculates the growth factor due to accumulated interest since the user's last update.
        * @param _user The address of the user.
        * @return linearInterestFactor The growth factor, scaled by PRECISION_FACTOR. (e.g., 1.05x growth is 1.05 * 1e18).
    */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns(uint256 linearInterestFactor) {
        // 1. Calculate the time elapsed since the user's balance was last effectively updated.
        uint256 timeElapsed = block.timestamp - sUserLastUpdatedTimestamp[_user];

        // If no time has passed, or if the user has no locked rate (e.g., never interacted), the growth factor is simply 1 (scaled by PRECISION_FACTOR).
        if(timeElapsed == 0 || sUserInterestRate[_user] == 0) return PRECISION_FACTOR;

        // 2. Calculate the total fractional interest accrued: UserInterestRate * TimeElapsed.
        // s_userInterestRate[_user] is the rate per second.
        // This product is already scaled appropriately if s_userInterestRate is stored scaled.
        uint256 fractionalInterest = sUserInterestRate[_user] * timeElapsed;

        // 3. The growth factor is (1 + fractional_interest_part).
        // Since '1' is represented as PRECISION_FACTOR, and fractionalInterest is already scaled, we add them.
        linearInterestFactor = PRECISION_FACTOR + fractionalInterest;

        return linearInterestFactor;
    }
}
