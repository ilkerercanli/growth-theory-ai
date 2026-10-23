# --- 2. CMIP6 (Google Cloud açık arşivi, CC BY 4.0): 5 iklim modeli × tarihsel + 3 SSP; aylık tas, pr, hurs; alan noktalarında ---
GCM = ['GFDL-ESM4', 'IPSL-CM6A-LR', 'MPI-ESM1-2-HR', 'MRI-ESM2-0', 'UKESM1-0-LL']
SSP = ['ssp126', 'ssp245', 'ssp585']; DEG3 = ['tas', 'pr', 'hurs']
KLS = os.path.join(ANA, 'CMIP6'); os.makedirs(KLS, exist_ok=True)
LATs, LONs = d['site_lat'].astype(float), d['site_lon'].astype(float)
def cmip_indir():
    import subprocess
    for paket in ['zarr', 'gcsfs']:            # Colab'da zarr kurulu gelmiyor
        try: importlib.import_module(paket)
        except ImportError: subprocess.run([sys.executable, '-m', 'pip', '-q', 'install', paket], check=False)
    importlib.invalidate_caches()
    import xarray as xr, fsspec
    try:                                                   # yeni kurulan zarr motorunu xarray'e tanıt (önbellekleri temizle)
        import xarray.namedarray.utils as _nu; _nu.module_available.cache_clear()
    except Exception: pass
    try: xr.backends.plugins.list_engines.cache_clear()
    except Exception: pass
    print('zarr', importlib.import_module('zarr').__version__, '| motorlar:', list(xr.backends.list_engines()))
    KAT = pd.read_csv('https://storage.googleapis.com/cmip6/cmip6-zarr-consolidated-stores.csv')
    KAT = KAT[(KAT.table_id == 'Amon') & KAT.variable_id.isin(DEG3) & KAT.experiment_id.isin(['historical'] + SSP)]
    lisans = []
    def ac(zs):
        try: return xr.open_zarr(zs, consolidated=True, storage_options={'token': 'anon'})
        except Exception as h1_:
            try: return xr.open_zarr(zs.replace('gs://', 'https://storage.googleapis.com/'), consolidated=True)
            except Exception: raise h1_
    def noktalar(ds, v, y0, y1):
        da = ds[v].sel(time=slice(str(y0), str(y1))).squeeze(drop=True)
        la = 'lat' if 'lat' in da.dims else 'latitude'; lo = 'lon' if 'lon' in da.dims else 'longitude'
        lons = LONs % 360 if float(da[lo].max()) > 180 else LONs
        da = da.sel({la: xr.DataArray(LATs, dims='s'), lo: xr.DataArray(lons, dims='s')}, method='nearest').load()
        out = np.full((y1 - y0 + 1, 12, S), np.nan, np.float32)
        yy, mm = da['time'].dt.year.values, da['time'].dt.month.values; k_ = (yy >= y0) & (yy <= y1)
        out[yy[k_] - y0, mm[k_] - 1, :] = da.values[k_]
        return out
    for g in GCM:
        q = KAT[KAT.source_id == g]
        uyeler = sorted(q.member_id.unique(), key=lambda m_: (m_ != 'r1i1p1f1', m_ != 'r1i1p1f2', m_))
        uye = next((m_ for m_ in uyeler if all(((q.member_id == m_) & (q.experiment_id == e) & (q.variable_id == v)).any()
                                                for e in ['historical'] + SSP for v in DEG3)), None)
        if uye is None: print('ATLANDI (eksik veri):', g); continue
        def zs(e, v): return q[(q.member_id == uye) & (q.experiment_id == e) & (q.variable_id == v)].sort_values('version').iloc[-1].zstore
        f_h = os.path.join(KLS, f'{g}_historical.npz')
        if not os.path.exists(f_h):
            np.savez_compressed(f_h, **{v: noktalar(ac(zs('historical', v)), v, 1985, 2014) for v in DEG3})
        for e in SSP:
            f_e = os.path.join(KLS, f'{g}_{e}.npz')
            if not os.path.exists(f_e):
                np.savez_compressed(f_e, **{v: noktalar(ac(zs(e, v)), v, 2015, 2100) for v in DEG3})
            print('tamam:', g, e, uye)
        lisans.append(dict(model=g, uye=uye, lisans='CC BY 4.0 (CMIP6, Ekim 2022 itibarıyla tüm modelleme grupları)'))
    pd.DataFrame(lisans).to_csv(os.path.join(ANALIZ, 'H0_cmip6_modeller.csv'), index=False)
def cmip_sahte():
    """Yalnız yerel deneme: ağ erişimi yoksa basit yapay değişim (gerçek analizde KULLANILMAZ)"""
    for g in GCM:
        np.savez_compressed(os.path.join(KLS, f'{g}_historical.npz'), tas=np.full((30, 12, S), 285., np.float32), pr=np.full((30, 12, S), 3e-5, np.float32), hurs=np.full((30, 12, S), 70., np.float32))
        for e, dT in zip(SSP, [1.0, 2.0, 4.0]):
            r_ = np.linspace(0, 1, 86)[:, None, None]
            np.savez_compressed(os.path.join(KLS, f'{g}_{e}.npz'), tas=(285. + dT * r_ + np.zeros((86, 12, S))).astype(np.float32),
                                pr=(3e-5 * (1 + 0.05 * r_) + np.zeros((86, 12, S))).astype(np.float32), hurs=(70. - 3 * r_ + np.zeros((86, 12, S))).astype(np.float32))
try:
    cmip_indir()
except Exception as hata:
    if AYAR['hizli_deneme']: print('CMIP6 indirilemedi (yerel deneme) → yapay değişim:', type(hata).__name__); cmip_sahte()
    else: raise
MEVCUT = [g for g in GCM if all(os.path.exists(os.path.join(KLS, f'{g}_{e}.npz')) for e in ['historical'] + SSP)]
print('Kullanılabilir iklim modelleri:', MEVCUT)