
import math

class Pool:
    meme_amount: float
    usdc_amount: float
    last_price:float
    
    def __init__(self) -> None:
        self.meme_amount = 0
        self.usdc_amount = 0
        self.last_price = Pool.curve(0) / 10**6
    
    
    def curve(x: float) -> float:
        """
        returns the price of 10M meme tokens in USDC at a given supply `x`
        """
        return 0.6015 * math.exp(0.00003606*x)

    def cap(self) -> float:
        """
        returns the current market cap of the pool
        """
        return self.meme_amount * self.last_price

    def buy(self, usdc_amount: float) -> float:
        """
        buys meme tokens with usdc
        """
        self.usdc_amount += usdc_amount
        self.last_price = Pool.curve(self.cap()) / 10**6
        n = usdc_amount / self.last_price
        self.meme_amount += n
        return n
    
    def sell(self, meme_amount: float) -> float:
        """
        sells meme tokens for usdc
        """
        self.meme_amount -= meme_amount
        self.last_price = Pool.curve(self.cap()) / 10**6
        redeemed = meme_amount * self.last_price
        return redeemed

if __name__ == "__main__":
    pool = Pool()
    # 
    print(f"bought {pool.buy(1000)} MEME with {10000}$")
    # print(f"bought {pool.buy(100)} MEME with {100}$")
    # print(f"bought {pool.buy(100)} MEME with {100}$")
    # print(f"bought {pool.buy(100)} MEME with {100}$")
    # print(f"bought {pool.buy(100)} MEME with {100}$")
    # print(f"bought {pool.buy(100)} MEME with {100}$")
    # print(f"bought {pool.buy(100)} MEME with {100}$")
    # print(f"bought {pool.buy(100)} MEME with {100}$")
    # # # sell
    # print(f"redeemed {pool.sell(100)} USDC with {100} MEME")
    # print(f"redeemed {pool.sell(100)} USDC with {100} MEME")
    # print(f"redeemed {pool.sell(100)} USDC with {100} MEME")
    # print(f"redeemed {pool.sell(100)} USDC with {100} MEME")
    # print(f"redeemed {pool.sell(100)} USDC with {100} MEME")
    # print(f"redeemed {pool.sell(100)} USDC with {100} MEME")
    # print(f"redeemed {pool.sell(100)} USDC with {100} MEME")
    # print(f"redeemed {pool.sell(100)} USDC with {100} MEME")

    print(math.floor(math.sqrt(1/2) * 2 ** 96))
