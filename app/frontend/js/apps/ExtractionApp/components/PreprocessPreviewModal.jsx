import React, { useState, useEffect } from "react";
import { createPortal } from "react-dom";
import { useSelector, useDispatch } from "react-redux";
import { selectAppDetails } from "~/js/features/ExtractionApp/AppDetailsSlice";

import Modal from "react-bootstrap/Modal";
import PreviewPanel from "~/js/apps/ExtractionApp/components/PreviewPanel";

import {
  previewRequest,
  selectRequestById,
} from "~/js/features/ExtractionApp/RequestsSlice";
import {
  setLoading,
  selectUiRequestById,
} from "~/js/features/ExtractionApp/UiRequestsSlice";
import { request } from "~/js/utils/request";

const PreprocessPreviewModal = ({ showModal, handleClose, requestId }) => {
  const dispatch = useDispatch();
  const appDetails = useSelector(selectAppDetails);

  const [currentPage, setCurrentPage] = useState(1);
  const [currentRecord, setCurrentRecord] = useState(1);
  const [currentRunId, setCurrentRunId] = useState(null);

  const { loading } = useSelector((state) =>
    selectUiRequestById(state, requestId)
  );
  const { preview, format } = useSelector((state) =>
    selectRequestById(state, requestId)
  );

  const runs = preview?.runs || [];
  const totalPages = preview?.total_pages || 0;
  const totalRecords = preview?.total_records || 0;
  const selectedRunId = currentRunId ?? preview?.current_run_id ?? "";
  const selectedRun = runs.find((run) => run.id === selectedRunId);

  useEffect(() => {
    if (!showModal) return;

    dispatch(setLoading(requestId));
    dispatch(
      previewRequest({
        pipelineId: appDetails.pipeline.id,
        harvestDefinitionId: appDetails.harvestDefinition.id,
        extractionDefinitionId: appDetails.extractionDefinition.id,
        id: requestId,
        page: currentPage,
        record: currentRecord,
        pipelineJobId: currentRunId,
      })
    );
  }, [showModal, currentPage, currentRecord, currentRunId]);

  const handleNextRecordClick = () => {
    if (currentRecord < totalRecords) {
      setCurrentRecord(currentRecord + 1);
    } else {
      setCurrentPage(currentPage + 1);
      setCurrentRecord(1);
    }
  };

  const handlePreviousRecordClick = () => {
    if (currentRecord > 1) {
      setCurrentRecord(currentRecord - 1);
    } else {
      setCurrentPage(currentPage - 1);
      setCurrentRecord(totalRecords);
    }
  };

  const handleRunChange = (event) => {
    setCurrentRunId(Number(event.target.value));
    setCurrentPage(1);
    setCurrentRecord(1);
  };

  const handleRetentionToggle = () => {
    const path = `/pipelines/${appDetails.pipeline.id}/jobs/${selectedRunId}/retention`;
    const toggle = selectedRun?.retained
      ? request.delete(path)
      : request.post(path);

    toggle.then(() => {
      dispatch(setLoading(requestId));
      dispatch(
        previewRequest({
          pipelineId: appDetails.pipeline.id,
          harvestDefinitionId: appDetails.harvestDefinition.id,
          extractionDefinitionId: appDetails.extractionDefinition.id,
          id: requestId,
          page: currentPage,
          record: currentRecord,
          pipelineJobId: selectedRunId,
        })
      );
    });
  };

  const canNotClickPreviousRecord = () =>
    loading || (currentPage == 1 && currentRecord == 1);

  const canNotClickNextRecord = () =>
    loading ||
    totalRecords == 0 ||
    (currentPage == totalPages && currentRecord == totalRecords);

  return createPortal(
    <Modal
      size="lg"
      show={showModal}
      onHide={handleClose}
      className="modal--full-width"
    >
      <Modal.Header>
        <Modal.Title>Pre-processed data extraction preview</Modal.Title>

        <div className="float-end d-flex align-items-center">
          <label className="me-2 mb-0" htmlFor="preprocess-preview-run">
            Preview Data:
          </label>
          <select
            id="preprocess-preview-run"
            className="form-select me-2"
            style={{ width: "auto" }}
            value={selectedRunId}
            onChange={handleRunChange}
            disabled={loading || runs.length == 0}
          >
            {runs.map((run) => (
              <option key={run.id} value={run.id}>
                {run.retained ? "🔒 " : ""}
                {run.label}
              </option>
            ))}
          </select>

          <button
            className="btn btn-outline-primary me-2"
            onClick={handleRetentionToggle}
            disabled={loading || runs.length == 0}
            title={
              selectedRun?.retained
                ? "Stop retaining this run's pre-processed data"
                : "Retain this run's pre-processed data. The nightly cleanup will keep it."
            }
          >
            <i
              className={
                selectedRun?.retained ? "bi bi-lock-fill" : "bi bi-unlock"
              }
              aria-hidden="true"
            ></i>
          </button>

          <button
            className="btn btn-outline-primary"
            onClick={() => {
              handleClose();
            }}
          >
            <i className="bi bi-pencil-square me-1" aria-hidden="true"></i>
            Return to edit extraction
          </button>
        </div>
      </Modal.Header>
      <Modal.Body>
        {loading && runs.length == 0 && (
          <div className="d-flex justify-content-center">
            <div className="spinner-border text-primary" role="status">
              <span className="visually-hidden">Loading...</span>
            </div>
          </div>
        )}

        {!loading && runs.length == 0 && (
          <p className="text-muted">
            No pre-processed data yet — run the pipeline first.
          </p>
        )}

        {runs.length > 0 && (
          <>
            <h5 className="float-start">
              Record {currentRecord} / {totalRecords} | Page {currentPage} /{" "}
              {totalPages}
            </h5>

            <div className="float-end">
              <button
                className="btn btn-outline-primary me-2"
                disabled={canNotClickPreviousRecord()}
                onClick={() => {
                  handlePreviousRecordClick();
                }}
              >
                <i
                  className="bi bi-arrow-left-short me-1"
                  aria-hidden="true"
                ></i>
                Previous record
              </button>

              <button
                className="btn btn-outline-primary"
                disabled={canNotClickNextRecord()}
                onClick={() => {
                  handleNextRecordClick();
                }}
              >
                Next record
                <i
                  className="bi bi-arrow-right-short me-1"
                  aria-hidden="true"
                ></i>
              </button>
            </div>

            <div className="clearfix"></div>

            <div className="row">
              <div className="col-6">
                <PreviewPanel
                  preview={preview?.input}
                  format="JSON"
                  loading={loading}
                  view="apiRecord"
                />
              </div>

              <div className="col-6">
                <PreviewPanel
                  preview={preview?.response}
                  format={format}
                  loading={loading}
                  view="accordion"
                />
              </div>
            </div>
          </>
        )}
      </Modal.Body>
    </Modal>,
    document.getElementById("react-modals")
  );
};

export default PreprocessPreviewModal;
