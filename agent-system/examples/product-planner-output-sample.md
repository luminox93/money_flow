# Problem Definition

Users need to record where money was spent and which account or payment method funded it.

## Target Users

- one-person household
- users who want daily cashflow visibility

## Core User Flow

1. enter amount, merchant, and payment method
2. map the transaction to a source account
3. save the transaction
4. view daily `+` and `-` cashflow by source

## MVP Features

- manual transaction entry
- payment method selection
- source account selection
- transaction history
- daily cashflow summary

## Out of Scope

- automatic bank API sync
- OCR receipt parsing

## Success Metrics

- users can enter a transaction in under 20 seconds
- users can view daily source-based cashflow on mobile

## Handoff Notes

- design should focus on mobile-first quick entry
- development should model source account and payment method separately
