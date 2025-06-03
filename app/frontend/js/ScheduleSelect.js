const schedulableSelect = document.getElementById("js-schedulable-select");

if (schedulableSelect) {

  const pipelineInput = document.getElementById("js-pipeline-id");
  const automationInput = document.getElementById("js-automation-template-id");

  schedulableSelect.addEventListener("change", (event) => {
    const selectedOption = event.target.querySelector(`option[value="${event.target.value}"]`);
    const pipelineId = selectedOption.dataset.pipelineId;
    const automationTemplateId = selectedOption.dataset.automationTemplateId;

    if (pipelineId) {
      pipelineInput.value = pipelineId;
      automationInput.value = '';

      // Display the blocks to run for the pipeline

      


    } else if (automationTemplateId) {
      automationInput.value = automationTemplateId;
      pipelineInput.value = '';
    } else {
      pipelineInput.value = '';
      automationInput.value = '';
    }
  });
}