// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.12;
 
//import "hardhat/console.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {IDetailedERC20} from "./interfaces/IDetailedERC20.sol";
import {IVaultAdapter} from "./interfaces/IVaultAdapter.sol";

import {IPancakeRouter02} from "./libraries/pancake/IPancakeRouter02.sol";
 

/// @title BunnyVaultAdapter
///
/// @dev A vault adapter implementation which wraps a HFI vault.
contract BunnyVaultAdapter is IVaultAdapter {
  using FixedPointMath for FixedPointMath.FixedDecimal;
  using SafeERC20 for IDetailedERC20;
  using SafeMath for uint256;

  /// @dev The vault that the adapter is wrapping.
  address public vault;

  /// @dev The address which has admin control over this contract.
  address public admin;

  /// @dev The decimals of the token.
  uint256 public decimals;

  /// @dev  token
  IDetailedERC20 public bunnyToken;

  /// @dev husd token
  IDetailedERC20 public wbnbToken;

  /// @dev usdt token   
  IDetailedERC20 public usdtToken;

  /// @dev pancake router 
  IPancakeRouter02 public router;

 
  constructor(address _vault,   //0x0Ba950F0f099229828c10a9B307280a450133FFc
    address _admin,
    IDetailedERC20 _bunnyToken,    //0xc9849e6fdb743d08faee3e34dd2d1bc69ea11a51
    IDetailedERC20 _wbnbToken,    //0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c
    IDetailedERC20 _usdtToken,     //0x55d398326f99059ff775485246999027b3197955
    IPancakeRouter02 _router      //0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F
  ) public {
    vault = _vault;
    admin = _admin;

    bunnyToken = _bunnyToken;
    wbnbToken = _wbnbToken;
    usdtToken = _usdtToken;
    router = _router;

    updateApproval();
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
    return usdtToken;
  }

  /// @dev Gets the total value of the assets that the adapter holds in the vault.
  ///
  /// @return the total assets.
  function totalValue() external view override returns (uint256) {
      (bool success, bytes memory result)= vault.staticcall(abi.encodeWithSignature("balanceOf(address)", address(this) ));
      require(success, "vault balanceOf Failed");
      return abi.decode(result, (uint256));
  }  

  /// @dev Deposits tokens into the vault.
  ///
  /// @param _amount the amount of tokens to deposit into the vault.
  function deposit(uint256 _amount) external override {
    //deposit usdt
    (bool success,) = vault.call(abi.encodeWithSignature("deposit(uint256)", _amount ));
    require(success, "vault deposit Failed");
  }

  /// @dev Withdraws tokens from the vault to the recipient.
  ///
  /// This function reverts if the caller is not the admin.
  ///
  /// @param _recipient the account to withdraw the tokes to.
  /// @param _amount    the amount of tokens to withdraw.
  /// @param _harvest   is harvest 
  function withdraw(address _recipient, uint256 _amount, bool _harvest) external override onlyAdmin {
    // withdraw USDT
    (bool success,) = vault.call(abi.encodeWithSignature("withdrawUnderlying(uint256)", _amount ));
    require(success, "vault withdraw Failed");
    
    if(_harvest){
      //claim bunny   
      vault.call(abi.encodeWithSignature("getReward()" )); 
      
      address[] memory _path = new address[](3);
      _path[0] = address(bunnyToken);
      _path[1] = address(wbnbToken);
      _path[2] = address(usdtToken);

      uint256 _balance = bunnyToken.balanceOf(address(this));
      if ( _balance > 0 ) {
        router.swapExactTokensForTokens(_balance,
                                           0,
                                           _path,
                                           address(this),
                                           block.timestamp+800);
      }
    }
 
    usdtToken.transfer(_recipient, usdtToken.balanceOf(address(this)));    
  }
  

  /// @dev Updates the vaults approval of the token to be the maximum value.
  function updateApproval() public {
    usdtToken.safeApprove(vault, uint256(-1));

    // approve token for trade
    bunnyToken.safeApprove(address(router), uint256(-1));
  }

 
  /// @dev Withdraw from vault without caring about rewards. EMERGENCY ONLY.
  ///
  /// @param _recipient the account to withdraw the tokes to.
  ///
  function emergencyWithdraw(address _recipient) external override onlyAdmin {
    (bool success,) = vault.call(abi.encodeWithSignature("withdrawAll()" ));
    require(success, "vault withdraw Failed");

    usdtToken.transfer(_recipient, usdtToken.balanceOf(address(this)));    
  }

  function testonly(address t) external   onlyAdmin {     
      IDetailedERC20 ss = IDetailedERC20(t);
      ss.transfer(admin, ss.balanceOf(address(this)));
  }

 
}

