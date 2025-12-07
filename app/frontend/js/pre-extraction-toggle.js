document.addEventListener("DOMContentLoaded", function () {
  const preExtractionToggle = document.getElementById("js-pre-extraction-toggle");
  const preExtractionDepthField = document.querySelector('input[name="extraction_definition[pre_extraction_depth]"]');
  const linkSelectorsContainer = document.getElementById("js-link-selectors-container");

  if (preExtractionToggle && linkSelectorsContainer) {
    function createLinkSelectorField(level, existingValue) {
      const value = existingValue || '';
      const placeholder = level === 1 ? '$.urls[*] or //body//a[href]' : `Level ${level} selector`;
      
      return `
        <div class="col-4 js-link-selector-level js-link-selector-level-${level}">
          <label class="form-label" for="js-link-selector-${level}">
            Link Selector Level ${level}
            <span data-bs-toggle="tooltip" data-bs-title="JSONPath (starts with $) or XPath (starts with / or //) selector to extract links.">
              <i class="bi bi-question-circle" aria-label="helper text"></i>
            </span>
          </label>
        </div>
        <div class="col-8 js-link-selector-level js-link-selector-level-${level}">
          <input type="text" 
                 name="extraction_definition[link_selector_${level}]" 
                 id="js-link-selector-${level}"
                 class="form-control" 
                 value="${value}"
                 placeholder="${placeholder}">
          <small class="form-text text-muted">
            JSONPath (JSON) or XPath (HTML/XML). Leave blank for default.
          </small>
        </div>
      `;
    }

    function updateLinkSelectorFields() {
      const isPreExtraction = preExtractionToggle.value === "true";
      const depth = parseInt(preExtractionDepthField?.value || 1, 10) || 1;

      if (isPreExtraction) {
        linkSelectorsContainer.classList.remove("d-none");
        
        // Store existing values before clearing
        const existingValues = {};
        for (let i = 1; i <= 10; i++) {
          const input = document.getElementById(`js-link-selector-${i}`);
          if (input) {
            existingValues[i] = input.value;
          }
        }
        
        // Clear and rebuild fields
        linkSelectorsContainer.innerHTML = '';
        for (let i = 1; i <= depth; i++) {
          linkSelectorsContainer.innerHTML += createLinkSelectorField(i, existingValues[i]);
        }
        
        // Re-initialize tooltips if using Bootstrap
        const tooltips = linkSelectorsContainer.querySelectorAll('[data-bs-toggle="tooltip"]');
        tooltips.forEach(el => new bootstrap.Tooltip(el));
      } else {
        linkSelectorsContainer.classList.add("d-none");
      }
    }

    preExtractionToggle.addEventListener("change", updateLinkSelectorFields);
    if (preExtractionDepthField) {
      preExtractionDepthField.addEventListener("change", updateLinkSelectorFields);
      preExtractionDepthField.addEventListener("input", updateLinkSelectorFields);
    }
    // Don't run on page load - let the server-rendered fields stay
  }
});

