#!/bin/bash
# =====================================================================
#  Proton S70 - Steering Wheel Button Remap : Xposed module builder
#  Fully self-contained. Creates the project, writes every source file,
#  builds, creates a signing key if needed, signs and aligns.
#
#  Needs: apktool (2.x), java/jarsigner, zipalign, keytool
#  Output: ~/SWMod-signed.apk
# =====================================================================
set -e

for t in apktool jarsigner zipalign keytool; do
  command -v $t >/dev/null || { echo "ERROR: '$t' not found in PATH"; exit 1; }
done

echo "== toolchain =="
echo "   apktool $(apktool --version 2>&1 | head -1)"
echo "   (this script writes an apktool 2.x project file. If the build fails with"
echo "    a complaint about apktool.yml, see the note in Step 8 of the guide.)"

PROJ="$HOME/SWMod"
KS="$HOME/swmod.keystore"

echo "== creating project =="
rm -rf "$PROJ" "$HOME/SWMod.apk" "$HOME/SWMod-signed.apk"
mkdir -p "$PROJ/smali/com/protons70/swmod" "$PROJ/assets" "$PROJ/res/values"
cd "$PROJ"

cat > apktool.yml <<'XEOF'
!!brut.androlib.meta.MetaInfo
apkFileName: SWMod.apk
compressionType: false
doNotCompress:
- resources.arsc
isFrameworkApk: false
packageInfo:
  forcedPackageId: '127'
  renameManifestPackage: null
sdkInfo:
  minSdkVersion: '21'
  targetSdkVersion: '28'
sharedLibrary: false
sparseResources: false
unknownFiles: {}
usesFramework:
  ids:
  - 1
  tag: null
version: 2.7.0
versionInfo:
  versionCode: '1'
  versionName: '1.0'
XEOF

echo "== writing AndroidManifest.xml =="
cat > AndroidManifest.xml <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.protons70.swmod"
    android:versionCode="1"
    android:versionName="1.0">

    <uses-sdk
        android:minSdkVersion="21"
        android:targetSdkVersion="28" />

    <application
        android:allowBackup="false"
        android:hasCode="true"
        android:label="S70 Steering Mod">

        <meta-data
            android:name="xposedmodule"
            android:value="true" />

        <meta-data
            android:name="xposeddescription"
            android:value="Proton S70: Hi Proton short press = cycle drive mode, hold = voice. Phone button hold = 360 camera." />

        <meta-data
            android:name="xposedminversion"
            android:value="93" />

        <meta-data
            android:name="xposedscope"
            android:resource="@array/xposedscope" />

    </application>

</manifest>
XEOF

echo "== writing res/values/arrays.xml =="
cat > res/values/arrays.xml <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string-array name="xposedscope">
        <item>com.malaysia.voicemaster</item>
        <item>com.malaysia.btphone</item>
    </string-array>
</resources>
XEOF

echo "== writing assets/xposed_init =="
cat > assets/xposed_init <<'XEOF'
com.protons70.swmod.Hook
XEOF

echo "== writing smali/com/protons70/swmod/Hook.smali =="
cat > smali/com/protons70/swmod/Hook.smali <<'XEOF'
.class public Lcom/protons70/swmod/Hook;
.super Lde/robv/android/xposed/XC_MethodHook;
.implements Lde/robv/android/xposed/IXposedHookLoadPackage;


# ---- key ids ----
# 200231 = 0x30E27  -> "VR"    (Hi Proton button)
# 200005 = 0x30D45  -> "Phone" (pick-up-call button)

.field static bypass:Z

.field static bt:Z

.field static idx:I


.method static constructor <clinit>()V
    .locals 1

    const/4 v0, 0x0

    sput-boolean v0, Lcom/protons70/swmod/Hook;->bypass:Z

    sput-boolean v0, Lcom/protons70/swmod/Hook;->bt:Z

    sput v0, Lcom/protons70/swmod/Hook;->idx:I

    return-void
.end method


.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Lde/robv/android/xposed/XC_MethodHook;-><init>()V

    return-void
.end method


# ---------------------------------------------------------------
# small logging helper
# ---------------------------------------------------------------
.method static say(Ljava/lang/String;)V
    .locals 1

    invoke-static {p0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    return-void
.end method


# ---------------------------------------------------------------
# get the application Context of the hooked process
# ---------------------------------------------------------------
.method static ctx()Landroid/content/Context;
    .locals 4

    const/4 v0, 0x0

    :try_start_0
    const-string v1, "android.app.ActivityThread"

    const/4 v2, 0x0

    invoke-static {v1, v2}, Lde/robv/android/xposed/XposedHelpers;->findClass(Ljava/lang/String;Ljava/lang/ClassLoader;)Ljava/lang/Class;

    move-result-object v1

    const-string v2, "currentApplication"

    const/4 v3, 0x0

    new-array v3, v3, [Ljava/lang/Object;

    invoke-static {v1, v2, v3}, Lde/robv/android/xposed/XposedHelpers;->callStaticMethod(Ljava/lang/Class;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Landroid/content/Context;

    move-object v0, v1
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    goto :goto_0

    :catch_0
    move-exception v1

    :goto_0
    return-object v0
.end method


# ---------------------------------------------------------------
# open the 360 camera app
# ---------------------------------------------------------------
.method static openCam()V
    .locals 4

    :try_start_0
    invoke-static {}, Lcom/protons70/swmod/Hook;->ctx()Landroid/content/Context;

    move-result-object v0

    if-nez v0, :cond_0

    return-void

    :cond_0
    new-instance v1, Landroid/content/Intent;

    invoke-direct {v1}, Landroid/content/Intent;-><init>()V

    const-string v2, "ecarx.camera.calibration"

    const-string v3, "ecarx.camera.calibration.MainActivity"

    invoke-virtual {v1, v2, v3}, Landroid/content/Intent;->setClassName(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;

    const v2, 0x10000000

    invoke-virtual {v1, v2}, Landroid/content/Intent;->addFlags(I)Landroid/content/Intent;

    invoke-virtual {v0, v1}, Landroid/content/Context;->startActivity(Landroid/content/Intent;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    goto :goto_0

    :catch_0
    move-exception v0

    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lcom/protons70/swmod/Hook;->say(Ljava/lang/String;)V

    :goto_0
    return-void
.end method


# ---------------------------------------------------------------
# advance drive mode: Comfort -> ECO -> Sport -> Comfort ...
# ---------------------------------------------------------------
.method static nextMode()V
    .locals 5

    :try_start_0
    invoke-static {}, Lcom/protons70/swmod/Hook;->ctx()Landroid/content/Context;

    move-result-object v0

    if-nez v0, :cond_0

    return-void

    :cond_0
    sget v1, Lcom/protons70/swmod/Hook;->idx:I

    add-int/lit8 v1, v1, 0x1

    rem-int/lit8 v1, v1, 0x3

    sput v1, Lcom/protons70/swmod/Hook;->idx:I

    const/4 v2, 0x0

    if-ne v1, v2, :cond_1

    const-string v2, "ecarx.settings.vehicle.setting.widget.DriveModeComfortWidget"

    goto :goto_0

    :cond_1
    const/4 v2, 0x1

    if-ne v1, v2, :cond_2

    const-string v2, "ecarx.settings.vehicle.setting.widget.DriveModeECOWidget"

    goto :goto_0

    :cond_2
    const-string v2, "ecarx.settings.vehicle.setting.widget.DriveModeSportWidget"

    :goto_0
    new-instance v3, Landroid/content/Intent;

    const-string v4, "ecarx.settings.vehicle.setting.widget.CarSettingWidget.action.ACTION_CLICK"

    invoke-direct {v3, v4}, Landroid/content/Intent;-><init>(Ljava/lang/String;)V

    const-string v4, "ecarx.settings"

    invoke-virtual {v3, v4, v2}, Landroid/content/Intent;->setClassName(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;

    invoke-virtual {v0, v3}, Landroid/content/Context;->sendBroadcast(Landroid/content/Intent;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    goto :goto_1

    :catch_0
    move-exception v0

    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lcom/protons70/swmod/Hook;->say(Ljava/lang/String;)V

    :goto_1
    return-void
.end method


# ---------------------------------------------------------------
# hooks inside com.malaysia.voicemaster
# ---------------------------------------------------------------
.method private hookVm(Ljava/lang/ClassLoader;)V
    .locals 3

    :try_start_0
    const-string v0, "com.malaysia.voicemaster.util.ConnectServiceUtil$3"

    invoke-static {v0, p1}, Lde/robv/android/xposed/XposedHelpers;->findClass(Ljava/lang/String;Ljava/lang/ClassLoader;)Ljava/lang/Class;

    move-result-object v0

    const-string v1, "onHkShortPress"

    invoke-static {v0, v1, p0}, Lde/robv/android/xposed/XposedBridge;->hookAllMethods(Ljava/lang/Class;Ljava/lang/String;Lde/robv/android/xposed/XC_MethodHook;)Ljava/util/Set;

    const-string v1, "onHkLongPress"

    invoke-static {v0, v1, p0}, Lde/robv/android/xposed/XposedBridge;->hookAllMethods(Ljava/lang/Class;Ljava/lang/String;Lde/robv/android/xposed/XC_MethodHook;)Ljava/util/Set;

    const-string v0, "SWMod: voicemaster hooks installed"

    invoke-static {v0}, Lcom/protons70/swmod/Hook;->say(Ljava/lang/String;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    goto :goto_0

    :catch_0
    move-exception v0

    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "SWMod: voicemaster hook FAILED: "

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lcom/protons70/swmod/Hook;->say(Ljava/lang/String;)V

    :goto_0
    return-void
.end method


# ---------------------------------------------------------------
# hooks inside com.malaysia.btphone
# onHkLongPress may sit on BlueToothService itself OR on one of its
# inner classes, so hook both and report how many we caught.
# ---------------------------------------------------------------
.method private hookBt(Ljava/lang/ClassLoader;)V
    .locals 9

    :try_start_0
    const-string v0, "com.malaysia.btphone.service.BlueToothService"

    invoke-static {v0, p1}, Lde/robv/android/xposed/XposedHelpers;->findClass(Ljava/lang/String;Ljava/lang/ClassLoader;)Ljava/lang/Class;

    move-result-object v0

    const/4 v1, 0x0

    const-string v2, "onHkLongPress"

    invoke-static {v0, v2, p0}, Lde/robv/android/xposed/XposedBridge;->hookAllMethods(Ljava/lang/Class;Ljava/lang/String;Lde/robv/android/xposed/XC_MethodHook;)Ljava/util/Set;

    move-result-object v3

    invoke-interface {v3}, Ljava/util/Set;->size()I

    move-result v3

    add-int/2addr v1, v3

    invoke-virtual {v0}, Ljava/lang/Class;->getDeclaredClasses()[Ljava/lang/Class;

    move-result-object v4

    const/4 v5, 0x0

    :goto_loop
    array-length v6, v4

    if-ge v5, v6, :goto_done

    aget-object v7, v4, v5

    const-string v8, "onHkLongPress"

    invoke-static {v7, v8, p0}, Lde/robv/android/xposed/XposedBridge;->hookAllMethods(Ljava/lang/Class;Ljava/lang/String;Lde/robv/android/xposed/XC_MethodHook;)Ljava/util/Set;

    move-result-object v7

    invoke-interface {v7}, Ljava/util/Set;->size()I

    move-result v7

    add-int/2addr v1, v7

    add-int/lit8 v5, v5, 0x1

    goto :goto_loop

    :goto_done
    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    const-string v3, "SWMod: btphone onHkLongPress hooks = "

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v2, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v2

    invoke-static {v2}, Lcom/protons70/swmod/Hook;->say(Ljava/lang/String;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    goto :goto_0

    :catch_0
    move-exception v0

    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "SWMod: btphone hook FAILED: "

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lcom/protons70/swmod/Hook;->say(Ljava/lang/String;)V

    :goto_0
    return-void
.end method


# ---------------------------------------------------------------
# entry point
# ---------------------------------------------------------------
.method public handleLoadPackage(Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;)V
    .locals 3

    iget-object v0, p1, Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;->packageName:Ljava/lang/String;

    iget-object v1, p1, Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;->classLoader:Ljava/lang/ClassLoader;

    const-string v2, "com.malaysia.voicemaster"

    invoke-virtual {v2, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v2

    if-eqz v2, :cond_bt

    invoke-direct {p0, v1}, Lcom/protons70/swmod/Hook;->hookVm(Ljava/lang/ClassLoader;)V

    return-void

    :cond_bt
    const-string v2, "com.malaysia.btphone"

    invoke-virtual {v2, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v2

    if-nez v2, :cond_do_bt

    return-void

    :cond_do_bt
    const/4 v2, 0x1

    sput-boolean v2, Lcom/protons70/swmod/Hook;->bt:Z

    invoke-direct {p0, v1}, Lcom/protons70/swmod/Hook;->hookBt(Ljava/lang/ClassLoader;)V

    return-void
.end method


# ---------------------------------------------------------------
# the hook body
# ---------------------------------------------------------------
.method protected beforeHookedMethod(Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;)V
    .locals 6

    # --- read first argument as int (the key id) ---
    iget-object v0, p1, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->args:[Ljava/lang/Object;

    if-nez v0, :cond_0

    return-void

    :cond_0
    array-length v1, v0

    if-nez v1, :cond_1

    return-void

    :cond_1
    const/4 v1, 0x0

    aget-object v1, v0, v1

    instance-of v2, v1, Ljava/lang/Integer;

    if-nez v2, :cond_2

    return-void

    :cond_2
    check-cast v1, Ljava/lang/Integer;

    invoke-virtual {v1}, Ljava/lang/Integer;->intValue()I

    move-result v1

    # --- which method are we in? ---
    iget-object v2, p1, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->method:Ljava/lang/reflect/Member;

    invoke-interface {v2}, Ljava/lang/reflect/Member;->getName()Ljava/lang/String;

    move-result-object v2

    const-string v3, "onHkShortPress"

    invoke-virtual {v3, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v3

    if-eqz v3, :cond_long

    # ================= SHORT PRESS (voicemaster only) =================
    const v3, 0x30E27

    if-eq v1, v3, :cond_vrshort

    return-void

    :cond_vrshort
    sget-boolean v3, Lcom/protons70/swmod/Hook;->bypass:Z

    if-eqz v3, :cond_block

    # called from our own long-press handler: let the original voice path run
    const/4 v3, 0x0

    sput-boolean v3, Lcom/protons70/swmod/Hook;->bypass:Z

    return-void

    :cond_block
    const/4 v3, 0x0

    invoke-virtual {p1, v3}, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->setResult(Ljava/lang/Object;)V

    invoke-static {}, Lcom/protons70/swmod/Hook;->nextMode()V

    return-void

    # ================= LONG PRESS =================
    :cond_long
    sget-boolean v3, Lcom/protons70/swmod/Hook;->bt:Z

    if-eqz v3, :cond_vmlong

    # ---- we are inside com.malaysia.btphone ----
    # swallow the phone key so it does not dial / open the dialler
    const v3, 0x30D45

    if-eq v1, v3, :cond_swallow

    return-void

    :cond_swallow
    const/4 v3, 0x0

    invoke-virtual {p1, v3}, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->setResult(Ljava/lang/Object;)V

    return-void

    # ---- we are inside com.malaysia.voicemaster ----
    :cond_vmlong
    const v3, 0x30E27

    if-ne v1, v3, :cond_phone

    # Hi Proton held -> run the original short-press logic (voice)
    const/4 v3, 0x0

    invoke-virtual {p1, v3}, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->setResult(Ljava/lang/Object;)V

    const/4 v3, 0x1

    sput-boolean v3, Lcom/protons70/swmod/Hook;->bypass:Z

    iget-object v3, p1, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->thisObject:Ljava/lang/Object;

    const-string v4, "onHkShortPress"

    iget-object v5, p1, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->args:[Ljava/lang/Object;

    invoke-static {v3, v4, v5}, Lde/robv/android/xposed/XposedHelpers;->callMethod(Ljava/lang/Object;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/Object;

    return-void

    :cond_phone
    const v3, 0x30D45

    if-eq v1, v3, :cond_cam

    return-void

    :cond_cam
    # phone button held -> 360 camera
    const/4 v3, 0x0

    invoke-virtual {p1, v3}, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->setResult(Ljava/lang/Object;)V

    invoke-static {}, Lcom/protons70/swmod/Hook;->openCam()V

    return-void
.end method
XEOF

echo "== building =="
cd "$HOME"
apktool b SWMod -o "$HOME/SWMod.apk"

if [ ! -f "$KS" ]; then
  echo "== creating signing key =="
  keytool -genkeypair -v -keystore "$KS" -alias swmod \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass android -keypass android \
    -dname "CN=SWMod, O=ArdentLab"
fi

echo "== signing =="
jarsigner -keystore "$KS" -storepass android -keypass android \
  "$HOME/SWMod.apk" swmod

echo "== aligning =="
zipalign -f 4 "$HOME/SWMod.apk" "$HOME/SWMod-signed.apk"

echo
echo "DONE -> $HOME/SWMod-signed.apk"
ls -l "$HOME/SWMod-signed.apk"
