# TestingBot

TestingBot is a cloud-based platform for running automated tests on real browsers and mobile devices at scale.

Run Selenium, Cypress, Playwright, Maestro and Appium tests without maintaining your own infrastructure.

👉 https://testingbot.com

---

## Why TestingBot

Modern web and mobile apps ship fast. Testing shouldn’t slow you down.

TestingBot helps teams:

- Run automated tests across 6000+ browser/device combinations
- Scale test execution in parallel
- Debug failures with video, logs and network data
- Integrate seamlessly into CI/CD pipelines
- Reduce flaky tests with consistent cloud environments

---

## Supported Frameworks

- Selenium WebDriver
- Appium (iOS & Android)
- Cypress
- Playwright
- WebdriverIO
- Robot Framework
- Maestro

---

## Quick Start

### Selenium (JavaScript)

```javascript
const { Builder } = require('selenium-webdriver');

const driver = new Builder()
  .usingServer('https://hub.testingbot.com/wd/hub')
  .withCapabilities({
    browserName: 'chrome',
    version: 'latest',
    platform: 'WINDOWS',
    tb: {
      apiKey: process.env.TESTINGBOT_KEY,
      apiSecret: process.env.TESTINGBOT_SECRET
    }
  })
  .build();

(async function test() {
  await driver.get('https://example.com');
  console.log(await driver.getTitle());
  await driver.quit();
})();
```

---

## Key Features

### ⚡ Fast Parallel Testing
Run hundreds of tests simultaneously across browsers and devices.

### 📹 Debugging Tools
- Video recordings
- Selenium logs
- Network logs
- Screenshots on failure

### 🔗 CI/CD Ready
Works with:
- GitHub Actions
- GitLab CI
- Jenkins
- CircleCI
- Bitbucket Pipelines

### 📱 Real Devices
Test on real iOS and Android devices, not emulators only.

### 🔒 Secure Infrastructure
Isolated test sessions with secure, disposable environments.

---

## Example Use Cases

- Regression testing for web apps
- Cross-browser compatibility testing
- Mobile app automation testing
- CI pipeline validation
- Visual debugging of flaky tests

---

## Getting Started

1. Create an account: https://testingbot.com
2. Get your API key & secret
3. Run your first test in under 5 minutes

Docs: https://testingbot.com/support

---

## Open Source SDKs

Explore our official repositories:

- Selenium bindings
- Appium helpers
- CI examples
- Sample projects

👉 https://github.com/testingbot

---

## Status & Reliability

- High-availability cloud infrastructure
- Distributed test execution
- Global browser/device coverage

---

## Contributing

We welcome contributions and feedback.

- Open issues for bugs or feature requests
- Submit PRs to SDK repositories
- Share example test setups

---

## Support

- Docs: https://testingbot.com/support
- Dashboard: https://testingbot.com/members
- Contact: info@testingbot.com

---

## TestingBot

Automated testing infrastructure for teams that ship fast.
