from __future__ import annotations

import time
import uuid

import pytest
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

FIELD_IDS = {
    "username": "register-username",
    "email": "register-email",
    "password": "register-password",
    "passwordConfirm": "register-password-confirm",
    "accepted": "register-accepted",
    "submit": "register-submit",
}

ERROR_IDS = {
    "username": "error-username",
    "email": "error-email",
    "password": "error-password",
    "passwordConfirm": "error-password-confirm",
    "accepted": "error-accepted",
}


def _open_register(driver, frontend_url: str) -> None:
    driver.get(frontend_url + "/register")
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="register-form"]')
        )
    )


def _field(driver, name):
    return driver.find_element(By.CSS_SELECTOR, f'[data-testid="{FIELD_IDS[name]}"]')


def _error(driver, name):
    elements = driver.find_elements(
        By.CSS_SELECTOR, f'[data-testid="{ERROR_IDS[name]}"]'
    )
    return elements[0] if elements else None


def _fill(driver, **values) -> None:
    for name, value in values.items():
        if name == "accepted":
            checkbox = _field(driver, "accepted")
            if checkbox.is_selected() != bool(value):
                checkbox.click()
            continue
        elem = _field(driver, name)
        elem.clear()
        if value:
            elem.send_keys(value)


def _submit(driver) -> None:
    _field(driver, "submit").click()


def test_empty_form_reports_all_required_errors(driver, app_servers):
    _open_register(driver, app_servers["frontend_url"])
    _submit(driver)

    for name in ("username", "email", "password", "passwordConfirm", "accepted"):
        elem = _error(driver, name)
        assert elem is not None, f"missing error for {name}"
        assert elem.text.strip() != ""

    status_elements = driver.find_elements(
        By.CSS_SELECTOR, '[data-testid="register-status"]'
    )
    assert status_elements == []


def test_only_username_filled_keeps_other_errors(driver, app_servers):
    _open_register(driver, app_servers["frontend_url"])
    _fill(driver, username="janusz", accepted=False)
    _submit(driver)
    assert _error(driver, "username") is None
    for name in ("email", "password", "passwordConfirm", "accepted"):
        assert _error(driver, name) is not None


def test_username_too_short(driver, app_servers):
    _open_register(driver, app_servers["frontend_url"])
    _fill(
        driver,
        username="ab",
        email="ok@example.com",
        password="LongEnough1!",
        passwordConfirm="LongEnough1!",
        accepted=True,
    )
    _submit(driver)
    err = _error(driver, "username")
    assert err is not None
    assert "3" in err.text


def test_password_too_short(driver, app_servers):
    _open_register(driver, app_servers["frontend_url"])
    _fill(
        driver,
        username="janusz",
        email="ok@example.com",
        password="short",
        passwordConfirm="short",
        accepted=True,
    )
    _submit(driver)
    err = _error(driver, "password")
    assert err is not None
    assert "8" in err.text


def test_password_mismatch(driver, app_servers):
    _open_register(driver, app_servers["frontend_url"])
    _fill(
        driver,
        username="janusz",
        email="ok@example.com",
        password="LongEnough1!",
        passwordConfirm="Different1!",
        accepted=True,
    )
    _submit(driver)
    err = _error(driver, "passwordConfirm")
    assert err is not None
    assert err.text.strip() != ""


def test_terms_must_be_accepted(driver, app_servers):
    _open_register(driver, app_servers["frontend_url"])
    _fill(
        driver,
        username="janusz",
        email="ok@example.com",
        password="LongEnough1!",
        passwordConfirm="LongEnough1!",
        accepted=False,
    )
    _submit(driver)
    err = _error(driver, "accepted")
    assert err is not None


@pytest.mark.parametrize(
    "bad_email",
    [
        "plainaddress",
        "missing-at.example.com",
        "user@",
        "@example.com",
        "user@@example.com",
        "user@example",
        "user @example.com",
        "user@exa mple.com",
        "user@.com",
        "user@example..com",
        "user@-example.com",
    ],
)
def test_invalid_email_format_is_rejected(driver, app_servers, bad_email):
    _open_register(driver, app_servers["frontend_url"])
    _fill(
        driver,
        username="janusz",
        email=bad_email,
        password="LongEnough1!",
        passwordConfirm="LongEnough1!",
        accepted=True,
    )
    _submit(driver)
    err = _error(driver, "email")
    assert err is not None, f"expected client-side email error for {bad_email!r}"
    assert "email" in err.text.lower() or "format" in err.text.lower()
    status_elements = driver.find_elements(
        By.CSS_SELECTOR, '[data-testid="register-status"]'
    )
    assert status_elements == []


def test_valid_registration_clears_errors_and_shows_status(driver, app_servers):
    _open_register(driver, app_servers["frontend_url"])
    unique = uuid.uuid4().hex[:10]
    _fill(
        driver,
        username=f"user_{unique}",
        email=f"valid_{unique}@example.com",
        password="LongEnough1!",
        passwordConfirm="LongEnough1!",
        accepted=True,
    )
    _submit(driver)

    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="register-status"]')
        )
    )
    status = driver.find_element(
        By.CSS_SELECTOR, '[data-testid="register-status"]'
    )
    assert "sukces" in status.text.lower() or "zakon" in status.text.lower()

    for name in ("username", "email", "password", "passwordConfirm", "accepted"):
        assert _error(driver, name) is None


def test_email_html5_validation_is_bypassed_for_custom_messages(driver, app_servers):
    _open_register(driver, app_servers["frontend_url"])
    form = driver.find_element(
        By.CSS_SELECTOR, '[data-testid="register-form"]'
    )
    assert form.get_attribute("novalidate") is not None


def test_server_rejects_duplicate_registration(driver, app_servers):
    _open_register(driver, app_servers["frontend_url"])
    unique = uuid.uuid4().hex[:10]
    payload = dict(
        username=f"dup_{unique}",
        email=f"dup_{unique}@example.com",
        password="LongEnough1!",
        passwordConfirm="LongEnough1!",
        accepted=True,
    )
    _fill(driver, **payload)
    _submit(driver)
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="register-status"]')
        )
    )
    time.sleep(0.2)

    _open_register(driver, app_servers["frontend_url"])
    _fill(driver, **payload)
    _submit(driver)
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="register-server-error"]')
        )
    )
    err = driver.find_element(
        By.CSS_SELECTOR, '[data-testid="register-server-error"]'
    )
    assert err.text.strip() != ""
