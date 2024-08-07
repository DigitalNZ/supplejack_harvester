import React from "react";
import { useSelector } from "react-redux";
import { selectAllSchemaFields } from "~/js/features/SchemaApp/SchemaFieldsSlice";
import FieldNavigationListItem from "./FieldNavigationListItem";
import AddField from "~/js/apps/SchemaApp/components/AddSchemaField";
import Tooltip from "~/js/components/Tooltip";

const FieldNavigationPanel = () => {
  const fields = useSelector(selectAllSchemaFields);

  return (
    <div className="card field-nav-panel">
      <div className="d-flex flex-column overflow-auto">
        <div className="field-nav-panel__header field-nav-panel__header--fields">
          <Tooltip data-bs-title="PLACEHOLDER">
            <h5>Schema fields</h5>
          </Tooltip>

          <div className="btn-group card__control">
            <i
              className="bi bi-three-dots-vertical"
              data-bs-toggle="dropdown"
            ></i>
            <ul className="dropdown-menu dropdown-menu-end">
              <li
                className="dropdown-item card__control-acton"
              >
                <i className="bi bi-eye-slash me-2"></i> Hide all fields
              </li>

              <li
                className="dropdown-item card__control-acton"
              >
                <i className="bi bi-eye me-2"></i> Show all fields
              </li>
            </ul>
          </div>
        </div>

        <div className="field-nav-panel__content">
          <AddField />

          <ul className="field-nav nav nav-pills flex-column overflow-auto flex-nowrap">
            {fields.map((field) => {
              return <FieldNavigationListItem id={field.id} key={field.id} />;
            })}
          </ul>
        </div>
      </div>
    </div>
  );
};

export default FieldNavigationPanel;
