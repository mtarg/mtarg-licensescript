<p align="center">
  <img src="https://www.image2url.com/dashboard" alt="MTARG Logo" width="150"/>
</p>

<h1 align="center">MTARG License Script</h1>

<p align="center">
  <b>A secure and reliable licensing system for your Multi Theft Auto (MTA) server resources.</b>
</p>

<p align="center">
  <a href="https://mtarg.xyz/"><b>Main Website</b></a>
</p>

---

## 🚀 How to Add to Your MTA Server

Follow these simple steps to integrate the MTARG license script into your MTA server:

### Step 1: Download Setup Files
1. Go to the [GitHub Repository](https://github.com/mtarg/mtarg-licensescript/tree/main).
2. Download or clone the setup files into your server's `resources` directory.

### Step 2: Configure the Resource
1. Open the configuration file included in the resource folder.
2. Link your server with your account from the [MTARG Website](https://mtarg.xyz/).
3. Save the changes.

### Step 3: Add to Server Config
1. Open your server's `mtaserver.conf` file.
2. Add the resource start command:
   ```xml
   <resource src="mtarg-licensescript" startup="true" protected="0" />
