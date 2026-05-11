/**
 * Multi-Step Form Controller
 * Handles stepper navigation, step visibility, validation,
 * review accordion toggling, document upload, archive search,
 * summary population, form submission to localStorage, and twin addition.
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

  var logoutBtns = document.querySelectorAll('.header__action-btn[title="\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c"]');
  logoutBtns.forEach(function (btn) {
    btn.addEventListener('click', function () {
      var confirmed = confirm('\u0647\u0644 \u062a\u0631\u064a\u062f \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c \u0645\u0646 \u0627\u0644\u0646\u0638\u0627\u0645\u061f');
      if (confirmed) {
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
        field.tagName === 'SELECT' && (field.value === '' || field.value === '-- \u0627\u062e\u062a\u0631 --');

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
      showToast('\u064a\u0631\u062c\u0649 \u0645\u0644\u0621 \u062c\u0645\u064a\u0639 \u0627\u0644\u062d\u0642\u0648\u0644 \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629 \u0642\u0628\u0644 \u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0629', 'warning');
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
    var radioGroup = e.target.closest('[data-radio-required]');
    if (radioGroup) {
      radioGroup.style.outline = '';
      radioGroup.style.outlineOffset = '';
    }
  });

  // ============================================
  // SUMMARY POPULATION
  // ============================================

  /** Radio value labels for display */
  var radioLabels = {
    'direct': '\u0645\u0628\u0627\u0634\u0631',
    'court': '\u062d\u0643\u0645 \u0645\u0646 \u0627\u0644\u0645\u062d\u0643\u0645\u0629',
    'male': '\u0630\u0643\u0631',
    'female': '\u0623\u0646\u062b\u0649',
    'm': '\u0630\u0643\u0631',
    'f': '\u0623\u0646\u062b\u0649'
  };

  /**
   * Populates all review-row values from form fields.
   * Uses data-review-field attribute to map review cells to form inputs.
   */
  function populateSummary() {
    var reviewFields = document.querySelectorAll('[data-review-field]');
    reviewFields.forEach(function (cell) {
      var fieldId = cell.getAttribute('data-review-field');
      var value = '---';

      // Check if it is a radio group name (no element with that ID, but radio inputs exist)
      var inputById = document.getElementById(fieldId);
      if (inputById) {
        // Standard input or select
        if (inputById.tagName === 'SELECT') {
          var selectedOpt = inputById.options[inputById.selectedIndex];
          value = (selectedOpt && selectedOpt.value) ? selectedOpt.text : '---';
        } else {
          value = inputById.value.trim() || '---';
        }
      } else {
        // Try as a radio group name
        var checkedRadio = document.querySelector('input[name="' + fieldId + '"]:checked');
        if (checkedRadio) {
          value = radioLabels[checkedRadio.value] || checkedRadio.value;
        }
      }

      cell.textContent = value;
    });
  }

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
      panel.hidden = (i !== currentStep);
    });

    // Update buttons
    if (btnPrev) {
      btnPrev.disabled = currentStep === 0;
    }
    if (btnNext) {
      btnNext.textContent =
        currentStep === totalSteps - 1 ? '\u062a\u0623\u0643\u064a\u062f \u0648\u0625\u0631\u0633\u0627\u0644' : '\u0627\u0644\u062a\u0627\u0644\u064a';
    }

    // Populate summary when reaching the last step
    if (currentStep === totalSteps - 1) {
      populateSummary();
    }
  }

  // ============================================
  // FORM DATA COLLECTION & SUBMISSION
  // ============================================

  /**
   * Collects all form field values into an object for localStorage persistence.
   */
  function collectFormData() {
    var data = {};
    var allInputs = document.querySelectorAll('.form-input[id], .form-select[id]');
    allInputs.forEach(function (field) {
      if (!field.disabled) {
        if (field.tagName === 'SELECT') {
          var opt = field.options[field.selectedIndex];
          data[field.id] = (opt && opt.value) ? opt.text : '';
        } else if (field.type !== 'file') {
          data[field.id] = field.value.trim();
        }
      }
    });

    // Collect radio groups
    var radioGroups = document.querySelectorAll('[data-radio-required]');
    radioGroups.forEach(function (group) {
      var name = group.getAttribute('data-radio-required');
      var checked = document.querySelector('input[name="' + name + '"]:checked');
      if (checked) {
        data[name] = radioLabels[checked.value] || checked.value;
      }
    });

    // Also collect declaration type radios
    var declTypeRadios = ['decl-type', 'dtype'];
    declTypeRadios.forEach(function (name) {
      var checked = document.querySelector('input[name="' + name + '"]:checked');
      if (checked) {
        data[name] = radioLabels[checked.value] || checked.value;
      }
    });

    return data;
  }

  /**
   * Handles final form submission: saves to localStorage and shows confirmation.
   */
  function submitForm() {
    var data = collectFormData();
    var formType = document.querySelector('input[name="decl-type"]') ? 'birth' : 'death';
    var timestamp = new Date().toISOString();
    var key = 'dilona_' + formType + '_' + Date.now();

    var record = {
      type: formType,
      timestamp: timestamp,
      data: data
    };

    try {
      localStorage.setItem(key, JSON.stringify(record));
      showToast('\u062a\u0645 \u062d\u0641\u0638 \u0627\u0644\u062a\u0635\u0631\u064a\u062d \u0628\u0646\u062c\u0627\u062d \u0628\u0631\u0642\u0645: ' + key.slice(-8), '');

      // Disable the submit button to prevent double submission
      if (btnNext) {
        btnNext.disabled = true;
        btnNext.textContent = '\u062a\u0645 \u0627\u0644\u062d\u0641\u0638';
      }
    } catch (e) {
      showToast('\u062e\u0637\u0623 \u0641\u064a \u062d\u0641\u0638 \u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a', 'warning');
    }
  }

  // ============================================
  // NAVIGATION BUTTONS
  // ============================================

  if (btnNext) {
    btnNext.addEventListener('click', function () {
      if (currentStep === totalSteps - 1) {
        // Final step: submit form data
        submitForm();
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
      var inputs = panel.querySelectorAll('.form-input, .form-select');
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
        showToast('\u064a\u0631\u062c\u0649 \u0627\u062e\u062a\u064a\u0627\u0631 \u0646\u0648\u0639 \u0627\u0644\u0648\u062b\u064a\u0642\u0629', 'warning');
        return;
      }
      if (!file) {
        showToast('\u064a\u0631\u062c\u0649 \u0627\u062e\u062a\u064a\u0627\u0631 \u0645\u0644\u0641 \u0644\u062a\u062d\u0645\u064a\u0644\u0647', 'warning');
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
          '<button type="button" class="doc-card__delete">\u062d\u0630\u0641</button>';

        galleryContainer.appendChild(card);
        showToast('\u062a\u0645 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0648\u062b\u064a\u0642\u0629 \u0628\u0646\u062c\u0627\u062d', '');

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
          showToast('\u062a\u0645 \u062d\u0630\u0641 \u0627\u0644\u0648\u062b\u064a\u0642\u0629', '');
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

      if (!office || office === '-- \u0627\u062e\u062a\u0631 --') {
        showToast('\u064a\u0631\u062c\u0649 \u0627\u062e\u062a\u064a\u0627\u0631 \u0645\u0643\u062a\u0628 \u0627\u0644\u062d\u0627\u0644\u0629 \u0627\u0644\u0645\u062f\u0646\u064a\u0629', 'warning');
        return;
      }
      if (!year || year === '--') {
        showToast('\u064a\u0631\u062c\u0649 \u0627\u062e\u062a\u064a\u0627\u0631 \u0633\u0646\u0629 \u0627\u0644\u062a\u0633\u062c\u064a\u0644', 'warning');
        return;
      }
      if (!record) {
        showToast('\u064a\u0631\u062c\u0649 \u0625\u062f\u062e\u0627\u0644 \u0631\u0642\u0645 \u0627\u0644\u0631\u0633\u0645', 'warning');
        return;
      }

      var resultsContainer = searchBlock.querySelector('.archive-results');
      if (!resultsContainer) {
        resultsContainer = document.createElement('article');
        resultsContainer.className = 'archive-results';
        searchBlock.appendChild(resultsContainer);
      }

      var officeText = officeSelect.options[officeSelect.selectedIndex].text;

      var tag = document.createElement('span');
      tag.className = 'archive-tag';
      tag.innerHTML =
        officeText + ' / ' + year + ' / \u0631\u0633\u0645 \u0631\u0642\u0645 ' + record +
        '<button type="button" class="archive-tag__remove" title="\u062d\u0630\u0641">&times;</button>';

      resultsContainer.appendChild(tag);
      showToast('\u062a\u0645\u062a \u0625\u0636\u0627\u0641\u0629 \u0645\u0631\u062c\u0639 \u0627\u0644\u0623\u0631\u0634\u064a\u0641', '');

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
  // ADD TWIN BUTTON (Birth Form Only)
  // ============================================

  var twinCount = 0;
  var MAX_TWINS = 3;

  var addTwinBtns = document.querySelectorAll('.form-step[data-step-content="3"] .btn--orange');
  addTwinBtns.forEach(function (btn) {
    // Only target the "Add Twin" button (not archive search buttons)
    if (btn.textContent.indexOf('\u0625\u0636\u0627\u0641\u0629 \u0645\u0648\u0644\u0648\u062f') === -1) return;

    btn.addEventListener('click', function () {
      twinCount++;
      if (twinCount >= MAX_TWINS) {
        showToast('\u0627\u0644\u062d\u062f \u0627\u0644\u0623\u0642\u0635\u0649 \u0644\u0644\u062a\u0648\u0627\u0626\u0645 \u0647\u0648 ' + MAX_TWINS, 'warning');
        btn.disabled = true;
        btn.style.opacity = '0.5';
        return;
      }

      var panel = btn.closest('.form-panel');
      var suffix = '_twin' + twinCount;

      var twinFieldset = document.createElement('fieldset');
      twinFieldset.className = 'form-panel';
      twinFieldset.style.marginTop = 'var(--space-md)';
      twinFieldset.setAttribute('data-twin', twinCount);

      twinFieldset.innerHTML =
        '<legend class="form-panel__legend">\u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0639\u0646 \u0627\u0644\u062a\u0648\u0623\u0645 ' + twinCount + '</legend>' +
        '<article class="form-row">' +
          '<label class="form-label" for="twin-fname' + suffix + '">\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0634\u062e\u0635\u064a</label>' +
          '<input type="text" class="form-input form-input--with-keyboard" id="twin-fname' + suffix + '" style="max-width: 300px;" required>' +
          '<span class="form-label--fr">Prenom</span>' +
        '</article>' +
        '<article class="form-row">' +
          '<label class="form-label">\u0627\u0644\u062c\u0646\u0633</label>' +
          '<article style="display: flex; gap: 24px;" data-radio-required="twin-gender' + suffix + '">' +
            '<label class="form-check"><input type="radio" name="twin-gender' + suffix + '" value="male"><span class="form-check__label">\u0630\u0643\u0631</span></label>' +
            '<label class="form-check"><input type="radio" name="twin-gender' + suffix + '" value="female"><span class="form-check__label">\u0623\u0646\u062b\u0649</span></label>' +
          '</article>' +
        '</article>' +
        '<article class="form-row">' +
          '<label class="form-label" for="twin-birthplace' + suffix + '">\u0645\u0643\u0627\u0646 \u0627\u0644\u0648\u0644\u0627\u062f\u0629</label>' +
          '<input type="text" class="form-input form-input--with-keyboard" id="twin-birthplace' + suffix + '" style="max-width: 400px;">' +
          '<span class="form-label--fr">Lieu de naissance</span>' +
        '</article>' +
        '<button type="button" class="btn btn--danger twin-remove" style="margin-top: var(--space-sm);">\u062d\u0630\u0641 \u0627\u0644\u062a\u0648\u0623\u0645</button>';

      panel.parentNode.insertBefore(twinFieldset, panel.nextSibling);
      showToast('\u062a\u0645\u062a \u0625\u0636\u0627\u0641\u0629 \u062a\u0648\u0623\u0645 \u062c\u062f\u064a\u062f', '');
    });
  });

  // Delegation for removing twin fieldsets
  document.addEventListener('click', function (e) {
    if (e.target.classList.contains('twin-remove')) {
      var fieldset = e.target.closest('.form-panel[data-twin]');
      if (fieldset) {
        fieldset.remove();
        twinCount--;
        // Re-enable the add twin button
        var addBtn = document.querySelector('.form-step[data-step-content="3"] .btn--orange');
        if (addBtn && addBtn.textContent.indexOf('\u0625\u0636\u0627\u0641\u0629 \u0645\u0648\u0644\u0648\u062f') !== -1) {
          addBtn.disabled = false;
          addBtn.style.opacity = '1';
        }
        showToast('\u062a\u0645 \u062d\u0630\u0641 \u0627\u0644\u062a\u0648\u0623\u0645', '');
      }
    }
  });

  // ============================================
  // INIT
  // ============================================

  updateView();
})();
