use std::sync::{Mutex, MutexGuard};

use serde::Deserialize;

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
        let _ = self;
        Err("DOCX export is not implemented in rhwp v0.7.12".to_string())
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
