/**
 * Multi-Step Form Controller
 * Handles stepper navigation, step visibility, validation,
 * review accordion toggling, document upload, and archive search.
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

  // ============================================
  // HEADER SCROLL EFFECT
  // ============================================

  if (siteHeader) {
    window.addEventListener('scroll', function () {
      if (window.scrollY > 10) {
        siteHeader.classList.add('is-scrolled');
      } else {
        siteHeader.classList.remove('is-scrolled');
      }
    });
  }

  // ============================================
  // TOAST NOTIFICATION SYSTEM
  // ============================================

  var toastElement = null;
  var toastTimeout = null;

  function showToast(message, type) {
    if (toastElement) {
      toastElement.remove();
    }
    clearTimeout(toastTimeout);

    toastElement = document.createElement('aside');
    toastElement.className = 'system-toast';
    toastElement.setAttribute('role', 'status');
    toastElement.setAttribute('aria-live', 'polite');
    if (type === 'warning') {
      toastElement.classList.add('system-toast--warning');
    }
    toastElement.textContent = message;
    document.body.appendChild(toastElement);

    // Trigger reflow then show
    void toastElement.offsetWidth;
    toastElement.classList.add('system-toast--visible');

    toastTimeout = setTimeout(function () {
      toastElement.classList.remove('system-toast--visible');
      setTimeout(function () {
        if (toastElement) {
          toastElement.remove();
          toastElement = null;
        }
      }, 250);
    }, 3000);
  }

  // ============================================
  // LOGOUT BUTTON
  // ============================================

  var logoutBtns = document.querySelectorAll('.header__action-btn[title="تسجيل الخروج"]');
  logoutBtns.forEach(function (btn) {
    btn.addEventListener('click', function () {
      var confirmed = confirm('هل تريد تسجيل الخروج من النظام؟');
      if (confirmed) {
        // Navigate to the main page (acts as session end for a static site)
        var isInForms = window.location.pathname.indexOf('/forms/') !== -1;
        window.location.href = isInForms ? '../index.html' : 'index.html';
      }
    });
  });

  // ============================================
  // STEP VALIDATION
  // ============================================

  /**
   * Validates all required inputs/selects within the current step panel.
   * Returns true if all pass, false otherwise.
   * Adds visual error indicators to invalid fields.
   */
  function validateCurrentStep() {
    var currentPanel = panels[currentStep];
    if (!currentPanel) return true;

    // Summary step never needs validation
    if (currentStep === totalSteps - 1) return true;

    var fields = currentPanel.querySelectorAll(
      '.form-input[required], .form-select[required]'
    );

    // If no required fields exist in this step, allow navigation
    if (fields.length === 0) return true;

    var isValid = true;
    var firstInvalid = null;

    fields.forEach(function (field) {
      // Clear previous error state
      field.classList.remove('form-input--error', 'form-select--error');

      var isEmpty = !field.value || field.value.trim() === '';
      var isDefaultSelect =
        field.tagName === 'SELECT' && (field.value === '' || field.value === '-- اختر --');

      // Skip disabled fields (e.g. when "unknown" checkbox is active)
      if (field.disabled) return;

      if (isEmpty || isDefaultSelect) {
        var errorClass = field.tagName === 'SELECT' ? 'form-select--error' : 'form-input--error';
        field.classList.add(errorClass);
        isValid = false;
        if (!firstInvalid) {
          firstInvalid = field;
        }
      }
    });

    // Also validate radio groups marked as required
    var radioGroups = currentPanel.querySelectorAll('[data-radio-required]');
    radioGroups.forEach(function (group) {
      var groupName = group.getAttribute('data-radio-required');
      var checked = currentPanel.querySelector('input[name="' + groupName + '"]:checked');
      if (!checked) {
        isValid = false;
        group.style.outline = '2px solid #C0392B';
        group.style.outlineOffset = '4px';
        group.style.borderRadius = '2px';
        if (!firstInvalid) {
          firstInvalid = group;
        }
      } else {
        group.style.outline = '';
        group.style.outlineOffset = '';
      }
    });

    if (!isValid) {
      showToast('يرجى ملء جميع الحقول المطلوبة قبل المتابعة', 'warning');
      if (firstInvalid) {
        firstInvalid.focus();
      }
    }

    return isValid;
  }

  // Clear error state on user input
  document.addEventListener('input', function (e) {
    if (e.target.classList.contains('form-input--error')) {
      e.target.classList.remove('form-input--error');
    }
  });

  document.addEventListener('change', function (e) {
    if (e.target.classList.contains('form-select--error')) {
      e.target.classList.remove('form-select--error');
    }
    if (e.target.classList.contains('form-input--error')) {
      e.target.classList.remove('form-input--error');
    }
    // Clear radio group outline
    var radioGroup = e.target.closest('[data-radio-required]');
    if (radioGroup) {
      radioGroup.style.outline = '';
      radioGroup.style.outlineOffset = '';
    }
  });

  // ============================================
  // STEP VIEW UPDATE
  // ============================================

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

  // ============================================
  // NAVIGATION BUTTONS
  // ============================================

  if (btnNext) {
    btnNext.addEventListener('click', function () {
      if (currentStep === totalSteps - 1) {
        // Final step: confirm submission
        showToast('تم حفظ التصريح بنجاح', '');
        return;
      }
      // Validate before advancing
      if (!validateCurrentStep()) return;

      currentStep++;
      updateView();
      window.scrollTo({ top: 0, behavior: 'smooth' });
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

  // ============================================
  // REVIEW ACCORDION TOGGLE (SUMMARY STEP)
  // ============================================

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

  // ============================================
  // UNKNOWN ENTITY TOGGLE
  // ============================================

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
          input.classList.remove('form-input--error', 'form-select--error');
        } else {
          input.style.opacity = '1';
        }
      });
    });
  });

  // ============================================
  // DOCUMENT UPLOAD
  // ============================================

  var uploadBtn = document.getElementById('upload-doc-btn');
  var uploadType = document.getElementById('upload-doc-type');
  var uploadFile = document.getElementById('upload-doc-file');
  var galleryContainer = document.getElementById('doc-gallery-container');

  if (uploadBtn && uploadType && uploadFile && galleryContainer) {
    uploadBtn.addEventListener('click', function () {
      var docType = uploadType.value;
      var file = uploadFile.files[0];

      if (!docType) {
        showToast('يرجى اختيار نوع الوثيقة', 'warning');
        return;
      }
      if (!file) {
        showToast('يرجى اختيار ملف لتحميله', 'warning');
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
        showToast('تم تحميل الوثيقة بنجاح', '');

        // Reset inputs
        uploadType.value = '';
        uploadFile.value = '';
      };
      reader.readAsDataURL(file);
    });

    // Delete delegation
    galleryContainer.addEventListener('click', function (e) {
      if (e.target.classList.contains('doc-card__delete')) {
        var card = e.target.closest('.doc-card');
        if (card) {
          card.remove();
          showToast('تم حذف الوثيقة', '');
        }
      }
    });
  }

  // ============================================
  // ARCHIVE SEARCH - ADD BUTTON LOGIC
  // ============================================

  var archiveAddBtns = document.querySelectorAll('.archive-search .btn--orange');
  archiveAddBtns.forEach(function (btn) {
    btn.addEventListener('click', function () {
      var searchBlock = this.closest('.archive-search');
      var officeSelect = searchBlock.querySelector('.archive-search__field:nth-child(1) .form-select');
      var yearSelect = searchBlock.querySelector('.archive-search__field:nth-child(2) .form-select');
      var recordInput = searchBlock.querySelector('.archive-search__field:nth-child(3) .form-input');

      var office = officeSelect ? officeSelect.value : '';
      var year = yearSelect ? yearSelect.value : '';
      var record = recordInput ? recordInput.value.trim() : '';

      // Validate all three fields
      if (!office || office === '-- اختر --') {
        showToast('يرجى اختيار مكتب الحالة المدنية', 'warning');
        return;
      }
      if (!year || year === '--') {
        showToast('يرجى اختيار سنة التسجيل', 'warning');
        return;
      }
      if (!record) {
        showToast('يرجى إدخال رقم الرسم', 'warning');
        return;
      }

      // Create or find results container
      var resultsContainer = searchBlock.querySelector('.archive-results');
      if (!resultsContainer) {
        resultsContainer = document.createElement('article');
        resultsContainer.className = 'archive-results';
        searchBlock.appendChild(resultsContainer);
      }

      // Build display text from the selected option text (not value)
      var officeText = officeSelect.options[officeSelect.selectedIndex].text;

      var tag = document.createElement('span');
      tag.className = 'archive-tag';
      tag.innerHTML =
        officeText + ' / ' + year + ' / رسم رقم ' + record +
        '<button type="button" class="archive-tag__remove" title="حذف">&times;</button>';

      resultsContainer.appendChild(tag);
      showToast('تمت إضافة مرجع الأرشيف', '');

      // Reset fields
      officeSelect.selectedIndex = 0;
      yearSelect.selectedIndex = 0;
      if (recordInput) recordInput.value = '';
    });
  });

  // Delegation for removing archive tags
  document.addEventListener('click', function (e) {
    if (e.target.classList.contains('archive-tag__remove')) {
      var tag = e.target.closest('.archive-tag');
      if (tag) {
        tag.remove();
      }
    }
  });

  // ============================================
  // INIT
  // ============================================

  updateView();
})();
