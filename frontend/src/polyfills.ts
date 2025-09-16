// Polyfills for libraries expecting Node-like globals in the browser.
// Ensures compatibility with CommonJS packages that reference `global` or `process`.
(window as any).global = (window as any).global || window;
(window as any).process = (window as any).process || { env: {} };

