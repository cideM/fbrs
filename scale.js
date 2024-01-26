function f(i, f0, ratio = 1.61803398875, interval_size = 5) {
  return f0 * ratio ** (i / interval_size);
}

const n = 6; // h1, h2, h3, h4, h5, h6
// -1 = small; 0 = normal; headings...
for (let i = -1; i <= 6; i++) {
  const x = f(i, 1, 2).toFixed(2);
  console.log(`--s${i}: ${x};`);
}
