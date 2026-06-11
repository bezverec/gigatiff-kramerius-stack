#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


HOST = os.environ.get("AUTH_SHIM_HOST", "0.0.0.0")
PORT = int(os.environ.get("AUTH_SHIM_PORT", "8080"))
REALM = os.environ.get("KEYCLOAK_REALM", "kramerius")
CLIENT_ID = os.environ.get("KEYCLOAK_CLIENT_ID", "krameriusClient")
CLIENT_SECRET = os.environ.get("KEYCLOAK_CLIENT_SECRET", "")
PUBLIC_BASE_URL = os.environ.get("KEYCLOAK_PUBLIC_BASE_URL", "http://127.0.0.1:8990").rstrip("/")
INTERNAL_BASE_URL = os.environ.get("KEYCLOAK_INTERNAL_BASE_URL", PUBLIC_BASE_URL).rstrip("/")
ALLOWED_REDIRECT_ORIGINS = {
    item.rstrip("/")
    for item in os.environ.get("AUTH_ALLOWED_REDIRECT_ORIGINS", "").split(",")
    if item.strip()
}


def realm_endpoint(base_url: str, path: str) -> str:
    return f"{base_url}/realms/{urllib.parse.quote(REALM)}/protocol/openid-connect/{path}"


def origin_of(uri: str) -> str:
    parsed = urllib.parse.urlparse(uri)
    if not parsed.scheme or not parsed.netloc:
        return ""
    return f"{parsed.scheme}://{parsed.netloc}"


def redirect_allowed(uri: str) -> bool:
    if not uri:
        return False
    if not ALLOWED_REDIRECT_ORIGINS:
        return True
    return origin_of(uri).rstrip("/") in ALLOWED_REDIRECT_ORIGINS


def token_request(params: dict[str, str]) -> tuple[int, bytes, str]:
    form = {
        "client_id": CLIENT_ID,
        **params,
    }
    if CLIENT_SECRET:
        form["client_secret"] = CLIENT_SECRET
    body = urllib.parse.urlencode(form).encode("utf-8")
    request = urllib.request.Request(
        realm_endpoint(INTERNAL_BASE_URL, "token"),
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status, response.read(), response.headers.get("Content-Type", "application/json")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read(), exc.headers.get("Content-Type", "application/json")


class AuthShimHandler(BaseHTTPRequestHandler):
    server_version = "gigatiff-auth-shim/0.1"

    def log_message(self, fmt: str, *args) -> None:
        sys.stdout.write(f"[auth-shim] {self.address_string()} {fmt % args}\n")

    def send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_token_response(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type or "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    def do_HEAD(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path.rstrip("/")
        if path in {"", "/healthz", "/auth/healthz"}:
            self.send_response(200)
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return
        if path.endswith("/auth/login"):
            self.send_response(405)
            self.send_header("Allow", "GET")
            self.end_headers()
            return
        self.send_response(404)
        self.end_headers()

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        path = parsed.path.rstrip("/")

        if path in {"", "/healthz", "/auth/healthz"}:
            self.send_json(200, {"status": "ok"})
            return

        if path.endswith("/auth/login"):
            redirect_uri = params.get("redirect_uri", [""])[0]
            if not redirect_allowed(redirect_uri):
                self.send_json(400, {"error": "invalid_redirect_uri"})
                return
            query = urllib.parse.urlencode(
                {
                    "client_id": CLIENT_ID,
                    "redirect_uri": redirect_uri,
                    "response_type": "code",
                    "scope": "openid profile email",
                }
            )
            self.send_response(302)
            self.send_header("Location", f"{realm_endpoint(PUBLIC_BASE_URL, 'auth')}?{query}")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return

        if path.endswith("/auth/logout"):
            redirect_uri = params.get("redirect_uri", [origin_of(self.headers.get("Referer", "")) or "/"])[0]
            if not redirect_allowed(redirect_uri):
                self.send_json(400, {"error": "invalid_redirect_uri"})
                return
            query = urllib.parse.urlencode(
                {
                    "client_id": CLIENT_ID,
                    "post_logout_redirect_uri": redirect_uri,
                }
            )
            self.send_response(302)
            self.send_header("Location", f"{realm_endpoint(PUBLIC_BASE_URL, 'logout')}?{query}")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return

        if path.endswith("/auth/token"):
            code = params.get("code", [""])[0]
            redirect_uri = params.get("redirect_uri", [""])[0]
            if not code or not redirect_allowed(redirect_uri):
                self.send_json(400, {"error": "invalid_authorization_code_request"})
                return
            status, body, content_type = token_request(
                {
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": redirect_uri,
                }
            )
            self.send_token_response(status, body, content_type)
            return

        self.send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        if not parsed.path.rstrip("/").endswith("/auth/token"):
            self.send_json(404, {"error": "not_found"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(length).decode("utf-8")
        incoming = urllib.parse.parse_qs(raw_body)
        params = {key: values[-1] for key, values in incoming.items() if values}
        grant_type = params.get("grant_type")

        if grant_type != "refresh_token" or not params.get("refresh_token"):
            self.send_json(400, {"error": "unsupported_grant_type"})
            return

        status, body, content_type = token_request(
            {
                "grant_type": "refresh_token",
                "refresh_token": params["refresh_token"],
            }
        )
        self.send_token_response(status, body, content_type)


if __name__ == "__main__":
    print(f"[auth-shim] listening on {HOST}:{PORT}", flush=True)
    ThreadingHTTPServer((HOST, PORT), AuthShimHandler).serve_forever()
