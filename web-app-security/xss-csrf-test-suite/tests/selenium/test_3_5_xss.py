from __future__ import annotations

import uuid

import pytest
from selenium.common.exceptions import NoAlertPresentException
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

XSS_PAYLOADS = [
    "<script>window.xssTriggered = true</script>",
    "<img src=x onerror=\"window.xssTriggered = true\">",
    "<svg onload=\"window.xssTriggered = true\"></svg>",
    "<iframe src=\"javascript:window.xssTriggered=true\"></iframe>",
    "<a href=\"javascript:window.xssTriggered=true\">link</a>",
    "<body onload=\"window.xssTriggered = true\">",
    "<details open ontoggle=\"window.xssTriggered = true\"></details>",
    "\"><script>window.xssTriggered=true</script>",
    "<scr<script>ipt>window.xssTriggered=true</scr</script>ipt>",
    "<input autofocus onfocus=\"window.xssTriggered=true\">",
]


def _no_alert(driver) -> bool:
    try:
        alert = driver.switch_to.alert
    except NoAlertPresentException:
        return True
    try:
        alert.dismiss()
    except Exception:
        pass
    return False


def _reset_flag(driver) -> None:
    driver.execute_script("window.xssTriggered = false;")


def _read_flag(driver) -> bool:
    return bool(driver.execute_script("return window.xssTriggered === true;"))


def _open(driver, frontend_url: str, path: str) -> None:
    driver.get(frontend_url + path)


@pytest.fixture
def reset_xss(driver):
    _reset_flag(driver)
    yield
    assert _no_alert(driver), "unexpected JavaScript alert appeared"
    assert _read_flag(driver) is False, "XSS payload executed"


@pytest.mark.parametrize("payload", XSS_PAYLOADS)
def test_comments_xss_payload_is_rendered_as_text(
    driver, app_servers, reset_xss, payload
):
    _open(driver, app_servers["frontend_url"], "/comments")
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="comment-input"]')
        )
    )
    textarea = driver.find_element(
        By.CSS_SELECTOR, '[data-testid="comment-input"]'
    )
    textarea.clear()
    textarea.send_keys(payload)
    driver.find_element(By.CSS_SELECTOR, '[data-testid="comment-submit"]').click()

    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="comment-0"]')
        )
    )
    comment = driver.find_element(By.CSS_SELECTOR, '[data-testid="comment-0"]')

    rendered_text = comment.text
    inner_html = comment.get_attribute("innerHTML")

    assert payload.strip() in rendered_text or payload in rendered_text
    assert "<script" not in inner_html.lower()
    assert "onerror=" not in inner_html.lower()
    assert "onload=" not in inner_html.lower()
    assert "ontoggle=" not in inner_html.lower()

    nested_scripts = driver.execute_script(
        "return document.querySelectorAll('[data-testid=\"comments-list\"] script').length"
    )
    nested_iframes = driver.execute_script(
        "return document.querySelectorAll('[data-testid=\"comments-list\"] iframe').length"
    )
    nested_imgs = driver.execute_script(
        "return document.querySelectorAll('[data-testid=\"comments-list\"] img').length"
    )
    nested_svgs = driver.execute_script(
        "return document.querySelectorAll('[data-testid=\"comments-list\"] svg').length"
    )
    assert nested_scripts == 0
    assert nested_iframes == 0
    assert nested_imgs == 0
    assert nested_svgs == 0


def test_registration_username_xss_does_not_execute(
    driver, app_servers, reset_xss
):
    _open(driver, app_servers["frontend_url"], "/register")
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="register-username"]')
        )
    )
    payload = "<img src=x onerror=\"window.xssTriggered=true\">"
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="register-username"]'
    ).send_keys(payload)
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="register-email"]'
    ).send_keys("ok@example.com")
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="register-password"]'
    ).send_keys("LongEnough1!")
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="register-password-confirm"]'
    ).send_keys("LongEnough1!")
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="register-accepted"]'
    ).click()
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="register-submit"]'
    ).click()

    nested_imgs = driver.execute_script(
        "return document.querySelectorAll('form img').length"
    )
    assert nested_imgs == 0


def test_payment_form_xss_in_full_name(driver, app_servers, reset_xss):
    _open(driver, app_servers["frontend_url"], "/payments")
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="payments-form"]')
        )
    )
    payload = "<svg/onload=\"window.xssTriggered=true\">"
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="payments-fullname"]'
    ).send_keys(payload)
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="payments-email"]'
    ).send_keys("ok@example.com")
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="payments-amount"]'
    ).send_keys("12.50")
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="payments-submit"]'
    ).click()
    nested_svgs = driver.execute_script(
        "return document.querySelectorAll('form svg').length"
    )
    assert nested_svgs == 0


def test_url_param_path_does_not_execute_script(driver, app_servers, reset_xss):
    payload_path = "/comments#<script>window.xssTriggered=true</script>"
    _open(driver, app_servers["frontend_url"], payload_path)
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="comment-input"]')
        )
    )
    document_scripts = driver.execute_script(
        "return Array.from(document.scripts).filter(s => /window\\.xssTriggered/.test(s.text)).length"
    )
    assert document_scripts == 0


def test_comment_text_is_textnode_only(driver, app_servers, reset_xss):
    _open(driver, app_servers["frontend_url"], "/comments")
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="comment-input"]')
        )
    )
    payload = "<b>bold</b><i>italic</i>"
    textarea = driver.find_element(
        By.CSS_SELECTOR, '[data-testid="comment-input"]'
    )
    textarea.send_keys(payload)
    driver.find_element(
        By.CSS_SELECTOR, '[data-testid="comment-submit"]'
    ).click()
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="comment-0"]')
        )
    )
    counts = driver.execute_script(
        """
        const el = document.querySelector('[data-testid="comment-0"]');
        let text = 0;
        let elementChildren = el.children.length;
        for (const node of el.childNodes) {
          if (node.nodeType === 3) text += 1;
        }
        return { text, elementChildren };
        """
    )
    assert counts["elementChildren"] == 0
    assert counts["text"] >= 1


def test_multiple_payloads_in_sequence(driver, app_servers, reset_xss):
    _open(driver, app_servers["frontend_url"], "/comments")
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, '[data-testid="comment-input"]')
        )
    )
    textarea = driver.find_element(
        By.CSS_SELECTOR, '[data-testid="comment-input"]'
    )
    submit = driver.find_element(
        By.CSS_SELECTOR, '[data-testid="comment-submit"]'
    )
    for payload in XSS_PAYLOADS[:5]:
        textarea.clear()
        textarea.send_keys(payload + uuid.uuid4().hex)
        submit.click()
    assert _read_flag(driver) is False
    total_scripts = driver.execute_script(
        "return document.querySelectorAll('[data-testid=\"comments-list\"] script').length"
    )
    assert total_scripts == 0
