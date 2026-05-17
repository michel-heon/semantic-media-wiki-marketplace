// =============================================================================
// tests/e2e/smw-mainpage.spec.js
// Tests navigateur E2E — SMW Marketplace (Playwright / Firefox)
// VM_IP : adresse IP de la VM cible (via playwright.config.js)
// =============================================================================
const { test, expect } = require('@playwright/test');

test.describe('SMW Marketplace — Navigateur Firefox', () => {

  // ---------------------------------------------------------------------------
  // T-BROWSER-00 : vérifie que la redirection "/" pointe vers l'adresse externe
  // Détecte la misconfiguration $wgServer = 'https://localhost' dans LocalSettings.php
  // VM_IP        : adresse de connexion à la VM (IP ou FQDN)
  // VM_RESOLVED_IP : IPv4 publique de la VM — fournie par le Makefile (ADR-602)
  //   La VM configure $wgServer avec l'IP IMDS (IPv4), pas le FQDN Azure.
  //   Le Makefile résout le FQDN → IP via getent hosts avant de lancer les tests.
  // ---------------------------------------------------------------------------
  test('T-BROWSER-00: redirect "/" → IP externe (pas localhost)', async ({ request }) => {
    const vmIP = process.env.VM_IP || '20.48.144.74';
    // IP attendue dans le Location header ($wgServer) — peut différer de VM_IP si FQDN
    const wgServerIP = process.env.VM_RESOLVED_IP || vmIP;

    // Récupère "/" sans suivre les redirections pour inspecter le Location header
    const response = await request.get(`https://${vmIP}/`, { maxRedirects: 0 });

    const status = response.status();
    expect(status, 'La racine "/" doit envoyer une redirection HTTP 3xx').toBeGreaterThanOrEqual(301);
    expect(status).toBeLessThanOrEqual(308);

    const location = response.headers()['location'] ?? '';
    expect(
      location,
      `ÉCHEC $wgServer: redirect "/" → "${location}" pointe vers localhost au lieu de https://${wgServerIP}/...`
    ).not.toMatch(/\/\/localhost/);

    expect(
      location,
      `ÉCHEC: redirect "/" → "${location}" ne contient pas l'IP publique de la VM (${wgServerIP})`
    ).toContain(wgServerIP);
  });

  // ---------------------------------------------------------------------------
  // T-BROWSER-01 : accès direct à Main_Page (contourne la redirection /)
  // ATTENTION : ce test ne détecte PAS la misconfiguration $wgServer
  // ---------------------------------------------------------------------------
  test('T-BROWSER-01: Page principale MediaWiki accessible', async ({ page }) => {
    // Navigation directe — ne suit PAS la redirection de "/" pour éviter localhost
    await page.goto('/wiki/Main_Page');

    await expect(page).toHaveURL(/wiki\/Main_Page/);

    // Titre de la page doit être défini
    await expect(page).toHaveTitle(/.+/);

    // Structure MediaWiki présente
    await expect(page.locator('#mw-content-text')).toBeVisible();
  });

  test('T-BROWSER-02: Page de connexion — champs login/mot de passe présents', async ({ page }) => {
    await page.goto('/wiki/Special:UserLogin');

    await expect(page.locator('#wpName1')).toBeVisible();
    await expect(page.locator('#wpPassword1')).toBeVisible();
    await expect(page.locator('#wpLoginAttempt')).toBeVisible();
  });

  test('T-BROWSER-03: Special:SemanticMediaWiki accessible', async ({ page }) => {
    await page.goto('/wiki/Special:SemanticMediaWiki');

    await expect(page.locator('#mw-content-text')).toBeVisible();
    // Pas d'erreur PHP fatale
    await expect(page.locator('body')).not.toContainText('Fatal error');
    await expect(page.locator('body')).not.toContainText('Parse error');
  });

  // ---------------------------------------------------------------------------
  // T-BROWSER-04 : vérifie que le skin vector-2022 est actif
  // Détecte la misconfiguration $wgDefaultSkin sans wfLoadSkin() correspondant
  // (MediaWiki 1.24+ exige wfLoadSkin() explicite — autodiscovery supprimé)
  // ---------------------------------------------------------------------------
  test('T-BROWSER-04: skin vector-2022 actif (pas de skin error)', async ({ page }) => {
    await page.goto('/wiki/Main_Page');

    // Pas de message d'erreur "skin not available"
    await expect(page.locator('body')).not.toContainText('is not available');
    await expect(page.locator('body')).not.toContainText('skin-error');

    // Le body doit porter la classe CSS skin-vector-2022
    await expect(page.locator('body')).toHaveClass(/skin-vector-2022/);

    // La page doit charger normalement (pas la page d'erreur de skin)
    await expect(page.locator('#mw-content-text')).toBeVisible();
  });

});
