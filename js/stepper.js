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

  // Document Upload Functionality
  var uploadBtn = document.getElementById('upload-doc-btn');
  var uploadType = document.getElementById('upload-doc-type');
  var uploadFile = document.getElementById('upload-doc-file');
  var galleryContainer = document.getElementById('doc-gallery-container');

  if (uploadBtn && uploadType && uploadFile && galleryContainer) {
    uploadBtn.addEventListener('click', function () {
      var docType = uploadType.value;
      var file = uploadFile.files[0];

      if (!docType) {
        alert('يرجى اختيار نوع الوثيقة');
        return;
      }
      if (!file) {
        alert('يرجى اختيار ملف لتحميله');
        return;
      }

      var reader = new FileReader();
      reader.onload = function (e) {
        var fileData = e.target.result;
        var thumbHtml = '';

        if (file.type.startsWith('image/')) {
          thumbHtml = '<img src="' + fileData + '" alt="' + docType + '" style="width:100%;height:100%;object-fit:cover;border-radius:2px;">';
        } else {
          thumbHtml = '<svg viewBox="0 0 64 64" width="64" fill="#CCC"><rect x="12" y="8" width="40" height="48" rx="2" stroke="#CCC" stroke-width="2" fill="none"/><line x1="20" y1="20" x2="44" y2="20" stroke="#DDD" stroke-width="2"/><line x1="20" y1="28" x2="44" y2="28" stroke="#DDD" stroke-width="2"/><line x1="20" y1="36" x2="36" y2="36" stroke="#DDD" stroke-width="2"/></svg>';
        }

        var card = document.createElement('article');
        card.className = 'doc-card';
        card.innerHTML = 
          '<article class="doc-card__thumb">' + thumbHtml + '</article>' +
          '<p class="doc-card__type">' + docType + '</p>' +
          '<button type="button" class="doc-card__delete">حذف</button>';

        galleryContainer.appendChild(card);

        // Reset inputs
        uploadType.value = '';
        uploadFile.value = '';
      };
      reader.readAsDataURL(file);
    });

    // Delete delegation
    galleryContainer.addEventListener('click', function(e) {
      if (e.target.classList.contains('doc-card__delete')) {
        var card = e.target.closest('.doc-card');
        if (card) {
          card.remove();
        }
      }
    });
  }

  updateView();
})();
