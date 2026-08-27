import TomSelect from "tom-select";

document.addEventListener("DOMContentLoaded", function () {
  const searchableSelects = document.querySelectorAll(".js-searchable-select");

  searchableSelects.forEach((select) => {
    // allowEmptyOption keeps the include_blank prompt selectable, so the
    // browser's required check still stops an empty submit.
    new TomSelect(select, { allowEmptyOption: true });
  });
});
