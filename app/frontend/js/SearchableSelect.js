import TomSelect from "tom-select";

document.addEventListener("DOMContentLoaded", function () {
  const searchableSelects = document.querySelectorAll(".js-searchable-select");

  searchableSelects.forEach((select) => {
    // The blank option stays out of the list, so the prompt can't be picked
    // and the browser's required check still stops an empty submit. The
    // placeholder disappears as soon as you type.
    new TomSelect(select, { placeholder: select.dataset.placeholder });
  });
});
