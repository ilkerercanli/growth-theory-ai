import numpy as np, pandas as pd, matplotlib, shutil, os
matplotlib.use('Agg'); import matplotlib.pyplot as plt
from global_land_mask import globe
A = '/mnt/user-data/uploads/ITRDB_AI/ANALIZ_SON/'; O = '/mnt/user-data/outputs/fig6/'; O3 = '/mnt/user-data/outputs/fig3/'
os.makedirs(O, exist_ok=True)
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 8, 'axes.spines.top': False, 'axes.spines.right': False,
                     'axes.linewidth': 0.6, 'xtick.major.width': 0.6, 'ytick.major.width': 0.6, 'legend.frameon': False})
INK, MUTED, GRID = '#1f1f1f', '#6b6b6b', '#e6e6e6'
CU, CT, CX, CL = '#C2571A', '#1B7A55', '#B8860B', '#6B6B6B'
def panel(ax, s, x=-0.14): ax.text(x, 1.04, s, transform=ax.transAxes, fontsize=10, fontweight='bold', va='bottom')

# ---------------- Fig 3: scenario responses with 95% site-bootstrap intervals
d = pd.read_csv(A + 'I2_senaryo_guven_araliklari.csv')
M3 = [('Karma model', 'LMM', CL), ('XGBoost', 'XGB', CX), ('U', 'U', CU), ('U+S', 'U+S', CU), ('T', 'T', CT), ('T_D', 'T$_D$', CT),
      ('T+S', 'T+S', CT), ('T_D+S', 'T$_D$+S', CT), ('T+S uyumlu', 'T+S acclim.', CT)]
P3 = [('yağış +%20 → azalan', 'Precipitation +20%:\nrings with lower growth (%)', 'a'),
      ('ısınma → azalan (en soğuk çeyrek)', '+1 °C, coldest quartile:\nrings with lower growth (%)', 'b'),
      ('ısınma → azalan (en kurak çeyrek)', '+1 °C, driest quartile:\nrings with lower growth (%)', 'c')]
fig, axs = plt.subplots(1, 3, figsize=(7.2, 2.9))
for ax, (o, yl, pl) in zip(axs, P3):
    for i, (m, lb, c) in enumerate(M3):
        r = d[(d.model == m) & (d.olcut == o)].iloc[0]
        hatch = '' if ('+S' in lb or lb in ('LMM', 'XGB')) else '////'
        ax.bar(i, r.yuzde, color=c, alpha=0.85 if hatch == '' else 0.45, width=0.72, edgecolor='white', lw=0.4)
        ax.errorbar(i, r.yuzde, yerr=[[r.yuzde - r.alt95], [r.ust95 - r.yuzde]], color=INK, lw=0.8, capsize=1.6)
        if r.yuzde < 4: ax.text(i, r.ust95 + 1.5, f'{r.yuzde:.1f}', ha='center', fontsize=5.8, color=INK)
    ax.set_xticks(range(len(M3))); ax.set_xticklabels([x[1] for x in M3], rotation=60, ha='right', fontsize=6.6)
    ax.set_ylabel(yl, fontsize=7.2); ax.set_ylim(0, 105); ax.grid(axis='y', color=GRID, lw=0.5); ax.set_axisbelow(True); panel(ax, pl, -0.2)
fig.tight_layout(); fig.savefig(O + 'Fig3.png', dpi=300); plt.close(fig)

# ---------------- Fig 4: independent benchmark — like-for-like sensitivities at withheld sites
b = pd.read_csv(A + 'I1_bagimsiz_duyarlilik.csv')
M4 = [('Karma model', 'LMM', CL, 'v'), ('XGBoost', 'XGB', CX, 'D'), ('U+S', 'U+S', CU, 'o'), ('T+S', 'T+S', CT, 's')]
K4 = [('tüm alanlar', 'All sites'), ('en soğuk çeyrek', 'Coldest quartile'), ('en kurak çeyrek', 'Driest quartile')]
P4 = [('sıcaklık', 'yon_uyumu', 'Temperature:\nsign agreement', 'a', (0.25, 1.02)),
      ('sıcaklık', 'spearman', 'Temperature:\nSpearman ρ', 'b', (0.0, 0.6)),
      ('yağış', 'spearman', 'Precipitation:\nSpearman ρ', 'c', (-0.1, 0.65)),
      ('sıcaklık', 'kalibrasyon_egimi', 'Temperature:\ncalibration slope', 'd', (0.0, 2.9))]
fig, axs = plt.subplots(1, 4, figsize=(7.2, 3.0), sharey=False)
for ax, (dg, ol, ttl, pl, yl) in zip(axs, P4):
    for k, (ku, kl) in enumerate(K4):
        for j, (m, lb, c, mk) in enumerate(M4):
            r = b[(b.kume == ku) & (b.degisken == dg) & (b.olcut == ol) & (b.model == m)].iloc[0]; x = k + (j - 1.5) * 0.18
            ax.vlines(x, r.alt95, r.ust95, color=c, lw=1.1)
            ax.scatter(x, r.deger, color=c, marker=mk, s=18, zorder=3, edgecolor='white', lw=0.4, label=lb if k == 0 else None)
        if ol == 'yon_uyumu':
            p = r.gozlenen_pozitif_orani; br = max(p, 1 - p)
            ax.hlines(br, k - 0.4, k + 0.4, color=MUTED, lw=0.7, ls=':')
    if ol == 'kalibrasyon_egimi': ax.axhline(1, color=MUTED, lw=0.7, ls='--')
    if ol == 'spearman': ax.axhline(0, color=MUTED, lw=0.5)
    ax.set_xticks(range(3)); ax.set_xticklabels(['All', 'Coldest\nquartile', 'Driest\nquartile'], fontsize=6.6)
    ax.set_ylim(*yl); ax.set_title(ttl, fontsize=7, loc='left'); ax.grid(axis='y', color=GRID, lw=0.5); ax.set_axisbelow(True); panel(ax, pl, -0.16)
axs[0].legend(fontsize=6.5, loc='lower left', handletextpad=0.2, borderaxespad=0.1)
fig.tight_layout(); fig.savefig(O + 'Fig4.png', dpi=300); plt.close(fig)

# ---------------- Fig 5: projections with climate-model × ensemble-member uncertainty
h2 = pd.read_csv(A + 'H2_sabit_boyut_gcm_ortalama.csv'); h2 = h2[h2.donem == '2071–2100']
i4 = pd.read_csv(A + 'I4_projeksiyon_belirsizlik.csv'); i4 = i4[i4.donem == 2071]
MOD = [('Karma model', 'Linear mixed model', CL, 'v'), ('XGBoost', 'XGBoost', CX, 'D'), ('U+S', 'U+S', CU, 'o'), ('T_D+S', 'T$_D$+S (with VPD)', '#5BA37E', '^'), ('T+S', 'T+S', CT, 's')]
j1 = pd.read_csv(A + 'J1_projeksiyon_vpd_kuvvet.csv'); j1 = j1[j1.donem == 2071]
SS = [('ssp126', 'SSP1-2.6'), ('ssp245', 'SSP2-4.5'), ('ssp585', 'SSP5-8.5')]
fig = plt.figure(figsize=(7.2, 6.5))
ax = fig.add_axes([0.12, 0.62, 0.37, 0.33])
for j, (m, lb, c, mk) in enumerate(MOD):
    for i, (s, sl) in enumerate(SS):
        src = j1 if m == 'T_D+S' else h2
        r = src[(src.ssp == s) & (src.normaller == 'sabit') & (src.model == m)].iloc[0]; x = i + (j - 2) * 0.15
        q = (j1 if m == 'T_D+S' else i4); q = q[(q.ssp == s) & (q.normaller == 'sabit') & (q.model == m)]
        lo, hi = (q.alt5.iloc[0], q.ust95.iloc[0]) if len(q) else (r.gcm_arasi_min, r.gcm_arasi_max)
        ax.vlines(x, lo, hi, color=c, lw=1.4)
        ax.scatter(x, r.medyan_degisim_yuzde, color=c, marker=mk, s=26, zorder=3, edgecolor='white', lw=0.5, label=lb if i == 0 else None)
ax.axhline(0, color=MUTED, lw=0.6); ax.set_xticks(range(3)); ax.set_xticklabels([s[1] for s in SS])
ax.set_ylabel('Median change in growth,\n2071–2100 vs 1985–2014 (%)'); ax.grid(axis='y', color=GRID, lw=0.5)
ax.legend(fontsize=6.5, loc='lower left'); ax.text(-0.2, 1.04, 'a', transform=ax.transAxes, fontsize=10, fontweight='bold')
ax = fig.add_axes([0.60, 0.62, 0.27, 0.33])
for j, (m, lb, c, mk) in enumerate(MOD):
    src = j1 if m == 'T_D+S' else h2
    a = src[(src.ssp == 'ssp585') & (src.normaller == 'sabit') & (src.model == m)].iloc[0]; bb = src[(src.ssp == 'ssp585') & (src.normaller == 'guncel') & (src.model == m)].iloc[0]
    ax.plot([0, 1], [a.medyan_degisim_yuzde, bb.medyan_degisim_yuzde], color=c, marker=mk, lw=1.4, ms=5, mec='white', mew=0.5)
    ax.text(1.08, bb.medyan_degisim_yuzde + (-1.8 if m == 'T_D+S' else (0.6 if m == 'XGBoost' else 0)), lb.replace('Linear mixed model', 'LMM').replace(' (with VPD)', ''), va='center', fontsize=6.8, color=INK)
ax.axhline(0, color=MUTED, lw=0.6); ax.set_xticks([0, 1]); ax.set_xticklabels(['Site normals\nfixed', 'Site normals\nupdated']); ax.set_xlim(-0.3, 1.35)
ax.set_ylabel('Median change, SSP5-8.5, 2071–2100 (%)'); ax.grid(axis='y', color=GRID, lw=0.5); ax.text(-0.42, 1.04, 'b', transform=ax.transAxes, fontsize=10, fontweight='bold')
hm = pd.read_csv(A + 'H4_harita_ssp585_2071.csv')
lon = np.linspace(-180, 180, 1080); lat = np.linspace(-60, 85, 435); LO, LA = np.meshgrid(lon, lat); land = np.where(globe.is_land(LA, LO), 1, np.nan)
cm = matplotlib.colormaps['BrBG']
for k, (col, ttl, pl) in enumerate([('teori_ortam', 'Theory-constrained network (T+S)', 'c'), ('serbest_ortam', 'Unconstrained network (U+S)', 'd')]):
    ax = fig.add_axes([0.02 + 0.49 * k, 0.11, 0.47, 0.40])
    ax.imshow(land, extent=[-180, 180, -60, 85], origin='lower', cmap=matplotlib.colors.ListedColormap(['#ececea']), aspect='auto')
    v = 100 * (np.exp(hm[col]) - 1)
    sc = ax.scatter(hm.lon, hm.lat, c=np.clip(v, -40, 40), cmap=cm, vmin=-40, vmax=40, s=3, lw=0)
    ax.set_xlim(-170, 180); ax.set_ylim(-56, 75); ax.set_xticks([]); ax.set_yticks([])
    for s_ in ax.spines.values(): s_.set_visible(False)
    ax.set_title(ttl, fontsize=7.5, loc='left'); ax.text(0.0, 1.08, pl, transform=ax.transAxes, fontsize=10, fontweight='bold')
    ax.text(0.99, 0.02, f'growth falls at {100 * (v < 0).mean():.0f}% of sites', transform=ax.transAxes, ha='right', fontsize=6.5, color=MUTED)
cax = fig.add_axes([0.3, 0.075, 0.4, 0.014]); cb = fig.colorbar(sc, cax=cax, orientation='horizontal'); cb.set_label('Change in growth at fixed size, SSP5-8.5, 2071–2100, mean of 5 GCMs (%)', fontsize=7); cb.ax.tick_params(labelsize=6.5)
fig.savefig(O + 'Fig5.png', dpi=300); plt.close(fig)

# ---------------- reuse unchanged figures under new numbers
for src, dst in [('Fig1.png', 'Fig1.png'), ('Fig2.png', 'Fig2.png'), ('Fig6.png', 'ED_Fig4.png'), ('Fig5.png', 'ED_Fig1.png'), ('Fig7.png', 'ED_Fig2.png')]:
    shutil.copy(O3 + src, O + dst)
shutil.copy('/mnt/user-data/outputs/fig2/FigS1.png', O + 'ED_Fig3.png')
print('ok', sorted(os.listdir(O)))
