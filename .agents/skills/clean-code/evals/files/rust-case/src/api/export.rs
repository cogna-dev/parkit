use super::super::reporting::generate_invoice::{
    generate_invoice, normalize_customer_name, render_invoice_lines, Customer, InvoiceRow,
};

pub fn export_invoice(customers: &[Customer]) -> String {
    generate_invoice(customers, false)
}

pub fn export_invoice_preview(customers: &[Customer]) -> String {
    let labels = customers
        .iter()
        .map(normalize_customer_name)
        .collect::<Vec<_>>()
        .join(", ");
    let preview_rows = customers
        .iter()
        .map(|customer| InvoiceRow {
            label: normalize_customer_name(customer),
            joined_date: "preview".to_string(),
            discount: 0.0,
            spend: customer.total_spend,
        })
        .collect::<Vec<_>>();

    format!("{}\n{}", labels, render_invoice_lines(&preview_rows))
}
