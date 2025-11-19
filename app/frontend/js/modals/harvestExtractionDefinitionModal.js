import { each } from "lodash";

const updateExtractionDefinitionModal = document.getElementById(
  "update-extraction-definition-modal"
);

const createExtractionDefinitionModal = document.getElementById(
  "create-harvest-extraction-definition-modal"
);

if (updateExtractionDefinitionModal || createExtractionDefinitionModal) {
  const extractionDefinitionFormat = document.getElementById(
    "js-extraction-definition-format"
  );
  const splitDropdown = document.getElementById(
    "js-extraction-definition-split-dropdown"
  );

  if (extractionDefinitionFormat != null) {
    extractionDefinitionFormat.addEventListener("change", (event) => {
      toggleSplitElements(event.target.value);
      toggleEvaluateJavascriptElements(event.target.value);
    });

    toggleEvaluateJavascriptElements(extractionDefinitionFormat.value);
  }

  if (splitDropdown != null) {
    toggleSplitElements(extractionDefinitionFormat.value);

    splitDropdown.addEventListener("change", () => {
      toggleSplitElements(extractionDefinitionFormat.value);
    });
  }

  // Handle link extraction checkbox
  const linkExtractionEnabled = document.getElementById(
    "js-link-extraction-enabled"
  );

  if (linkExtractionEnabled != null) {
    linkExtractionEnabled.addEventListener("change", (event) => {
      toggleLinkExtractionElements(event.target.checked);
    });

    // Initialize visibility on page load
    toggleLinkExtractionElements(linkExtractionEnabled.checked);
  }

  function toggleEvaluateJavascriptElements(format) {
    const evaluateJavascriptElements =
      document.getElementsByClassName("js-evaluate-js");

    if (format == "HTML") {
      each(evaluateJavascriptElements, (container) => {
        container.classList.remove("d-none");
      });
    } else {
      each(evaluateJavascriptElements, (element) => {
        element.classList.add("d-none");
      });
    }
  }

  // This hides and shows elements to do with splitting a document on the ExtractionDefinition modal.

  function toggleSplitElements(format) {
    const elements = document.getElementsByClassName("js-split");
    const splitDropdownContainers = document.getElementsByClassName(
      "js-extraction-definition-split-dropdown-container"
    );
    const splitSelectorContainers = document.getElementsByClassName(
      "js-extraction-definition-split-selector-container"
    );
    const splitSelector = document.getElementById(
      "js-extraction-definition-split-selector"
    );

    if (format == "XML") {
      each(splitDropdownContainers, (container) => {
        container.classList.remove("d-none");
      });

      if (splitDropdown.value == "true") {
        each(splitSelectorContainers, (container) => {
          container.classList.remove("d-none");
        });
      } else {
        each(splitSelectorContainers, (container) => {
          container.classList.add("d-none");
          splitSelector.value = "";
        });
      }
    } else {
      each(elements, (element) => {
        element.classList.add("d-none");
      });

      splitDropdown.value = "false";
      splitSelector.value = "";
    }
  }

  function toggleLinkExtractionElements(enabled) {
    const linkExtractionFields = document.getElementsByClassName(
      "js-link-extraction-fields"
    );
    const baseUrlField = document.getElementById("js-base-url");

    if (enabled) {
      each(linkExtractionFields, (element) => {
        element.classList.remove("d-none");
      });
      // Make base_url optional when link extraction is enabled
      if (baseUrlField != null) {
        baseUrlField.removeAttribute("required");
      }
    } else {
      each(linkExtractionFields, (element) => {
        element.classList.add("d-none");
      });
      // Make base_url required when link extraction is disabled
      if (baseUrlField != null) {
        baseUrlField.setAttribute("required", "required");
      }
    }
  }
}
