pragma solidity ^0.6.12;

 
interface IStakePool {
  function deposit(uint256 _pid, uint256 _amount) external;
  function withdraw(uint256 _pid, uint256 _amount) external;
  function claim(uint256 _pid) external returns (uint256 value) ;

  function emergencyWithdraw(uint256 _pid) external;
  function extendPool() external returns (address );
}

 
 