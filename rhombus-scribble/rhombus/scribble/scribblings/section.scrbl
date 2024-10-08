#lang rhombus/scribble/manual
@(import:
    "common.rhm" open)

@title(~tag: "section"){Title and Sections}

@doc(~include rhombus/scribble/private/section: title){

 Declares a title for the document. In the main module of a document,
 this title is the overall title of the document. In a section included
 via @rhombus(include_section), it is the name of the section.

}

@doc(~include rhombus/scribble/private/section: section){

 Declares a section at a level nested below @rhombus(title).

}

@doc(~include rhombus/scribble/private/section:
       subsection
       subsubsection
       subsubsub_section){

 Declares sections as further nesting levels. By the
 @rhombus(subsubsub_section) level, the result is simply a paragraph that
 renders as an unnumbered section header.

}

@doc(
  defn.macro 'include_section($module_path)'
){

 Makes the document at @rhombus(module_path) a section of the enclosing
 document, where the @rhombus(module_path) section hierarchy is
 effectively shifted to more nested my one layer. That is,
 @rhombus(title) within @rhombus(module_path) corresponds to a
 @rhombus(section) written in the document where
 @rhombus(include_section) is used, @rhombus(section) corresponds to
 @rhombus(subsection), and so on.

}
