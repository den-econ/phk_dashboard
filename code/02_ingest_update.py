"""
02_ingest_update.py  (stub, not yet implemented)
Purpose: read files from incoming_data/, standardize columns and province names,
validate the province_std + year + month key, then upsert into
clean_data/phk_master.csv (insert new rows, update existing rows, archive
overwritten values), and append to logs/ingestion_log.csv.
Reuses utils.standardize_province_name, utils.validate_keys, utils.write_log.
TODO: implement upsert. Do not repeat the full MAP and PHK baseline merge here.
"""
if __name__ == "__main__":
    raise NotImplementedError("02_ingest_update.py is a documented stub.")
