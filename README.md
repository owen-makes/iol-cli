# IOL CLI (InvertirOnline Command Line Interface)

A lightweight Ruby CLI for the InvertirOnline API. Designed for AI agents.

---

## 🥱 Features

* **Advisor Support**: Seamlessly fetch client lists, portfolios, and transaction histories.
* **Smart Caching**: Local JSON caching of client IDs to bypass redundant requests and speed up your workflow.
* **Human Mode**: Beautiful, color-coded terminal tables for quotes and portfolios.
* **Machine Mode**: Pure JSON output, perfect for AI Agents or piping into `jq`.
* **Secure**: Minimalist security using local Environment Variables for credentials.

---

## 🛠 Installation

1. **Clone the repository:**

```bash
git clone https://github.com/owen-makes/iol-cli
cd iol-cli
```

1. **Install dependencies:**

```bash
gem install httparty
```

1. **Make the script executable:**

```bash
chmod +x iol
```

---

## ⚙️ Config

To authenticate, set your IOL credentials in your environment (e.g., in your `.zshrc` or `.bashrc` file):

```bash
export IOL_USERNAME="your_username"
export IOL_PASSWORD="your_password"
```

---

## 📈 Usage

### 1. Market Data

**Get a Quote (Table View):**

```bash
./iol quote -s GGAL -H
```

**Get Options Chain (JSON):**

```bash
./iol options -s GGAL
```

### 2. Advisor & Portfolio Management

**List All Clients (Search):**

```bash
./iol search -q "Daniel"
```

**View Client Portfolio (Table View):**

```bash
./iol client_portfolio --account 123456 -H
```

**View Client Account/Balance:**

```bash
./iol client_account --account 123456 -H
```

**Get Client Transactions (Last 30 days):**

```bash
./iol client_transactions --account 123456
```

---

## 🚩 Command Options

| Flag | Alternative | Description |
| ------ | ------------- | ------------- |
| `-H` | `--human` | Output formatted tables instead of raw JSON. |
| `--refresh` | | Force a refresh of the local client cache. |
| `-m` | | Specify market (Default: `BCBA`). |
| `-t` | | Specify settlement (Default: `T1`). |

---

## 💦 Disclaimer

Purely informational. No trading endpoints have been added. This is an unofficial tool. Use it at your own risk.

## Credits

Myself. If you want to support me, consider trying my bond database tool https://argen.bond
