# System Design

- postgres stores transactions and daily rollups
- n8n handles normalization and daily aggregation
- dashboard reads summary tables

## Data Model

- accounts
- payment_methods
- transactions
- daily_cashflow

## Workflow Plan

1. manual entry arrives through form or webhook
2. n8n validates and stores transaction
3. daily aggregation updates source-based totals
4. dashboard queries daily summary

## Implementation Steps

1. add payment method and account reference schema
2. add write path for manual transactions
3. add daily aggregation workflow
4. add dashboard query contract

## Validation

- test one expense transaction
- test one transfer-like transaction
- test grouped day summary
