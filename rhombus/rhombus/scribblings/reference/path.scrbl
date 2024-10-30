#lang rhombus/scribble/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open)

@title{Paths}

A @deftech{path} value represents a filesystem path.

@dispatch_table(
  "path"
  Path
  path.bytes()
  path.add(part, ...)
  path.split()
  path.string()
  path.to_absolute_path(...)
)

Paths are @tech{comparable}, which means that generic operations like
@rhombus(<) and @rhombus(>) work on paths.

@doc(
  annot.macro 'Path'
  annot.macro 'PathString'
  annot.macro 'PathString.to_absolute_path'
  annot.macro 'PathString.to_absolute_path(~relative_to: base :: PathString)'
  annot.macro 'PathString.to_path'
  annot.macro 'Path.Absolute'
  annot.macro 'Path.Relative'
){

 Matches a path value.  The @rhombus(PathString, ~annot) annotation allows
 @rhombus(ReadableString, ~annot) as well as @rhombus(Path, ~annot) values.
 The @rhombus(PathString.to_path, ~annot)
 @tech(~doc: guide_doc){converter annotation} allows
 @rhombus(PathString, ~annot) values, but converts
 @rhombus(ReadableString, ~annot) values to @rhombus(Path) values.  Similarly
 @rhombus(PathString.to_absolute_path, ~annot) is a converter annotation that
 converts a @rhombus(PathString, ~annot) into an absolute path relative to
 @rhombus(Path.current_directory()) or to the specified @rhombus(base)
 directory.

 The @rhombus(Path.Absolute, ~annot) annotation only matches
 @rhombus(Path, ~annot)s that begin with the root directory of the filesystem
 or drive.  The @rhombus(Path.Relative, ~annot) annotation only matches
 @rhombus(Path, ~annot)s that are relative to some base directory.
}

@doc(
  fun Path(path :: Bytes || ReadableString || Path) :: Path
){

 Constructs a path given a byte string, string, or existing path. When a
 path is provided as @rhombus(path), then the result is @rhombus(path).

@examples(
  def p = Path("/home/rhombus/shape.txt")
  p
  Path(p)
  p.string()
)

}

@doc(
  bind.macro 'Path($bind)'
){

 Matches a path where the byte-string form of the path matches
 @rhombus(bind).

@examples(
  def Path(p) = Path("/home/rhombus/shape.txt")
  p
)

}

@doc(
  Parameter.def Path.current_directory :: Path
){
  A @tech{context parameter} for the current directory.
}

@doc(
  fun Path.bytes(path :: Path) :: Bytes
){

 Converts a path to a byte-string form, which does not lose any
 information about the path.

@examples(
  def p = Path("/home/rhombus/shape.txt")
  Path.bytes(p)
  p.bytes()
)

}

@doc(
  fun Path.add(path :: PathString,
               part :: PathString
                 || matching(#'up)
                 || matching(#'same), ...) :: Path
  operator ((base :: PathString) +/ (part :: PathString
                                       || matching(#'up)
                                       || matching(#'same))) :: Path
){

  Creates a path given a base path and any number of sub-path
  extensions. If @rhombus(path) is an absolute path,
  the result is an absolute path, otherwise the result is a relative path.

  The @rhombus(path) and each @rhombus(part) must be either a relative
  path, the symbol @rhombus(#'up) (indicating the relative parent
  directory), or the symbol @rhombus(#'same) (indicating the
  relative current directory).  For Windows paths, if @rhombus(path) is a
  drive specification (with or without a trailing slash) the first
  @rhombus(part) can be an absolute (driveless) path. For all platforms,
  the last @rhombus(part) can be a filename.

  The @rhombus(path) and @rhombus(part) arguments can be paths for
  any platform. The platform for the resulting path is inferred from the
  @rhombus(path) and @rhombus(part) arguments, where string arguments imply
  a path for the current platform. If different arguments are for
  different platforms, the @rhombus(Exn.Fail.Contract, ~class) exception
  is thrown.  If no argument implies a platform (i.e., all are @rhombus(#'up)
  or @rhombus(#'same)), the generated path is for the current platform.

  Each @rhombus(part) and @rhombus(path) can optionally end in a directory
  separator. If the last @rhombus(part) ends in a separator, it is
  included in the resulting path.

  The @rhombus(Path.add) procedure builds a path @italic{without}
  checking the validity of the path or accessing the filesystem.

@examples(
  def p = Path("/home/rhombus")
  Path.add(p, "shape.txt")
  p.add("shape.txt")
  p +/ "shape.txt"
)

}

@doc(
  fun Path.split(path :: PathString) :: List.of(Path || #'up || #'same)
){

  Returns a list of path elements that constitute @rhombus(path).

  The @rhombus(Path.split) function computes its result in time
  proportional to the length of @rhombus(path).

@examples(
  def p = Path("/home/rhombus/shape.txt")
  Path.split(p)
  p.split()
)

}

@doc(
  fun Path.string(path :: Path) :: String
){

 Converts a path to a human-readable form, but the conversion may lose
 information if the path cannot be expressed using a string (e.g., due to
 a byte-string form that is not a UTF-8 encoding).

@examples(
  def p = Path(#"/home/rhombus/shape.txt")
  Path.string(p)
  p.string()
)

}

@doc(
  fun Path.directory_only(path :: PathString) :: Path
){

 Returns @rhombus(path) without its final path element in the case
 that @rhombus(path) is not syntactically a directory; if
 @rhombus(path) has only a single, non-directory path element, #f is
 returned. If @rhombus(path) is syntactically a directory, then
 @rhombus(path) is returned unchanged (but as a path, if it was a
 string).

}

@doc(
  fun Path.to_absolute_path(path :: PathString,
                            ~relative_to: base
                                          :: PathString
                                            = Path.current_directory())
    :: Path
){
 Returns @rhombus(path) as an absolute path. If @rhombus(path) is already an
 absolute path, it is returned as the result. Otherwise, @rhombus(path) is
 resolved with respect to the absolute path @rhombus(base). If @rhombus(base) is
 not an absolute path, the @rhombus(Exn.Fail.Contract, ~class) exception is
 thrown.
}

@// ------------------------------------------------------------

@include_section("runtime-path.scrbl")
