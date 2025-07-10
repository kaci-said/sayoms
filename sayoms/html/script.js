// script.js

// 🔧 Nettoie une chaîne et extrait une valeur numérique (utile pour les valeurs comme "~ 95.75mm")
function cleanNumeric(val) {
  if (typeof val === "string") {
    const match = val.match(/[-+]?\d*\.?\d+/);
    return match ? parseFloat(match[0]) : null;
  }
  return typeof val === "number" ? val : null;
}

// 🔧 Formatte une valeur avec unité mm (ou retourne directement si elle est déjà approximative)
function formatDim(val) {
  if (val === undefined || val === null) return "?";
  if (typeof val === "string" && val.includes("~")) return val;
  const num = parseFloat(val);
  return isNaN(num) ? val.toString() : (num).toFixed(2) + " mm";
}

// Types de matériaux OCL
const MATERIAL_TYPES = {
  0: "Inconnu",
  1: "Bois massif",
  2: "Panneau",
  3: "Bois standard",
  4: "Chant",
  5: "Quincaillerie",
  6: "Placage"
};

function updateData(data) {
  const filteredData = data;

  const materialsTableBody = document.querySelector("#materialsTable tbody");
  materialsTableBody.innerHTML = "";

  const tree = document.getElementById("componentTree");
  tree.innerHTML = "";

  if (!filteredData || filteredData.length === 0) {
    document.querySelector(".info p").textContent = "❌ Aucun composant trouvé.";
    return;
  }

  const materials = {};

  function createComponentItem(comp) {
    let text = `${comp.full_path} — `;

    if (comp.material_name) {
      text += `🩵 Matériau: ${comp.material_name}`;
      materials[comp.material_name] = (materials[comp.material_name] || 0) + 1;

      if (comp.material_type !== undefined) {
        const typeLabel = MATERIAL_TYPES[comp.material_type] || "Type inconnu";
        text += ` (${typeLabel})`;
      }
    }

    if (comp.material_type !== 5 && comp.length !== undefined && comp.width !== undefined && comp.thickness !== undefined) {
      text += ` → Dim: ${formatDim(comp.length)} x ${formatDim(comp.width)} x ${formatDim(comp.thickness)}`;
    }

    if (comp.origin) {
      const x = formatDim(comp.origin.x);
      const y = formatDim(comp.origin.y);
      const z = formatDim(comp.origin.z);
      text += ` → Pos: X=${x}, Y=${y}, Z=${z}`;
    }

    const item = document.createElement("li");
    item.textContent = text;

    if (comp.material_type === 5) {
      const orientItem = document.createElement("li");
      orientItem.textContent = `⇄️ Orientation : ${comp.orientation || "inconnue"}`;
      item.appendChild(document.createElement("br"));
      item.appendChild(orientItem);
    }

    if (comp.material_type === 2) {
      const btn = document.createElement("button");
      btn.textContent = "📄 Exporter TXT";
      btn.classList.add("panel-button");

      btn.addEventListener("click", () => {
        const name = comp.full_path.replace(/[^a-zA-Z0-9-_]/g, "_");
        const L = cleanNumeric(comp.length);
        const W = cleanNumeric(comp.width);
        const D = cleanNumeric(comp.thickness);

        const precage = [`L${L.toFixed(3)} W${W.toFixed(3)} D${D.toFixed(3)}`];
        const horizontal = [];
        const o2Generated = new Set();

        // Fonction récursive de génération G-code
        function addHardwareLines(children, parentLength, parentWidth, parentThickness) {
          children.forEach(child => {
            if (child.material_type === 5 && child.origin) {
              const matName = child.material_name || "(Sans nom)";
              const isO2 = matName.trim().toUpperCase() === "O2 T1";

              const x = cleanNumeric(child.origin.x);
              const y = cleanNumeric(child.origin.y);
              const z = cleanNumeric(parentThickness);
              const L = cleanNumeric(parentLength);
              const W = cleanNumeric(parentWidth);
              const halfZ = (z / 2).toFixed(1);
              const EPSILON = 0.5;

              if (isO2) {
                if (child.orientation === "longueur") {
                  horizontal.push(`O2 T1`, "F0", `G0 X${Math.round(x)} Y30 Z${z}`, `G1 X${Math.round(x)} Y30 Z${halfZ}`);
                } else if (child.orientation === "largeur") {
                  horizontal.push(`O2 T1`, "F0", `G0 X30 Y${Math.round(y)} Z${z}`, `G1 X30 Y${Math.round(y)} Z${halfZ}`);
                }
              } else if (child.orientation === "largeur") {
                const yRounded = Math.round(y);
                const isLeft = Math.abs(x) < EPSILON;
                const isRight = Math.abs(x - L) < EPSILON;

                if (isLeft) {
                  precage.push(`O1 T1`, "F0", `G0 X32 Y${yRounded} Z${z}`, `G1 X32 Y${yRounded} Z5`);
                } else if (isRight) {
                  const xPos = L - 32;
                  precage.push(`O1 T1`, "F0", `G0 X${xPos} Y${yRounded} Z${z}`, `G1 X${xPos} Y${yRounded} Z5`);
                } else {
                  const isRightHalf = x >= L / 2.0;
                  const xPos = isRightHalf ? L - 32 : 32;
                  precage.push(`O1 T1`, "F0", `G0 X${xPos} Y${yRounded} Z${z}`, `G1 X${xPos} Y${yRounded} Z${(z - 12).toFixed(1)}`);
                }

                const o2Key = `Y${yRounded}`;
                if (!o2Generated.has(o2Key)) {
                  horizontal.push(`O2 T1`, "F0", `G0 X0 Y${yRounded} Z${z}`, `G1 X30 Y${yRounded} Z${halfZ}`);
                  o2Generated.add(o2Key);
                }

                if (isRight) {
                  horizontal.push(`O3 T1`, "F0", `G0 X${L} Y${yRounded} Z${z}`, `G1 X${L - 30} Y${yRounded} Z${halfZ}`);
                }
              } else if (child.orientation === "longueur") {
                const xRounded = Math.round(x);
                const isTop = y >= W / 2.0;
                const yPos = isTop ? W - 32 : 32;

                precage.push(`O1 T1`, "F0", `G0 X${xRounded} Y${yPos} Z${z}`, `G1 X${xRounded} Y${yPos} Z${(z - 12).toFixed(1)}`);
                horizontal.push(`O4 T1`, "F0");
                if (isTop) {
                  horizontal.push(`G0 X${xRounded} Y${W} Z${z}`, `G1 X${xRounded} Y${W - 30} Z${halfZ}`);
                } else {
                  horizontal.push(`G0 X${xRounded} Y0 Z${z}`, `G1 X${xRounded} Y30 Z${halfZ}`);
                }
              }
            }

            if (child.children) addHardwareLines(child.children, parentLength, parentWidth, parentThickness);
          });
        }

        if (comp.children) addHardwareLines(comp.children, L, W, D);

        const content = [...precage, ...horizontal].join("\n");
        const filename = name + ".txt";

        const blob = new Blob([content], { type: "text/plain;charset=utf-8" });
        const link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      });

      item.appendChild(document.createTextNode(" "));
      item.appendChild(btn);
    }

    if (comp.children && comp.children.length > 0) {
      const subList = document.createElement("ul");
      comp.children.forEach(child => {
        subList.appendChild(createComponentItem(child));
      });
      item.appendChild(subList);
    }

    return item;
  }

  filteredData.forEach(comp => {
    const mainItem = createComponentItem(comp);
    tree.appendChild(mainItem);
  });

  for (const materialName in materials) {
    const row = document.createElement("tr");
    const nameCell = document.createElement("td");
    nameCell.textContent = materialName;
    const quantityCell = document.createElement("td");
    quantityCell.textContent = materials[materialName];
    row.appendChild(nameCell);
    row.appendChild(quantityCell);
    materialsTableBody.appendChild(row);
  }

  document.querySelector(".info p").textContent = `✅ ${filteredData.length} composant(s) trouvés.`;
}

// Communication SketchUp → WebDialog
window.addEventListener("message", function(event) {
  const message = event.data;
  if (message.action === "su_action" && message.type === "updateData") {
    updateData(message.data);
  }
});

// Requête initiale à SketchUp au chargement
function requestComponentData() {
  window.parent.postMessage({
    action: "su_action",
    type: "requestData"
  }, "*");
}

window.onload = () => {
  requestComponentData();
};
