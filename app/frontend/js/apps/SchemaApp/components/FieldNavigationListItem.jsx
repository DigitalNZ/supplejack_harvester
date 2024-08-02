import React from "react";
import { useDispatch, useSelector } from "react-redux";
import { selectFieldById } from "~/js/features/SchemaApp/FieldsSlice";
import {
  selectUiFieldById,
  toggleDisplayField,
  setActiveField,
} from "~/js/features/TransformationApp/UiFieldsSlice";
import classNames from "classnames";

const FieldNavigationListItem = ({ id }) => {
  const dispatch = useDispatch();
  const { name } = useSelector((state) => selectFieldById(state, id));
  const { displayed } = useSelector((state) =>
    selectUiFieldById(state, id)
  );

  const linkClasses = classNames("nav-link", "text-truncate");

  const handleListItemClick = () => {
    const desiredDisplaySetting = !displayed;

    dispatch(toggleDisplayField({ id: id, displayed: desiredDisplaySetting }));

    if (desiredDisplaySetting == true) {
      dispatch(setActiveField(id));
    }
  };

  return (
    <li className="nav-item">
      <a
        className={linkClasses}
        data-bs-toggle="collapse"
        onClick={() => handleListItemClick()}
        href={`#field-${id}`}
        role="button"
        aria-expanded={displayed}
        aria-controls={`field-${id}`}
      >
        {name || `New field`}{" "}
      </a>
    </li>
  );
};

export default FieldNavigationListItem;
