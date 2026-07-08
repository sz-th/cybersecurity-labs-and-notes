from __future__ import annotations

import time

from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

ADD_PRODUCT_1 = '[data-testid="add-to-cart-1"]'
ADD_PRODUCT_2 = '[data-testid="add-to-cart-2"]'
ADD_PRODUCT_3 = '[data-testid="add-to-cart-3"]'
CART_COUNT = '[data-testid="cart-count"]'
CART_TOTAL = '[data-testid="cart-total"]'
CART_EMPTY = '[data-testid="cart-empty"]'
CART_ITEMS = '[data-testid="cart-items"] li'
NAV_CART = '[data-testid="nav-cart"]'
NAV_PRODUCTS = '[data-testid="nav-products"]'
CART_SUBMIT = '[data-testid="cart-submit"]'
CART_STATUS = '[data-testid="cart-status"]'
CART_CLEAR = '[data-testid="cart-clear"]'


def _open(driver, frontend_url: str, path: str) -> None:
    driver.get(frontend_url + path)
    if path in ("", "/"):
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located(
                (By.CSS_SELECTOR, '[data-testid="products-list"]')
            )
        )
    elif path == "/cart":
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, CART_COUNT))
        )


def _open_new_tab(driver, frontend_url: str, path: str) -> str:
    driver.switch_to.new_window("tab")
    handle = driver.current_window_handle
    _open(driver, frontend_url, path)
    return handle


def _switch(driver, handle: str) -> None:
    driver.switch_to.window(handle)


def _read_count(driver) -> int:
    text = driver.find_element(By.CSS_SELECTOR, CART_COUNT).text
    digits = "".join(ch for ch in text if ch.isdigit())
    return int(digits) if digits else 0


def _wait_count(driver, expected: int, timeout: float = 10.0) -> None:
    WebDriverWait(driver, timeout).until(
        lambda d: _read_count(d) == expected,
    )


def _read_total(driver) -> str:
    return driver.find_element(By.CSS_SELECTOR, CART_TOTAL).text


def test_add_in_tab_a_propagates_to_tab_b(driver, app_servers):
    url = app_servers["frontend_url"]
    _open(driver, url, "/")
    tab_a = driver.current_window_handle
    tab_b = _open_new_tab(driver, url, "/cart")

    _switch(driver, tab_a)
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_1).click()

    _switch(driver, tab_b)
    _wait_count(driver, 1)
    items = driver.find_elements(By.CSS_SELECTOR, CART_ITEMS)
    assert len(items) == 1


def test_add_in_both_tabs_results_in_combined_count(driver, app_servers):
    url = app_servers["frontend_url"]
    _open(driver, url, "/")
    tab_a = driver.current_window_handle
    tab_b = _open_new_tab(driver, url, "/")

    _switch(driver, tab_a)
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_1).click()
    time.sleep(0.2)

    _switch(driver, tab_b)
    _wait_count(driver, 1)
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_2).click()
    time.sleep(0.2)

    _switch(driver, tab_a)
    _wait_count(driver, 2)

    _switch(driver, tab_b)
    _wait_count(driver, 2)


def test_remove_in_one_tab_updates_other(driver, app_servers):
    url = app_servers["frontend_url"]
    _open(driver, url, "/")
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_1).click()
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_2).click()
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_3).click()

    tab_a = driver.current_window_handle
    tab_b = _open_new_tab(driver, url, "/cart")
    _wait_count(driver, 3)

    items = driver.find_elements(By.CSS_SELECTOR, CART_ITEMS)
    first_remove = items[0].find_element(By.CSS_SELECTOR, "button")
    first_remove.click()

    _wait_count(driver, 2)

    _switch(driver, tab_a)
    driver.find_element(By.CSS_SELECTOR, NAV_CART).click()
    _wait_count(driver, 2)


def test_clear_cart_synchronises_across_tabs(driver, app_servers):
    url = app_servers["frontend_url"]
    _open(driver, url, "/")
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_1).click()
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_2).click()

    tab_a = driver.current_window_handle
    tab_b = _open_new_tab(driver, url, "/cart")
    _wait_count(driver, 2)

    driver.find_element(By.CSS_SELECTOR, CART_CLEAR).click()
    _wait_count(driver, 0)
    WebDriverWait(driver, 5).until(
        EC.presence_of_element_located((By.CSS_SELECTOR, CART_EMPTY))
    )

    _switch(driver, tab_a)
    driver.find_element(By.CSS_SELECTOR, NAV_CART).click()
    _wait_count(driver, 0)


def test_total_value_matches_in_all_tabs(driver, app_servers):
    url = app_servers["frontend_url"]
    _open(driver, url, "/")
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_1).click()
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_2).click()

    tab_a = driver.current_window_handle
    tab_b = _open_new_tab(driver, url, "/cart")
    _wait_count(driver, 2)
    total_b = _read_total(driver)

    _switch(driver, tab_a)
    driver.find_element(By.CSS_SELECTOR, NAV_CART).click()
    WebDriverWait(driver, 5).until(
        EC.presence_of_element_located((By.CSS_SELECTOR, CART_TOTAL))
    )
    total_a = _read_total(driver)
    assert total_a == total_b


def test_three_tabs_stay_consistent(driver, app_servers):
    url = app_servers["frontend_url"]
    _open(driver, url, "/")
    handle_a = driver.current_window_handle
    handle_b = _open_new_tab(driver, url, "/cart")
    handle_c = _open_new_tab(driver, url, "/")

    _switch(driver, handle_a)
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_1).click()

    _switch(driver, handle_c)
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_3).click()

    _switch(driver, handle_b)
    _wait_count(driver, 2, timeout=15)

    _switch(driver, handle_a)
    driver.find_element(By.CSS_SELECTOR, NAV_CART).click()
    _wait_count(driver, 2)

    _switch(driver, handle_c)
    driver.find_element(By.CSS_SELECTOR, NAV_CART).click()
    _wait_count(driver, 2)


def test_submit_in_one_tab_does_not_double_in_other(driver, app_servers):
    url = app_servers["frontend_url"]
    _open(driver, url, "/")
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_1).click()

    tab_a = driver.current_window_handle
    tab_b = _open_new_tab(driver, url, "/cart")
    _wait_count(driver, 1)
    driver.find_element(By.CSS_SELECTOR, CART_SUBMIT).click()
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.CSS_SELECTOR, CART_STATUS))
    )

    _switch(driver, tab_a)
    driver.find_element(By.CSS_SELECTOR, NAV_CART).click()
    WebDriverWait(driver, 5).until(
        EC.presence_of_element_located((By.CSS_SELECTOR, CART_COUNT))
    )
    count_a = _read_count(driver)
    _switch(driver, tab_b)
    count_b = _read_count(driver)
    assert count_a == count_b


def test_local_storage_holds_canonical_state(driver, app_servers):
    url = app_servers["frontend_url"]
    _open(driver, url, "/")
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_1).click()
    driver.find_element(By.CSS_SELECTOR, ADD_PRODUCT_2).click()

    tab_b = _open_new_tab(driver, url, "/cart")
    _wait_count(driver, 2)

    raw = driver.execute_script(
        "return window.localStorage.getItem('zadanie8.cart');"
    )
    assert raw is not None
    assert raw.count("\"name\"") == 2
