import os, numpy as np, pandas as pd
from urllib.parse import quote_plus
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
pw = quote_plus(os.getenv("DB_PASS"))
engine = create_engine(f"mysql+pymysql://{os.getenv('DB_USER')}:{pw}@{os.getenv('DB_HOST','localhost')}/revenue_audit")

f = pd.read_csv("data/processed/fact_items_clean.csv",
                parse_dates=["order_purchase_timestamp", "order_delivered_customer_date",
                             "order_estimated_delivery_date"])

# customers
customers = (f.drop_duplicates("customer_unique_id")
             [["customer_unique_id", "customer_state", "customer_city"]])

# products
products = f.drop_duplicates("product_id")[["product_id", "category", "list_price"]]

# orders (one row per order)
o = f.groupby("order_id").agg(
    customer_unique_id=("customer_unique_id", "first"),
    order_status=("order_status", "first"),
    purchase_ts=("order_purchase_timestamp", "first"),
    delivered_date=("order_delivered_customer_date", "first"),
    estimated_date=("order_estimated_delivery_date", "first"),
    review_score=("review_score", "first")).reset_index()
o["purchase_date"] = o["purchase_ts"].dt.date
o["is_late"] = (o["delivered_date"] > o["estimated_date"]).astype(int)
orders = o[["order_id", "customer_unique_id", "order_status", "purchase_date", "purchase_ts",
            "delivered_date", "estimated_date", "is_late", "review_score"]]

# order_items
order_items = f[["order_id", "order_item_id", "product_id", "seller_id", "seller_state", "price",
                 "gross_revenue", "discount_amount", "net_revenue", "product_cost", "shipping_cost",
                 "refund_amount", "total_cost", "gross_profit", "gross_margin_percentage",
                 "revenue_leakage_amount", "below_margin_threshold"]]

# returns (only refunded lines)
r = f[f["is_refund"] == 1].copy()
r["return_reason"] = np.where(r["order_status"].isin(["canceled", "unavailable"]),
                              "Canceled/Unavailable", "Late delivery + low review")
returns = r[["order_id", "order_item_id", "return_reason", "refund_amount"]]

# shipping_costs
s = f[["order_id", "order_item_id", "freight_value", "excess_freight", "price"]].copy()
s["freight_pct"] = (100 * s["freight_value"] / s["price"]).round(2)
shipping_costs = s.drop(columns="price")

# date_dim
d = pd.DataFrame({"full_date": pd.date_range(f["order_purchase_timestamp"].min().replace(month=1, day=1),
                                             f["order_purchase_timestamp"].max().replace(month=12, day=31))})
d["date_key"] = d["full_date"].dt.strftime("%Y%m%d").astype(int)
d["year"] = d["full_date"].dt.year
d["quarter"] = d["full_date"].dt.quarter
d["month_num"] = d["full_date"].dt.month
d["month_name"] = d["full_date"].dt.strftime("%b")
d["ym"] = d["full_date"].dt.strftime("%Y-%m")
d["day_of_week"] = d["full_date"].dt.strftime("%a")
d["is_weekend"] = (d["full_date"].dt.dayofweek >= 5).astype(int)
date_dim = d[["date_key", "full_date", "year", "quarter", "month_num", "month_name",
              "ym", "day_of_week", "is_weekend"]]

# load (parents before children)
with engine.begin() as c:
    c.execute(text("SET FOREIGN_KEY_CHECKS=0"))
    for t in ["shipping_costs", "returns", "order_items", "orders", "products", "customers", "date_dim"]:
        c.execute(text(f"TRUNCATE TABLE {t}"))
    c.execute(text("SET FOREIGN_KEY_CHECKS=1"))

for name, df in [("customers", customers), ("products", products), ("date_dim", date_dim),
                 ("orders", orders), ("order_items", order_items),
                 ("returns", returns), ("shipping_costs", shipping_costs)]:
    df.to_sql(name, engine, if_exists="append", index=False, chunksize=5000)
    print(f"Loaded {name}: {len(df)} rows")

# validation
with engine.connect() as c:
    db = c.execute(text("SELECT ROUND(SUM(net_revenue),2), ROUND(SUM(gross_profit),2) FROM order_items")).one()
print("MySQL  revenue/profit:", db)
print("CSV    revenue/profit:", round(f["net_revenue"].sum(), 2), round(f["gross_profit"].sum(), 2))