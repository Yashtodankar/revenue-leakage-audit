import pandas as pd
from pathlib import Path

RAW = Path("data/raw/Dataset")
files = {
    "orders": "olist_orders_dataset.csv",
    "items": "olist_order_items_dataset.csv",
    "customers": "olist_customers_dataset.csv",
    "products": "olist_products_dataset.csv",
    "payments": "olist_order_payments_dataset.csv",
    "reviews": "olist_order_reviews_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "geo": "olist_geolocation_dataset.csv",
    "cat": "product_category_name_translation.csv",
}
d = {k: pd.read_csv(RAW / v) for k, v in files.items()}

for k, df in d.items():
    print(f"\n{k}: {df.shape[0]} rows | dupes: {df.duplicated().sum()}")
    print(df.isna().sum()[df.isna().sum() > 0].to_dict())

o, i = d["orders"], d["items"]
print("\nOrder status:\n", o["order_status"].value_counts())
print("\nOrders with no items:", (~o["order_id"].isin(i["order_id"])).sum())
print("Items with no order:", (~i["order_id"].isin(o["order_id"])).sum())
print("Items w/o product:", (~i["product_id"].isin(d["products"]["product_id"])).sum())
print("Orders w/o customer:", (~o["customer_id"].isin(d["customers"]["customer_id"])).sum())
print("Date range:", o["order_purchase_timestamp"].min(), "to", o["order_purchase_timestamp"].max())