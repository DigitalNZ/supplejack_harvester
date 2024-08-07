import React from "react";
import { useSelector } from "react-redux";

import { map } from 'lodash';

import SchemaFieldNavigationPanel from "./components/SchemaFieldNavigationPanel";
import SchemaField from './components/SchemaField';

// actions from state

import { selectSchemaFieldIds } from '~/js/features/SchemaApp/SchemaFieldsSlice';

const SchemaApp = () => {
  const schemaFieldIds = useSelector(selectSchemaFieldIds);

  return (
    <>
      <div className='row'>
        <div className='col-2'>
          <SchemaFieldNavigationPanel />
        </div>

        <div className='col-10'>
          <div className="row gy-4">
            {map(schemaFieldIds, (id) => (
              <SchemaField id={id} key={id} />
            ))}
          </div>
        </div>
      </div>
    </>
  );
};

export default SchemaApp;
