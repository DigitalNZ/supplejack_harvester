import { initRunBlocks } from "~/js/run-blocks";

const schedulableSelect = document.getElementById("js-schedulable-select");

if (schedulableSelect) {
  document.querySelectorAll(".accordion-button").forEach((button) => {
    button.addEventListener("click", (e) => {
      e.stopPropagation();
    });
  });

  const pipelineInput = document.getElementById("js-pipeline-id");
  const automationInput = document.getElementById("js-automation-template-id");
  const harvestDefinitionsContainer =
    document.getElementById("js-blocks-to-run");

  if (pipelineInput.value) {
    schedulableSelect.value = `pipeline_${pipelineInput.value}`;
    document.getElementById("js-pipeline-settings").classList.remove("d-none");
    fetchRunBlocks(pipelineInput.value);
  }

  if (automationInput.value) {
    document.getElementById("js-pipeline-settings").classList.add("d-none");
    schedulableSelect.value = `automation-template_${automationInput.value}`;
  }

  schedulableSelect.addEventListener("change", (event) => {
    const selectedOption = event.target.querySelector(
      `option[value="${event.target.value}"]`
    );
    const pipelineId = selectedOption.dataset.pipelineId;
    const automationTemplateId = selectedOption.dataset.automationTemplateId;

    if (pipelineId) {
      pipelineInput.value = pipelineId;
      automationInput.value = "";
      fetchRunBlocks(pipelineId);
      document
        .getElementById("js-pipeline-settings")
        .classList.remove("d-none");
    } else if (automationTemplateId) {
      automationInput.value = automationTemplateId;
      pipelineInput.value = "";
      harvestDefinitionsContainer.innerHTML = "";
      document.getElementById("js-pipeline-settings").classList.add("d-none");
    } else {
      pipelineInput.value = "";
      automationInput.value = "";
      harvestDefinitionsContainer.innerHTML = "";
    }
  });

  // Renders the same partial as the Run modal (PipelinesController#run_blocks) so a
  // schedule is configured with exactly the same layout and the same input choices.
  function fetchRunBlocks(pipelineId) {
    harvestDefinitionsContainer.innerHTML =
      '<div class="text-body-secondary">Loading blocks...</div>';

    const scheduleId = document.getElementById("js-schedule-id")?.value;
    const query = scheduleId ? `?schedule_id=${scheduleId}` : "";

    fetch(`/pipelines/${pipelineId}/run_blocks${query}`)
      .then((response) => response.text())
      .then((html) => {
        harvestDefinitionsContainer.innerHTML = html;
        initRunBlocks(harvestDefinitionsContainer);
      })
      .catch(() => {
        harvestDefinitionsContainer.innerHTML =
          '<div class="text-danger">Error loading blocks</div>';
      });
  }
}
