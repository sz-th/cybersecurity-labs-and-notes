from __future__ import annotations

import time
import uuid
from pathlib import Path

import pytest
import requests
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

ATTACK_PAGE = Path(__file__).resolve().parent / "csrf_attack.html"


def _register_user(backend_url: str, username: str, email: str, password: str) -> None:
    resp = requests.post(
        backend_url + "/api/register",
        json={"username": username, "email": email, "password": password},
        timeout=10,
    )
    assert resp.status_code in (200, 409), resp.text


def _open_login(driver, frontend_url: str) -> None:
    driver.get(frontend_url + "/login")
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="login-form"]')
        )
    )


def _ui_login(driver, frontend_url: str, username: str, password: str) -> None:
    _open_login(driver, frontend_url)
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="login-username"]'
    ).send_keys(username)
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="login-password"]'
    ).send_keys(password)
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="login-submit"]'
    ).click()
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="account-username"]')
        )
    )


def _wait_email(driver, expected: str, timeout: float = 10.0) -> None:
    WebDriverWait(driver, timeout).until(
        lambda d: d.find_element(
            By.CSS_SELECTOR, '[data-testid="account-email"]'
        ).text.strip()
        == expected
    )


def _refresh_account(driver) -> None:
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="account-refresh"]'
    ).click()


@pytest.fixture
def credentials(app_servers):
    suffix = uuid.uuid4().hex[:10]
    return {
        "username": f"csrf_{suffix}",
        "password": "LongEnough1!",
        "email": f"victim_{suffix}@example.com",
    }


@pytest.fixture
def logged_in(driver, app_servers, credentials):
    _register_user(
        app_servers["backend_url"],
        credentials["username"],
        credentials["email"],
        credentials["password"],
    )
    _ui_login(
        driver,
        app_servers["frontend_url"],
        credentials["username"],
        credentials["password"],
    )
    return credentials


def test_login_form_requires_username_and_password(driver, app_servers):
    _open_login(driver, app_servers["frontend_url"])
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="login-submit"]'
    ).click()
    WebDriverWait(driver, 5).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="login-local-error"]')
        )
    )


def test_login_with_invalid_credentials_shows_server_error(
    driver, app_servers
):
    _open_login(driver, app_servers["frontend_url"])
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="login-username"]'
    ).send_keys("nobody_" + uuid.uuid4().hex[:8])
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="login-password"]'
    ).send_keys("WrongPassword!")
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="login-submit"]'
    ).click()
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="login-error"]')
        )
    )


def test_successful_login_displays_account(driver, app_servers, logged_in):
    email = driver.find_element(
        By.CSS_SELECTOR, '[data-testid="account-email"]'
    ).text.strip()
    assert email == logged_in["email"]


def test_csrf_vulnerable_get_attack_changes_email(
    driver, app_servers, logged_in
):
    original_email = logged_in["email"]
    attacker_email = f"attacker_{uuid.uuid4().hex[:6]}@evil.example"

    _wait_email(driver, original_email)

    driver.switch_to.new_window("tab")
    driver.get(
        f"{app_servers['backend_url']}/api/account/email?newEmail={attacker_email}"
    )
    time.sleep(0.3)

    driver.switch_to.window(driver.window_handles[0])
    _refresh_account(driver)
    _wait_email(driver, attacker_email)


def test_csrf_attack_via_malicious_html_changes_email(
    driver, app_servers, logged_in
):
    original_email = logged_in["email"]
    _wait_email(driver, original_email)
    attacker_email = f"attacker_{uuid.uuid4().hex[:6]}@evil.example"

    html = ATTACK_PAGE.read_text(encoding="utf-8").replace(
        "attacker@evil.example", attacker_email
    ).replace(
        "http://127.0.0.1:8088/api/account/email",
        app_servers["backend_url"] + "/api/account/email",
    )
    file_path = ATTACK_PAGE.parent / f"_attack_{uuid.uuid4().hex[:6]}.html"
    file_path.write_text(html, encoding="utf-8")
    try:
        driver.switch_to.new_window("tab")
        driver.get(file_path.as_uri())
        time.sleep(0.5)
    finally:
        try:
            file_path.unlink()
        except OSError:
            pass

    driver.switch_to.window(driver.window_handles[0])
    _refresh_account(driver)
    _wait_email(driver, attacker_email)


def test_csrf_protected_endpoint_rejects_request_without_token(
    driver, app_servers, logged_in
):
    original_email = logged_in["email"]
    cookies = {c["name"]: c["value"] for c in driver.get_cookies()}
    assert "session" in cookies

    resp = requests.post(
        app_servers["backend_url"] + "/api/account/email/secure",
        json={"email": f"intruder_{uuid.uuid4().hex[:6]}@evil.example"},
        cookies=cookies,
        timeout=10,
    )
    assert resp.status_code == 403

    _refresh_account(driver)
    _wait_email(driver, original_email)


def test_csrf_protected_endpoint_rejects_invalid_token(
    driver, app_servers, logged_in
):
    original_email = logged_in["email"]
    cookies = {c["name"]: c["value"] for c in driver.get_cookies()}
    resp = requests.post(
        app_servers["backend_url"] + "/api/account/email/secure",
        json={"email": f"intruder_{uuid.uuid4().hex[:6]}@evil.example"},
        headers={"X-CSRF-Token": "totally-wrong-token"},
        cookies=cookies,
        timeout=10,
    )
    assert resp.status_code == 403

    _refresh_account(driver)
    _wait_email(driver, original_email)


def test_csrf_protected_endpoint_accepts_request_with_valid_token(
    driver, app_servers, logged_in
):
    new_email = f"owner_{uuid.uuid4().hex[:6]}@example.com"
    field = driver.find_element(
        By.CSS_SELECTOR, '[data-testid="email-change-input"]'
    )
    field.clear()
    field.send_keys(new_email)
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="email-change-submit"]'
    ).click()
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="email-change-status"]')
        )
    )
    _wait_email(driver, new_email)


def test_logout_invalidates_session(driver, app_servers, logged_in):
    cookies_before = {c["name"]: c["value"] for c in driver.get_cookies()}
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="account-logout"]'
    ).click()
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="account-not-logged-in"]')
        )
    )
    resp = requests.get(
        app_servers["backend_url"] + "/api/account",
        cookies=cookies_before,
        timeout=10,
    )
    assert resp.status_code == 401


def test_csrf_attack_fails_after_logout(driver, app_servers, logged_in):
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="account-logout"]'
    ).click()
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="account-not-logged-in"]')
        )
    )
    attacker_email = f"after_logout_{uuid.uuid4().hex[:6]}@evil.example"
    resp = requests.get(
        app_servers["backend_url"] + "/api/account/email",
        params={"newEmail": attacker_email},
        timeout=10,
    )
    assert resp.status_code == 401
