import TomSelect from "tom-select";

document.addEventListener("DOMContentLoaded", function () {
  const searchableSelects = document.querySelectorAll(".js-searchable-select");

  searchableSelects.forEach((select) => {
    // The blank option stays out of the list, so a prompt can't be picked as
    // a value and the browser's required check still stops an empty submit.
    // Selects where blank is a real choice mark themselves data-optional and
    // get a clear (×) button instead.
    new TomSelect(select, {
      placeholder: select.dataset.placeholder,
      plugins: "optional" in select.dataset ? ["clear_button"] : [],
    });
  });
});
