import os
from urllib.parse import quote_plus
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
pw = quote_plus(os.getenv("DB_PASS"))
engine = create_engine(f"mysql+pymysql://{os.getenv('DB_USER')}:{pw}@{os.getenv('DB_HOST','localhost')}/")

sql = open("sql/01_create_schema.sql", encoding="utf-8").read()
with engine.begin() as c:
    for stmt in sql.split(";"):
        if stmt.strip():
            c.execute(text(stmt))
print("Schema created")