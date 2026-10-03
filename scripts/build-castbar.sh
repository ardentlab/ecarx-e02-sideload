#!/bin/bash
# =====================================================================
#  Cast to Meter Panel - Vector/Xposed module builder
#  Inserts a white cast button (VECTOR drawable, sharp at any size)
#  into the ECarX bottom nav bar, cloning the all-apps button's size
#  and spacing. Empty screen = not casting, filled screen = casting.
#  Tap moves the focused app to the meter panel (display 1) and back,
#  streams fake nav status so steering POWER switches the meter panel
#  to HDMI, and hooks system_server so the app is not relaunched.
#  Scope: com.android.systemui/0 system/0
#  Needs: apktool (2.x), jarsigner, zipalign, keytool
#  Output: ~/CastBar-signed.apk
# =====================================================================
set -e
for t in apktool jarsigner zipalign keytool; do
  command -v $t >/dev/null || { echo "ERROR: '$t' not found in PATH"; exit 1; }
done
echo "== toolchain =="; echo "   apktool $(apktool --version 2>&1 | head -1)"
PROJ="$HOME/CastBar"; KS="$HOME/castbar.keystore"
echo "== creating project =="
rm -rf "$PROJ" "$HOME/CastBar.apk" "$HOME/CastBar-signed.apk"
mkdir -p "$PROJ/smali/com/ardentlab/cast" "$PROJ/assets" "$PROJ/res/values" "$PROJ/res/drawable"
cd "$PROJ"
cat > apktool.yml <<'XEOF'
!!brut.androlib.meta.MetaInfo
apkFileName: CastBar.apk
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
echo "== AndroidManifest.xml =="
cat > AndroidManifest.xml <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.ardentlab.cast"
    android:versionCode="1"
    android:versionName="1.0">
    <uses-sdk android:minSdkVersion="21" android:targetSdkVersion="28" />
    <application android:allowBackup="false" android:hasCode="true" android:label="Cast">
        <meta-data android:name="xposedmodule" android:value="true" />
        <meta-data android:name="xposeddescription" android:value="Cast/uncast button in the ECarX bottom nav bar: moves the focused app to the meter panel (display 1) without restarting it (hooks systemui + system_server)." />
        <meta-data android:name="xposedminversion" android:value="93" />
        <meta-data android:name="xposedscope" android:resource="@array/xposedscope" />
    </application>
</manifest>
XEOF
echo "== res/values/arrays.xml =="
cat > res/values/arrays.xml <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string-array name="xposedscope">
        <item>com.android.systemui</item>
        <item>android</item>
    </string-array>
</resources>
XEOF
echo "== assets/xposed_init =="
cat > assets/xposed_init <<'XEOF'
com.ardentlab.cast.Hook
XEOF
echo "== vector icons =="
cat > res/drawable/cast_off.xml <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="40dp" android:height="40dp"
    android:viewportWidth="40" android:viewportHeight="40">
    <group android:translateX="8" android:translateY="8">
        <path android:fillColor="#FFFFFFFF" android:pathData="M21,3H3c-1.1,0 -2,0.9 -2,2v3h2V5h18v14h-7v2h7c1.1,0 2,-0.9 2,-2V5c0,-1.1 -0.9,-2 -2,-2zM1,18v3h3c0,-1.66 -1.34,-3 -3,-3zM1,14v2c2.76,0 5,2.24 5,5h2c0,-3.87 -3.13,-7 -7,-7zM1,10v2c4.97,0 9,4.03 9,9h2c0,-6.08 -4.93,-11 -11,-11z"/>
    </group>
</vector>
XEOF
cat > res/drawable/cast_on.xml <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="40dp" android:height="40dp"
    android:viewportWidth="40" android:viewportHeight="40">
    <group android:translateX="8" android:translateY="8">
        <path android:fillColor="#FFFFFFFF" android:pathData="M1,18v3h3c0,-1.66 -1.34,-3 -3,-3zM1,14v2c2.76,0 5,2.24 5,5h2c0,-3.87 -3.13,-7 -7,-7zM19,7H5v1.63c3.96,1.02 7.35,4.41 8.37,8.37H19V7zM1,10v2c4.97,0 9,4.03 9,9h2c0,-6.08 -4.93,-11 -11,-11zM21,3H3c-1.1,0 -2,0.9 -2,2v3h2V5h18v14h-7v2h7c1.1,0 2,-0.9 2,-2V5c0,-1.1 -0.9,-2 -2,-2z"/>
    </group>
</vector>
XEOF
echo "== smali/Hook =="
cat > smali/com/ardentlab/cast/Hook.smali <<'XEOF'
.class public Lcom/ardentlab/cast/Hook;
.super Lde/robv/android/xposed/XC_MethodHook;
.implements Lde/robv/android/xposed/IXposedHookLoadPackage;


.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Lde/robv/android/xposed/XC_MethodHook;-><init>()V

    return-void
.end method


.method static say(Ljava/lang/String;)V
    .locals 0

    invoke-static {p0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    return-void
.end method


.method static copyMargins(Landroid/view/ViewGroup$MarginLayoutParams;Landroid/view/ViewGroup$MarginLayoutParams;)V
    .locals 1

    iget v0, p0, Landroid/view/ViewGroup$MarginLayoutParams;->leftMargin:I

    iput v0, p1, Landroid/view/ViewGroup$MarginLayoutParams;->leftMargin:I

    iget v0, p0, Landroid/view/ViewGroup$MarginLayoutParams;->topMargin:I

    iput v0, p1, Landroid/view/ViewGroup$MarginLayoutParams;->topMargin:I

    iget v0, p0, Landroid/view/ViewGroup$MarginLayoutParams;->rightMargin:I

    iput v0, p1, Landroid/view/ViewGroup$MarginLayoutParams;->rightMargin:I

    iget v0, p0, Landroid/view/ViewGroup$MarginLayoutParams;->bottomMargin:I

    iput v0, p1, Landroid/view/ViewGroup$MarginLayoutParams;->bottomMargin:I

    return-void
.end method


# firstInstallTime of this module (kept across pm install -r updates)
.method static installTime(Landroid/content/Context;)J
    .locals 3

    :try_start_0
    invoke-virtual {p0}, Landroid/content/Context;->getPackageManager()Landroid/content/pm/PackageManager;

    move-result-object v0

    const-string v1, "com.ardentlab.cast"

    const/4 v2, 0x0

    invoke-virtual {v0, v1, v2}, Landroid/content/pm/PackageManager;->getPackageInfo(Ljava/lang/String;I)Landroid/content/pm/PackageInfo;

    move-result-object v2

    iget-wide v0, v2, Landroid/content/pm/PackageInfo;->firstInstallTime:J

    return-wide v0
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :catch_0
    const-wide/16 v0, 0x0

    return-wide v0
.end method


.method static myTag(Landroid/content/Context;)Ljava/lang/String;
    .locals 3

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "ardentlab|com.ardentlab.cast|"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-static {p0}, Lcom/ardentlab/cast/Hook;->installTime(Landroid/content/Context;)J

    move-result-wide v1

    invoke-virtual {v0, v1, v2}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    return-object v0
.end method


# true if a view tag belongs to THIS module's button
.method static isMine(Ljava/lang/Object;)Z
    .locals 2

    instance-of v0, p0, Ljava/lang/String;

    if-eqz v0, :cond_no

    check-cast p0, Ljava/lang/String;

    const-string v1, "ardentlab|com.ardentlab.cast|"

    invoke-virtual {p0, v1}, Ljava/lang/String;->startsWith(Ljava/lang/String;)Z

    move-result v0

    return v0

    :cond_no
    const/4 v0, 0x0

    return v0
.end method


# Register this module in the shared order list (Settings.Global "ardentlab_navbar_order").
# Format: ",pkgA:t,pkgB:t," -- earlier entries sit next to home, later ones further left.
# t = firstInstallTime, only used to detect a reinstall (entry is moved to the end).
# Returns the list, or null if settings could not be read/written.
.method static reg(Landroid/content/Context;)Ljava/lang/String;
    .locals 8

    :try_start_0
    invoke-virtual {p0}, Landroid/content/Context;->getContentResolver()Landroid/content/ContentResolver;

    move-result-object v0

    const-string v1, "ardentlab_navbar_order"

    invoke-static {v0, v1}, Landroid/provider/Settings$Global;->getString(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;

    move-result-object v2

    if-nez v2, :cond_has

    const-string v2, ","

    :cond_has
    # entry = "pkg:time"
    new-instance v3, Ljava/lang/StringBuilder;

    invoke-direct {v3}, Ljava/lang/StringBuilder;-><init>()V

    const-string v4, "com.ardentlab.cast:"

    invoke-virtual {v3, v4}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-static {p0}, Lcom/ardentlab/cast/Hook;->installTime(Landroid/content/Context;)J

    move-result-wide v4

    invoke-virtual {v3, v4, v5}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;

    invoke-virtual {v3}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v3

    # already registered with the same install time? done
    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V

    const-string v5, ","

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v4

    invoke-virtual {v2, v4}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v5

    if-nez v5, :cond_done

    # remove an old entry for this package (reinstall)
    const-string v5, ",com.ardentlab.cast:"

    invoke-virtual {v2, v5}, Ljava/lang/String;->indexOf(Ljava/lang/String;)I

    move-result v6

    if-ltz v6, :cond_append

    add-int/lit8 v7, v6, 0x1

    const/16 v5, 0x2c

    invoke-virtual {v2, v5, v7}, Ljava/lang/String;->indexOf(II)I

    move-result v7

    if-ltz v7, :cond_append

    const/4 v5, 0x0

    invoke-virtual {v2, v5, v6}, Ljava/lang/String;->substring(II)Ljava/lang/String;

    move-result-object v5

    invoke-virtual {v2, v7}, Ljava/lang/String;->substring(I)Ljava/lang/String;

    move-result-object v6

    invoke-virtual {v5, v6}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v2

    :cond_append
    invoke-virtual {v2, v3}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v2

    const-string v5, ","

    invoke-virtual {v2, v5}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;

    move-result-object v2

    invoke-static {v0, v1, v2}, Landroid/provider/Settings$Global;->putString(Landroid/content/ContentResolver;Ljava/lang/String;Ljava/lang/String;)Z

    :cond_done
    return-object v2
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    :catch_0
    move-exception v0

    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "CASTBAR order err: "

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lcom/ardentlab/cast/Hook;->say(Ljava/lang/String;)V

    const/4 v0, 0x0

    return-object v0
.end method


# position of a package in the order list (smaller = registered earlier), -1 if absent
.method static rank(Ljava/lang/String;Ljava/lang/String;)I
    .locals 2

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, ","

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    const-string v1, ":"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-virtual {p0, v0}, Ljava/lang/String;->indexOf(Ljava/lang/String;)I

    move-result v0

    return v0
.end method


# where to insert: before the leftmost ArdentLab button registered EARLIER than this one, else before home
.method static findInsertIndex(Landroid/view/ViewGroup;Landroid/view/View;Landroid/content/Context;)I
    .locals 8

    invoke-static {p2}, Lcom/ardentlab/cast/Hook;->reg(Landroid/content/Context;)Ljava/lang/String;

    move-result-object v0

    if-eqz v0, :end

    const-string v1, "com.ardentlab.cast"

    invoke-static {v0, v1}, Lcom/ardentlab/cast/Hook;->rank(Ljava/lang/String;Ljava/lang/String;)I

    move-result v1

    if-ltz v1, :end

    invoke-virtual {p0}, Landroid/view/ViewGroup;->getChildCount()I

    move-result v2

    const/4 v3, 0x0

    :loop
    if-ge v3, v2, :end

    invoke-virtual {p0, v3}, Landroid/view/ViewGroup;->getChildAt(I)Landroid/view/View;

    move-result-object v4

    invoke-virtual {v4}, Landroid/view/View;->getTag()Ljava/lang/Object;

    move-result-object v4

    instance-of v5, v4, Ljava/lang/String;

    if-eqz v5, :next

    check-cast v4, Ljava/lang/String;

    const-string v5, "ardentlab|"

    invoke-virtual {v4, v5}, Ljava/lang/String;->startsWith(Ljava/lang/String;)Z

    move-result v5

    if-eqz v5, :next

    # package = text between "ardentlab|" and the last "|"
    const/16 v5, 0x7c

    invoke-virtual {v4, v5}, Ljava/lang/String;->lastIndexOf(I)I

    move-result v5

    const/16 v6, 0xa

    if-le v5, v6, :next

    invoke-virtual {v4, v6, v5}, Ljava/lang/String;->substring(II)Ljava/lang/String;

    move-result-object v4

    invoke-static {v0, v4}, Lcom/ardentlab/cast/Hook;->rank(Ljava/lang/String;Ljava/lang/String;)I

    move-result v5

    # skip buttons not in the list, or registered later than this one
    if-ltz v5, :next

    if-ge v5, v1, :next

    return v3

    :next
    add-int/lit8 v3, v3, 0x1

    goto :loop

    :end
    invoke-virtual {p0, p1}, Landroid/view/ViewGroup;->indexOfChild(Landroid/view/View;)I

    move-result v3

    return v3
.end method


.method static rid(Landroid/content/res/Resources;Ljava/lang/String;)I
    .locals 2

    const-string v0, "id"

    const-string v1, "com.malaysia.systemuiplugin"

    invoke-virtual {p0, p1, v0, v1}, Landroid/content/res/Resources;->getIdentifier(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)I

    move-result v0

    return v0
.end method


.method public handleLoadPackage(Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;)V
    .locals 4

    iget-object v0, p1, Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;->packageName:Ljava/lang/String;

    const-string v1, "com.android.systemui"

    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v2

    if-nez v2, :cond_0

    # system_server ("android"): stop activity relaunch when an app moves between displays
    const-string v1, "android"

    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v2

    if-nez v2, :cond_sys

    # some Xposed forks name the framework scope "system"
    const-string v1, "system"

    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v2

    if-eqz v2, :cond_ret

    :cond_sys
    invoke-static {p1}, Lcom/ardentlab/cast/SysHook;->install(Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;)V

    :cond_ret
    return-void

    :cond_0
    :try_start_0
    const-string v0, "com.ecarx.systemui.EcarxBars"

    iget-object v1, p1, Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;->classLoader:Ljava/lang/ClassLoader;

    invoke-static {v0, v1}, Lde/robv/android/xposed/XposedHelpers;->findClass(Ljava/lang/String;Ljava/lang/ClassLoader;)Ljava/lang/Class;

    move-result-object v0

    const-string v1, "getNavigationBarView"

    invoke-static {v0, v1, p0}, Lde/robv/android/xposed/XposedBridge;->hookAllMethods(Ljava/lang/Class;Ljava/lang/String;Lde/robv/android/xposed/XC_MethodHook;)Ljava/util/Set;

    const-string v0, "CASTBAR: hooked"

    invoke-static {v0}, Lcom/ardentlab/cast/Hook;->say(Ljava/lang/String;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    goto :goto_0

    :catch_0
    move-exception v0

    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lcom/ardentlab/cast/Hook;->say(Ljava/lang/String;)V

    :goto_0
    return-void
.end method


.method protected afterHookedMethod(Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;)V
    .locals 16

    :try_start_0
    invoke-virtual/range {p1 .. p1}, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->getResult()Ljava/lang/Object;

    move-result-object v0

    if-nez v0, :cond_have

    return-void

    :cond_have
    check-cast v0, Landroid/view/View;

    invoke-virtual {v0}, Landroid/view/View;->getContext()Landroid/content/Context;

    move-result-object v1

    invoke-virtual {v0}, Landroid/view/View;->getResources()Landroid/content/res/Resources;

    move-result-object v2

    # home view
    const-string v3, "layout_home"

    invoke-static {v2, v3}, Lcom/ardentlab/cast/Hook;->rid(Landroid/content/res/Resources;Ljava/lang/String;)I

    move-result v3

    if-nez v3, :cond_hid

    return-void

    :cond_hid
    invoke-virtual {v0, v3}, Landroid/view/View;->findViewById(I)Landroid/view/View;

    move-result-object v4

    if-nez v4, :cond_home

    return-void

    :cond_home
    invoke-virtual {v4}, Landroid/view/View;->getParent()Landroid/view/ViewParent;

    move-result-object v5

    instance-of v6, v5, Landroid/view/ViewGroup;

    if-nez v6, :cond_pg

    return-void

    :cond_pg
    check-cast v5, Landroid/view/ViewGroup;

    # de-dup
    invoke-virtual {v5}, Landroid/view/ViewGroup;->getChildCount()I

    move-result v6

    const/4 v7, 0x0

    :dloop
    if-ge v7, v6, :dbuild

    invoke-virtual {v5, v7}, Landroid/view/ViewGroup;->getChildAt(I)Landroid/view/View;

    move-result-object v8

    invoke-virtual {v8}, Landroid/view/View;->getTag()Ljava/lang/Object;

    move-result-object v8

    invoke-static {v8}, Lcom/ardentlab/cast/Hook;->isMine(Ljava/lang/Object;)Z

    move-result v8

    if-eqz v8, :dnext

    return-void

    :dnext
    add-int/lit8 v7, v7, 0x1

    goto :dloop

    :dbuild
    # drawables
    const-string v6, "com.ardentlab.cast"

    const/4 v7, 0x2

    invoke-virtual {v1, v6, v7}, Landroid/content/Context;->createPackageContext(Ljava/lang/String;I)Landroid/content/Context;

    move-result-object v9

    invoke-virtual {v9}, Landroid/content/Context;->getResources()Landroid/content/res/Resources;

    move-result-object v10

    const-string v6, "cast_off"

    const-string v7, "drawable"

    const-string v8, "com.ardentlab.cast"

    invoke-virtual {v10, v6, v7, v8}, Landroid/content/res/Resources;->getIdentifier(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)I

    move-result v6

    const-string v9, "cast_on"

    invoke-virtual {v10, v9, v7, v8}, Landroid/content/res/Resources;->getIdentifier(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)I

    move-result v9

    invoke-virtual {v10, v6}, Landroid/content/res/Resources;->getDrawable(I)Landroid/graphics/drawable/Drawable;

    move-result-object v11

    invoke-virtual {v10, v9}, Landroid/content/res/Resources;->getDrawable(I)Landroid/graphics/drawable/Drawable;

    move-result-object v12

    # template = the all-apps button (its right margin gives even spacing); fall back to home
    const-string v6, "app"

    invoke-static {v2, v6}, Lcom/ardentlab/cast/Hook;->rid(Landroid/content/res/Resources;Ljava/lang/String;)I

    move-result v6

    invoke-virtual {v0, v6}, Landroid/view/View;->findViewById(I)Landroid/view/View;

    move-result-object v6

    if-nez v6, :cond_tmpl

    move-object v6, v4

    :cond_tmpl
    # clone template LinearLayout.LayoutParams
    invoke-virtual {v6}, Landroid/view/View;->getLayoutParams()Landroid/view/ViewGroup$LayoutParams;

    move-result-object v3

    check-cast v3, Landroid/widget/LinearLayout$LayoutParams;

    iget v7, v3, Landroid/widget/LinearLayout$LayoutParams;->width:I

    iget v8, v3, Landroid/widget/LinearLayout$LayoutParams;->height:I

    new-instance v15, Landroid/widget/LinearLayout$LayoutParams;

    invoke-direct {v15, v7, v8}, Landroid/widget/LinearLayout$LayoutParams;-><init>(II)V

    invoke-static {v3, v15}, Lcom/ardentlab/cast/Hook;->copyMargins(Landroid/view/ViewGroup$MarginLayoutParams;Landroid/view/ViewGroup$MarginLayoutParams;)V

    # spacing 1:2 -> cast sits tight against home (no h-margins); the all-apps
    # button's own right margin supplies the wider left gap
    const/4 v7, 0x0

    iput v7, v15, Landroid/view/ViewGroup$MarginLayoutParams;->rightMargin:I

    iput v7, v15, Landroid/view/ViewGroup$MarginLayoutParams;->leftMargin:I

    iget v7, v3, Landroid/widget/LinearLayout$LayoutParams;->gravity:I

    iput v7, v15, Landroid/widget/LinearLayout$LayoutParams;->gravity:I

    iget v7, v3, Landroid/widget/LinearLayout$LayoutParams;->weight:F

    iput v7, v15, Landroid/widget/LinearLayout$LayoutParams;->weight:F

    # outer FrameLayout
    new-instance v13, Landroid/widget/FrameLayout;

    invoke-direct {v13, v1}, Landroid/widget/FrameLayout;-><init>(Landroid/content/Context;)V

    invoke-virtual {v13, v15}, Landroid/view/View;->setLayoutParams(Landroid/view/ViewGroup$LayoutParams;)V

    invoke-virtual {v6}, Landroid/view/View;->getPaddingLeft()I

    move-result v7

    invoke-virtual {v6}, Landroid/view/View;->getPaddingTop()I

    move-result v8

    invoke-virtual {v6}, Landroid/view/View;->getPaddingRight()I

    move-result v9

    invoke-virtual {v6}, Landroid/view/View;->getPaddingBottom()I

    move-result v10

    invoke-virtual {v13, v7, v8, v9, v10}, Landroid/view/View;->setPadding(IIII)V

    # inner ImageView fills the button (like the others)
    new-instance v14, Landroid/widget/ImageView;

    invoke-direct {v14, v1}, Landroid/widget/ImageView;-><init>(Landroid/content/Context;)V

    const/4 v7, -0x1

    new-instance v15, Landroid/widget/FrameLayout$LayoutParams;

    invoke-direct {v15, v7, v7}, Landroid/widget/FrameLayout$LayoutParams;-><init>(II)V

    invoke-virtual {v14, v15}, Landroid/view/View;->setLayoutParams(Landroid/view/ViewGroup$LayoutParams;)V

    sget-object v7, Landroid/widget/ImageView$ScaleType;->FIT_CENTER:Landroid/widget/ImageView$ScaleType;

    invoke-virtual {v14, v7}, Landroid/widget/ImageView;->setScaleType(Landroid/widget/ImageView$ScaleType;)V

    invoke-virtual {v14, v11}, Landroid/widget/ImageView;->setImageDrawable(Landroid/graphics/drawable/Drawable;)V

    # assemble
    invoke-virtual {v13, v14}, Landroid/widget/FrameLayout;->addView(Landroid/view/View;)V

    # tag = "ardentlab|<pkg>|<firstInstallTime>" (shared convention for all ArdentLab navbar buttons)
    invoke-static {v1}, Lcom/ardentlab/cast/Hook;->myTag(Landroid/content/Context;)Ljava/lang/String;

    move-result-object v7

    invoke-virtual {v13, v7}, Landroid/view/View;->setTag(Ljava/lang/Object;)V

    new-instance v15, Lcom/ardentlab/cast/CastClick;

    invoke-direct {v15, v14, v11, v12}, Lcom/ardentlab/cast/CastClick;-><init>(Landroid/widget/ImageView;Landroid/graphics/drawable/Drawable;Landroid/graphics/drawable/Drawable;)V

    const/4 v7, 0x1

    invoke-virtual {v13, v7}, Landroid/view/View;->setClickable(Z)V

    invoke-virtual {v13, v15}, Landroid/view/View;->setOnTouchListener(Landroid/view/View$OnTouchListener;)V

    # insert by install order: oldest ArdentLab button next to home, newer ones further left
    invoke-static {v5, v4, v1}, Lcom/ardentlab/cast/Hook;->findInsertIndex(Landroid/view/ViewGroup;Landroid/view/View;Landroid/content/Context;)I

    move-result v7

    invoke-virtual {v5, v13, v7}, Landroid/view/ViewGroup;->addView(Landroid/view/View;I)V

    const-string v7, "CASTBAR: inserted"

    invoke-static {v7}, Lcom/ardentlab/cast/Hook;->say(Ljava/lang/String;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    goto :goto_ret

    :catch_0
    move-exception v0

    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "CASTBAR err: "

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lcom/ardentlab/cast/Hook;->say(Ljava/lang/String;)V

    :goto_ret
    return-void
.end method
XEOF
echo "== smali/CastClick =="
cat > smali/com/ardentlab/cast/CastClick.smali <<'XEOF'
.class public Lcom/ardentlab/cast/CastClick;
.super Ljava/lang/Object;
.implements Landroid/view/View$OnTouchListener;


.field img:Landroid/widget/ImageView;

.field red:Landroid/graphics/drawable/Drawable;

.field grn:Landroid/graphics/drawable/Drawable;

.field on:Z

.field savedStack:I


.method public constructor <init>(Landroid/widget/ImageView;Landroid/graphics/drawable/Drawable;Landroid/graphics/drawable/Drawable;)V
    .locals 1

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/ardentlab/cast/CastClick;->img:Landroid/widget/ImageView;

    iput-object p2, p0, Lcom/ardentlab/cast/CastClick;->red:Landroid/graphics/drawable/Drawable;

    iput-object p3, p0, Lcom/ardentlab/cast/CastClick;->grn:Landroid/graphics/drawable/Drawable;

    const/4 v0, 0x0

    iput-boolean v0, p0, Lcom/ardentlab/cast/CastClick;->on:Z

    iput v0, p0, Lcom/ardentlab/cast/CastClick;->savedStack:I

    return-void
.end method


# move the focused app's stack to display 1 (cast) or back to display 0 (uncast)
# uses IActivityManager.moveStackToDisplay via reflection (runs inside systemui)
.method doCast(Z)Z
    .locals 7

    :try_start_0
    const-class v0, Landroid/app/ActivityManager;

    const-string v1, "getService"

    const/4 v2, 0x0

    new-array v2, v2, [Ljava/lang/Object;

    invoke-static {v0, v1, v2}, Lde/robv/android/xposed/XposedHelpers;->callStaticMethod(Ljava/lang/Class;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v0

    if-eqz p1, :cond_uncast

    # ---- CAST: find focused stack, move it to display 1 ----
    const-string v1, "getFocusedStackInfo"

    const/4 v2, 0x0

    new-array v2, v2, [Ljava/lang/Object;

    invoke-static {v0, v1, v2}, Lde/robv/android/xposed/XposedHelpers;->callMethod(Ljava/lang/Object;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v1

    if-eqz v1, :goto_fail

    # skip if the focused stack is not on the IHU (display 0)
    const-string v2, "displayId"

    invoke-static {v1, v2}, Lde/robv/android/xposed/XposedHelpers;->getIntField(Ljava/lang/Object;Ljava/lang/String;)I

    move-result v2

    if-nez v2, :goto_fail

    # skip if the focused app is the launcher (home screen)
    const-string v2, "topActivity"

    invoke-static {v1, v2}, Lde/robv/android/xposed/XposedHelpers;->getObjectField(Ljava/lang/Object;Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v2

    if-eqz v2, :goto_fail

    check-cast v2, Landroid/content/ComponentName;

    invoke-virtual {v2}, Landroid/content/ComponentName;->getPackageName()Ljava/lang/String;

    move-result-object v2

    const-string v3, "com.malaysia.launcher3"

    invoke-virtual {v3, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v2

    if-nez v2, :goto_fail

    const-string v2, "stackId"

    invoke-static {v1, v2}, Lde/robv/android/xposed/XposedHelpers;->getIntField(Ljava/lang/Object;Ljava/lang/String;)I

    move-result v2

    iput v2, p0, Lcom/ardentlab/cast/CastClick;->savedStack:I

    const/4 v3, 0x1

    invoke-static {v0, v2, v3}, Lcom/ardentlab/cast/CastClick;->moveStack(Ljava/lang/Object;II)V

    # tell the cluster navigation is active (old NavCast trick), so steering POWER switches it to HDMI
    iget-object v1, p0, Lcom/ardentlab/cast/CastClick;->img:Landroid/widget/ImageView;

    invoke-virtual {v1}, Landroid/view/View;->getContext()Landroid/content/Context;

    move-result-object v1

    invoke-static {v1}, Lcom/ardentlab/cast/NavTrick;->send(Landroid/content/Context;)V

    const/4 v0, 0x1

    return v0

    :cond_uncast
    # ---- UNCAST: move the saved stack back to display 0 ----
    iget v2, p0, Lcom/ardentlab/cast/CastClick;->savedStack:I

    const/4 v3, 0x0

    invoke-static {v0, v2, v3}, Lcom/ardentlab/cast/CastClick;->moveStack(Ljava/lang/Object;II)V

    const/4 v0, 0x1

    return v0

    :goto_fail
    const-string v0, "CAST skipped (home screen or not on IHU)"

    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    const/4 v0, 0x0

    return v0

    :catch_0
    move-exception v0

    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "CAST err: "

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    # cast failed -> report failure (icon reverts to off); uncast failed -> treat as off anyway
    xor-int/lit8 v0, p1, 0x1

    return v0
.end method


# amSvc.moveStackToDisplay(stackId, displayId)
.method static moveStack(Ljava/lang/Object;II)V
    .locals 4

    const-string v0, "moveStackToDisplay"

    const/4 v1, 0x2

    new-array v1, v1, [Ljava/lang/Object;

    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v2

    const/4 v3, 0x0

    aput-object v2, v1, v3

    invoke-static {p2}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v2

    const/4 v3, 0x1

    aput-object v2, v1, v3

    invoke-static {p0, v0, v1}, Lde/robv/android/xposed/XposedHelpers;->callMethod(Ljava/lang/Object;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/Object;

    return-void
.end method


.method public onTouch(Landroid/view/View;Landroid/view/MotionEvent;)Z
    .locals 4

    invoke-virtual {p2}, Landroid/view/MotionEvent;->getActionMasked()I

    move-result v0

    const/4 v1, 0x1

    # ACTION_DOWN (0): dim
    if-nez v0, :cond_notdown

    iget-object v2, p0, Lcom/ardentlab/cast/CastClick;->img:Landroid/widget/ImageView;

    const v3, 0x3f000000    # 0.5f

    invoke-virtual {v2, v3}, Landroid/view/View;->setAlpha(F)V

    return v1

    :cond_notdown
    # ACTION_UP (1): brighten + toggle + cast/uncast
    if-ne v0, v1, :cond_notup

    iget-object v2, p0, Lcom/ardentlab/cast/CastClick;->img:Landroid/widget/ImageView;

    const v3, 0x3f800000    # 1.0f

    invoke-virtual {v2, v3}, Landroid/view/View;->setAlpha(F)V

    # wanted new state = !on ; do the action first
    iget-boolean v2, p0, Lcom/ardentlab/cast/CastClick;->on:Z

    xor-int/2addr v2, v1

    invoke-virtual {p0, v2}, Lcom/ardentlab/cast/CastClick;->doCast(Z)Z

    move-result v0

    # if casting was refused/failed, stay off
    if-nez v0, :cond_ok

    const/4 v2, 0x0

    :cond_ok
    iput-boolean v2, p0, Lcom/ardentlab/cast/CastClick;->on:Z

    iget-object v3, p0, Lcom/ardentlab/cast/CastClick;->img:Landroid/widget/ImageView;

    if-eqz v2, :cond_off

    iget-object v0, p0, Lcom/ardentlab/cast/CastClick;->grn:Landroid/graphics/drawable/Drawable;

    goto :goto_set

    :cond_off
    iget-object v0, p0, Lcom/ardentlab/cast/CastClick;->red:Landroid/graphics/drawable/Drawable;

    :goto_set
    invoke-virtual {v3, v0}, Landroid/widget/ImageView;->setImageDrawable(Landroid/graphics/drawable/Drawable;)V

    return v1

    :cond_notup
    # ACTION_CANCEL (3): brighten, no toggle
    const/4 v2, 0x3

    if-ne v0, v2, :cond_other

    iget-object v2, p0, Lcom/ardentlab/cast/CastClick;->img:Landroid/widget/ImageView;

    const v3, 0x3f800000

    invoke-virtual {v2, v3}, Landroid/view/View;->setAlpha(F)V

    :cond_other
    return v1
.end method
XEOF
echo "== smali/SysHook =="
cat > smali/com/ardentlab/cast/SysHook.smali <<'XEOF'
.class public Lcom/ardentlab/cast/SysHook;
.super Lde/robv/android/xposed/XC_MethodHook;

# Runs inside system_server (scope "android").
# mode 0 = ActivityRecord.ensureActivityConfiguration : remember if the activity changed display
# mode 1 = ActivityRecord.shouldRelaunchLocked         : return false for display moves, so the app
#          gets onMovedToDisplay/onConfigurationChanged instead of being relaunched (no restart)


.field mode:I

.field static warned:Z


.method public constructor <init>(I)V
    .locals 0

    invoke-direct {p0}, Lde/robv/android/xposed/XC_MethodHook;-><init>()V

    iput p1, p0, Lcom/ardentlab/cast/SysHook;->mode:I

    return-void
.end method


.method public static install(Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;)V
    .locals 4

    :try_start_0
    const-string v0, "com.android.server.am.ActivityRecord"

    iget-object v1, p0, Lde/robv/android/xposed/callbacks/XC_LoadPackage$LoadPackageParam;->classLoader:Ljava/lang/ClassLoader;

    invoke-static {v0, v1}, Lde/robv/android/xposed/XposedHelpers;->findClass(Ljava/lang/String;Ljava/lang/ClassLoader;)Ljava/lang/Class;

    move-result-object v0

    new-instance v2, Lcom/ardentlab/cast/SysHook;

    const/4 v3, 0x0

    invoke-direct {v2, v3}, Lcom/ardentlab/cast/SysHook;-><init>(I)V

    const-string v1, "ensureActivityConfiguration"

    invoke-static {v0, v1, v2}, Lde/robv/android/xposed/XposedBridge;->hookAllMethods(Ljava/lang/Class;Ljava/lang/String;Lde/robv/android/xposed/XC_MethodHook;)Ljava/util/Set;

    move-result-object v1

    invoke-interface {v1}, Ljava/util/Set;->size()I

    move-result v3

    new-instance v2, Lcom/ardentlab/cast/SysHook;

    const/4 v1, 0x1

    invoke-direct {v2, v1}, Lcom/ardentlab/cast/SysHook;-><init>(I)V

    const-string v1, "shouldRelaunchLocked"

    invoke-static {v0, v1, v2}, Lde/robv/android/xposed/XposedBridge;->hookAllMethods(Ljava/lang/Class;Ljava/lang/String;Lde/robv/android/xposed/XC_MethodHook;)Ljava/util/Set;

    move-result-object v1

    invoke-interface {v1}, Ljava/util/Set;->size()I

    move-result v1

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "CAST sys: hooked ensureActivityConfiguration="

    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, v3}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    const-string v2, " shouldRelaunchLocked="

    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    goto :goto_ret

    :catch_0
    move-exception v0

    const-string v1, "CAST sys: hook install FAILED"

    invoke-static {v1}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/Throwable;)V

    :goto_ret
    return-void
.end method


.method protected beforeHookedMethod(Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;)V
    .locals 6

    :try_start_0
    iget-object v0, p1, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->thisObject:Ljava/lang/Object;

    if-eqz v0, :goto_done

    iget v1, p0, Lcom/ardentlab/cast/SysHook;->mode:I

    # current display of this activity
    const-string v2, "getDisplayId"

    const/4 v3, 0x0

    new-array v3, v3, [Ljava/lang/Object;

    invoke-static {v0, v2, v3}, Lde/robv/android/xposed/XposedHelpers;->callMethod(Ljava/lang/Object;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Ljava/lang/Integer;

    invoke-virtual {v2}, Ljava/lang/Integer;->intValue()I

    move-result v2

    if-nez v1, :cond_relaunch

    # ---- mode 0: remember whether the display changed since the app was last told ----
    const-string v3, "mLastReportedDisplayId"

    invoke-static {v0, v3}, Lde/robv/android/xposed/XposedHelpers;->getIntField(Ljava/lang/Object;Ljava/lang/String;)I

    move-result v3

    const/4 v4, 0x0

    if-eq v2, v3, :cond_same

    const/4 v4, 0x1

    :cond_same
    invoke-static {v4}, Ljava/lang/Boolean;->valueOf(Z)Ljava/lang/Boolean;

    move-result-object v4

    const-string v5, "acastDisplayChanged"

    invoke-static {v0, v5, v4}, Lde/robv/android/xposed/XposedHelpers;->setAdditionalInstanceField(Ljava/lang/Object;Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/Object;

    goto :goto_done

    :cond_relaunch
    # ---- mode 1: skip relaunch if the app is on the meter panel or is moving between displays ----
    if-gtz v2, :cond_skip

    const-string v5, "acastDisplayChanged"

    invoke-static {v0, v5}, Lde/robv/android/xposed/XposedHelpers;->getAdditionalInstanceField(Ljava/lang/Object;Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v4

    sget-object v5, Ljava/lang/Boolean;->TRUE:Ljava/lang/Boolean;

    invoke-virtual {v5, v4}, Ljava/lang/Boolean;->equals(Ljava/lang/Object;)Z

    move-result v4

    if-eqz v4, :goto_done

    :cond_skip
    sget-object v4, Ljava/lang/Boolean;->FALSE:Ljava/lang/Boolean;

    invoke-virtual {p1, v4}, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->setResult(Ljava/lang/Object;)V

    const-string v4, "CAST sys: relaunch skipped (display move)"

    invoke-static {v4}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    :goto_done
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_0

    return-void

    :catch_0
    move-exception v0

    # never break system_server; log the first failure only
    sget-boolean v1, Lcom/ardentlab/cast/SysHook;->warned:Z

    if-nez v1, :cond_quiet

    const/4 v1, 0x1

    sput-boolean v1, Lcom/ardentlab/cast/SysHook;->warned:Z

    const-string v1, "CAST sys: hook error (first only)"

    invoke-static {v1}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/Throwable;)V

    :cond_quiet
    return-void
.end method


.method protected afterHookedMethod(Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;)V
    .locals 3

    # mode 0 only: clear the flag once ensureActivityConfiguration is done
    iget v0, p0, Lcom/ardentlab/cast/SysHook;->mode:I

    if-nez v0, :cond_ret

    :try_start_0
    iget-object v0, p1, Lde/robv/android/xposed/XC_MethodHook$MethodHookParam;->thisObject:Ljava/lang/Object;

    if-eqz v0, :cond_ret

    const-string v1, "acastDisplayChanged"

    sget-object v2, Ljava/lang/Boolean;->FALSE:Ljava/lang/Boolean;

    invoke-static {v0, v1, v2}, Lde/robv/android/xposed/XposedHelpers;->setAdditionalInstanceField(Ljava/lang/Object;Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/Object;
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :cond_ret

    :cond_ret
    return-void
.end method
XEOF
echo "== smali/NavTrick =="
cat > smali/com/ardentlab/cast/NavTrick.smali <<'XEOF'
.class public Lcom/ardentlab/cast/NavTrick;
.super Ljava/lang/Object;
.implements Ljava/lang/Runnable;

# Same method as the old Elite Cast "MIRROR: ON" (NavService + NavSender):
#   vsm = new VehicleSignalManager(ctx); vsm.connect();
#   dim = ECarXDimServiceImpl.getInstance(ctx, vsm);
#   then forever every 500 ms: dim.updateNAVInfo(new NavInfo(1))
# (Elite Cast slept 5 s first; here frames start at once and failed early frames are retried)
# This makes the cluster MCU believe navigation is running, so the steering POWER
# button switches the meter panel to HDMI (display 1). Started on the first cast
# tap and kept running (like MIRROR: ON) until the IHU reboots.


.field static running:Z

.field ctx:Landroid/content/Context;


.method public constructor <init>(Landroid/content/Context;)V
    .locals 0

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/ardentlab/cast/NavTrick;->ctx:Landroid/content/Context;

    return-void
.end method


# start the stream once; later calls do nothing
.method public static send(Landroid/content/Context;)V
    .locals 2

    sget-boolean v0, Lcom/ardentlab/cast/NavTrick;->running:Z

    if-nez v0, :cond_ret

    const/4 v0, 0x1

    sput-boolean v0, Lcom/ardentlab/cast/NavTrick;->running:Z

    new-instance v0, Ljava/lang/Thread;

    new-instance v1, Lcom/ardentlab/cast/NavTrick;

    invoke-direct {v1, p0}, Lcom/ardentlab/cast/NavTrick;-><init>(Landroid/content/Context;)V

    invoke-direct {v0, v1}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V

    invoke-virtual {v0}, Ljava/lang/Thread;->start()V

    :cond_ret
    return-void
.end method


.method public run()V
    .locals 6

    # ---- connect (same as Elite Cast NavService.onCreate) ----
    :try_start_0
    iget-object v0, p0, Lcom/ardentlab/cast/NavTrick;->ctx:Landroid/content/Context;

    new-instance v1, Lcom/ecarx/xui/adaptapi/car/impl/vehicle/VehicleSignalManager;

    invoke-direct {v1, v0}, Lcom/ecarx/xui/adaptapi/car/impl/vehicle/VehicleSignalManager;-><init>(Landroid/content/Context;)V

    invoke-virtual {v1}, Lcom/ecarx/xui/adaptapi/car/impl/vehicle/VehicleSignalManager;->connect()V

    invoke-static {v0, v1}, Lcom/malaysia/xui/adaptapi/dim/impl/ECarXDimServiceImpl;->getInstance(Landroid/content/Context;Lcom/ecarx/xui/adaptapi/car/impl/vehicle/VehicleSignalManager;)Lcom/malaysia/xui/adaptapi/dim/impl/ECarXDimServiceImpl;

    move-result-object v1

    const-string v0, "CAST: nav stream connecting (no fixed wait)"

    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V
    :try_end_0
    .catch Ljava/lang/Throwable; {:try_start_0 .. :try_end_0} :catch_setup

    # v4 = first frame sent?  v5 = failed frames before the first success
    const/4 v4, 0x0

    const/4 v5, 0x0

    # ---- stream: start sending right away; frames that fail while the car service is still connecting are retried ----
    :loop
    sget-boolean v0, Lcom/ardentlab/cast/NavTrick;->running:Z

    if-eqz v0, :cond_end

    :try_start_1
    new-instance v0, Lcom/ardentlab/cast/NavInfo;

    const/4 v2, 0x1

    invoke-direct {v0, v2}, Lcom/ardentlab/cast/NavInfo;-><init>(I)V

    invoke-virtual {v1, v0}, Lcom/malaysia/xui/adaptapi/dim/impl/ECarXDimServiceImpl;->updateNAVInfo(Lcom/malaysia/xui/adaptapi/diminteraction/INaviInteraction$INavigationInfo;)V
    :try_end_1
    .catch Ljava/lang/Throwable; {:try_start_1 .. :try_end_1} :catch_frame

    if-nez v4, :cond_sleep

    const/4 v4, 0x1

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "CAST: nav stream running (status 1 every 500 ms), first frame after retries="

    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v0, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    goto :cond_sleep

    :catch_frame
    move-exception v0

    add-int/lit8 v5, v5, 0x1

    # give up after 40 failed frames (20 s) without any success
    if-nez v4, :cond_sleep

    const/16 v2, 0x28

    if-lt v5, v2, :cond_sleep

    const/4 v2, 0x0

    sput-boolean v2, Lcom/ardentlab/cast/NavTrick;->running:Z

    const-string v2, "CAST: nav stream FAILED (car service never accepted a frame)"

    invoke-static {v2}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/Throwable;)V

    return-void

    :cond_sleep
    const-wide/16 v2, 0x1f4

    invoke-static {v2, v3}, Ljava/lang/Thread;->sleep(J)V

    goto :loop

    :cond_end
    return-void

    :catch_setup
    move-exception v0

    const/4 v1, 0x0

    sput-boolean v1, Lcom/ardentlab/cast/NavTrick;->running:Z

    const-string v1, "CAST: nav stream FAILED (connect)"

    invoke-static {v1}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/String;)V

    invoke-static {v0}, Lde/robv/android/xposed/XposedBridge;->log(Ljava/lang/Throwable;)V

    return-void
.end method
XEOF
echo "== smali/NavInfo =="
cat > smali/com/ardentlab/cast/NavInfo.smali <<'XEOF'
.class public Lcom/ardentlab/cast/NavInfo;
.super Ljava/lang/Object;
.implements Lcom/malaysia/xui/adaptapi/diminteraction/INaviInteraction$INavigationInfo;

# Fake "navigation info" frame, identical to the old Elite Cast NavInfo:
# only the status is set (1 = navigating, 0 = stopped); everything else empty.


.field status:I


.method public constructor <init>(I)V
    .locals 0

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput p1, p0, Lcom/ardentlab/cast/NavInfo;->status:I

    return-void
.end method


.method public getDayNightMode()I
    .locals 1

    const/4 v0, 0x0

    return v0
.end method


.method public getDistanceToDestination()J
    .locals 2

    const-wide/16 v0, 0x0

    return-wide v0
.end method


.method public getDistanceToNextGuidancePoint()J
    .locals 2

    const-wide/16 v0, 0x0

    return-wide v0
.end method


.method public getDrivingDirection()I
    .locals 1

    const/4 v0, 0x0

    return v0
.end method


.method public getETA()J
    .locals 2

    const-wide/16 v0, 0x0

    return-wide v0
.end method


.method public getHighwayExitInfo()Lcom/malaysia/xui/adaptapi/diminteraction/INaviInteraction$IHighwayExitInfo;
    .locals 1

    const/4 v0, 0x0

    return-object v0
.end method


.method public getLaneInfo()[Lcom/malaysia/xui/adaptapi/diminteraction/INaviInteraction$ILaneInfo;
    .locals 1

    const/4 v0, 0x0

    return-object v0
.end method


.method public getMuteState()I
    .locals 1

    const/4 v0, 0x0

    return v0
.end method


.method public getNavigationStatus()I
    .locals 1

    iget v0, p0, Lcom/ardentlab/cast/NavInfo;->status:I

    return v0
.end method


.method public getNavigationTurnId()I
    .locals 1

    const/4 v0, 0x0

    return v0
.end method


.method public getNavigationTurnSVG()Ljava/lang/String;
    .locals 1

    const-string v0, " "

    return-object v0
.end method


.method public getNextGuidancePointName()Ljava/lang/String;
    .locals 1

    const-string v0, " "

    return-object v0
.end method


.method public getRoadCameraInfo()Lcom/malaysia/xui/adaptapi/diminteraction/INaviInteraction$IRoadCamera;
    .locals 1

    const/4 v0, 0x0

    return-object v0
.end method


.method public getServiceAreaInfo()Lcom/malaysia/xui/adaptapi/diminteraction/INaviInteraction$IServiceArea;
    .locals 1

    const/4 v0, 0x0

    return-object v0
.end method
XEOF
echo "== building =="
cd "$HOME"
apktool b CastBar -o "$HOME/CastBar.apk"
if [ ! -f "$KS" ]; then
  echo "== creating signing key =="
  keytool -genkeypair -v -keystore "$KS" -alias castbar -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Cast, OU=RD, O=ArdentLab, L=KL, ST=KL, C=MY"
fi
echo "== signing =="
jarsigner -keystore "$KS" -storepass android -keypass android "$HOME/CastBar.apk" castbar
echo "== aligning =="
zipalign -f 4 "$HOME/CastBar.apk" "$HOME/CastBar-signed.apk"
echo; echo "DONE -> $HOME/CastBar-signed.apk"; ls -l "$HOME/CastBar-signed.apk"
