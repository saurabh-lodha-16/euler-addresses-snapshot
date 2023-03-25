const axios = require("axios");
const fs = require("fs");

const endpoint = "https://api.thegraph.com/subgraphs/name/euler-xyz/euler-mainnet";

const query = `
  query FetchAccounts($skip: Int!, $orderDirection: String!) {
    accounts(first: 1000, skip: $skip, orderBy: id, orderDirection: $orderDirection) {
      id
    }
  }
`;

async function fetchAccounts(skip, order) {
  try {
    const response = await axios.post(endpoint, {
      query,
      variables: {
        skip,
        orderDirection: order,
      },
    });
    return response.data.data.accounts;
  } catch (error) {
    console.error("Error fetching accounts:", error);
    return [];
  }
}

async function main() {
  const addressSet = new Set();
  let skip = 0;
  let done = false;
  let order = "asc";

  while (!done) {
    const accounts = await fetchAccounts(skip, order);

    if (accounts.length === 0) {
      if (order === "asc") {
        // Switch to descending order and reset skip
        order = "desc";
        skip = 0;
        continue;
      } else {
        done = true;
      }
    } else {
      for (const account of accounts) {
        addressSet.add(account.id);
      }
      skip += accounts.length;
    }
  }

  console.log("Total addresses found:", addressSet.size);

  const csvContent = Array.from(addressSet).join("\n");
  fs.writeFile("addresses.csv", csvContent, (err) => {
    if (err) {
      console.error("Error writing addresses to CSV file:", err);
    } else {
      console.log("Addresses saved to addresses.csv");
    }
  });
}

main();
