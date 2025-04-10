import numpy as np
import matplotlib.pyplot as plt

# Constants from contract
INITIAL_SUPPLY = 0
INITIAL_LOCKED_WETH = 0
M = 1_000_000e18

# Constants for simulation
WETH_AMOUNT_STEP = 1e18  # 1 WETH per buy
NUM_STEPS = 100

# Helper functions

def ud(x):
    return x / 1e18

def curve(x):
    return 0.6015 * np.exp(0.00003606 * x)

def cap(price, supply):
    return price * supply

def price(supply):
    return curve(cap(price=0, supply=supply)) / ud(M)

def buy_price(supply):
    return curve(cap(price=0, supply=supply)) / ud(M)

def buy_tokens(weth_amount, current_price):
    return weth_amount / current_price

def sell_weth(token_amount, current_price):
    return token_amount * current_price

# Simulation storage
supply_history = []
price_history = []
locked_weth_history = []

supply = INITIAL_SUPPLY
locked_weth = INITIAL_LOCKED_WETH

for step in range(NUM_STEPS):
    current_price = buy_price(supply)
    tokens_out = buy_tokens(WETH_AMOUNT_STEP, current_price)

    supply += tokens_out
    locked_weth += WETH_AMOUNT_STEP

    supply_history.append(supply)
    price_history.append(current_price)
    locked_weth_history.append(locked_weth)

print("Final supply:", supply)
print("Final price:", current_price)
print("Final locked WETH:", locked_weth)  # in wei