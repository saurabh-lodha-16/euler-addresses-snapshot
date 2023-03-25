const fs = require("fs");
const csv = require("csv-parser");

const inputFilePath = "account_statuses.csv";
const outputFilePath = "output.json";

const outputData = [];

fs.createReadStream(inputFilePath)
  .pipe(csv())
  .on("data", (row) => {
    // divide collateral and liability by 1e18 and keep them as strings
    const collateralValue = (
      parseFloat(row["Collateral Value"]) / 1e18
    ).toString();
    const liabilityValue = (
      parseFloat(row["Liability Value"]) / 1e18
    ).toString();

    // check if health factor is equal to infinity and update it accordingly
    const healthFactor =
      row["Health Factor"] ===
      "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        ? "∞"
        : parseFloat(row["Health Factor"]) / 1e18;

    // create a new object with updated values and push it to outputData array
    const newData = {
      Address: row.Address.toLowerCase(),
      "Collateral Value": collateralValue,
      "Liability Value": liabilityValue,
      "Health Factor": healthFactor,
    };
    outputData.push(newData);
  })
  .on("end", () => {
    // write the output data to a JSON file
    fs.writeFile(outputFilePath, JSON.stringify(outputData), (err) => {
      if (err) {
        console.error(err);
      } else {
        console.log(
          `Successfully converted ${outputData.length} rows to JSON and saved to ${outputFilePath}`
        );
      }
    });
  })
  .on("error", (err) => {
    console.error(err);
  });
