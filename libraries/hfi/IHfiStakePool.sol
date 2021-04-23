pragma solidity >=0.6.2;

 
interface IHfiStakePool {
  function deposit(uint256 _pid, uint256 _amount) external;
  function withdraw(uint256 _pid, uint256 _amount) external;

  function emergencyWithdraw(uint256 _pid) external;
}

 
 