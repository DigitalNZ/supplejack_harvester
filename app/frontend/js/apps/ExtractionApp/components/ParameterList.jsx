import React from "react";
import { useSelector } from "react-redux";
import { selectParameterIdsByRequestAndKind } from "/js/features/ExtractionApp/ParametersSlice";
import Parameter from "./Parameter";

const ParameterList = ({ requestId, kind }) => {
  const ids = useSelector((state) =>
    selectParameterIdsByRequestAndKind(state, requestId, kind)
  );

  return ids.map((id) => <Parameter id={id} key={id} />);
};

export default ParameterList;
