function cleanNumeric(val) {
  if (typeof val === "string") {
    const match = val.match(/[-+]?\d*\.?\d+/);
    return match ? parseFloat(match[0]) : null;
  }
  return typeof val === "number" ? val : null;
}

function formatDim(val) {
  if (val === undefined || val === null) return "?";
  if (typeof val === "string" && val.includes("~")) return val;
  const num = parseFloat(val);
  return isNaN(num) ? val.toString() : (num).toFixed(2) + " mm";
}