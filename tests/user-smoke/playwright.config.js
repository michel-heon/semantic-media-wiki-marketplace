// =============================================================================
// tests/user-smoke/playwright.config.js
// Configuration Playwright — Smoke tests utilisateur SMW Marketplace
// Émulation Firefox, certificat self-signed ignoré, timeout étendu (édition wiki)
// =============================================================================
const { defineConfig, devices } = require('@playwright/test');

const VM_IP = process.env.VM_IP || '20.48.144.74';

module.exports = defineConfig({
  testDir: '.',
  testMatch: '**/*.spec.js',
  timeout: 60000,
  use: {
    baseURL: `https://${VM_IP}`,
    ignoreHTTPSErrors: true,
    screenshot: 'only-on-failure',
    trace: 'off',
  },
  projects: [
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
  ],
  reporter: [['list']],
  outputDir: 'test-results',
});
