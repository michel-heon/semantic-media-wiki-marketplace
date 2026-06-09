// =============================================================================
// tests/e2e/smw-mainpage.spec.js
// Tests navigateur E2E — SMW Marketplace (Playwright / Firefox)
// VM_IP : adresse IP de la VM cible (via playwright.config.js)
// =============================================================================
const { test, expect } = require('@playwright/test');

test.describe('SMW Marketplace — Navigateur Firefox', () => {

  // ---------------------------------------------------------------------------
  // T-BROWSER-00 : vérifie que la redirection "/" pointe vers l'adresse de connexion
  // Détecte deux misconfigurations :
  //   1. $wgServer = 'https://localhost'  (valeur par défaut non remplacée)
  //   2. $wgServer = 'https://<IP>'      quand la VM est accédée via un FQDN
  //      (smw-firstboot.sh doit détecter le FQDN via reverse DNS — ADR-618)
  // VM_IP : adresse de connexion (IP ou FQDN) — le Location header doit la contenir.
  // ---------------------------------------------------------------------------
  test('T-BROWSER-00: redirect "/" → adresse de connexion (pas localhost, pas IP si FQDN)', async ({ request }) => {
    const vmIP = process.env.VM_IP || '20.48.144.74';

    // Récupère "/" sans suivre les redirections pour inspecter le Location header
    const response = await request.get(`https://${vmIP}/`, { maxRedirects: 0 });

    const status = response.status();
    expect(status, 'La racine "/" doit envoyer une redirection HTTP 3xx').toBeGreaterThanOrEqual(301);
    expect(status).toBeLessThanOrEqual(308);

    const location = response.headers()['location'] ?? '';
    expect(
      location,
      `ÉCHEC $wgServer: redirect "/" → "${location}" pointe vers localhost au lieu de https://${vmIP}/...`
    ).not.toMatch(/\/\/localhost/);

    // La redirection doit contenir l'adresse utilisée pour se connecter.
    // Si VM_IP est un FQDN, le Location doit contenir ce FQDN (pas l'IP brute).
    expect(
      location,
      `ÉCHEC $wgServer: redirect "/" → "${location}" ne correspond pas à l'adresse de connexion (${vmIP}). ` +
      `smw-firstboot.sh doit configurer $wgServer avec le FQDN quand un label DNS est assigné.`
    ).toContain(vmIP);
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
