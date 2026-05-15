// =============================================================================
// tests/e2e/playwright.config.js
// Configuration Playwright — Tests navigateur SMW Marketplace
// Émulation Firefox, certificat self-signed ignoré
// =============================================================================
const { defineConfig, devices } = require('@playwright/test');

const VM_IP = process.env.VM_IP || '20.48.144.74';

module.exports = defineConfig({
  testDir: '.',
  testMatch: '**/*.spec.js',
  timeout: 30000,
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
