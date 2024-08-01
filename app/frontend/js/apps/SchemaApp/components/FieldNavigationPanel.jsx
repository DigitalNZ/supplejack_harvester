import React from "react";
import { useSelector, useDispatch } from "react-redux";
// import { selectAllFields } from "~/js/features/TransformationApp/FieldsSlice";
// import { filter } from "lodash";
// import FieldNavigationListItem from "./FieldNavigationListItem";
import AddField from "~/js/apps/SchemaApp/components/AddField";
// import { toggleDisplayFields } from "~/js/features/TransformationApp/UiFieldsSlice";
import Tooltip from "~/js/components/Tooltip";

const FieldNavigationPanel = () => {
  // const dispatch = useDispatch();
  // const allFields = useSelector(selectAllFields);

  // const fields = filter(allFields, ["kind", "field"]);
  // const conditions = filter(allFields, ["kind", "reject_if"]).concat(
  //   filter(allFields, ["kind", "delete_if"])
  // );

  return (
    <div className="card field-nav-panel">
      <div className="d-flex flex-column overflow-auto">
        <div className="field-nav-panel__header field-nav-panel__header--fields">
          <Tooltip data-bs-title="PLACEHOLDER">
            <h5>Fields</h5>
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
                  // dispatch(
                  //   toggleDisplayFields({ fields: fields, displayed: false })
                  // );
                }}
              >
                <i className="bi bi-eye-slash me-2"></i> Hide all fields
              </li>

              <li
                className="dropdown-item card__control-acton"
                onClick={() => {
                  // dispatch(
                  //   toggleDisplayFields({ fields: fields, displayed: true })
                  // );
                }}
              >
                <i className="bi bi-eye me-2"></i> Show all fields
              </li>
            </ul>
          </div>
        </div>

        <div className="field-nav-panel__content">
          <AddField />

          <ul className="field-nav nav nav-pills flex-column overflow-auto flex-nowrap">

          </ul>
        </div>
      </div>
    </div>
  );
};

export default FieldNavigationPanel;
