import { each } from "lodash";

const toggleInlineEditable = (id) => {
  const content = document.getElementById(`${id}-content`);
  const form = document.getElementById(`${id}-form`);

  content.classList.toggle("d-none");
  form.classList.toggle("d-none");
};

const inlineEditableControls = document.getElementsByClassName(
  "js-inline-editable-control"
);

each(inlineEditableControls, (control) => {
  control.addEventListener("click", (event) => {
    toggleInlineEditable(event.target.dataset.id);
  });
});

const inlineEditableCancels = document.getElementsByClassName(
  "js-inline-editable-cancel"
);

each(inlineEditableCancels, (cancel) => {
  cancel.addEventListener("click", (event) => {
    const id = event.target.dataset.id;

    document.getElementById(`${id}-form`).reset();

    toggleInlineEditable(id);
  });
});
