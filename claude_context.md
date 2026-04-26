# Claude Context — TwoWallet

## Project Overview

TwoWallet is a **Flutter mobile app for couples to manage money together**.

The app helps partners:

- track spending
- split shared expenses
- manage shared goals
- have weekly “Money Date” financial check-ins

The product uses a **freemium subscription model** with RevenueCat.

---

# Tech Stack

Frontend:
Flutter

State Management:
Riverpod

Backend:
Supabase

Subscriptions:
RevenueCat (purchases_flutter)

AI Feature:
Claude API used inside the Money Date screen.

---

# Folder Structure

lib/

features/

- home
- money_date
- fair_split
- goals
- spending
- transactions
- paywall

data/
services/

- revenue_cat_service.dart
- supabase_service.dart

shared/
providers/
widgets/
theme/

---

# Subscription Tiers

free
together
together_plus

The current tier is returned from:

RevenueCatService.getCurrentTier()

---

# Feature Gating Rules

Free tier:

• Money Date
only 1 talking point

• Goals
max 3 goals

• Transactions
manual entry only

Paid tiers:

Together / Together Plus unlock:

• all 3 Money Date talking points
• unlimited goals
• bank sync
• advanced insights

Paywall route:

/paywall

---

# UI Design System

Fonts:
Body → Inter
Headings → Plus Jakarta Sans

Spacing:
16px page padding
12px between cards

Corner Radius:
Cards → 16px
Buttons → 12px
Bottom sheets → 24px

Shadow:

BoxShadow(
color: Colors.black.withValues(alpha:0.06),
blurRadius: 12,
offset: Offset(0,4)
)

Background:
#F8F9FA

Cards:
white background
no borders
subtle shadow

Buttons:
full width
52px height
filled style only

---

# Brand Colors

Mine → #378ADD
Ours → #1D9E75
Theirs → #BA7517

Primary actions use **Ours (#1D9E75)**.

---

# UX Principles

The app UI should resemble modern fintech apps:

• Apple Wallet
• Copilot Money
• Revolut

Design goals:

minimal
clean
high readability
soft shadows
large spacing
touch-friendly

---

# Important Development Rules

Claude must follow these rules when modifying the project:

1. Never break existing logic.
2. Only modify UI when requested.
3. Follow Flutter best practices.
4. Keep Riverpod providers clean.
5. Maintain consistent spacing and styling.
6. Prefer reusable widgets over duplicated UI.

---

# Current Focus

The current development priorities are:

1. UI/UX modernization
2. subscription feature gating
3. paywall optimization
4. improving onboarding flow

---

# When Generating Code

Claude should:

• follow Flutter conventions
• avoid unnecessary rebuilds
• maintain null safety
• keep code production ready

All code must compile successfully.

# Analytics

Provider: PostHog
API Key env var: POSTHOG_API_KEY
Events tracked: signup_completed, partner_invited, transaction_added, goal_created, paywall_viewed, subscription_purchased

## Design Standards
Apply frontend-design skill for all UI work.
Target audience: couples 25–40, managing money together.
Design language: warm, modern, trustworthy. Think Monzo meets Notion.
Avoid: corporate, sterile, or generic fintech aesthetics.