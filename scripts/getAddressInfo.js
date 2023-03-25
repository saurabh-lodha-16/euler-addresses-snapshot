/* eslint-disable node/no-unsupported-features/es-syntax */
/* eslint-disable no-process-exit */
const hre = require("hardhat");
const fs = require("fs");
const ora = require("ora");

const EulerAddresses = {
  simpleLens: "0x5077B7642abF198b4a5b7C4BdCE4f03016C7089C",
  generalView: "0xACC25c4d40651676FEEd43a3467F3169e3E68e42",
  euler: "0x27182842E098f60e3D576794A5bFFb0777E025d3",
};

function readAddressesFromFile(filePath) {
  return new Promise((resolve, reject) => {
    fs.readFile(filePath, "utf8", (err, data) => {
      if (err) {
        reject(err);
      } else {
        const addresses = data.split("\n");
        resolve(addresses);
      }
    });
  });
}

function saveAccountStatusesToCsv(filename, data) {
  return new Promise((resolve, reject) => {
    const header = "Address,Collateral Value,Liability Value,Health Factor\n";
    const rows = data
      .map(
        (item) =>
          `${item.address},${item.collateralValue},${item.liabilityValue},${item.healthScore}`
      )
      .join("\n");
    const csvContent = header + rows;

    fs.writeFile(filename, csvContent, (err) => {
      if (err) {
        reject(err);
      } else {
        resolve();
      }
    });
  });
}

async function main() {
  const addresses = await readAddressesFromFile("addresses.csv");
  const SimpleLens = await hre.ethers.getContractFactory("EulerSimpleLens");
  const simpleLensContractInstance = SimpleLens.attach(EulerAddresses.simpleLens);

  let completedRequests = 0;
  let startTime = null;

  const bigSpinner = {
    interval: 100,
    frames: [
      "■       ",
      " ■      ",
      "  ■     ",
      "   ■    ",
      "    ■   ",
      "     ■  ",
      "      ■ ",
      "       ■",
      "      ■ ",
      "     ■  ",
      "    ■   ",
      "   ■    ",
      "  ■     ",
      " ■      ",
    ],
  };

  const spinner = ora({ text: "Fetching account statuses...", spinner: bigSpinner }).start();

  const updateProgress = () => {
    completedRequests += 1;

    if (completedRequests === 1) {
      startTime = Date.now();
    }

    const progress = (completedRequests / addresses.length) * 100;
    const elapsedTime = Date.now() - startTime;
    const estimatedTotalTime = (elapsedTime / completedRequests) * addresses.length;
    const remainingTime = Math.round((estimatedTotalTime - elapsedTime) / 1000);

    spinner.text = `Progress: ${progress.toFixed(2)}% (${completedRequests}/${
      addresses.length
    }) | ETA: ${remainingTime}s`;
  };

  const accountStatusPromises = addresses.map(async (address) => {
    const accountStatus = await simpleLensContractInstance.getAccountStatus(address);
    updateProgress();
    return { address, ...accountStatus };
  });

  const accountStatuses = await Promise.all(accountStatusPromises);

  spinner.succeed("Fetching account statuses completed");

  try {
    await saveAccountStatusesToCsv("account_statuses.csv", accountStatuses);
    console.log("Account statuses saved to account_statuses.csv");
  } catch (err) {
    console.error("Error saving account statuses to CSV file:", err);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
