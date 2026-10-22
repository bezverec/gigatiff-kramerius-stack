const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const source = fs.readFileSync(
  path.join(__dirname, "../../ops/web-client/gigatiff-login-shortcut.js"), "utf8"
);

function renderShortcut(text, visible = true, validToken = false) {
  const buttons = [];
  const native = {
    textContent: text,
    getBoundingClientRect: () => ({ width: visible ? 100 : 0, height: 30,
      top: 0, left: 0, right: 100, bottom: 30 })
  };
  vm.runInNewContext(source, {
    document: {
      readyState: "complete",
      body: { appendChild: button => buttons.push(button) },
      querySelectorAll: () => text ? [native] : [],
      getElementById: () => null,
      createElement: () => ({ setAttribute() {}, addEventListener() {} })
    },
    localStorage: { getItem: () => validToken
      ? JSON.stringify({ expiresAt: Date.now() + 60000 }) : null },
    window: {
      innerWidth: 1280, innerHeight: 720,
      getComputedStyle: () => ({ display: "block", visibility: "visible" }),
      setInterval() {}, requestAnimationFrame() {}
    },
    MutationObserver: class { observe() {} }
  });
  return buttons;
}

for (const label of ["Log in", "Sign in", "Login", "P\u0159ihl\u00e1sit se", " Log\n in "]) {
  test(`no duplicate shortcut alongside native ${JSON.stringify(label)}`, () => {
    assert.equal(renderShortcut(label).length, 0);
  });
}

test("fallback remains available without a visible native login", () => {
  assert.equal(renderShortcut("").length, 1);
  assert.equal(renderShortcut("Log in", false).length, 1);
});

test("valid local session suppresses the fallback", () => {
  assert.equal(renderShortcut("", true, true).length, 0);
});
