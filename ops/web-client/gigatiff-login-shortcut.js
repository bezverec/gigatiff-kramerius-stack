(function () {
  "use strict";

  var buttonId = "gigatiff-login-shortcut";
  var loginText = "Přihlásit se";
  var authRoute = "/auth/callback";

  function hasValidStoredToken() {
    try {
      var raw = localStorage.getItem("auth_tokens");
      if (!raw) return false;
      var tokens = JSON.parse(raw);
      return tokens && tokens.expiresAt && Date.now() < Number(tokens.expiresAt);
    } catch (error) {
      return false;
    }
  }

  function nativeLoginVisible() {
    var nodes = document.querySelectorAll("a,button,[role='button']");
    for (var index = 0; index < nodes.length; index += 1) {
      var node = nodes[index];
      if (node.id === buttonId) continue;

      var text = (node.textContent || "").trim().toLowerCase();
      if (text !== "přihlásit se" && text !== "prihlasit se" && text !== "login") continue;

      var style = window.getComputedStyle(node);
      var rect = node.getBoundingClientRect();
      var visible =
        style.display !== "none" &&
        style.visibility !== "hidden" &&
        rect.width > 0 &&
        rect.height > 0 &&
        rect.bottom >= 0 &&
        rect.right >= 0 &&
        rect.top <= window.innerHeight &&
        rect.left <= window.innerWidth;
      if (visible) return true;
    }
    return false;
  }

  function ensureButton() {
    var existing = document.getElementById(buttonId);
    if (hasValidStoredToken() || nativeLoginVisible()) {
      if (existing) existing.remove();
      return;
    }
    if (existing) return;

    var button = document.createElement("button");
    button.id = buttonId;
    button.type = "button";
    button.textContent = loginText;
    button.setAttribute("aria-label", loginText);
    button.addEventListener("click", function () {
      var returnRoute = window.location.pathname + window.location.search + window.location.hash;
      if (window.location.pathname !== "/pages/terms") {
        window.location.href = "/pages/terms?returnUrl=" + encodeURIComponent(returnRoute || "/");
        return;
      }

      try {
        var params = new URLSearchParams(window.location.search);
        localStorage.setItem("auth_original_route", JSON.stringify(params.get("returnUrl") || "/"));
      } catch (error) {
        console.warn("GigaTIFF login shortcut could not store return route", error);
      }
      var redirectUri = window.location.origin + authRoute;
      window.location.href = "/auth/login?redirect_uri=" + encodeURIComponent(redirectUri);
    });
    document.body.appendChild(button);
  }

  function start() {
    ensureButton();
    var observer = new MutationObserver(function () {
      window.requestAnimationFrame(ensureButton);
    });
    observer.observe(document.body, { childList: true, subtree: true });
    window.setInterval(ensureButton, 3000);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
