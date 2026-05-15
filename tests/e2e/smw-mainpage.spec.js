// =============================================================================
// tests/e2e/smw-mainpage.spec.js
// Tests navigateur E2E — SMW Marketplace (Playwright / Firefox)
// VM_IP : adresse IP de la VM cible (via playwright.config.js)
// =============================================================================
const { test, expect } = require('@playwright/test');

test.describe('SMW Marketplace — Navigateur Firefox', () => {

  test('T-BROWSER-01: Page principale MediaWiki accessible', async ({ page }) => {
    // Navigation directe vers Main_Page (la redirection / → localhost ne suit pas l'IP externe)
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

});
