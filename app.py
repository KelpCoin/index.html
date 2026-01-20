import os
import secrets
import sqlite3
from datetime import date, datetime
from urllib.parse import urlencode, urlparse, urlunparse, parse_qsl

from flask import Flask, abort, redirect, render_template, request

DB_PATH = os.environ.get("UTM_DB", "utm.sqlite3")
APP_HOST = os.environ.get("UTM_HOST", "127.0.0.1")
APP_PORT = int(os.environ.get("UTM_PORT", "5000"))

app = Flask(__name__)


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS campaigns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            destination_url TEXT NOT NULL,
            utm_source TEXT NOT NULL,
            utm_medium TEXT NOT NULL,
            utm_campaign TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            cost_total REAL DEFAULT 0,
            created_at TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS clicks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            campaign_id INTEGER NOT NULL,
            clicked_at TEXT NOT NULL,
            ip_address TEXT,
            user_agent TEXT,
            referrer TEXT,
            FOREIGN KEY (campaign_id) REFERENCES campaigns(id)
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            campaign_id INTEGER NOT NULL,
            order_id TEXT,
            revenue REAL NOT NULL,
            ordered_at TEXT NOT NULL,
            FOREIGN KEY (campaign_id) REFERENCES campaigns(id)
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS spend (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            spend_date TEXT NOT NULL,
            amount REAL NOT NULL
        )
        """
    )
    conn.commit()
    conn.close()


def generate_code():
    return secrets.token_urlsafe(6).rstrip("=")


def build_destination(campaign):
    url = urlparse(campaign["destination_url"])
    params = dict(parse_qsl(url.query))
    params.update(
        {
            "utm_source": campaign["utm_source"],
            "utm_medium": campaign["utm_medium"],
            "utm_campaign": campaign["utm_campaign"],
        }
    )
    new_query = urlencode(params)
    return urlunparse(
        (url.scheme, url.netloc, url.path, url.params, new_query, url.fragment)
    )


@app.route("/", methods=["GET"])
def dashboard():
    conn = get_db()
    campaigns = conn.execute(
        """
        SELECT c.*, 
            COUNT(cl.id) AS click_count,
            COUNT(o.id) AS order_count,
            COALESCE(SUM(o.revenue), 0) AS revenue_total
        FROM campaigns c
        LEFT JOIN clicks cl ON cl.campaign_id = c.id
        LEFT JOIN orders o ON o.campaign_id = c.id
        GROUP BY c.id
        ORDER BY revenue_total DESC, click_count DESC
        """
    ).fetchall()

    daily_rows = conn.execute(
        """
        SELECT d.day,
            COALESCE(clicks.click_count, 0) AS click_count,
            COALESCE(orders.order_count, 0) AS order_count,
            COALESCE(orders.revenue_total, 0) AS revenue_total,
            COALESCE(spend.amount_total, 0) AS spend_total
        FROM (
            SELECT DATE(clicked_at) AS day FROM clicks
            UNION
            SELECT DATE(ordered_at) AS day FROM orders
            UNION
            SELECT spend_date AS day FROM spend
        ) d
        LEFT JOIN (
            SELECT DATE(clicked_at) AS day, COUNT(*) AS click_count
            FROM clicks
            GROUP BY DATE(clicked_at)
        ) clicks ON clicks.day = d.day
        LEFT JOIN (
            SELECT DATE(ordered_at) AS day, COUNT(*) AS order_count, SUM(revenue) AS revenue_total
            FROM orders
            GROUP BY DATE(ordered_at)
        ) orders ON orders.day = d.day
        LEFT JOIN (
            SELECT spend_date AS day, SUM(amount) AS amount_total
            FROM spend
            GROUP BY spend_date
        ) spend ON spend.day = d.day
        ORDER BY d.day DESC
        """
    ).fetchall()

    conn.close()

    return render_template(
        "dashboard.html",
        campaigns=campaigns,
        daily_rows=daily_rows,
        host_url=request.host_url.rstrip("/"),
    )


@app.route("/campaigns", methods=["POST"])
def create_campaign():
    name = request.form.get("name", "").strip()
    destination_url = request.form.get("destination_url", "").strip()
    utm_source = request.form.get("utm_source", "").strip()
    utm_medium = request.form.get("utm_medium", "").strip()
    utm_campaign = request.form.get("utm_campaign", "").strip()
    cost_total = request.form.get("cost_total", "0").strip()

    if not all([name, destination_url, utm_source, utm_medium, utm_campaign]):
        abort(400, "All campaign fields are required.")

    code = generate_code()
    created_at = datetime.utcnow().isoformat()

    conn = get_db()
    conn.execute(
        """
        INSERT INTO campaigns
            (name, destination_url, utm_source, utm_medium, utm_campaign, code, cost_total, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            name,
            destination_url,
            utm_source,
            utm_medium,
            utm_campaign,
            code,
            float(cost_total or 0),
            created_at,
        ),
    )
    conn.commit()
    conn.close()

    return redirect("/")


@app.route("/orders", methods=["POST"])
def create_order():
    code = request.form.get("code", "").strip()
    revenue = request.form.get("revenue", "").strip()
    order_id = request.form.get("order_id", "").strip() or None

    if not code or not revenue:
        abort(400, "Campaign code and revenue are required.")

    conn = get_db()
    campaign = conn.execute(
        "SELECT id FROM campaigns WHERE code = ?",
        (code,),
    ).fetchone()
    if campaign is None:
        conn.close()
        abort(404, "Campaign not found.")

    conn.execute(
        """
        INSERT INTO orders (campaign_id, order_id, revenue, ordered_at)
        VALUES (?, ?, ?, ?)
        """,
        (campaign["id"], order_id, float(revenue), datetime.utcnow().isoformat()),
    )
    conn.commit()
    conn.close()

    return redirect("/")


@app.route("/spend", methods=["POST"])
def create_spend():
    spend_date = request.form.get("spend_date", "").strip() or date.today().isoformat()
    amount = request.form.get("amount", "").strip()
    if not amount:
        abort(400, "Spend amount is required.")

    conn = get_db()
    conn.execute(
        "INSERT INTO spend (spend_date, amount) VALUES (?, ?)",
        (spend_date, float(amount)),
    )
    conn.commit()
    conn.close()
    return redirect("/")


@app.route("/r/<code>")
def redirect_campaign(code):
    conn = get_db()
    campaign = conn.execute(
        "SELECT * FROM campaigns WHERE code = ?",
        (code,),
    ).fetchone()
    if campaign is None:
        conn.close()
        abort(404, "Campaign not found.")

    conn.execute(
        """
        INSERT INTO clicks (campaign_id, clicked_at, ip_address, user_agent, referrer)
        VALUES (?, ?, ?, ?, ?)
        """,
        (
            campaign["id"],
            datetime.utcnow().isoformat(),
            request.headers.get("X-Forwarded-For", request.remote_addr),
            request.headers.get("User-Agent"),
            request.headers.get("Referer"),
        ),
    )
    conn.commit()
    conn.close()

    destination = build_destination(campaign)
    return redirect(destination, code=302)


if __name__ == "__main__":
    init_db()
    app.run(host=APP_HOST, port=APP_PORT, debug=False)
