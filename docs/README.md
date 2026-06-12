# TokenFlow — Landing page

Page d'atterrissage bilingue (EN/FR) pour TokenFlow, prête à déployer sur n'importe quel hébergement statique.

## Contenu du dossier

```
index.html        → la page
landing.css       → styles de la page
landing.js        → bascule EN/FR + bouton « télécharger la dernière release »
styles.css        → entrée des tokens du design system
tokens/           → couleurs, typo, espacements, effets, polices
assets/           → icônes + captures de l'app (PNG transparents)
.nojekyll         → désactive le traitement Jekyll sur GitHub Pages
```

## Déployer

Tout est **statique** — aucun build requis. Choisis une option :

### GitHub Pages
1. Copie le contenu de ce dossier dans `docs/` (ou la racine) de ton dépôt.
2. Pousse sur la branche `main`.
3. `Settings → Pages → Source : main / docs` (ou `main / root`).
4. Le `.nojekyll` est déjà là — les dossiers commençant par `_` ne sont pas requis ici, mais il évite tout souci.

### Glisser-déposer (Netlify / Vercel / Cloudflare Pages)
Dépose simplement ce dossier dans l'interface — il est servi tel quel.

### Local
Ouvre `index.html` dans un navigateur, ou sers le dossier :
```
python3 -m http.server 8000
```

## Notes

- Les captures sont des PNG à fond transparent — elles posent directement sur le fond sombre.
- Le bouton « Télécharger » récupère la dernière release GitHub de `pulssart/TokenFlow` et retombe sur v1.0 si l'API est indisponible.
