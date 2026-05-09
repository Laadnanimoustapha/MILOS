/**
 * Accordion Navigation Controller
 * Handles expand/collapse logic for the main menu categories.
 */
(function () {
  'use strict';

  const headers = document.querySelectorAll('.accordion__header');

  headers.forEach(function (header) {
    header.addEventListener('click', function () {
      const panelId = this.getAttribute('aria-controls');
      const panel = document.getElementById(panelId);
      const isExpanded = this.getAttribute('aria-expanded') === 'true';

      // Close all other panels
      headers.forEach(function (otherHeader) {
        if (otherHeader !== header) {
          otherHeader.setAttribute('aria-expanded', 'false');
          const otherPanel = document.getElementById(
            otherHeader.getAttribute('aria-controls')
          );
          if (otherPanel) {
            otherPanel.setAttribute('aria-hidden', 'true');
          }
        }
      });

      // Toggle current panel
      if (isExpanded) {
        this.setAttribute('aria-expanded', 'false');
        panel.setAttribute('aria-hidden', 'true');
      } else {
        this.setAttribute('aria-expanded', 'true');
        panel.setAttribute('aria-hidden', 'false');
      }
    });
  });

  // Active submenu link tracking
  const links = document.querySelectorAll('.submenu__link');
  links.forEach(function (link) {
    link.addEventListener('click', function () {
      links.forEach(function (l) {
        l.classList.remove('submenu__link--active');
      });
      this.classList.add('submenu__link--active');
    });
  });
})();
