// =============================================================================
// tests/user-smoke/smw-user-smoke.spec.js
// Smoke tests utilisateur — SMW Marketplace (Playwright / Firefox)
//
// Couvre les fonctionnalités SMW du point de vue utilisateur :
//   Groupe 1 : Pages spéciales SMW (accès anonyme — T-USER-00 à T-USER-04)
//   Groupe 2 : Flux utilisateur authentifié (annotations, requêtes, API
//              — T-USER-05 à T-USER-09)
//
// Références :
//   https://www.semantic-mediawiki.org/wiki/Help:User_manual
//   https://www.semantic-mediawiki.org/wiki/Help:Getting_started
//   ADR-613 — Architecture provisioners / validation
//   ADR-700 — Plan de tests d'intégration
// =============================================================================
const { test, expect } = require('@playwright/test');

// ---------------------------------------------------------------------------
// Constantes — credentials et données de test
// Chargées depuis tests/user-smoke/env (voir env.example)
// ---------------------------------------------------------------------------
const ADMIN_USER  = process.env.SMW_ADMIN_USER;
const ADMIN_PASS  = process.env.SMW_ADMIN_PASSWORD;
const TEST_PAGE   = 'SMW_Smoke_Test';
const TEST_PROP   = 'Has population';
const TEST_VALUE  = '42000';

// =============================================================================
// Groupe 1 — Pages spéciales SMW (accès anonyme)
// Ces tests vérifient que les fonctionnalités SMW sont accessibles sans login.
// Ils doivent passer sur un wiki fraîchement déployé, sans données pré-existantes.
// =============================================================================
test.describe('SMW User Smoke — Pages spéciales (anonyme)', () => {

  // ---------------------------------------------------------------------------
  // T-USER-00 : Special:Ask — formulaire de recherche sémantique
  // Vérifie que le moteur de requêtes SMW est actif et que l'interface rend
  // correctement. Un wiki fraîchement installé sans données retourne 0 résultats
  // mais le formulaire doit être présent et fonctionnel.
  // ---------------------------------------------------------------------------
  test('T-USER-00: Special:Ask — formulaire de recherche sémantique accessible', async ({ page }) => {
    await page.goto('/wiki/Special:Ask');

    await expect(page.locator('#mw-content-text')).toBeVisible();

    // Pas d'erreur PHP fatale ou parse error
    await expect(page.locator('body')).not.toContainText('Fatal error');
    await expect(page.locator('body')).not.toContainText('Parse error');

    // Le formulaire de requête doit être présent (textarea ou input[name="q"])
    const queryInput = page.locator('textarea, input[name="q"]').first();
    await expect(queryInput).toBeVisible();
  });

  // ---------------------------------------------------------------------------
  // T-USER-01 : Special:Browse — navigation sémantique d'une page existante
  // Vérifie que le navigateur de données sémantiques SMW est opérationnel.
  // Main_Page est toujours présente sur un wiki fraîchement installé.
  // ---------------------------------------------------------------------------
  test('T-USER-01: Special:Browse — données sémantiques de Main_Page accessibles', async ({ page }) => {
    await page.goto('/wiki/Special:Browse/:Main_Page');

    await expect(page.locator('#mw-content-text')).toBeVisible();

    // Pas d'erreur PHP
    await expect(page.locator('body')).not.toContainText('Fatal error');
    await expect(page.locator('body')).not.toContainText('Parse error');

    // La page Browse doit référencer le sujet consulté
    await expect(page.locator('body')).toContainText('Main');
  });

  // ---------------------------------------------------------------------------
  // T-USER-02 : Special:Types — types de données SMW (built-in)
  // Les types de données SMW (Text, Number, Date, URL, Page…) sont enregistrés
  // automatiquement à l'installation. Cette page doit lister au moins "Text".
  // ---------------------------------------------------------------------------
  test('T-USER-02: Special:Types — types de données SMW présents', async ({ page }) => {
    await page.goto('/wiki/Special:Types');

    await expect(page.locator('#mw-content-text')).toBeVisible();

    // Pas d'erreur PHP
    await expect(page.locator('body')).not.toContainText('Fatal error');
    await expect(page.locator('body')).not.toContainText('Parse error');

    // Le type Text est toujours déclaré par SMW nativement
    await expect(page.locator('body')).toContainText('Text');
  });

  // ---------------------------------------------------------------------------
  // T-USER-03 : Special:Properties — liste des propriétés du wiki
  // Cette page est vide sur un wiki fraîchement installé mais doit être
  // accessible sans erreur. La présence de #mw-content-text suffit.
  // ---------------------------------------------------------------------------
  test('T-USER-03: Special:Properties — page accessible sans erreur', async ({ page }) => {
    await page.goto('/wiki/Special:Properties');

    await expect(page.locator('#mw-content-text')).toBeVisible();

    // Pas d'erreur PHP
    await expect(page.locator('body')).not.toContainText('Fatal error');
    await expect(page.locator('body')).not.toContainText('Parse error');
  });

  // ---------------------------------------------------------------------------
  // T-USER-04 : Special:Concepts — page des concepts SMW accessible
  // Les concepts SMW sont des requêtes mémorisées réutilisables. La page doit
  // s'afficher sans erreur même si aucun concept n'est défini.
  // ---------------------------------------------------------------------------
  test('T-USER-04: Special:Concepts — page accessible sans erreur', async ({ page }) => {
    await page.goto('/wiki/Special:Concepts');

    await expect(page.locator('#mw-content-text')).toBeVisible();

    // Pas d'erreur PHP
    await expect(page.locator('body')).not.toContainText('Fatal error');
    await expect(page.locator('body')).not.toContainText('Parse error');
  });

});

// =============================================================================
// Groupe 2 — Flux utilisateur authentifié (serial — partage l'état de session)
//
// Ces tests s'exécutent séquentiellement via test.describe.serial().
// Une page partagée (authPage) maintient la session WikiAdmin entre les tests.
// T-USER-06 crée la page de test ; T-USER-07, T-USER-08 et T-USER-09 en dépendent.
// =============================================================================
test.describe.serial('SMW User Smoke — Flux authentifié (WikiAdmin)', () => {

  /** Page partagée entre les tests du groupe — session WikiAdmin persistée */
  let authPage;

  // -------------------------------------------------------------------------
  // Initialisation : créer un contexte navigateur et se connecter en WikiAdmin
  // Le contexte est créé une seule fois pour tout le groupe (beforeAll)
  // -------------------------------------------------------------------------
  test.beforeAll(async ({ browser }) => {
    const context = await browser.newContext({ ignoreHTTPSErrors: true });
    authPage = await context.newPage();

    // Navigation vers la page de login
    await authPage.goto('/wiki/Special:UserLogin');
    await authPage.locator('#wpName1').fill(ADMIN_USER);
    await authPage.locator('#wpPassword1').fill(ADMIN_PASS);
    await authPage.locator('#wpLoginAttempt').click();

    // Attendre la redirection post-login (quitter Special:UserLogin)
    await authPage.waitForURL(url => !url.toString().includes('Special:UserLogin'), { timeout: 30000 });
  });

  // -------------------------------------------------------------------------
  // Fermeture : libérer le contexte après tous les tests du groupe
  // -------------------------------------------------------------------------
  test.afterAll(async () => {
    await authPage.context().close();
  });

  // -------------------------------------------------------------------------
  // T-USER-05 : Connexion WikiAdmin réussie
  // Vérifie que les credentials par défaut du firstboot permettent de se
  // connecter (ADR-613 §Credentials — défaut : WikiAdmin / ChangeMe123!)
  // -------------------------------------------------------------------------
  test('T-USER-05: Connexion WikiAdmin — session active après login', async () => {
    // Vérifier que la session est bien établie en naviguant vers le profil
    await authPage.goto('/wiki/Special:Preferences');

    // Sur Special:Preferences, le nom de l'utilisateur connecté apparaît
    await expect(authPage.locator('#mw-content-text')).toBeVisible();
    await expect(authPage.locator('body')).not.toContainText('Vous devez vous connecter');
    await expect(authPage.locator('body')).not.toContainText('You must be logged in');

    // Le nom d'utilisateur doit apparaître dans la page de préférences
    await expect(authPage.locator('body')).toContainText(ADMIN_USER);
  });

  // -------------------------------------------------------------------------
  // T-USER-06 : Création d'une page wiki avec annotation sémantique
  // Crée la page SMW_Smoke_Test contenant [[Has population::42000]]
  // Ce test constitue le setup pour T-USER-07, T-USER-08 et T-USER-09.
  // -------------------------------------------------------------------------
  test(`T-USER-06: Créer page wiki avec annotation [[${TEST_PROP}::${TEST_VALUE}]]`, async () => {
    // Naviguer vers l'éditeur de la page de test (création ou re-création)
    await authPage.goto(`/w/index.php?title=${TEST_PAGE}&action=edit`);

    // L'éditeur wikitext doit être présent
    const textarea = authPage.locator('#wpTextbox1');
    await expect(textarea).toBeVisible();

    // Rédiger le contenu avec annotation sémantique
    await textarea.fill(
      `== SMW Smoke Test ==\n` +
      `Page de test automatique — générée par les smoke tests utilisateur SMW.\n\n` +
      `[[${TEST_PROP}::${TEST_VALUE}]]\n\n` +
      `[[Category:SMW_Smoke_Tests]]`
    );

    // Renseigner le résumé de modification
    const summary = authPage.locator('#wpSummary');
    if (await summary.isVisible()) {
      await summary.fill('Smoke test automatique — création annotation sémantique');
    }

    // Sauvegarder la page
    await authPage.locator('#wpSave').click();

    // La page doit être sauvegardée (plus en mode édition, contenu visible)
    await expect(authPage).not.toHaveURL(/action=edit/);
    await expect(authPage.locator('#mw-content-text')).toBeVisible();

    // L'annotation brute peut être masquée, mais la page doit exister
    await expect(authPage.locator('body')).not.toContainText('Fatal error');
  });

  // -------------------------------------------------------------------------
  // T-USER-07 : Special:Ask retrouve la page annotée via requête sémantique
  // Requête : [[Has population::+]] — retourne toute page ayant cette propriété.
  // Après T-USER-06, SMW_Smoke_Test doit apparaître dans les résultats.
  // -------------------------------------------------------------------------
  test('T-USER-07: Special:Ask — requête sémantique retrouve la page annotée', async () => {
    // Requête : toutes les pages ayant une valeur pour [[Has population::+]]
    const query = encodeURIComponent(`[[${TEST_PROP}::+]]`);
    const printout = encodeURIComponent(`?${TEST_PROP}`);
    await authPage.goto(`/wiki/Special:Ask?q=${query}&po=${printout}&eq=yes`);

    await expect(authPage.locator('#mw-content-text')).toBeVisible();
    await expect(authPage.locator('body')).not.toContainText('Fatal error');
    await expect(authPage.locator('body')).not.toContainText('Parse error');

    // La page de test doit figurer dans les résultats (titre sans underscore)
    await expect(authPage.locator('body')).toContainText(TEST_PAGE.replace(/_/g, ' '));
  });

  // -------------------------------------------------------------------------
  // T-USER-08 : Special:Browse affiche l'annotation sur la page créée
  // Special:Browse expose les données sémantiques d'un sujet.
  // La propriété [[Has population]] et sa valeur 42000 doivent être visibles.
  // -------------------------------------------------------------------------
  test('T-USER-08: Special:Browse — annotation sémantique visible sur la page de test', async () => {
    await authPage.goto(`/wiki/Special:Browse/:${TEST_PAGE}`);

    await expect(authPage.locator('#mw-content-text')).toBeVisible();
    await expect(authPage.locator('body')).not.toContainText('Fatal error');
    await expect(authPage.locator('body')).not.toContainText('Parse error');

    // La valeur annotée doit apparaître dans le panneau Browse de SMW
    await expect(authPage.locator('body')).toContainText(TEST_VALUE);
  });

  // -------------------------------------------------------------------------
  // T-USER-09 : API SMW — action=smwinfo retourne des données valides
  // Vérifie que l'API MediaWiki/SMW répond avec des données structurées JSON.
  // La clé "smwinfo" doit être présente dans la réponse.
  // -------------------------------------------------------------------------
  test('T-USER-09: API SMW — action=smwinfo retourne un JSON valide', async () => {
    await authPage.goto('/api.php?action=smwinfo&info=propcount|usedpropcount|declaredpropcount&format=json');

    await expect(authPage.locator('body')).not.toContainText('Fatal error');

    // La réponse JSON doit contenir la clé "info" (SMW 4.x retourne "info" et non "smwinfo")
    const body = await authPage.locator('body').textContent();
    const json = JSON.parse(body);
    expect(json).toHaveProperty('info');
    expect(json.info).toHaveProperty('propcount');
  });

});
