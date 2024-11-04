#lang rhombus/scribble/manual
@(import:
    "common.rhm" open:
      except: def
    "nonterminal.rhm" open
    meta_label:
      rhombus/runtime_path)

@title(~style: #'toc){Runtime Paths}

@docmodule(rhombus/runtime_path)

@(~version_at_least "8.14.0.4")

@doc(
  defn.macro 'runtime_path.def $id:
                $body
                ...'
){

 Defines @rhombus(id) to provide an absolute path that refers to the
 file name produced by the @rhombus(body) sequence as interpreted
 relative to the source module.

 An unusual property of @rhombus(runtime_path.def) is that the
 @rhombus(body) sequence is used in both a run-time context and a
 @rhombus(meta) context, so it must be valid for both. The meta
 interpretation is used for tasks like creating a standalone executable
 to ensure that referenced files are accessible at run time.

@examples(
  import:
    rhombus/meta open
    rhombus/runtime_path
  runtime_path.def image_file: "file.png"
)

}
