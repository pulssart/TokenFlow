/* TokenFlow landing — i18n, language switch, live DMG download, icons. */
(function () {
  'use strict';

  var REPO = 'pulssart/TokenFlow';
  var FALLBACK_DMG = 'https://github.com/' + REPO + '/releases/download/v1.0/TokenFlow-1.0.dmg';
  var RELEASES = 'https://github.com/' + REPO + '/releases/latest';

  /* ---------- Copy ---------- */
  var I18N = {
    en: {
      'nav.features': 'Features', 'nav.widgets': 'Widgets', 'nav.setup': 'Setup', 'nav.download': 'Download',
      'hero.eyebrow': 'macOS · Codex token tracker',
      'hero.title': 'See the session limit coming,<br/>keep <em>control</em>.',
      'hero.sub': 'TokenFlow reads your local Codex history and shows session, weekly and per-category token usage at a glance — a native macOS app with widgets and a menu-bar status item.',
      'hero.download': 'Download for macOS', 'hero.github': 'View on GitHub',
      'hero.meta': 'Free · Signed & notarized DMG · Apple Silicon & Intel',
      'sig.types': 'token types tracked', 'sig.local': 'local — reads your own history',
      'sig.account': 'accounts, no sign-up', 'sig.native': 'native · widgets · menu bar',
      'feat.eyebrow': 'What it shows', 'feat.title': 'A full read on your Codex usage.',
      'feat.session.t': 'Live session breakdown',
      'feat.session.d': 'Input, cache, output and reasoning tokens for the current session — with the share of total and a live counter that updates as you work.',
      'feat.week.t': 'Weekly quota', 'feat.week.d': 'Track the weekly limit Codex exposes, with daily bars and reset times.',
      'feat.summary.t': 'Session at a glance', 'feat.summary.d': 'Total tokens tracked plus primary and fallback session limits as rings.',
      'feat.summary.note': 'A non-zero value always keeps a visible sliver — so a glance is never empty.',
      'feat.summary.r1': 'Primary', 'feat.summary.r2': 'Fallback 5.3',
      'feat.notify.t': 'Menu bar & notifications', 'feat.notify.d': 'An optional status item keeps usage one glance away, with notifications when you approach a limit.',
      'feat.recent.t': 'Recent sessions', 'feat.recent.d': 'The latest work threads from your Codex history, with the tokens each one consumed.',
      'wid.eyebrow': 'On your desktop', 'wid.title': 'Native widgets, always in view.',
      'wid.lede': 'Drop a TokenFlow widget into Notification Center to keep session and weekly usage glanceable — without opening the app.',
      'wid.session': 'Session · usage ring', 'wid.week': 'Week · daily bars',
      'set.eyebrow': 'Three steps', 'set.title': 'Up and running in a minute.',
      'set.s1.t': 'Download & open', 'set.s1.d': 'Grab the signed, notarized DMG and drag TokenFlow into Applications.',
      'set.s2.t': 'Sign in to Codex', 'set.s2.d': 'TokenFlow reads local Codex data, so Codex needs to be signed in on the machine.',
      'set.s3.t': 'Watch the tokens', 'set.s3.d': 'Open the app — session, week and recent activity populate automatically.',
      'cta.title': 'Start tracking your Codex tokens.', 'cta.sub': 'Free, native, and private. Your history never leaves your Mac.',
      'foot.tag': 'Codex token tracker for macOS', 'foot.releases': 'Releases', 'foot.docs': 'Docs',
      'foot.note': 'Not affiliated with OpenAI. Reads local Codex history only.'
    },
    fr: {
      'nav.features': 'Fonctionnalités', 'nav.widgets': 'Widgets', 'nav.setup': 'Installation', 'nav.download': 'Télécharger',
      'hero.eyebrow': 'macOS · Suivi des tokens Codex',
      'hero.title': 'Vois la fin de session arriver,<br/>garde le <em>contrôle</em>.',
      'hero.sub': 'TokenFlow lit votre historique Codex local et affiche l’usage par session, par semaine et par catégorie en un coup d’œil — une application macOS native avec widgets et barre de menus.',
      'hero.download': 'Télécharger pour macOS', 'hero.github': 'Voir sur GitHub',
      'hero.meta': 'Gratuit · DMG signé et notarisé · Apple Silicon & Intel',
      'sig.types': 'types de tokens suivis', 'sig.local': 'local — lit votre propre historique',
      'sig.account': 'compte, aucune inscription', 'sig.native': 'natif · widgets · barre de menus',
      'feat.eyebrow': 'Ce qu’il affiche', 'feat.title': 'Une lecture complète de votre usage Codex.',
      'feat.session.t': 'Détail de la session en direct',
      'feat.session.d': 'Tokens d’entrée, de cache, de sortie et de raisonnement de la session courante — avec leur part du total et un compteur en direct.',
      'feat.week.t': 'Quota hebdomadaire', 'feat.week.d': 'Suivez la limite hebdomadaire exposée par Codex, avec barres journalières et heures de réinitialisation.',
      'feat.summary.t': 'Session en un coup d’œil', 'feat.summary.d': 'Total des tokens suivis, plus les limites de session principale et de repli en anneaux.',
      'feat.summary.note': 'Une valeur non nulle garde toujours un filet visible — un coup d’œil n’est jamais vide.',
      'feat.summary.r1': 'Principale', 'feat.summary.r2': 'Repli 5.3',
      'feat.notify.t': 'Barre de menus et notifications', 'feat.notify.d': 'Un élément de statut optionnel garde l’usage à portée de regard, avec des notifications à l’approche d’une limite.',
      'feat.recent.t': 'Sessions récentes', 'feat.recent.d': 'Les derniers fils de travail de votre historique Codex, avec les tokens consommés par chacun.',
      'wid.eyebrow': 'Sur votre bureau', 'wid.title': 'Des widgets natifs, toujours visibles.',
      'wid.lede': 'Placez un widget TokenFlow dans le Centre de notifications pour garder l’usage de la session et de la semaine à portée de regard — sans ouvrir l’app.',
      'wid.session': 'Session · anneau d’usage', 'wid.week': 'Semaine · barres journalières',
      'set.eyebrow': 'Trois étapes', 'set.title': 'Opérationnel en une minute.',
      'set.s1.t': 'Télécharger et ouvrir', 'set.s1.d': 'Récupérez le DMG signé et notarisé, puis glissez TokenFlow dans Applications.',
      'set.s2.t': 'Connectez-vous à Codex', 'set.s2.d': 'TokenFlow lit les données Codex locales : Codex doit être connecté sur la machine.',
      'set.s3.t': 'Suivez les tokens', 'set.s3.d': 'Ouvrez l’app — session, semaine et activité récente se remplissent automatiquement.',
      'cta.title': 'Suivez vos tokens Codex dès maintenant.', 'cta.sub': 'Gratuit, natif et privé. Votre historique ne quitte jamais votre Mac.',
      'foot.tag': 'Suivi des tokens Codex pour macOS', 'foot.releases': 'Versions', 'foot.docs': 'Docs',
      'foot.note': 'Sans affiliation avec OpenAI. Lit uniquement l’historique Codex local.'
    }
  };

  /* ---------- Feature icons ---------- */
  var ICONS = {
    bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></svg>',
    list: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8 6h13M8 12h13M8 18h13"/><circle cx="3.5" cy="6" r="1.2"/><circle cx="3.5" cy="12" r="1.2"/><circle cx="3.5" cy="18" r="1.2"/></svg>'
  };

  function injectIcons() {
    document.querySelectorAll('[data-icon]').forEach(function (el) {
      var k = el.getAttribute('data-icon');
      if (ICONS[k]) el.innerHTML = ICONS[k];
    });
  }

  /* ---------- Language ---------- */
  function applyLang(lang) {
    var dict = I18N[lang] || I18N.en;
    document.documentElement.lang = lang;
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      var v = dict[el.getAttribute('data-i18n')];
      if (v != null) el.textContent = v;
    });
    document.querySelectorAll('[data-i18n-html]').forEach(function (el) {
      var v = dict[el.getAttribute('data-i18n-html')];
      if (v != null) el.innerHTML = v;
    });
    document.querySelectorAll('.lang__btn').forEach(function (b) {
      b.classList.toggle('is-active', b.getAttribute('data-lang') === lang);
    });
    try { localStorage.setItem('tf_lang', lang); } catch (e) {}
    // refresh download meta (it carries localized prefix)
    if (window.__tfDl) window.__tfDl(lang);
  }

  function initLang() {
    var saved;
    try { saved = localStorage.getItem('tf_lang'); } catch (e) {}
    var lang = saved || ((navigator.language || 'en').toLowerCase().indexOf('fr') === 0 ? 'fr' : 'en');
    applyLang(lang);
    document.querySelectorAll('.lang__btn').forEach(function (b) {
      b.addEventListener('click', function () { applyLang(b.getAttribute('data-lang')); });
    });
  }

  /* ---------- DMG download (latest release via GitHub API) ---------- */
  function setDownload(url, version, sizeMB) {
    ['heroDownload', 'ctaDownload', 'navDownload'].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.href = url;
    });
    window.__tfMeta = { version: version, sizeMB: sizeMB };
    if (window.__tfDl) window.__tfDl(document.documentElement.lang || 'en');
  }

  // Re-render the meta line in the current language with version/size if known.
  window.__tfDl = function (lang) {
    var m = window.__tfMeta;
    var base = (I18N[lang] || I18N.en)['hero.meta'];
    var els = [document.getElementById('dlMeta'), document.getElementById('ctaMeta')];
    var text = base;
    if (m && m.version) {
      var parts = base.split('·');
      // insert version after the first segment
      var ver = (lang === 'fr' ? 'Version ' : '') + m.version + (m.sizeMB ? ' · ' + m.sizeMB + ' MB' : '');
      text = parts[0].trim() + ' · ' + ver + ' · ' + parts.slice(1).join('·').trim();
    }
    els.forEach(function (el) { if (el) el.textContent = text; });
  };

  function fetchLatest() {
    fetch('https://api.github.com/repos/' + REPO + '/releases/latest', { headers: { Accept: 'application/vnd.github+json' } })
      .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
      .then(function (rel) {
        var dmg = (rel.assets || []).filter(function (a) { return /\.dmg$/i.test(a.name); })[0];
        var url = dmg ? dmg.browser_download_url : FALLBACK_DMG;
        var size = dmg && dmg.size ? Math.round(dmg.size / 1048576) : null;
        setDownload(url, (rel.tag_name || 'v1.0'), size);
      })
      .catch(function () { setDownload(FALLBACK_DMG, 'v1.0', null); });
  }

  /* ---------- Init ---------- */
  function init() {
    injectIcons();
    initLang();
    setDownload(FALLBACK_DMG, 'v1.0', null); // sensible default before API resolves
    fetchLatest();

    // smooth in-page anchors
    document.querySelectorAll('a[href^="#"]').forEach(function (a) {
      a.addEventListener('click', function (e) {
        var t = document.querySelector(a.getAttribute('href'));
        if (t) { e.preventDefault(); window.scrollTo({ top: t.getBoundingClientRect().top + window.pageYOffset - 72, behavior: 'smooth' }); }
      });
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
