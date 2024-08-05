import React from "react";
import { useDispatch, useSelector } from "react-redux";
import { selectSchemaFieldById } from "~/js/features/SchemaApp/SchemaFieldsSlice";
import {
  selectUiSchemaFieldById,
  toggleDisplaySchemaField,
  setActiveSchemaField,
} from "~/js/features/SchemaApp/UiSchemaFieldsSlice";
import classNames from "classnames";

const FieldNavigationListItem = ({ id }) => {
  const dispatch = useDispatch();
  const { name } = useSelector((state) => selectSchemaFieldById(state, id));
  const { displayed } = useSelector((state) =>
    selectUiSchemaFieldById(state, id)
  );

  const linkClasses = classNames("nav-link", "text-truncate");

  const handleListItemClick = () => {
    const desiredDisplaySetting = !displayed;

    dispatch(toggleDisplaySchemaField({ id: id, displayed: desiredDisplaySetting }));

    if (desiredDisplaySetting == true) {
      dispatch(setActiveSchemaField(id));
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
