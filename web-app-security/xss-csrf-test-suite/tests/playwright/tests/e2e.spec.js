import { test, expect, request as playwrightRequest } from "@playwright/test";

const BACKEND_URL = process.env.BACKEND_URL || "http://127.0.0.1:8088";

const PRODUCTS = [
  { id: 1, name: "Laptop", price: 3999.99 },
  { id: 2, name: "Mysz", price: 149.99 },
  { id: 3, name: "Klawiatura", price: 249.99 },
  { id: 4, name: "Monitor", price: 1299.0 },
  { id: 5, name: "Sluchawki", price: 399.5 },
];

function randomSuffix() {
  return Math.random().toString(36).slice(2, 10);
}

function priceStr(value) {
  return `${value.toFixed(2)} PLN`;
}

test.describe.configure({ mode: "serial" });

test("pelny scenariusz E2E sklepu z uwierzytelnianiem", async ({
  page,
  context,
}) => {
  const suffix = randomSuffix();
  const username = `e2e_${suffix}`;
  const initialEmail = `init_${suffix}@example.com`;
  const updatedEmail = `updated_${suffix}@example.com`;
  const password = "LongEnough1!";

  await page.goto("/");
  await page.evaluate(() => localStorage.clear());
  await page.reload();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.locator("h1")).toHaveText("Zadanie 8 - Sklep");
  await expect(page.getByTestId("nav-products")).toBeVisible();
  await expect(page.getByTestId("nav-cart")).toBeVisible();
  await expect(page.getByTestId("nav-payments")).toBeVisible();
  await expect(page.getByTestId("nav-register")).toBeVisible();
  await expect(page.getByTestId("nav-comments")).toBeVisible();
  await expect(page.getByTestId("nav-login")).toBeVisible();
  await expect(page.getByTestId("nav-account")).toHaveCount(0);

  await expect(page.getByTestId("product-1")).toBeVisible();
  await expect(page.getByTestId("products-list")).toBeVisible();
  for (const product of PRODUCTS) {
    await expect(page.getByTestId(`product-${product.id}`)).toBeVisible();
    await expect(page.getByTestId(`product-name-${product.id}`)).toHaveText(
      product.name,
    );
    await expect(page.getByTestId(`product-price-${product.id}`)).toHaveText(
      priceStr(product.price),
    );
    await expect(page.getByTestId(`add-to-cart-${product.id}`)).toBeEnabled();
  }

  await page.getByTestId("nav-cart").click();
  await expect(page).toHaveURL(/\/cart$/);
  await expect(page.getByTestId("cart-count")).toContainText("0");
  await expect(page.getByTestId("cart-empty")).toBeVisible();
  await expect(page.getByTestId("cart-total")).toHaveText("Razem: 0.00 PLN");
  await expect(page.getByTestId("cart-submit")).toBeDisabled();

  await page.getByTestId("nav-products").click();
  await page.getByTestId("add-to-cart-1").click();
  await page.getByTestId("add-to-cart-2").click();
  await page.getByTestId("add-to-cart-3").click();
  await page.getByTestId("nav-cart").click();
  await expect(page.getByTestId("cart-count")).toContainText("3");
  const itemRows = page.locator('[data-testid="cart-items"] > li');
  await expect(itemRows).toHaveCount(3);
  await expect(page.getByTestId("cart-total")).toHaveText(
    `Razem: ${(3999.99 + 149.99 + 249.99).toFixed(2)} PLN`,
  );
  await expect(page.getByTestId("cart-submit")).toBeEnabled();
  await expect(page.getByTestId("cart-clear")).toBeEnabled();

  const firstRemoveButton = itemRows.first().locator("button");
  await firstRemoveButton.click();
  await expect(page.getByTestId("cart-count")).toContainText("2");
  await expect(itemRows).toHaveCount(2);

  await page.getByTestId("cart-submit").click();
  await expect(page.getByTestId("cart-status")).toContainText(
    "Koszyk przyjety",
  );
  await expect(page.getByTestId("global-status")).toContainText(
    "Koszyk przyjety",
  );

  await page.getByTestId("cart-clear").click();
  await expect(page.getByTestId("cart-count")).toContainText("0");
  await expect(page.getByTestId("cart-empty")).toBeVisible();
  await expect(page.getByTestId("cart-total")).toHaveText("Razem: 0.00 PLN");

  await page.getByTestId("nav-register").click();
  await expect(page).toHaveURL(/\/register$/);
  await expect(page.getByTestId("register-form")).toBeVisible();
  await page.getByTestId("register-submit").click();
  await expect(page.getByTestId("error-username")).toBeVisible();
  await expect(page.getByTestId("error-email")).toBeVisible();
  await expect(page.getByTestId("error-password")).toBeVisible();
  await expect(page.getByTestId("error-password-confirm")).toBeVisible();
  await expect(page.getByTestId("error-accepted")).toBeVisible();
  await expect(page.getByTestId("register-status")).toHaveCount(0);

  await page.getByTestId("register-username").fill(username);
  await page.getByTestId("register-email").fill("not-an-email");
  await page.getByTestId("register-password").fill(password);
  await page.getByTestId("register-password-confirm").fill(password);
  await page.getByTestId("register-accepted").check();
  await page.getByTestId("register-submit").click();
  await expect(page.getByTestId("error-email")).toBeVisible();
  await expect(page.getByTestId("error-email")).toContainText(/email/i);
  await expect(page.getByTestId("register-status")).toHaveCount(0);

  await page.getByTestId("register-email").fill(initialEmail);
  await page.getByTestId("register-password-confirm").fill("Different1!");
  await page.getByTestId("register-submit").click();
  await expect(page.getByTestId("error-password-confirm")).toBeVisible();

  await page.getByTestId("register-password-confirm").fill(password);
  await page.getByTestId("register-submit").click();
  await expect(page.getByTestId("register-status")).toContainText(/sukces|zakon/i);
  await expect(page.getByTestId("error-username")).toHaveCount(0);
  await expect(page.getByTestId("error-email")).toHaveCount(0);

  await page.getByTestId("nav-comments").click();
  await expect(page).toHaveURL(/\/comments$/);
  await expect(page.getByTestId("comments-empty")).toBeVisible();
  const xssPayload = `<img src=x onerror="window.xssTriggered=true"><script>window.xssTriggered=true</script>`;
  await page.evaluate(() => {
    window.xssTriggered = false;
  });
  await page.getByTestId("comment-input").fill(xssPayload);
  await page.getByTestId("comment-submit").click();
  await expect(page.getByTestId("comment-0")).toBeVisible();
  await expect(page.getByTestId("comment-0")).toContainText("<script>");
  const xssExecuted = await page.evaluate(
    () => window.xssTriggered === true,
  );
  expect(xssExecuted).toBe(false);
  const scriptCount = await page.evaluate(
    () =>
      document.querySelectorAll(
        '[data-testid="comments-list"] script',
      ).length,
  );
  expect(scriptCount).toBe(0);
  const imgCount = await page.evaluate(
    () => document.querySelectorAll('[data-testid="comments-list"] img').length,
  );
  expect(imgCount).toBe(0);

  await page.getByTestId("nav-login").click();
  await expect(page).toHaveURL(/\/login$/);
  await expect(page.getByTestId("login-form")).toBeVisible();
  await page.getByTestId("login-submit").click();
  await expect(page.getByTestId("login-local-error")).toBeVisible();

  await page.getByTestId("login-username").fill(username);
  await page.getByTestId("login-password").fill("WrongPassword!");
  await page.getByTestId("login-submit").click();
  await expect(page.getByTestId("login-error")).toBeVisible();
  await expect(page.getByTestId("login-error")).toContainText(/niepoprawne/i);

  await page.getByTestId("login-password").fill(password);
  await page.getByTestId("login-submit").click();
  await expect(page).toHaveURL(/\/account$/);
  await expect(page.getByTestId("account-username")).toHaveText(username);
  await expect(page.getByTestId("account-email")).toHaveText(initialEmail);
  await expect(page.getByTestId("nav-account")).toBeVisible();
  await expect(page.getByTestId("nav-login")).toHaveCount(0);

  const cookiesAfterLogin = await context.cookies();
  const sessionCookie = cookiesAfterLogin.find((c) => c.name === "session");
  expect(sessionCookie).toBeDefined();
  expect(sessionCookie.httpOnly).toBe(true);
  expect(sessionCookie.value.length).toBeGreaterThan(20);

  await page.getByTestId("email-change-input").fill(updatedEmail);
  await page.getByTestId("email-change-submit").click();
  await expect(page.getByTestId("email-change-status")).toBeVisible();
  await expect(page.getByTestId("account-email")).toHaveText(updatedEmail);

  const apiContext = await playwrightRequest.newContext({
    baseURL: BACKEND_URL,
  });
  const noSessionResponse = await apiContext.post(
    "/api/account/email/secure",
    {
      data: { email: `nope_${randomSuffix()}@evil.example` },
    },
  );
  expect(noSessionResponse.status()).toBe(401);

  const cookieHeader = cookiesAfterLogin
    .filter((c) => c.name === "session")
    .map((c) => `${c.name}=${c.value}`)
    .join("; ");
  const missingTokenResponse = await apiContext.post(
    "/api/account/email/secure",
    {
      data: { email: `attacker_${randomSuffix()}@evil.example` },
      headers: { Cookie: cookieHeader },
    },
  );
  expect(missingTokenResponse.status()).toBe(403);

  const invalidTokenResponse = await apiContext.post(
    "/api/account/email/secure",
    {
      data: { email: `attacker_${randomSuffix()}@evil.example` },
      headers: {
        Cookie: cookieHeader,
        "X-CSRF-Token": "obviously-wrong",
      },
    },
  );
  expect(invalidTokenResponse.status()).toBe(403);

  await page.getByTestId("account-refresh").click();
  await expect(page.getByTestId("account-email")).toHaveText(updatedEmail);

  const cartPage = await context.newPage();
  await cartPage.goto("/cart");
  await expect(cartPage.getByTestId("cart-empty")).toBeVisible();

  await page.bringToFront();
  await page.getByTestId("nav-products").click();
  await page.getByTestId("add-to-cart-4").click();
  await page.getByTestId("add-to-cart-5").click();

  await cartPage.bringToFront();
  await expect(cartPage.getByTestId("cart-count")).toContainText("2", {
    timeout: 10_000,
  });
  await expect(cartPage.getByTestId("cart-total")).toHaveText(
    `Razem: ${(1299.0 + 399.5).toFixed(2)} PLN`,
  );

  await cartPage.getByTestId("cart-clear").click();
  await expect(cartPage.getByTestId("cart-count")).toContainText("0");

  await page.bringToFront();
  await page.getByTestId("nav-cart").click();
  await expect(page.getByTestId("cart-count")).toContainText("0");

  await page.getByTestId("nav-payments").click();
  await expect(page).toHaveURL(/\/payments$/);
  await expect(page.getByTestId("payments-form")).toBeVisible();
  await page.getByTestId("payments-fullname").fill("Jan Kowalski");
  await page.getByTestId("payments-email").fill(updatedEmail);
  await page.getByTestId("payments-amount").fill("123.45");
  await page.getByTestId("payments-submit").click();
  await expect(page.getByTestId("payments-status")).toContainText(
    "Platnosc przyjeta",
  );
  await expect(page.getByTestId("payments-status")).toContainText("123.45");

  await page.getByTestId("nav-account").click();
  await page.getByTestId("account-logout").click();
  await expect(page.getByTestId("account-not-logged-in")).toBeVisible();
  await expect(page.getByTestId("nav-login")).toBeVisible();
  await expect(page.getByTestId("nav-account")).toHaveCount(0);

  const afterLogoutAccount = await apiContext.get("/api/account", {
    headers: { Cookie: cookieHeader },
  });
  expect(afterLogoutAccount.status()).toBe(401);

  const productsApi = await apiContext.get("/api/products");
  expect(productsApi.status()).toBe(200);
  const productsBody = await productsApi.json();
  expect(Array.isArray(productsBody)).toBe(true);
  expect(productsBody).toHaveLength(PRODUCTS.length);
  expect(productsBody[0]).toHaveProperty("id", PRODUCTS[0].id);
  expect(productsBody[0]).toHaveProperty("name", PRODUCTS[0].name);
  expect(productsBody[0]).toHaveProperty("price", PRODUCTS[0].price);

  const securityResponse = await apiContext.get("/api/products");
  expect(securityResponse.headers()["x-content-type-options"]).toBe("nosniff");
  expect(securityResponse.headers()["x-frame-options"]).toBe("DENY");
  expect(securityResponse.headers()["referrer-policy"]).toBe("no-referrer");

  await apiContext.dispose();
  await cartPage.close();
});
