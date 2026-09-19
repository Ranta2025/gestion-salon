# Project: Gestión Salón

## Why

A hair salon owner/administrator needs clear, fast, visual control of the business finances:
how much comes in, how much goes out, and how much profit remains — without depending
on internet connectivity.

## What

Cross-platform mobile app (Android + iOS) built with Flutter to register daily income and
expenses, visualize a pastel pie chart of earnings vs. expenses, consult reports, and track
the financial health of the salon. 100% offline with local backup/restore.

## Tech Stack

- **Framework**: Flutter 3.47 (Dart 3.13) — Android + iOS targets
- **Local DB**: sqflite (SQLite) — single source of truth, fully offline
- **State**: Provider + ChangeNotifier (explicit, no codegen)
- **Charts**: fl_chart (pie + line)
- **Export**: pdf + printing (PDF reports), CSV via share_plus
- **Backup**: JSON export/import (file_picker + share_plus + path_provider)
- **No network dependencies**: no google_fonts, no HTTP calls, no cloud services.
  Release manifest must NOT request the INTERNET permission.

## Conventions

- Code, identifiers and comments: English. UI copy: Spanish (product requirement).
- Currency and date formatting via `intl` (es locale).
- Money stored as REAL (double) in SQLite; all aggregation done in SQL.
- Dates stored as ISO-8601 strings (`yyyy-MM-dd HH:mm:ss` for movements,
  `yyyy-MM-dd` for day keys, `yyyy-MM` for month keys).
- Design language: iOS-style (rounded cards, soft shadows, clean typography)
  with a pastel palette — mint (income), coral (expenses), lavender (accent).
