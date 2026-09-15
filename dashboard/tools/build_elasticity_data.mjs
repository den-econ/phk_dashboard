import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const root = path.resolve(import.meta.dirname, '..');
const csvDir = path.join(root, 'csv');

const provinceCodes = [
  '1100','1200','1300','1400','1500','1600','1700','1800','1900','2100',
  '3100','3200','3300','3400','3500','3600','5100','5200','5300','6100',
  '6200','6300','6400','6500','7100','7200','7300','7400','7500','7600',
  '8100','8200','9100','9400'
];

const provinceNames = {
  '1100':'Aceh','1200':'Sumatera Utara','1300':'Sumatera Barat','1400':'Riau',
  '1500':'Jambi','1600':'Sumatera Selatan','1700':'Bengkulu','1800':'Lampung',
  '1900':'Bangka Belitung','2100':'Kepulauan Riau','3100':'DKI Jakarta',
  '3200':'Jawa Barat','3300':'Jawa Tengah','3400':'DI Yogyakarta','3500':'Jawa Timur',
  '3600':'Banten','5100':'Bali','5200':'Nusa Tenggara Barat','5300':'Nusa Tenggara Timur',
  '6100':'Kalimantan Barat','6200':'Kalimantan Tengah','6300':'Kalimantan Selatan',
  '6400':'Kalimantan Timur','6500':'Kalimantan Utara','7100':'Sulawesi Utara',
  '7200':'Sulawesi Tengah','7300':'Sulawesi Selatan','7400':'Sulawesi Tenggara',
  '7500':'Gorontalo','7600':'Sulawesi Barat','8100':'Maluku','8200':'Maluku Utara',
  '9100':'Papua Barat','9400':'Papua'
};

const shockSpecs = [
  ['cpo','t1','eta_t1_cpo.csv'],
  ['coal','t1','eta_t1_coal.csv'],
  ['nickel','t1','eta_t1_nickel.csv'],
  ['copper','t1','eta_t1_copper.csv'],
  ['electronics','t1','eta_t1_electronics.csv'],
  ['rubber','t1','eta_t1_rubber.csv'],
  ['oilgas','t1','eta_t1_oilgas.csv'],
  ['export_basic_metal','t2','eta_t2_BasicMetal.csv'],
  ['export_chemical','t2','eta_t2_Chemical.csv'],
  ['export_coal','t2','eta_t2_Coal.csv'],
  ['export_coal_oil_man','t2','eta_t2_CoalOilMan.csv'],
  ['export_estates','t2','eta_t2_Estates.csv'],
  ['export_fishery','t2','eta_t2_Fishery.csv'],
  ['export_food_man','t2','eta_t2_FoodMan.csv'],
  ['export_forestry','t2','eta_t2_Forestry.csv'],
  ['export_furniture','t2','eta_t2_Furniture.csv'],
  ['export_horti_crops','t2','eta_t2_HortiCrops.csv'],
  ['export_iron_ore','t2','eta_t2_IronOre.csv'],
  ['export_leather','t2','eta_t2_Leather.csv'],
  ['export_machinery','t2','eta_t2_Machinery.csv'],
  ['export_metal_prod','t2','eta_t2_MetalProd.csv'],
  ['export_non_metal_prod','t2','eta_t2_NonMetalProd.csv'],
  ['export_oil_gas_geo','t2','eta_t2_OilGasGeo.csv'],
  ['export_other_man','t2','eta_t2_OtherMan.csv'],
  ['export_paper_prod','t2','eta_t2_PaperProd.csv'],
  ['export_rubber','t2','eta_t2_Rubber.csv'],
  ['export_textiles','t2','eta_t2_Textiles.csv'],
  ['export_tobacco','t2','eta_t2_Tobacco.csv'],
  ['export_transport_equip','t2','eta_t2_TranspEquip.csv'],
  ['export_wood_prod','t2','eta_t2_WoodProd.csv'],
  ['ipr_food','t3','eta_t3_food_bev_tobacco.csv'],
  ['ipr_clothing','t3','eta_t3_sandang.csv'],
  ['ipr_fuel','t3','eta_t3_fuel.csv'],
  ['ipr_recreation','t3','eta_t3_cultural_rec.csv'],
  ['ipr_ict','t3','eta_t3_ict_equipment.csv'],
  ['ipr_household','t3','eta_t3_household_equip.csv'],
  ['ipr_parts','t3','eta_t3_spare_parts.csv'],
  ['ipr_other','t3','eta_t3_other_goods.csv']
];

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function readMatrix(file) {
  const text = fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '').trim();
  const lines = text.split(/\r?\n/);
  const header = lines[0].split(',').slice(1);
  if (header.length !== 34 || header.some((v, i) => v !== provinceCodes[i])) {
    throw new Error(`${path.basename(file)} has an unexpected province header`);
  }
  if (lines.length !== 53) throw new Error(`${path.basename(file)} must contain 52 sector rows`);

  return lines.slice(1).map((line, index) => {
    const cells = line.split(',');
    const expected = `s${String(index + 1).padStart(2, '0')}`;
    if (cells[0] !== expected || cells.length !== 35) {
      throw new Error(`${path.basename(file)} row ${index + 2} is malformed`);
    }
    return cells.slice(1).map((raw) => {
      const value = Number(raw);
      if (!Number.isFinite(value)) throw new Error(`${path.basename(file)} contains a non-numeric value`);
      return value;
    });
  });
}

const shocks = {};
const sources = [];
for (const [id, theme, filename] of shockSpecs) {
  const file = path.join(csvDir, filename);
  const values = readMatrix(file);
  shocks[id] = { theme, source: filename, values };
  sources.push({ filename, sha256: sha256(file) });
}

const payload = {
  meta: {
    generated_at: new Date().toISOString(),
    source_directory: 'csv',
    model: 'IndoTERM',
    value_definition: 'Percent change in sector-province employment caused by a one-percent shock in the named model run.',
    sector_count: 52,
    model_region_count: 34,
    shock_count: shockSpecs.length,
    theme2_method: 'The 23 export-demand matrices are summed and multiplied by the partner-share-weighted trading-partner growth shock.',
    regional_bridge: {
      'Papua Barat Daya': 'Papua Barat',
      'Papua Selatan': 'Papua',
      'Papua Tengah': 'Papua',
      'Papua Pegunungan': 'Papua'
    }
  },
  province_codes: provinceCodes,
  province_names: provinceCodes.map((code) => provinceNames[code]),
  sector_codes: Array.from({ length: 52 }, (_, i) => i + 1),
  sources,
  shocks
};

const json = JSON.stringify(payload);
fs.writeFileSync(path.join(root, 'dashboard_elasticity_data.json'), `${json}\n`);
fs.writeFileSync(path.join(root, 'dashboard_elasticity_data.js'), `window.PHK_ELASTICITY_DATA=${json};\n`);

const values = Object.values(shocks).flatMap((shock) => shock.values.flat());
const stats = {
  shocks: Object.keys(shocks).length,
  values: values.length,
  min: Math.min(...values),
  max: Math.max(...values),
  mean_abs: values.reduce((sum, value) => sum + Math.abs(value), 0) / values.length
};
console.log(JSON.stringify(stats, null, 2));
