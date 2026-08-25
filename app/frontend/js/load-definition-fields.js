// Which of a load definition's settings apply follows from its block's kind, so the form is
// rendered with the ones that do not left out. The exception is a harvest block, which chooses
// between writing the record itself and writing its own fragment: the two disagree about the
// priority, and that choice can change while the form is open.
//
// The primary fragment is 0 by definition. A secondary fragment must not be 0 - at that
// priority the destination selects the primary fragment and nils every mutable field the
// payload does not carry - so switching to one moves a priority of 0 off it rather than
// leaving the form holding a number the model will refuse. A priority already chosen is left
// alone: -1 is only a starting point, not the only answer.
const SECONDARY_FRAGMENT_DEFAULT_PRIORITY = -1;

// The field is readonly rather than disabled so the 0 is still submitted. A disabled input
// sends nothing, which would leave a definition being moved off a secondary fragment stuck at
// the non-zero priority it is not allowed to keep.
const fixPriority = (priority, fixed) => {
  priority.readOnly = fixed;

  // Plain text while it is fixed, a field again as soon as it is the block's to choose.
  priority.classList.toggle("form-control-plaintext", fixed);
  priority.classList.toggle("form-control", !fixed);
};

// Blank counts as unset for the same reason 0 does: neither is a priority a secondary
// fragment can be saved with.
const needsAPriorityOfItsOwn = (priority) =>
  priority.value.trim() === "" || Number(priority.value) === 0;

export const initLoadDefinitionFields = (root) => {
  root.querySelectorAll('[data-js="load-kind"]').forEach((select) => {
    const form = select.closest("form");
    const priority = form && form.querySelector('[data-js="load-priority"]');

    if (!priority) return;

    select.addEventListener("change", () => {
      const writesPrimaryFragment = select.value === "primary_fragment";

      fixPriority(priority, writesPrimaryFragment);

      if (writesPrimaryFragment) {
        priority.value = 0;
      } else if (needsAPriorityOfItsOwn(priority)) {
        priority.value = SECONDARY_FRAGMENT_DEFAULT_PRIORITY;
      }
    });
  });
};

document.addEventListener("DOMContentLoaded", () =>
  initLoadDefinitionFields(document)
);
