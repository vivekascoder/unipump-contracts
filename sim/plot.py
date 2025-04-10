import matplotlib.pyplot as plt
from unipump_simulation import supply_history, price_history, locked_weth_history

# Convert from 1e18 scale
supply = [s / 1e18 for s in supply_history]
price = [p for p in price_history]
weth = [w / 1e18 for w in locked_weth_history]

plt.figure(figsize=(12, 6))

# Price vs Supply
plt.subplot(1, 2, 1)
plt.plot(supply, price, label='Price')
plt.xlabel("Token Supply (in tokens)")
plt.ylabel("Token Price (WETH)")
plt.title("Price vs Supply")
plt.grid(True)

# WETH Locked vs Supply
plt.subplot(1, 2, 2)
plt.plot(supply, weth, label='Locked WETH', color='orange')
plt.xlabel("Token Supply (in tokens)")
plt.ylabel("Locked WETH")
plt.title("Locked WETH vs Supply")
plt.grid(True)

plt.tight_layout()
plt.show()
