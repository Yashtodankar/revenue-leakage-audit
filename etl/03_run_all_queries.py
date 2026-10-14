import os, pandas as pd
from urllib.parse import quote_plus
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
pw = quote_plus(os.getenv("DB_PASS"))
engine = create_engine(f"mysql+pymysql://{os.getenv('DB_USER')}:{pw}@{os.getenv('DB_HOST','localhost')}/revenue_audit")

sql = open("sql/03_audit_queries.sql", encoding="utf-8").read()
out = []
for stmt in sql.split(";"):
    s = stmt.strip()
    if not s or s.upper().startswith("USE"):
        continue
    title = s.splitlines()[0]
    try:
        df = pd.read_sql(text(s), engine)
        out.append(title + "\n" + df.head(15).to_string(index=False))
    except Exception as e:
        out.append(title + "\nERROR: " + str(e)[:200])

open("docs/query_results.txt", "w", encoding="utf-8").write("\n\n".join(out))
print("Done: docs/query_results.txt")