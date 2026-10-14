# Findings (currency: BRL; cost = 70% of list price, refunds are a modelled proxy)

**Q1 KPIs.** Net revenue 13.28M, profit 0.69M, margin 5.22% vs 15% target. Leakage 1.52M (11.1% of gross revenue), more than total profit.
**Q2 Leakage split.** Refund proxy 47% (719k), discount 30% (457k), excess freight 23% (348k).
**Q3 Category leakage.** Largest by amount: Watches Gifts (122k), Bed Bath Table (118k), Health Beauty (114k). Highest rate among the top 15: Electronics 22.3%, Telephony 15.0%, Auto 13.9%.
**Q4 Loss-making products.** 4 of the 10 worst are Garden Tools (~-2.8k each on 150-390 lines); one Auto product loses 13.8k on 11 lines. Review pricing and freight for these.
**Q5 High revenue, low profit.** A Computers Accessories product (#3 by revenue) has -9.6% margin; a Garden Tools product (#17) -8.6%; a Bed Bath Table product (#6) earns 0.1%. Large sellers can still lose money.
**Q6 Loss-making customers.** The 10 worst losses (-1.7k to -3.4k) are each single high-value orders (revenue 2.3k-4.6k), so this is about individual orders (likely freight and refunds), not bad customers.
**Q7 Regions.** SP: 38% of revenue, 68% of profit. RJ is #2 for leakage (270k) with only 1.23% margin. BA, PE, CE and MA have negative margins; freight is 20-27% of revenue there versus 14% in SP.
**Q8 Below-average states.** 12 states have negative margin (RR, MA, SE, AC, AL, PI, CE, RN, TO, PE, PA, BA).
**Q9 Channel proxy (route).** Same-state: freight 13.2%, margin 10.21%. Cross-state: freight 18.7%, margin 2.95%, leakage 12.3%. Cross-state is 64% of lines.
**Q10 Channel proxy (seller state).** Negative margins for sellers in MA (-14.3%), ES (-3.6%), MT (-3.3%). MG sellers earn 1.3% on about 1M revenue; SP sellers 4.1% on 8.5M.
**Q11 Discount bands.** Margin: none 8.2%, up to 5% 8.5%, 5-10% 0.9%, 10-20% -4.8%, above 20% -182.8%. Caveat: this includes voucher-paid lines with near-zero revenue (see Q14) and the 70% cost assumption.
**Q12 Customer segments.** About 3% of customers order again. Repeat customers (2-3 orders) have a higher discount rate (4.1%) and lower margin (3.8%) than one-time customers (3.3%, 5.3%).
**Q13 Price anomalies.** Items priced over 50% away from the product's median price (e.g. 39.99 vs 229.90) are candidates to review. They may be genuine price changes, not errors.
**Q14 Order anomalies.** Many orders have a 100% discount (voucher covering the whole order) and lose 600-1,300 each. Voucher payments should be separated from price discounts.
**Q15 Refund impact.** Profit would be 1.41M before refunds versus 0.69M after, so the refund proxy removes about half of profit (5.4% of revenue).
**Q16 Refund reasons.** 87% of refund value (625k) is late delivery with a 1-2 star review; 13% (95k) is cancellations/unavailable.
**Q17 Refund rate by category.** Overall about 4.6%. Highest: Audio 9.1%, Musical Instruments 6.8%. Largest value: Health Beauty (57k at 5.0%).
**Q18 Shipping.** Margin by freight share of price: under 10% 16.8%, 10-20% 7.9%, 20-30% -3.3%, 30-50% -17.7%, above 50% -56.5%. Lines above 20% are 57% of lines, 27% of revenue, and lose about 0.59M.
**Q19 Monthly trend.** Margin 10.3% (Jan 2017) to 2.0% (Nov 2017, revenue +53%, profit fell from 55.8k to 19.8k). Negative in Feb 2018 (-1.1%) and Mar 2018 (-3.8%).
**Q20 Weakest categories by state.** Furniture Decor, Bed Bath Table and Garden Tools lose money in BA.

## Recommendations (conditional on the assumptions above)
- If late-delivery refunds are confirmed as real, prioritise delivery performance on long routes, since this is the largest modelled leak.
- If freight over 20% of price holds in real data, consider minimum order values, freight surcharges or regional seller routing for cheap items.
- Before capping discounts, split vouchers from price cuts and re-test Q11.
- Test the cost ratio at 60% and 80%; if the ranking of states and categories stays the same, treat those rankings as robust.