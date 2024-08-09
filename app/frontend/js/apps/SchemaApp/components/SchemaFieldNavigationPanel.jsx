import React from "react";
import { useSelector, useDispatch } from "react-redux";
import { selectAllSchemaFields } from "~/js/features/SchemaApp/SchemaFieldsSlice";
import SchemaFieldNavigationListItem from "./SchemaFieldNavigationListItem";
import AddSchemaField from "./AddSchemaField";
import Tooltip from "~/js/components/Tooltip";

import { toggleDisplaySchemaFields } from '~/js/features/SchemaApp/UiSchemaFieldsSlice';

const SchemaFieldNavigationPanel = () => {
  const dispatch = useDispatch();
  const fields = useSelector(selectAllSchemaFields);

  return (
    <div className="card field-nav-panel">
      <div className="d-flex flex-column overflow-auto">
        <div className="field-nav-panel__header field-nav-panel__header--fields">
          <Tooltip data-bs-title="Schema fields allow creating a controlled list of fields and values that can be referenced within a Transformation Definition. Updating the names or values here will affect Transformations which reference them">
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
                onClick={() => {
                  dispatch(
                    toggleDisplaySchemaFields({
                      fields: fields,
                      displayed: false,
                    })
                  );
                }}
              >
                <i className="bi bi-eye-slash me-2"></i> Hide all fields
              </li>

              <li
                className="dropdown-item card__control-acton"
                onClick={() => {
                  dispatch(
                    toggleDisplaySchemaFields({ fields: fields, displayed: true })
                  );
                }}
              >
                <i className="bi bi-eye me-2"></i> Show all fields
              </li>
            </ul>
          </div>
        </div>

        <div className="field-nav-panel__content">
          <AddSchemaField />

          <ul className="field-nav nav nav-pills flex-column overflow-auto flex-nowrap">
            {fields.map((field) => {
              return <SchemaFieldNavigationListItem id={field.id} key={field.id} />;
            })}
          </ul>
        </div>
      </div>
    </div>
  );
};

export default SchemaFieldNavigationPanel;
