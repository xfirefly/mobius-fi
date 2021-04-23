// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//import "hardhat/console.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {IDetailedERC20} from "./interfaces/IDetailedERC20.sol";
import {IVaultAdapter} from "./interfaces/IVaultAdapter.sol";

import {IHfiVault} from "./libraries/hfi/IHfiVault.sol";
import {IMdexRouter} from "./libraries/mdex/IMdexRouter.sol";
import {IHfiStakePool} from "./libraries/hfi/IHfiStakePool.sol";


/// @title HFIVaultAdapter
///
/// @dev A vault adapter implementation which wraps a HFI vault.
contract HFIVaultAdapter is IVaultAdapter {
  using FixedPointMath for FixedPointMath.FixedDecimal;
  using SafeERC20 for IDetailedERC20;
  using SafeMath for uint256;

  /// @dev The total amount the token deposited into the pool that is owned by this.
  uint256 public totalDeposited;

  /// @dev The vault that the adapter is wrapping.
  IHfiVault public vault;

  /// @dev The address which has admin control over this contract.
  address public admin;

  /// @dev The decimals of the token.
  uint256 public decimals;

  /// @dev hfi token
  IDetailedERC20 public hfiToken;

  /// @dev husd token
  IDetailedERC20 public husdToken;

  /// @dev usdt token   
  IDetailedERC20 public usdtToken;

  /// @dev mdex router 
  IMdexRouter public router;

  /// @dev fUSDT stake pool
  IHfiStakePool public pool;


  constructor(IHfiVault _vault,  
    address _admin,
    IDetailedERC20 _hfiToken,   
    IDetailedERC20 _husdToken,  
    IDetailedERC20 _usdtToken,  
    IMdexRouter _router,  
    IHfiStakePool _pool    
  ) public {
    vault = _vault;
    admin = _admin;

    hfiToken = _hfiToken;
    husdToken = _husdToken;
    usdtToken = _usdtToken;

    router = _router;
    pool = _pool;

    updateApproval();
    decimals = _vault.decimals();
  }

  /// @dev A modifier which reverts if the caller is not the admin.
  modifier onlyAdmin() {
    require(admin == msg.sender, "VaultAdapter: only admin");
    _;
  }

  /// @dev Gets the token that the vault accepts.
  ///
  /// @return the accepted token.
  function token() external view override returns (IDetailedERC20) {
    return IDetailedERC20(vault.token());
  }

  /// @dev Gets the total value of the assets that the adapter holds in the vault.
  ///
  /// @return the total assets.
  function totalValue() external view override returns (uint256) {
    return _sharesToTokens(totalDeposited);
  }

  /// @dev Deposits tokens into the vault.
  ///
  /// @param _amount the amount of tokens to deposit into the vault.
  function deposit(uint256 _amount) external override {
    //deposit usdt
    vault.deposit(_amount);
    //stake fUSDT
    uint256 _shares = vault.balanceOf(address(this));
    totalDeposited = totalDeposited.add(_shares);
    pool.deposit(1, _shares );
  }

  /// @dev Withdraws tokens from the vault to the recipient.
  ///
  /// This function reverts if the caller is not the admin.
  ///
  /// @param _recipient the account to withdraw the tokes to.
  /// @param _amount    the amount of tokens to withdraw.
  /// @param _harvest   is harvest   
  function withdraw(address _recipient, uint256 _amount, bool _harvest) external override onlyAdmin {
    uint256 _shares = _tokensToShares(_amount);
    //unstake fUSDT    
    totalDeposited = totalDeposited.sub(_shares);
    pool.withdraw(1, _shares );
    // withdraw USDT
    vault.withdraw(_shares); 
    
    if(_harvest){
      address[] memory _path = new address[](3);
      _path[0] = address(hfiToken);
      _path[1] = address(husdToken);
      _path[2] = address(usdtToken);

      uint256 _hfiBalance = hfiToken.balanceOf(address(this));
      if ( _hfiBalance > 0 ) {
        router.swapExactTokensForTokens(_hfiBalance,
                                           0,
                                           _path,
                                           address(this),
                                           block.timestamp+800);
      }
    }

    IDetailedERC20 _token = IDetailedERC20(vault.token());  
    _token.transfer(_recipient, _token.balanceOf(address(this)));    
  }
 

  /// @dev Updates the vaults approval of the token to be the maximum value.
  function updateApproval() public {
    address _token = vault.token();
    IDetailedERC20(_token).safeApprove(address(vault), uint256(-1));

     // approve fusdt for staking into masterchef
    IDetailedERC20(address(vault)).safeApprove(address(pool), uint256(-1));
    // approve hfi for mdex trade
    hfiToken.safeApprove(address(router), uint256(-1));
  }

  /// @dev Computes the number of tokens an amount of shares is worth.
  ///
  /// @param _sharesAmount the amount of shares.
  ///
  /// @return the number of tokens the shares are worth.
  function _sharesToTokens(uint256 _sharesAmount) internal view returns (uint256) {
    return _sharesAmount.mul(vault.getPricePerFullShare()).div(10**decimals);
  }

  /// @dev Computes the number of shares an amount of tokens is worth.
  ///
  /// @param _tokensAmount the amount of shares.
  ///
  /// @return the number of shares the tokens are worth.
  function _tokensToShares(uint256 _tokensAmount) internal view returns (uint256) {
    return _tokensAmount.mul(10**decimals).div(vault.getPricePerFullShare());
  }

  /// @dev Withdraw from vault without caring about rewards. EMERGENCY ONLY.
  ///
  ///
  function emergencyWithdraw() external override onlyAdmin {
    pool.emergencyWithdraw(1);
  
  }

}
