import React from "react";
import { useSelector } from "react-redux";

import { map } from 'lodash';

import FieldNavigationPanel from "./components/FieldNavigationPanel";
import Field from './components/Field';

// actions from state

import { selectFieldIds } from '~/js/features/SchemaApp/FieldsSlice';

const SchemaApp = () => {
  const fieldIds = useSelector(selectFieldIds);

  return (
    <>
      <div className='row'>
        <div className='col-2'>
          <FieldNavigationPanel />
        </div>

        <div className='col-10'>
          <div className="row gy-4">
            {map(fieldIds, (fieldId) => (
              <Field id={fieldId} key={fieldId} />
            ))}
          </div>
        </div>
      </div>
    </>
  );
};

export default SchemaApp;
