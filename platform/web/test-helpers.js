// Browser test helpers for the love.js build. Injected into dist/web/index.html
// by scripts/build-web.sh. These let a human (or an automated browser) drive the
// game from the devtools console without touching the real in-game UX.
//
// Why this exists: love.js/SDL detects a key press by diffing keyboard state
// between frames. A synthetic keydown+keyup fired in the same tick collapses
// before the game's update loop samples it, so taps are missed. These helpers
// HOLD the key across several frames (real time) before releasing, which is how
// SDL and the game's input layer (baton) reliably register a press.
//
// Usage from the console:
//   valya.hold('up', 600)      // fly north for 600ms
//   await valya.press('A')     // one A-button press (~150ms hold)
//   await valya.press('A', 800)// long A press
//   valya.keys                 // list of supported logical key names
(function () {
  // Logical name -> {key, code, keyCode} for KeyboardEvent. Names match the
  // device buttons and d-pad the game binds in src/platform/input.lua.
  var KEYS = {
    up: { key: "ArrowUp", code: "ArrowUp", keyCode: 38 },
    down: { key: "ArrowDown", code: "ArrowDown", keyCode: 40 },
    left: { key: "ArrowLeft", code: "ArrowLeft", keyCode: 37 },
    right: { key: "ArrowRight", code: "ArrowRight", keyCode: 39 },
    // A = interact/confirm (Enter), B = back/repeat (Backspace) — matches the
    // physical RG35XX buttons. Space/Return both map to interact in the game.
    a: { key: "Enter", code: "Enter", keyCode: 13 },
    b: { key: "Backspace", code: "Backspace", keyCode: 8 },
    start: { key: "p", code: "KeyP", keyCode: 80 },
    // Debug helpers (only act when debug mode is on).
    debug: { key: "`", code: "Backquote", keyCode: 192 },
    drift: { key: "0", code: "Digit0", keyCode: 48 },
    reset: { key: "9", code: "Digit9", keyCode: 57 },
  };

  function resolve(name) {
    var k = KEYS[String(name).toLowerCase()];
    if (!k) throw new Error("valya: unknown key '" + name + "'. Try: " + Object.keys(KEYS).join(", "));
    return k;
  }

  function dispatch(type, k) {
    // SDL's listeners live on window; dispatch there so presses register.
    window.dispatchEvent(
      new KeyboardEvent(type, {
        key: k.key,
        code: k.code,
        keyCode: k.keyCode,
        which: k.keyCode,
        bubbles: true,
        cancelable: true,
      })
    );
  }

  function wait(ms) {
    return new Promise(function (r) {
      setTimeout(r, ms);
    });
  }

  // Hold a key down for `ms`, then release. Default 150ms comfortably spans
  // several 60fps frames so the press is never missed.
  function hold(name, ms) {
    var k = resolve(name);
    dispatch("keydown", k);
    return wait(ms || 150).then(function () {
      dispatch("keyup", k);
      return name + " held " + (ms || 150) + "ms";
    });
  }

  // A single press. Alias of hold with the default short duration.
  function press(name, ms) {
    return hold(name, ms || 150);
  }

  // Fire a sequence: valya.sequence(['a', ['up', 600], 'b'])
  function sequence(steps) {
    return steps.reduce(function (p, step) {
      return p.then(function () {
        if (Array.isArray(step)) return hold(step[0], step[1]);
        return press(step);
      });
    }, Promise.resolve());
  }

  window.valya = {
    keys: Object.keys(KEYS),
    hold: hold,
    press: press,
    sequence: sequence,
  };
  console.log("[valya] test helpers ready. Try valya.hold('up', 600). Keys:", window.valya.keys.join(", "));
})();
