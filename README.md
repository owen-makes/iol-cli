# IOL CLI (InvertirOnline Command Line Interface)

A lightweight Ruby CLI for the InvertirOnline API. Designed for Financial Advisors (Asesores) and Power Users who want to manage portfolios, check quotes, and view account details directly from the terminal or integrate with AI agents.

## Features

- **Advisor Support:** Fetch client lists, portfolios, and transactions.
- **Smart Caching:** Local JSON caching of client IDs to speed up requests.
- **Human Mode:** Beautiful, color-coded terminal tables for quotes and portfolios.
- **Machine Mode:** Pure JSON output for AI Agents or pipe processing.
- **Secure:** Uses Environment Variables for credentials.

## Installation

1. **Clone the repo:**

   ```bash
   git clone [https://github.com/YOUR_USERNAME/iol-cli.git](https://github.com/YOUR_USERNAME/iol-cli.git)
   cd iol-cli


2. **Install dependencies:**

    ```bash

    gem install httparty

3. **Make executable:**

    ```bash

    chmod +x iol

## Configuration

Set your IOL credentials in your environment (e.g., in .zshrc or .bashrc):

```bash

export IOL_USERNAME="your_username"
export IOL_PASSWORD="your_password"
```

## Usage

1. **Market Data**

Get a Quote (Table View):

```bash

./iol quote -s GGAL -H
```

Get Options Chain (JSON):

```bash

./iol options -s GGAL
```

2. **Advisor / Portfolio Management**

List All Clients (Search):

```bash

./iol search -q "Daniel"
```

View Client Portfolio (Table View):

```bash

./iol client_portfolio --account 123456 -H
```

View Client Account/Balance:

```bash

./iol client_account --account 123456 -H
```

Get Client Transactions (Last 30 days):

```bash

./iol client_transactions --account 123456
```

3. **Options**

  ```
    -H or --human: Output formatted tables instead of JSON.

    --refresh: Force a refresh of the local client cache.

    -m: Specify market (default: BCBA).

    -t: Specify settlement (default: T1).
  ```

Disclaimer

This is an unofficial tool. Use at your own risk. Always verify trade data.
