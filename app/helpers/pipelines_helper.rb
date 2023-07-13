module PipelinesHelper
  def reference?(pipeline, definition)
    pipeline != definition.pipeline
  end
end
