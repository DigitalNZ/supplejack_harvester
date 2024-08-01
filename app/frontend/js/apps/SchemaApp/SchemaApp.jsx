import React from "react";
import { useSelector } from "react-redux";

import FieldNavigationPanel from "./components/FieldNavigationPanel";

const SchemaApp = ({ }) => {
  return (
    <>
      <div className='row'>
        <div className='col-2'>
          <FieldNavigationPanel />
        </div>

        <div className='col-10'>
          Parameter List
        </div>
      </div>
    </>
  );
};

export default SchemaApp;
