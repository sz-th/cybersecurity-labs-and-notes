from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

import pytest
import requests
from selenium import webdriver
from selenium.webdriver.chrome.options import Options as ChromeOptions

REPO_ROOT = Path(__file__).resolve().parents[2]
APP_DIR = REPO_ROOT / "app"
BACKEND_DIR = APP_DIR / "backend"
FRONTEND_DIR = APP_DIR / "frontend"

BACKEND_PORT = int(os.environ.get("BACKEND_PORT", "8088"))
FRONTEND_PORT = int(os.environ.get("FRONTEND_PORT", "5174"))
BACKEND_URL = os.environ.get("BACKEND_URL", f"http://127.0.0.1:{BACKEND_PORT}")
FRONTEND_URL = os.environ.get("FRONTEND_URL", f"http://127.0.0.1:{FRONTEND_PORT}")


def _is_port_open(host: str, port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(0.4)
        try:
            sock.connect((host, port))
            return True
        except OSError:
            return False


def _backend_ready(url: str) -> bool:
    try:
        resp = requests.get(url + "/api/products", timeout=2)
        if resp.status_code != 200:
            return False
        data = resp.json()
        return isinstance(data, list) and len(data) > 0
    except (requests.RequestException, json.JSONDecodeError, ValueError):
        return False


def _wait_for_backend(url: str, timeout: float = 60.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if _backend_ready(url):
            return
        time.sleep(0.5)
    raise RuntimeError(f"timeout waiting for backend at {url}")


def _wait_for_url(url: str, timeout: float = 60.0) -> None:
    deadline = time.time() + timeout
    last_error: Exception | None = None
    while time.time() < deadline:
        try:
            resp = requests.get(url, timeout=2)
            if resp.status_code < 500:
                return
        except requests.RequestException as exc:
            last_error = exc
        time.sleep(0.5)
    raise RuntimeError(f"timeout waiting for {url}: {last_error}")


@pytest.fixture(scope="session")
def app_servers():
    procs: list[subprocess.Popen] = []
    started_backend = False
    started_frontend = False

    backend_host = urlparse(BACKEND_URL).hostname or "127.0.0.1"
    frontend_host = urlparse(FRONTEND_URL).hostname or "127.0.0.1"

    if not _backend_ready(BACKEND_URL):
        env = os.environ.copy()
        env["PORT"] = str(BACKEND_PORT)
        backend_proc = subprocess.Popen(
            ["go", "run", "."],
            cwd=str(BACKEND_DIR),
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=(
                subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
            ),
        )
        procs.append(backend_proc)
        started_backend = True

    if not _is_port_open(frontend_host, FRONTEND_PORT):
        npm_cmd = "npm.cmd" if os.name == "nt" else "npm"
        env = os.environ.copy()
        env["VITE_API_BASE_URL"] = BACKEND_URL
        frontend_proc = subprocess.Popen(
            [
                npm_cmd,
                "run",
                "dev",
                "--",
                "--host",
                frontend_host,
                "--port",
                str(FRONTEND_PORT),
            ],
            cwd=str(FRONTEND_DIR),
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=(
                subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
            ),
        )
        procs.append(frontend_proc)
        started_frontend = True

    try:
        _wait_for_backend(BACKEND_URL, timeout=60)
        _wait_for_url(FRONTEND_URL, timeout=60)
    except Exception:
        for proc in procs:
            proc.terminate()
        raise

    yield {
        "frontend_url": FRONTEND_URL,
        "backend_url": BACKEND_URL,
        "started_backend": started_backend,
        "started_frontend": started_frontend,
    }

    for proc in procs:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()


def _build_options(headless: bool) -> ChromeOptions:
    options = ChromeOptions()
    if headless:
        options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--window-size=1280,900")
    options.add_argument("--disable-dev-shm-usage")
    return options


@pytest.fixture
def driver(app_servers):
    headless = os.environ.get("HEADLESS", "1") != "0"
    options = _build_options(headless)
    drv = webdriver.Chrome(options=options)
    drv.set_page_load_timeout(30)
    try:
        yield drv
    finally:
        drv.quit()


@pytest.fixture
def make_driver(app_servers):
    drivers: list[webdriver.Chrome] = []

    def factory():
        headless = os.environ.get("HEADLESS", "1") != "0"
        options = _build_options(headless)
        drv = webdriver.Chrome(options=options)
        drv.set_page_load_timeout(30)
        drivers.append(drv)
        return drv

    yield factory

    for drv in drivers:
        try:
            drv.quit()
        except Exception:
            pass


@pytest.fixture(autouse=True)
def _print_test_separator(request):
    sys.stdout.write(f"\n--- {request.node.nodeid} ---\n")
    yield
