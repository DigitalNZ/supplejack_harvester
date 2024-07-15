import React, { useRef, useEffect } from "react";
import { EditorView, basicSetup } from "codemirror";
import { StreamLanguage } from "@codemirror/language";
import { EditorState } from "@codemirror/state";
import { json } from "@codemirror/lang-json";
import { ruby } from "@codemirror/legacy-modes/mode/ruby";
import { xml } from "@codemirror/legacy-modes/mode/xml";
import xmlFormat from "xml-formatter";

const CodeEditor = ({ initContent, onChange, format = "ruby", ...props }) => {
  const editorRef = useRef();

  const editorExtensions = () => {
    if (format == "JSON" || format == "ARCHIVE_JSON") {
      return [basicSetup, json(), EditorState.readOnly.of(true)];
    } else if (format == "XML" || format == "HTML") {
      return [
        basicSetup,
        StreamLanguage.define(xml),
        EditorState.readOnly.of(true),
      ];
    } else if (format == "ruby") {
      return [
        basicSetup,
        StreamLanguage.define(ruby),
        EditorView.updateListener.of(function (e) {
          onChange({ target: { value: e.state.doc.toString() } });
        }),
      ];
    }
  };

  const errorDocument = () => {
    return JSON.stringify({
      error:
        "Something went wrong fetching the response from the content source. This can also happen when the format specified in the extraction definition is not the same as the format of the extracted document.",
    });
  };

  const doc = () => {
    let content;
    if (format == "JSON" || format == "ARCHIVE_JSON") {
      try {
        content = JSON.stringify(JSON.parse(initContent), null, 2);
      } catch (err) {
        content = errorDocument();
      }

      return content;
    } else if (format == "XML") {
      try {
        content = xmlFormat(initContent, {
          indentation: "  ",
          lineSeparator: "\n",
        });
      } catch (err) {
        content = errorDocument();
      }

      return content;
    } else {
      return initContent;
    }
  };

  useEffect(() => {
    const state = EditorState.create({
      doc: doc(),
      extensions: editorExtensions(),
    });

    const view = new EditorView({ state, parent: editorRef.current });

    return () => view.destroy();
  }, []);

  return <div ref={editorRef} {...props}></div>;
};

export default CodeEditor;
