import { Modal } from "bootstrap";
import editor from "../editor";
import xmlFormat from "xml-formatter";
import { Tooltip } from "bootstrap";
import { each } from "lodash";
import { bindTestForm } from "../utils/test-form";

const transformationDefinitionSettingsForms = document.getElementsByClassName(
  "js-transformation-definition-form"
);

if (transformationDefinitionSettingsForms) {
  each(transformationDefinitionSettingsForms, (form) => {
    const data = extractTransformationPreviewData(form);

    if (data) {
      displayInitialPreview(data);
      bindRecordSelectorTestEventListeners(data.id);
    }
  });
}

function extractTransformationPreviewData(form) {
  const id = form.dataset.id;

  const recordSelector = document.getElementById(
    `js-transformation-definition-record-selector-${id}`
  );

  const transformationDefinitionUpdateButton = document.getElementById(
    `js-transformation-definition-submit-button-${id}`
  );

  const tooltip = Tooltip.getInstance(
    `#js-transformation-definition-submit-button-tooltip-${id}`
  );

  const transformationDefinitionPreviewData = document.getElementById(
    `js-transformation-definition-preview-data-${id}`
  );

  if (transformationDefinitionPreviewData) {
    return {
      id,
      recordSelector,
      transformationDefinitionUpdateButton,
      tooltip,
      result: transformationDefinitionPreviewData.dataset.result,
      format: transformationDefinitionPreviewData.dataset.format,
      completed: transformationDefinitionPreviewData.dataset.completed,
    };
  }
}

function displayInitialPreview(data) {
  let { id, result, tooltip } = data;

  if (result == "") {
    displayError(id);
    tooltip.disable();
  } else {
    displayPreview(data);
  }
}

function displayPreview(data) {
  let {
    id,
    recordSelector,
    result,
    format,
    transformationDefinitionUpdateButton,
    tooltip,
    completed,
  } = data;

  try {
    if (format == "JSON" || format == "ARCHIVE_JSON") {
      result = JSON.stringify(JSON.parse(result), null, 2);
    } else if (format == "XML") {
      result = xmlFormat(result, {
        indentation: "  ",
        lineSeparator: "\n",
      });
    }
  } catch (error) {
    displayError(id);
    tooltip.disable();
    return;
  }

  editor(`#js-record-selector-result-${id}`, format, true, result);

  setupTooltip(tooltip, recordSelector, transformationDefinitionUpdateButton);
  setupModal(recordSelector, completed);
  bindRecordSelectorInput(
    recordSelector,
    transformationDefinitionUpdateButton,
    tooltip
  );
}

function setupTooltip(
  tooltip,
  recordSelector,
  transformationDefinitionUpdateButton
) {
  tooltip.disable();

  if (recordSelector.value == "") {
    transformationDefinitionUpdateButton.disabled = true;
    tooltip.enable();
  }
}

function setupModal(recordSelector, completed) {
  if (recordSelector.value == "" && completed == "true") {
    new Modal(
      document.getElementById("update-transformation-definition-modal")
    ).show();
  }
}

function bindRecordSelectorInput(
  recordSelector,
  transformationDefinitionUpdateButton,
  tooltip
) {
  recordSelector.addEventListener("input", (event) => {
    if (event.target.value == "") {
      transformationDefinitionUpdateButton.disabled = true;
      tooltip.enable();
    } else {
      transformationDefinitionUpdateButton.disabled = false;
      tooltip.disable();
    }
  });
}

function bindRecordSelectorTestEventListeners(id) {
  bindTestForm(
    "test",
    `js-test-transformation-record-selector-button-${id}`,
    `js-transformation-definition-form-${id}`,
    (response, _alertClass) => {
      let results = response.data.result;

      if (
        response.data.format == "JSON" ||
        response.data.format == "ARCHIVE_JSON"
      ) {
        results = JSON.stringify(response.data.result, null, 2);
      } else if (response.data.format == "XML") {
        results = xmlFormat(response.data.result, {
          indentation: "  ",
          lineSeparator: "\n",
        });
      }

      editor(
        `#js-record-selector-result-${id}`,
        response.data.format,
        true,
        results
      );
    },
    () => {
      displayError(id);
    }
  );
}

function displayError(id) {
  document.getElementById(
    `js-record-selector-result-${id}`
  ).innerHTML = `<p class='text-danger'>
    Something went wrong when attempting to display this document. This could mean that the provided record selector doesn't return anything or if the document is over 10 megabytes you will need to split it before it can be used in a Transformation.
  </p>`;
}
