use std::io::{Cursor, Write};
use std::sync::{Mutex, MutexGuard};

use serde::Deserialize;
use zip::write::SimpleFileOptions;
use zip::{CompressionMethod, DateTime, ZipWriter};

use rhwp_core::wasm_api::HwpDocument;

#[flutter_rust_bridge::frb(opaque)]
pub struct RhwpSession {
    inner: Mutex<RhwpSessionInner>,
}

struct RhwpSessionInner {
    document: HwpDocument,
    file_name: Option<String>,
}

pub struct RhwpDocumentInfo {
    pub page_count: u32,
    pub source_format: String,
    pub file_name: Option<String>,
    pub raw_json: String,
}

impl RhwpSession {
    pub fn page_count(&self) -> Result<u32, String> {
        Ok(self.lock()?.document.page_count())
    }

    pub fn document_info(&self) -> Result<RhwpDocumentInfo, String> {
        let inner = self.lock()?;
        Ok(RhwpDocumentInfo {
            page_count: inner.document.page_count(),
            source_format: inner.document.get_source_format(),
            file_name: inner.file_name.clone(),
            raw_json: inner.document.get_document_info(),
        })
    }

    pub fn render_page_svg(&self, page: u32) -> Result<String, String> {
        let inner = self.lock()?;
        inner
            .document
            .render_page_svg_native(page)
            .map_err(error_to_string)
    }

    pub fn page_layer_tree(&self, page: u32) -> Result<String, String> {
        let inner = self.lock()?;
        inner
            .document
            .get_page_layer_tree_native(page)
            .map_err(error_to_string)
    }

    pub fn extract_text(&self, page: Option<u32>) -> Result<String, String> {
        let inner = self.lock()?;
        let pages = selected_pages(inner.document.page_count(), page)?;
        let mut output = Vec::with_capacity(pages.len());

        for page in pages {
            output.push(
                inner
                    .document
                    .extract_page_text_native(page)
                    .map_err(error_to_string)?,
            );
        }

        Ok(output.join("\n\n"))
    }

    pub fn extract_markdown(&self, page: Option<u32>) -> Result<String, String> {
        let inner = self.lock()?;
        let pages = selected_pages(inner.document.page_count(), page)?;
        let mut output = Vec::with_capacity(pages.len());

        for page in pages {
            output.push(
                inner
                    .document
                    .extract_page_markdown_native(page)
                    .map_err(error_to_string)?,
            );
        }

        Ok(output.join("\n\n"))
    }

    pub fn export_hwp(&self) -> Result<Vec<u8>, String> {
        let mut inner = self.lock()?;
        inner
            .document
            .export_hwp_with_adapter()
            .map_err(error_to_string)
    }

    pub fn export_hwpx(&self) -> Result<Vec<u8>, String> {
        let inner = self.lock()?;
        inner.document.export_hwpx_native().map_err(error_to_string)
    }

    pub fn export_pdf(&self) -> Result<Vec<u8>, String> {
        #[cfg(target_arch = "wasm32")]
        {
            let _ = self;
            Err("PDF export is not supported on Web/WASM yet".to_string())
        }

        #[cfg(not(target_arch = "wasm32"))]
        {
            let inner = self.lock()?;
            let pages = selected_pages(inner.document.page_count(), None)?;
            let mut svg_pages = Vec::with_capacity(pages.len());

            for page in pages {
                svg_pages.push(
                    inner
                        .document
                        .render_page_svg_native(page)
                        .map_err(error_to_string)?,
                );
            }

            rhwp_core::renderer::pdf::svgs_to_pdf(&svg_pages)
        }
    }

    pub fn export_docx(&self) -> Result<Vec<u8>, String> {
        let inner = self.lock()?;
        let pages = selected_pages(inner.document.page_count(), None)?;
        let mut output = Vec::with_capacity(pages.len());

        for page in pages {
            output.push(
                inner
                    .document
                    .extract_page_text_native(page)
                    .map_err(error_to_string)?,
            );
        }

        build_docx(
            &output.join("\n\n"),
            inner.file_name.as_deref().unwrap_or("document.hwp"),
        )
    }

    pub fn apply_command(&self, command_json: String) -> Result<String, String> {
        let command: RhwpCommand =
            serde_json::from_str(&command_json).map_err(|error| error.to_string())?;
        let mut inner = self.lock()?;

        match command {
            RhwpCommand::InsertText {
                section,
                paragraph,
                offset,
                text,
            } => inner
                .document
                .insert_text_native(section as usize, paragraph as usize, offset as usize, &text)
                .map_err(error_to_string),
            RhwpCommand::DeleteText {
                section,
                paragraph,
                offset,
                count,
            } => inner
                .document
                .delete_text_native(
                    section as usize,
                    paragraph as usize,
                    offset as usize,
                    count as usize,
                )
                .map_err(error_to_string),
            RhwpCommand::SetFileName { name } => {
                inner.document.set_file_name(&name);
                inner.file_name = Some(name);
                Ok("{\"ok\":true}".to_string())
            }
        }
    }

    pub fn close(&self) -> Result<(), String> {
        let _guard = self.lock()?;
        Ok(())
    }

    fn lock(&self) -> Result<MutexGuard<'_, RhwpSessionInner>, String> {
        self.inner
            .lock()
            .map_err(|_| "rhwp session lock was poisoned".to_string())
    }
}

pub fn open_bytes(bytes: Vec<u8>, file_name: Option<String>) -> Result<RhwpSession, String> {
    let mut document = HwpDocument::from_bytes(&bytes).map_err(error_to_string)?;
    if let Some(name) = file_name.as_deref() {
        document.set_file_name(name);
    }

    Ok(RhwpSession {
        inner: Mutex::new(RhwpSessionInner {
            document,
            file_name,
        }),
    })
}

pub fn create_empty(file_name: Option<String>) -> RhwpSession {
    let mut document = HwpDocument::create_empty();
    if let Some(name) = file_name.as_deref() {
        document.set_file_name(name);
    }

    RhwpSession {
        inner: Mutex::new(RhwpSessionInner {
            document,
            file_name,
        }),
    }
}

pub fn rhwp_version() -> String {
    rhwp_core::version()
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
enum RhwpCommand {
    InsertText {
        section: u32,
        paragraph: u32,
        offset: u32,
        text: String,
    },
    DeleteText {
        section: u32,
        paragraph: u32,
        offset: u32,
        count: u32,
    },
    SetFileName {
        name: String,
    },
}

fn selected_pages(page_count: u32, page: Option<u32>) -> Result<Vec<u32>, String> {
    if page_count == 0 {
        return Err("document has no pages".to_string());
    }

    match page {
        Some(page) if page >= page_count => Err(format!(
            "page index {page} is out of range; expected 0..{}",
            page_count - 1
        )),
        Some(page) => Ok(vec![page]),
        None => Ok((0..page_count).collect()),
    }
}

fn error_to_string(error: impl std::fmt::Display) -> String {
    error.to_string()
}

fn build_docx(text: &str, title: &str) -> Result<Vec<u8>, String> {
    let mut writer = ZipWriter::new(Cursor::new(Vec::new()));
    let options = SimpleFileOptions::default()
        .compression_method(CompressionMethod::Deflated)
        .last_modified_time(DateTime::default());

    write_zip_entry(
        &mut writer,
        "[Content_Types].xml",
        CONTENT_TYPES_XML,
        options,
    )?;
    write_zip_entry(&mut writer, "_rels/.rels", ROOT_RELS_XML, options)?;
    write_zip_entry(
        &mut writer,
        "docProps/core.xml",
        &docx_core_properties(title),
        options,
    )?;
    write_zip_entry(&mut writer, "docProps/app.xml", APP_PROPERTIES_XML, options)?;
    write_zip_entry(&mut writer, "word/styles.xml", STYLES_XML, options)?;
    write_zip_entry(
        &mut writer,
        "word/document.xml",
        &docx_document_xml(text),
        options,
    )?;

    writer
        .finish()
        .map(|cursor| cursor.into_inner())
        .map_err(error_to_string)
}

fn write_zip_entry(
    writer: &mut ZipWriter<Cursor<Vec<u8>>>,
    name: &str,
    data: &str,
    options: SimpleFileOptions,
) -> Result<(), String> {
    writer.start_file(name, options).map_err(error_to_string)?;
    writer.write_all(data.as_bytes()).map_err(error_to_string)
}

fn docx_document_xml(text: &str) -> String {
    let mut body = String::new();
    let normalized = text.replace("\r\n", "\n").replace('\r', "\n");

    if normalized.is_empty() {
        body.push_str("<w:p/>");
    } else {
        for line in normalized.split('\n') {
            body.push_str("<w:p>");
            if !line.is_empty() {
                body.push_str("<w:r><w:t xml:space=\"preserve\">");
                body.push_str(&escape_xml_text(&line.replace('\t', "    ")));
                body.push_str("</w:t></w:r>");
            }
            body.push_str("</w:p>");
        }
    }

    format!(
        r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    {body}
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>"#
    )
}

fn docx_core_properties(title: &str) -> String {
    format!(
        r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>{}</dc:title>
  <dc:creator>flutter_rhwp</dc:creator>
  <cp:lastModifiedBy>flutter_rhwp</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">1980-01-01T00:00:00Z</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">1980-01-01T00:00:00Z</dcterms:modified>
</cp:coreProperties>"#,
        escape_xml_text(title)
    )
}

fn escape_xml_text(source: &str) -> String {
    let mut escaped = String::with_capacity(source.len());
    for ch in source.chars() {
        match ch {
            '&' => escaped.push_str("&amp;"),
            '<' => escaped.push_str("&lt;"),
            '>' => escaped.push_str("&gt;"),
            '"' => escaped.push_str("&quot;"),
            '\'' => escaped.push_str("&apos;"),
            '\u{9}' | '\u{A}' | '\u{D}' => escaped.push(ch),
            '\u{0}'..='\u{8}' | '\u{B}' | '\u{C}' | '\u{E}'..='\u{1F}' => {}
            _ => escaped.push(ch),
        }
    }
    escaped
}

const CONTENT_TYPES_XML: &str = r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>"#;

const ROOT_RELS_XML: &str = r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>"#;

const APP_PROPERTIES_XML: &str = r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>flutter_rhwp</Application>
</Properties>"#;

const STYLES_XML: &str = r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
  </w:style>
</w:styles>"#;

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Read;
    use zip::ZipArchive;

    const BLANK_2010_HWP: &[u8] = include_bytes!("../../vendor/rhwp/saved/blank2010.hwp");
    const EXAMPLE_ASSET_HWP: &[u8] =
        include_bytes!("../../../example/assets/korea_ai_action_plan_2026_2028.hwp");

    #[test]
    fn opens_vendored_sample_and_reports_metadata() {
        let session = open_bytes(BLANK_2010_HWP.to_vec(), Some("blank2010.hwp".to_string()))
            .expect("vendored sample should open");

        let info = session
            .document_info()
            .expect("document metadata should be available");

        assert!(info.page_count > 0);
        assert_eq!(info.file_name.as_deref(), Some("blank2010.hwp"));
        assert!(!info.source_format.is_empty());
        assert!(!info.raw_json.is_empty());
    }

    #[test]
    fn renders_and_extracts_vendored_sample() {
        let session =
            open_bytes(BLANK_2010_HWP.to_vec(), None).expect("vendored sample should open");

        let svg = session
            .render_page_svg(0)
            .expect("first page should render to SVG");
        assert!(svg.contains("<svg"));

        let layer_tree = session
            .page_layer_tree(0)
            .expect("first page layer tree should be available");
        assert!(!layer_tree.is_empty());

        session
            .extract_text(Some(0))
            .expect("first page text extraction should not fail");
        session
            .extract_markdown(Some(0))
            .expect("first page markdown extraction should not fail");
    }

    #[test]
    fn applies_commands_exports_and_reopens() {
        let session =
            open_bytes(BLANK_2010_HWP.to_vec(), None).expect("vendored sample should open");

        session
            .apply_command(
                r#"{"type":"insertText","section":0,"paragraph":0,"offset":0,"text":"rhwp"}"#
                    .to_string(),
            )
            .expect("insert text command should be accepted");

        let hwp = session.export_hwp().expect("HWP export should succeed");
        assert!(!hwp.is_empty());
        open_bytes(hwp, Some("roundtrip.hwp".to_string())).expect("exported HWP should reopen");

        let hwpx = session.export_hwpx().expect("HWPX export should succeed");
        assert!(!hwpx.is_empty());
        open_bytes(hwpx, Some("roundtrip.hwpx".to_string())).expect("exported HWPX should reopen");
    }

    #[test]
    #[cfg(not(target_arch = "wasm32"))]
    fn exports_pdf_bytes_on_native_targets() {
        let session =
            open_bytes(BLANK_2010_HWP.to_vec(), None).expect("vendored sample should open");

        let pdf = session.export_pdf().expect("PDF export should succeed");
        assert_pdf_structure(&pdf, session.page_count().expect("page count should load"));
    }

    #[test]
    fn exports_docx_package() {
        let session =
            open_bytes(BLANK_2010_HWP.to_vec(), None).expect("vendored sample should open");

        session
            .apply_command(
                r#"{"type":"insertText","section":0,"paragraph":0,"offset":0,"text":"rhwp docx"}"#
                    .to_string(),
            )
            .expect("insert text command should be accepted");

        let docx = session
            .export_docx()
            .expect("DOCX export should produce an OOXML package");
        assert!(docx.starts_with(b"PK"));

        let mut archive = ZipArchive::new(Cursor::new(docx)).expect("DOCX should be a ZIP file");
        archive
            .by_name("[Content_Types].xml")
            .expect("DOCX should include content types");

        let mut document_xml = String::new();
        archive
            .by_name("word/document.xml")
            .expect("DOCX should include word/document.xml")
            .read_to_string(&mut document_xml)
            .expect("document.xml should be UTF-8 text");

        assert!(document_xml.contains("<w:document"));
        assert!(document_xml.contains("rhwp docx"));
    }

    #[test]
    #[cfg(not(target_arch = "wasm32"))]
    fn exports_multipage_pdf_structure_from_svg_pages() {
        let svg_pages = vec![test_svg_page("#dc2626"), test_svg_page("#2563eb")];
        let pdf = rhwp_core::renderer::pdf::svgs_to_pdf(&svg_pages)
            .expect("multi-page SVG PDF export should succeed");

        assert_pdf_structure(&pdf, svg_pages.len() as u32);
    }

    #[test]
    fn opens_and_renders_example_asset() {
        let session = open_bytes(
            EXAMPLE_ASSET_HWP.to_vec(),
            Some("korea_ai_action_plan_2026_2028.hwp".to_string()),
        )
        .expect("example asset should open");

        assert!(session.page_count().expect("page count should load") > 0);
        assert!(session
            .render_page_svg(0)
            .expect("first page should render")
            .contains("<svg"));
        assert!(!session
            .extract_text(Some(0))
            .expect("first page text extraction should succeed")
            .trim()
            .is_empty());

        let hwp = session
            .export_hwp()
            .expect("example asset should export to HWP");
        open_bytes(hwp, Some("example-roundtrip.hwp".to_string()))
            .expect("example asset HWP export should reopen");

        let hwpx = session
            .export_hwpx()
            .expect("example asset should export to HWPX");
        open_bytes(hwpx, Some("example-roundtrip.hwpx".to_string()))
            .expect("example asset HWPX export should reopen");
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn assert_pdf_structure(pdf: &[u8], expected_page_count: u32) {
        assert!(
            pdf.starts_with(b"%PDF-"),
            "PDF should start with a version header"
        );
        assert!(
            pdf.windows(b"%%EOF".len()).any(|window| window == b"%%EOF"),
            "PDF should include an EOF marker"
        );

        let text = String::from_utf8_lossy(pdf);
        assert!(text.contains("startxref"), "PDF should include xref data");
        assert!(
            text.contains("/Type /Catalog") || text.contains("/Type/Catalog"),
            "PDF should include a catalog object"
        );

        let page_objects = count_pdf_page_objects(&text);
        assert_eq!(
            page_objects, expected_page_count as usize,
            "PDF page object count should match the source document"
        );
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn count_pdf_page_objects(text: &str) -> usize {
        text.match_indices("/Type /Page")
            .filter(|(index, _)| !text[*index + "/Type /Page".len()..].starts_with('s'))
            .count()
            + text
                .match_indices("/Type/Page")
                .filter(|(index, _)| !text[*index + "/Type/Page".len()..].starts_with('s'))
                .count()
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn test_svg_page(fill: &str) -> String {
        format!(
            r##"<svg xmlns="http://www.w3.org/2000/svg" width="240" height="180" viewBox="0 0 240 180">
  <rect width="240" height="180" fill="#ffffff"/>
  <rect x="24" y="24" width="192" height="132" fill="{fill}"/>
</svg>"##
        )
    }
}
