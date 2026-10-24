(() => {
  const root = document.documentElement;
  const themeButton = document.querySelector('.tema');
  const status = document.querySelector('.estado');

  const setTheme = (theme) => {
    root.setAttribute('data-theme', theme);
    themeButton.setAttribute('aria-pressed', theme === 'dark' ? 'true' : 'false');
    themeButton.setAttribute('aria-label', theme === 'dark' ? 'Cambiar al tema claro' : 'Cambiar al tema oscuro');
    themeButton.querySelector('.tema-icono').textContent = theme === 'light' ? '☾' : '☼';
  };

  let savedTheme = null;
  try { savedTheme = localStorage.getItem('heimdall-theme'); } catch (error) { savedTheme = null; }
  setTheme(savedTheme === 'light' || savedTheme === 'dark' ? savedTheme : (matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark'));

  themeButton.addEventListener('click', () => {
    const nextTheme = root.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
    setTheme(nextTheme);
    try { localStorage.setItem('heimdall-theme', nextTheme); } catch (error) { /* El cambio de tema sigue funcionando sin almacenamiento. */ }
  });

  document.querySelectorAll('.copiar').forEach((button) => {
    button.addEventListener('click', async () => {
      const code = button.parentElement.querySelector('code');
      const text = code.textContent;
      let copied = false;
      try { await navigator.clipboard.writeText(text); copied = true; } catch (error) { copied = false; }
      if (!copied) {
        const selection = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(code);
        selection.removeAllRanges();
        selection.addRange(range);
      }
      status.textContent = copied ? 'Copiado' : 'Selecciona y copia con Ctrl+C';
      window.setTimeout(() => { status.textContent = ''; }, 2000);
    });
  });
})();
