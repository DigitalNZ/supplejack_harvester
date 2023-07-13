import { Modal } from "bootstrap"


const createModal = document.getElementById('create-modal');

if(createModal) {
  const alert = document.getElementsByClassName('is-invalid');

  if(alert[0]) {
    new Modal(document.getElementById('create-modal')).show();
  }
}
