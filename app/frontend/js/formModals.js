// Open the create Modal on error so the user can see the validation issues
// and correct them without having to open the modal again.

import { Modal } from "bootstrap";

const createModal = document.getElementById("create-modal");

if (createModal) {
  const alert = document.getElementsByClassName("is-invalid");

  if (alert[0]) {
    new Modal(document.getElementById("create-modal")).show();
  }
}

const addHarvestModal = document.getElementById("add-harvest");

if(addHarvestModal) {
  const addHarvestAlert = addHarvestModal.getElementsByClassName('is-invalid');

  if (addHarvestAlert[0]) {
    new Modal(document.getElementById("add-harvest")).show();
  }
}