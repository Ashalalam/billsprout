# Flutter SDK Installation Guide for BillSprout

## Step-by-Step Flutter Installation

### Step 1: Download Flutter SDK
1. **Open your web browser** and go to: https://flutter.dev/docs/get-started/install/windows
2. **Click "Get started"** and then **"Windows"**
3. **Download the stable release** (flutter_windows_3.x.x-stable.zip)
4. **Choose the latest stable version** (not beta or dev)

### Step 2: Extract Flutter
1. **Create a folder**: `C:\development\` (or choose your preferred location)
2. **Extract the downloaded ZIP file** to `C:\development\`
3. **You should now have**: `C:\development\flutter\`

### Step 3: Add Flutter to PATH
1. **Press Windows Key + R** and type `sysdm.cpl`
2. **Click "Environment Variables"** at the bottom
3. **In "User variables"**, click **"New"**
4. **Variable name**: `PATH` (or edit existing PATH)
5. **Variable value**: `C:\development\flutter\bin`
6. **Click OK** to close all dialogs

### Step 4: Verify Installation
1. **Open a NEW PowerShell window** (important - must be new!)
2. **Run these commands**:
   ```powershell
   flutter doctor
   ```

### Step 5: Fix any issues
The `flutter doctor` command will show what needs to be fixed. Common issues:
- **Android toolchain**: You can skip this for web development
- **Chrome**: Make sure Chrome browser is installed
- **Visual Studio**: You can skip this for now

### Step 6: Run Your BillSprout App
Once Flutter is installed, navigate to your project and run:

```powershell
cd "C:\Users\saile\Desktop\erpme\billsprout"
flutter pub get
flutter run -d web-server --web-port=3000
```

## Alternative: Quick Install with Chocolatey
If you have Chocolatey package manager, you can install Flutter quickly:

```powershell
# Install Chocolatey first if you don't have it
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Then install Flutter
choco install flutter
```

## Expected Results
After installation and rebuild, you'll see:
- ✅ **Complete Patient Dashboard** with real-time stats
- ✅ **Medicine Search & Shopping Cart** with checkout
- ✅ **Prescription Upload** functionality  
- ✅ **Purchase History** from Supabase database
- ✅ **Appointment Booking** system
- ✅ **Health Profile** management
- ✅ **Refill Requests** with tracking

## Need Help?
If you run into issues:
1. **Check the error messages** from `flutter doctor`
2. **Restart your PowerShell** after adding to PATH
3. **Try running as Administrator** if you get permission errors
4. **Make sure you have internet connection** for downloading dependencies

## Login Credentials (After Rebuild)
- **Patient Portal**: `patient@lifesproutcare.com` / `patient123`
- **Admin Portal**: `admin@lifesproutcare.com` / `admin123`