import pandas as pd, numpy as np
from pathlib import Path

# ---------- 1. LOAD ----------
RAW = Path("data/raw/Dataset")
OUT = Path("data/processed"); OUT.mkdir(parents=True, exist_ok=True)
Path("docs").mkdir(exist_ok=True)

rd = lambda f: pd.read_csv(RAW / f)
orders, items, cust = rd("olist_orders_dataset.csv"), rd("olist_order_items_dataset.csv"), rd("olist_customers_dataset.csv")
prod, pay, rev = rd("olist_products_dataset.csv"), rd("olist_order_payments_dataset.csv"), rd("olist_order_reviews_dataset.csv")
sell, cat = rd("olist_sellers_dataset.csv"), rd("product_category_name_translation.csv")

audit = []
def log(step, n):
    audit.append({"step": step, "rows_affected": int(n)})
    print(step, "->", int(n))

# ---------- 2. CLEAN ----------
for c in ["order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date",
          "order_delivered_customer_date", "order_estimated_delivery_date"]:
    orders[c] = pd.to_datetime(orders[c], errors="coerce")

bad = orders["order_delivered_customer_date"] < orders["order_purchase_timestamp"]
log("delivery before purchase (nulled)", bad.sum())
orders.loc[bad, "order_delivered_customer_date"] = pd.NaT

for n, df in {"orders": orders, "items": items, "cust": cust, "prod": prod}.items():
    log(f"duplicates dropped: {n}", df.duplicated().sum())
orders, items, cust, prod = [d.drop_duplicates() for d in (orders, items, cust, prod)]

bad_price = (items["price"] <= 0) | (items["freight_value"] < 0)
log("invalid price/freight rows removed", bad_price.sum())
items = items[~bad_price]

prod = prod.merge(cat, on="product_category_name", how="left")
log("products with no category", prod["product_category_name_english"].isna().sum())
prod["category"] = (prod["product_category_name_english"].fillna("unknown")
                    .str.replace("_", " ").str.strip().str.title())

cust["customer_city"] = cust["customer_city"].str.strip().str.title()
cust["customer_state"] = cust["customer_state"].str.strip().str.upper()
sell["seller_state"] = sell["seller_state"].str.strip().str.upper()

# ---------- 3. BUILD ITEM-LEVEL TABLE ----------
COST_RATIO, FREIGHT_LIMIT, MARGIN_THRESHOLD = 0.70, 0.30, 15

voucher = pay[pay.payment_type == "voucher"].groupby("order_id")["payment_value"].sum().rename("order_voucher")
score = rev.groupby("order_id")["review_score"].mean().rename("review_score")

f = (items.merge(orders, on="order_id")
          .merge(cust[["customer_id", "customer_unique_id", "customer_state", "customer_city"]], on="customer_id")
          .merge(prod[["product_id", "category"]], on="product_id")
          .merge(sell[["seller_id", "seller_state"]], on="seller_id", how="left")
          .merge(voucher, on="order_id", how="left")
          .merge(score, on="order_id", how="left"))
f["order_voucher"] = f["order_voucher"].fillna(0)

f["list_price"] = f.groupby("product_id")["price"].transform("median")
f["gross_revenue"] = np.maximum(f["list_price"], f["price"])
price_gap = f["gross_revenue"] - f["price"]

f["voucher_share"] = (f["order_voucher"] * f["price"] / f.groupby("order_id")["price"].transform("sum")).clip(upper=f["price"])
f["discount_amount"] = price_gap + f["voucher_share"]
f["net_revenue"] = f["gross_revenue"] - f["discount_amount"]

f["product_cost"] = COST_RATIO * f["gross_revenue"]
f["shipping_cost"] = f["freight_value"]

late = f["order_delivered_customer_date"] > f["order_estimated_delivery_date"]
refund = f["order_status"].isin(["canceled", "unavailable"]) | \
         ((f["order_status"] == "delivered") & late & (f["review_score"] <= 2))
f["is_refund"] = refund.astype(int)
f["refund_amount"] = np.where(refund, f["net_revenue"], 0)

f["total_cost"] = f["product_cost"] + f["shipping_cost"] + f["refund_amount"]
f["gross_profit"] = f["net_revenue"] - f["total_cost"]
f["gross_margin_percentage"] = np.where(f["net_revenue"] >= 1, 100 * f["gross_profit"] / f["net_revenue"], np.nan)
f["excess_freight"] = np.maximum(0, f["freight_value"] - FREIGHT_LIMIT * f["price"])
f["revenue_leakage_amount"] = f["discount_amount"] + f["refund_amount"] + f["excess_freight"]
f["below_margin_threshold"] = ((f["gross_margin_percentage"] < MARGIN_THRESHOLD) | f["gross_margin_percentage"].isna()).astype(int)

f = f.round(2)
print(f.shape)
print(f[["price", "list_price", "discount_amount", "net_revenue", "refund_amount",
         "gross_profit", "gross_margin_percentage", "revenue_leakage_amount"]].describe().T)

# ---------- 4. QUALITY CHECKS + SAVE ----------
checks = {
    "no null net_revenue": f["net_revenue"].notna().all(),
    "no negative net_revenue": (f["net_revenue"] >= -0.01).all(),
    "profit = revenue - cost": np.allclose(f["gross_profit"], f["net_revenue"] - f["total_cost"], atol=0.05),
    "unique order_id+item_id": not f.duplicated(["order_id", "order_item_id"]).any(),
}
for k, v in checks.items():
    print("PASS" if v else "FAIL", "-", k)

f.to_csv(OUT / "fact_items_clean.csv", index=False)
pd.DataFrame(audit).to_csv("docs/audit_log.csv", index=False)
print("Saved fact_items_clean.csv and docs/audit_log.csv")