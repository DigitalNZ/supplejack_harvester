// Which of a load definition's settings apply follows from its block's kind, so the form is
// rendered with the ones that do not left out. The exception is a harvest block, which chooses
// between writing the record itself and writing its own fragment: only the first fixes the
// priority at 0, and that choice can change while the form is open.
//
// The field is readonly rather than disabled so the 0 is still submitted. A disabled input
// sends nothing, which would leave a definition being moved off a secondary fragment stuck at
// the non-zero priority it is not allowed to keep.
document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll('[data-js="load-kind"]').forEach(function (select) {
    const form = select.closest("form");
    const priority = form && form.querySelector('[data-js="load-priority"]');

    if (!priority) return;

    select.addEventListener("change", function () {
      const writesPrimaryFragment = select.value === "primary_fragment";

      priority.readOnly = writesPrimaryFragment;

      // Plain text while it is fixed, a field again as soon as it is the block's to choose.
      priority.classList.toggle(
        "form-control-plaintext",
        writesPrimaryFragment
      );
      priority.classList.toggle("form-control", !writesPrimaryFragment);

      if (writesPrimaryFragment) priority.value = 0;
    });
  });
});
