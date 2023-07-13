import React, { useEffect, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { askNewRawRecord, selectRawRecord } from "/js/features/RawRecordSlice";
import { selectAppDetails } from "/js/features/AppDetailsSlice";

const JumpTo = () => {
  const dispatch = useDispatch();

  const { transformationDefinition } = useSelector(selectAppDetails);

  const { isFetching, page, record, totalPages, totalRecords } =
    useSelector(selectRawRecord);

  const [inputPage, setInputPage] = useState(page);
  const [inputRecord, setInputRecord] = useState(record);

  useEffect(() => {
    setInputPage(page);
    setInputRecord(record);
  }, [page, record]);

  const handleSubmit = (e) => {
    e.preventDefault();
    dispatch(
      askNewRawRecord({
        transformationDefinitionId: transformationDefinition.id,
        page: inputPage,
        record: inputRecord,
      })
    );
  };

  const handleNextRecordClick = (e) => {
    dispatch(
      askNewRawRecord({
        transformationDefinitionId: transformationDefinition.id,
        page: record === totalRecords ? page + 1 : page,
        record: record === totalRecords ? 1 : record + 1,
      })
    );
  };

  const handlePreviousRecordClick = (e) => {
    dispatch(
      askNewRawRecord({
        transformationDefinitionId: transformationDefinition.id,
        page: record === 1 ? page - 1 : page,
        record: record === 1 ? totalRecords : record - 1,
      })
    );
  };

  return (
    <div className="dropdown jump-to">
      <button
        className="btn btn-primary dropdown-toggle text-truncate"
        type="button"
        data-bs-toggle="dropdown"
        data-bs-auto-close="outside"
        aria-expanded="false"
      >
        Jump to
      </button>
      <div className="dropdown-menu dropdown-menu-end jump-to__body p-2">
        <form className="row gx-1 mb-3" onSubmit={handleSubmit}>
          <label className="col-3 col-form-label" htmlFor="page">
            Page
          </label>
          <div className="col">
            <div className="input-group">
              <input
                name="page"
                id="page"
                className="form-control"
                disabled={isFetching || record !== inputRecord}
                type="number"
                value={inputPage}
                onChange={(e) => setInputPage(parseInt(e.target.value))}
              />
              <span className="input-group-text">/ {totalPages}</span>
            </div>
          </div>
          <div className="col-auto">
            <button
              className="btn btn-primary"
              disabled={
                isFetching ||
                record !== inputRecord ||
                page === inputPage ||
                inputPage > totalPages
              }
            >
              Go
            </button>
          </div>
        </form>
        <form className="row gx-1 mb-3" onSubmit={handleSubmit}>
          <label className="col-3 col-form-label" htmlFor="record">
            Record
          </label>
          <div className="col">
            <div className="mr-2">
              <div className="input-group">
                <input
                  name="record"
                  id="record"
                  className="form-control"
                  disabled={isFetching || page !== inputPage}
                  type="number"
                  value={inputRecord}
                  onChange={(e) => setInputRecord(parseInt(e.target.value))}
                />
                <span className="input-group-text"> / {totalRecords}</span>
              </div>
            </div>
          </div>
          <div className="col-auto">
            <button
              className="btn btn-primary"
              disabled={
                isFetching ||
                page !== inputPage ||
                record === inputRecord ||
                inputRecord > totalRecords
              }
            >
              Go
            </button>
          </div>
        </form>
        <div
          className="btn-group-vertical w-100"
          role="group"
          aria-label="Quick navigation"
        >
          <button
            className="btn btn-outline-primary"
            disabled={isFetching || (page == 1 && record == 1)}
            onClick={handlePreviousRecordClick}
          >
            Previous record
          </button>
          <button
            className="btn btn-outline-primary"
            disabled={
              isFetching || (page == totalPages && record == totalRecords)
            }
            onClick={handleNextRecordClick}
          >
            Next record
          </button>
        </div>
      </div>
    </div>
  );
};

export default JumpTo;
