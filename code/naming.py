"""
naming.py — shared column-name shortener so every generated artifact (dictionary,
schema, .do) uses identical names that fit Stata's 32-character variable limit.

Applies readable, consistent econ abbreviations (not cryptic truncation) plus
compact frequency/scope suffixes. Imported by build_crosswalk.py and gen_pipeline.py.
The full original Bahasa/English label is preserved in indicator_dictionary.csv, so
no meaning is lost — only the machine column name is abbreviated.
"""
import re

# ordered, most-specific first; concept abbreviations, then frequency/scope suffixes
ABBR=[
 ("public_admin_defense_social_security","public_admin"),
 ("agriculture_forestry_fishery","agri"),("agriculture","agri"),
 ("information_communication","info_comm"),
 ("laborcost_share_total_labor_cost","laborcost_share"),
 ("labor_cost_share_total_labor_cost","laborcost_share"),
 ("nonproduction_wage_per_nonproduction_worker","nonprod_wage_per_worker"),
 ("production_wage_per_production_worker","prod_wage_per_worker"),
 ("nonproduction","nonprod"),("production","prod"),
 ("value_added_factor_cost","va_fc"),("value_added_market","va_mkt"),("value_added","va"),
 ("labor_productivity_factor_cost","labor_prod_fc"),("labor_productivity","labor_prod"),
 ("manufacturing","manuf"),("manufaktur","manuf"),
 ("underemployment","underemp"),
 ("nonagri_informal_employment_share","nonagri_informal_share"),
 ("informal_employment_share","informal_share"),
 ("share_growth_from_2019_pp","share_chg_vs2019"),
 ("written_contract","contract"),
 ("working_population","working_pop"),("unpaid_family_workers","unpaid_family"),
 ("accommodation_food","accom_food"),("transport_warehousing","transport"),
 ("water_waste_management","water_waste"),("financial_insurance","finance"),
 ("business_services","business_svc"),("other_services","other_svc"),("services","svc"),
 ("electricity_gas","electricity"),("mining_quarrying","mining"),
 ("trade_repair","trade"),("health_social","health"),
 ("consumer_confidence_index","consumer_conf"),
 ("exchange_rate","fx"),("brent_oil_usd_per_barrel","brent_usd_bbl"),
 ("producer_change_ceic","producer_ceic"),
 ("diff_growth","diffgr"),
 ("output_value","output"),("input_cost","input"),
 ("labor_cost","laborcost"),("from_2019","vs2019"),
 ("job_seekers_registered","job_seekers"),("per_worker","per_wkr"),
 ("_quarterly","_q"),("_annual","_y"),("_national","_nat"),
]
_KEEP={'excluded_from_master','manual_review_required',''}

def shorten(name):
    """Abbreviate a snake_case column name to <=32 chars, deterministically."""
    if name in _KEEP: return name
    s=name
    for a,b in ABBR: s=s.replace(a,b)
    return re.sub(r'_+','_',s).strip('_')
