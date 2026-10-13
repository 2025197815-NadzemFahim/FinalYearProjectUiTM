import pandas as pd

from ml import config


def _to_category_strings(s: pd.Series) -> pd.Series:
    def norm(v):
        if pd.isna(v):
            return float("nan")
        if isinstance(v, bool):
            return str(int(v))
        if isinstance(v, float) and v.is_integer():
            return str(int(v))
        return str(v)
    return s.map(norm).astype(object)


def prepare_features(df: pd.DataFrame, numeric: list, categorical: list) -> pd.DataFrame:
    missing = [c for c in numeric + categorical if c not in df.columns]
    if missing:
        raise KeyError(f"Missing feature columns: {missing}")
    out = pd.DataFrame(index=df.index)
    for c in numeric:
        out[c] = pd.to_numeric(df[c], errors="coerce").astype(float)
    for c in categorical:
        out[c] = _to_category_strings(df[c])
    return out


# ---------------------------------------------------------------- Layer 1
def load_brfss() -> tuple[pd.DataFrame, pd.DataFrame]:

    df = pd.read_csv(config.BRFSS_FILE)
    X = prepare_features(df, config.BRFSS_FEATURES, [])
    Y = df[config.BRFSS_TARGETS].astype(int)
    return X, Y


# ---------------------------------------------------------------- Layer 2
def _clean_heart(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["target"] = (df["num"] > 0).astype(int)            # 0 = no disease, 1-4 = disease
    for col in ["chol", "trestbps"]:
        df[col] = df[col].mask(df[col] == 0)
    return df


def _clean_stroke(df: pd.DataFrame) -> pd.DataFrame:
    return df.loc[df["gender"] != "Other"].copy()           # 1 row


def _clean_diabetes(df: pd.DataFrame) -> pd.DataFrame:
    df = df.drop_duplicates()
    return df.loc[df["gender"] != "Other"].copy()           # 18 rows


_CLEANERS = {"heart": _clean_heart, "stroke": _clean_stroke, "diabetes": _clean_diabetes}


def load_layer2(name: str) -> tuple[pd.DataFrame, pd.Series]:
    spec = config.LAYER2[name]
    df = _CLEANERS[name](pd.read_csv(spec["file"]))
    X = prepare_features(df, spec["numeric"], spec["categorical"])
    y = df[spec["target"]].astype(int)
    return X.reset_index(drop=True), y.reset_index(drop=True)
