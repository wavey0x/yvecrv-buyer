# @version 0.3.3
from vyper.interfaces import ERC20

YVECRV: constant(address) = 0xc5bDdf9843308380375a611c18B50Fb9341f502A
CRV: constant(address) = 0xD533a949740bb3306d119CC777fa900bA034cd52
LLAMAPAY: constant(address) = 0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B
PRECISION: constant(uint256) = 10_000

discount: public(uint256) # Discount expressed in BPS.
admin: public(address)
treasury: public(address)
rate: public(uint216) # LlamaPay rate

struct Withdrawable:
    amount: uint256
    last_update: uint256
    owed: uint256

interface LlamaPay:
    def withdraw(source: address, target: address, rate: uint216): nonpayable
    def withdrawable(source: address, target: address, rate: uint216) -> Withdrawable: view

event Buy:
    buyer: indexed(address)
    yvecrv: uint256
    crv: uint256

event UpdateAdmin:
    admin: indexed(address)

event UpdateTreasury:
    treasury: indexed(address)

event UpdateDiscount:
    discount: uint256

@external
def __init__():
    self.admin = msg.sender
    self.treasury = msg.sender
    self.discount = 1_000
    
    log UpdateAdmin(msg.sender)
    log UpdateTreasury(msg.sender)
    log UpdateDiscount(1_000)


@view
@internal
def withdrawable() -> uint256:
    if self.rate != 0:
        return LlamaPay(LLAMAPAY).withdrawable(self.admin, self, self.rate).amount
    return 0


@external
def buy_crv(yvecrv_amount: uint256):
    if self.rate != 0:
        LlamaPay(LLAMAPAY).withdraw(self.admin, self, self.rate)

    crv_amount: uint256 = yvecrv_amount * (PRECISION - self.discount) / PRECISION

    assert ERC20(YVECRV).transferFrom(msg.sender, self.treasury, yvecrv_amount)  # dev: no allowance
    assert ERC20(CRV).transfer(msg.sender, crv_amount)  # dev: not enough dai

    log Buy(msg.sender, yvecrv_amount, crv_amount)


@view
@external
def total_crv() -> uint256:
    return ERC20(CRV).balanceOf(self) + self.withdrawable()


@view
@external
def max_amount() -> uint256:
    total_crv: uint256 = ERC20(CRV).balanceOf(self) + self.withdrawable()
    return total_crv * (PRECISION - self.discount) / PRECISION


@external
def sweep(token: address, amount: uint256 = MAX_UINT256):
    assert msg.sender == self.admin
    value: uint256 = amount
    if value == MAX_UINT256:
        value = ERC20(token).balanceOf(self)
    
    assert ERC20(token).transfer(self.admin, value)


@external
def set_admin(proposed_admin: address):
    assert msg.sender == self.admin
    self.admin = proposed_admin

    log UpdateAdmin(proposed_admin)


@external
def set_treasury(new_treasury: address):
    assert msg.sender == self.admin
    self.treasury = new_treasury

    log UpdateTreasury(new_treasury)

@external
def set_discount(new_discount: uint256):
    assert msg.sender == self.admin
    self.discount = new_discount

    log UpdateDiscount(new_discount)