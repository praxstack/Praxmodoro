// CSV export helpers. Cells that a spreadsheet would evaluate as a formula
// (leading = + - @, tab or carriage return) are prefixed with a single quote
// so opening the export in Excel, Numbers or Sheets cannot run anything.

const FORMULA_START = /^[=+\-@\t\r]/;

export function csvCell(value) {
  if (value === null || value === undefined) return "";
  let text = String(value);
  if (FORMULA_START.test(text)) text = `'${text}`;
  if (/[",\r\n]/.test(text)) text = `"${text.replaceAll('"', '""')}"`;
  return text;
}

export function toCsv(header, rows) {
  const lines = [header, ...rows].map((row) => row.map(csvCell).join(","));
  return `${lines.join("\r\n")}\r\n`;
}
