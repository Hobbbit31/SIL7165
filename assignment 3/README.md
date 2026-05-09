# SIL765 — Assignment 3: Network Traffic Analysis

This project analyses network traffic logs to uncover patterns, detect anomalies, and perform deep security threat hunting using both exact and space-efficient (sublinear) algorithms.

---

## Project Structure

```
assignment 3/
├── README.md                     ← You are here
├── SIL765_Assignment_3.pdf       ← Assignment specification
├── basic_stats.ipynb             ← Section 1: Basic Network Traffic Statistics
├── estimation.ipynb              ← Section 2: Traffic Estimation (Sublinear Space)
├── anomaly_detection.ipynb       ← Section 3: Advanced Anomaly Detection
├── threat_analysis.ipynb         ← Section 4: Deep Security Threat Analysis
├── b/                            ← Dataset (CSV files)
│   ├── network_analysis_data1.csv
│   ├── network_analysis_data2.csv
│   ├── network_analysis_data3.csv
│   ├── network_analysis_data4.csv
│   ├── network_analysis_data5.csv
│   └── network_analysis_data6.csv
└── a/                            ← Reference implementation (last year)
```

---

## What Each Notebook Does (Detailed)

### 1. `basic_stats.ipynb` — Basic Network Traffic Statistics

Parses all 6 CSVs into one DataFrame and computes fundamental traffic metrics.

1. **Total flows** — Simple `len(df)` after concatenating all CSVs = **2,071,657 flows**
2. **Top-k protocols** — Uses `value_counts()` on `protocolName` column. k is configurable (default 5). Result: TCP dominates at 79.4%, UDP at 20.2%, ICMP at 0.4%
3. **Top 10 source & destination IPs** — Ranked by **flow count** (number of flows, not bytes). This captures communication activity regardless of transfer size
4. **Average packet size** — Computed as `(totalSourceBytes + totalDestinationBytes) / (totalSourcePackets + totalDestinationPackets)` = **736.92 bytes**. Also computes Coefficient of Variation (CV = std/mean = 39.15) to show the average is NOT representative — flow sizes range from tiny ACKs to multi-MB transfers
5. **Top 3 source-destination pairs** — Groups by `(source, destination)` and counts flows. Top pair: `192.168.5.122 -> 198.164.30.2` with 232,409 flows
6. **Consistent communicators** — Splits timeline into 1-hour windows using `dt.floor('h')` (146 windows total). An IP active in >= 80% of windows is "consistent". Found **25 IPs** — mostly internal `192.168.x.x` hosts. Hourly windows balance between detecting gaps and tolerating brief idle periods
7. **Traffic spikes** — Sums total bytes per hour, converts to MB. A spike = any hour where volume > mean + 2*std (threshold: 2,060 MB). Found **2 spikes**: 2010-06-13 10:00 (2,357 MB) and 2010-06-15 16:00 (7,720 MB). Possible causes: large file transfers, DDoS, backup jobs
8. **Packet size variance** — Variance is extremely high (2.09 x 10^12, CV = 39.15). This is because tiny control packets coexist with large file transfers, and different protocols produce very different packet sizes

---

### 2. `estimation.ipynb` — Traffic Estimation Using Sublinear Space

Implements space-efficient data structures that use far less memory than exact methods — critical for real-world network monitoring where you can't store everything.

#### (a) HyperLogLog — Estimating Unique IPs
- **Problem:** Count distinct IPs without storing them all in a set
- **How it works:** Hashes each IP using MurmurHash3 to a 32-bit value. The first p=10 bits select one of 1024 registers. The remaining bits are checked for leading zeros — the more leading zeros, the rarer the hash, suggesting more unique elements. Each register tracks the maximum leading-zero count seen
- **Key formula:** `E = alpha * m^2 * Z` where Z is the harmonic mean of 2^(-register) values
- **Result:** Estimated **32,034** vs exact **34,801**. Error = **7.95%** (within <10% requirement). Uses only **8 KB** vs 3,884 KB for exact set = **472x memory saving**
- **Trade-off:** Increasing p reduces error but memory grows as O(2^p). HLL cannot enumerate or delete elements

#### (b) Count-Min Sketch — Heavy Hitter Destination IPs
- **Problem:** Find most frequently contacted destinations without a full Counter
- **How it works:** 2D array of counters (depth=5 rows, width=10,000 columns). For each destination IP, hash it with 5 different seeds to get 5 column positions, increment those 5 cells. To query, hash again and return the **minimum** across 5 rows — this minimises overcounting from hash collisions
- **Result:** Average error across top-10 destinations = **0.01%**. Uses **391 KB** vs 3,707 KB = **9.5x saving**
- **Trade-off:** CMS always overcounts (never undercounts). Wider table = lower error but more memory

#### (c) Bloom Filter — IP Membership Testing (Blocklist)
- **Problem:** Quickly check if an IP was previously seen, without storing all IPs (useful for blocklists)
- **How it works:** Bit array of 100,000 bits + k=4 hash functions. Adding an IP sets 4 bits to 1. Checking an IP tests those 4 bits — if ALL are 1, "probably yes"; if ANY is 0, "definitely no". False negatives are **impossible**; false positives occur when bits overlap from different IPs
- **Result:** False positive rate = **1.38%**. Memory: **97.8 KB** vs 1,040 KB = **10.6x saving**
- **Trade-off:** Larger bit array = fewer false positives. Standard Bloom filters cannot delete elements

---

### 3. `anomaly_detection.ipynb` — Advanced Anomaly Detection

Uses statistical methods to detect unusual behavior in the traffic.

#### (a) Statistical Traffic Analysis
- **Thresholds defined:**
  - Packet size: IQR method — Q3 + 1.5 * IQR = 19,788 bytes
  - Hourly flows: mean + 2*std = 40,417 flows/hr
  - Daily flows: mean + std = 507,149 flows/day
- **Hourly vs Daily comparison:** Plots both timelines. Finds anomalous days (June 15: 571,699 flows). Also detects **hidden anomalies** — days with normal daily totals but with hourly spikes exceeding the hourly threshold
- **Abnormal IPs:** Uses IQR on total source bytes per IP. **318 source IPs** flagged as high-traffic outliers

#### (b) Behavioural Analysis
- **Spikes after inactivity:** Pivots data into (IP x hour) matrix. Checks if traffic jumps from 0 to >50 KB between consecutive hours. **16 IPs flagged** — suggests compromised hosts waking up or automated tasks triggering
- **Network-wide correlation:** Groups by (destination, 15-min window), counts unique source IPs. Threshold via IQR (8 sources/window). **772 pairs flagged**. Top target: `192.168.2.107` with **229 distinct sources** in one 15-minute window — strong evidence of coordinated attack (DDoS or scan)
- **Many-source destinations:** Same analysis — identifies destinations contacted by abnormally many IPs in short bursts

#### (c) Suspicious Communication Patterns
- **Long-duration connections:** IQR on `(stopDateTime - startDateTime).total_seconds()`. **9,975 flows** exceeded threshold. Could indicate exfiltration tunnels, persistent shells, or forgotten idle connections
- **Multi-protocol bursts:** Counts distinct protocols per source IP per 15-min window. **1 entry flagged:** `192.168.2.107` used 4 protocols (tcp, udp, icmp, igmp) in one window — consistent with reconnaissance or multi-vector probing

---

### 4. `threat_analysis.ipynb` — Deep Security Threat Analysis

Performs active threat hunting — looking for specific known attack patterns.

#### (a) Complex Attack Patterns
- **Stealthy port scans:** Groups by (source, destination), counts unique destination ports and active hours. Pairs with >= 10 ports over > 1 hour flagged. **31 pairs found**. Most aggressive: `192.168.4.121` scanned **3,658 ports** on `192.168.5.122` over 123 hours — classic slow scan to evade IDS
- **Slow DDoS:** Three-way percentile filter — flow count > 95th pctl AND unique sources > 95th pctl AND avg bytes < 25th pctl. This catches attacks that don't spike traffic but gradually exhaust resources with many small flows from many sources. **5 targets** found, mostly `192.168.2.107`
- **IP hopping:** Groups by (destination, port, hour), counts unique source IPs. Values above 99.5th percentile flagged. **619 entries** — consistent with botnet IP rotation to evade blocklists. Top: `192.168.2.107` port 0 received traffic from 441 unique sources in one hour

#### (b) Malicious Payload Identification
- **Unusually long payloads:** Flows with Base64 payload length above 99.5th percentile. **8,852 flows** — could contain exploit payloads or exfiltrated data
- **Repeated payloads:** Same Base64 payload appearing >10 times. **383,880 flows** — could be keep-alives, heartbeats, or malware beaconing
- **Obfuscated payloads:** Base64 present but no readable UTF content. **84,856 flows** — binary/encrypted data that warrants inspection
- **Suspicious encrypted traffic:** Flows on ports 443/22/993 with near-empty payloads (<50 chars). **63,968 flows** — possible service fingerprinting or connection probing
- **C2 beaconing detection:** Looks for source-destination pairs with ALL of: high flow count (top 10%), tiny payloads (bottom 10%), low interval standard deviation (bottom 10% = regular timing), long duration (top 50%). **1 pair found:** `192.168.2.109 -> 95.211.98.12` — 25,095 zero-payload flows at ~14.9s interval std over 10 hours. Classic malware beacon pattern

#### (c) Threat Attribution and Risk Classification
All detected events categorised into three risk levels:
- **High risk (29 events):** Stealthy port scans >24h (23), slow DDoS (5), C2 beaconing (1) — these require immediate action
- **Medium risk (15 events):** Short port scans (8), IP hopping (5), suspicious encrypted (1), obfuscated payloads (1) — need investigation
- **Low risk (2 events):** Repeated payloads (1), large payloads (1) — anomalous but possibly benign
- **Total: 46 security events**
- Generates a formatted risk report with per-event justifications and 5 actionable recommendations

---

## Requirements

### Python Version
Python **3.8 or higher** is required.

Check your version:
```bash
python3 --version
```

### Required Libraries

| Library | Purpose |
|---------|---------|
| `pandas` | Data loading and manipulation |
| `numpy` | Numerical operations |
| `matplotlib` | Plotting and visualisation |
| `seaborn` | Enhanced statistical plots |
| `mmh3` | MurmurHash3 — used in HyperLogLog, Count-Min Sketch, Bloom Filter |
| `jupyter` | Running `.ipynb` notebooks |

---

## Installation & Setup by Operating System

---

### 🐧 Linux (Ubuntu / Debian / Fedora)

#### Step 1 — Install Python (if not already installed)

**Ubuntu / Debian:**
```bash
sudo apt update
sudo apt install python3 python3-pip python3-venv -y
```

**Fedora:**
```bash
sudo dnf install python3 python3-pip -y
```

Verify:
```bash
python3 --version
pip3 --version
```

#### Step 2 — Navigate to the Project Folder
```bash
cd ~/Desktop/NSS/"assignment 3"
```

#### Step 3 — Create and Activate Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate
```
You will see `(venv)` at the start of your prompt.

#### Step 4 — Install Dependencies
```bash
pip install pandas numpy matplotlib seaborn mmh3 jupyter notebook ipykernel
```

#### Step 5 — Launch Jupyter
```bash
jupyter notebook
```
A browser tab opens at `http://localhost:8888`. Open any `.ipynb` file and click **Kernel → Restart & Run All**.

---

### 🍎 macOS

#### Step 1 — Install Python

macOS comes with Python 2 by default. Install Python 3 via Homebrew (recommended):

```bash
# Install Homebrew first if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Then install Python 3
brew install python3
```

Or download the installer directly from [python.org](https://www.python.org/downloads/).

Verify:
```bash
python3 --version
pip3 --version
```

#### Step 2 — Navigate to the Project Folder
```bash
cd ~/Desktop/NSS/"assignment 3"
```

#### Step 3 — Create and Activate Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate
```
You will see `(venv)` at the start of your prompt.

#### Step 4 — Install Dependencies
```bash
pip install pandas numpy matplotlib seaborn mmh3 jupyter notebook ipykernel
```

> **Note for Apple Silicon (M1/M2/M3 Macs):** If `mmh3` fails to install, try:
> ```bash
> pip install --no-binary mmh3 mmh3
> ```

#### Step 5 — Launch Jupyter
```bash
jupyter notebook
```
A browser tab opens at `http://localhost:8888`. Open any `.ipynb` file and click **Kernel → Restart & Run All**.

---

### 🪟 Windows

#### Step 1 — Install Python

1. Go to [https://www.python.org/downloads/](https://www.python.org/downloads/)
2. Download the latest **Python 3.x** installer
3. Run the installer — **make sure to check "Add Python to PATH"** before clicking Install
4. Click **"Install Now"**

Verify (open **Command Prompt** or **PowerShell**):
```cmd
python --version
pip --version
```

#### Step 2 — Open Terminal and Navigate to Project Folder

Open **Command Prompt** (`Win + R` → type `cmd` → Enter) or **PowerShell**:

```cmd
cd "%USERPROFILE%\Desktop\NSS\assignment 3"
```

> If your username has spaces or the path doesn't work, try:
> ```cmd
> cd /d "C:\Users\YourName\Desktop\NSS\assignment 3"
> ```

#### Step 3 — Create and Activate Virtual Environment

```cmd
python -m venv venv
venv\Scripts\activate
```

You will see `(venv)` at the start of your prompt.

> **If activation is blocked by PowerShell policy**, run this first:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```
> Then try activating again.

#### Step 4 — Install Dependencies

```cmd
pip install pandas numpy matplotlib seaborn mmh3 jupyter notebook ipykernel
```

#### Step 5 — Launch Jupyter

```cmd
jupyter notebook
```

A browser tab opens at `http://localhost:8888`. Open any `.ipynb` file and click **Kernel → Restart & Run All**.

> **If the browser doesn't open automatically**, copy the URL shown in the terminal (looks like `http://localhost:8888/?token=...`) and paste it into your browser manually.

---

## Running the Notebooks

### Option A — Jupyter Notebook (Recommended for all OS)

After launching `jupyter notebook` (Step 5 above):

1. The Jupyter file browser opens in your browser
2. Click on any `.ipynb` file:
   - `basic_stats.ipynb`
   - `estimation.ipynb`
   - `anomaly_detection.ipynb`
   - `threat_analysis.ipynb`
3. Once open, run it:
   - **Run cell by cell**: Press `Shift + Enter` on each cell
   - **Run entire notebook**: Click **`Kernel → Restart & Run All`** from the menu bar

> **Important:** Always run notebooks in order — `basic_stats` first, then `estimation`, `anomaly_detection`, and finally `threat_analysis`. Run each notebook top to bottom without skipping cells.

---

### Option B — Jupyter Lab (Cleaner UI, all OS)

```bash
pip install jupyterlab
jupyter lab
```

Same steps as Option A — open notebooks from the left sidebar file browser.

---

### Option C — VS Code (all OS)

1. Download and install **VS Code** from [https://code.visualstudio.com/](https://code.visualstudio.com/)
2. Open VS Code → go to Extensions (`Ctrl+Shift+X`) → search **"Jupyter"** → Install
3. Also install the **"Python"** extension if not already present
4. Open the project: `File → Open Folder` → select the `assignment 3` folder
5. Open any `.ipynb` file
6. Click **"Select Kernel"** (top-right corner) → choose your venv Python interpreter
7. Click **"Run All"** at the top of the notebook

---

## Verify Dependencies (All OS)

Run this to confirm everything is installed:

```bash
python3 -c "import pandas, numpy, matplotlib, seaborn, mmh3; print('All dependencies OK')"
```

On Windows:
```cmd
python -c "import pandas, numpy, matplotlib, seaborn, mmh3; print('All dependencies OK')"
```

---

## Running Order

Run the notebooks in this order for best results:

```
1. basic_stats.ipynb
2. estimation.ipynb
3. anomaly_detection.ipynb
4. threat_analysis.ipynb
```

Each notebook is self-contained (loads data independently), but running in order mirrors the assignment structure and makes reviewing easier.

---

## Dataset Notes

- All 6 CSV files in `b/` are automatically loaded by each notebook using `glob('../b/*.csv')`
- Each CSV contains ~100K–570K rows; total dataset is ~2 million network flows
- Columns used: `source`, `destination`, `protocolName`, `sourcePort`, `destinationPort`, `totalSourceBytes`, `totalDestinationBytes`, `totalSourcePackets`, `totalDestinationPackets`, `startDateTime`, `stopDateTime`, `sourcePayloadAsBase64`, `sourcePayloadAsUTF`, `destinationPayloadAsBase64`, `destinationPayloadAsUTF`
- The `Label` column (Normal/Attack) is present in the data but not used in analysis — the goal is unsupervised detection

---

## Troubleshooting

### `ModuleNotFoundError: No module named 'mmh3'`
```bash
pip install mmh3
```
On Apple Silicon Mac if that fails:
```bash
pip install --no-binary mmh3 mmh3
```

### `ModuleNotFoundError: No module named 'seaborn'`
```bash
pip install seaborn
```

### Notebook is slow / kernel dies on large data
The full dataset is ~2 million rows. If your machine has limited RAM:
- Close other applications before running
- If a cell is taking too long, try loading only 1–2 CSV files for testing:
  ```python
  csv_files = sorted(glob.glob('../b/*.csv'))[:2]   # load first 2 files only
  ```

### `FileNotFoundError: ../b/*.csv`
Make sure you are launching Jupyter **from inside** the `assignment 3` folder:

**Linux / macOS:**
```bash
cd ~/Desktop/NSS/"assignment 3"
jupyter notebook
```
**Windows:**
```cmd
cd "%USERPROFILE%\Desktop\NSS\assignment 3"
jupyter notebook
```
If Jupyter is launched from a different directory, the relative path `../b/` will not resolve correctly.

### `jupyter` command not found
Your virtual environment may not be active. Re-activate it:

**Linux / macOS:**
```bash
source venv/bin/activate
```
**Windows:**
```cmd
venv\Scripts\activate
```

### Windows: `venv\Scripts\activate` is blocked
Run this once in PowerShell (as Administrator):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Kernel keeps crashing
Try restarting with a higher data rate limit:
```bash
jupyter notebook --NotebookApp.iopub_data_rate_limit=1.0e10
```

### Browser doesn't open automatically (Windows)
Copy the full URL from the terminal output (including the token) and paste it into Chrome/Firefox manually. It looks like:
```
http://localhost:8888/?token=abc123...
```

---

## Quick Start (TL;DR)

**Linux / macOS:**
```bash
cd ~/Desktop/NSS/"assignment 3"
python3 -m venv venv
source venv/bin/activate
pip install pandas numpy matplotlib seaborn mmh3 jupyter
jupyter notebook
```

**Windows (Command Prompt):**
```cmd
cd "%USERPROFILE%\Desktop\NSS\assignment 3"
python -m venv venv
venv\Scripts\activate
pip install pandas numpy matplotlib seaborn mmh3 jupyter
jupyter notebook
```

Then open each `.ipynb` file in the browser and click **Kernel → Restart & Run All**.
