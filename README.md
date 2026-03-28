# Rwanda Crop Yield Prediction — Linear Regression Summative

## Mission & Problem
Smallholder farmers in Rwanda lack data-driven tools to estimate crop yields before harvest. This project builds a multivariate regression model predicting crop yield (hg/ha) from agronomic inputs including area harvested, production trends, crop type, and year. The goal is to empower agricultural extension officers and farmers with informed, data-backed decisions that improve food security across Rwanda's five provinces.

## Live API — Swagger UI
Click the link below to access the live API and test predictions:

**[https://rwanda-crop-yield.onrender.com/docs](https://rwanda-crop-yield.onrender.com/docs)**

## Video Demo
**[https://youtu.be/bEeHgEo1eHM]()**

## How to Run the Mobile App

**Requirements:** Flutter installed on your machine

```bash
# Step 1 — Clone the repo
git clone https://github.com/62Laura/linear_regression_model.git
cd linear_regression_model

# Step 2 — Navigate to the Flutter app
cd summative
cd FlutterApp
cd crop_yield_app

# Step 3 — Install dependencies
flutter pub get

# Step 4 — Run the app
flutter run
```

> Make sure you have an Android emulator or iOS simulator running before `flutter run`.

## Repository Structure

```
linear_regression_model/
├── README.md
└── summative/
    ├── linear_regression/
    │   ├── multivariate.ipynb        ← Task 1 notebook
    │   └── FAOSTAT_data_en_3-12-2026.csv
    ├── API/
    │   ├── prediction.py             ← FastAPI app
    │   ├── requirements.txt
    │   └── saved_model/              ← trained model files
    └── FlutterApp/
        └── crop_yield_app/           ← Flutter mobile app
```

## Dataset
**Source:** FAOSTAT — Rwanda Crops and Livestock Products (1961–2024)
**Crops:** 35 crop types | **Rows:** 1,384 clean records
**Target:** `yield` — crop yield in hectograms per hectare (hg/ha)

## Models Trained
| Model | RMSE | R² |
|-------|------|-----|
| Linear Regression (SGD) | 30.39 hg/ha | 0.9999 |
| Random Forest | 1,237 hg/ha | 0.9583 |
| Decision Tree | 1,674 hg/ha | 0.9236 |

**Best model:** Linear Regression — saved and deployed via FastAPI on Render.
