import React from "react";
import { useSelector } from "react-redux";
import { selectUiAppDetails } from "/js/features/UiAppDetailsSlice";
import ExpandCollapseIcon from "./components/ExpandCollapseIcon";
import RecordViewer from "~/js/apps/TransformationApp/components/RecordViewer";
import JumpTo from "./JumpTo";
import { selectRawRecord } from "/js/features/RawRecordSlice";

const RawDataBody = ({ clickToggleSection }) => {
  const { body, format } = useSelector(selectRawRecord);
  const { rawRecordExpanded } = useSelector(selectUiAppDetails);

  return (
    <>
      <div className="d-flex flex-row flex-nowrap justify-content-between mb-4">
        <h5 className="text-truncate">Raw data</h5>

        <div className="hstack gap-2">
          <JumpTo />
          <button
            onClick={() => clickToggleSection("rawRecordExpanded")}
            type="button"
            className="btn btn-outline-primary"
          >
            <ExpandCollapseIcon expanded={rawRecordExpanded} />
          </button>
        </div>
      </div>

      <RecordViewer record={body} format={format} />
    </>
  );
};

export default RawDataBody;
