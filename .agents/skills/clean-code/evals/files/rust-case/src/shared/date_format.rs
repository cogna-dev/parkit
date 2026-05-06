pub fn format_invoice_date(raw: &str) -> String {
    raw.split('T').next().unwrap_or(raw).to_string()
}
