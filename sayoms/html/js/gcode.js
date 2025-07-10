function generateGCode(comp) {
  const name = comp.full_path.replace(/[^a-zA-Z0-9-_]/g, "_");
  const L = cleanNumeric(comp.length);
  const W = cleanNumeric(comp.width);
  const D = cleanNumeric(comp.thickness);

  const precage = [`L${L.toFixed(3)} W${W.toFixed(3)} D${D.toFixed(3)}`];
  const horizontal = [];
  const o2Generated = new Set();

  function addHardwareLines(children, parentLength, parentWidth, parentThickness) {
    children.forEach(child => {
      if (child.material_type === 5 && child.origin) {
        const matName = child.material_name || "(Sans nom)";
        const isO2 = matName.trim().toUpperCase() === "O2 T1";
        let x = cleanNumeric(child.origin.x);
        let y = cleanNumeric(child.origin.y);
        const z = parentThickness;
        const halfZ = (z / 2).toFixed(1);

if (isO2) {
  if (child.orientation === "longueur") {
    // x fixe, y de 0 → 30
    horizontal.push(`O4 T1`);
    horizontal.push(`F0`);
    horizontal.push(`G0 X${Math.round(x)} Y0 Z${z}`);     // Départ en bas
    horizontal.push(`G1 X${Math.round(x)} Y30 Z${halfZ}`); // Avance en Y
  } else if (child.orientation === "largeur") {
    // y fixe, x de 0 → 30
    horizontal.push(`O2 T1`);
    horizontal.push(`F0`);
    horizontal.push(`G0 X0 Y${Math.round(y)} Z${z}`);
    horizontal.push(`G1 X30 Y${Math.round(y)} Z${halfZ}`);
  }
}


        else {
          if (child.orientation === "largeur") {
            const EPSILON = 0.5;

            const xRaw = cleanNumeric(child.origin.x);
            const y = Math.round(cleanNumeric(child.origin.y));
            const z = cleanNumeric(parentThickness);
            const L = cleanNumeric(parentLength);
            const halfZ = (z / 2).toFixed(1);

            const isLeft = Math.abs(xRaw) < EPSILON;
            const isRight = Math.abs(xRaw - L) < EPSILON;

            console.log(`🧪 O1 T1 largeur — x=${xRaw}, y=${y}, L=${L}, isLeft=${isLeft}, isRight=${isRight}`);

            // Détermine la position X à percer
            let xPos;
            if (isLeft) {
              xPos = 32;
            } else if (isRight) {
              xPos = L - 32;
            } else {
              xPos = xRaw >= L / 2 ? L - 32 : 32;
            }

            // Génère le perçage O1 T1
            precage.push(`O1 T1`);
            precage.push(`F0`);
            precage.push(`G0 X${xPos} Y${y} Z${z}`);
            precage.push(`G1 X${xPos} Y${y} Z5`);

            // Génère O2 T1 une seule fois pour cette ligne Y
            const o2Key = `Y${y}`;
            if (!o2Generated.has(o2Key)) {
              horizontal.push(`O2 T1`);
              horizontal.push(`F0`);
              horizontal.push(`G0 X0 Y${y} Z${z}`);
              horizontal.push(`G1 X30 Y${y} Z${halfZ}`);
              o2Generated.add(o2Key);
            }

            // Si c’est à droite, ajouter O3 T1 (fin de ligne)
            if (isRight) {
              horizontal.push(`O3 T1`);
              horizontal.push(`F0`);
              horizontal.push(`G0 X${L} Y${y} Z${z}`);
              horizontal.push(`G1 X${L - 30} Y${y} Z${halfZ}`);
            }

          // ... tout le reste du code reste identique

          } else {
            x = Math.round(x);
            const isTop = y >= parentWidth / 2.0;
            const yPos = isTop ? Math.round(parentWidth - 32) : 32;

            precage.push("O1 T1", "F0", `G0 X${x} Y${yPos} Z${z}`, `G1 X${x} Y${yPos} Z${(z - 12).toFixed(1)}`);

            // ⚠️ Détection O5 T1 si perçage est en haut exactement
            const isExtremeTop = Math.abs(y - parentWidth) < 1; // tolérance 1 mm
            if (isExtremeTop) {
              horizontal.push("O5 T1", "F0");
              horizontal.push(`G0 X${x} Y${parentWidth} Z${z}`);
              horizontal.push(`G1 X${x} Y${parentWidth - 30} Z${halfZ}`);
            } else {
              horizontal.push("O4 T1", "F0");
              horizontal.push(`G0 X${x} Y0 Z${z}`);
              horizontal.push(`G1 X${x} Y30 Z${halfZ}`);
            }
          }

        }
      }
      if (child.children) {
        addHardwareLines(child.children, parentLength, parentWidth, parentThickness);
      }
    });
  }

  if (comp.children) addHardwareLines(comp.children, L, W, D);

  return {
    filename: name + ".txt",
    content: [...precage, ...horizontal].join("\n")
  };
}