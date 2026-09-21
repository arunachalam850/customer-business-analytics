"""
End-to-end ETL script for the Customer & Business Analytics project.
Run with:
    python etl_pipeline.py

Expected input folder: ../data
Output folder: ../data/processed
"""

from pathlib import Path
import pandas as pd
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
OUT = DATA / "processed"
OUT.mkdir(exist_ok=True)

def load():
    customers = pd.read_csv(DATA / "customers.csv", parse_dates=["signup_date"])
    products = pd.read_csv(DATA / "products.csv")
    orders = pd.read_csv(DATA / "orders.csv", parse_dates=["order_datetime"])
    items = pd.read_csv(DATA / "order_items.csv")
    returns = pd.read_csv(DATA / "returns.csv", parse_dates=["return_date"])
    support = pd.read_csv(DATA / "support_tickets.csv", parse_dates=["opened_datetime","resolved_datetime"])
    campaigns = pd.read_csv(DATA / "campaign_touchpoints.csv", parse_dates=["touch_date"])
    return customers, products, orders, items, returns, support, campaigns

def clean_and_engineer():
    customers, products, orders, items, returns, support, campaigns = load()

    # Basic validation
    customers = customers.drop_duplicates("customer_id")
    products = products.drop_duplicates("product_id")
    orders = orders.drop_duplicates("order_id")
    items = items.drop_duplicates("order_item_id")

    # Standardize categories and remove invalid amounts
    products["gross_margin_per_unit"] = products["list_price"] - products["unit_cost"]
    items["discount_amount"] = items["discount_amount"].clip(lower=0)
    orders["order_total"] = orders["order_total"].clip(lower=0)

    # Useful dates
    orders["order_date"] = orders["order_datetime"].dt.date
    orders["year"] = orders["order_datetime"].dt.year
    orders["month"] = orders["order_datetime"].dt.to_period("M").astype(str)

    # Customer lifetime metrics
    valid_orders = orders[orders["order_status"].isin(["Completed","Returned"])].copy()
    customer_metrics = (
        valid_orders.groupby("customer_id")
        .agg(
            total_orders=("order_id","nunique"),
            total_revenue=("order_total","sum"),
            avg_order_value=("order_total","mean"),
            last_order_date=("order_datetime","max")
        )
        .reset_index()
    )
    customer_metrics["recency_days"] = (
        valid_orders["order_datetime"].max().normalize() -
        customer_metrics["last_order_date"].dt.normalize()
    ).dt.days
    customer_metrics["repeat_customer"] = np.where(customer_metrics["total_orders"] > 1, 1, 0)

    # Product profitability
    item_enriched = items.merge(
        products[["product_id","category","unit_cost"]],
        on="product_id", how="left"
    )
    item_enriched["product_cost"] = item_enriched["quantity"] * item_enriched["unit_cost"]
    item_enriched["gross_profit"] = item_enriched["net_line_sales"] - item_enriched["product_cost"]

    # Daily business KPI table
    daily = (
        valid_orders.groupby("order_date")
        .agg(
            revenue=("order_total","sum"),
            orders=("order_id","nunique"),
            customers=("customer_id","nunique"),
            avg_order_value=("order_total","mean"),
            avg_delivery_days=("delivery_days","mean")
        ).reset_index()
    )

    # Campaign funnel
    campaign_summary = campaigns.groupby(
        ["campaign_name","touch_channel"], as_index=False
    ).agg(
        touches=("campaign_touch_id","count"),
        delivered=("delivered","sum"),
        opens=("opened","sum"),
        clicks=("clicked","sum"),
        conversions=("converted","sum"),
        spend=("spend","sum")
    )
    campaign_summary["CTR_pct"] = campaign_summary["clicks"] / campaign_summary["delivered"].replace(0,np.nan) * 100
    campaign_summary["conversion_rate_pct"] = campaign_summary["conversions"] / campaign_summary["clicks"].replace(0,np.nan) * 100
    campaign_summary["cost_per_conversion"] = campaign_summary["spend"] / campaign_summary["conversions"].replace(0,np.nan)

    # Write processed outputs
    customer_metrics.to_csv(OUT / "customer_metrics.csv", index=False)
    item_enriched.to_csv(OUT / "item_profitability.csv", index=False)
    daily.to_csv(OUT / "daily_kpis.csv", index=False)
    campaign_summary.to_csv(OUT / "campaign_summary.csv", index=False)

    return {
        "customers": len(customers),
        "products": len(products),
        "orders": len(orders),
        "order_items": len(items),
        "processed_customer_metrics": len(customer_metrics),
    }

if __name__ == "__main__":
    print(clean_and_engineer())
