const tableData = [
  {
    Address: "0x000000000000000000000000000000000000dead",
    "Collateral Value": 0,
    "Liability Value": 0,
    "Health Factor": 1.157920892373162e77,
  },
  {
    Address: "0x000000000000df8c944e775bde7af50300999282",
    "Collateral Value": 124192392051052050000,
    "Liability Value": 0,
    "Health Factor": 1.157920892373162e77,
  },
  {
    Address: "0x000000000000df8c944e775bde7af50300999283",
    "Collateral Value": 0,
    "Liability Value": 0,
    "Health Factor": 1.157920892373162e77,
  },
  {
    Address: "0x000000000002e33d9a86567c6dfe6d92f6777d1e",
    "Collateral Value": 0,
    "Liability Value": 0,
    "Health Factor": 1.157920892373162e77,
  },
  {
    Address: "0x00000000000747d525e898424e8774f7eb317d00",
    "Collateral Value": 0,
    "Liability Value": 0,
    "Health Factor": 1.157920892373162e77,
  },
  {
    Address: "0x000000000007d330338c8c9d3b9321e870acc85d",
    "Collateral Value": 0,
    "Liability Value": 0,
    "Health Factor": 1.157920892373162e77,
  },
  {
    Address: "0x00000000000970375ff38f05eb9d6db32ae40708",
    "Collateral Value": 0,
    "Liability Value": 0,
    "Health Factor": 1.157920892373162e77,
  },
  {
    Address: "0x00000000007cdeedd7f45c80ce479fff1c4e3791",
    "Collateral Value": 0,
    "Liability Value": 0,
    "Health Factor": 1.157920892373162e77,
  },
  {
    Address: "0x000000000097432da963a9d18c10763f302b1033",
    "Collateral Value": 0,
    "Liability Value": 0,
    "Health Factor": 1.157920892373162e77,
  },
  {
    Address: "0x0000000002732779240fe05873611dc4203dfb71",
    "Collateral Value": 0,
    "Liability Value": 0,
    "Health Factor": 1.157920892373162e77,
  },
];

function displayTableData(data) {
  const tableBody = document.getElementById("table-body");
  if (!tableBody) {
    console.error("Table body element not found");
    return;
  }
  tableBody.innerHTML = "";
  data.forEach((row) => {
    const tr = document.createElement("tr");
    Object.values(row).forEach((val, index) => {
      const td = document.createElement("td");
      if (index === 0) {
        td.classList.add("address-column");
        td.textContent = val;
      } else {
        let value = val;
        if (index === 1 || index === 2) {
          value = (value / 1e18).toFixed(4);
        }
        td.textContent = value;
        td.classList.add("numeric-column");
      }
      tr.appendChild(td);
    });
    tableBody.appendChild(tr);
  });
}

displayTableData(tableData);

const searchInput = document.getElementById("search-input");
if (!searchInput) {
  console.error("Search input element not found");
} else {
  searchInput.addEventListener("keyup", () => {
    const filter = searchInput.value.toUpperCase();
    const tableRows = document.querySelectorAll("#account-status-table tbody tr");
    tableRows.forEach((row) => {
      const address = row.getElementsByTagName("td")[0].textContent.toUpperCase();
      if (address.includes(filter)) {
        row.style.display = "";
      } else {
        row.style.display = "none";
      }
    });
  });
}
