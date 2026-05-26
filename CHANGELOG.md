## 2026.5.24

* Updated plugin release metadata for the `2026.5.24` release.
* Added paragraph-property query commands and synchronized the Flutter-native
  format ribbon with the caret's current paragraph alignment and line spacing.
* Treated external primary-focus churn during a desktop text commit as part of
  the active native-editor input session, preventing Space/text input from
  immediately releasing deferred page refresh.
* Added Flutter-native selected object copy, cut, and paste through rhwp core's
  internal control clipboard.
* Kept Flutter-native editor text refresh blocked when desktop focus/action
  churn arrives before a slow input command finishes.
* Debounced desktop text-input focus churn with the native editor refresh delay
  so typing or Space does not trigger visible page refreshes between commits.
* Restored the Flutter-native editor TextInput focus after delayed desktop
  input churn so typing or Space does not reopen a page refresh while editing.
* Kept late desktop text input actions from flushing an already scheduled
  native-editor page refresh while optimistic text input is still active.
* Added Flutter-native new page number insertion from the page ribbon through
  rhwp core's `insert_new_number_native` command.
* Added Flutter-native header/footer text insertion from the page ribbon,
  backed by rhwp core header/footer query and text-edit commands.
* Changed the Flutter-native header/footer text dialog to prefill existing
  text and replace it through the Rust header/footer delete command.
* Added Flutter-native style list/apply commands and a format toolbar style
  picker for body paragraphs and selected table-cell paragraphs.
* Added Flutter-native character background/shade color formatting for selected
  text, table-cell text, pending input, and the character-shape dialog.
* Added Flutter-native superscript/subscript character formatting from the
  format ribbon, pending input, and character-shape dialog.
* Added Flutter-native emboss/engrave character formatting from the format
  ribbon, pending input, and character-shape dialog.
* Added a Flutter-native view-ribbon toggle that overlays transparent table cell
  borders from the page layer tree.
* Added the upstream-style `Alt+L` shortcut to open the Flutter-native character
  shape dialog.
* Changed the Flutter-native caret overlay to blink on the same 500ms cadence as
  the upstream web editor while keeping the caret hit-test widget mounted.
* Treated root or ancestor focus churn during desktop text input as part of the
  active editor session so Space/text input does not release deferred refresh.
* Matched upstream table-cell edit mode handling so `F5` enters a selected cell
  and `Esc` returns active cell text editing to cell selection.
* Matched upstream search-field keyboard handling so `Enter`/`Shift+Enter`
  navigate matches and `Esc` clears the active search from the tools ribbon.
* Matched upstream find shortcut behavior so `Ctrl/Cmd+F` selects the existing
  search text when focusing the tools-ribbon search field.
* Added upstream-style debounced live search from the Flutter-native tools
  ribbon search field.
* Scoped `RhwpViewer` controller rebuilds to zoom changes so native-editor
  cursor updates during typing do not refresh the page surface.
* Batched continuous Flutter-native text input into one undo snapshot so Space
  and character input avoid repeated full-document snapshot work.
* Added Flutter-native font family selection to the format ribbon and character
  shape dialog, backed by rhwp font id registration and char-layout reflow
  through the Rust facade.
* Added native char-property query commands and synchronized the Flutter-native
  format ribbon with the caret's current document character shape.
* Added upstream-style line-spacing presets to the Flutter-native format ribbon.
* Kept Flutter-native editor deferred page refresh blocked when desktop text
  input focus briefly drops and returns during typing.
* Initial flutter_rhwp plugin scaffold.
* Added flutter_rust_bridge v2 Rust bridge with vendored rhwp v0.7.12.
* Added Dart APIs for opening bytes, rendering SVG, extracting text/Markdown,
  exporting HWP/HWPX/PDF, and applying basic text commands.
* Added RhwpViewer, an initial RhwpEditor overlay, and an example app with
  open/save/export workflows.
* Added facade tests against the vendored blank HWP sample, DOCX package
  output, and explicit unsupported exceptions for Web/WASM PDF export.
* Added HWP/HWPX export reopen checks for both the vendored blank sample and
  the bundled example asset.
* Strengthened native PDF export tests with structural PDF checks and a fast
  multi-page SVG-to-PDF regression case.
* Verified the FRB Web/WASM build path and patched vendored rhwp's standalone
  WASM startup and web-sys canvas style compatibility for FRB integration.
* Updated package metadata links for `JAICHANGPARK/flutter_rhwp`.
* Added a bundled example HWP asset and wired the example app to open it by
  default while keeping file picker and export/save workflows.
* Added text, Markdown, and SVG to the public Dart export surface and example
  export menu.
* Implemented initial DOCX export as a valid Word OOXML package generated from
  extracted document text, and exposed it in the example export menu.
* Added a Web-only `RhwpWebEditor` embed for upstream `@rhwp/editor`, plus an
  example app toggle between the Flutter bridge editor and the upstream Web
  editor.
* Added `RhwpWebEditorController` so Web editor mode can export bytes from the
  upstream editor state instead of the stale Flutter bridge document.
* Added a Web COOP/COEP service worker bootstrap for local FRB WASM debugging.
* Use the FRB process loader on iOS/macOS so the statically linked Rust library
  can be resolved inside Flutter apps.
* Removed incomplete Apple SwiftPM manifests so iOS/macOS builds use the
  CocoaPods podspec/cargokit path that links the Rust static library.
* Added Linux desktop example integration tests for opening the bundled HWP
  asset, rendering SVG, extracting text/Markdown, and exporting supported
  formats.
* Run Linux desktop integration tests under Xvfb in CI for headless GitHub
  Actions runners.
* Added macOS desktop example integration tests to CI for the bundled asset
  open/render/export workflow.
* Added Windows desktop example integration tests to CI for the bundled asset
  open/render/export workflow.
* Added Android emulator example integration tests to CI for the bundled asset
  open/render/export workflow.
* Added GitHub Actions CI for Rust/Dart checks, Web WASM build, desktop builds,
  and Android/iOS example builds.
* Added a custom `RhwpViewer` SVG builder hook and Flutter widget paint tests
  for viewer rendering, zoom, and editor overlay command flows.
* Isolated rendered SVG pages behind a repaint boundary so native editor typing
  overlays do not force the HWP page raster layer to repaint.
* Added a `RhwpViewer` page virtualization regression test for lazy SVG page
  rendering during scroll.
* Added a Flutter-drawn `RhwpEditor` command-target caret and selection marker
  with widget coverage for collapsed and expanded selection states.
* Changed the example Web app to default to upstream Web editor mode so HWP
  open/edit/export can run without eager FRB WASM initialization on startup.
* Added example Web widget tests to CI so the browser editor mode shell is
  verified before the FRB WASM build.
* Added an iOS simulator CI helper and mobile workflow step for the example
  bundled asset open/render/export integration test.
* Added a generated FRB bridge mock smoke test for the Dart Rust API entrypoint.
* Improved DOCX export to use extracted Markdown and emit heading and simple
  table OOXML instead of only plain paragraph runs.
* Added root third-party notices for the vendored rhwp core, Cargokit, direct
  Dart/Rust dependencies, and generated FRB bridge files.
* Added a Web widget smoke test for bundled sample auto-open in upstream Web
  editor mode without eager Flutter bridge WASM initialization, and made empty
  Web editor module URLs render an inline message without injecting a bootstrap
  script.
* Added a typed Dart page layer tree model on top of rhwp's raw page layer tree
  JSON so editor/viewer code can inspect text nodes and bounds without ad hoc
  JSON traversal.
* Added text-run geometry helpers for page layer trees and made `RhwpEditor`
  prefer layer-tree caret/selection bounds when first-page text run geometry is
  available.
* Added a page-local `RhwpViewer.pageOverlayBuilder` hook and moved
  `RhwpEditor` caret/selection painting onto each rendered page so visible page
  overlays stay aligned with viewer scrolling and page layout.
* Added a Flutter-native page setup dialog that reads and updates rhwp page
  definitions through the Rust bridge.
* Added Flutter-native footnote insertion from the insert ribbon through the
  Rust command bridge.
* Added Flutter-native equation insertion from the insert ribbon through the
  Rust command bridge.
* Prevented immediate text input actions from flushing the Flutter-native
  editor's deferred page refresh after every committed character.
* Reduced example-app typing refresh churn by using a longer native-editor
  render sync delay and deferring HWP snapshot export until save/export or a
  native-to-full-editor mode switch.
* Added Flutter-native picture insertion from the insert ribbon through an app
  supplied image picker callback and the Rust command bridge.
* Added Flutter-native rectangle shape insertion from the insert ribbon through
  the Rust shape-control command bridge.
* Expanded Flutter-native shape insertion into a preset menu for rectangle,
  ellipse, line, and text box controls.
* Added a `moveLineEndpoint` Dart/Rust command and Flutter-native line endpoint
  drag handles for selected line objects.
* Added Flutter-native page break and column break insertion from the insert
  ribbon and Ctrl/Cmd+Enter shortcuts through the Rust command bridge.
* Added a Flutter-native document information dialog from the file ribbon,
  backed by the existing Rust document metadata bridge.
* Extended page layer tree selection geometry to span multiple paragraphs and
  wired `RhwpEditor` page overlays to render those page-local selection rects.
* Added a Rust facade regression test for the page layer tree JSON contract that
  Flutter editor geometry depends on.
* Added `RhwpExportedDocument` and `RhwpDocument.exportDocument()` so save and
  download flows can use the same bytes, file name, extension, and MIME
  metadata contract across the Flutter bridge and example app.
* Added `RhwpWebEditorController.exportDocument()` so upstream Web editor mode
  can use the same export artifact metadata contract as the Flutter bridge.
* Documented the Rust vendoring policy: commit `rust/vendor/rhwp` for
  reproducible builds, but keep generated `rust/target` output ignored.
* Verified that the example Web release build completes after the Web editor
  default-mode and export artifact changes.
* Added Dart API documentation for export artifact metadata and Web editor
  controller export methods.
* Relaxed the `flutter_rust_bridge` dependency constraint to a caret range and
  recorded the current `flutter pub publish --dry-run` warnings.
* Added `.pubignore` so repository work logs remain in `docs/` without being
  published in the runtime package archive.
* Added bundled asset integration coverage for native PDF export metadata and
  PDF byte structure, while keeping Web/WASM on the explicit unsupported path.
* Added `RhwpFullEditor` as the public full-editor surface backed by upstream
  `@rhwp/editor`, and introduced `RhwpCommandEditor` to make the Flutter-native
  command overlay's limited role explicit.
* Backed native `RhwpFullEditor` with `webview_all` so the upstream editor can
  be hosted on Android, iOS, macOS, Windows, and Linux instead of being limited
  to Web.
* Updated the Linux example runner to host Flutter in a `GtkOverlay`, matching
  the platform view setup required by `webview_all`'s Linux WebKitGTK
  implementation.
* Added the WebKitGTK 4.1 development package to Linux CI dependencies for the
  full-editor WebView host.
* Raised the Flutter SDK lower bound to 3.35.0 to match the native full-editor
  WebView host dependency.
* Added macOS outgoing network entitlements to the example app so WKWebView can
  load the upstream editor module in sandboxed debug/profile/release runs.
* Added a Flutter-side loading/error overlay for native `RhwpFullEditor` so
  WebView bootstrap failures do not appear as a blank black panel.
* Fixed upstream editor file injection by using `@rhwp/editor`'s documented
  `loadFile(data, fileName)` API, and added `getPageSvg()` as the SVG export
  method for full-editor mode.
* Simplified README around package purpose, installation, quick start, usage,
  example, notes, and license.
* Added ArrowUp/ArrowDown paragraph navigation with Shift selection extension
  in the Flutter-native editor.
* Added Tab key text insertion in the Flutter-native editor, including
  replacement of active text selections.
* Changed Flutter-native ArrowUp/ArrowDown movement to prefer page-layer text
  run geometry before falling back to paragraph order.
* Changed Flutter-native Home/End movement to use page-layer line geometry
  before falling back to paragraph boundaries.
* Added Ctrl/Option+Arrow word navigation with Shift selection extension in the
  Flutter-native editor.
* Added Ctrl/Option+Backspace/Delete word deletion in the Flutter-native
  editor.
* Added PageUp/PageDown page-level keyboard navigation with Shift selection
  extension in the Flutter-native editor.
* Added `RhwpNativeEditor` as the 100% Flutter widget editor track while
  keeping `RhwpFullEditor` as the WebView/upstream editor fallback.
* Reworked the Flutter-native editor surface with a Flutter toolbar, menu tabs,
  page viewport, caret/selection overlay, status bar, and basic insert/delete
  command flow.
* Updated the example editor toggle from `Commands` to `Native editor`.
* Added page-layer text hit testing so the Flutter-native editor can move the
  caret by tapping rendered document text.
* Wired Flutter-native drag selection to the same page-layer hit-test model.
* Added Flutter-native editor keyboard handling for left/right/home caret
  movement, shift-selection, and backspace/delete command dispatch.
* Added a Flutter `TextInputClient` bridge so the native editor can receive IME
  text composition and commit finalized text through the Rust insert command.
* Added a Flutter-native composing preview overlay so active IME composition is
  visible near the caret before it is committed to the document.
* Added page-layer selection text extraction plus Flutter-native editor
  copy/cut/paste shortcuts and toolbar actions.
* Added `splitParagraph` to the Rust bridge command surface and wired
  Flutter-native Enter/Shift+Enter handling.
* Added `deleteRange` to the Rust bridge command surface and wired
  Flutter-native multi-paragraph selection replacement.
* Added `applyCharFormat` to the Rust bridge command surface and wired
  Flutter-native bold, italic, and underline toolbar/shortcut actions.
* Added `applyCharFormatRange` for same-section multi-paragraph character
  formatting in the Flutter-native editor.
* Added `applyParaFormat` and `applyParaFormatRange` for paragraph alignment,
  with Flutter-native toolbar buttons for left, center, right, and justify.
* Added Ctrl/Cmd+L/E/R/J paragraph alignment shortcuts for left, center, right,
  and justify in the Flutter-native editor.
* Added `insertTable` to the Rust bridge command surface and wired a
  Flutter-native toolbar table insertion action.
* Added table row/column insert and delete commands to the Rust bridge surface
  with Flutter-native toolbar actions.
* Added table cell merge and split commands to the Rust bridge surface with
  Flutter-native toolbar actions.
* Added page-layer table cell hit testing so `RhwpNativeEditor` can fill table
  edit context from tapped rendered cells.
* Added Flutter-native table cell selection state and page overlay highlighting
  for tapped rendered cells.
* Added drag-based table cell range selection in `RhwpNativeEditor`, including
  multi-cell overlay highlighting and merge command context updates.
* Added Shift+click range extension for selected table cells in the
  Flutter-native editor.
* Added selected table cell text insert/delete commands through the Rust bridge
  and wired `RhwpNativeEditor` text input to the active cell.
* Added table cell text source parsing and hit testing so tapping rendered cell
  text sets the active cell edit offset.
* Added page-layer object/control hit testing and Flutter overlay highlighting
  for selected bounded objects in `RhwpNativeEditor`.
* Added a `deleteObjectControl` Dart/Rust command and wired selected object
  deletion through `RhwpNativeEditor` Delete/Backspace handling and context
  menu actions.
* Added selected object z-order commands to the Dart/Rust bridge and exposed
  bring-to-front/send-to-back/forward/backward actions through the
  Flutter-native edit ribbon and object context menu.
* Added selected object size/position property commands to the Dart/Rust bridge
  and exposed them through a Flutter-native object properties dialog.
* Added Flutter-native pointer drag move and resize handles for selected
  objects, backed by the same object properties bridge command.
* Added Arrow and Shift+Arrow keyboard nudging for selected objects in the
  Flutter-native editor.
* Added Shift+drag aspect-ratio preservation for selected object resize
  handles in the Flutter-native editor.
* Changed Flutter-native document edits to preserve the viewer widget and scroll
  position while refreshing rendered page content.
* Changed page SVG refreshes to keep showing the previous render until the next
  render completes, reducing edit-time flicker in the native editor.
* Changed Flutter-native text input, tab input, paste, and keyboard text delete
  edits to debounce page SVG refreshes so typing does not reload the page on
  every keystroke.
* Added a configurable `editRefreshDelay` for `RhwpNativeEditor` and set the
  example app to a 1200 ms delay so slower typing does not trigger a page SVG
  refresh after every space or character.
* Changed Flutter-native text input refresh scheduling to wait for the active
  text input action or connection close before starting `editRefreshDelay`,
  preventing page SVG refreshes while the user is still typing, and queued
  rapid text input commits so characters are not skipped while a previous edit
  command is still finishing.
* Added an optimistic Flutter text overlay for committed native-editor input so
  newly typed text remains visible until the refreshed page SVG finishes
  rendering, including table cell input and a temporary caret at the end of the
  pending text.
* Added pending delete masks for Flutter-native body text deletion and
  selection replacement so removed text is hidden until the refreshed page SVG
  finishes rendering.
* Changed Flutter-native text input previews to update through a scoped
  notifier and suppressed root editor rebuilds for pending typing cursor moves,
  reducing visible page refresh while entering spaces or text.
* Added a short desktop text-input focus grace window so transient IME/focus
  churn while typing does not release the deferred page refresh immediately.
* Extended desktop native-editor input hold handling so delayed text input
  actions and longer focus churn after a space or character do not trigger a
  page SVG refresh while typing is still in progress.
* Added Flutter-native Insert/Overwrite input mode toggling with the Insert key,
  including overwrite text replacement through the Rust `deleteText` command.
* Extended Flutter-native overwrite typing to active table cell text through
  the Rust `deleteTextInTableCell` command.
* Changed the Flutter-native status bar to show active table cell row/column
  and object selection context instead of only body paragraph offsets.
* Added a Flutter-native paragraph mark view toggle that paints paragraph-end
  markers from page layer tree text runs without changing rendered document
  output.
* Added a Flutter-native compare dialog in the tools ribbon that uses
  `extractText` and shows same/changed/added/removed line counts without
  editing the document.
* Changed Flutter-native body paste to convert multiline clipboard text into
  paragraph split and insert commands instead of inserting raw newline text.
* Added Flutter-native double-click word selection based on page-layer text run
  hit testing.
* Added Flutter-native triple-click paragraph selection using the same
  page-layer text source model.
* Added Flutter-native Shift+click selection extension for rendered text.
* Added Arrow and Tab keyboard navigation for selected table cells in the
  Flutter-native editor, including Shift+Arrow range extension.
* Added Escape handling in the Flutter-native editor to clear composing input,
  selected table cells, selected text, and active search highlights.
* Added Enter handling for selected table cells so the Flutter-native editor
  enters the active cell without dispatching a body paragraph split command.
* Added Flutter-native copy, cut, and paste handling for selected table cell
  text using page-layer cell text runs and table-cell edit commands.
* Added Flutter-native multi-cell table paste so tab/newline clipboard text is
  distributed across rendered table cells instead of being inserted into one
  active cell.
* Added Flutter-native find/replace support for table cell text using
  page-layer cell contexts and table-cell edit commands.
* Changed Delete/Backspace on selected table cells to clear the selected cell
  text, while preserving character-level deletion for active cell text editing.
* Split the Flutter-native editor toolbar into HWP-style ribbon tabs for file,
  edit, view, input, format, page, table, and tools, with table cell selection
  opening the table ribbon context.
* Added a Flutter-native secondary-click context menu for text selection,
  clipboard, formatting, paragraph alignment, table insertion, and selected
  table cell actions.
* Exposed strikethrough, font size, and text color character-format properties
  in the Dart command surface, and added a Flutter-native character shape dialog
  that applies those values through the Rust bridge.
* Added inline Flutter-native font size and text color controls to the format
  ribbon so common character shape edits no longer require opening the dialog.
* Added pending character formatting for collapsed selections in the native
  editor, so toolbar font/shape choices apply to the next inserted body text.
* Exposed line spacing, line spacing type, indent, and paragraph margin
  properties in the Dart paragraph-format command surface, and added a
  Flutter-native paragraph shape dialog that applies those values through the
  Rust bridge.
* Added Flutter-native text search in `RhwpNativeEditor`, using page layer tree
  text runs to select and highlight matches without calling the upstream Web
  editor.
* Added viewer page navigation to `RhwpViewerController`, wired the
  Flutter-native editor view ribbon to previous/next page controls, and made
  search result selection request the matching page.
* Added file-ribbon export actions to `RhwpNativeEditor` so HWP, HWPX, and PDF
  save artifacts can be emitted through a Flutter callback without using the
  upstream Web editor.
* Added synchronized zoom controls to the Flutter-native editor view ribbon and
  status bar, backed by the shared `RhwpEditorController` zoom state.
* Added Ctrl/Cmd zoom shortcuts to the Flutter-native editor for zoom in, zoom
  out, and reset zoom.
* Added Ctrl/Cmd+mouse-wheel zoom handling to the Flutter-native editor
  viewport.
* Added file-open callback support to `RhwpNativeEditor` and wired the example
  app so the native editor file ribbon can launch the same file picker and save
  callbacks as the outer app toolbar.
* Added header/footer creation commands to the Dart/Rust bridge and enabled the
  Flutter-native editor page ribbon Header/Footer buttons.
* Added snapshot commands to the Dart/Rust bridge and wired `RhwpNativeEditor`
  edit-ribbon undo/redo to rhwp core snapshots.
* Added active search-match replace to the Flutter-native editor tools ribbon,
  using undo-aware delete/insert commands through the Rust bridge.
* Added replace-all to the Flutter-native editor tools ribbon, applying all
  current search matches in one undo-aware edit transaction.
* Added Flutter-native select-all through the edit ribbon, context menu, and
  Ctrl/Cmd+A shortcut using page layer tree source positions.
* Added End and Shift+End keyboard navigation to move or extend selection to
  the current paragraph end from page layer tree source positions.
* Added Ctrl/Cmd+F handling in `RhwpNativeEditor` to open the tools ribbon and
  focus the Flutter-native search field.
* Added F3 and Shift+F3 search result navigation shortcuts for the
  Flutter-native editor.
* Added Ctrl/Cmd+Home and Ctrl/Cmd+End document boundary navigation, including
  Shift selection extension, using page layer tree source positions.
* Kept Flutter-native text input refresh deferred while desktop platforms churn
  the text input connection, so typing spaces or characters no longer triggers
  a page SVG refresh while the editor still has focus.
* Kept delayed desktop `TextInputAction.done` events from releasing the
  Flutter-native editor's deferred page refresh while the editor still has
  focus, preventing another per-character refresh path on macOS/Linux/Windows.
* Cached the rendered SVG page widget inside `RhwpViewer` so native-editor
  overlay updates during typing do not rebuild the SVG picture and appear as a
  page refresh.
* Added `applyCharFormatInTableCell` to the Dart/Rust command surface and wired
  Flutter-native character formatting to selected table cell text and pending
  table-cell input.
* Added `applyParaFormatInTableCell` to the Dart/Rust command surface and wired
  Flutter-native paragraph alignment/shape actions to selected table cell
  paragraphs.
* Added `applyTableCellStyle` to the Dart/Rust command surface and wired
  Flutter-native table ribbon actions for selected cell fill and border style.
* Extended `applyTableCellStyle` with selected table cell vertical alignment
  controls in the Flutter-native table ribbon.
