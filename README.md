# PHK Early Warning Dashboard

Prototype dashboard and technical materials for monitoring layoff pressure
across Indonesian sectors and provinces.

## Recommended entry points

- Latest dashboard:
  `dashboard/PHK Early Warning Dashboard — Dewan Ekonomi update v5.html`
- Full province table:
  `dashboard/PHK Shock Simulation Full Province Table.html`
- Final technical presentation:
  `presentations/PHK Early Warning Dashboard - Technical Notes - Final.pptx`

The HTML dashboards are self-contained and can be opened directly in a modern
browser.

## Repository structure

| Directory | Contents |
| --- | --- |
| `dashboard/` | All retained HTML dashboard versions and the full province table |
| `presentations/` | Final presentation only |
| `data/source/` | Source workbooks and sector-province employment data |
| `data/model-outputs/` | Generated LLI and sector-province data embedded in the dashboard |
| `data/geospatial/` | Indonesian province GeoJSON/JSON boundaries |
| `methodology/` | Layoff-risk and CGE/IndoTERM methodology documents |
| `assets/` | Reference images and dashboard mockups |
| `scripts/` | Python scripts used to patch, embed, and validate dashboard files |
| `archive/` | Earlier bundled source archive retained for reference |

## Methodological scope

- The Layoff Pressure Index combines structural exposure, current economic
  pressure, labor-market signals, and external exposure.
- Provincial clusters are exploratory and indicative. They are based on
  descriptive economic characteristics and common layoff-risk transmission
  channels, rather than a statistical clustering algorithm.
- IndoTERM is used offline to calibrate sector-province employment
  elasticities. The dashboard applies current or custom shocks to stored
  elasticities; it does not solve the full CGE model in the browser.
- Fractional-logit and Labor Leading Indicator results are supplied as
  precomputed model outputs.
- Several simulation values remain placeholders until official elasticity
  tensors and live data pipelines are connected.

## Key data notes

- `lo.csv` contains baseline employment by province and 52-sector code.
- `Komposit_LEI_Ketenagakerjaan.xlsx` contains national and provincial LLI
  output series.
- The two original `Data untuk PHK Dashboard` workbooks were byte-identical;
  only one cleanly named copy is retained here.

## Status

This repository contains a working analytical prototype. Review data vintages,
model assumptions, and placeholder status before using outputs for formal
policy communication.
