# Global COVID-19 Mortality Patterns

Country-level data engineering and machine learning analysis combining Johns Hopkins COVID-19 time series with World Bank Development Indicators. This was my PSTAT 135 final project.

## Results

- **209 countries** in the final modeling table; mortality is measured as reported deaths per 100,000 people through March 9, 2023.
- PCA's first component explained about **44%** of predictor variance. A three-cluster K-Means solution provided exploratory country profiles.
- A Random Forest classified countries in the highest mortality quartile with **82.5% accuracy** and **75% recall** on one held-out test split, compared with about **74.6% majority-class accuracy**.

These are descriptive and predictive associations, not causal effects. Country-level reporting quality varies, and the classifier was evaluated on one small test split. Read the [full report](Final_Project_Report.pdf) or its [source](Final_Project_Report_Revised.qmd) for methods and limitations.

## Reproduce the analysis

The [notebook](analysis/covid_wdi_analysis.ipynb) reads the included 209-country [modeling table](analysis/exports/country_covid_wdi_modeling.csv). From the repository root:

```bash
python -m pip install -r requirements.txt
jupyter lab analysis/covid_wdi_analysis.ipynb
```

Run the cells in order. The saved notebook outputs and `figures/` show the reported results without needing Google Cloud credentials. The modeling table was produced from the included source CSVs by the scripts in `scripts/ingestion/` and BigQuery SQL in `sql/`; [EXECUTION_GUIDE.md](EXECUTION_GUIDE.md) describes that cloud workflow. Rerunning the cloud pipeline requires your own Google Cloud project and BigQuery configuration.

## Data and repository contents

- `data/raw/jhu/`: Johns Hopkins CSSE confirmed-case, death, and country lookup snapshots.
- `data/raw/wdi/`: selected World Bank indicators for 2019 and 2020, with 2019 preferred where available.
- `analysis/`: final modeling table and Python notebook.
- `figures/`: charts used in the report.
- `sql/`: BigQuery transformations and validation checks.

Original data sources: [Johns Hopkins CSSE](https://github.com/CSSEGISandData/COVID-19) and [World Bank WDI](https://data.worldbank.org/). The included snapshots preserve the analysis as performed; they are not a current COVID-19 dataset.
