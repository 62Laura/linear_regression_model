import os, json, shutil
import numpy as np
import pandas as pd
import joblib

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator

app = FastAPI(
    title="Rwanda Crop Yield Prediction API",
    description="Predicts crop yield (hg/ha) for Rwanda using Linear Regression trained on FAOSTAT data (1961-2024).",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL_DIR = "saved_model"

def load_artifacts():
    m  = joblib.load(os.path.join(MODEL_DIR, "best_model.pkl"))
    sc = joblib.load(os.path.join(MODEL_DIR, "scaler.pkl"))
    l  = joblib.load(os.path.join(MODEL_DIR, "label_encoder.pkl"))
    with open(os.path.join(MODEL_DIR, "features.json")) as f:
        ft = json.load(f)
    return m, sc, l, ft

model, scaler, le, FEATURES = load_artifacts()
VALID_CROPS = list(le.classes_)

class CropInput(BaseModel):
    year: int = Field(..., ge=1961, le=2030, description="Harvest year", example=2024)
    area_harvested: float = Field(..., gt=0, le=5000000, description="Area harvested (ha)", example=15000.0)
    production: float = Field(..., gt=0, le=50000000, description="Total production (tonnes)", example=180000.0)
    yield_lag1: float = Field(..., gt=0, le=200000, description="Previous year yield (hg/ha)", example=12000.0)
    yield_lag2: float = Field(..., gt=0, le=200000, description="Yield 2 years ago (hg/ha)", example=11500.0)
    yield_rolling3: float = Field(..., gt=0, le=200000, description="3-year average yield (hg/ha)", example=11800.0)
    crop_name: str = Field(..., description="Rwanda crop name", example="Bananas")

    @field_validator("crop_name")
    @classmethod
    def validate_crop(cls, v):
        if v not in VALID_CROPS:
            raise ValueError(f"'{v}' is not valid. Choose from: {VALID_CROPS}")
        return v

    model_config = {
        "json_schema_extra": {
            "example": {
                "year": 2024, "area_harvested": 15000.0, "production": 180000.0,
                "yield_lag1": 12000.0, "yield_lag2": 11500.0,
                "yield_rolling3": 11800.0, "crop_name": "Bananas"
            }
        }
    }

class PredictionResponse(BaseModel):
    predicted_yield_hg_ha: float
    predicted_yield_t_ha: float
    crop: str
    year: int
    unit: str

class RetrainResponse(BaseModel):
    message: str
    rows_used: int
    model_name: str
    r2: float
    rmse: float

# ── Helper ────────────────────────────────────────────────────────────────────
def build_features(data: CropInput) -> np.ndarray:
    decade         = (data.year // 10) * 10
    crop_encoded   = int(le.transform([data.crop_name])[0])
    log_area       = float(np.log1p(data.area_harvested))
    log_production = float(np.log1p(data.production))
    vector = np.array([[
        data.year, log_area, log_production,
        data.yield_lag1, data.yield_lag2, data.yield_rolling3,
        crop_encoded, decade
    ]])
    return scaler.transform(vector)

# ── Routes ────────────────────────────────────────────────────────────────────
@app.get("/", tags=["Health"])
def root():
    return {"message": "Rwanda Crop Yield Prediction API is running.", "docs": "/docs"}

@app.get("/health", tags=["Health"])
def health():
    return {"status": "ok", "model": "Linear Regression (SGD)", "crops_supported": len(VALID_CROPS)}

@app.get("/crops", tags=["Info"])
def list_crops():
    """Return all valid crop names accepted by the predict endpoint."""
    return {"valid_crops": VALID_CROPS, "count": len(VALID_CROPS)}

@app.post("/predict", tags=["Prediction"], response_model=PredictionResponse)
def predict(data: CropInput):
    """
    Predict crop yield (hg/ha) for Rwanda given farm inputs.
    - year: harvest year (1961-2030)
    - area_harvested: hectares (>0)
    - production: tonnes (>0)
    - yield_lag1: last year yield hg/ha (>0)
    - yield_lag2: 2 years ago yield hg/ha (>0)
    - yield_rolling3: 3-year average yield hg/ha (>0)
    - crop_name: one of 35 Rwanda crops
    """
    try:
        scaled   = build_features(data)
        predicted = max(0.0, float(model.predict(scaled)[0]))
        return PredictionResponse(
            predicted_yield_hg_ha=round(predicted, 2),
            predicted_yield_t_ha=round(predicted / 10000, 4),
            crop=data.crop_name,
            year=data.year,
            unit="hg/ha"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/retrain", tags=["Retraining"], response_model=RetrainResponse)
async def retrain(file: UploadFile = File(...)):
    """
    Upload a new FAOSTAT-format CSV to retrain the model on fresh data.
    Artifacts (model, scaler, encoder) are updated in-place.
    """
    global model, scaler, le, FEATURES
    tmp_path = f"/tmp/{file.filename}"
    with open(tmp_path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    try:
        from sklearn.model_selection import train_test_split
        from sklearn.preprocessing import StandardScaler, LabelEncoder
        from sklearn.linear_model import SGDRegressor
        from sklearn.metrics import mean_squared_error, r2_score

        df_raw   = pd.read_csv(tmp_path, encoding="utf-8-sig")
        df_clean = df_raw[df_raw["Value"].notna() & (df_raw["Flag"] != "M")].copy()
        pivot    = df_clean.pivot_table(
            index=["Area","Item","Year"], columns="Element",
            values="Value", aggfunc="first"
        ).reset_index()
        pivot.columns.name = None
        pivot.columns = [c.lower().replace(" ","_") for c in pivot.columns]
        pivot = pivot.sort_values(["item","year"]).reset_index(drop=True)
        pivot["yield_lag1"]     = pivot.groupby("item")["yield"].shift(1)
        pivot["yield_lag2"]     = pivot.groupby("item")["yield"].shift(2)
        pivot["yield_rolling3"] = pivot.groupby("item")["yield"].transform(lambda x: x.rolling(3,min_periods=1).mean())
        pivot["log_production"] = np.log1p(pivot["production"])
        pivot["log_area"]       = np.log1p(pivot["area_harvested"])
        pivot["decade"]         = (pivot["year"]//10)*10
        new_le  = LabelEncoder()
        pivot["crop_encoded"] = new_le.fit_transform(pivot["item"])
        pivot   = pivot.dropna(subset=["yield_lag1","yield_lag2","yield"])
        for col in ["log_production","log_area"]:
            pivot[col] = pivot[col].fillna(pivot[col].median())
        FT = ["year","log_area","log_production","yield_lag1","yield_lag2","yield_rolling3","crop_encoded","decade"]
        X  = pivot[FT].values
        y  = pivot["yield"].values
        X_train,X_test,y_train,y_test = train_test_split(X,y,test_size=0.2,random_state=42)
        new_sc = StandardScaler()
        X_tr   = new_sc.fit_transform(X_train)
        X_te   = new_sc.transform(X_test)
        new_m  = SGDRegressor(max_iter=500,tol=1e-4,learning_rate="invscaling",eta0=0.01,random_state=42)
        new_m.fit(X_tr, y_train)
        yp     = new_m.predict(X_te)
        r2v    = float(r2_score(y_test,yp))
        rmse_v = float(np.sqrt(mean_squared_error(y_test,yp)))
        joblib.dump(new_m,  os.path.join(MODEL_DIR,"best_model.pkl"))
        joblib.dump(new_sc, os.path.join(MODEL_DIR,"scaler.pkl"))
        joblib.dump(new_le, os.path.join(MODEL_DIR,"label_encoder.pkl"))
        with open(os.path.join(MODEL_DIR,"features.json"),"w") as f:
            json.dump(FT,f)
        model,scaler,le,FEATURES = new_m,new_sc,new_le,FT
        return RetrainResponse(
            message="Model retrained successfully.",
            rows_used=len(pivot), model_name="Linear Regression (SGD)",
            r2=round(r2v,4), rmse=round(rmse_v,2)
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Retraining failed: {str(e)}")
