//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../token/behaviours/ERC20Mintable.sol";
import "../token/ChicksBase.sol";

contract WChicksToken is ERC20Mintable, Ownable {
    address internal _serviceAddress = 0x0000000000000000000000000000000000000000;
    address internal _presaleAddress = 0x0000000000000000000000000000000000000000;
    uint16 internal _feePercent = 15; // 1.5%

    constructor(string memory name, string memory symbol, uint256 initialBalance) ChicksBase(name, symbol) {
        require(initialBalance > 0, "wChicks: Supply cannot be zero");
        _mint(msg.sender, initialBalance * (10 ** decimals()));
    }

    function _mint(address account, uint256 amount) internal override onlyOwner {
        super._mint(account, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        uint256 receiveAmount = amount;
        uint256 transferAmount = amount;
        uint256 feeAmount = 0;
        if (sender != _presaleAddress && _serviceAddress != recipient  && _serviceAddress != address(0) && _feePercent > 0) {
            feeAmount = amount * _feePercent / 1000;
            emit Transfer(sender, _serviceAddress, feeAmount);

            receiveAmount = amount - feeAmount;
            if (sender == _serviceAddress) {
                transferAmount = receiveAmount;
                feeAmount = 0;
            }
        }

        unchecked {
            _balances[sender] = senderBalance - transferAmount;
        }

        if (feeAmount > 0) {
            _balances[_serviceAddress] += feeAmount;
        }
        _balances[recipient] += receiveAmount;

        emit Transfer(sender, recipient, receiveAmount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    function migrate(address recipient, uint256 amount, uint8 targetChainId, uint256 targetAddress) public returns (bool) {
        require(targetChainId > 0 && targetAddress > 0, "target is required");
        return transfer(recipient, amount);
    }

    function setService(address value) public onlyOwner {
        _serviceAddress = value;
    }

    function setPresale(address value) public onlyOwner {
        _presaleAddress = value;
    }

    function setFee(uint16 feePercent) public onlyOwner {
        _feePercent = feePercent;
    }

    function fee() public view returns (uint16) {
        return _feePercent;
    }

    function service() public view returns (address) {
        return _serviceAddress;
    }

    function presale() public view returns (address) {
        return _presaleAddress;
    }
}
