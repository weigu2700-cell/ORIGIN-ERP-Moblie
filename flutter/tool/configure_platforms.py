#!/usr/bin/env python3
"""给 Flutter 生成的宿主补充相机说明、网络权限及安全存储设置，可重复执行。"""
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
android = root / 'android/app/src/main/AndroidManifest.xml'
if android.exists():
    ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
    ns = '{http://schemas.android.com/apk/res/android}'
    tree = ET.parse(android)
    manifest = tree.getroot()
    for permission in ['android.permission.INTERNET', 'android.permission.CAMERA']:
        if not any(e.get(ns+'name') == permission for e in manifest.findall('uses-permission')):
            ET.SubElement(manifest, 'uses-permission', {ns+'name': permission})
    app = manifest.find('application')
    app.set(ns+'label', '原点智造')
    app.set(ns+'allowBackup', 'false')
    # 不开启全局明文传输；测试 HTTP 服务器需使用 HTTPS 或明确配置 debug 域名例外。
    ET.indent(tree, space='    ')
    tree.write(android, encoding='utf-8', xml_declaration=True)
    gradle = root / 'android/app/build.gradle.kts'
    if gradle.exists():
        text = gradle.read_text()
        text = re.sub(r'minSdk = flutter.minSdkVersion', 'minSdk = maxOf(23, flutter.minSdkVersion)', text)
        gradle.write_text(text)

info = root / 'ios/Runner/Info.plist'
if info.exists():
    with info.open('rb') as handle:
        data = plistlib.load(handle)
    data.update(CFBundleDisplayName='原点智造', NSCameraUsageDescription='用于扫描物料和业务编码，识别后由你核对作业对象。')
    with info.open('wb') as handle:
        plistlib.dump(data, handle, sort_keys=False)
    entitlements = root / 'ios/Runner/Runner.entitlements'
    capability = {}
    if entitlements.exists():
        with entitlements.open('rb') as handle:
            capability = plistlib.load(handle)
    capability.setdefault('keychain-access-groups', [])
    with entitlements.open('wb') as handle:
        plistlib.dump(capability, handle, sort_keys=False)
    project = root / 'ios/Runner.xcodeproj/project.pbxproj'
    if project.exists():
        text = project.read_text()
        def configure_runner(match):
            block = match.group(0)
            if 'INFOPLIST_FILE = Runner/Info.plist;' in block and 'CODE_SIGN_ENTITLEMENTS' not in block:
                block = block.replace('INFOPLIST_FILE = Runner/Info.plist;', 'INFOPLIST_FILE = Runner/Info.plist;\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;')
            return block
        text = re.sub(r'buildSettings = \{.*?\n\s*\};', configure_runner, text, flags=re.S)
        project.write_text(text)
    # 不写入开发团队、签名及生产 bundle ID。
