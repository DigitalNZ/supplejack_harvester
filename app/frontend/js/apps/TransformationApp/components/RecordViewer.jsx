import React, { useRef, useEffect } from "react";
import { EditorState } from "@codemirror/state";
import { EditorView } from "codemirror";
import { editorExtensions } from "~/js/editor";

import xmlFormat from "xml-formatter";

const RecordViewer = ({ record, format }) => {
  const editor = useRef();

  function doc() {
    if (format == "JSON" || format == "ARCHIVE_JSON") {
      return JSON.stringify(record, null, 2);
    } else if (format == "XML") {
      return xmlFormat(record, { indentation: "  ", lineSeparator: "\n" });
    } else {
      return record;
    }
  }

  useEffect(() => {
    const state = EditorState.create({
      doc: doc(),
      extensions: editorExtensions(format, true),
    });

    const view = new EditorView({ state, parent: editor.current });

    return () => {
      view.destroy();
    };
  }, [record]);

  return (
    <div className="record-view record-view--transformation">
      <div className="record-view__container" ref={editor}></div>
    </div>
  );
};

export default RecordViewer;
