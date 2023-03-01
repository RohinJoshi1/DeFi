//SPDX-License-Identifier:MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract CSAMM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    //Amount of token0
    uint public reserve0;
    //Amount of token1
    uint public reserve1;

    //Total share
    uint public totalSupply;

    //Address to shares
    mapping(address=>uint) public balanceOf;
    constructor(address _token0,address _token1){
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }
    function _mint(address _to,uint _amount) private{
        balanceOf[_to]+=_amount;
        totalSupply +=_amount;
    }
    function _burn(address _from,uint _amount) private{
        balanceOf[_from]-=_amount;
        totalSupply-=_amount;
    }
    function _update(uint _res0,uint _res1) private{
        reserve0 = _res0;
        reserve1 = _res1;
    }
    function swap(address _tokenIn,uint _amountIn) external returns(uint amountOut){
        require(_tokenIn == address(token0) || _tokenIn == address(token1),"Invalid token");
        /* 
            1.First transfer token to contract
            2.then calculate the amount to swap including fees
            3.update reserve0 and res1
            4.transfer token out
        */
        bool isToken0 = _tokenIn == address(token0);
        (IERC20 tokenIn,IERC20 tokenOut,uint resIn,uint resOut) = isToken0 ? (token0,token1,reserve0,reserve1):
        (token1,token0,reserve1,reserve0);
        //1.
            tokenIn.transferFrom(msg.sender,address(this),_amountIn);
            uint amountIn = tokenIn.balanceOf(address(this))-resIn;
    
        //2
        //0.3% fee
        //dx=dy
        amountOut = amountIn * 997/1000;
        (uint res0,uint res1) = isToken0 ? 
        (resIn + _amountIn,resOut - amountOut) :
        (resOut - amountOut,resIn+amountIn);
        _update(res0,res1);
        //Transfer
        tokenOut.transfer(msg.sender,amountOut);


    }
    //change return param
    function addLiquidity(uint _amount0,uint _amount1) external returns (uint shares){
        token0.transferFrom(msg.sender,address(this),_amount0);
        token1.transferFrom(msg.sender,address(this),_amount1);
        uint _bal0 = token0.balanceOf(address(this));
        uint _bal1 = token1.balanceOf(address(this));
        uint d0 = _bal0- reserve0;
        uint d1 = _bal1- reserve1;
        /*
        a=amount in
        L = total liquidity
        s = shares to mint
        T = total supply
        (L+a)/L = (T+s)/T
        a/L = s/T
        s = aT/L
        */
        if(totalSupply==0){
            shares = d0+d1;
        }else{
            shares = ((d0+d1)*totalSupply)/(reserve1+reserve0);
        }
        require(shares>0,"shares =0");
        _mint(msg.sender,shares);
        _update(_bal0,_bal1);
     }
    function removeLiquidity(uint _shares) external returns (uint d0,uint d1){
        /* 
        a=amountOut
        L -> total liquidity
        s = shares
        T = Total supply
        a/L = s/T
        a = sL/T
        s*(reserve0 + reserve1) / T
        */
        d0 = (reserve0*_shares)/totalSupply;
        d1 = (reserve1*_shares)/totalSupply;
        _burn(msg.sender,_shares);
        _update(reserve0-d0,reserve1-d1);
        if(d0>0){
            token0.transfer(msg.sender,d0);
        }
        if(d1>0){
            token1.transfer(msg.sender,d1);
        }


    }
}