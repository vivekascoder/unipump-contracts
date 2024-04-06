import numpy as np
import pandas as pd
from datetime import datetime, timedelta

def generate_time_series_data(start_time, end_time):
    """
    Generate fake minute-candle time series data for e^x curve.

    :param start_time: The start time as a string (e.g., '2024-11-17 09:00:00').
    :param end_time: The end time as a string (e.g., '2024-11-17 18:00:00').
    :return: Pandas DataFrame with minute candle data.
    """
    # Convert input strings to datetime objects
    start_time = datetime.strptime(start_time, "%Y-%m-%d %H:%M:%S")
    end_time = datetime.strptime(end_time, "%Y-%m-%d %H:%M:%S")
    
    # Generate minute timestamps
    timestamps = pd.date_range(start=start_time, end=end_time, freq='T')
    
    # Generate x values corresponding to minutes elapsed
    minutes_elapsed = np.array([(ts - timestamps[0]).total_seconds() / 60 for ts in timestamps])
    
    # Generate e^x values
    values = np.exp(minutes_elapsed / 500)  # Scale x to prevent huge growth
    
    # Generate OHLC data
    data = []
    for value in values:
        open_price = value * np.random.uniform(0.99, 1.01)  # Small random variance
        close_price = value * np.random.uniform(0.99, 1.01)
        high_price = max(open_price, close_price) * np.random.uniform(1.01, 1.02)
        low_price = min(open_price, close_price) * np.random.uniform(0.98, 0.99)
        data.append([open_price, high_price, low_price, close_price])
    
    # Create DataFrame
    df = pd.DataFrame(data, columns=["open", "high", "low", "close"], index=timestamps)
    df.index.name = "timestamp"
    
    return df

# Example usage
start_time = "2024-11-17 09:00:00"
end_time = "2024-11-17 10:00:00"
df = generate_time_series_data(start_time, end_time)

print(df.head())  # Preview the first few rows


import matplotlib.pyplot as plt
from matplotlib.dates import date2num
from mplfinance.original_flavor import candlestick_ohlc

# Plotting function
def plot_candlestick_chart(df):
    """
    Plot a candlestick chart from the OHLC DataFrame.

    :param df: Pandas DataFrame with columns ['open', 'high', 'low', 'close'] and datetime index.
    """
    # Convert DataFrame index (timestamp) to Matplotlib's date format
    df['date_num'] = date2num(df.index)
    
    # Prepare data in (date, open, high, low, close) format for plotting
    ohlc_data = df[['date_num', 'open', 'high', 'low', 'close']].values

    # Plot candlestick chart
    fig, ax = plt.subplots(figsize=(12, 6))
    candlestick_ohlc(ax, ohlc_data, width=0.0008, colorup='g', colordown='r')
    
    # Format the chart
    ax.xaxis_date()  # Use datetime on the x-axis
    ax.set_title("Candlestick Chart")
    ax.set_xlabel("Time")
    ax.set_ylabel("Price")
    ax.grid(True)
    
    # Rotate date labels for better visibility
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.show()

# Generate data and plot
plot_candlestick_chart(df)
