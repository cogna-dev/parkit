use crate::shared::date_format::format_invoice_date;

#[derive(Clone, Debug)]
pub struct Customer {
    pub id: String,
    pub display_name: String,
    pub joined_at: String,
    pub active: bool,
    pub total_spend: f64,
}

#[derive(Clone, Debug)]
pub struct InvoiceRow {
    pub label: String,
    pub joined_date: String,
    pub discount: f64,
    pub spend: f64,
}

pub fn normalize_customer_name(customer: &Customer) -> String {
    customer
        .display_name
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

pub fn render_invoice_lines(rows: &[InvoiceRow]) -> String {
    let mut lines = vec!["label,joined_date,discount,spend".to_string()];

    lines.extend(rows.iter().map(|row| {
        format!(
            "{},{},{:.2},{:.2}",
            row.label, row.joined_date, row.discount, row.spend
        )
    }));

    lines.join("\n")
}

fn determine_discount(total_spend: f64) -> f64 {
    if total_spend >= 1000.0 {
        0.15
    } else if total_spend >= 500.0 {
        0.10
    } else {
        0.0
    }
}

pub fn generate_invoice(customers: &[Customer], include_inactive: bool) -> String {
    let mut rows = Vec::new();

    for customer in customers {
        if !include_inactive && !customer.active {
            continue;
        }

        rows.push(InvoiceRow {
            label: normalize_customer_name(customer),
            joined_date: format_invoice_date(&customer.joined_at),
            discount: determine_discount(customer.total_spend),
            spend: customer.total_spend,
        });
    }

    render_invoice_lines(&rows)
}
