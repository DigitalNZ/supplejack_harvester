import React, { useState } from "react";

import { useSelector, useDispatch } from 'react-redux';
import { selectFieldValueById } from "~/js/features/SchemaApp/FieldValuesSlice";

const FieldValue = ({ id }) => {

  const { value } = useSelector((state) =>
    selectFieldValueById(state, id)
  );

  return (
    <>
      <div className="float-start">
        {value}
      </div>

      <div className="float-end">
        <ul className="list-inline">
          <li className="list-inline-item">Edit</li>
          <li className="list-inline-item">Delete</li>
        </ul>
      </div>

      <div className='clearfix'></div>
    </>
  )
}

export default FieldValue;