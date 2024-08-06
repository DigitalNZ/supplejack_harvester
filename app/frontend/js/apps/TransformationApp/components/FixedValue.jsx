import React from 'react';

import { map } from 'lodash';

const FixedValue = ({ schemaFieldValues }) => {

  return (
    <>
      <div className='row my-2'>
        <div className="col-12">
          <div className="row">
            <label className="col-form-label col-sm-2" htmlFor="name">
              <strong>Fixed value </strong>
            </label>

            <div className="col-sm-10">
              <select
                className="form-select"
                aria-label="Condition type"
              >
                {map(schemaFieldValues, (value) => {
                  return <option key={value.id} value={value.id}>{value.value}</option>
                })}
              </select>
            </div>
          </div>
        </div>
      </div>
    </>
  )
}

export default FixedValue;