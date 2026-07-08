import { defineConfig, devices } from "@playwright/test";

const BACKEND_PORT = process.env.BACKEND_PORT || "8088";
const FRONTEND_PORT = process.env.FRONTEND_PORT || "5174";
const BACKEND_URL =
  process.env.BACKEND_URL || `http://127.0.0.1:${BACKEND_PORT}`;
const FRONTEND_URL =
  process.env.FRONTEND_URL || `http://127.0.0.1:${FRONTEND_PORT}`;

export default defineConfig({
  testDir: "./tests",
  timeout: 90_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL: FRONTEND_URL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: [
    {
      command: "go run .",
      cwd: "../../app/backend",
      url: `${BACKEND_URL}/api/products`,
      reuseExistingServer: false,
      timeout: 60_000,
      env: {
        PORT: BACKEND_PORT,
      },
    },
    {
      command: `npm run dev -- --host 127.0.0.1 --port ${FRONTEND_PORT}`,
      cwd: "../../app/frontend",
      url: FRONTEND_URL,
      reuseExistingServer: false,
      timeout: 90_000,
      env: {
        VITE_API_BASE_URL: BACKEND_URL,
      },
    },
  ],
});
