import React from "react";

import { useSelector } from "react-redux";

import { selectUiRequestById } from "~/js/features/ExtractionApp/UiRequestsSlice";
import { selectRequestById } from "~/js/features/ExtractionApp/RequestsSlice";

import PreviewPanel from "~/js/apps/ExtractionApp/components/PreviewPanel";

const Preview = ({ id, view = "accordion" }) => {
  const { loading } = useSelector((state) => selectUiRequestById(state, id));
  const { preview, format } = useSelector((state) => selectRequestById(state, id));

  return (
    <PreviewPanel preview={preview} format={format} loading={loading} view={view} />
  );
};

export default Preview;
