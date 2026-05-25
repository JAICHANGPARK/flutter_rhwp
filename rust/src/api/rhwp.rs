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
            let markdown = inner
                .document
                .extract_page_markdown_native(page)
                .map_err(error_to_string)?;
            if markdown.trim().is_empty() {
                output.push(
                    inner
                        .document
                        .extract_page_text_native(page)
                        .map_err(error_to_string)?,
                );
            } else {
                output.push(markdown);
            }
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
            RhwpCommand::InsertTextInTableCell {
                section,
                paragraph,
                control_index,
                cell_index,
                cell_paragraph,
                offset,
                text,
            } => inner
                .document
                .insert_text_in_cell_native(
                    section as usize,
                    paragraph as usize,
                    control_index as usize,
                    cell_index as usize,
                    cell_paragraph as usize,
                    offset as usize,
                    &text,
                )
                .map_err(error_to_string),
            RhwpCommand::DeleteTextInTableCell {
                section,
                paragraph,
                control_index,
                cell_index,
                cell_paragraph,
                offset,
                count,
            } => inner
                .document
                .delete_text_in_cell_native(
                    section as usize,
                    paragraph as usize,
                    control_index as usize,
                    cell_index as usize,
                    cell_paragraph as usize,
                    offset as usize,
                    count as usize,
                )
                .map_err(error_to_string),
            RhwpCommand::DeleteRange {
                section,
                start_paragraph,
                start_offset,
                end_paragraph,
                end_offset,
            } => inner
                .document
                .delete_range_native(
                    section as usize,
                    start_paragraph as usize,
                    start_offset as usize,
                    end_paragraph as usize,
                    end_offset as usize,
                    None,
                )
                .map_err(error_to_string),
            RhwpCommand::SplitParagraph {
                section,
                paragraph,
                offset,
            } => inner
                .document
                .split_paragraph_native(section as usize, paragraph as usize, offset as usize)
                .map_err(error_to_string),
            RhwpCommand::InsertTable {
                section,
                paragraph,
                offset,
                rows,
                columns,
            } => {
                let row_count =
                    u16::try_from(rows).map_err(|_| "rows must fit in u16".to_string())?;
                let column_count =
                    u16::try_from(columns).map_err(|_| "columns must fit in u16".to_string())?;
                inner
                    .document
                    .create_table_native(
                        section as usize,
                        paragraph as usize,
                        offset as usize,
                        row_count,
                        column_count,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::InsertTableRow {
                section,
                paragraph,
                control_index,
                row,
                below,
            } => {
                let row_index =
                    u16::try_from(row).map_err(|_| "row must fit in u16".to_string())?;
                inner
                    .document
                    .insert_table_row_native(
                        section as usize,
                        paragraph as usize,
                        control_index as usize,
                        row_index,
                        below,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::InsertTableColumn {
                section,
                paragraph,
                control_index,
                column,
                right,
            } => {
                let column_index =
                    u16::try_from(column).map_err(|_| "column must fit in u16".to_string())?;
                inner
                    .document
                    .insert_table_column_native(
                        section as usize,
                        paragraph as usize,
                        control_index as usize,
                        column_index,
                        right,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::DeleteTableRow {
                section,
                paragraph,
                control_index,
                row,
            } => {
                let row_index =
                    u16::try_from(row).map_err(|_| "row must fit in u16".to_string())?;
                inner
                    .document
                    .delete_table_row_native(
                        section as usize,
                        paragraph as usize,
                        control_index as usize,
                        row_index,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::DeleteTableColumn {
                section,
                paragraph,
                control_index,
                column,
            } => {
                let column_index =
                    u16::try_from(column).map_err(|_| "column must fit in u16".to_string())?;
                inner
                    .document
                    .delete_table_column_native(
                        section as usize,
                        paragraph as usize,
                        control_index as usize,
                        column_index,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::MergeTableCells {
                section,
                paragraph,
                control_index,
                start_row,
                start_column,
                end_row,
                end_column,
            } => {
                let start_row =
                    u16::try_from(start_row).map_err(|_| "startRow must fit in u16".to_string())?;
                let start_column = u16::try_from(start_column)
                    .map_err(|_| "startColumn must fit in u16".to_string())?;
                let end_row =
                    u16::try_from(end_row).map_err(|_| "endRow must fit in u16".to_string())?;
                let end_column = u16::try_from(end_column)
                    .map_err(|_| "endColumn must fit in u16".to_string())?;
                inner
                    .document
                    .merge_table_cells_native(
                        section as usize,
                        paragraph as usize,
                        control_index as usize,
                        start_row,
                        start_column,
                        end_row,
                        end_column,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::SplitTableCell {
                section,
                paragraph,
                control_index,
                row,
                column,
            } => {
                let row_index =
                    u16::try_from(row).map_err(|_| "row must fit in u16".to_string())?;
                let column_index =
                    u16::try_from(column).map_err(|_| "column must fit in u16".to_string())?;
                inner
                    .document
                    .split_table_cell_native(
                        section as usize,
                        paragraph as usize,
                        control_index as usize,
                        row_index,
                        column_index,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::DeleteObjectControl {
                section,
                paragraph,
                control_index,
                object_type,
            } => delete_object_control(
                &mut inner.document,
                section as usize,
                paragraph as usize,
                control_index as usize,
                &object_type,
            ),
            RhwpCommand::ChangeObjectZOrder {
                section,
                paragraph,
                control_index,
                object_type,
                operation,
            } => change_object_z_order(
                &mut inner.document,
                section as usize,
                paragraph as usize,
                control_index as usize,
                &object_type,
                &operation,
            ),
            RhwpCommand::GetObjectProperties {
                section,
                paragraph,
                control_index,
                object_type,
            } => get_object_properties(
                &inner.document,
                section as usize,
                paragraph as usize,
                control_index as usize,
                &object_type,
            ),
            RhwpCommand::SetObjectProperties {
                section,
                paragraph,
                control_index,
                object_type,
                properties,
            } => {
                let properties_json = properties.to_string();
                set_object_properties(
                    &mut inner.document,
                    section as usize,
                    paragraph as usize,
                    control_index as usize,
                    &object_type,
                    &properties_json,
                )
            }
            RhwpCommand::ApplyCharFormat {
                section,
                paragraph,
                start_offset,
                end_offset,
                properties,
            } => {
                let properties_json = properties.to_string();
                inner
                    .document
                    .apply_char_format_native(
                        section as usize,
                        paragraph as usize,
                        start_offset as usize,
                        end_offset as usize,
                        &properties_json,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::ApplyCharFormatRange {
                section,
                start_paragraph,
                start_offset,
                end_paragraph,
                end_offset,
                properties,
            } => {
                let properties_json = properties.to_string();
                inner
                    .document
                    .apply_char_format_range_native(
                        section as usize,
                        start_paragraph as usize,
                        start_offset as usize,
                        end_paragraph as usize,
                        end_offset as usize,
                        &properties_json,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::ApplyCharFormatInTableCell {
                section,
                paragraph,
                control_index,
                cell_index,
                cell_paragraph,
                start_offset,
                end_offset,
                properties,
            } => {
                let properties_json = properties.to_string();
                inner
                    .document
                    .apply_char_format_in_cell_native(
                        section as usize,
                        paragraph as usize,
                        control_index as usize,
                        cell_index as usize,
                        cell_paragraph as usize,
                        start_offset as usize,
                        end_offset as usize,
                        &properties_json,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::ApplyParaFormat {
                section,
                paragraph,
                properties,
            } => {
                let properties_json = properties.to_string();
                inner
                    .document
                    .apply_para_format_native(
                        section as usize,
                        paragraph as usize,
                        &properties_json,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::ApplyParaFormatRange {
                section,
                start_paragraph,
                end_paragraph,
                properties,
            } => {
                let properties_json = properties.to_string();
                inner
                    .document
                    .apply_para_format_range_native(
                        section as usize,
                        start_paragraph as usize,
                        end_paragraph as usize,
                        &properties_json,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::ApplyParaFormatInTableCell {
                section,
                paragraph,
                control_index,
                cell_index,
                cell_paragraph,
                properties,
            } => {
                let properties_json = properties.to_string();
                inner
                    .document
                    .apply_para_format_in_cell_native(
                        section as usize,
                        paragraph as usize,
                        control_index as usize,
                        cell_index as usize,
                        cell_paragraph as usize,
                        &properties_json,
                    )
                    .map_err(error_to_string)
            }
            RhwpCommand::CreateHeaderFooter {
                section,
                is_header,
                apply_to,
            } => inner
                .document
                .create_header_footer_native(section as usize, is_header, apply_to as u8)
                .map_err(error_to_string),
            RhwpCommand::SaveSnapshot => {
                let snapshot_id = inner.document.save_snapshot_native();
                Ok(format!("{{\"ok\":true,\"snapshotId\":{snapshot_id}}}"))
            }
            RhwpCommand::RestoreSnapshot { snapshot_id } => inner
                .document
                .restore_snapshot_native(snapshot_id)
                .map_err(error_to_string),
            RhwpCommand::DiscardSnapshot { snapshot_id } => {
                inner.document.discard_snapshot_native(snapshot_id);
                Ok("{\"ok\":true}".to_string())
            }
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
    InsertTextInTableCell {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        #[serde(rename = "cellIndex")]
        cell_index: u32,
        #[serde(rename = "cellParagraph")]
        cell_paragraph: u32,
        offset: u32,
        text: String,
    },
    DeleteTextInTableCell {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        #[serde(rename = "cellIndex")]
        cell_index: u32,
        #[serde(rename = "cellParagraph")]
        cell_paragraph: u32,
        offset: u32,
        count: u32,
    },
    DeleteRange {
        section: u32,
        #[serde(rename = "startParagraph")]
        start_paragraph: u32,
        #[serde(rename = "startOffset")]
        start_offset: u32,
        #[serde(rename = "endParagraph")]
        end_paragraph: u32,
        #[serde(rename = "endOffset")]
        end_offset: u32,
    },
    SplitParagraph {
        section: u32,
        paragraph: u32,
        offset: u32,
    },
    InsertTable {
        section: u32,
        paragraph: u32,
        offset: u32,
        rows: u32,
        columns: u32,
    },
    InsertTableRow {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        row: u32,
        below: bool,
    },
    InsertTableColumn {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        column: u32,
        right: bool,
    },
    DeleteTableRow {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        row: u32,
    },
    DeleteTableColumn {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        column: u32,
    },
    MergeTableCells {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        #[serde(rename = "startRow")]
        start_row: u32,
        #[serde(rename = "startColumn")]
        start_column: u32,
        #[serde(rename = "endRow")]
        end_row: u32,
        #[serde(rename = "endColumn")]
        end_column: u32,
    },
    SplitTableCell {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        row: u32,
        column: u32,
    },
    DeleteObjectControl {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        #[serde(rename = "objectType")]
        object_type: String,
    },
    ChangeObjectZOrder {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        #[serde(rename = "objectType")]
        object_type: String,
        operation: String,
    },
    GetObjectProperties {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        #[serde(rename = "objectType")]
        object_type: String,
    },
    SetObjectProperties {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        #[serde(rename = "objectType")]
        object_type: String,
        properties: serde_json::Value,
    },
    ApplyCharFormat {
        section: u32,
        paragraph: u32,
        #[serde(rename = "startOffset")]
        start_offset: u32,
        #[serde(rename = "endOffset")]
        end_offset: u32,
        properties: serde_json::Value,
    },
    ApplyCharFormatRange {
        section: u32,
        #[serde(rename = "startParagraph")]
        start_paragraph: u32,
        #[serde(rename = "startOffset")]
        start_offset: u32,
        #[serde(rename = "endParagraph")]
        end_paragraph: u32,
        #[serde(rename = "endOffset")]
        end_offset: u32,
        properties: serde_json::Value,
    },
    ApplyCharFormatInTableCell {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        #[serde(rename = "cellIndex")]
        cell_index: u32,
        #[serde(rename = "cellParagraph")]
        cell_paragraph: u32,
        #[serde(rename = "startOffset")]
        start_offset: u32,
        #[serde(rename = "endOffset")]
        end_offset: u32,
        properties: serde_json::Value,
    },
    ApplyParaFormat {
        section: u32,
        paragraph: u32,
        properties: serde_json::Value,
    },
    ApplyParaFormatRange {
        section: u32,
        #[serde(rename = "startParagraph")]
        start_paragraph: u32,
        #[serde(rename = "endParagraph")]
        end_paragraph: u32,
        properties: serde_json::Value,
    },
    ApplyParaFormatInTableCell {
        section: u32,
        paragraph: u32,
        #[serde(rename = "controlIndex")]
        control_index: u32,
        #[serde(rename = "cellIndex")]
        cell_index: u32,
        #[serde(rename = "cellParagraph")]
        cell_paragraph: u32,
        properties: serde_json::Value,
    },
    CreateHeaderFooter {
        section: u32,
        #[serde(rename = "isHeader")]
        is_header: bool,
        #[serde(rename = "applyTo")]
        apply_to: u32,
    },
    SaveSnapshot,
    RestoreSnapshot {
        #[serde(rename = "snapshotId")]
        snapshot_id: u32,
    },
    DiscardSnapshot {
        #[serde(rename = "snapshotId")]
        snapshot_id: u32,
    },
    SetFileName {
        name: String,
    },
}

fn delete_object_control(
    document: &mut HwpDocument,
    section: usize,
    paragraph: usize,
    control_index: usize,
    object_type: &str,
) -> Result<String, String> {
    let kind = object_type.to_ascii_lowercase();
    if matches!(kind.as_str(), "picture" | "image" | "img") {
        let picture_error =
            match document.delete_picture_control_native(section, paragraph, control_index) {
                Ok(result) => return Ok(result),
                Err(error) => error_to_string(error),
            };
        return document
            .delete_shape_control_native(section, paragraph, control_index)
            .map_err(|error| {
                format!(
                    "unsupported picture-like object control at section {section}, paragraph {paragraph}, control {control_index}; picture: {picture_error}; shape: {}",
                    error_to_string(error)
                )
            });
    }

    if matches!(kind.as_str(), "equation" | "formula") {
        return document
            .delete_equation_control_native(section, paragraph, control_index)
            .map_err(error_to_string);
    }

    if matches!(
        kind.as_str(),
        "shape"
            | "textbox"
            | "text_box"
            | "text box"
            | "rect"
            | "rectangle"
            | "ellipse"
            | "line"
            | "polygon"
            | "path"
            | "curve"
            | "arc"
            | "group"
            | "ole"
            | "chart"
    ) {
        return document
            .delete_shape_control_native(section, paragraph, control_index)
            .map_err(error_to_string);
    }

    let shape_error = match document.delete_shape_control_native(section, paragraph, control_index)
    {
        Ok(result) => return Ok(result),
        Err(error) => error_to_string(error),
    };
    let picture_error =
        match document.delete_picture_control_native(section, paragraph, control_index) {
            Ok(result) => return Ok(result),
            Err(error) => error_to_string(error),
        };
    let equation_error =
        match document.delete_equation_control_native(section, paragraph, control_index) {
            Ok(result) => return Ok(result),
            Err(error) => error_to_string(error),
        };

    Err(format!(
        "unsupported object control type '{object_type}' at section {section}, paragraph {paragraph}, control {control_index}; shape: {shape_error}; picture: {picture_error}; equation: {equation_error}"
    ))
}

fn change_object_z_order(
    document: &mut HwpDocument,
    section: usize,
    paragraph: usize,
    control_index: usize,
    object_type: &str,
    operation: &str,
) -> Result<String, String> {
    match operation {
        "front" | "back" | "forward" | "backward" => {}
        _ => {
            return Err(format!(
                "unsupported object z-order operation '{operation}'"
            ));
        }
    }

    let kind = object_type.to_ascii_lowercase();
    if matches!(
        kind.as_str(),
        "shape"
            | "textbox"
            | "text_box"
            | "text box"
            | "rect"
            | "rectangle"
            | "ellipse"
            | "line"
            | "polygon"
            | "path"
            | "curve"
            | "arc"
            | "group"
            | "ole"
            | "chart"
            | "picture"
            | "image"
            | "img"
    ) {
        return document
            .change_shape_z_order_native(section, paragraph, control_index, operation)
            .map_err(error_to_string);
    }

    document
        .change_shape_z_order_native(section, paragraph, control_index, operation)
        .map_err(|error| {
            format!(
                "unsupported object control type '{object_type}' for z-order at section {section}, paragraph {paragraph}, control {control_index}; shape: {}",
                error_to_string(error)
            )
        })
}

fn get_object_properties(
    document: &HwpDocument,
    section: usize,
    paragraph: usize,
    control_index: usize,
    object_type: &str,
) -> Result<String, String> {
    let kind = object_type.to_ascii_lowercase();
    if matches!(kind.as_str(), "picture" | "image" | "img") {
        let picture_error =
            match document.get_picture_properties_native(section, paragraph, control_index) {
                Ok(result) => return Ok(result),
                Err(error) => error_to_string(error),
            };
        return document
            .get_shape_properties_native(section, paragraph, control_index)
            .map_err(|error| {
                format!(
                    "unsupported picture-like object control at section {section}, paragraph {paragraph}, control {control_index}; picture: {picture_error}; shape: {}",
                    error_to_string(error)
                )
            });
    }

    if matches!(
        kind.as_str(),
        "shape"
            | "textbox"
            | "text_box"
            | "text box"
            | "rect"
            | "rectangle"
            | "ellipse"
            | "line"
            | "polygon"
            | "path"
            | "curve"
            | "arc"
            | "group"
            | "ole"
            | "chart"
    ) {
        return document
            .get_shape_properties_native(section, paragraph, control_index)
            .map_err(error_to_string);
    }

    let shape_error = match document.get_shape_properties_native(section, paragraph, control_index)
    {
        Ok(result) => return Ok(result),
        Err(error) => error_to_string(error),
    };
    let picture_error =
        match document.get_picture_properties_native(section, paragraph, control_index) {
            Ok(result) => return Ok(result),
            Err(error) => error_to_string(error),
        };

    Err(format!(
        "unsupported object control type '{object_type}' for properties at section {section}, paragraph {paragraph}, control {control_index}; shape: {shape_error}; picture: {picture_error}"
    ))
}

fn set_object_properties(
    document: &mut HwpDocument,
    section: usize,
    paragraph: usize,
    control_index: usize,
    object_type: &str,
    properties_json: &str,
) -> Result<String, String> {
    let kind = object_type.to_ascii_lowercase();
    if matches!(kind.as_str(), "picture" | "image" | "img") {
        let picture_error = match document.set_picture_properties_native(
            section,
            paragraph,
            control_index,
            properties_json,
        ) {
            Ok(result) => return Ok(result),
            Err(error) => error_to_string(error),
        };
        return document
            .set_shape_properties_native(section, paragraph, control_index, properties_json)
            .map_err(|error| {
                format!(
                    "unsupported picture-like object control at section {section}, paragraph {paragraph}, control {control_index}; picture: {picture_error}; shape: {}",
                    error_to_string(error)
                )
            });
    }

    if matches!(
        kind.as_str(),
        "shape"
            | "textbox"
            | "text_box"
            | "text box"
            | "rect"
            | "rectangle"
            | "ellipse"
            | "line"
            | "polygon"
            | "path"
            | "curve"
            | "arc"
            | "group"
            | "ole"
            | "chart"
    ) {
        return document
            .set_shape_properties_native(section, paragraph, control_index, properties_json)
            .map_err(error_to_string);
    }

    let shape_error = match document.set_shape_properties_native(
        section,
        paragraph,
        control_index,
        properties_json,
    ) {
        Ok(result) => return Ok(result),
        Err(error) => error_to_string(error),
    };
    let picture_error = match document.set_picture_properties_native(
        section,
        paragraph,
        control_index,
        properties_json,
    ) {
        Ok(result) => return Ok(result),
        Err(error) => error_to_string(error),
    };

    Err(format!(
        "unsupported object control type '{object_type}' for property update at section {section}, paragraph {paragraph}, control {control_index}; shape: {shape_error}; picture: {picture_error}"
    ))
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

#[derive(Debug, PartialEq, Eq)]
enum DocxBlock {
    Paragraph(String),
    Heading { level: u8, text: String },
    Table(Vec<Vec<String>>),
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

fn docx_document_xml(markdown: &str) -> String {
    let blocks = parse_markdown_blocks(markdown);
    let mut body = String::new();

    for block in blocks {
        body.push_str(&docx_block_xml(&block));
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

fn parse_markdown_blocks(markdown: &str) -> Vec<DocxBlock> {
    let normalized = markdown.replace("\r\n", "\n").replace('\r', "\n");
    if normalized.is_empty() {
        return vec![DocxBlock::Paragraph(String::new())];
    }

    let lines: Vec<&str> = normalized.split('\n').collect();
    let mut blocks = Vec::new();
    let mut index = 0;

    while index < lines.len() {
        let line = lines[index];
        let trimmed = line.trim();

        if trimmed.is_empty() {
            blocks.push(DocxBlock::Paragraph(String::new()));
            index += 1;
            continue;
        }

        if let Some((level, text)) = parse_markdown_heading(trimmed) {
            blocks.push(DocxBlock::Heading { level, text });
            index += 1;
            continue;
        }

        if index + 1 < lines.len() && is_markdown_table_separator(lines[index + 1]) {
            let header = split_markdown_table_row(line);
            if header.len() > 1 {
                let mut rows = vec![header];
                index += 2;
                while index < lines.len() {
                    let cells = split_markdown_table_row(lines[index]);
                    if cells.len() <= 1 {
                        break;
                    }
                    rows.push(cells);
                    index += 1;
                }
                blocks.push(DocxBlock::Table(rows));
                continue;
            }
        }

        blocks.push(DocxBlock::Paragraph(line.trim_end().to_string()));
        index += 1;
    }

    blocks
}

fn parse_markdown_heading(line: &str) -> Option<(u8, String)> {
    let hashes = line.chars().take_while(|ch| *ch == '#').count();
    if hashes == 0 || hashes > 6 || !line.chars().nth(hashes).is_some_and(|ch| ch == ' ') {
        return None;
    }

    Some((hashes as u8, line[hashes + 1..].trim().to_string()))
}

fn split_markdown_table_row(line: &str) -> Vec<String> {
    let trimmed = line.trim().trim_matches('|');
    if !trimmed.contains('|') {
        return Vec::new();
    }

    trimmed
        .split('|')
        .map(|cell| cell.trim().to_string())
        .collect()
}

fn is_markdown_table_separator(line: &str) -> bool {
    let cells = split_markdown_table_row(line);
    !cells.is_empty()
        && cells.iter().all(|cell| {
            let trimmed = cell.trim();
            trimmed.contains('-')
                && trimmed
                    .chars()
                    .all(|ch| ch == '-' || ch == ':' || ch.is_whitespace())
        })
}

fn docx_block_xml(block: &DocxBlock) -> String {
    match block {
        DocxBlock::Paragraph(text) => docx_paragraph_xml(None, text),
        DocxBlock::Heading { level, text } => {
            docx_paragraph_xml(Some(&format!("Heading{}", (*level).clamp(1, 6))), text)
        }
        DocxBlock::Table(rows) => docx_table_xml(rows),
    }
}

fn docx_paragraph_xml(style: Option<&str>, text: &str) -> String {
    let paragraph_properties = style
        .map(|style| format!(r#"<w:pPr><w:pStyle w:val="{style}"/></w:pPr>"#))
        .unwrap_or_default();

    if text.is_empty() {
        return format!("<w:p>{paragraph_properties}</w:p>");
    }

    format!(
        r#"<w:p>{paragraph_properties}<w:r><w:t xml:space="preserve">{}</w:t></w:r></w:p>"#,
        escape_xml_text(&text.replace('\t', "    "))
    )
}

fn docx_table_xml(rows: &[Vec<String>]) -> String {
    if rows.is_empty() {
        return String::new();
    }

    let column_count = rows.iter().map(Vec::len).max().unwrap_or(1).max(1);
    let column_width = 8640 / column_count;
    let mut xml = String::from(
        r#"<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders></w:tblPr><w:tblGrid>"#,
    );

    for _ in 0..column_count {
        xml.push_str(&format!(r#"<w:gridCol w:w="{column_width}"/>"#));
    }
    xml.push_str("</w:tblGrid>");

    for (row_index, row) in rows.iter().enumerate() {
        xml.push_str("<w:tr>");
        for column_index in 0..column_count {
            let cell = row.get(column_index).map(String::as_str).unwrap_or("");
            xml.push_str(&docx_table_cell_xml(cell, row_index == 0, column_width));
        }
        xml.push_str("</w:tr>");
    }

    xml.push_str("</w:tbl>");
    xml
}

fn docx_table_cell_xml(text: &str, is_header: bool, width: usize) -> String {
    let run_properties = if is_header {
        "<w:rPr><w:b/></w:rPr>"
    } else {
        ""
    };
    format!(
        r#"<w:tc><w:tcPr><w:tcW w:w="{width}" w:type="dxa"/></w:tcPr><w:p><w:r>{run_properties}<w:t xml:space="preserve">{}</w:t></w:r></w:p></w:tc>"#,
        escape_xml_text(&text.replace('\t', "    "))
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
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading4">
    <w:name w:val="heading 4"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading5">
    <w:name w:val="heading 5"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading6">
    <w:name w:val="heading 6"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
  </w:style>
</w:styles>"#;

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;
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
    fn page_layer_tree_json_exposes_editor_geometry_contract() {
        let session = open_bytes(
            EXAMPLE_ASSET_HWP.to_vec(),
            Some("korea_ai_action_plan_2026_2028.hwp".to_string()),
        )
        .expect("example asset should open");

        let layer_tree = session
            .page_layer_tree(0)
            .expect("first page layer tree should be available");
        let json: Value =
            serde_json::from_str(&layer_tree).expect("layer tree should be valid JSON");

        assert!(json["schemaVersion"].as_u64().is_some());
        assert!(json["pageWidth"].as_f64().unwrap_or_default() > 0.0);
        assert!(json["pageHeight"].as_f64().unwrap_or_default() > 0.0);
        assert_bbox(&json["root"]["bounds"]);

        let text_sources = json["textSources"]
            .as_array()
            .expect("layer tree should expose textSources");
        assert!(
            text_sources.iter().any(|source| {
                source["stableSourceKey"]
                    .as_str()
                    .is_some_and(is_stable_text_source_key)
            }),
            "at least one text source should map back to section/paragraph/char"
        );

        let text_run = find_text_run(&json["root"]).expect("layer tree should include textRun ops");
        assert_bbox(&text_run["bbox"]);
        assert!(text_run["text"].as_str().is_some());
        assert_text_range(&text_run["source"]["utf16Range"]);
        assert!(text_run["source"]["stableSourceKey"]
            .as_str()
            .is_some_and(is_stable_text_source_key));
        assert_transform(&text_run["placement"]["runToPage"]);
        assert!(
            text_run["clusters"].as_array().is_some(),
            "textRun should expose clusters as an array"
        );
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
        let snapshot_result = session
            .apply_command(r#"{"type":"saveSnapshot"}"#.to_string())
            .expect("save snapshot command should be accepted");
        let snapshot_result: Value =
            serde_json::from_str(&snapshot_result).expect("snapshot result should be JSON");
        let snapshot_id = snapshot_result["snapshotId"]
            .as_u64()
            .expect("snapshot result should include snapshotId");
        session
            .apply_command(
                r#"{"type":"insertText","section":0,"paragraph":0,"offset":4,"text":" temp"}"#
                    .to_string(),
            )
            .expect("temporary insert should be accepted");
        session
            .apply_command(format!(
                r#"{{"type":"restoreSnapshot","snapshotId":{snapshot_id}}}"#
            ))
            .expect("restore snapshot command should be accepted");
        session
            .apply_command(format!(
                r#"{{"type":"discardSnapshot","snapshotId":{snapshot_id}}}"#
            ))
            .expect("discard snapshot command should be accepted");
        session
            .apply_command(
                r##"{"type":"applyCharFormat","section":0,"paragraph":0,"startOffset":0,"endOffset":2,"properties":{"bold":true,"italic":true,"underline":true,"strikethrough":true,"fontSize":1250,"textColor":"#dc2626"}}"##
                    .to_string(),
            )
            .expect("apply char format command should be accepted");
        session
            .apply_command(
                r#"{"type":"splitParagraph","section":0,"paragraph":0,"offset":4}"#.to_string(),
            )
            .expect("split paragraph command should be accepted");
        session
            .apply_command(
                r#"{"type":"insertText","section":0,"paragraph":1,"offset":0,"text":"next"}"#
                    .to_string(),
            )
            .expect("second paragraph insert should be accepted");
        session
            .apply_command(
                r#"{"type":"applyCharFormatRange","section":0,"startParagraph":0,"startOffset":1,"endParagraph":1,"endOffset":2,"properties":{"bold":true}}"#
                    .to_string(),
            )
            .expect("apply char format range command should be accepted");
        session
            .apply_command(
                r#"{"type":"applyParaFormat","section":0,"paragraph":0,"properties":{"alignment":"center","lineSpacing":180,"lineSpacingType":"Percent","indent":120,"marginLeft":300,"marginRight":400,"spacingBefore":50,"spacingAfter":60}}"#
                    .to_string(),
            )
            .expect("apply para format command should be accepted");
        session
            .apply_command(
                r#"{"type":"applyParaFormatRange","section":0,"startParagraph":0,"endParagraph":1,"properties":{"alignment":"right","lineSpacing":200,"lineSpacingType":"Fixed","indent":-40,"marginLeft":100,"marginRight":200,"spacingBefore":10,"spacingAfter":20}}"#
                    .to_string(),
            )
            .expect("apply para format range command should be accepted");
        session
            .apply_command(
                r#"{"type":"applyParaFormatInTableCell","section":0,"paragraph":0,"controlIndex":0,"cellIndex":0,"cellParagraph":0,"properties":{"alignment":"center"}}"#
                    .to_string(),
            )
            .expect_err("apply para format in missing table cell should fail before table exists");
        session
            .apply_command(
                r#"{"type":"deleteRange","section":0,"startParagraph":0,"startOffset":2,"endParagraph":1,"endOffset":2}"#
                    .to_string(),
            )
            .expect("delete range command should be accepted");
        session
            .apply_command(
                r#"{"type":"createHeaderFooter","section":0,"isHeader":true,"applyTo":0}"#
                    .to_string(),
            )
            .expect("create header command should be accepted");
        session
            .apply_command(
                r#"{"type":"createHeaderFooter","section":0,"isHeader":false,"applyTo":0}"#
                    .to_string(),
            )
            .expect("create footer command should be accepted");
        let table_result = session
            .apply_command(
                r#"{"type":"insertTable","section":0,"paragraph":0,"offset":0,"rows":2,"columns":3}"#
                    .to_string(),
            )
            .expect("insert table command should be accepted");
        let table_result: Value =
            serde_json::from_str(&table_result).expect("table result should be valid JSON");
        let table_paragraph = table_result["paraIdx"]
            .as_u64()
            .expect("table insert result should expose paraIdx");
        let table_layer_tree = session
            .page_layer_tree(0)
            .expect("table layer tree should be available after insert");
        assert!(table_layer_tree.contains(r#""kind":"table""#));
        assert!(table_layer_tree.contains("\"paraIndex\":"));
        assert!(table_layer_tree.contains("\"controlIndex\":"));
        assert!(table_layer_tree.contains(r#""kind":"tableCell""#));
        session
            .apply_command(
                format!(
                    r#"{{"type":"insertTextInTableCell","section":0,"paragraph":{},"controlIndex":0,"cellIndex":0,"cellParagraph":0,"offset":0,"text":"cell"}}"#,
                    table_paragraph
                ),
            )
            .expect("insert text in table cell command should be accepted");
        session
            .apply_command(
                format!(
                    r##"{{"type":"applyCharFormatInTableCell","section":0,"paragraph":{},"controlIndex":0,"cellIndex":0,"cellParagraph":0,"startOffset":0,"endOffset":4,"properties":{{"bold":true,"fontSize":1100,"textColor":"#2563eb"}}}}"##,
                    table_paragraph
                ),
            )
            .expect("apply char format in table cell command should be accepted");
        session
            .apply_command(
                format!(
                    r#"{{"type":"applyParaFormatInTableCell","section":0,"paragraph":{},"controlIndex":0,"cellIndex":0,"cellParagraph":0,"properties":{{"alignment":"center","lineSpacing":180,"lineSpacingType":"Percent"}}}}"#,
                    table_paragraph
                ),
            )
            .expect("apply para format in table cell command should be accepted");
        session
            .apply_command(
                format!(
                    r#"{{"type":"deleteTextInTableCell","section":0,"paragraph":{},"controlIndex":0,"cellIndex":0,"cellParagraph":0,"offset":0,"count":1}}"#,
                    table_paragraph
                ),
            )
            .expect("delete text in table cell command should be accepted");
        session
            .apply_command(
                format!(
                    r#"{{"type":"mergeTableCells","section":0,"paragraph":{},"controlIndex":0,"startRow":0,"startColumn":0,"endRow":1,"endColumn":1}}"#,
                    table_paragraph
                ),
            )
            .expect("merge table cells command should be accepted");
        session
            .apply_command(
                format!(
                    r#"{{"type":"splitTableCell","section":0,"paragraph":{},"controlIndex":0,"row":0,"column":0}}"#,
                    table_paragraph
                ),
            )
            .expect("split table cell command should be accepted");
        session
            .apply_command(
                format!(
                    r#"{{"type":"insertTableRow","section":0,"paragraph":{},"controlIndex":0,"row":0,"below":true}}"#,
                    table_paragraph
                ),
            )
            .expect("insert table row command should be accepted");
        session
            .apply_command(
                format!(
                    r#"{{"type":"insertTableColumn","section":0,"paragraph":{},"controlIndex":0,"column":0,"right":true}}"#,
                    table_paragraph
                ),
            )
            .expect("insert table column command should be accepted");
        session
            .apply_command(
                format!(
                    r#"{{"type":"deleteTableRow","section":0,"paragraph":{},"controlIndex":0,"row":1}}"#,
                    table_paragraph
                ),
            )
            .expect("delete table row command should be accepted");
        session
            .apply_command(
                format!(
                    r#"{{"type":"deleteTableColumn","section":0,"paragraph":{},"controlIndex":0,"column":1}}"#,
                    table_paragraph
                ),
            )
            .expect("delete table column command should be accepted");
        let missing_object_result = session.apply_command(
            r#"{"type":"deleteObjectControl","section":0,"paragraph":0,"controlIndex":99,"objectType":"shape"}"#
                .to_string(),
        );
        assert!(
            missing_object_result.is_err(),
            "delete object command should route through the Rust facade"
        );
        let missing_object_z_order_result = session.apply_command(
            r#"{"type":"changeObjectZOrder","section":0,"paragraph":0,"controlIndex":99,"objectType":"shape","operation":"front"}"#
                .to_string(),
        );
        assert!(
            missing_object_z_order_result.is_err(),
            "object z-order command should route through the Rust facade"
        );
        let missing_object_properties_result = session.apply_command(
            r#"{"type":"getObjectProperties","section":0,"paragraph":0,"controlIndex":99,"objectType":"shape"}"#
                .to_string(),
        );
        assert!(
            missing_object_properties_result.is_err(),
            "object properties query should route through the Rust facade"
        );
        let missing_set_object_properties_result = session.apply_command(
            r#"{"type":"setObjectProperties","section":0,"paragraph":0,"controlIndex":99,"objectType":"shape","properties":{"width":1200,"height":2400,"horzOffset":80,"vertOffset":90}}"#
                .to_string(),
        );
        assert!(
            missing_set_object_properties_result.is_err(),
            "object properties update should route through the Rust facade"
        );

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
    fn docx_markdown_headings_and_tables_use_structured_ooxml() {
        let document_xml = docx_document_xml(
            "# Heading & One\n\n| Name | Value |\n| --- | --- |\n| A & B | <C> |\n\nAfter",
        );

        assert!(document_xml.contains(r#"<w:pStyle w:val="Heading1"/>"#));
        assert!(document_xml.contains("<w:tbl>"));
        assert!(document_xml.contains("<w:tblGrid>"));
        assert!(document_xml.contains("<w:b/>"));
        assert!(document_xml.contains("A &amp; B"));
        assert!(document_xml.contains("&lt;C&gt;"));
        assert!(document_xml.contains("After"));
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

    fn find_text_run(node: &Value) -> Option<&Value> {
        if let Some(ops) = node["ops"].as_array() {
            if let Some(op) = ops.iter().find(|op| op["type"].as_str() == Some("textRun")) {
                return Some(op);
            }
        }

        if let Some(children) = node["children"].as_array() {
            for child in children {
                if let Some(op) = find_text_run(child) {
                    return Some(op);
                }
            }
        }

        if node["child"].is_object() {
            return find_text_run(&node["child"]);
        }

        None
    }

    fn assert_bbox(value: &Value) {
        for key in ["x", "y", "width", "height"] {
            assert!(
                value[key].as_f64().is_some(),
                "bbox should include numeric {key}"
            );
        }
    }

    fn assert_text_range(value: &Value) {
        assert!(value["start"].as_u64().is_some());
        assert!(value["end"].as_u64().is_some());
    }

    fn assert_transform(value: &Value) {
        for key in ["a", "b", "c", "d", "e", "f"] {
            assert!(
                value[key].as_f64().is_some(),
                "runToPage should include numeric {key}"
            );
        }
    }

    fn is_stable_text_source_key(value: &str) -> bool {
        value.starts_with("section:") && value.contains("/para:") && value.contains("/char:")
    }
}
