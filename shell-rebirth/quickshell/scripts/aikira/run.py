#!/usr/bin/env python3
"""
Run the Aikira backend server.

Usage:
    python run.py                   # uses settings from .env
    python run.py --host 0.0.0.0   # expose on LAN
    python run.py --reload          # development hot-reload
"""

import argparse
import uvicorn

from app.config import settings


def main():
    parser = argparse.ArgumentParser(description="Aikira AI Chat Backend")
    parser.add_argument("--host", default=settings.host)
    parser.add_argument("--port", type=int, default=settings.port)
    parser.add_argument(
        "--reload",
        action="store_true",
        help="Enable hot-reload (development only)",
    )
    parser.add_argument(
        "--log-level",
        default="info",
        choices=["debug", "info", "warning", "error"],
    )
    args = parser.parse_args()

    print(f"  Aikira backend starting on http://{args.host}:{args.port}")
    print(f"  API docs: http://{args.host}:{args.port}/docs")

    uvicorn.run(
        "app.main:app",
        host=args.host,
        port=args.port,
        reload=args.reload,
        log_level=args.log_level,
    )


if __name__ == "__main__":
    main()