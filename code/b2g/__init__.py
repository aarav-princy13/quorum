"""brand_to_generic backend package.

Pure standard-library Python (sqlite3, csv). No third-party deps, no pandas.

Pipeline: parsed receipt line items (text)  ->  for each drug:
  - find its salt + strength
  - find cheaper generic equivalents (same salt + strength)
  - compute savings
  - classify Schedule H/H1/X and decide if an Rx confirmation is required
"""

from .db import connect, build_db, load_seed
from .matcher import find_alternatives, normalize
from .schedule import classify_schedule, schedule_for_salts
from .pipeline import process_receipt, nearby_pharmacies
from .report import build_report

__all__ = [
    "connect",
    "build_db",
    "load_seed",
    "find_alternatives",
    "normalize",
    "classify_schedule",
    "schedule_for_salts",
    "process_receipt",
    "nearby_pharmacies",
    "build_report",
]
