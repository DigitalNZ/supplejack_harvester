import React, { useState } from "react";
import { createPortal } from "react-dom";
import { useDispatch, useSelector } from "react-redux";
import { setLoading } from "~/js/features/ExtractionApp/UiRequestsSlice";
import { selectAppDetails } from "~/js/features/ExtractionApp/AppDetailsSlice";
import {
  selectRequestIds,
  previewRequest,
} from "~/js/features/ExtractionApp/RequestsSlice";
import PreviewModal from "~/js/apps/ExtractionApp/components/PreviewModal";
import EnrichmentPreviewModal from "~/js/apps/ExtractionApp/components/EnrichmentPreviewModal";
import RunSample from "~/js/apps/ExtractionApp/components/RunSample";

const HeaderActions = () => {
  const dispatch = useDispatch();
  const appDetails = useSelector(selectAppDetails);

  const requestIds = useSelector(selectRequestIds);
  const initialRequestId = requestIds[0];
  const mainRequestId = requestIds[1];

  const [showModal, setShowModal] = useState(false);
  const handleClose = () => setShowModal(false);
  const handleShow = () => setShowModal(true);

  const handlePreviewClick = async () => {
    handleShow();

    dispatch(setLoading(initialRequestId));
    dispatch(setLoading(mainRequestId));

    const initialPreview = await dispatch(
      previewRequest({
        harvestDefinitionId: appDetails.harvestDefinition.id,
        pipelineId: appDetails.pipeline.id,
        extractionDefinitionId: appDetails.extractionDefinition.id,
        id: initialRequestId,
        page: 1,
        record: 1,
      })
    );

    if (
      (appDetails.extractionDefinition.paginated ||
      appDetails.extractionDefinition.kind == "enrichment") && !appDetails.extractionDefinition.pre_extraction
    ) {
      dispatch(
        previewRequest({
          harvestDefinitionId: appDetails.harvestDefinition.id,
          pipelineId: appDetails.pipeline.id,
          extractionDefinitionId: appDetails.extractionDefinition.id,
          id: mainRequestId,
          previousRequestId: initialPreview.payload.id,
          page: 1,
          record: 1,
        })
      );
    }
  };

  return createPortal(
    <>
      {!appDetails.extractionDefinition.split &&
        !appDetails.extractionDefinition.extract_text_from_file && (
          <button className="btn btn-success me-2" onClick={handlePreviewClick}>
            <i className="bi bi-play" aria-hidden="true"></i> Preview
          </button>
        )}

      {appDetails.extractionDefinition.split && <RunSample />}

      {appDetails.extractionDefinition.kind == "harvest" && (
        <PreviewModal
          showModal={showModal}
          handleClose={handleClose}
          initialRequestId={initialRequestId}
          mainRequestId={mainRequestId}
        />
      )}

      {appDetails.extractionDefinition.kind == "enrichment" && (
        <EnrichmentPreviewModal
          showModal={showModal}
          handleClose={handleClose}
          initialRequestId={initialRequestId}
          mainRequestId={mainRequestId}
        />
      )}
    </>,
    document.getElementById("react-header-actions")
  );
};

export default HeaderActions;
