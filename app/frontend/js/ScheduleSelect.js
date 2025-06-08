const schedulableSelect = document.getElementById("js-schedulable-select");

if (schedulableSelect) {
  const pipelineInput = document.getElementById("js-pipeline-id");
  const automationInput = document.getElementById("js-automation-template-id");
  const harvestDefinitionsContainer = document.getElementById("js-blocks-to-run");

  if(pipelineInput.value) {
    schedulableSelect.value = `pipeline_${pipelineInput.value}`;
    fetchHarvestDefinitions(pipelineInput.value);
  }

  if(automationInput.value) {
    schedulableSelect.value = `automation-template_${automationInput.value}`;
  }

  schedulableSelect.addEventListener("change", (event) => {
    const selectedOption = event.target.querySelector(`option[value="${event.target.value}"]`);
    const pipelineId = selectedOption.dataset.pipelineId;
    const automationTemplateId = selectedOption.dataset.automationTemplateId;

    if (pipelineId) {
      pipelineInput.value = pipelineId;
      automationInput.value = '';
      fetchHarvestDefinitions(pipelineId);
    } else if (automationTemplateId) {
      automationInput.value = automationTemplateId;
      pipelineInput.value = '';
      harvestDefinitionsContainer.innerHTML = '';
    } else {
      pipelineInput.value = '';
      automationInput.value = '';
      harvestDefinitionsContainer.innerHTML = '';
    }
  });

  function fetchHarvestDefinitions(pipelineId) {
    harvestDefinitionsContainer.innerHTML = '<div class="text-muted">Loading harvest definitions...</div>';
    
    fetch(`/pipelines/${pipelineId}/harvest_definitions`)
      .then(response => response.json())
      .then(data => {
        updateHarvestDefinitionsCheckboxes(data);
      })
      .catch(() => {
        harvestDefinitionsContainer.innerHTML = '<div class="text-danger">Error loading harvest definitions</div>';
      });
  }
  
  function updateHarvestDefinitionsCheckboxes(definitions) {
    const existingBlocksToRun = document.getElementById("js-existing-blocks-to-run").value.split(' ');

    harvestDefinitionsContainer.innerHTML = '<label class="form-label" for="schedule_harvest_definitions_to_run">Blocks to run</label>';
    
    definitions.forEach(definition => {
      const div = document.createElement('div');
      div.className = 'form-check';
      
      const checkedAttribute = existingBlocksToRun.includes(String(definition.id)) ? ' checked="checked"' : '';

      div.innerHTML = `
        <input class="form-check-input" 
               type="checkbox" 
               name="schedule[harvest_definitions_to_run][]" 
               value="${definition.id}"
               ${checkedAttribute}
               id="harvest_definition_${definition.id}">
        <label class="form-check-label" for="harvest_definition_${definition.id}">
          ${definition.name}
        </label>
      `;
      
      harvestDefinitionsContainer.appendChild(div);
    });
  }
}
