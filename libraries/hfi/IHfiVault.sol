pragma solidity ^0.6.12;

interface IHfiVault {
    function token() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function totalSupply() external view returns (uint);
    
    function deposit(uint) external payable ;
    function withdraw(uint) external ;
    function withdrawAll() external ;
    function getPricePerFullShare() external view returns (uint);
}