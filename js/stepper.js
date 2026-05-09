/**
 * Multi-Step Form Controller
 * Handles stepper navigation, step visibility, and review accordion toggling.
 */
(function () {
  'use strict';

  var currentStep = 0;
  var steps = document.querySelectorAll('.stepper__step');
  var panels = document.querySelectorAll('.form-step');
  var btnPrev = document.getElementById('btn-prev');
  var btnNext = document.getElementById('btn-next');
  var totalSteps = steps.length;
  var siteHeader = document.querySelector('.site-header');

  if (siteHeader) {
    window.addEventListener('scroll', function () {
      if (window.scrollY > 10) {
        siteHeader.classList.add('is-scrolled');
      } else {
        siteHeader.classList.remove('is-scrolled');
      }
    });
  }

  function updateView() {
    // Update stepper indicators
    steps.forEach(function (step, i) {
      step.classList.remove(
        'stepper__step--active',
        'stepper__step--next',
        'stepper__step--inactive',
        'stepper__step--completed'
      );
      if (i < currentStep) {
        step.classList.add('stepper__step--completed');
      } else if (i === currentStep) {
        step.classList.add('stepper__step--active');
      } else if (i === currentStep + 1) {
        step.classList.add('stepper__step--next');
      } else {
        step.classList.add('stepper__step--inactive');
      }
    });

    // Show/hide form panels
    panels.forEach(function (panel, i) {
      if (i === currentStep) {
        panel.hidden = false;
      } else {
        panel.hidden = true;
      }
    });

    // Update buttons
    if (btnPrev) {
      btnPrev.disabled = currentStep === 0;
    }
    if (btnNext) {
      btnNext.textContent =
        currentStep === totalSteps - 1 ? 'تأكيد وإرسال' : 'التالي';
    }
  }

  if (btnNext) {
    btnNext.addEventListener('click', function () {
      if (currentStep < totalSteps - 1) {
        currentStep++;
        updateView();
        window.scrollTo({ top: 0, behavior: 'smooth' });
      }
    });
  }

  if (btnPrev) {
    btnPrev.addEventListener('click', function () {
      if (currentStep > 0) {
        currentStep--;
        updateView();
        window.scrollTo({ top: 0, behavior: 'smooth' });
      }
    });
  }

  // Review accordion toggle (summary step)
  document.addEventListener('click', function (e) {
    var header = e.target.closest('.review-accordion__header');
    if (!header) return;
    var accordion = header.closest('.review-accordion');
    var icon = header.querySelector('.review-accordion__icon');
    var isOpen = accordion.classList.contains('review-accordion--open');

    if (isOpen) {
      accordion.classList.remove('review-accordion--open');
      icon.textContent = '+';
    } else {
      accordion.classList.add('review-accordion--open');
      icon.textContent = '-';
    }
  });

  // Unknown entity toggle - disable fields
  var unknownToggles = document.querySelectorAll('[id^="unknown-"]');
  unknownToggles.forEach(function (toggle) {
    toggle.addEventListener('change', function () {
      var panel = this.closest('.form-panel');
      var inputs = panel.querySelectorAll(
        '.form-input, .form-select'
      );
      inputs.forEach(function (input) {
        input.disabled = toggle.checked;
        if (toggle.checked) {
          input.style.opacity = '0.4';
        } else {
          input.style.opacity = '1';
        }
      });
    });
  });

  updateView();
})();
