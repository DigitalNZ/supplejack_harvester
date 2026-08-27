import React, { useState, useEffect } from "react";
import { createPortal } from "react-dom";
import { useSelector, useDispatch } from "react-redux";
import { selectAppDetails } from "~/js/features/ExtractionApp/AppDetailsSlice";
import { request } from "~/js/utils/request";

import Modal from "react-bootstrap/Modal";
import Preview from "~/js/apps/ExtractionApp/components/Preview";
import RunSample from "~/js/apps/ExtractionApp/components/RunSample";

import { previewRequest } from "~/js/features/ExtractionApp/RequestsSlice";

import { setLoading } from "~/js/features/ExtractionApp/UiRequestsSlice";
import { selectUiRequestById } from "~/js/features/ExtractionApp/UiRequestsSlice";
import { selectRequestById } from "~/js/features/ExtractionApp/RequestsSlice";

const EnrichmentPreviewModal = ({
  showModal,
  handleClose,
  initialRequestId,
  mainRequestId,
}) => {
  const dispatch = useDispatch();
  const appDetails = useSelector(selectAppDetails);

  const [currentPage, setCurrentPage] = useState(1);
  const [currentRecord, setCurrentRecord] = useState(1);

  const initialRequestLoading = useSelector((state) =>
    selectUiRequestById(state, initialRequestId)
  ).loading;
  const mainRequestLoading = useSelector((state) =>
    selectUiRequestById(state, mainRequestId)
  ).loading;

  const { total_pages, total_records } = useSelector((state) =>
    selectRequestById(state, initialRequestId)
  ).preview;

  useEffect(() => {
    requestNewPreview();
  }, [currentPage, currentRecord]);

  const handleNextRecordClick = async () => {
    if (currentRecord < total_records) {
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
      setCurrentRecord(total_records);
    }
  };

  const requestNewPreview = async () => {
    dispatch(setLoading(initialRequestId));
    dispatch(setLoading(mainRequestId));

    const initialPreview = await dispatch(
      previewRequest({
        harvestDefinitionId: appDetails.harvestDefinition.id,
        pipelineId: appDetails.pipeline.id,
        extractionDefinitionId: appDetails.extractionDefinition.id,
        id: initialRequestId,
        page: currentPage,
        record: currentRecord,
      })
    );

    dispatch(
      previewRequest({
        harvestDefinitionId: appDetails.harvestDefinition.id,
        pipelineId: appDetails.pipeline.id,
        extractionDefinitionId: appDetails.extractionDefinition.id,
        id: mainRequestId,
        previousRequestId: initialPreview.payload.id,
        page: currentPage,
        record: currentRecord,
      })
    );
  };

  const canNotClickPreviousRecord = () => {
    return (
      initialRequestLoading ||
      mainRequestLoading ||
      (currentPage == 1 && currentRecord == 1)
    );
  };

  const canNotClickNextRecord = () => {
    return (
      initialRequestLoading ||
      mainRequestLoading ||
      (currentPage == total_pages && currentRecord == total_records)
    );
  };

  return createPortal(
    <Modal
      size="lg"
      show={showModal}
      onHide={handleClose}
      className="modal--full-width"
    >
      <Modal.Header>
        <Modal.Title>Enrichment Extraction preview</Modal.Title>

        <div className="ms-auto">
          <button
            className="btn btn-outline-primary me-2"
            onClick={() => {
              handleClose();
            }}
          >
            <i className="bi bi-pencil-square me-1" aria-hidden="true"></i>
            Return to edit extraction
          </button>

          <RunSample />
        </div>
      </Modal.Header>
      <Modal.Body>
        <h5 className="float-start">
          Record {currentRecord} / {total_records} | Page {currentPage} /{" "}
          {total_pages}
        </h5>

        <div className="float-end">
          <button
            className="btn btn-outline-primary me-2"
            disabled={canNotClickPreviousRecord()}
            onClick={() => {
              handlePreviousRecordClick();
            }}
          >
            <i className="bi bi-arrow-left-short me-1" aria-hidden="true"></i>
            Previous record
          </button>

          <button
            className="btn btn-outline-primary me-2"
            disabled={canNotClickNextRecord()}
            onClick={() => {
              handleNextRecordClick();
            }}
          >
            Next record
            <i className="bi bi-arrow-right-short me-1" aria-hidden="true"></i>
          </button>
        </div>

        <div className="clearfix"></div>

        <div className="row">
          <div className="col-6">
            <Preview id={initialRequestId} view={"apiRecord"} />
          </div>

          <div className="col-6">
            <Preview id={mainRequestId} />
          </div>
        </div>
      </Modal.Body>
    </Modal>,
    document.getElementById("react-modals")
  );
};

export default EnrichmentPreviewModal;
