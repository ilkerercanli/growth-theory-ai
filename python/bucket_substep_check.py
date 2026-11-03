"""Post hoc check of the monthly VS-Lite bucket model (Section 3.3).

Compares soil moisture computed with the monthly step used in the models with
soil moisture computed with 30 sub-steps per month, for 800 randomly chosen
sites (random_state=1), and counts site-months in which a 20% increase in
precipitation lowers computed soil moisture.
Input: IKLIM/iklim_aylik.csv.gz and IKLIM/alan_iklim_ozet.csv (CRU TS 4.09 at the sites).
Result (run 3 Nov 2026): violations 0.693% (monthly) vs 0.0000% (30 sub-steps);
r = 0.9975, MAE = 0.0071 v/v, mean M = 0.378.
"""
import sys, numpy as np, pandas as pd

def gun_uzunlugu(lat):
    gun = np.array([15, 46, 74, 105, 135, 166, 196, 227, 258, 288, 319, 349])
    dek = 23.45 * np.sin(np.deg2rad(360 * (284 + gun) / 365))
    x = -np.tan(np.deg2rad(lat))[:, None] * np.tan(np.deg2rad(dek))[None, :]
    return 24 / np.pi * np.arccos(np.clip(x, -1, 1))

def kova(T, P, lat, I, nsub=1, Mmax=0.76, Mmin=0.01, alph=0.093, m_th=4.886, mu_th=5.80, rootd=1000., M0=0.2):
    S_, N = T.shape; gu = gun_uzunlugu(lat)
    ng = np.array([31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]); L = (ng / 30)[None, :] * (gu / 12)
    a = 6.75e-7 * I**3 - 7.71e-5 * I**2 + 1.792e-2 * I + 0.49
    M = np.empty((S_, N)); m = np.full(S_, M0)
    for t in range(N):
        Tt, Pt, Lt = T[:, t], P[:, t], L[:, t % 12]
        Ep = np.where(Tt <= 0, 0., np.where(Tt < 26.5, 16 * Lt * (10 * np.maximum(Tt, 0) / np.maximum(I, 1e-6)) ** a,
                                            -415.85 + 32.25 * Tt - 0.43 * Tt**2))
        Ep = np.maximum(Ep, 0)
        for _ in range(nsub):
            p, ep = Pt / nsub, Ep / nsub
            E = ep * (m / Mmax); G = mu_th * alph / (1 + mu_th) * m * rootd / nsub
            R = p * (m / Mmax) ** m_th + (alph / (1 + mu_th)) * m * rootd / nsub
            m = np.clip(m + (p - E - R - G) / rootd, Mmin, Mmax)
        M[:, t] = m
    return M

if __name__ == '__main__':
    klasor = sys.argv[1] if len(sys.argv) > 1 else 'IKLIM'
    d = pd.read_csv(f'{klasor}/iklim_aylik.csv.gz', usecols=['studyCode', 'year', 'month', 'tmp', 'pre'])
    a = pd.read_csv(f'{klasor}/alan_iklim_ozet.csv', usecols=['studyCode', 'lat'])
    kod = a.studyCode.sample(800, random_state=1).values
    d = d[d.studyCode.isin(kod)].sort_values(['studyCode', 'year', 'month'])
    pT = d.pivot_table(index='studyCode', columns=['year', 'month'], values='tmp')
    pP = d.pivot_table(index='studyCode', columns=['year', 'month'], values='pre')
    ok = pT.notna().all(1) & pP.notna().all(1); T = pT[ok].values; P = pP[ok].values
    lat = a.set_index('studyCode').loc[pT[ok].index, 'lat'].values
    S = T.shape[0]; Tc = np.nanmean(T.reshape(S, -1, 12), 1)
    I = np.sum(np.where(Tc > 0, (np.maximum(Tc, 0) / 5) ** 1.514, 0), 1)
    M1, M1p = kova(T, P, lat, I), kova(T, P * 1.2, lat, I)
    M30, M30p = kova(T, P, lat, I, 30), kova(T, P * 1.2, lat, I, 30)
    print('sites', S)
    print('violations, monthly step: %.3f%%' % ((M1p < M1 - 1e-6).mean() * 100))
    print('violations, 30 sub-steps: %.4f%%' % ((M30p < M30 - 1e-6).mean() * 100))
    print('r = %.4f, MAE = %.4f v/v, mean M = %.3f' % (np.corrcoef(M1.ravel(), M30.ravel())[0, 1], np.abs(M1 - M30).mean(), M1.mean()))
