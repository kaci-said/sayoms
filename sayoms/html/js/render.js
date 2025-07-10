function updateData(data) {
  const materialsTableBody = document.querySelector("#materialsTable tbody");
  materialsTableBody.innerHTML = "";

  const tree = document.getElementById("componentTree");
  tree.innerHTML = "";

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

    if (comp.material_type !== 5) {
      text += ` → Dim: ${formatDim(comp.length)} x ${formatDim(comp.width)} x ${formatDim(comp.thickness)}`;
    }

    if (comp.origin) {
      text += ` → Pos: X=${formatDim(comp.origin.x)}, Y=${formatDim(comp.origin.y)}, Z=${formatDim(comp.origin.z)}`;
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
        const gcode = generateGCode(comp);
        const blob = new Blob([gcode.content], { type: "text/plain;charset=utf-8" });
        const link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = gcode.filename;
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

  data.forEach(comp => {
    tree.appendChild(createComponentItem(comp));
  });

  for (const materialName in materials) {
    const row = document.createElement("tr");
    row.innerHTML = `<td>${materialName}</td><td>${materials[materialName]}</td>`;
    materialsTableBody.appendChild(row);
  }

  document.querySelector(".info p").textContent = `✅ ${data.length} composant(s) trouvés.`;
}